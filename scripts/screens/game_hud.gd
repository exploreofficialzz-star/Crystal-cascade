class_name GameHud
extends Control

signal pause_pressed
signal hint_pressed
signal moves_pressed
signal tube_pressed
signal crystal_pressed
signal voice_requested(kind: String)
signal avatar_poked

const AVATAR_W := 420
const AVATAR_H := 580
const LEFT_W := 560

var avatar: AvatarPortrait
var _level_label: Label
var _theme_label: Label
var _twist_row: HBoxContainer
var _moves_chip: Control
var _score_chip: Control
var _coin_chip: Control
var _hint_badge: Label
var _bubble: PanelContainer
var _bubble_label: Label
var _bubble_tween: Tween
var _banner: Label
var _banner_sub: Label
var _banner_tween: Tween
var _action_buttons: Array = []

func setup() -> void:
	Ui.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shade := Ui.gradient_rect(Color(0.02, 0.02, 0.08, 0.66), Color(0.02, 0.02, 0.08, 0.0))
	shade.set_anchors_preset(Control.PRESET_TOP_WIDE)
	shade.offset_top = 0
	shade.offset_bottom = 520
	add_child(shade)

	# top-left: pause, level title, theme name, stat chips, twist pills
	var left := VBoxContainer.new()
	left.set_anchors_preset(Control.PRESET_TOP_LEFT)
	left.offset_left = 40
	left.offset_top = 36 + Ui.inset_top
	left.offset_right = 40 + LEFT_W
	left.offset_bottom = left.offset_top + 10
	left.add_theme_constant_override("separation", 12)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(left)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 22)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pause := Ui.circle_button("pause", 108)
	pause.pressed.connect(_emit_pause)
	head.add_child(pause)
	_level_label = Ui.label("LEVEL 1", 56, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, true)
	_level_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_level_label.add_theme_constant_override("outline_size", 8)
	head.add_child(_level_label)
	left.add_child(head)

	_theme_label = Ui.label("", 30, Color("#c9d2ff"), HORIZONTAL_ALIGNMENT_LEFT, true)
	_theme_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_theme_label.add_theme_constant_override("outline_size", 6)
	left.add_child(_theme_label)

	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 12)
	chips.add_theme_constant_override("v_separation", 10)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_moves_chip = Ui.chip("moves", "0", Ui.PINK, 34)
	_score_chip = Ui.chip("star", "0", Ui.GOLD, 34)
	_coin_chip = Ui.chip("coin", "0", Ui.GOLD, 34)
	chips.add_child(_moves_chip)
	chips.add_child(_score_chip)
	chips.add_child(_coin_chip)
	left.add_child(chips)

	_twist_row = HBoxContainer.new()
	_twist_row.add_theme_constant_override("separation", 10)
	_twist_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(_twist_row)

	# right edge: Cass, full body (big)
	avatar = AvatarPortrait.new()
	avatar.custom_minimum_size = Vector2(AVATAR_W, AVATAR_H)
	avatar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	avatar.offset_right = -16
	avatar.offset_left = -16 - AVATAR_W
	avatar.offset_top = 8 + Ui.inset_top
	avatar.offset_bottom = avatar.offset_top + AVATAR_H
	add_child(avatar)
	avatar.poked.connect(_emit_poked)

	# speech bubble, left of Cass and below the stat chips
	_bubble = PanelContainer.new()
	_bubble.add_theme_stylebox_override("panel", Ui.flat(Color("#f4f1ff"), 30, Color("#7ef0ff"), 3, 24, 14))
	_bubble.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_bubble.offset_right = -(16 + AVATAR_W + 4)
	_bubble.offset_left = _bubble.offset_right - 400
	_bubble.offset_top = 372 + Ui.inset_top
	_bubble.offset_bottom = _bubble.offset_top + 10
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.modulate = Color(1, 1, 1, 0)
	_bubble_label = Ui.label("", 32, Color("#241b63"), HORIZONTAL_ALIGNMENT_CENTER, true)
	_bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble_label.custom_minimum_size = Vector2(340, 0)
	_bubble.add_child(_bubble_label)
	add_child(_bubble)

	# centre: level / combo banner with a sub line
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
	_banner_sub = Ui.label("", 42, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
	_banner_sub.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.3, 0.9))
	_banner_sub.add_theme_constant_override("outline_size", 10)
	_banner_sub.set_anchors_preset(Control.PRESET_CENTER)
	_banner_sub.offset_left = -500
	_banner_sub.offset_right = 500
	_banner_sub.offset_top = -40
	_banner_sub.offset_bottom = 40
	_banner_sub.modulate = Color(1, 1, 1, 0)
	add_child(_banner_sub)

	# bottom action bar. HINT plays the best move at once; the others ask first.
	var bar_m := MarginContainer.new()
	bar_m.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar_m.offset_top = -260
	bar_m.offset_bottom = 0
	bar_m.add_theme_constant_override("margin_left", 24)
	bar_m.add_theme_constant_override("margin_right", 24)
	bar_m.add_theme_constant_override("margin_bottom", 30 + int(Ui.inset_bottom))
	bar_m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar_m)
	var bar := PanelContainer.new()
	bar.size_flags_vertical = Control.SIZE_SHRINK_END
	bar.add_theme_stylebox_override("panel", Ui.flat(Color(0.03, 0.04, 0.14, 0.88), 44, Color(0.45, 0.55, 1.0, 0.28), 2, 14, 14))
	bar_m.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	bar.add_child(row)
	row.add_child(_action("bulb", "HINT", "40", Color("#ffe14d"), _emit_hint, true))
	row.add_child(_action("moves", "+%d MOVES" % ProductionConfig.REWARD_EXTRA_MOVES, "30", Ui.PINK, _emit_moves))
	row.add_child(_action("tube", "+TUBE", "100", Ui.BLUE, _emit_tube))
	row.add_child(_action("diamond", "+CRYSTAL", "60", Ui.GREEN, _emit_crystal))

