extends Node3D

# ── Economy ───────────────────────────────────────────────────────────────────
const HINT_COST           := 40
const EXTRA_MOVES_COST    := 30
const EXTRA_TUBE_COST     := 100
const LEVEL_COMPLETE_COINS := 5

# ── UI sizes (1080 x 1920 base viewport) ──────────────────────────────────────
const MRG  := 44
const SEP  := 18
const F_TITLE  := 78
const F_SUB    := 34
const F_BTN_H  := 46
const F_BTN    := 38
const F_BTN_S  := 32
const F_STAT   := 38
const F_HUD_L  := 40
const F_HUD_S  := 34
const F_BODY   := 34
const F_TOAST  := 34
const H_HERO   := 142
const H_LG     := 118
const H_BTN    := 106
const H_SM     := 88
const H_CTRL   := 100
const H_CARD   := 160

enum UiScreen { NONE, HOME, LEVELS, GAME, SHOP, SETTINGS, RESULT, CRASH }

# ── State ─────────────────────────────────────────────────────────────────────
var save:     SaveData
var audio:    AudioManager
var world:    GameWorld
var ui:       Control
var screen_root: Control
var hud:      VBoxContainer
var platform: AndroidPlatform

var current_screen: UiScreen = UiScreen.NONE
var game_status      := GameData.Status.IDLE
var current_level    := 1
var level_info:      Dictionary = {}
var tubes:           Array = []
var selected         := -1
var hint_destination := -1
var moves            := 0
var score            := 0
var combo            := 0
var stars            := 0
var move_serial      := 0
var toast_node:      Control
var tutorial_visible := false

var _pause_overlay: Control = null
var _last_tap_tube  := -1
var _last_tap_frame := -1
var _last_tap_ms    := -1000
var _back_armed_until_ms := 0

# ── Crash trail ───────────────────────────────────────────────────────────────
# Every risky step is written to a small file in the app's own storage and
# flushed immediately. If the app dies, the file shows where. On the next launch
# it is shown on screen with a COPY button. Set SHOW_CRASH_TRAIL to false for
# the Play Store build (the trail is still written, the screen is just skipped).
const SHOW_CRASH_TRAIL := true
const CRASH_LOG_PATH := "user://crash_trail.txt"
const MARK_CLEAN := "=== SESSION ENDED CLEANLY ==="
const MARK_PAUSED := "=== APP PAUSED ==="
const MARK_RESUMED := "=== APP RESUMED ==="
var _trail_file: FileAccess = null

func _open_trail() -> void:
	_trail_file = FileAccess.open(CRASH_LOG_PATH, FileAccess.WRITE)

func _trail(msg: String) -> void:
	print("[CC-DEBUG] " + msg)
	if _trail_file:
		_trail_file.store_line("%d | %s" % [Time.get_ticks_msec(), msg])
		_trail_file.flush()

# The previous session counts as a crash unless its LAST line is a clean-exit or
# app-paused marker. (Before, a marker anywhere in the file counted as clean, and
# after tapping CONTINUE the marker sat at the top of the file forever, so every
# later crash went undetected.)
func _read_previous_crash_trail() -> String:
	if not FileAccess.file_exists(CRASH_LOG_PATH):
		return ""
	var f := FileAccess.open(CRASH_LOG_PATH, FileAccess.READ)
	if f == null:
		return ""
	var content := f.get_as_text()
	f.close()
	var lines := content.strip_edges().split("\n")
	if lines.size() == 0 or lines[0] == "":
		return ""
	var last := lines[lines.size() - 1]
	if last.ends_with(MARK_CLEAN) or last.ends_with(MARK_PAUSED):
		return ""
	return content

func _log_environment() -> void:
	_trail("build %s, godot %s" % [ProductionConfig.VERSION_NAME, str(Engine.get_version_info().get("string", "?"))])
	_trail("os %s, model %s" % [OS.get_name(), OS.get_model_name()])
	_trail("gpu %s, vendor %s" % [
		RenderingServer.get_video_adapter_name(),
		RenderingServer.get_video_adapter_vendor()])
	_trail("gpu api %s" % str(RenderingServer.call("get_video_adapter_api_version")))
	_trail("static mem %d MB" % (OS.get_static_memory_usage() / 1048576))

# Logs once the renderer has really drawn a frame. If the trail ends at
# "complete" WITHOUT a "frame drawn" line, the crash is in rendering / shader
# compilation, not in game scripts.
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
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_handle_back()

