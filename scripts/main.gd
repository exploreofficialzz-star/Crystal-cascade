extends Node3D

# Game orchestrator: launch sequence, navigation, game rules, power-ups, retention
# systems and the glue between screens, the 3D world, ads and purchases.
# Screens live in scripts/screens, widgets in scripts/ui, the ad/billing bridge
# in scripts/services/android_platform.gd.

const HINT_COST := 40
const EXTRA_MOVES_COST := 30
const EXTRA_TUBE_COST := 100
const LEVEL_COMPLETE_COINS := 5
const MAX_TUBES := 10
const NUDGE_AFTER := 14.0
const MIN_SPLASH_MS := 2600

const CHEERS := ["Nice one!", "Sparkling!", "Great match!", "Crystal clear!", "You got it!", "Brilliant!"]
const OOPS := ["Hmm, not there.", "Try another tube!", "Careful now!"]
const PICKS := ["Good choice.", "Where to?", "Ooh, that one."]
const LOW := ["Only a few moves left!", "Think carefully!"]
const GREETINGS := ["Let's go!", "You can do it!", "Ready when you are!"]
const POKES := ["Hehe, that tickles!", "Hi there!", "Need me?", "Let's play!"]

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
var splash: SplashScreen = null

var current_screen: UiScreen = UiScreen.NONE
var game_status := GameData.Status.IDLE
var current_level := 1
var level_info: Dictionary = {}
var tubes: Array = []
var selected := -1
var hint_destination := -1
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
var _pending_pu := ""
var _chest_reward: Dictionary = {}
var _chest_wait := false
var _login_double_wait := false
var _modal: Control = null
var _toast_node: Control = null
var _banner_reserve := 0
var _back_armed_until_ms := 0
var _last_poke_ms := 0

# ── Crash trail (diagnostics) ─────────────────────────────────────────────────
# Every risky step is written to a small file and flushed immediately. Hidden in
# production: in Settings tap "Version" 7 times to open the viewer. Set
# SHOW_CRASH_TRAIL to true to show the previous run's trail automatically.
const SHOW_CRASH_TRAIL := false
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
	splash = SplashScreen.new()
	overlay_root.add_child(splash)
	splash.setup()
	await get_tree().process_frame
	await _boot(crashed)
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

# Preloads art and sound, builds the 3D world, starts the ad/billing plugins and
# warms up the shaders behind the splash screen, then reveals the home screen.
func _boot(crashed: bool) -> void:
	var t0 := Time.get_ticks_msec()
	splash.set_progress(0.04, "Polishing crystals…")
	var paths := _asset_paths()
	for i in range(paths.size()):
		Ui.tex(paths[i])
		if i % 8 == 7:
			splash.set_progress(0.04 + 0.30 * float(i) / float(paths.size()), "Polishing crystals…")
			await get_tree().process_frame
	splash.set_progress(0.36, "Tuning the sounds…")
	for i in range(audio.preload_count()):
		audio.preload_one(i)
		if i % 5 == 4:
			await get_tree().process_frame
	splash.set_progress(0.50, "Building the table…")
	await get_tree().process_frame
	world = GameWorld.new()
	add_child(world)
	world.build()
	world.set_active(false)
	world.set_auto_camera(bool(save.data.auto_camera))
	_trail("world.build() returned")
	splash.set_progress(0.62, "Connecting…")
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
	platform.setup(save)
	await get_tree().process_frame
	splash.set_progress(0.72, "Waking Cass…")
	await _warm_up()
	splash.set_progress(1.0, "Ready!")
	while Time.get_ticks_msec() - t0 < MIN_SPLASH_MS or not splash.is_done():
		await get_tree().process_frame
	audio.set_music(bool(save.data.music))
	show_home()
	splash.fade_out()
	splash = null
	audio.play_voice("hello")
	if crashed and SHOW_CRASH_TRAIL:
		_show_diagnostics()
	else:
		await get_tree().create_timer(0.7).timeout
		_maybe_show_daily_login()

# Draws one real board and one avatar frame behind the splash so every shader is
# compiled before the first level (otherwise the first level start stutters).
func _warm_up() -> void:
	var avatar := AvatarPortrait.new()
	avatar.modulate = Color(1, 1, 1, 0.02)
	overlay_root.add_child(avatar)
	overlay_root.move_child(avatar, 0)
	current_level = 1
	level_info = GameData.level_info(1)
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
	s.back_pressed.connect(show_home)
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
	s.back_pressed.connect(show_home)
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

# ── Treasure chest (every 3rd win) ───────────────────────────────────────────

