extends Node3D

# Game orchestrator: launch sequence, navigation, game rules, power-ups, retention
# systems and the glue between screens, the 3D world, ads and purchases.
# Screens live in scripts/screens, widgets in scripts/ui, the ad/billing bridge
# in scripts/services/android_platform.gd.

const HINT_COST := 40
const EXTRA_MOVES_COST := 30
const EXTRA_TUBE_COST := 100
const CRYSTAL_COST := 60
const LEVEL_COMPLETE_COINS := 5
const MATCH_COINS := 2
const GOLD_COINS := 8
const MAX_TUBES := 10
const NUDGE_AFTER := 14.0
const SLEEPY_AFTER := 40.0

const CHEERS := ["Nice one!", "Sparkling!", "Great match!", "Crystal clear!", "You got it!", "Brilliant!"]
const OOPS := ["Hmm, not there.", "Try another tube!", "Careful now!"]
const PICKS := ["Good choice.", "Where to?", "Ooh, that one."]
const LOW := ["Only a few moves left!", "Think carefully!"]
const GREETINGS := ["Let's go!", "You can do it!", "Ready when you are!"]
const POKES := ["Hehe, that tickles!", "Hi there!", "Need me?", "Let's play!"]
const DOUBLES := ["Double match!", "Two in a row!", "You're on fire!"]
const CASCADES := ["Cascade!", "Chain reaction!", "Look at that go!"]
const STUCK := ["Hmm, nothing can move...", "We're stuck! New tube?"]
const SLEEPY := ["Hmm? Oh, still here!", "*yawn* Tap me!", "Waiting for you..."]

const PRELOAD_ICONS := [
	"ad_free", "arrow_right", "back", "bag", "bulb", "calendar", "camera", "check", "chest",
	"chevron_right", "clock", "close", "coin", "diamond", "flame", "gear", "gift", "grid",
	"heart", "home", "lock", "moon", "moves", "music", "pause", "play", "plus", "restore",
	"scroll", "share", "sound", "star", "star_outline", "sun", "trash", "trophy", "tube",
	"vibrate", "video", "wallet",
]

enum UiScreen { NONE, HOME, LEVELS, GAME, SHOP, REWARDS, SETTINGS, RESULT }

# ── State ─────────────────────────────────────────────────────────────────────
var save: SaveData
var audio: AudioManager
var world: GameWorld
var platform: AndroidPlatform
var ui: Control
var screen_root: Control
var overlay_root: Control
var screen: Control = null
var hud: GameHud = null
var _world_ready := false
var _start_waiting := false

var current_screen: UiScreen = UiScreen.NONE
var game_status := GameData.Status.IDLE
var current_level := 1
var level_info: Dictionary = {}
var tubes: Array = []
var caps: Array = []
var selected := -1
var moves := 0
var score := 0
var combo := 0
var stars := 0
var coins_earned := 0
var _doubled := false
var _streak_bonus := 0
var _hints_used_level := 0
var _idle_time := 0.0
var _idle_nudged := false
var _idle_sleepy := false
var _pending_pu := ""
var _chest_reward: Dictionary = {}
var _chest_wait := false
var _login_double_wait := false
var _modal: Control = null
var _toast_node: Control = null
var _banner_reserve := 0
var _back_armed_until_ms := 0
var _last_poke_ms := 0
var _busy := false
var _level_token := 0
var _moves_made := 0
var _gold_collected := 0
var _best_chain := 0
var _lose_reason := "moves"
var _return_to_game := false
var _boss_chest_due := false
var _chest_boss := false
var _plan: Array = []
var _plan_keys: Array = []
var _pending_reveals: Array = []

# ── Crash trail (diagnostics) ─────────────────────────────────────────────────
# Every risky step is written to a small file and flushed immediately. Hidden in
# production: in Settings tap "Version" 7 times to open the viewer. Set
# SHOW_CRASH_TRAIL to true to show the previous run's trail automatically.
const SHOW_CRASH_TRAIL := true
const CRASH_LOG_PATH := "user://crash_trail.txt"
const MARK_CLEAN := "=== SESSION ENDED CLEANLY ==="
const MARK_PAUSED := "=== APP PAUSED ==="
const MARK_RESUMED := "=== APP RESUMED ==="
var _trail_file: FileAccess = null
var _prev_trail_text := ""

func _open_trail() -> void:
	_trail_file = FileAccess.open(CRASH_LOG_PATH, FileAccess.WRITE)

func _trail(msg: String) -> void:
	print("[CC-DEBUG] " + msg)
	if _trail_file:
		_trail_file.store_line("%d | %s" % [Time.get_ticks_msec(), msg])
		_trail_file.flush()

func _read_trail_file() -> String:
	if not FileAccess.file_exists(CRASH_LOG_PATH):
		return ""
	var f := FileAccess.open(CRASH_LOG_PATH, FileAccess.READ)
	if f == null:
		return ""
	var content := f.get_as_text()
	f.close()
	return content

# A session counts as a crash unless its LAST line is a clean-exit / paused marker.
func _trail_is_crash(content: String) -> bool:
	var lines := content.strip_edges().split("\n")
	if lines.size() == 0 or lines[0] == "":
		return false
	var last := lines[lines.size() - 1]
	return not (last.ends_with(MARK_CLEAN) or last.ends_with(MARK_PAUSED))

func _log_environment() -> void:
	_trail("build %s, godot %s" % [ProductionConfig.VERSION_NAME, str(Engine.get_version_info().get("string", "?"))])
	_trail("os %s, model %s" % [OS.get_name(), OS.get_model_name()])
	_trail("gpu %s, vendor %s" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor()])
	_trail("static mem %d MB" % (OS.get_static_memory_usage() / 1048576))

func _trail_after_draw(tag: String) -> void:
	await RenderingServer.frame_post_draw
	_trail("frame drawn after %s" % tag)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_trail(MARK_CLEAN)
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		if save:
			save.save()
		_trail(MARK_PAUSED)
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_trail(MARK_RESUMED)
		if save:
			save.refresh_lives()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_handle_back()

# ── Launch sequence ───────────────────────────────────────────────────────────

func _ready() -> void:
	_prev_trail_text = _read_trail_file()
	var crashed := _trail_is_crash(_prev_trail_text)
	_open_trail()
	_trail("main._ready begin")
	_log_environment()
	_compute_insets()
	save = SaveData.new()
	add_child(save)
	audio = AudioManager.new()
	add_child(audio)
	audio.enabled = bool(save.data.sound)
	audio.voice_enabled = bool(save.data.voice)
	Ui.sfx_target = self
	_build_root_ui()
	_make_platform()
	# The home screen is built right here, before the first frame: the engine's
	# boot splash is the only splash and it hands over straight to the menu.
	show_home()
	_trail("home screen shown")
	await get_tree().process_frame
	await _boot_background(crashed)
	_trail("main._ready complete")

func _asset_paths() -> Array:
	var paths: Array = []
	for n in PRELOAD_ICONS:
		paths.append("res://assets/icons/%s.png" % n)
	for n in ["pink", "blue", "gold", "green", "purple", "red"]:
		paths.append("res://assets/ui/btn_%s.png" % n)
	for n in ["bg_menu.jpg", "bg_levelselect.jpg", "bg_victory.jpg", "game_logo.png"]:
		paths.append("res://assets/images/%s" % n)
	for n in ["wood_planks", "velvet", "rune_rug", "lab_backdrop"]:
		paths.append("res://assets/textures/%s.png" % n)
	return paths

# The ad/billing bridge object exists from the start (it is null-safe until
# setup() runs in the background boot below).
func _make_platform() -> void:
	platform = AndroidPlatform.new()
	add_child(platform)
	platform.diagnostic.connect(_trail)
	platform.rewarded_earned.connect(_on_rewarded_earned)
	platform.rewarded_cancelled.connect(_on_rewarded_cancelled)
	platform.purchase_completed.connect(_on_purchase_completed)
	platform.purchase_failed.connect(_on_purchase_failed)
	platform.restore_finished.connect(_on_restore_finished)
	platform.prices_updated.connect(_on_prices_updated)
	platform.banner_height_changed.connect(_on_banner_height)