# ── Bootstrap ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	var previous_trail := _read_previous_crash_trail()
	_open_trail()
	_trail("main._ready begin")
	_log_environment()
	save  = SaveData.new();     add_child(save)
	audio = AudioManager.new(); add_child(audio)
	audio.enabled = bool(save.data.sound)
	world = GameWorld.new();    add_child(world)
	world.build()
	world.set_board_visible(false)
	_trail("world.build() returned")
	platform = AndroidPlatform.new(); add_child(platform)
	platform.diagnostic.connect(_trail)
	platform.rewarded_earned.connect(_on_rewarded_earned)
	platform.purchase_completed.connect(_on_purchase_completed)
	platform.purchase_failed.connect(_on_purchase_failed)
	platform.setup(save)
	_build_ui()
	await get_tree().process_frame
	audio.set_music(bool(save.data.music))
	if previous_trail != "" and SHOW_CRASH_TRAIL:
		_trail("previous run did not close cleanly, showing trail screen")
		_show_crash_trail_screen(previous_trail)
	else:
		_trail("going to show_home()")
		show_home()
	_trail("main._ready complete")

func _show_crash_trail_screen(trail: String) -> void:
	current_screen = UiScreen.CRASH
	_clear_ui()
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.03, 0.08, 1.0)
	screen_root.add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   MRG)
	margin.add_theme_constant_override("margin_right",  MRG)
	margin.add_theme_constant_override("margin_top",    60)
	margin.add_theme_constant_override("margin_bottom", 40)
	screen_root.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", SEP)
	margin.add_child(box)

	box.add_child(_label("LAST SESSION DIDN'T CLOSE CLEANLY", 40, Color("#ff9060")))
	box.add_child(_label("Here's exactly where it stopped. Tap COPY LOG, then paste it to Claude.",
		26, Color("#c0c8ee")))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)

	var log_panel := PanelContainer.new()
	log_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_panel.add_theme_stylebox_override("panel", _style(Color(0.0, 0.0, 0.0, 0.6), 14))
	scroll.add_child(log_panel)

	var log_label := Label.new()
	log_label.text = trail
	log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_label.add_theme_font_size_override("font_size", 24)
	log_label.add_theme_color_override("font_color", Color("#9dffb0"))
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_panel.add_child(log_label)

	box.add_child(_button("COPY LOG", func(): _copy_trail(trail), H_BTN, F_BTN, true))
	box.add_child(_button("CONTINUE TO GAME", show_home, H_BTN, F_BTN))

func _copy_trail(trail: String) -> void:
	DisplayServer.clipboard_set(trail)
	_toast("Copied - paste it to Claude")

func _build_ui() -> void:
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	screen_root = Control.new()
	screen_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(screen_root)

func _clear_ui() -> void:
	for child in screen_root.get_children():
		screen_root.remove_child(child)
		child.queue_free()
	toast_node = null
	hud = null
	_pause_overlay = null
	tutorial_visible = false

func _vibrate(ms: int) -> void:
	if save and bool(save.data.vibration) and OS.get_name() == "Android":
		Input.vibrate_handheld(ms)

# ── Android back button ───────────────────────────────────────────────────────
# project.godot sets quit_on_go_back=false, so back no longer kills the app from
# the middle of a level.

func _handle_back() -> void:
	match current_screen:
		UiScreen.GAME:
			if game_status == GameData.Status.PAUSED and _pause_overlay != null:
				_pause_resume(_pause_overlay)
			elif game_status == GameData.Status.PLAYING:
				show_pause()
		UiScreen.LEVELS, UiScreen.SHOP, UiScreen.SETTINGS, UiScreen.RESULT:
			show_home()
		UiScreen.HOME, UiScreen.CRASH:
			var now := Time.get_ticks_msec()
			if now < _back_armed_until_ms:
				_trail(MARK_CLEAN)
				get_tree().quit()
			else:
				_back_armed_until_ms = now + 2000
				_toast("Press back again to exit")
		_:
			pass

# ── Style helpers ─────────────────────────────────────────────────────────────

