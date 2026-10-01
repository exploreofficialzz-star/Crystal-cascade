class_name Modals
extends RefCounted

# Pop-up dialogs, all built in code with the shared UI kit. Each function adds an
# overlay to `parent` and returns it (free it with queue_free()).

static func _base(parent: Control, dim: float = 0.78) -> ColorRect:
	var ov := ColorRect.new()
	Ui.full_rect(ov)
	ov.color = Color(0, 0, 0, dim)
	parent.add_child(ov)
	var center := CenterContainer.new()
	Ui.full_rect(center)
	ov.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Ui.flat(Color(0.07, 0.09, 0.24, 0.98), 44, Color(0.45, 0.55, 1.0, 0.35), 2, 44, 44))
	panel.custom_minimum_size = Vector2(880, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	panel.add_child(box)
	ov.set_meta("box", box)
	return ov

static func _box(ov: ColorRect) -> VBoxContainer:
	return ov.get_meta("box") as VBoxContainer

static func _wrap(ov: Control, action: Callable) -> Callable:
	return func():
		if is_instance_valid(ov):
			ov.queue_free()
		if action.is_valid():
			action.call()

static func _text(msg: String) -> Label:
	var l := Ui.label(msg, 34, Color("#d8def8"))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(760, 0)
	return l

static func pause(parent: Control, on_resume: Callable, on_restart: Callable,
		on_levels: Callable, on_home: Callable) -> Control:
	var ov := _base(parent)
	var box := _box(ov)
	box.add_child(Ui.label("PAUSED", 72, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true))
	var resume := Ui.pill_button("RESUME", "pink", 136, 46, "play")
	resume.pressed.connect(_wrap(ov, on_resume))
	box.add_child(resume)
	var restart := Ui.glass_button("Restart", Ui.PURPLE, 116, 38, "restore")
	restart.pressed.connect(_wrap(ov, on_restart))
	box.add_child(restart)
	var levels := Ui.glass_button("Level Select", Ui.BLUE, 116, 38, "grid")
	levels.pressed.connect(_wrap(ov, on_levels))
	box.add_child(levels)
	var home := Ui.glass_button("Main Menu", Ui.GREY, 116, 38, "home")
	home.pressed.connect(_wrap(ov, on_home))
	box.add_child(home)
	return ov

static func confirm(parent: Control, title: String, message: String, ok_text: String,
		on_ok: Callable, danger: bool = true) -> Control:
	var ov := _base(parent, 0.82)
	var box := _box(ov)
	box.add_child(Ui.label(title, 56, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true))
	box.add_child(_text(message))
	var ok := Ui.pill_button(ok_text, "red" if danger else "pink", 128, 38)
	ok.pressed.connect(_wrap(ov, on_ok))
	box.add_child(ok)
	var cancel := Ui.glass_button("Cancel", Ui.GREY, 112, 36)
	cancel.pressed.connect(_wrap(ov, Callable()))
	box.add_child(cancel)
	return ov

static func message(parent: Control, title: String, text: String, button: String, on_close: Callable) -> Control:
	var ov := _base(parent, 0.82)
	var box := _box(ov)
	box.add_child(Ui.label(title, 56, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true))
	box.add_child(_text(text))
	var ok := Ui.pill_button(button, "pink", 128, 40)
	ok.pressed.connect(_wrap(ov, on_close))
	box.add_child(ok)
	return ov

static func tutorial(parent: Control, on_close: Callable) -> Control:
	var ov := _base(parent, 0.84)
	var box := _box(ov)
	box.add_child(Ui.label("HOW TO PLAY", 62, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true))
	var steps := [
		["1", "Tap a tube to lift its top crystal."],
		["2", "Tap a tube with the same colour on top, or an empty tube."],
		["3", "Line up 3 or more matching crystals to clear them."],
		["4", "Clear every tube to win. Fewer moves = more stars."],
		["5", "Drag on the table to look around, or use the camera button."],
	]
	for step in steps:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 22)
		var num := PanelContainer.new()
		num.custom_minimum_size = Vector2(64, 64)
		num.add_theme_stylebox_override("panel", Ui.flat(Ui.PURPLE, 40, Color(0, 0, 0, 0), 0, 0, 0))
		var cc := CenterContainer.new()
		num.add_child(cc)
		cc.add_child(Ui.label(step[0], 34, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true))
		row.add_child(num)
		var t := Ui.label(step[1], 32, Color("#d8def8"), HORIZONTAL_ALIGNMENT_LEFT)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(t)
		box.add_child(row)
	var ok := Ui.pill_button("GOT IT", "pink", 128, 42, "check")
	ok.pressed.connect(_wrap(ov, on_close))
	box.add_child(ok)
	return ov

# Shown when the player is out of lives and taps PLAY/RETRY.
static func no_lives(parent: Control, wait_text: String, rewarded_ready: bool,
		on_watch: Callable, on_close: Callable) -> Control:
	var ov := _base(parent, 0.82)
	var box := _box(ov)
	var hero := Ui.icon("heart", 130, Ui.RED)
	hero.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(hero)
	box.add_child(Ui.label("OUT OF LIVES", 58, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true))
	box.add_child(_text("Next life in %s." % wait_text))
	if rewarded_ready:
		var watch := Ui.pill_button("WATCH VIDEO: +1 LIFE", "pink", 128, 38, "video")
		watch.pressed.connect(_wrap(ov, on_watch))
		box.add_child(watch)
	var close := Ui.glass_button("OK", Ui.GREY, 112, 36)
	close.pressed.connect(_wrap(ov, on_close))
	box.add_child(close)
	return ov
