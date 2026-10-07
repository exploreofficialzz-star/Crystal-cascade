class_name HomeScreen
extends Control

signal play_pressed
signal levels_pressed
signal shop_pressed
signal settings_pressed
signal share_pressed
signal rewards_pressed

const BTN_H := 158.0
const BTN_GAP := 32.0
const BAR_H := 128.0

var save: SaveData
var _coin_chip: Control
var _life_chip: Control

# Layout: coins | daily reward | lives across the top, the logo above the centred
# PLAY / LEVELS / SHOP block, a chest + streak strip under it, and
# settings | stars | share along the bottom.
func setup(save_data: SaveData) -> void:
	save = save_data
	Ui.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.background(self, "res://assets/images/bg_menu.jpg", 0.0)
	_shade()

	var vs: Vector2 = get_viewport_rect().size
	var h: float = vs.y
	var top_y: float = 44.0 + Ui.inset_top
	var bottom_y: float = h - 44.0 - Ui.inset_bottom - BAR_H

	# ── top row: coins (left), daily reward (centre), lives (right) ──
	var top := Control.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 44
	top.offset_right = -44
	top.offset_top = top_y
	top.offset_bottom = top_y + BAR_H
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	_coin_chip = Ui.chip("coin", str(int(save.data.coins)), Ui.GOLD)
	top.add_child(_coin_chip)
	_coin_chip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE)
	_life_chip = Ui.chip("heart", _lives_text(), Ui.RED)
	top.add_child(_life_chip)
	_life_chip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE)
	var rewards := Ui.circle_button("gift", int(BAR_H), Ui.GOLD)
	rewards.pressed.connect(func(): rewards_pressed.emit())
	top.add_child(rewards)
	rewards.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	if Rewards.claimable(save):
		rewards.add_child(_badge_dot(true))
		_wiggle(rewards)

	# ── centred menu block ──
	var blk_h: float = BTN_H * 3.0 + BTN_GAP * 2.0
	var blk_top: float = h * 0.5 - blk_h * 0.5

	var logo_top: float = top_y + BAR_H + 6.0
	var logo_bottom: float = blk_top - 70.0
	var logo_h: float = clampf(logo_bottom - logo_top, 300.0, 560.0)
	var logo_y: float = logo_top + maxf(0.0, (logo_bottom - logo_top - logo_h) * 0.5)
	var logo := TextureRect.new()
	logo.texture = Ui.tex("res://assets/images/game_logo.png")
	logo.set_anchors_preset(Control.PRESET_TOP_WIDE)
	logo.offset_top = logo_y
	logo.offset_bottom = logo_y + logo_h
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logo)
	var by := Ui.label("by chAs", 34, Color(0.75, 0.78, 0.95, 0.85))
	by.set_anchors_preset(Control.PRESET_TOP_WIDE)
	by.offset_top = logo_y + logo_h - 4.0
	by.offset_bottom = logo_y + logo_h + 44.0
	add_child(by)

	var buttons := VBoxContainer.new()
	buttons.set_anchors_preset(Control.PRESET_TOP_WIDE)
	buttons.offset_left = 120
	buttons.offset_right = -120
	buttons.offset_top = blk_top
	buttons.offset_bottom = blk_top + blk_h
	buttons.add_theme_constant_override("separation", int(BTN_GAP))
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(buttons)

	var play := Ui.pill_button("PLAY", "pink", int(BTN_H), 52, "play")
	play.pressed.connect(func(): play_pressed.emit())
	buttons.add_child(play)
	var lvl_tag := Ui.label("LEVEL %d" % int(save.data.highest_unlocked), 32, Color(1, 1, 1, 0.92), HORIZONTAL_ALIGNMENT_RIGHT, true)
	lvl_tag.add_theme_color_override("font_outline_color", Color(0.3, 0.0, 0.4, 0.8))
	lvl_tag.add_theme_constant_override("outline_size", 6)
	play.add_child(lvl_tag)
	lvl_tag.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, 40)
	var levels := Ui.pill_button("LEVELS", "blue", int(BTN_H), 52, "grid")
	levels.pressed.connect(func(): levels_pressed.emit())
	buttons.add_child(levels)
	var shop := Ui.pill_button("SHOP", "gold", int(BTN_H), 52, "bag")
	shop.pressed.connect(func(): shop_pressed.emit())
	buttons.add_child(shop)
	if save.can_claim_daily_bonus():
		shop.add_child(_badge_dot())
	Ui.pulse(play, 0.025, 1.0)

	# ── chest + streak strip under the buttons ──
	var strip_y: float = blk_top + blk_h + 52.0
	var strip := PanelContainer.new()
	strip.set_anchors_preset(Control.PRESET_TOP_WIDE)
	strip.offset_left = 120
	strip.offset_right = -120
	strip.offset_top = strip_y
	strip.offset_bottom = strip_y + 110.0
	strip.add_theme_stylebox_override("panel", Ui.flat(Color(0.03, 0.04, 0.14, 0.80), 40, Color(Ui.GOLD, 0.40), 2, 30, 14))
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(strip)
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 14)
	srow.alignment = BoxContainer.ALIGNMENT_CENTER
	srow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(srow)
	var wins_left: int = save.wins_to_chest()
	srow.add_child(Ui.icon("chest", 56, Ui.GOLD))
	var chest_text := "Chest ready!" if wins_left <= 0 else "Chest in %d win%s" % [wins_left, "" if wins_left == 1 else "s"]
	srow.add_child(Ui.label(chest_text, 32, Ui.TEXT, HORIZONTAL_ALIGNMENT_LEFT, true))
	srow.add_child(Ui.hspace_expand())
	var streak: int = int(save.data.win_streak)
	var hot: Color = Color("#ff944d") if streak > 0 else Ui.TEXT_DIM
	srow.add_child(Ui.icon("flame", 52, hot))
	srow.add_child(Ui.label("x%d" % streak, 34, hot, HORIZONTAL_ALIGNMENT_LEFT, true))

	# ── bottom row: settings | stars | share ──
	var bottom := Control.new()
	bottom.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bottom.offset_left = 44
	bottom.offset_right = -44
	bottom.offset_top = bottom_y
	bottom.offset_bottom = bottom_y + BAR_H
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)
	var settings := Ui.circle_button("gear", int(BAR_H))
	settings.pressed.connect(func(): settings_pressed.emit())
	bottom.add_child(settings)
	settings.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE)
	var stars := Ui.chip("star", str(int(save.data.total_stars)), Ui.GOLD, 40)
	bottom.add_child(stars)
	stars.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	var share := Ui.circle_button("share", int(BAR_H))
	share.pressed.connect(func(): share_pressed.emit())
	bottom.add_child(share)
	share.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE)

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

# A claimable reward shakes every couple of seconds to pull the eye.
func _wiggle(c: Control) -> void:
	c.pivot_offset = c.size / 2.0
	c.resized.connect(func(): c.pivot_offset = c.size / 2.0)
	var tw := c.create_tween().set_loops()
	tw.tween_interval(1.8)
	tw.tween_property(c, "rotation", 0.2, 0.07)
	tw.tween_property(c, "rotation", -0.2, 0.12)
	tw.tween_property(c, "rotation", 0.13, 0.10)
	tw.tween_property(c, "rotation", -0.08, 0.08)
	tw.tween_property(c, "rotation", 0.0, 0.08)

func _shade() -> void:
	var top := Ui.gradient_rect(Color(0.02, 0.02, 0.08, 0.72), Color(0.02, 0.02, 0.08, 0.0))
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 0
	top.offset_bottom = 380
	add_child(top)
	var bottom := Ui.gradient_rect(Color(0.02, 0.02, 0.08, 0.0), Color(0.02, 0.02, 0.08, 0.78))
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -560
	bottom.offset_bottom = 0
	add_child(bottom)
