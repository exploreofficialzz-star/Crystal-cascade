class_name SettingsScreen
extends Control

signal back_pressed
signal sound_toggled(value: bool)
signal music_toggled(value: bool)
signal vibration_toggled(value: bool)
signal voice_toggled(value: bool)
signal auto_camera_toggled(value: bool)
signal restore_pressed
signal reset_pressed
signal privacy_pressed
signal diagnostics_requested

var save: SaveData
var _version_taps := 0

func setup(save_data: SaveData) -> void:
	save = save_data
	Ui.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := Ui.gradient_rect(Color("#191a2f"), Color("#12294b"))
	Ui.full_rect(bg)
	add_child(bg)

	var pad := Ui.margin(self, 40, 36 + int(Ui.inset_top), 40, 24 + int(Ui.inset_bottom))
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 22)
	pad.add_child(outer)
	var back := Ui.header(outer, "Settings")
	back.pressed.connect(func(): back_pressed.emit())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 16)
	scroll.add_child(list)

	list.add_child(Ui.section_title("Audio"))
	list.add_child(_toggle("sound", "Sound Effects", bool(save.data.sound), func(v): sound_toggled.emit(v)))
	list.add_child(_toggle("music", "Music", bool(save.data.music), func(v): music_toggled.emit(v)))
	list.add_child(_toggle("vibrate", "Vibration", bool(save.data.vibration), func(v): vibration_toggled.emit(v)))
	list.add_child(_toggle("sound", "Cass's Voice", bool(save.data.voice), func(v): voice_toggled.emit(v)))

	list.add_child(Ui.section_title("Gameplay"))
	list.add_child(_toggle("camera", "Auto Camera", bool(save.data.auto_camera), func(v): auto_camera_toggled.emit(v)))

	list.add_child(Ui.section_title("Account"))
	list.add_child(_nav("restore", "Restore Purchases", Ui.TEXT, func(): restore_pressed.emit()))
	if ProductionConfig.PRIVACY_POLICY_URL != "":
		list.add_child(_nav("check", "Privacy Policy", Ui.TEXT, func(): privacy_pressed.emit()))
	list.add_child(_nav("trash", "Reset Progress", Ui.RED, func(): reset_pressed.emit()))

	list.add_child(Ui.section_title("About"))
	var version_row := _info("Version", ProductionConfig.VERSION_NAME)
	Ui.make_tappable(version_row, 28, _on_version_tapped)
	list.add_child(version_row)
	list.add_child(_info("Developer", "chAs"))
	list.add_child(_info("Package", ProductionConfig.PACKAGE_NAME))
	list.add_child(Ui.vspace(40))
	Ui.scroll_friendly(list)

func _on_version_tapped() -> void:
	_version_taps += 1
	if _version_taps >= 7:
		_version_taps = 0
		diagnostics_requested.emit()

func _row_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Ui.flat(Color(0.03, 0.05, 0.14, 0.72), 28, Color(0.45, 0.55, 1.0, 0.22), 2, 26, 22))
	return card

func _toggle(icon_name: String, text: String, value: bool, on_change: Callable) -> Control:
	var card := _row_card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	card.add_child(row)
	row.add_child(Ui.icon(icon_name, 52, Color(0.72, 0.75, 0.9)))
	var l := Ui.label(text, 36, Ui.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var sw := ToggleSwitch.new()
	sw.set_value(value)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sw.toggled.connect(_on_switch.bind(on_change))
	row.add_child(sw)
	return card

func _on_switch(value: bool, on_change: Callable) -> void:
	if Ui.sfx_target != null and Ui.sfx_target.has_method("ui_click"):
		Ui.sfx_target.call("ui_click")
	on_change.call(value)

func _nav(icon_name: String, text: String, color: Color, action: Callable) -> Control:
	var card := _row_card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	card.add_child(row)
	row.add_child(Ui.icon(icon_name, 50, color))
	var l := Ui.label(text, 36, color, HORIZONTAL_ALIGNMENT_LEFT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	row.add_child(Ui.icon("chevron_right", 42, Color(1, 1, 1, 0.45)))
	Ui.make_tappable(card, 28, action)
	Ui.ignore_mouse(row)
	return card

func _info(key: String, value: String) -> Control:
	var card := _row_card()
	var row := HBoxContainer.new()
	card.add_child(row)
	var k := Ui.label(key, 32, Ui.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT)
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(k)
	row.add_child(Ui.label(value, 32, Ui.TEXT, HORIZONTAL_ALIGNMENT_RIGHT, true))
	Ui.ignore_mouse(row)
	return card