func _roll_chest() -> Dictionary:
	var r := randf()
	if r < 0.6:
		return {"type": "coins", "amount": 40 + 10 * (randi() % 7)}
	if r < 0.85:
		return {"type": "hints", "amount": 2}
	return {"type": "lives", "amount": 1}

func _maybe_offer_chest() -> void:
	if not save.chest_ready():
		return
	await get_tree().create_timer(1.0).timeout
	if current_screen != UiScreen.RESULT or game_status != GameData.Status.WON or is_instance_valid(_modal):
		return
	_chest_reward = _roll_chest()
	audio.play("chest_open")
	_modal = Modals.chest(overlay_root, Rewards.describe(_chest_reward),
		Rewards.icon_for(str(_chest_reward["type"])), platform.is_rewarded_ready(), _collect_chest, _double_chest)

func _collect_chest() -> void:
	Rewards.grant(save, _chest_reward)
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
		UiScreen.LEVELS, UiScreen.SHOP, UiScreen.REWARDS, UiScreen.SETTINGS, UiScreen.RESULT:
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
		"double":
			save.add_coins(coins_earned)
			coins_earned *= 2
			_doubled = true
			_toast("Coins doubled!")
			if current_screen == UiScreen.RESULT:
				_build_result(true)
		"pu_hint", "pu_moves", "pu_tube":
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
	hud.hint_pressed.connect(_open_powerup.bind("hint"))
	hud.moves_pressed.connect(_open_powerup.bind("moves"))
	hud.tube_pressed.connect(_open_powerup.bind("tube"))
	hud.voice_requested.connect(_on_voice)
	hud.avatar_poked.connect(_on_avatar_poked)

func start_level(id: int) -> void:
	_trail("===== start_level(%d) begin =====" % id)
	current_level = id
	level_info = GameData.level_info(id)
	moves = int(level_info.moves)
	score = 0
	combo = 0
	stars = 0
	coins_earned = 0
	_doubled = false
	_streak_bonus = 0
	_hints_used_level = 0
	_idle_time = 0.0
	_idle_nudged = false
	_pending_pu = ""
	selected = -1
	hint_destination = -1
	game_status = GameData.Status.PLAYING
	_enter(UiScreen.GAME)
	_create_hud()
	_make_board()
	world.calm()
	audio.play("ui_whoosh")
	_refresh_hud()
	hud.show_banner("LEVEL %d" % id)
	hud.say(GREETINGS[randi() % GREETINGS.size()], "wave", "hello")
	if current_level == 1 and not bool(save.data.tutorial):
		_show_tutorial()
	_trail("===== start_level(%d) complete =====" % id)
	_trail_after_draw("start_level(%d)" % id)