func _style(bg: Color, radius := 22,
		bdr := Color(0.35, 0.50, 1.0, 0.30)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		s.set_border_width(side, 1)
	s.border_color          = bdr
	s.content_margin_left   = 26
	s.content_margin_right  = 26
	s.content_margin_top    = 14
	s.content_margin_bottom = 14
	return s

func _button(lbl: String, action: Callable,
		height := H_BTN, fsize := F_BTN, hero := false) -> Button:
	var b := Button.new()
	b.text = lbl
	b.custom_minimum_size = Vector2(0, height)
	b.add_theme_font_size_override("font_size", fsize)
	b.add_theme_color_override("font_color", Color.WHITE)
	var n := Color(0.28, 0.10, 0.62, 0.94) if hero else Color(0.08, 0.12, 0.34, 0.94)
	var h := Color(0.38, 0.16, 0.78, 0.98) if hero else Color(0.15, 0.22, 0.52, 0.98)
	var p := Color(0.18, 0.06, 0.44, 1.00) if hero else Color(0.05, 0.08, 0.22, 1.00)
	b.add_theme_stylebox_override("normal",  _style(n))
	b.add_theme_stylebox_override("hover",   _style(h))
	b.add_theme_stylebox_override("pressed", _style(p))
	b.pressed.connect(action)
	return b

func _label(txt: String, fsize: int,
		color := Color("#eef1ff"),
		align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = txt
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", color)
	return l

func _title_block(main_txt: String, sub_txt := "") -> VBoxContainer:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	box.add_child(_label(main_txt, F_TITLE))
	if sub_txt != "":
		box.add_child(_label(sub_txt, F_SUB, Color("#9ca8d9")))
	return box

func _background(img := "res://assets/images/bg_menu.jpg") -> void:
	var tr := TextureRect.new()
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var tex = load(img)
	if tex: tr.texture = tex
	tr.modulate = Color(0.32, 0.36, 0.62, 0.52)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_root.add_child(tr)
	var ov := ColorRect.new()
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.color = Color(0.02, 0.03, 0.11, 0.60)
	ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_root.add_child(ov)

func _content_scroll() -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	screen_root.add_child(scroll)
	var mrg := MarginContainer.new()
	mrg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mrg.add_theme_constant_override("margin_left",   MRG)
	mrg.add_theme_constant_override("margin_right",  MRG)
	mrg.add_theme_constant_override("margin_top",    56)
	mrg.add_theme_constant_override("margin_bottom", 56)
	scroll.add_child(mrg)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", SEP)
	mrg.add_child(box)
	return box

# Enter a non-game screen: hide the 3D board so a stale board is never visible
# behind menus.
func _enter_menu_screen(screen: UiScreen) -> void:
	current_screen = screen
	_clear_ui()
	if world:
		world.set_board_visible(false)

# ── HOME ──────────────────────────────────────────────────────────────────────

func show_home() -> void:
	game_status = GameData.Status.IDLE
	_enter_menu_screen(UiScreen.HOME)
	save.refresh_lives()
	_background()
	var box := _content_scroll()
	box.add_child(_title_block("CRYSTAL CASCADE", "A living 3D crystal puzzle"))

	var logo := TextureRect.new()
	var ltex = load("res://assets/images/game_logo.png")
	if ltex: logo.texture = ltex
	logo.custom_minimum_size  = Vector2(0, 200)
	logo.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(logo)

	box.add_child(_label(
		"💎 %d     💡 %d     ♥ %d / 5     ★ %d" % [
			int(save.data.coins), int(save.data.hints),
			int(save.data.lives), int(save.data.total_stars)],
		F_STAT, Color("#d4d8ff")))

	if save.can_claim_daily_bonus():
		box.add_child(_button("CLAIM DAILY BONUS  +50 💎",
			_claim_daily_bonus, H_BTN, F_BTN))
	else:
		box.add_child(_label("Daily bonus returns after 24 hours",
			F_BTN_S, Color("#7882b8")))

	box.add_child(_button("▶  PLAY",    show_levels,   H_HERO, F_BTN_H, true))
	box.add_child(_button("SHOP",       show_shop,     H_BTN,  F_BTN))
	box.add_child(_button("SETTINGS",   show_settings, H_BTN,  F_BTN))
	box.add_child(_label("by chAs  •  Godot 4.6 3D Edition",
		26, Color("#4a5480")))

func _claim_daily_bonus() -> void:
	if save.claim_daily_bonus():
		audio.play("coin")
		var came_from_shop := current_screen == UiScreen.SHOP
		if came_from_shop:
			show_shop()
		else:
			show_home()
		_toast("+50 coins claimed!")

# ── LEVEL SELECT ──────────────────────────────────────────────────────────────

func show_levels() -> void:
	_enter_menu_screen(UiScreen.LEVELS)
	_background("res://assets/images/bg_levelselect.jpg")

	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left",   MRG)
	root.add_theme_constant_override("margin_right",  MRG)
	root.add_theme_constant_override("margin_top",    44)
	root.add_theme_constant_override("margin_bottom", 40)
	screen_root.add_child(root)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", SEP)
	root.add_child(outer)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	var back := _button("‹", show_home, H_SM, F_BTN)
	back.custom_minimum_size.x = 110
	header.add_child(back)
	var title := Label.new()
	title.text = "SELECT LEVEL"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color("#eef1ff"))
	header.add_child(title)
	var sp := Control.new()
	sp.custom_minimum_size.x = 110
	header.add_child(sp)
	outer.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)

	var highest     := int(save.data.highest_unlocked)
	var max_display := maxi(100, highest + 16)

	for id in range(1, max_display + 1):
		var prog   : Dictionary = save.level(id)
		var locked := id > highest
		var nstars := clampi(int(prog.get("stars", 0)), 0, 3)
		var card   := Button.new()
		card.custom_minimum_size = Vector2(0, H_CARD)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_font_size_override("font_size", 32)
		if locked:
			card.text     = "🔒\n%d" % id
			card.disabled = true
			card.add_theme_stylebox_override("normal",
				_style(Color(0.06, 0.09, 0.22, 0.82), 16))
		else:
			card.text = "%d\n%s" % [id, "★".repeat(nstars) + "☆".repeat(3 - nstars)]
			card.pressed.connect(start_level.bind(id))
			card.add_theme_stylebox_override("normal",
				_style(Color(0.10, 0.14, 0.34, 0.94), 16))
			card.add_theme_stylebox_override("hover",
				_style(Color(0.16, 0.23, 0.52, 0.98), 16))
			card.add_theme_stylebox_override("pressed",
				_style(Color(0.06, 0.08, 0.20, 1.00), 16))
		grid.add_child(card)

