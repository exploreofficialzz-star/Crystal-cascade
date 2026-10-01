class_name GameHud
extends Control

signal pause_pressed
signal hint_pressed
signal moves_pressed
signal tube_pressed
signal camera_pressed

const AVATAR_SIZE := 264

var avatar: AvatarPortrait
var _level_label: Label
var _moves_chip: Control
var _score_chip: Control
var _coin_chip: Control
var _hint_badge: Label
var _bubble: PanelContainer
var _bubble_label: Label
var _bubble_tween: Tween
var _banner: Label
var _banner_tween: Tween

func setup() -> void:
	Ui.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shade := Ui.gradient_rect(Color(0.02, 0.02, 0.08, 0.66), Color(0.02, 0.02, 0.08, 0.0))
	shade.set_anchors_preset(Control.PRESET_TOP_WIDE)
	shade.offset_top = 0
	shade.offset_bottom = 460
	add_child(shade)

	# top-left: pause, level title, stat chips
	var left := VBoxContainer.new()
	left.set_anchors_preset(Control.PRESET_TOP_LEFT)
	left.offset_left = 40
	left.offset_top = 36 + Ui.inset_top
	left.offset_right = 40 + 700
	left.offset_bottom = left.offset_top + 10
	left.add_theme_constant_override("separation", 18)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(left)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 22)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pause := Ui.circle_button("pause", 108)
	pause.pressed.connect(func(): pause_pressed.emit())
	head.add_child(pause)
	_level_label = Ui.label("LEVEL 1", 56, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, true)
	_level_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_level_label.add_theme_constant_override("outline_size", 8)
	head.add_child(_level_label)
	left.add_child(head)

	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 14)
	chips.add_theme_constant_override("v_separation", 12)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_moves_chip = Ui.chip("moves", "0", Ui.PINK, 36)
	_score_chip = Ui.chip("star", "0", Ui.GOLD, 36)
	_coin_chip = Ui.chip("coin", "0", Ui.GOLD, 36)
	chips.add_child(_moves_chip)
	chips.add_child(_score_chip)
	chips.add_child(_coin_chip)
	left.add_child(chips)

	# top-right: the Guardian's portrait and speech bubble
	avatar = AvatarPortrait.new()
	avatar.custom_minimum_size = Vector2(AVATAR_SIZE, AVATAR_SIZE)
	avatar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	avatar.offset_right = -36
	avatar.offset_left = -36 - AVATAR_SIZE
	avatar.offset_top = 30 + Ui.inset_top
	avatar.offset_bottom = avatar.offset_top + AVATAR_SIZE
	add_child(avatar)

	_bubble = PanelContainer.new()
	_bubble.add_theme_stylebox_override("panel", Ui.flat(Color("#f4f1ff"), 30, Color("#7ef0ff"), 3, 24, 14))
	_bubble.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_bubble.offset_right = -36
	_bubble.offset_left = -36 - 420
	_bubble.offset_top = avatar.offset_bottom + 8
	_bubble.offset_bottom = _bubble.offset_top + 10
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.modulate = Color(1, 1, 1, 0)
	_bubble_label = Ui.label("", 32, Color("#241b63"), HORIZONTAL_ALIGNMENT_CENTER, true)
	_bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble_label.custom_minimum_size = Vector2(340, 0)
	_bubble.add_child(_bubble_label)
	add_child(_bubble)

	# centre: level banner
	_banner = Ui.label("", 96, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
	_banner.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.3, 0.9))
	_banner.add_theme_constant_override("outline_size", 14)
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.offset_left = -500
	_banner.offset_right = 500
	_banner.offset_top = -190
	_banner.offset_bottom = -40
	_banner.modulate = Color(1, 1, 1, 0)
	add_child(_banner)

	# bottom action bar
	var bar_m := MarginContainer.new()
	bar_m.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar_m.offset_top = -260
	bar_m.offset_bottom = 0
	bar_m.add_theme_constant_override("margin_left", 30)
	bar_m.add_theme_constant_override("margin_right", 30)
	bar_m.add_theme_constant_override("margin_bottom", 30 + int(Ui.inset_bottom))
	bar_m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar_m)
	var bar := PanelContainer.new()
	bar.size_flags_vertical = Control.SIZE_SHRINK_END
	bar.add_theme_stylebox_override("panel", Ui.flat(Color(0.03, 0.04, 0.14, 0.86), 44, Color(0.45, 0.55, 1.0, 0.28), 2, 18, 16))
	bar_m.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	bar.add_child(row)
	row.add_child(_action("bulb", "HINT", "", Color("#ffe14d"), _emit_hint, true))
	row.add_child(_action("moves", "+%d MOVES" % ProductionConfig.REWARD_EXTRA_MOVES, "30", Ui.PINK, _emit_moves))
	row.add_child(_action("tube", "+TUBE", "100", Ui.BLUE, _emit_tube))
	row.add_child(_action("camera", "CAMERA", "", Ui.GREEN, _emit_camera))