# Everything the home screen does not need is prepared AFTER it is on screen:
# remaining art and sound, the 3D world, ads/billing and a shader warm-up. If
# PLAY is tapped before this finishes, start_level() waits for it.
func _boot_background(crashed: bool) -> void:
	if crashed and SHOW_CRASH_TRAIL:
		_show_diagnostics()
	var paths := _asset_paths()
	for i in range(paths.size()):
		Ui.tex(paths[i])
		if i % 10 == 9:
			await get_tree().process_frame
	for i in range(audio.preload_count()):
		audio.preload_one(i)
		if i % 6 == 5:
			await get_tree().process_frame
	await get_tree().process_frame
	_trail("background: world.build() begin")
	world = GameWorld.new()
	add_child(world)
	world.build()
	world.set_active(false)
	world.set_auto_camera(bool(save.data.auto_camera))
	_trail("background: world.build() returned")
	platform.setup(save)
	await get_tree().process_frame
	await _warm_up()
	audio.load_music()
	audio.set_music(bool(save.data.music))
	_world_ready = true
	_trail("background boot complete")
	audio.play_voice("hello")
	if not (crashed and SHOW_CRASH_TRAIL):
		await get_tree().create_timer(0.4).timeout
		_maybe_show_daily_login()

# Draws one real board (with gold and shadow crystals and two rows of tubes) and
# one avatar frame so every shader is compiled before the first level (otherwise
# the first level start stutters). The home screen's opaque background hides it.
func _warm_up() -> void:
	_trail("warm-up begin")
	var avatar := AvatarPortrait.new()
	avatar.modulate = Color(1, 1, 1, 0.02)
	overlay_root.add_child(avatar)
	overlay_root.move_child(avatar, 0)
	_load_level(12)
	_make_board()
	world.set_active(true)
	for _i in range(3):
		await get_tree().process_frame
	world.set_active(false)
	for child in world.tubes_root.get_children():
		world.tubes_root.remove_child(child)
		child.queue_free()
	tubes.clear()
	avatar.queue_free()
	_trail("warm-up done")

# Safe-area insets (status bar / camera cut-out / gesture bar) in canvas units.
func _compute_insets() -> void:
	var win := DisplayServer.window_get_size()
	if win.x <= 0:
		return
	var k := 1080.0 / float(win.x)
	var safe := DisplayServer.get_display_safe_area()
	var scr := DisplayServer.screen_get_size()
	if safe.size.x > 0 and scr.y > 0:
		Ui.inset_top = clampf(float(safe.position.y) * k, 0.0, 140.0)
		Ui.inset_bottom = clampf(float(scr.y - (safe.position.y + safe.size.y)) * k, 0.0, 120.0)

func _build_root_ui() -> void:
	ui = Control.new()
	Ui.full_rect(ui)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	screen_root = Control.new()
	Ui.full_rect(screen_root)
	screen_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(screen_root)
	overlay_root = Control.new()
	Ui.full_rect(overlay_root)
	overlay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(overlay_root)

func ui_click() -> void:
	if audio:
		audio.play("tap")

func _vibrate(ms: int) -> void:
	if save and bool(save.data.vibration) and OS.get_name() == "Android":
		Input.vibrate_handheld(ms)

# ── Navigation helpers ────────────────────────────────────────────────────────

func _close_modal() -> void:
	if is_instance_valid(_modal):
		_modal.queue_free()
	_modal = null

func _enter(kind: UiScreen) -> void:
	_close_modal()
	if is_instance_valid(screen):
		screen_root.remove_child(screen)
		screen.queue_free()
	screen = null
	hud = null
	current_screen = kind
	if world != null:
		world.set_active(kind == UiScreen.GAME)
	# The only banner left is on Level Select (none on Shop, Rewards or in play).
	if kind == UiScreen.LEVELS:
		platform.show_banner()
	else:
		platform.hide_banner()

func _attach(s: Control) -> void:
	screen_root.add_child(s)
	screen = s

func _apply_banner_reserve() -> void:
	if screen != null and screen.has_method("set_bottom_reserve"):
		screen.call("set_bottom_reserve", _banner_reserve)

func _on_banner_height(px: int) -> void:
	_banner_reserve = px
	_apply_banner_reserve()

# ── HOME ──────────────────────────────────────────────────────────────────────

func show_home() -> void:
	game_status = GameData.Status.IDLE
	_return_to_game = false
	_busy = false
	_enter(UiScreen.HOME)
	save.refresh_lives()
	var s := HomeScreen.new()
	_attach(s)
	s.setup(save)
	s.play_pressed.connect(_on_play)
	s.levels_pressed.connect(show_levels)
	s.shop_pressed.connect(show_shop)
	s.settings_pressed.connect(show_settings)
	s.share_pressed.connect(_share)
	s.rewards_pressed.connect(show_rewards)

func _on_play() -> void:
	start_level(int(save.data.highest_unlocked))

func _share() -> void:
	DisplayServer.clipboard_set(ProductionConfig.SHARE_TEXT + ProductionConfig.PLAY_STORE_URL)
	_toast("Invite link copied. Paste it to a friend!")

# ── LEVEL SELECT ──────────────────────────────────────────────────────────────

func show_levels() -> void:
	game_status = GameData.Status.IDLE
	_return_to_game = false
	_busy = false
	_enter(UiScreen.LEVELS)
	var s := LevelsScreen.new()
	_attach(s)
	s.setup(save)
	s.back_pressed.connect(show_home)
	s.level_selected.connect(start_level)
	_apply_banner_reserve()

# ── SHOP ──────────────────────────────────────────────────────────────────────

func show_shop() -> void:
	game_status = GameData.Status.IDLE
	_enter(UiScreen.SHOP)
	var s := ShopScreen.new()
	_attach(s)
	s.setup(save, platform.prices)
	s.back_pressed.connect(_back_from_sub)
	s.purchase_requested.connect(_purchase)
	s.watch_coins_requested.connect(_watch.bind("coins"))
	s.watch_hint_requested.connect(_watch.bind("hint"))
	s.watch_life_requested.connect(_watch.bind("life"))
	s.bonus_requested.connect(_claim_daily_bonus)
	s.rewards_requested.connect(show_rewards)
	s.coins_for_hints_requested.connect(_buy_hints)
	s.coins_for_lives_requested.connect(_refill_lives)

# Rebuilds the shop but keeps the scroll position.
func _refresh_shop() -> void:
	if current_screen != UiScreen.SHOP or screen == null:
		return
	var sv: int = int(screen.call("get_scroll"))
	show_shop()
	await get_tree().process_frame
	if current_screen == UiScreen.SHOP and screen != null:
		screen.call("set_scroll", sv)

func _claim_daily_bonus() -> void:
	if save.claim_daily_bonus():
		audio.play("coin")
		_toast("+%d coins claimed!" % SaveData.DAILY_BONUS)
		_refresh_shop()

func _buy_hints() -> void:
	if save.spend_coins(ShopScreen.HINT_BUNDLE_COST):
		save.add_hints(ShopScreen.HINT_BUNDLE_COUNT)
		audio.play("coin")
		_toast("+%d hints" % ShopScreen.HINT_BUNDLE_COUNT)
		_refresh_shop()
	else:
		_toast("You need %d coins. Watch a video for free coins!" % ShopScreen.HINT_BUNDLE_COST)

func _refill_lives() -> void:
	if int(save.data.lives) >= SaveData.MAX_LIVES:
		_toast("Your lives are already full")
		return
	if save.spend_coins(ShopScreen.LIFE_REFILL_COST):
		while int(save.data.lives) < SaveData.MAX_LIVES:
			save.add_life()
		audio.play("coin")
		_toast("Lives refilled!")
		_refresh_shop()
	else:
		_toast("You need %d coins. Watch a video for free coins!" % ShopScreen.LIFE_REFILL_COST)