# ── BOARD ─────────────────────────────────────────────────────────────────────

func start_level(id: int) -> void:
	_trail("===== start_level(%d) begin =====" % id)
	current_level    = id
	level_info       = GameData.level_info(id)
	_trail("level_info = %s" % str(level_info))
	moves            = int(level_info.moves)
	score = 0;  combo = 0;  stars = 0
	selected = -1;  hint_destination = -1
	game_status = GameData.Status.PLAYING
	_make_board()
	_trail("_make_board() returned, calling show_game()")
	show_game()
	_trail("show_game() returned")
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
			if idx >= all_colors.size(): break
			tubes[ti].append(all_colors[idx])
			idx += 1
	_trail("_make_board: %d tubes, capacity %d, %d crystals" % [
		tubes.size(), int(level_info.capacity), idx])
	world.arrange(tubes.size(), int(level_info.capacity))
	_connect_tubes()
	_sync_visuals()
	_trail("_make_board complete")

func _connect_tubes() -> void:
	var count := world.tubes_root.get_child_count()
	for i in range(count):
		var tube := world.get_tube(i)
		if tube and not tube.tapped.is_connected(_on_tube_tapped):
			tube.tapped.connect(_on_tube_tapped)

# Rebuilds every crystal from the tubes array. Old crystals are removed from
# the tree right away but freed with queue_free(): freeing them synchronously
# destroyed the very crystal whose tap signal was still being delivered, which
# is a use-after-free. All callers that run from a tap go through
# _handle_tap(), which is itself deferred.
func _sync_visuals() -> void:
	for i in range(tubes.size()):
		var tube_node := world.get_tube(i)
		if tube_node == null:
			_trail("_sync_visuals: WARNING no tube node at index %d" % i)
			continue
		for child in tube_node.get_children():
			if child is Crystal3D:
				tube_node.remove_child(child)
				child.queue_free()
		var values : Array = tubes[i]
		var slot_h := 0.82
		var start_y := -((float(level_info.capacity) - 1.0) * slot_h) / 2.0
		for j in range(values.size()):
			var gem := Crystal3D.new()
			gem.setup(str(values[j]),
				Vector3(0, start_y + j * slot_h, 0),
				float(i * 17 + j), j)
			gem.tapped.connect(_on_crystal_tapped.bind(i))
			tube_node.add_child(gem)
			if i == selected and j == values.size() - 1:
				gem.set_selected(true)
		tube_node.set_highlight(i == selected or i == hint_destination)

func _on_crystal_tapped(_crystal: Crystal3D, tube_index: int) -> void:
	_on_tube_tapped(tube_index)

# ── GAME SCREEN ───────────────────────────────────────────────────────────────

func show_game() -> void:
	_trail("show_game begin")
	current_screen = UiScreen.GAME
	_clear_ui()
	world.set_board_visible(true)

	var top_mrg := MarginContainer.new()
	top_mrg.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_mrg.add_theme_constant_override("margin_left",  MRG)
	top_mrg.add_theme_constant_override("margin_right", MRG)
	top_mrg.add_theme_constant_override("margin_top",   32)
	screen_root.add_child(top_mrg)

	var top_panel := PanelContainer.new()
	top_panel.add_theme_stylebox_override("panel",
		_style(Color(0.04, 0.06, 0.18, 0.88), 18))
	top_mrg.add_child(top_panel)

	var top_inner := MarginContainer.new()
	top_inner.add_theme_constant_override("margin_left",   22)
	top_inner.add_theme_constant_override("margin_right",  22)
	top_inner.add_theme_constant_override("margin_top",    14)
	top_inner.add_theme_constant_override("margin_bottom", 14)
	top_panel.add_child(top_inner)

	hud = VBoxContainer.new()
	hud.add_theme_constant_override("separation", 8)
	top_inner.add_child(hud)
	_update_hud()

	var bot_mrg := MarginContainer.new()
	bot_mrg.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bot_mrg.add_theme_constant_override("margin_left",   28)
	bot_mrg.add_theme_constant_override("margin_right",  28)
	bot_mrg.add_theme_constant_override("margin_bottom", 44)
	screen_root.add_child(bot_mrg)

	var bot_panel := PanelContainer.new()
	bot_panel.add_theme_stylebox_override("panel",
		_style(Color(0.04, 0.06, 0.18, 0.90), 22))
	bot_mrg.add_child(bot_panel)

	var bot_inner := MarginContainer.new()
	bot_inner.add_theme_constant_override("margin_left",   18)
	bot_inner.add_theme_constant_override("margin_right",  18)
	bot_inner.add_theme_constant_override("margin_top",    16)
	bot_inner.add_theme_constant_override("margin_bottom", 16)
	bot_panel.add_child(bot_inner)

	var ctrl := HBoxContainer.new()
	ctrl.add_theme_constant_override("separation", 10)
	bot_inner.add_child(ctrl)

	for pair in [["HINT", _hint], ["+5 MV", _extra_moves],
			["+TUBE", _extra_tube], ["CAM", world.next_camera],
			["PAUSE", show_pause]]:
		var b := _button(pair[0], pair[1], H_CTRL, F_BTN_S)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ctrl.add_child(b)
	_trail("show_game complete")

