class_name LevelsScreen
extends Control

signal back_pressed
signal level_selected(id: int)

const COLUMNS := 4
const CARD_H := 190
const GAP := 14

var save: SaveData
var _scroll: ScrollContainer
var _pad: MarginContainer

func setup(save_data: SaveData) -> void:
	save = save_data
	Ui.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.background(self, "res://assets/images/bg_levelselect.jpg", 0.52)

	_pad = Ui.margin(self, 40, 36 + int(Ui.inset_top), 40, 24 + int(Ui.inset_bottom))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 26)
	_pad.add_child(col)

	var back := Ui.header(col, "Select Level")
	back.pressed.connect(func(): back_pressed.emit())

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", GAP)
	grid.add_theme_constant_override("v_separation", GAP)
	_scroll.add_child(grid)

	var highest := int(save.data.highest_unlocked)
	var total := maxi(100, highest + 16)
	for id in range(1, total + 1):
		grid.add_child(_card(id, highest))
	_scroll_to_current()

# Keeps the grid clear of the native banner ad.
func set_bottom_reserve(px: int) -> void:
	if _pad != null:
		_pad.add_theme_constant_override("margin_bottom", 24 + int(Ui.inset_bottom) + px)

func _scroll_to_current() -> void:
	await get_tree().process_frame
	if _scroll == null:
		return
	var row := int((int(save.data.highest_unlocked) - 1) / COLUMNS)
	_scroll.scroll_vertical = maxi(0, row * (CARD_H + GAP) - 420)

func _on_card(id: int) -> void:
	level_selected.emit(id)

func _card(id: int, highest: int) -> Control:
	var prog: Dictionary = save.level(id)
	var stars := clampi(int(prog.get("stars", 0)), 0, 3)
	var locked := id > highest
	var current := id == highest
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, CARD_H)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.focus_mode = Control.FOCUS_NONE
	var content := VBoxContainer.new()
	Ui.full_rect(content)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 6)
	b.add_child(content)
	if locked:
		var dark := Ui.flat(Color(0.03, 0.05, 0.14, 0.82), 30, Color(1, 1, 1, 0.07), 2, 0, 0)
		b.add_theme_stylebox_override("normal", dark)
		b.add_theme_stylebox_override("disabled", dark)
		b.disabled = true
		content.add_child(Ui.icon("lock", 58, Color(1, 1, 1, 0.40)))
		content.add_child(Ui.label(str(id), 30, Color(1, 1, 1, 0.35), HORIZONTAL_ALIGNMENT_CENTER, true))
	else:
		if current:
			b.add_theme_stylebox_override("normal", Ui.nine("res://assets/ui/btn_purple.png", 48))
			b.add_theme_stylebox_override("hover", Ui.nine("res://assets/ui/btn_purple.png", 48, Color(1.1, 1.1, 1.1)))
			b.add_theme_stylebox_override("pressed", Ui.nine("res://assets/ui/btn_purple.png", 48, Color(0.8, 0.8, 0.85)))
		else:
			b.add_theme_stylebox_override("normal", Ui.flat(Color(0.09, 0.15, 0.36, 0.88), 30, Color(0.4, 0.6, 1.0, 0.45), 2, 0, 0))
			b.add_theme_stylebox_override("hover", Ui.flat(Color(0.14, 0.22, 0.50, 0.92), 30, Color(0.5, 0.7, 1.0, 0.7), 2, 0, 0))
			b.add_theme_stylebox_override("pressed", Ui.flat(Color(0.06, 0.10, 0.26, 0.95), 30, Color(0.5, 0.7, 1.0, 0.7), 2, 0, 0))
		content.add_child(Ui.label(str(id), 54, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true))
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 4)
		for s in range(3):
			if s < stars:
				row.add_child(Ui.icon("star", 30, Ui.GOLD))
			else:
				row.add_child(Ui.icon("star_outline", 30, Color(1, 1, 1, 0.35)))
		content.add_child(row)
		Ui.hook_click(b)
		b.pressed.connect(_on_card.bind(id))
	Ui.ignore_mouse(content)
	return b
