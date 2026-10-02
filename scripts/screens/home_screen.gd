class_name HomeScreen
extends Control

signal play_pressed
signal levels_pressed
signal shop_pressed
signal settings_pressed
signal share_pressed
signal rewards_pressed

var save: SaveData
var _coin_chip: Control
var _life_chip: Control

func setup(save_data: SaveData) -> void:
	save = save_data
	Ui.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.background(self, "res://assets/images/bg_menu.jpg", 0.0)
	_shade()

	var m := Ui.margin(self, 44, 44 + int(Ui.inset_top), 44, 44 + int(Ui.inset_bottom))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	m.add_child(col)

	# top row: coins (left) and lives (right)
	var top := HBoxContainer.new()
	_coin_chip = Ui.chip("coin", str(int(save.data.coins)), Ui.GOLD)
	top.add_child(_coin_chip)
	top.add_child(Ui.hspace_expand())
	_life_chip = Ui.chip("heart", _lives_text(), Ui.RED)
	top.add_child(_life_chip)
	col.add_child(top)

	var s1 := Control.new()
	s1.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s1.size_flags_stretch_ratio = 1.0
	s1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(s1)

	var logo := TextureRect.new()
	logo.texture = Ui.tex("res://assets/images/game_logo.png")
	logo.custom_minimum_size = Vector2(0, 520)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(logo)
	col.add_child(Ui.label("by chAs", 34, Color(0.75, 0.78, 0.95, 0.85)))

	var s2 := Control.new()
	s2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s2.size_flags_stretch_ratio = 1.7
	s2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(s2)

	var bm := MarginContainer.new()
	bm.add_theme_constant_override("margin_left", 120)
	bm.add_theme_constant_override("margin_right", 120)
	bm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(bm)
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 32)
	bm.add_child(buttons)

	var play := Ui.pill_button("PLAY", "pink", 158, 52, "play")
	play.pressed.connect(func(): play_pressed.emit())
	buttons.add_child(play)
	var levels := Ui.pill_button("LEVELS", "blue", 158, 52, "grid")
	levels.pressed.connect(func(): levels_pressed.emit())
	buttons.add_child(levels)
	var shop := Ui.pill_button("SHOP", "gold", 158, 52, "bag")
	shop.pressed.connect(func(): shop_pressed.emit())
	buttons.add_child(shop)
	if save.can_claim_daily_bonus():
		shop.add_child(_badge_dot())
	Ui.pulse(play, 0.025, 1.0)

	col.add_child(Ui.vspace(64))

	# bottom row: settings, stars, share
	var bottom := HBoxContainer.new()
	var settings := Ui.circle_button("gear", 128)
	settings.pressed.connect(func(): settings_pressed.emit())
	bottom.add_child(settings)
	bottom.add_child(Ui.vspace(1))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(18, 0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(gap)
	var rewards := Ui.circle_button("gift", 128, Ui.GOLD)
	rewards.pressed.connect(func(): rewards_pressed.emit())
	if Rewards.claimable(save):
		rewards.add_child(_badge_dot(true))
	bottom.add_child(rewards)
	bottom.add_child(Ui.hspace_expand())
	var stars := Ui.chip("star", str(int(save.data.total_stars)), Ui.GOLD, 40)
	bottom.add_child(stars)
	bottom.add_child(Ui.hspace_expand())
	var share := Ui.circle_button("share", 128)
	share.pressed.connect(func(): share_pressed.emit())
	bottom.add_child(share)
	col.add_child(bottom)

func _lives_text() -> String:
	var lives := int(save.data.lives)
	var t := "%d/5" % lives
	var wait := save.seconds_to_next_life()
	if lives < 5 and wait > 0:
		t += "  %s" % Ui.format_duration(wait)
	return t

func _badge_dot(on_circle: bool = false) -> Control:
	var dot := Panel.new()
	dot.add_theme_stylebox_override("panel", Ui.flat(Ui.RED, 40, Color.WHITE, 3, 0, 0))
	dot.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	dot.offset_left = -40 if on_circle else -70
	dot.offset_right = -6 if on_circle else -34
	dot.offset_top = 4 if on_circle else 22
	dot.offset_bottom = 38 if on_circle else 58
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return dot

func _shade() -> void:
	var top := Ui.gradient_rect(Color(0.02, 0.02, 0.08, 0.72), Color(0.02, 0.02, 0.08, 0.0))
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 0
	top.offset_bottom = 380
	add_child(top)
	var bottom := Ui.gradient_rect(Color(0.02, 0.02, 0.08, 0.0), Color(0.02, 0.02, 0.08, 0.78))
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -820
	bottom.offset_bottom = 0
	add_child(bottom)