func _update_hud() -> void:
	if not is_instance_valid(hud):
		return
	for child in hud.get_children():
		hud.remove_child(child)
		child.queue_free()
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 10)
	hud.add_child(row1)
	var lv := Label.new()
	lv.text = "LEVEL %d" % current_level
	lv.add_theme_font_size_override("font_size", F_HUD_L)
	lv.add_theme_color_override("font_color", Color("#eef1ff"))
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(lv)
	row1.add_child(_label(
		"💎%d  💡%d  ♥%d" % [int(save.data.coins), int(save.data.hints), int(save.data.lives)],
		F_HUD_S, Color("#ccd4ff")))
	hud.add_child(_label(
		"MOVES %d   ·   SCORE %d   ·   COMBO ×%d" % [moves, score, combo],
		F_HUD_S, Color("#9aa8d4")))

# ── INPUT ─────────────────────────────────────────────────────────────────────

# Called from inside the physics-picking signal. Do NOTHING heavy here: just
# de-duplicate and defer. (One touch produces a touch event AND an emulated
# mouse event; both reach this function.)
func _on_tube_tapped(index: int) -> void:
	var frame := Engine.get_process_frames()
	var now := Time.get_ticks_msec()
	if index == _last_tap_tube and (frame == _last_tap_frame or now - _last_tap_ms < 150):
		return
	_last_tap_tube  = index
	_last_tap_frame = frame
	_last_tap_ms    = now
	_handle_tap.call_deferred(index)

func _handle_tap(index: int) -> void:
	if game_status != GameData.Status.PLAYING: return
	if index < 0 or index >= tubes.size():     return
	hint_destination = -1

	if selected == -1:
		if not tubes[index].is_empty():
			selected = index
			world.focus_on_tube(index)
			world.guardian.react("surprised")
			audio.play("tap")
	elif selected == index:
		selected = -1
		world.guardian.react("idle")
		audio.play("tap")
	else:
		_move_gem(selected, index)

	_sync_visuals()
	_update_hud()

func _move_gem(from_i: int, to_i: int) -> void:
	if tubes[from_i].is_empty():                         _invalid_move(); return
	if tubes[to_i].size() >= int(level_info.capacity):   _invalid_move(); return
	var col: String = tubes[from_i][-1]
	if not tubes[to_i].is_empty() and tubes[to_i][-1] != col:
		_invalid_move(); return
	world.focus_on_tube(to_i)
	world.pulse_camera(0.12)
	tubes[from_i].pop_back()
	tubes[to_i].append(col)
	moves -= 1;  move_serial += 1;  score += 10
	selected = -1
	audio.play("tap")
	world.guardian.react("happy")
	_check_match(to_i)
	if game_status == GameData.Status.PLAYING and moves <= 3:
		world.guardian.react("sad")
	_check_win_condition()

func _invalid_move() -> void:
	selected = -1;  hint_destination = -1
	world.guardian.react("angry")
	world.pulse_camera(0.22)
	audio.play("tap")
	_vibrate(40)
	_toast("That crystal cannot move there")

func _check_match(ti: int) -> void:
	var tube: Array = tubes[ti]
	if tube.size() < 3: return
	var target = tube[-1];  var count := 1
	for i in range(tube.size() - 2, -1, -1):
		if tube[i] == target: count += 1
		else: break
	if count < 3: return
	combo += 1;  score += combo * 50
	for _i in range(count):
		if tube.is_empty(): break
		tube.pop_back()
	save.add_coins(2)
	audio.play("match")
	world.guardian.react("happy")
	world.pulse_camera(0.18)
	_vibrate(25)
	_toast("MATCH! +%d" % (combo * 50))