func _purchase(product_id: String) -> void:
	if platform.purchase(product_id):
		_toast("Opening Google Play…")

func _on_purchase_completed(_product_id: String) -> void:
	audio.play("coin")
	_toast("Purchase complete!")
	_refresh_shop()

func _on_purchase_failed(_product_id: String, message: String) -> void:
	_toast(message)

func _on_restore_finished(count: int) -> void:
	if count > 0:
		_toast("Purchases restored (%d)" % count)
	else:
		_toast("No purchases to restore")

func _on_prices_updated() -> void:
	_refresh_shop()

# ── REWARDS HUB (login streak, quests, milestones) ───────────────────────────

func show_rewards() -> void:
	game_status = GameData.Status.IDLE
	_enter(UiScreen.REWARDS)
	var s := RewardsScreen.new()
	_attach(s)
	s.setup(save)
	s.back_pressed.connect(_back_from_sub)
	s.claim_login_pressed.connect(_claim_login_hub)
	s.claim_quest_pressed.connect(_claim_quest)
	s.claim_milestone_pressed.connect(_claim_milestone)

func _refresh_rewards() -> void:
	if current_screen != UiScreen.REWARDS or screen == null:
		return
	var sv: int = int(screen.call("get_scroll"))
	show_rewards()
	await get_tree().process_frame
	if current_screen == UiScreen.REWARDS and screen != null:
		screen.call("set_scroll", sv)

func _claim_login_hub() -> void:
	_do_claim_login(1)

func _claim_login_popup() -> void:
	_do_claim_login(1)

func _do_claim_login(mult: int) -> void:
	var day := save.claim_login()
	if day <= 0:
		return
	var r: Dictionary = Rewards.LOGIN[day - 1]
	for _i in range(mult):
		Rewards.grant(save, r)
	audio.play("streak_up")
	audio.play_voice("yay")
	_toast("Day %d reward: %s%s" % [day, Rewards.describe(r), "  (x2!)" if mult > 1 else ""])
	if current_screen == UiScreen.REWARDS:
		_refresh_rewards()
	elif current_screen == UiScreen.HOME:
		show_home()

func _login_double() -> void:
	_login_double_wait = true
	if not platform.show_rewarded("login_double"):
		_login_double_wait = false
		_toast("No video available. Claimed normally.")
		_do_claim_login(1)

func _maybe_show_daily_login() -> void:
	if current_screen != UiScreen.HOME or not save.login_available() or is_instance_valid(_modal):
		return
	var day := save.login_day_if_claimed()
	var r: Dictionary = Rewards.LOGIN[day - 1]
	audio.play("ui_chime")
	_modal = Modals.daily_login(overlay_root, day, Rewards.describe(r),
		Rewards.icon_for(str(r["type"])), platform.is_rewarded_ready(), _claim_login_popup, _login_double)

func _quest_def(id: String) -> Dictionary:
	for q in Rewards.QUEST_POOL:
		var quest: Dictionary = q
		if str(quest["id"]) == id:
			return quest
	return {}

func _claim_quest(id: String) -> void:
	var q := _quest_def(id)
	if q.is_empty() or save.quest_is_claimed(id):
		return
	if save.quest_progress_of(id) < int(q["goal"]):
		return
	Rewards.grant(save, q)
	save.quest_mark_claimed(id)
	audio.play("coin")
	_toast("Quest reward: %s" % Rewards.describe(q))
	_refresh_rewards()

func _claim_milestone(star_goal: int) -> void:
	if save.milestone_is_claimed(star_goal) or int(save.data.total_stars) < star_goal:
		return
	for m in Rewards.MILESTONES:
		var ms: Dictionary = m
		if int(ms["stars"]) == star_goal:
			Rewards.grant(save, ms)
			save.milestone_mark_claimed(star_goal)
			audio.play("coin")
			_toast("Milestone reward: %s" % Rewards.describe(ms))
			_refresh_rewards()
			return

# ── Treasure chest (every 3rd win, plus a bigger one for each boss level) ────

func _roll_chest(boss: bool = false) -> Dictionary:
	var r := randf()
	if boss:
		if r < 0.55:
			return {"type": "coins", "amount": 120 + 20 * (randi() % 7)}
		if r < 0.85:
			return {"type": "hints", "amount": 4}
		return {"type": "lives", "amount": 2}
	if r < 0.6:
		return {"type": "coins", "amount": 40 + 10 * (randi() % 7)}
	if r < 0.85:
		return {"type": "hints", "amount": 2}
	return {"type": "lives", "amount": 1}

func _maybe_offer_chest() -> void:
	var boss := _boss_chest_due
	if not boss and not save.chest_ready():
		return
	await get_tree().create_timer(1.0).timeout
	if current_screen != UiScreen.RESULT or game_status != GameData.Status.WON or is_instance_valid(_modal):
		return
	_chest_boss = boss
	_boss_chest_due = false
	_chest_reward = _roll_chest(boss)
	audio.play("chest_open")
	var title := "BOSS CHEST!" if boss else "TREASURE CHEST!"
	var sub := "Boss defeated! Here is your prize:" if boss else "You cleared 3 levels. Here is your prize:"
	_modal = Modals.chest(overlay_root, Rewards.describe(_chest_reward),
		Rewards.icon_for(str(_chest_reward["type"])), platform.is_rewarded_ready(), _collect_chest, _double_chest, title, sub)

func _collect_chest() -> void:
	Rewards.grant(save, _chest_reward)
	if not _chest_boss:
		save.chest_opened()
	audio.play("coin")
	_toast("Chest: %s" % Rewards.describe(_chest_reward))

func _double_chest() -> void:
	_chest_wait = true
	if not platform.show_rewarded("chest_double"):
		_chest_wait = false
		_toast("No video available. Collected normally.")
		_collect_chest()

# ── SETTINGS ──────────────────────────────────────────────────────────────────

func show_settings() -> void:
	game_status = GameData.Status.IDLE
	_enter(UiScreen.SETTINGS)
	var s := SettingsScreen.new()
	_attach(s)
	s.setup(save)
	s.back_pressed.connect(show_home)
	s.sound_toggled.connect(_set_sound)
	s.music_toggled.connect(_set_music)
	s.vibration_toggled.connect(_set_vibration)
	s.voice_toggled.connect(_set_voice)
	s.auto_camera_toggled.connect(_set_auto_camera)
	s.restore_pressed.connect(_restore)
	s.reset_pressed.connect(_confirm_reset)
	s.privacy_pressed.connect(_open_privacy)
	s.diagnostics_requested.connect(_show_diagnostics)

func _set_sound(v: bool) -> void:
	save.set_setting("sound", v)
	audio.enabled = v

func _set_music(v: bool) -> void:
	save.set_setting("music", v)
	audio.set_music(v)

func _set_vibration(v: bool) -> void:
	save.set_setting("vibration", v)
	_vibrate(40)

func _set_voice(v: bool) -> void:
	save.set_setting("voice", v)
	audio.voice_enabled = v
	if v:
		audio.play_voice("giggle")

func _set_auto_camera(v: bool) -> void:
	save.set_setting("auto_camera", v)
	if world != null:
		world.set_auto_camera(v)

func _restore() -> void:
	if platform.has_billing():
		_toast("Checking your purchases…")
	platform.restore_purchases()

func _open_privacy() -> void:
	if ProductionConfig.PRIVACY_POLICY_URL != "":
		OS.shell_open(ProductionConfig.PRIVACY_POLICY_URL)

func _confirm_reset() -> void:
	_close_modal()
	_modal = Modals.confirm(overlay_root, "Reset progress?",
		"This permanently erases all coins, lives, stars, levels and settings on this device. It cannot be undone.",
		"YES, ERASE EVERYTHING", _do_reset)

func _do_reset() -> void:
	save.reset_all()
	audio.enabled = bool(save.data.sound)
	audio.voice_enabled = bool(save.data.voice)
	audio.set_music(bool(save.data.music))
	if world != null:
		world.set_auto_camera(bool(save.data.auto_camera))
	show_home()
	_toast("Progress reset")

