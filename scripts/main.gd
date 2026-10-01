extends Node3D

# Game orchestrator: navigation, game rules, and the glue between screens, the
# 3D world, ads and purchases. Screens live in scripts/screens, widgets in
# scripts/ui, the ad/billing bridge in scripts/services/android_platform.gd.

const HINT_COST := 40
const EXTRA_MOVES_COST := 30
const EXTRA_TUBE_COST := 100
const LEVEL_COMPLETE_COINS := 5

const CHEERS := ["Nice one!", "Sparkling!", "Great match!", "Crystal clear!", "You got it!", "Brilliant!"]
const OOPS := ["Hmm, not there.", "Try another tube!", "Careful now!"]
const PICKS := ["Good choice.", "Where to?", "Ooh, that one."]
const LOW := ["Only a few moves left!", "Think carefully!"]
const GREETINGS := ["Let's go!", "You can do it!", "Ready when you are!"]

enum UiScreen { NONE, HOME, LEVELS, GAME, SHOP, SETTINGS, RESULT, DIAGNOSTICS }

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
var _modal: Control = null
var _toast_node: Control = null
var _banner_reserve := 0
var _back_armed_until_ms := 0

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

# ── Bootstrap ─────────────────────────────────────────────────────────────────

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
	world = GameWorld.new()
	add_child(world)
	world.build()
	world.set_active(false)
	_trail("world.build() returned")
	Ui.sfx_target = self
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
	_build_root_ui()
	await get_tree().process_frame
	audio.set_music(bool(save.data.music))
	if crashed and SHOW_CRASH_TRAIL:
		_trail("previous run did not close cleanly")
		_show_diagnostics()
	else:
		show_home()
	_trail("main._ready complete")

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
	if kind == UiScreen.SHOP or kind == UiScreen.LEVELS:
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
	s.bonus_requested.connect(_claim_daily_bonus)
	_apply_banner_reserve()

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

func _purchase(product_id: String) -> void:
	if platform.purchase(product_id):
		_toast("Opening Google Play…")

func _on_purchase_completed(product_id: String) -> void:
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
	audio.set_music(bool(save.data.music))
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
			_pause_resume()
		_close_modal()
		return
	match current_screen:
		UiScreen.GAME:
			if game_status == GameData.Status.PLAYING:
				show_pause()
		UiScreen.LEVELS, UiScreen.SHOP, UiScreen.SETTINGS, UiScreen.RESULT:
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
		"moves":
			_resume_with_moves(ProductionConfig.REWARD_EXTRA_MOVES)
		"double":
			save.add_coins(coins_earned)
			coins_earned *= 2
			_doubled = true
			_toast("Coins doubled!")
			if current_screen == UiScreen.RESULT:
				_build_result(true)
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
	selected = -1
	hint_destination = -1
	game_status = GameData.Status.PLAYING
	_enter(UiScreen.GAME)
	hud = GameHud.new()
	_attach(hud)
	hud.setup()
	hud.pause_pressed.connect(show_pause)
	hud.hint_pressed.connect(_hint)
	hud.moves_pressed.connect(_extra_moves)
	hud.tube_pressed.connect(_extra_tube)
	hud.camera_pressed.connect(_next_camera)
	_make_board()
	world.calm()
	_refresh_hud()
	hud.show_banner("LEVEL %d" % id)
	hud.say(GREETINGS[randi() % GREETINGS.size()], "happy")
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

func _next_camera() -> void:
	world.next_camera()