func _check_win_condition() -> void:
	var complete := true
	for tube in tubes:
		if not tube.is_empty(): complete = false; break
	if complete:
		game_status = GameData.Status.WON
		stars = 3 if moves >= int(level_info.s3) \
			else (2 if moves >= int(level_info.s2) else 1)
		score += moves * 20
		save.set_level(current_level, stars, score)
		save.add_coins(LEVEL_COMPLETE_COINS)
		audio.play("victory")
		world.guardian.react("happy")
		_vibrate(60)
		if platform: platform.show_interstitial()
		_show_result(true)
	elif moves <= 0:
		game_status = GameData.Status.LOST
		audio.play("gameover")
		world.guardian.react("sad")
		_show_result(false)

func _hint() -> void:
	if game_status != GameData.Status.PLAYING: return
	var granted := save.use_hint()
	if not granted: granted = save.spend_coins(HINT_COST)
	if not granted: _toast("Need a hint or %d coins" % HINT_COST); return
	for fi in range(tubes.size()):
		if tubes[fi].is_empty(): continue
		var col = tubes[fi][-1]
		for ti in range(tubes.size()):
			if fi == ti or tubes[ti].size() >= int(level_info.capacity): continue
			if tubes[ti].is_empty() or tubes[ti][-1] == col:
				selected = fi;  hint_destination = ti
				world.focus_on_tube(ti)
				world.guardian.react("surprised")
				_sync_visuals()
				_update_hud()
				_toast("Hint: tap the glowing tube to move there")
				return
	_update_hud()
	_toast("No simple move found - expose another crystal")

func _extra_moves() -> void:
	if game_status != GameData.Status.PLAYING: return
	if save.spend_coins(EXTRA_MOVES_COST):
		moves += 5;  _update_hud();  _toast("+5 moves")
	else:
		_toast("You need %d coins" % EXTRA_MOVES_COST)

func _extra_tube() -> void:
	if game_status != GameData.Status.PLAYING: return
	if tubes.size() >= 10: _toast("Maximum 10 tubes"); return
	if not save.spend_coins(EXTRA_TUBE_COST):
		_toast("You need %d coins" % EXTRA_TUBE_COST); return
	tubes.append([])
	world.arrange(tubes.size(), int(level_info.capacity))
	_connect_tubes(); _sync_visuals(); _update_hud()
	_toast("Extra tube added")

# ── PAUSE ─────────────────────────────────────────────────────────────────────

func _pause_resume(overlay: Control) -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
	_pause_overlay = null
	game_status = GameData.Status.PLAYING

func _pause_restart(overlay: Control) -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
	start_level(current_level)

func _pause_to_levels(overlay: Control) -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
	show_levels()

func _pause_to_home(overlay: Control) -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
	show_home()

func show_pause() -> void:
	if game_status != GameData.Status.PLAYING: return
	game_status = GameData.Status.PAUSED
	var ov := ColorRect.new()
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.color = Color(0, 0, 0, 0.78)
	screen_root.add_child(ov)
	_pause_overlay = ov
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.add_child(center)
	var mrg := MarginContainer.new()
	mrg.add_theme_constant_override("margin_left",  MRG)
	mrg.add_theme_constant_override("margin_right", MRG)
	center.add_child(mrg)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", SEP)
	mrg.add_child(box)
	box.add_child(_title_block("PAUSED"))
	box.add_child(_button("▶  RESUME",
		func(): _pause_resume(ov), H_LG, F_BTN_H, true))
	box.add_child(_button("↺  RESTART",
		func(): _pause_restart(ov), H_BTN, F_BTN))
	box.add_child(_button("LEVELS",
		func(): _pause_to_levels(ov), H_BTN, F_BTN))
	box.add_child(_button("HOME",
		func(): _pause_to_home(ov), H_BTN, F_BTN))

# ── RESULT ────────────────────────────────────────────────────────────────────

