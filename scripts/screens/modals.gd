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

# "Use coins or watch a video" choice for HINT / +MOVES / +TUBE.
static func powerup(parent: Control, icon_name: String, accent: Color, title: String, desc: String,
		coin_text: String, coin_costs: bool, coin_enabled: bool, watch_enabled: bool,
		on_coins: Callable, on_watch: Callable, on_cancel: Callable) -> Control:
	var ov := _base(parent, 0.82)
	var box := _box(ov)
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(150, 150)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	badge.add_theme_stylebox_override("panel", Ui.flat(Color(accent, 0.25), 80, Color(accent, 0.6), 3, 0, 0))
	var cc := CenterContainer.new()
	badge.add_child(cc)
	cc.add_child(Ui.icon(icon_name, 84, accent))
	box.add_child(badge)
	box.add_child(Ui.label(title, 56, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true))
	box.add_child(_text(desc))
	var coins := Ui.pill_button(coin_text, "gold", 128, 38, "coin" if coin_costs else "bulb")
	coins.disabled = not coin_enabled
	coins.pressed.connect(_wrap(ov, on_coins))
	box.add_child(coins)
	if not coin_enabled:
		box.add_child(Ui.label("Not enough coins", 28, Ui.RED))
	var watch := Ui.pill_button("WATCH VIDEO  ·  FREE" if watch_enabled else "Video not ready", "pink", 128, 38, "video")
	watch.disabled = not watch_enabled
	watch.pressed.connect(_wrap(ov, on_watch))
	box.add_child(watch)
	var cancel := Ui.glass_button("Cancel", Ui.GREY, 108, 34)
	cancel.pressed.connect(_wrap(ov, on_cancel))
	box.add_child(cancel)
	return ov

# Daily login popup shown at launch.
static func daily_login(parent: Control, day: int, reward_text: String, reward_icon: String,
		can_double: bool, on_claim: Callable, on_double: Callable) -> Control:
	var ov := _base(parent, 0.84)
	var box := _box(ov)
	var flame := Ui.icon("flame", 130, Color("#ffb347"))
	flame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(flame)
	box.add_child(Ui.label("DAY %d  ·  DAILY REWARD" % day, 48, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true))
	var dots := HBoxContainer.new()
	dots.alignment = BoxContainer.ALIGNMENT_CENTER
	dots.add_theme_constant_override("separation", 14)
	for i in range(1, 8):
		var d := Panel.new()
		d.custom_minimum_size = Vector2(34, 34)
		var on := i <= day
		d.add_theme_stylebox_override("panel", Ui.flat(Ui.GOLD if on else Color(1, 1, 1, 0.14), 40, Color(0, 0, 0, 0), 0, 0, 0))
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dots.add_child(d)
	box.add_child(dots)
	var rw := HBoxContainer.new()
	rw.alignment = BoxContainer.ALIGNMENT_CENTER
	rw.add_theme_constant_override("separation", 16)
	rw.add_child(Ui.icon(reward_icon, 64, Ui.GOLD))
	rw.add_child(Ui.label(reward_text, 56, Ui.GOLD, HORIZONTAL_ALIGNMENT_CENTER, true))
	box.add_child(rw)
	var claim := Ui.pill_button("CLAIM", "pink", 132, 44, "gift")
	claim.pressed.connect(_wrap(ov, on_claim))
	box.add_child(claim)
	if can_double:
		var dbl := Ui.pill_button("WATCH VIDEO: DOUBLE IT", "gold", 120, 34, "video")
		dbl.pressed.connect(_wrap(ov, on_double))
		box.add_child(dbl)
	return ov

# Treasure chest after every third win.
static func chest(parent: Control, reward_text: String, reward_icon: String,
		can_double: bool, on_collect: Callable, on_double: Callable) -> Control:
	var ov := _base(parent, 0.84)
	var box := _box(ov)
	var hero := Ui.icon("chest", 170, Color("#ffcf5a"))
	hero.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hero.pivot_offset = Vector2(85, 85)
	box.add_child(hero)
	var tw := hero.create_tween()
	tw.set_loops(3)
	tw.tween_property(hero, "rotation", 0.12, 0.09)
	tw.tween_property(hero, "rotation", -0.12, 0.18)
	tw.tween_property(hero, "rotation", 0.0, 0.09)
	box.add_child(Ui.label("TREASURE CHEST!", 56, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true))
	box.add_child(_text("You cleared 3 levels. Here is your prize:"))
	var rw := HBoxContainer.new()
	rw.alignment = BoxContainer.ALIGNMENT_CENTER
	rw.add_theme_constant_override("separation", 16)
	rw.add_child(Ui.icon(reward_icon, 64, Ui.GOLD))
	rw.add_child(Ui.label(reward_text, 56, Ui.GOLD, HORIZONTAL_ALIGNMENT_CENTER, true))
	box.add_child(rw)
	var collect := Ui.pill_button("COLLECT", "pink", 132, 44, "check")
	collect.pressed.connect(_wrap(ov, on_collect))
	box.add_child(collect)
	if can_double:
		var dbl := Ui.pill_button("WATCH VIDEO: DOUBLE IT", "gold", 120, 34, "video")
		dbl.pressed.connect(_wrap(ov, on_double))
		box.add_child(dbl)
	return ov
