class_name SplashScreen
extends Control

# Launch screen: studio line, animated logo, loading bar with status text and a
# gameplay tip. main.gd steps the bar while it preloads art/sound, builds the 3D
# world and warms up the shaders, so the first level starts without a hitch.

const TIPS := [
	"Match 3 or more crystals of the same colour to clear them.",
	"Empty tubes are your best friend. Keep one free!",
	"Drag on the table to look around. Cass films the match for you.",
	"Tap Cass to make her wave. She loves attention.",
	"Combos pay extra coins: chain your matches!",
	"Come back every day: login streaks reach a big reward on day 7.",
	"Finish quests each day for free hints and lives.",
	"Stuck? A hint shows a good move, or watch a video for a free one.",
]

var _fill: Panel
var _pct: Label
var _status: Label
var _logo: TextureRect
var _target := 0.0
var _shown := 0.0

func setup() -> void:
	Ui.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	Ui.background(self, "res://assets/images/bg_menu.jpg", 0.32)
	var top := Ui.gradient_rect(Color(0.02, 0.02, 0.08, 0.80), Color(0.02, 0.02, 0.08, 0.0))
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 420
	add_child(top)
	var bottom := Ui.gradient_rect(Color(0.02, 0.02, 0.08, 0.0), Color(0.02, 0.02, 0.08, 0.88))
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -760
	add_child(bottom)
	_sparkles()

	var m := Ui.margin(self, 70, 70 + int(Ui.inset_top), 70, 56 + int(Ui.inset_bottom))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	m.add_child(col)

	var studio := Ui.label("c h A s   T E C H   G R O U P", 28, Color(0.80, 0.84, 1.0, 0.85), HORIZONTAL_ALIGNMENT_CENTER, true)
	studio.modulate = Color(1, 1, 1, 0)
	col.add_child(studio)
	var s_tw := studio.create_tween()
	s_tw.tween_property(studio, "modulate:a", 1.0, 0.8)

	var s1 := Control.new()
	s1.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(s1)

	_logo = TextureRect.new()
	_logo.texture = Ui.tex("res://assets/images/game_logo.png")
	_logo.custom_minimum_size = Vector2(0, 560)
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo.modulate = Color(1, 1, 1, 0)
	_logo.pivot_offset = Vector2(470, 280)
	_logo.scale = Vector2(0.86, 0.86)
	col.add_child(_logo)
	var l_tw := _logo.create_tween()
	l_tw.set_parallel(true)
	l_tw.tween_property(_logo, "modulate:a", 1.0, 0.9)
	l_tw.tween_property(_logo, "scale", Vector2.ONE, 1.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var s2 := Control.new()
	s2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s2.size_flags_stretch_ratio = 1.4
	s2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(s2)

	# loading bar
	var track := Panel.new()
	track.custom_minimum_size = Vector2(0, 30)
	track.add_theme_stylebox_override("panel", Ui.flat(Color(0.03, 0.04, 0.12, 0.85), 15, Color(0.5, 0.6, 1.0, 0.40), 2, 0, 0))
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(track)
	_fill = Panel.new()
	_fill.add_theme_stylebox_override("panel", Ui.nine("res://assets/ui/btn_pink.png", 24))
	_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fill.anchor_right = 0.02
	_fill.offset_left = 3
	_fill.offset_top = 3
	_fill.offset_bottom = -3
	_fill.offset_right = -3
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(_fill)

	col.add_child(Ui.vspace(18))
	var row := HBoxContainer.new()
	_status = Ui.label("Starting…", 32, Color(0.85, 0.88, 1.0), HORIZONTAL_ALIGNMENT_LEFT)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_status)
	_pct = Ui.label("0%", 32, Ui.GOLD, HORIZONTAL_ALIGNMENT_RIGHT, true)
	row.add_child(_pct)
	col.add_child(row)

	col.add_child(Ui.vspace(36))
	var tip := Ui.label("TIP:  " + TIPS[randi() % TIPS.size()], 30, Color(0.70, 0.75, 0.95, 0.9))
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(tip)
	col.add_child(Ui.vspace(54))
	col.add_child(Ui.label("v%s" % ProductionConfig.VERSION_NAME, 26, Color(0.55, 0.6, 0.8, 0.8)))

func _sparkles() -> void:
	var p := CPUParticles2D.new()
	p.position = Vector2(540, 2100)
	p.amount = 36
	p.lifetime = 5.0
	p.preprocess = 4.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(540, 20)
	p.direction = Vector2(0, -1)
	p.spread = 18.0
	p.gravity = Vector2(0, 0)
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 260.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 8.0
	p.color = Color(0.8, 0.9, 1.0, 0.75)
	add_child(p)
	p.emitting = true

func set_progress(value: float, status: String = "") -> void:
	_target = clampf(value, 0.0, 1.0)
	if status != "" and _status != null:
		_status.text = status

func is_done() -> bool:
	return _shown >= 0.995

func _process(delta: float) -> void:
	_shown = lerpf(_shown, _target, 1.0 - exp(-delta * 5.0))
	if _target >= 1.0 and _shown > 0.985:
		_shown = 1.0
	if _fill != null:
		_fill.anchor_right = clampf(_shown, 0.03, 1.0)
	if _pct != null:
		_pct.text = "%d%%" % int(round(_shown * 100.0))

func fade_out() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	tw.tween_callback(queue_free)