# Hidden diagnostics viewer (Settings > tap Version 7 times).
func _show_diagnostics() -> void:
	_close_modal()
	var text := "=== PREVIOUS SESSION ===\n%s\n=== THIS SESSION ===\n%s" % [_prev_trail_text, _read_trail_file()]
	var ov := ColorRect.new()
	Ui.full_rect(ov)
	ov.color = Color(0.02, 0.02, 0.07, 0.98)
	overlay_root.add_child(ov)
	_modal = ov
	var pad := Ui.margin(ov, 40, 60 + int(Ui.inset_top), 40, 40 + int(Ui.inset_bottom))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	pad.add_child(box)
	box.add_child(Ui.label("DIAGNOSTICS", 46, Ui.GOLD, HORIZONTAL_ALIGNMENT_CENTER, true))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var log_label := Label.new()
	log_label.text = text
	log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_label.add_theme_font_size_override("font_size", 22)
	log_label.add_theme_color_override("font_color", Color("#9dffb0"))
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scroll.add_child(log_label)
	var copy := Ui.pill_button("COPY LOG", "purple", 120, 38)
	copy.pressed.connect(_copy_text.bind(text))
	box.add_child(copy)
	var close := Ui.glass_button("Close", Ui.GREY, 110, 36)
	close.pressed.connect(_close_modal)
	box.add_child(close)

func _copy_text(text: String) -> void:
	DisplayServer.clipboard_set(text)
	_toast("Log copied")

# ── Android back button ───────────────────────────────────────────────────────

func _handle_back() -> void:
	if is_instance_valid(_modal):
		if current_screen == UiScreen.GAME and game_status == GameData.Status.PAUSED:
			_pending_pu = ""
			_pause_resume()
		_close_modal()
		return
	match current_screen:
		UiScreen.GAME:
			if game_status == GameData.Status.PLAYING:
				show_pause()
		UiScreen.SHOP, UiScreen.REWARDS:
			_back_from_sub()
		UiScreen.LEVELS, UiScreen.SETTINGS, UiScreen.RESULT:
			show_home()
		UiScreen.HOME:
			var now := Time.get_ticks_msec()
			if now < _back_armed_until_ms:
				_trail(MARK_CLEAN)
				get_tree().quit()
			else:
				_back_armed_until_ms = now + 2000
				_toast("Press back again to exit")
		_:
			pass

# ── Rewarded videos and interstitials ────────────────────────────────────────

func _watch(kind: String) -> void:
	if platform.show_rewarded(kind):
		_toast("Watch the video to earn your reward")
	else:
		_toast("No video available right now. Try again in a moment.")

func _on_rewarded_cancelled() -> void:
	if _login_double_wait:
		_login_double_wait = false
		_do_claim_login(1)
		return
	if _chest_wait:
		_chest_wait = false
		_collect_chest()
		return
	if _pending_pu != "":
		_pu_cancel()
	_toast("Watch the whole video to get the reward")

func _on_rewarded_earned(kind: String) -> void:
	audio.play("coin")
	match kind:
		"hint":
			save.add_hints(ProductionConfig.REWARD_VIDEO_HINTS)
			_toast("+%d hint" % ProductionConfig.REWARD_VIDEO_HINTS)
			_refresh_shop()
		"life":
			save.add_life()
			_toast("+1 life")
			if current_screen == UiScreen.RESULT:
				_build_result(game_status == GameData.Status.WON)
			else:
				_refresh_shop()
		"moves":
			_resume_with_moves(ProductionConfig.REWARD_EXTRA_MOVES)
		"tube":
			_resume_lost("tube")
		"double":
			save.add_coins(coins_earned)
			coins_earned *= 2
			_doubled = true
			_toast("Coins doubled!")
			if current_screen == UiScreen.RESULT:
				_build_result(true)
		"pu_hint", "pu_moves", "pu_tube", "pu_crystal":
			var effect := kind.substr(3)
			_pending_pu = ""
			_pause_resume()
			_apply_powerup(effect)
		"login_double":
			_login_double_wait = false
			_do_claim_login(2)
		"chest_double":
			_chest_wait = false
			Rewards.grant(save, _chest_reward)
			_collect_chest()
		_:
			save.add_coins(ProductionConfig.REWARD_VIDEO_COINS)
			_toast("+%d coins" % ProductionConfig.REWARD_VIDEO_COINS)
			_refresh_shop()

# Interstitial (if pacing allows) and then start the level.
func _start_after_ad(id: int) -> void:
	var go := func(): start_level(id)
	if platform.try_interstitial(go):
		return
	go.call()

# ── GAME ──────────────────────────────────────────────────────────────────────

func _create_hud() -> void:
	hud = GameHud.new()
	_attach(hud)
	hud.setup()
	hud.pause_pressed.connect(show_pause)
	hud.hint_pressed.connect(_use_hint)
	hud.moves_pressed.connect(_open_powerup.bind("moves"))
	hud.tube_pressed.connect(_open_powerup.bind("tube"))
	hud.crystal_pressed.connect(_open_powerup.bind("crystal"))
	hud.voice_requested.connect(_on_voice)
	hud.avatar_poked.connect(_on_avatar_poked)
	hud.set_level_info(str(level_info.get("name", "")), level_info.get("twists", []))

# LevelGen is deterministic: the same id is always the same board.
func _load_level(id: int) -> void:
	current_level = id
	var t0 := Time.get_ticks_msec()
	level_info = LevelGen.build(id)
	caps = (level_info["caps"] as Array).duplicate()
	_trail("level %d built in %d ms: %d colours, %d tubes x%d, twists %s, par %d, budget %d" % [id,
		Time.get_ticks_msec() - t0, int(level_info["k"]), int(level_info["tubes"]),
		int(level_info["capacity"]), str(level_info["twists"]), int(level_info["par"]), int(level_info["budget"])])

func start_level(id: int) -> void:
	if not _world_ready:
		if _start_waiting:
			return
		_start_waiting = true
		_toast("Preparing the table...")
		while not _world_ready:
			await get_tree().process_frame
		_start_waiting = false
	_trail("===== start_level(%d) begin =====" % id)
	_load_level(id)
	# a little help after failed tries on the same level
	var bonus: int = mini(6, save.fail_count(id) * 2)
	moves = int(level_info["budget"]) + bonus
	score = 0
	combo = 0
	stars = 0
	coins_earned = 0
	_doubled = false
	_streak_bonus = 0
	_hints_used_level = 0
	_moves_made = 0
	_gold_collected = 0
	_best_chain = 0
	_boss_chest_due = false
	_idle_time = 0.0
	_idle_nudged = false
	_idle_sleepy = false
	_pending_pu = ""
	_pending_reveals = []
	_return_to_game = false
	_busy = false
	_level_token += 1
	selected = -1
	game_status = GameData.Status.PLAYING
	_enter(UiScreen.GAME)
	_create_hud()
	_make_board()
	_set_plan(level_info["solution"])
	world.calm()
	audio.play("ui_whoosh")
	_refresh_hud()
	_announce_level(bonus)
	if current_level == 1 and not bool(save.data.tutorial):
		_show_tutorial()
	else:
		_intro_twist_later()
	_trail("===== start_level(%d) complete =====" % id)
	_trail_after_draw("start_level(%d)" % id)

# Banner with the level, its theme and twists, plus a line from Cass.
func _announce_level(bonus: int) -> void:
	var twists: Array = level_info.get("twists", [])
	var boss: bool = bool(level_info.get("boss", false))
	var title := "BOSS LEVEL %d" % current_level if boss else "LEVEL %d" % current_level
	var sub := str(level_info["name"])
	var summary := Twists.summary(level_info)
	if summary != "":
		sub += "  -  " + summary
	hud.show_banner(title, Color("#ff5b8a") if boss else Color.WHITE, sub, Color("#c9d2ff"), 1.5)
	var line: String = GREETINGS[randi() % GREETINGS.size()]
	var mood := "wave"
	if boss:
		line = Twists.cass_line("boss")
		mood = "point"
	elif not twists.is_empty():
		line = Twists.cass_line(str(twists[0]))
		mood = "point"
	hud.say(line, mood, "hello")
	if bonus > 0:
		_toast("Cass added +%d moves to help" % bonus)