func _show_result(won: bool) -> void:
	await get_tree().create_timer(0.55).timeout
	var expected := GameData.Status.WON if won else GameData.Status.LOST
	if game_status != expected: return
	_enter_menu_screen(UiScreen.RESULT)
	save.refresh_lives()
	_background("res://assets/images/bg_victory.jpg" if won
		else "res://assets/images/bg_menu.jpg")
	var box := _content_scroll()
	box.add_child(_title_block(
		"LEVEL COMPLETE" if won else "GAME OVER",
		"★".repeat(stars) if won else "Your Guardian wants another try"))
	box.add_child(_label(
		"SCORE  %d\nMOVES LEFT  %d\nBEST STARS  %d" % [
			score, moves,
			maxi(stars, int(save.level(current_level).get("stars", 0)))],
		F_STAT, Color("#d4d8ff")))
	if won:
		box.add_child(_button("▶  NEXT LEVEL",
			func(): start_level(current_level + 1), H_HERO, F_BTN_H, true))
	else:
		if int(save.data.lives) > 0:
			box.add_child(_button("↺  RETRY  (1 life)",
				_retry_with_life, H_LG, F_BTN, true))
		else:
			box.add_child(_button("WATCH AD FOR 1 LIFE",
				_reward_life_notice, H_LG, F_BTN, true))
		# The old condition was "moves > 0", but a lost game always has 0 moves
		# left, so this button could never appear.
		box.add_child(_button("+5 MOVES  (%d coins)" % EXTRA_MOVES_COST,
			_resume_with_extra_moves, H_BTN, F_BTN))
	box.add_child(_button("↺  REPLAY",  func(): start_level(current_level), H_BTN, F_BTN))
	box.add_child(_button("LEVELS",     show_levels, H_BTN, F_BTN))
	box.add_child(_button("HOME",       show_home,   H_SM,  F_BTN_S))

func _retry_with_life() -> void:
	if save.use_life(): start_level(current_level)
	else: _reward_life_notice()

func _resume_with_extra_moves() -> void:
	if save.spend_coins(EXTRA_MOVES_COST):
		moves += 5;  game_status = GameData.Status.PLAYING;  show_game()
	else:
		_toast("You need %d coins" % EXTRA_MOVES_COST)

func _reward_life_notice() -> void:
	if platform and platform.show_rewarded("life"):
		_toast("Watch the ad to receive 1 life")
	else:
		_toast("No ad available right now - try again shortly")

func _on_rewarded_earned(reward_type: String) -> void:
	match reward_type:
		"life":  save.add_life();    _toast("+1 life")
		"hint":  save.add_hints(1);  _toast("+1 hint")
		"coins": save.add_coins(50); _toast("+50 coins")
		_:       save.add_coins(50); _toast("+50 coins")
	if current_screen == UiScreen.RESULT:
		_show_result_refresh()

# After a life is granted from the game-over screen, rebuild it so RETRY shows.
func _show_result_refresh() -> void:
	if game_status == GameData.Status.LOST:
		_show_result(false)

func _on_purchase_completed(product_id: String) -> void:
	_toast("Purchase complete: %s" % product_id)
	if current_screen == UiScreen.SHOP:
		show_shop()

func _on_purchase_failed(_product_id: String, message: String) -> void:
	_toast("Purchase unavailable: %s" % message)

# ── TUTORIAL ──────────────────────────────────────────────────────────────────

func _close_tutorial(overlay: Control) -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
	tutorial_visible     = false
	save.data.tutorial   = true
	save.save()

func _show_tutorial() -> void:
	tutorial_visible = true
	var ov := ColorRect.new()
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.color = Color(0, 0, 0, 0.80)
	screen_root.add_child(ov)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.add_child(center)
	var mrg := MarginContainer.new()
	mrg.add_theme_constant_override("margin_left",  MRG)
	mrg.add_theme_constant_override("margin_right", MRG)
	center.add_child(mrg)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	mrg.add_child(box)
	box.add_child(_title_block("HOW TO PLAY", "Sort every crystal into matching tubes"))
	var inst := Label.new()
	inst.text = (
		"1. Tap a tube to select its top crystal.\n"
		+ "2. Tap a tube with the same colour on top, or an empty tube.\n"
		+ "3. Build 3 or more matching crystals in a row to clear them.\n"
		+ "4. Clear all crystals from every tube to win.\n"
		+ "5. Fewer moves used = more stars earned.\n\n"
		+ "Use the CAM button to rotate the 3D camera around the board.")
	inst.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inst.custom_minimum_size = Vector2(900, 0)
	inst.add_theme_font_size_override("font_size", F_BODY)
	inst.add_theme_color_override("font_color", Color("#d8def8"))
	box.add_child(inst)
	box.add_child(_button("GOT IT  ▶",
		func(): _close_tutorial(ov), H_LG, F_BTN, true))

# ── SHOP ──────────────────────────────────────────────────────────────────────