func _make_board() -> void:
	_trail("_make_board begin")
	tubes.clear()
	var all_colors: Array = []
	for cname in level_info.colors:
		for _i in range(int(level_info.gems)):
			all_colors.append(cname)
	var rng := RandomNumberGenerator.new()
	rng.seed = 700001 + current_level * 7919
	for i in range(all_colors.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = all_colors[i]
		all_colors[i] = all_colors[j]
		all_colors[j] = tmp
	tubes.resize(int(level_info.tubes))
	for i in range(tubes.size()):
		tubes[i] = []
	var idx := 0
	for ti in range(tubes.size() - 1):
		for _s in range(int(level_info.capacity)):
			if idx >= all_colors.size():
				break
			tubes[ti].append(all_colors[idx])
			idx += 1
	_trail("_make_board: %d tubes, capacity %d, %d crystals" % [tubes.size(), int(level_info.capacity), idx])
	world.arrange(tubes.size(), int(level_info.capacity), true)
	_connect_tubes()
	_sync_visuals()
	_trail("_make_board complete")

func _connect_tubes() -> void:
	var count := world.tubes_root.get_child_count()
	for i in range(count):
		var tube := world.get_tube(i)
		if tube and not tube.tapped.is_connected(_on_tube_tapped):
			tube.tapped.connect(_on_tube_tapped)

# Old crystals leave the tree at once but are freed with queue_free(): freeing
# the crystal whose tap signal is still being delivered is a use-after-free.
func _sync_visuals() -> void:
	for i in range(tubes.size()):
		var tube_node := world.get_tube(i)
		if tube_node == null:
			continue
		for child in tube_node.get_children():
			if child is Crystal3D:
				tube_node.remove_child(child)
				child.queue_free()
		var values: Array = tubes[i]
		var slot_h := 0.82
		var start_y := -((float(level_info.capacity) - 1.0) * slot_h) / 2.0
		for j in range(values.size()):
			var gem := Crystal3D.new()
			gem.setup(str(values[j]), Vector3(0, start_y + j * slot_h, 0), float(i * 17 + j), j)
			gem.tapped.connect(_on_crystal_tapped.bind(i))
			tube_node.add_child(gem)
			if i == selected and j == values.size() - 1:
				gem.set_selected(true)
		tube_node.set_highlight(i == selected or i == hint_destination)

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
	if current_screen == UiScreen.GAME and game_status == GameData.Status.PLAYING and hud != null:
		_idle_time += delta
		if _idle_time > NUDGE_AFTER and not _idle_nudged:
			_idle_nudged = true
			_cass("Stuck? Tap HINT for help!", "think", "think")

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
	_cass(POKES[randi() % POKES.size()], "wave", "giggle")

func _glow_for(tube_index: int) -> void:
	if hud == null or tubes[tube_index].is_empty():
		return
	var top: String = tubes[tube_index][-1]
	if GameData.COLOR_HEX.has(top):
		hud.avatar.set_glow(GameData.COLOR_HEX[top])

# Runs inside the physics-picking signal: just defer.
func _on_tube_tapped(index: int) -> void:
	_handle_tap.call_deferred(index)

func _handle_tap(index: int) -> void:
	if game_status != GameData.Status.PLAYING or hud == null:
		return
	if index < 0 or index >= tubes.size():
		return
	_idle_time = 0.0
	_idle_nudged = false
	hint_destination = -1
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

func _move_gem(from_i: int, to_i: int) -> void:
	if tubes[from_i].is_empty():
		_invalid_move()
		return
	if tubes[to_i].size() >= int(level_info.capacity):
		_invalid_move()
		return
	var col: String = tubes[from_i][-1]
	if not tubes[to_i].is_empty() and tubes[to_i][-1] != col:
		_invalid_move()
		return
	world.cam_move(from_i, to_i)
	world.pulse_camera(0.10)
	hud.avatar.look_at_screen(world.tube_screen_pos(to_i))
	tubes[from_i].pop_back()
	tubes[to_i].append(col)
	moves -= 1
	score += 10
	selected = -1
	audio.play("tap")
	hud.avatar.react("happy")
	_check_match(to_i)
	if game_status == GameData.Status.PLAYING and moves <= 3 and moves > 0:
		_cass(LOW[randi() % LOW.size()], "sad", "sigh")
	_check_win_condition()

func _invalid_move() -> void:
	selected = -1
	hint_destination = -1
	world.release_focus()
	world.pulse_camera(0.22)
	_cass(OOPS[randi() % OOPS.size()], "angry", "oops" if randi() % 2 == 0 else "nope")
	audio.play("tap")
	_vibrate(40)

func _check_match(ti: int) -> void:
	var tube: Array = tubes[ti]
	if tube.size() < 3:
		return
	var target = tube[-1]
	var count := 1
	for i in range(tube.size() - 2, -1, -1):
		if tube[i] == target:
			count += 1
		else:
			break
	if count < 3:
		return
	combo += 1
	score += combo * 50
	for _i in range(count):
		if tube.is_empty():
			break
		tube.pop_back()
	save.add_coins(2)
	coins_earned += 2
	save.data.total_matches = int(save.data.total_matches) + count
	save.quest_add("match", count)
	if combo == 3:
		save.quest_add("combo", 1)
	audio.play("match")
	world.cam_match(ti)
	world.pulse_camera(0.16)
	_vibrate(25)
	if combo >= 3:
		var bonus := combo
		save.add_coins(bonus)
		coins_earned += bonus
		hud.show_banner("COMBO x%d!" % combo, Color("#ffb347"))
		_cass("COMBO x%d!  +%d" % [combo, bonus], "dance", "wow")
		audio.play("streak_up")
	elif combo == 2:
		_cass("Double match!", "cheer", "cheer")
	else:
		_cass(CHEERS[randi() % CHEERS.size()], "cheer", "yay")

func _check_win_condition() -> void:
	var complete := true
	for tube in tubes:
		if not tube.is_empty():
			complete = false
			break
	if complete:
		game_status = GameData.Status.WON
		stars = 3 if moves >= int(level_info.s3) else (2 if moves >= int(level_info.s2) else 1)
		score += moves * 20
		save.set_level(current_level, stars, score)
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
	elif moves <= 0:
		game_status = GameData.Status.LOST
		save.record_loss()
		platform.level_finished()
		audio.play("gameover")
		_cass("Oh no...", "sad", "oh_no")
		world.defeat()
		_show_result(false)

# ── Power-ups: each asks "use coins or watch a video" ────────────────────────

func _open_powerup(kind: String) -> void:
	if game_status != GameData.Status.PLAYING or hud == null:
		return
	if kind == "tube" and tubes.size() >= MAX_TUBES:
		_toast("Maximum %d tubes" % MAX_TUBES)
		return
	var icon_name := "bulb"
	var accent := Color("#ffe14d")
	var title := ""
	var desc := ""
	var coin_text := ""
	var cost := 0
	match kind:
		"hint":
			title = "Need a hint?"
			desc = "Cass will point at a good move."
			if int(save.data.hints) > 0:
				coin_text = "Use a hint  (%d left)" % int(save.data.hints)
			else:
				cost = HINT_COST
				coin_text = "Use %d coins" % cost
		"moves":
			icon_name = "moves"
			accent = Ui.PINK
			title = "Out of moves?"
			desc = "+%d moves keep you in the game." % ProductionConfig.REWARD_EXTRA_MOVES
			cost = EXTRA_MOVES_COST
			coin_text = "Use %d coins" % cost
		"tube":
			icon_name = "tube"
			accent = Ui.BLUE
			title = "Add an extra tube?"
			desc = "A fresh empty tube gives you room to sort."
			cost = EXTRA_TUBE_COST
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
		"hint":
			ok = save.use_hint() or save.spend_coins(HINT_COST)
		"moves":
			ok = save.spend_coins(EXTRA_MOVES_COST)
		"tube":
			ok = save.spend_coins(EXTRA_TUBE_COST)
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
			_apply_hint()
		"moves":
			moves += ProductionConfig.REWARD_EXTRA_MOVES
			_refresh_hud()
			_cass("+%d moves!" % ProductionConfig.REWARD_EXTRA_MOVES, "cheer", "yay")
		"tube":
			_add_tube()

func _apply_hint() -> void:
	_hints_used_level += 1
	for fi in range(tubes.size()):
		if tubes[fi].is_empty():
			continue
		var col = tubes[fi][-1]
		for ti in range(tubes.size()):
			if fi == ti or tubes[ti].size() >= int(level_info.capacity):
				continue
			if tubes[ti].is_empty() or tubes[ti][-1] == col:
				selected = fi
				hint_destination = ti
				world.cam_hint(ti)
				_glow_for(fi)
				hud.avatar.look_at_screen(world.tube_screen_pos(ti))
				_cass("Try the glowing tube!", "point", "hmm")
				_sync_visuals()
				_refresh_hud()
				return
	_refresh_hud()
	_toast("No simple move found. Expose another crystal.")

# New tubes are appended at the end of the layout; existing tubes glide to their
# new places and the new one drops in (see BoardLayout / GameWorld.arrange).
func _add_tube() -> void:
	if tubes.size() >= MAX_TUBES:
		_toast("Maximum %d tubes" % MAX_TUBES)
		return
	var old_positions := world.tube_positions()
	tubes.append([])
	world.arrange(tubes.size(), int(level_info.capacity), false, old_positions)
	_connect_tubes()
	_sync_visuals()
	_refresh_hud()
	audio.play("tube_drop")
	_cass("A fresh tube!", "cheer", "wow")

# ── Pause / tutorial ──────────────────────────────────────────────────────────

func show_pause() -> void:
	if game_status != GameData.Status.PLAYING:
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
	_enter(UiScreen.RESULT)
	save.refresh_lives()
	var s := ResultScreen.new()
	_attach(s)
	var can_watch := platform.is_rewarded_ready() and not (won and _doubled)
	s.setup(won, stars, score, coins_earned, int(save.data.lives),
		EXTRA_MOVES_COST, can_watch, int(save.data.coins),
		int(save.data.win_streak), _streak_bonus)
	s.next_pressed.connect(func(): _start_after_ad(current_level + 1))
	s.replay_pressed.connect(func(): _start_after_ad(current_level))
	s.retry_pressed.connect(_retry_with_life)
	s.levels_pressed.connect(show_levels)
	s.home_pressed.connect(show_home)
	s.extra_moves_pressed.connect(_buy_extra_moves)
	s.free_moves_pressed.connect(_watch.bind("moves"))
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

# Continue a lost level with extra moves (the board is still in place).
func _resume_with_moves(count: int) -> void:
	if current_screen != UiScreen.RESULT or game_status != GameData.Status.LOST:
		if game_status == GameData.Status.PLAYING or game_status == GameData.Status.PAUSED:
			moves += count
			_refresh_hud()
		return
	moves += count
	game_status = GameData.Status.PLAYING
	_enter(UiScreen.GAME)
	_create_hud()
	world.calm()
	_refresh_hud()
	_cass("Back in the game!", "cheer", "yay")

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