# The first time a twist appears, a short introduction (after the camera intro).
func _intro_twist_later() -> void:
	var twists: Array = level_info.get("twists", [])
	var fresh := ""
	for t in twists:
		if not save.twist_seen(str(t)):
			fresh = str(t)
			break
	if fresh == "":
		return
	var token := _level_token
	await get_tree().create_timer(1.8).timeout
	if token != _level_token or current_screen != UiScreen.GAME or game_status != GameData.Status.PLAYING or is_instance_valid(_modal):
		return
	save.mark_twist_seen(fresh)
	_trail("twist intro: " + fresh)
	game_status = GameData.Status.PAUSED
	_close_modal()
	_modal = Modals.twist_intro(overlay_root, Twists.title_of(fresh), Twists.text_of(fresh), Twists.color_of(fresh), _pause_resume)

func _make_board() -> void:
	_trail("_make_board begin")
	tubes.clear()
	for t in (level_info["board"] as Array):
		tubes.append((t as Array).duplicate())
	caps = (level_info["caps"] as Array).duplicate()
	var cap: int = int(level_info["capacity"])
	_trail("_make_board: %d tubes, capacity %d, %d crystals" % [tubes.size(), cap, Rules.count_crystals(tubes)])
	world.apply_theme(int(level_info["theme"]))
	world.arrange(tubes.size(), cap, true)
	_connect_tubes()
	_sync_visuals()
	_trail("_make_board complete")

func _connect_tubes() -> void:
	var count := world.tubes_root.get_child_count()
	for i in range(count):
		var tube := world.get_tube(i)
		if tube and not tube.tapped.is_connected(_on_tube_tapped):
			tube.tapped.connect(_on_tube_tapped)

# Colour name of a crystal value (the level's palette maps colour index -> name).
func _color_name(v: int) -> String:
	var pal: Array = level_info["palette"]
	var idx: int = v & 15
	if idx >= pal.size():
		return "white"
	return str(GameData.COLORS[int(pal[idx])])

func _crystal_color(v: int) -> Color:
	var cname := _color_name(v)
	if GameData.COLOR_HEX.has(cname):
		return GameData.COLOR_HEX[cname]
	return Color(1.0, 0.85, 0.35)

# A shadow crystal that reaches the top of its tube shows its colour for good.
func _reveal_tops() -> void:
	for i in range(tubes.size()):
		var t: Array = tubes[i]
		if t.is_empty():
			continue
		var v: int = int(t[t.size() - 1])
		if (v & Rules.F_HIDDEN) != 0:
			t[t.size() - 1] = v & (~Rules.F_HIDDEN)
			_pending_reveals.append([i, t.size() - 1])
			_trail("shadow crystal revealed: tube %d slot %d" % [i, t.size() - 1])

# Old crystals leave the tree at once but are freed with queue_free(): freeing
# the crystal whose tap signal is still being delivered is a use-after-free.
func _sync_visuals() -> void:
	_reveal_tops()
	var cap: int = int(level_info["capacity"])
	var sel_color := Color(1.0, 0.85, 0.35)
	if selected >= 0 and selected < tubes.size() and not tubes[selected].is_empty():
		var st: Array = tubes[selected]
		sel_color = _crystal_color(int(st[st.size() - 1]))
	for i in range(tubes.size()):
		var tube_node := world.get_tube(i)
		if tube_node == null:
			continue
		for child in tube_node.get_children():
			if child is Crystal3D:
				tube_node.remove_child(child)
				child.queue_free()
		var values: Array = tubes[i]
		for j in range(values.size()):
			var v: int = int(values[j])
			var gem := Crystal3D.new()
			gem.setup(_color_name(v), Vector3(0, Tube3D.slot_y(cap, j), 0), float(i * 17 + j), j, v & (Rules.F_HIDDEN | Rules.F_GOLD))
			gem.tapped.connect(_on_crystal_tapped.bind(i))
			tube_node.add_child(gem)
			if i == selected and j == values.size() - 1:
				gem.set_selected(true)
			if _pending_reveals.has([i, j]):
				gem.play_reveal()
		# the glow takes the colour of the crystal that is about to move
		if i == selected:
			tube_node.set_highlight(true, sel_color)
		elif selected >= 0 and Rules.can_move(tubes, caps, selected, i):
			tube_node.set_target(true, sel_color)
		else:
			tube_node.set_highlight(false)
	_pending_reveals = []
	_trail("sync: %d tubes, %d crystals" % [tubes.size(), Rules.count_crystals(tubes)])

func _on_crystal_tapped(_crystal: Crystal3D, tube_index: int) -> void:
	_on_tube_tapped(tube_index)

func _refresh_hud() -> void:
	if hud != null:
		hud.update_stats(current_level, moves, score, int(save.data.coins), int(save.data.hints))