# Drag on the table to orbit the camera (taps are filtered in TapFilter, so a
# drag that starts on a tube never selects it).
func _unhandled_input(event: InputEvent) -> void:
	if current_screen != UiScreen.GAME or game_status != GameData.Status.PLAYING:
		return
	if event is InputEventScreenDrag:
		world.orbit_drag(event.relative)
	elif event is InputEventMouseMotion and not DisplayServer.is_touchscreen_available():
		if (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			world.orbit_drag(event.relative)

# Runs inside the physics-picking signal: just defer.
func _on_tube_tapped(index: int) -> void:
	_handle_tap.call_deferred(index)

func _glow_for(tube_index: int) -> void:
	if hud == null or tubes[tube_index].is_empty():
		return
	var top: String = tubes[tube_index][-1]
	if GameData.COLOR_HEX.has(top):
		hud.avatar.set_glow(GameData.COLOR_HEX[top])

func _handle_tap(index: int) -> void:
	if game_status != GameData.Status.PLAYING or hud == null:
		return
	if index < 0 or index >= tubes.size():
		return
	hint_destination = -1
	if selected == -1:
		if not tubes[index].is_empty():
			selected = index
			world.focus_on_tube(index)
			_glow_for(index)
			hud.avatar.look_at_screen(world.tube_screen_pos(index))
			audio.play("tap")
			if randi() % 4 == 0:
				hud.say(PICKS[randi() % PICKS.size()], "think")
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
	world.focus_on_tube(to_i)
	world.pulse_camera(0.10)
	hud.avatar.look_at_screen(world.tube_screen_pos(to_i))
	tubes[from_i].pop_back()
	tubes[to_i].append(col)
	moves -= 1
	score += 10
	selected = -1
	audio.play("tap")
	_check_match(to_i)
	if game_status == GameData.Status.PLAYING and moves <= 3 and moves > 0:
		hud.say(LOW[randi() % LOW.size()], "sad")
	_check_win_condition()

func _invalid_move() -> void:
	selected = -1
	hint_destination = -1
	world.release_focus()
	world.pulse_camera(0.22)
	hud.say(OOPS[randi() % OOPS.size()], "angry")
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
	audio.play("match")
	hud.say(CHEERS[randi() % CHEERS.size()], "happy")
	world.pulse_camera(0.16)
	world.punch(1.0)
	_vibrate(25)

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
		platform.level_finished()
		audio.play("victory")
		hud.say("We did it!", "happy")
		world.celebrate()
		_vibrate(60)
		_show_result(true)
	elif moves <= 0:
		game_status = GameData.Status.LOST
		platform.level_finished()
		audio.play("gameover")
		hud.say("Oh no...", "sad")
		world.defeat()
		_show_result(false)

func _hint() -> void:
	if game_status != GameData.Status.PLAYING or hud == null:
		return
	var granted := save.use_hint()
	if not granted:
		granted = save.spend_coins(HINT_COST)
	if not granted:
		_toast("Need a hint or %d coins. Watch a video in the Shop!" % HINT_COST)
		return
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
				world.focus_on_tube(ti)
				_glow_for(fi)
				hud.say("Try the glowing tube!", "think")
				_sync_visuals()
				_refresh_hud()
				return
	_refresh_hud()
	_toast("No simple move found. Expose another crystal.")

func _extra_moves() -> void:
	if game_status != GameData.Status.PLAYING:
		return
	if save.spend_coins(EXTRA_MOVES_COST):
		moves += ProductionConfig.REWARD_EXTRA_MOVES
		_refresh_hud()
		hud.say("+%d moves!" % ProductionConfig.REWARD_EXTRA_MOVES, "happy")
	else:
		_toast("You need %d coins. Earn them in the Shop!" % EXTRA_MOVES_COST)

func _extra_tube() -> void:
	if game_status != GameData.Status.PLAYING:
		return
	if tubes.size() >= 10:
		_toast("Maximum 10 tubes")
		return
	if not save.spend_coins(EXTRA_TUBE_COST):
		_toast("You need %d coins. Earn them in the Shop!" % EXTRA_TUBE_COST)
		return
	tubes.append([])
	world.arrange(tubes.size(), int(level_info.capacity), false)
	_connect_tubes()
	_sync_visuals()
	_refresh_hud()
	hud.say("A fresh tube!", "happy")

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

func _show_tutorial() -> void:
	_close_modal()
	_modal = Modals.tutorial(overlay_root, _close_tutorial)

func _close_tutorial() -> void:
	save.data.tutorial = true
	save.save()

# ── Result ────────────────────────────────────────────────────────────────────

func _show_result(won: bool) -> void:
	await get_tree().create_timer(1.7 if won else 1.1).timeout
	var expected := GameData.Status.WON if won else GameData.Status.LOST
	if game_status != expected:
		return
	_build_result(won)

func _build_result(won: bool) -> void:
	_enter(UiScreen.RESULT)
	save.refresh_lives()
	var s := ResultScreen.new()
	_attach(s)
	var can_watch := platform.is_rewarded_ready() and not (won and _doubled)
	s.setup(won, stars, score, coins_earned, int(save.data.lives),
		EXTRA_MOVES_COST, can_watch, int(save.data.coins))
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
		if game_status == GameData.Status.PLAYING:
			moves += count
			_refresh_hud()
		return
	moves += count
	game_status = GameData.Status.PLAYING
	_enter(UiScreen.GAME)
	hud = GameHud.new()
	_attach(hud)
	hud.setup()
	hud.pause_pressed.connect(show_pause)
	hud.hint_pressed.connect(_hint)
	hud.moves_pressed.connect(_extra_moves)
	hud.tube_pressed.connect(_extra_tube)
	hud.camera_pressed.connect(_next_camera)
	world.calm()
	_refresh_hud()
	hud.say("Back in the game!", "happy")

# ── Toast ─────────────────────────────────────────────────────────────────────

func _toast(msg: String) -> void:
	if overlay_root == null or not is_inside_tree():
		return
	if toast_valid():
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

func toast_valid() -> bool:
	return _toast_node != null and is_instance_valid(_toast_node)