func _emit_pause() -> void:
	pause_pressed.emit()

func _emit_hint() -> void:
	hint_pressed.emit()

func _emit_moves() -> void:
	moves_pressed.emit()

func _emit_tube() -> void:
	tube_pressed.emit()

func _emit_crystal() -> void:
	crystal_pressed.emit()

func _emit_poked() -> void:
	avatar_poked.emit()

func _action(icon_name: String, text: String, cost: String, accent: Color, action: Callable, with_badge: bool = false) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 176)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_contents = true
	b.add_theme_stylebox_override("normal", Ui.flat(Color(accent, 0.14), 30, Color(accent, 0.55), 2, 0, 0))
	b.add_theme_stylebox_override("hover", Ui.flat(Color(accent, 0.24), 30, Color(accent, 0.8), 2, 0, 0))
	b.add_theme_stylebox_override("pressed", Ui.flat(Color(accent, 0.36), 30, Color(accent, 1.0), 2, 0, 0))
	b.add_theme_stylebox_override("disabled", Ui.flat(Color(accent, 0.06), 30, Color(accent, 0.2), 2, 0, 0))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.focus_mode = Control.FOCUS_NONE
	var v := VBoxContainer.new()
	Ui.full_rect(v)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 4)
	v.add_child(Ui.icon(icon_name, 60, accent))
	v.add_child(Ui.label(text, 25, Ui.TEXT, HORIZONTAL_ALIGNMENT_CENTER, true))
	var cr := HBoxContainer.new()
	cr.alignment = BoxContainer.ALIGNMENT_CENTER
	cr.add_theme_constant_override("separation", 5)
	cr.add_child(Ui.icon("coin", 24, Ui.GOLD))
	cr.add_child(Ui.label(cost, 24, Ui.GOLD, HORIZONTAL_ALIGNMENT_CENTER, true))
	cr.add_child(Ui.label("or", 21, Ui.TEXT_DIM))
	cr.add_child(Ui.icon("video", 25, Color(0.9, 0.5, 1.0)))
	v.add_child(cr)
	b.add_child(v)
	Ui.ignore_mouse(v)
	if with_badge:
		var badge := PanelContainer.new()
		badge.add_theme_stylebox_override("panel", Ui.flat(Ui.RED, 40, Color.WHITE, 2, 12, 2))
		badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		badge.offset_left = -64
		badge.offset_right = -8
		badge.offset_top = 8
		badge.offset_bottom = 52
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hint_badge = Ui.label("0", 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
		badge.add_child(_hint_badge)
		b.add_child(badge)
	Ui.hook_click(b)
	b.pressed.connect(action)
	_action_buttons.append(b)
	return b

# Disables the booster bar while a hint is playing or a popup is open.
func set_boosters_enabled(value: bool) -> void:
	for b in _action_buttons:
		if is_instance_valid(b):
			(b as Button).disabled = not value

func update_stats(level: int, moves: int, score: int, coins: int, hints: int) -> void:
	if _level_label != null:
		_level_label.text = "LEVEL %d" % level
	Ui.set_chip(_moves_chip, "%d" % moves)
	Ui.set_chip(_score_chip, "%d" % score)
	Ui.set_chip(_coin_chip, "%d" % coins)
	if _hint_badge != null:
		_hint_badge.text = str(hints)

# Theme name under the level title and one pill per twist (GOLD, SHADOW, CASCADE, BOSS).
func set_level_info(theme_name: String, twists: Array) -> void:
	if _theme_label != null:
		_theme_label.text = theme_name
	if _twist_row == null:
		return
	for c in _twist_row.get_children():
		_twist_row.remove_child(c)
		c.queue_free()
	for t in twists:
		var key: String = str(t)
		var col: Color = Twists.color_of(key)
		var pill := PanelContainer.new()
		pill.add_theme_stylebox_override("panel", Ui.flat(Color(col, 0.22), 30, Color(col, 0.9), 2, 16, 4))
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill.add_child(Ui.label(Twists.label(key), 24, col, HORIZONTAL_ALIGNMENT_CENTER, true))
		_twist_row.add_child(pill)

# Cass says something: speech bubble, body/face reaction, optional voice line.
func say(text: String, mood: String = "", voice: String = "") -> void:
	if _bubble == null:
		return
	if mood != "" and avatar != null:
		avatar.react(mood)
	if voice != "":
		voice_requested.emit(voice)
	_bubble_label.text = text
	if _bubble_tween != null and _bubble_tween.is_valid():
		_bubble_tween.kill()
	_bubble.modulate = Color(1, 1, 1, 0)
	_bubble_tween = create_tween()
	_bubble_tween.tween_property(_bubble, "modulate:a", 1.0, 0.16)
	_bubble_tween.tween_interval(2.3)
	_bubble_tween.tween_property(_bubble, "modulate:a", 0.0, 0.35)

func show_banner(title: String, color: Color = Color.WHITE, sub: String = "", sub_color: Color = Color.WHITE, hold: float = 1.1) -> void:
	if _banner == null:
		return
	_banner.text = title
	_banner.add_theme_color_override("font_color", color)
	_banner.pivot_offset = Vector2(500, 75)
	_banner.scale = Vector2(0.6, 0.6)
	_banner.modulate = Color(1, 1, 1, 0)
	_banner_sub.text = sub
	_banner_sub.add_theme_color_override("font_color", sub_color)
	_banner_sub.modulate = Color(1, 1, 1, 0)
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.set_parallel(true)
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.25)
	_banner_tween.tween_property(_banner, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_property(_banner_sub, "modulate:a", 1.0 if sub != "" else 0.0, 0.3)
	_banner_tween.chain().tween_interval(hold)
	_banner_tween.chain().tween_property(_banner, "modulate:a", 0.0, 0.4)
	_banner_tween.tween_property(_banner_sub, "modulate:a", 0.0, 0.4)

# A number that floats up from a point on screen (coins from a match, gold bonus ...).
func float_text(text: String, pos: Vector2, color: Color = Color.WHITE) -> void:
	var l := Ui.label(text, 54, color, HORIZONTAL_ALIGNMENT_CENTER, true)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 10)
	l.custom_minimum_size = Vector2(320, 72)
	l.position = pos - Vector2(160, 36)
	l.pivot_offset = Vector2(160, 36)
	l.scale = Vector2(0.6, 0.6)
	add_child(l)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 130.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.65)
	tw.chain().tween_callback(l.queue_free)