# Drag on the table to take over the camera (taps are filtered in TapFilter, so a
# drag that starts on a tube never selects it). Auto camera resumes afterwards.
func _unhandled_input(event: InputEvent) -> void:
	if world == null or current_screen != UiScreen.GAME or game_status != GameData.Status.PLAYING:
		return
	if event is InputEventScreenDrag:
		world.orbit_drag(event.relative)
	elif event is InputEventMouseMotion and not DisplayServer.is_touchscreen_available():
		if (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			world.orbit_drag(event.relative)

func _process(delta: float) -> void:
	if current_screen == UiScreen.GAME and game_status == GameData.Status.PLAYING and hud != null and not _busy:
		_idle_time += delta
		if _idle_time > NUDGE_AFTER and not _idle_nudged:
			_idle_nudged = true
			_cass("Stuck? Tap HINT for help!", "think", "think")
		elif _idle_time > SLEEPY_AFTER and not _idle_sleepy:
			_idle_sleepy = true
			_cass(SLEEPY[randi() % SLEEPY.size()], "sleepy", "")

# Cass: speech bubble + body/face reaction + optional voice line.
func _cass(text: String, mood: String, voice: String = "") -> void:
	if hud != null:
		hud.say(text, mood, voice)

func _on_voice(kind: String) -> void:
	var length := audio.play_voice(kind)
	if length > 0.0 and hud != null:
		hud.avatar.speak(length)

func _on_avatar_poked() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_poke_ms < 1200 or hud == null:
		return
	_last_poke_ms = now
	_idle_time = 0.0
	_idle_sleepy = false
	_cass(POKES[randi() % POKES.size()], "wave", "giggle")

func _glow_for(tube_index: int) -> void:
	if hud == null or tubes[tube_index].is_empty():
		return
	var t: Array = tubes[tube_index]
	hud.avatar.set_glow(_crystal_color(int(t[t.size() - 1])))

# Runs inside the physics-picking signal: just defer.
func _on_tube_tapped(index: int) -> void:
	_handle_tap.call_deferred(index)

func _handle_tap(index: int) -> void:
	if game_status != GameData.Status.PLAYING or hud == null or _busy:
		return
	if index < 0 or index >= tubes.size():
		return
	_trail("tap tube %d (selected %d)" % [index, selected])
	_idle_time = 0.0
	_idle_nudged = false
	_idle_sleepy = false
	if selected == -1:
		if not tubes[index].is_empty():
			selected = index
			world.focus_on_tube(index)
			_glow_for(index)
			hud.avatar.look_at_screen(world.tube_screen_pos(index))
			audio.play("tap")
			if randi() % 4 == 0:
				_cass(PICKS[randi() % PICKS.size()], "think", "hmm" if randi() % 2 == 0 else "")
	elif selected == index:
		selected = -1
		world.release_focus()
		audio.play("tap")
	else:
		_move_gem(selected, index)
	_sync_visuals()
	_refresh_hud()

# no_cost: the auto-played hint does not use up a move.
func _move_gem(from_i: int, to_i: int, no_cost: bool = false) -> void:
	if not Rules.can_move(tubes, caps, from_i, to_i):
		_invalid_move()
		return
	_trail("move %d -> %d%s" % [from_i, to_i, " (hint)" if no_cost else ""])
	world.cam_move(from_i, to_i)
	world.pulse_camera(0.10)
	hud.avatar.look_at_screen(world.tube_screen_pos(to_i))
	var events: Array = Rules.apply_move(tubes, from_i, to_i)
	if not no_cost:
		moves -= 1
		score += 10
		_moves_made += 1
	selected = -1
	audio.play("tap")
	hud.avatar.react("happy")
	_on_clears(events)
	if events.is_empty() and not no_cost and game_status == GameData.Status.PLAYING and moves <= 3 and moves > 0:
		_cass(LOW[randi() % LOW.size()], "sad", "sigh")
	_check_win_condition()

func _invalid_move() -> void:
	selected = -1
	world.release_focus()
	world.pulse_camera(0.22)
	_cass(OOPS[randi() % OOPS.size()], "angry", "oops" if randi() % 2 == 0 else "nope")
	audio.play("tap")
	_vibrate(40)

# Everything a move (or a conjured crystal) cleared: rewards, effects, Cass.
# Several clears in one move are a cascade; matching on consecutive moves is a combo.
func _on_clears(events: Array) -> void:
	if events.is_empty():
		combo = 0
		return
	_trail("clears x%d, combo %d" % [events.size(), combo + 1])
	_spawn_pops(events)
	var chain: int = events.size()
	combo += 1
	_best_chain = maxi(_best_chain, chain)
	var coins_now := 0
	var gold_now := 0
	var first_pos := Vector2.ZERO
	for k in range(events.size()):
		var ev: Array = events[k]
		var ti: int = int(ev[0])
		var golds: int = int(ev[2])
		coins_now += MATCH_COINS + GOLD_COINS * golds
		gold_now += golds
		score += 50 * combo + 100 * golds
		world.cam_match(ti)
		world.burst(ti, _crystal_color(int(ev[1])))
		save.data.total_matches = int(save.data.total_matches) + 3
		save.quest_add("match", 3)
		if k == 0:
			first_pos = world.tube_screen_pos(ti)
	if chain >= 2:
		coins_now += 5 * (chain - 1)
		score += 100 * (chain - 1)
	if combo >= 3:
		coins_now += combo
	save.add_coins(coins_now)
	coins_earned += coins_now
	_gold_collected += gold_now
	if gold_now > 0:
		save.quest_add("gold", gold_now)
	if chain >= 2:
		save.quest_add("cascade", 1)
	if combo == 3 or chain >= 3:
		save.quest_add("combo", 1)
	audio.play("match")
	world.pulse_camera(0.16 + 0.06 * float(chain - 1))
	_vibrate(25 + 15 * chain)
	if hud != null:
		hud.float_text("+%d" % coins_now, first_pos, Ui.GOLD)
		if gold_now > 0:
			hud.float_text("GOLD x%d" % gold_now, first_pos + Vector2(0, -90), Color("#ffd34e"))
	if chain >= 2:
		var casc_msg: String = CASCADES[randi() % CASCADES.size()]
		if hud != null:
			hud.show_banner("CASCADE x%d!" % chain, Color("#ff944d"))
		_cass(casc_msg, "dance", "wow")
		audio.play("streak_up")
	elif combo >= 3:
		if hud != null:
			hud.show_banner("COMBO x%d!" % combo, Color("#ffb347"))
		_cass("COMBO x%d!  +%d" % [combo, combo], "dance", "wow")
		audio.play("streak_up")
	elif combo == 2:
		_cass(DOUBLES[randi() % DOUBLES.size()], "cheer", "cheer")
	elif gold_now > 0:
		_cass("Golden! +%d coins" % (GOLD_COINS * gold_now), "thumbs", "yay")
	else:
		_cass(CHEERS[randi() % CHEERS.size()], "cheer", "yay")

# The cleared crystals pop where they stood (the board itself is rebuilt from
# `tubes`, so the pop crystals live in their own node that survives the rebuild).
func _spawn_pops(events: Array) -> void:
	var cap: int = int(level_info["capacity"])
	var per_tube: Dictionary = {}
	for ev in events:
		var ti: int = int(ev[0])
		if not per_tube.has(ti):
			per_tube[ti] = []
		per_tube[ti].append(ev)
	for key in per_tube.keys():
		var ti2: int = int(key)
		var list: Array = per_tube[key]
		var tube_node := world.get_tube(ti2)
		if tube_node == null:
			continue
		var fx := Node3D.new()
		tube_node.add_child(fx)
		var final_size: int = tubes[ti2].size()
		var n: int = list.size()
		for k in range(n):
			var ev2: Array = list[k]
			var base_slot: int = final_size + 3 * (n - 1 - k)
			var cname := _color_name(int(ev2[1]))
			var golds: int = int(ev2[2])
			for q in range(3):
				var gem := Crystal3D.new()
				var flags: int = Rules.F_GOLD if q < golds else 0
				gem.setup(cname, Vector3(0, Tube3D.slot_y(cap, base_slot + q), 0), float(q), base_slot + q, flags)
				fx.add_child(gem)
				gem.play_match_pop()
		get_tree().create_timer(0.7).timeout.connect(fx.queue_free)

# Leftovers that can never match (only after a conjured crystal) fade away.
func _dissolve_leftovers() -> void:
	var cap: int = int(level_info["capacity"])
	var any := false
	for i in range(tubes.size()):
		var t: Array = tubes[i]
		if t.is_empty():
			continue
		any = true
		var tube_node := world.get_tube(i)
		if tube_node != null:
			var fx := Node3D.new()
			tube_node.add_child(fx)
			for j in range(t.size()):
				var gem := Crystal3D.new()
				gem.setup(_color_name(int(t[j])), Vector3(0, Tube3D.slot_y(cap, j), 0), float(j), j, 0)
				fx.add_child(gem)
				gem.play_match_pop()
			get_tree().create_timer(0.7).timeout.connect(fx.queue_free)
		t.clear()
	if any:
		_sync_visuals()

func _check_win_condition() -> void:
	if game_status != GameData.Status.PLAYING:
		return
	if Rules.is_cleared(tubes):
		_win()
	elif moves <= 0:
		_lose("moves")
	elif not Rules.any_move(tubes, caps):
		_lose("stuck")

func _win() -> void:
	_trail("level %d won" % current_level)
	game_status = GameData.Status.WON
	_dissolve_leftovers()
	var t3: int = int(level_info["star3"])
	var t2: int = int(level_info["star2"])
	stars = 3 if _moves_made <= t3 else (2 if _moves_made <= t2 else 1)
	score += moves * 20
	var first_clear: bool = int(save.level(current_level).get("stars", 0)) == 0
	_boss_chest_due = first_clear and bool(level_info.get("boss", false))
	save.set_level(current_level, stars, score)
	save.clear_fail(current_level)
	save.add_coins(LEVEL_COMPLETE_COINS)
	coins_earned += LEVEL_COMPLETE_COINS
	var streak := save.record_win()
	_streak_bonus = 0
	if streak >= 2:
		_streak_bonus = mini(5 * streak, 25)
		save.add_coins(_streak_bonus)
		coins_earned += _streak_bonus
	save.quest_add("win", 1)
	save.quest_add("stars", stars)
	if stars == 3:
		save.quest_add("perfect", 1)
	if _hints_used_level == 0:
		save.quest_add("nohint", 1)
	platform.level_finished()
	audio.play("victory")
	_cass("We did it!", "dance", "cheer")
	world.celebrate()
	_vibrate(60)
	_show_result(true)

func _lose(reason: String) -> void:
	_trail("level %d lost: %s" % [current_level, reason])
	game_status = GameData.Status.LOST
	_lose_reason = reason
	save.record_loss()
	save.add_fail(current_level)
	platform.level_finished()
	audio.play("gameover")
	if reason == "stuck":
		_cass(STUCK[randi() % STUCK.size()], "shrug", "hmm")
	else:
		_cass("Oh no...", "sad", "oh_no")
	world.defeat()
	_show_result(false)

# ── HINT: plays the best move itself ──────────────────────────────────────────

# No popup: a stored hint is used first, then coins. When both are gone, offer a
# video, the shop or the daily tasks. The move is then played automatically and
# does not cost one of the level's moves.
func _use_hint() -> void:
	if game_status != GameData.Status.PLAYING or hud == null or _busy:
		return
	var has_hint: bool = int(save.data.hints) > 0
	if not has_hint and int(save.data.coins) < HINT_COST:
		_offer_more_hints()
		return
	var mv: Array = _hint_move()
	if mv.is_empty():
		_toast("No helpful move right now. Try an extra tube!")
		return
	if has_hint:
		save.use_hint()
	else:
		save.spend_coins(HINT_COST)
	_hints_used_level += 1
	_trail("hint: %d -> %d" % [int(mv[0]), int(mv[1])])
	_run_hint(mv)

# The next move of the current plan, or a fresh search when the player went their own way.
func _hint_move() -> Array:
	var key: int = Solver.key_exact(tubes)
	var pos: int = _plan_keys.find(key)
	if pos >= 0 and pos < _plan.size():
		var pm: Array = _plan[pos]
		if Rules.can_move(tubes, caps, int(pm[0]), int(pm[1])):
			return [int(pm[0]), int(pm[1])]
	var sol: Array = Solver.solve(tubes, caps, 14, 5000, 280)
	if not sol.is_empty():
		_set_plan(sol)
		var first: Array = _plan[0]
		return [int(first[0]), int(first[1])]
	return Solver.best_effort(tubes, caps)

func _set_plan(sol: Array) -> void:
	_plan = sol.duplicate(true)
	_plan_keys = []
	var t: Array = tubes.duplicate(true)
	for mv in _plan:
		if not Rules.can_move(t, caps, int(mv[0]), int(mv[1])):
			break
		_plan_keys.append(Solver.key_exact(t))
		Rules.apply_move(t, int(mv[0]), int(mv[1]))

func _run_hint(mv: Array) -> void:
	var from_i: int = int(mv[0])
	var to_i: int = int(mv[1])
	_busy = true
	var token := _level_token
	hud.set_boosters_enabled(false)
	selected = from_i
	world.cam_hint(to_i)
	world.focus_on_tube(from_i)
	_glow_for(from_i)
	hud.avatar.look_at_screen(world.tube_screen_pos(to_i))
	_cass("Watch this!", "point", "hmm")
	_sync_visuals()
	_refresh_hud()
	await get_tree().create_timer(0.7).timeout
	if token != _level_token:
		return
	_busy = false
	if hud == null or game_status != GameData.Status.PLAYING:
		return
	hud.set_boosters_enabled(true)
	_move_gem(from_i, to_i, true)
	_sync_visuals()
	_refresh_hud()

# Out of hints (and coins): a video, the shop or a daily task.
func _offer_more_hints() -> void:
	game_status = GameData.Status.PAUSED
	_pending_pu = "hint"
	_close_modal()
	_modal = Modals.get_more(overlay_root, "bulb", Color("#ffe14d"), "OUT OF HINTS",
		"A hint plays the best move for you. Get more:", "WATCH VIDEO: FREE HINT",
		platform.is_rewarded_ready(), _pu_watch, _open_sub_from_game.bind("shop"),
		_open_sub_from_game.bind("rewards"), _pu_cancel)

# Shop / daily tasks opened from a level: Back returns to the very same level.
func _open_sub_from_game(kind: String) -> void:
	_close_modal()
	_pending_pu = ""
	_return_to_game = true
	if kind == "shop":
		show_shop()
	else:
		show_rewards()

func _back_from_sub() -> void:
	if _return_to_game and not tubes.is_empty() and game_status != GameData.Status.WON and game_status != GameData.Status.LOST:
		_return_to_game = false
		_resume_game_view()
	else:
		_return_to_game = false
		show_home()

func _resume_game_view() -> void:
	game_status = GameData.Status.PLAYING
	_busy = false
	_idle_time = 0.0
	_idle_nudged = false
	selected = -1
	_enter(UiScreen.GAME)
	_create_hud()
	_sync_visuals()
	_refresh_hud()
	_cass("Welcome back!", "wave", "hello")

# ── Power-ups: +MOVES, +TUBE and +CRYSTAL ask "use coins or watch a video" ───

func _open_powerup(kind: String) -> void:
	if game_status != GameData.Status.PLAYING or hud == null or _busy:
		return
	if kind == "tube" and tubes.size() >= MAX_TUBES:
		_toast("Maximum %d tubes" % MAX_TUBES)
		return
	if kind == "crystal" and _crystal_target().is_empty():
		_toast("No room for a crystal right now")
		return
	var icon_name := "moves"
	var accent := Ui.PINK
	var title := ""
	var desc := ""
	var coin_text := ""
	var cost := 0
	match kind:
		"moves":
			title = "Out of moves?"
			desc = "+%d moves keep you in the game." % ProductionConfig.REWARD_EXTRA_MOVES
			cost = EXTRA_MOVES_COST
			coin_text = "Use %d coins" % cost
		"tube":
			icon_name = "tube"
			accent = Ui.BLUE
			title = "Add an extra tube?"
			desc = "A fresh, full-size empty tube gives you room to sort."
			cost = EXTRA_TUBE_COST
			coin_text = "Use %d coins" % cost
		"crystal":
			icon_name = "diamond"
			accent = Ui.GREEN
			title = "Conjure a crystal?"
			desc = "Cass adds a crystal that finishes a pair, so it clears at once."
			cost = CRYSTAL_COST
			coin_text = "Use %d coins" % cost
	var can_pay := cost <= 0 or int(save.data.coins) >= cost
	game_status = GameData.Status.PAUSED
	_pending_pu = kind
	_close_modal()
	_modal = Modals.powerup(overlay_root, icon_name, accent, title, desc, coin_text,
		cost > 0, can_pay, platform.is_rewarded_ready(), _pu_coins, _pu_watch, _pu_cancel)

func _pu_cancel() -> void:
	_pending_pu = ""
	_pause_resume()

func _pu_coins() -> void:
	var kind := _pending_pu
	_pending_pu = ""
	var ok := false
	match kind:
		"moves":
			ok = save.spend_coins(EXTRA_MOVES_COST)
		"tube":
			ok = save.spend_coins(EXTRA_TUBE_COST)
		"crystal":
			ok = save.spend_coins(CRYSTAL_COST)
	_pause_resume()
	if ok:
		_apply_powerup(kind)
	else:
		_toast("Not enough coins. Watch a video instead!")

func _pu_watch() -> void:
	var kind := _pending_pu
	if not platform.show_rewarded("pu_" + kind):
		_pending_pu = ""
		_pause_resume()
		_toast("No video available right now. Try coins!")

func _apply_powerup(kind: String) -> void:
	match kind:
		"hint":
			var mv: Array = _hint_move()
			if mv.is_empty():
				_toast("No helpful move right now. Try an extra tube!")
			else:
				_hints_used_level += 1
				_run_hint(mv)
		"moves":
			moves += ProductionConfig.REWARD_EXTRA_MOVES
			_refresh_hud()
			_cass("+%d moves!" % ProductionConfig.REWARD_EXTRA_MOVES, "cheer", "yay")
		"tube":
			_add_tube()
		"crystal":
			_apply_crystal()

# New tubes are appended at the end of the layout, always with the full capacity
# of the level; existing tubes glide to their new places and the new one drops in
# (see BoardLayout / GameWorld.arrange).
func _add_tube() -> void:
	if tubes.size() >= MAX_TUBES:
		_toast("Maximum %d tubes" % MAX_TUBES)
		return
	var cap: int = int(level_info["capacity"])
	_trail("add tube (now %d)" % (tubes.size() + 1))
	var old_positions := world.tube_positions()
	tubes.append([])
	caps.append(cap)
	world.arrange(tubes.size(), cap, false, old_positions)
	_connect_tubes()
	_sync_visuals()
	_refresh_hud()
	audio.play("tube_drop")
	_cass("A fresh tube!", "cheer", "wow")

# Where a conjured crystal helps most: a pair it turns into a match, otherwise a
# single it turns into a pair. Returns [tube, colour] or [] when nothing has room.
func _crystal_target() -> Array:
	var best: Array = []
	var best_score: int = -1
	for i in range(tubes.size()):
		var t: Array = tubes[i]
		if t.is_empty() or t.size() >= int(caps[i]):
			continue
		var run: int = Rules.top_run(t)
		if run != 1 and run != 2:
			continue
		var c: int = int(t[t.size() - 1]) & 15
		var sc: int = Rules.count_color(tubes, c)
		if run == 2:
			sc += 100
		if sc > best_score:
			best_score = sc
			best = [i, c]
	return best

func _top_gem(tube_index: int) -> Crystal3D:
	var node := world.get_tube(tube_index)
	if node == null:
		return null
	var kids := node.get_children()
	for k in range(kids.size() - 1, -1, -1):
		if kids[k] is Crystal3D:
			return kids[k] as Crystal3D
	return null

func _apply_crystal() -> void:
	var tgt: Array = _crystal_target()
	if tgt.is_empty():
		_toast("No room for a crystal right now")
		return
	var ti: int = int(tgt[0])
	var c: int = int(tgt[1])
	_trail("crystal conjured on tube %d" % ti)
	_busy = true
	var token := _level_token
	tubes[ti].append(c)
	_sync_visuals()
	var gem := _top_gem(ti)
	if gem != null:
		gem.play_spawn()
	audio.play("tube_drop")
	_cass("A little sparkle!", "wink", "wow")
	await get_tree().create_timer(0.55).timeout
	if token != _level_token:
		return
	var events: Array = Rules.resolve_tube(tubes, ti)
	_on_clears(events)
	_sync_visuals()
	_refresh_hud()
	_busy = false
	_check_win_condition()

# ── Pause / tutorial ──────────────────────────────────────────────────────────

func show_pause() -> void:
	if game_status != GameData.Status.PLAYING or _busy:
		return
	game_status = GameData.Status.PAUSED
	_close_modal()
	_modal = Modals.pause(overlay_root, _pause_resume, _restart_level, show_levels, show_home)

func _restart_level() -> void:
	start_level(current_level)

func _pause_resume() -> void:
	if game_status == GameData.Status.PAUSED:
		game_status = GameData.Status.PLAYING
		_idle_time = 0.0

func _show_tutorial() -> void:
	_close_modal()
	_modal = Modals.tutorial(overlay_root, _close_tutorial)

func _close_tutorial() -> void:
	save.data.tutorial = true
	save.save()

# ── Result ────────────────────────────────────────────────────────────────────

func _show_result(won: bool) -> void:
	await get_tree().create_timer(2.0 if won else 1.2).timeout
	var expected := GameData.Status.WON if won else GameData.Status.LOST
	if game_status != expected:
		return
	_build_result(won)
	if won:
		_maybe_offer_chest()

func _build_result(won: bool) -> void:
	_trail("result screen (won=%s)" % str(won))
	_enter(UiScreen.RESULT)
	save.refresh_lives()
	var s := ResultScreen.new()
	_attach(s)
	var can_watch := platform.is_rewarded_ready() and not (won and _doubled)
	var nxt: Dictionary = LevelGen.spec(current_level + 1)
	s.setup({
		"won": won,
		"reason": _lose_reason,
		"stars": stars,
		"score": score,
		"coins_earned": coins_earned,
		"lives": int(save.data.lives),
		"extra_moves_cost": EXTRA_MOVES_COST,
		"extra_tube_cost": EXTRA_TUBE_COST,
		"tube_available": tubes.size() < MAX_TUBES,
		"rewarded_ready": can_watch,
		"total_coins": int(save.data.coins),
		"win_streak": int(save.data.win_streak),
		"streak_bonus": _streak_bonus,
		"level": current_level,
		"theme_name": str(level_info.get("name", "")),
		"gold": _gold_collected,
		"cascades": _best_chain,
		"chest_in": save.wins_to_chest(),
		"boss": bool(level_info.get("boss", false)),
		"next_level": current_level + 1,
		"next_twists": nxt.get("twists", []),
		"next_boss": bool(nxt.get("boss", false)),
	})
	s.next_pressed.connect(func(): _start_after_ad(current_level + 1))
	s.replay_pressed.connect(func(): _start_after_ad(current_level))
	s.retry_pressed.connect(_retry_with_life)
	s.levels_pressed.connect(show_levels)
	s.home_pressed.connect(show_home)
	s.extra_moves_pressed.connect(_buy_extra_moves)
	s.free_moves_pressed.connect(_watch.bind("moves"))
	s.extra_tube_pressed.connect(_buy_extra_tube)
	s.free_tube_pressed.connect(_watch.bind("tube"))
	s.double_coins_pressed.connect(_watch.bind("double"))
	s.watch_life_pressed.connect(_watch.bind("life"))

func _retry_with_life() -> void:
	if save.use_life():
		_start_after_ad(current_level)
	else:
		_show_no_lives()

func _show_no_lives() -> void:
	_close_modal()
	_modal = Modals.no_lives(overlay_root, Ui.format_duration(save.seconds_to_next_life()),
		platform.is_rewarded_ready(), _watch.bind("life"), Callable())

func _buy_extra_moves() -> void:
	if save.spend_coins(EXTRA_MOVES_COST):
		_resume_with_moves(ProductionConfig.REWARD_EXTRA_MOVES)
	else:
		_toast("You need %d coins" % EXTRA_MOVES_COST)

func _buy_extra_tube() -> void:
	if save.spend_coins(EXTRA_TUBE_COST):
		_resume_lost("tube")
	else:
		_toast("You need %d coins" % EXTRA_TUBE_COST)

func _resume_with_moves(count: int) -> void:
	_resume_lost("moves", count)

# Continue a lost level (the board is still in place) with extra moves or an extra tube.
func _resume_lost(kind: String, count: int = 0) -> void:
	if current_screen != UiScreen.RESULT or game_status != GameData.Status.LOST:
		if game_status == GameData.Status.PLAYING or game_status == GameData.Status.PAUSED:
			if kind == "moves":
				moves += count
				_refresh_hud()
		return
	if kind == "moves":
		moves += count
	game_status = GameData.Status.PLAYING
	_busy = false
	_idle_time = 0.0
	_idle_nudged = false
	_enter(UiScreen.GAME)
	_create_hud()
	world.calm()
	if kind == "tube":
		_add_tube()
	else:
		_sync_visuals()
		_cass("Back in the game!", "cheer", "yay")
	_refresh_hud()

# ── Toast ─────────────────────────────────────────────────────────────────────

func _toast(msg: String) -> void:
	if overlay_root == null or not is_inside_tree():
		return
	if is_instance_valid(_toast_node):
		_toast_node.queue_free()
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", Ui.flat(Color(0.05, 0.07, 0.22, 0.96), 40, Color(0.5, 0.6, 1.0, 0.45), 2, 34, 22))
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 60
	panel.offset_right = -60
	panel.offset_top = -380
	panel.offset_bottom = -300
	var l := Ui.label(msg, 34, Color.WHITE)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(l)
	overlay_root.add_child(panel)
	_toast_node = panel
	var tw := panel.create_tween()
	tw.tween_interval(1.9)
	tw.tween_property(panel, "modulate:a", 0.0, 0.35)
	tw.tween_callback(panel.queue_free)