func show_shop() -> void:
	_enter_menu_screen(UiScreen.SHOP)
	_background()
	var box := _content_scroll()
	box.add_child(_title_block("SHOP", "Coins, hints and premium items"))
	box.add_child(_label(
		"COINS  %d     HINTS  %d     LIVES  %d / 5" % [
			int(save.data.coins), int(save.data.hints), int(save.data.lives)],
		F_STAT, Color("#ffd34e")))
	var items := [
		["💎  DAILY BONUS — FREE +50 COINS",        _claim_daily_bonus],
		["💡  HINT PACK — 5 HINTS",                 func(): _purchase("hint_pack_small")],
		["💡  HINT PACK — 15 HINTS",                func(): _purchase("hint_pack_large")],
		["💰  COIN PACK — 500 COINS",               func(): _purchase("coin_pack_starter")],
		["🌟  MEGA PACK — 2 000 COINS + 20 HINTS",  func(): _purchase("mega_pack")],
		["🚫  REMOVE ADS — 1 DAY",                  func(): _purchase("remove_ads_day")],
		["🚫  REMOVE ADS — WEEKEND",                func(): _purchase("remove_ads_weekend")],
		["🚫  REMOVE ADS — MONTH",                  func(): _purchase("remove_ads_month")],
	]
	for item in items:
		box.add_child(_button(item[0], item[1], H_BTN, F_BTN))
	box.add_child(_button("‹  BACK", show_home, H_SM, F_BTN_S))

# The failure toast used to be overwritten by "Opening Google Play checkout",
# so a failed purchase looked like it had started.
func _purchase(product_id: String) -> void:
	if platform and platform.purchase(product_id):
		_toast("Opening Google Play checkout…")

# ── SETTINGS ──────────────────────────────────────────────────────────────────

func show_settings() -> void:
	_enter_menu_screen(UiScreen.SETTINGS)
	_background()
	var box := _content_scroll()
	box.add_child(_title_block("SETTINGS"))
	box.add_child(_button(
		"🔊  SOUND: %s" % ("ON ✓" if bool(save.data.sound) else "OFF"),
		_toggle_sound, H_BTN, F_BTN))
	box.add_child(_button(
		"🎵  MUSIC: %s" % ("ON ✓" if bool(save.data.music) else "OFF"),
		_toggle_music, H_BTN, F_BTN))
	box.add_child(_button(
		"📳  VIBRATION: %s" % ("ON ✓" if bool(save.data.vibration) else "OFF"),
		_toggle_vibration, H_BTN, F_BTN))
	box.add_child(_button("⚠  RESET ALL PROGRESS", _confirm_reset, H_BTN, F_BTN))
	box.add_child(_button("‹  BACK", show_home, H_SM, F_BTN_S))

func _toggle_sound() -> void:
	save.set_setting("sound", not bool(save.data.sound))
	audio.enabled = bool(save.data.sound);  show_settings()

func _toggle_music() -> void:
	var en := not bool(save.data.music)
	save.set_setting("music", en);  audio.set_music(en);  show_settings()

func _toggle_vibration() -> void:
	save.set_setting("vibration", not bool(save.data.vibration))
	_vibrate(40)
	show_settings()

func _do_reset() -> void:
	save.reset_all()
	audio.enabled = bool(save.data.sound)
	audio.set_music(bool(save.data.music))
	show_home()

# Same styling as the rest of the game (the stock ConfirmationDialog rendered
# in tiny default fonts on a 1080-wide canvas).
func _confirm_reset() -> void:
	var ov := ColorRect.new()
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.color = Color(0, 0, 0, 0.82)
	screen_root.add_child(ov)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.add_child(center)
	var mrg := MarginContainer.new()
	mrg.add_theme_constant_override("margin_left",  MRG)
	mrg.add_theme_constant_override("margin_right", MRG)
	center.add_child(mrg)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", SEP)
	mrg.add_child(box)
	box.add_child(_title_block("RESET PROGRESS?"))
	var msg := Label.new()
	msg.text = ("This permanently erases all coins, lives, stars, "
		+ "levels and settings on this device.\nThis cannot be undone.")
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.custom_minimum_size = Vector2(900, 0)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", F_BODY)
	msg.add_theme_color_override("font_color", Color("#d8def8"))
	box.add_child(msg)
	box.add_child(_button("YES, ERASE EVERYTHING", _do_reset, H_BTN, F_BTN, true))
	box.add_child(_button("CANCEL", func(): ov.queue_free(), H_BTN, F_BTN))

# ── TOAST ─────────────────────────────────────────────────────────────────────

func _toast(msg: String) -> void:
	if not is_inside_tree() or screen_root == null: return
	if toast_node and is_instance_valid(toast_node):
		toast_node.queue_free()
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(Color(0.06, 0.08, 0.26, 0.94), 16))
	panel.anchor_left   = 0.0;  panel.anchor_right  = 1.0
	panel.anchor_top    = 1.0;  panel.anchor_bottom = 1.0
	panel.offset_left   = MRG;  panel.offset_right  = -MRG
	panel.offset_top    = -230; panel.offset_bottom = -140
	screen_root.add_child(panel)
	toast_node = panel
	var lbl := Label.new()
	lbl.text = msg
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", F_TOAST)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	panel.add_child(lbl)
	# Tween is owned by the panel, so it dies with it if the screen changes.
	var tw := panel.create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(panel, "modulate:a", 0.0, 0.35)
	tw.tween_callback(panel.queue_free)