func _emit_hint() -> void:
	hint_pressed.emit()

func _emit_moves() -> void:
	moves_pressed.emit()

func _emit_tube() -> void:
	tube_pressed.emit()

func _emit_camera() -> void:
	camera_pressed.emit()

func _action(icon_name: String, text: String, cost: String, accent: Color, action: Callable, with_badge: bool = false) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 176)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_stylebox_override("normal", Ui.flat(Color(accent, 0.14), 32, Color(accent, 0.55), 2, 0, 0))
	b.add_theme_stylebox_override("hover", Ui.flat(Color(accent, 0.24), 32, Color(accent, 0.8), 2, 0, 0))
	b.add_theme_stylebox_override("pressed", Ui.flat(Color(accent, 0.36), 32, Color(accent, 1.0), 2, 0, 0))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.focus_mode = Control.FOCUS_NONE
	var v := VBoxContainer.new()
	Ui.full_rect(v)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 4)
	v.add_child(Ui.icon(icon_name, 62, accent))
	v.add_child(Ui.label(text, 24, Ui.TEXT, HORIZONTAL_ALIGNMENT_CENTER, true))
	if cost != "":
		var cr := HBoxContainer.new()
		cr.alignment = BoxContainer.ALIGNMENT_CENTER
		cr.add_theme_constant_override("separation", 6)
		cr.add_child(Ui.icon("coin", 24, Ui.GOLD))
		cr.add_child(Ui.label(cost, 24, Ui.GOLD, HORIZONTAL_ALIGNMENT_CENTER, true))
		v.add_child(cr)
	b.add_child(v)
	Ui.ignore_mouse(v)
	if with_badge:
		var badge := PanelContainer.new()
		badge.add_theme_stylebox_override("panel", Ui.flat(Ui.RED, 40, Color.WHITE, 2, 12, 2))
		badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		badge.offset_left = -70
		badge.offset_right = -12
		badge.offset_top = 10
		badge.offset_bottom = 54
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hint_badge = Ui.label("0", 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
		badge.add_child(_hint_badge)
		b.add_child(badge)
	Ui.hook_click(b)
	b.pressed.connect(action)
	return b

func update_stats(level: int, moves: int, score: int, coins: int, hints: int) -> void:
	if _level_label != null:
		_level_label.text = "LEVEL %d" % level
	Ui.set_chip(_moves_chip, "%d" % moves)
	Ui.set_chip(_score_chip, "%d" % score)
	Ui.set_chip(_coin_chip, "%d" % coins)
	if _hint_badge != null:
		_hint_badge.text = str(hints)

func say(text: String, mood: String = "") -> void:
	if _bubble == null:
		return
	if mood != "" and avatar != null:
		avatar.react(mood)
	_bubble_label.text = text
	if _bubble_tween != null and _bubble_tween.is_valid():
		_bubble_tween.kill()
	_bubble.modulate = Color(1, 1, 1, 0)
	_bubble_tween = create_tween()
	_bubble_tween.tween_property(_bubble, "modulate:a", 1.0, 0.16)
	_bubble_tween.tween_interval(1.9)
	_bubble_tween.tween_property(_bubble, "modulate:a", 0.0, 0.35)

func show_banner(title: String) -> void:
	if _banner == null:
		return
	_banner.text = title
	_banner.pivot_offset = Vector2(500, 75)
	_banner.scale = Vector2(0.6, 0.6)
	_banner.modulate = Color(1, 1, 1, 0)
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.set_parallel(true)
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.25)
	_banner_tween.tween_property(_banner, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.chain().tween_interval(1.1)
	_banner_tween.chain().tween_property(_banner, "modulate:a", 0.0, 0.4)
