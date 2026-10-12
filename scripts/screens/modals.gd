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
		["3", "Line up 3 matching crystals to clear them."],
		["4", "Clear every crystal to win. Fewer moves = more stars."],
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

# Treasure chest after every third win (and a bigger one after every boss level).
static func chest(parent: Control, reward_text: String, reward_icon: String,
		can_double: bool, on_collect: Callable, on_double: Callable,
		title: String = "TREASURE CHEST!", sub: String = "You cleared a few levels in a row. Here is your prize:") -> Control:
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
	box.add_child(Ui.label(title, 56, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true))
	box.add_child(_text(sub))
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

# Out of hints: watch a video, visit the shop or finish a daily task.
static func get_more(parent: Control, icon_name: String, accent: Color, title: String, desc: String,
		watch_text: String, watch_enabled: bool, on_watch: Callable, on_shop: Callable,
		on_tasks: Callable, on_cancel: Callable) -> Control:
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
	var watch := Ui.pill_button(watch_text if watch_enabled else "Video not ready", "pink", 128, 38, "video")
	watch.disabled = not watch_enabled
	watch.pressed.connect(_wrap(ov, on_watch))
	box.add_child(watch)
	var shop := Ui.pill_button("GO TO SHOP", "gold", 128, 38, "bag")
	shop.pressed.connect(_wrap(ov, on_shop))
	box.add_child(shop)
	var tasks := Ui.pill_button("DAILY TASKS", "blue", 128, 38, "gift")
	tasks.pressed.connect(_wrap(ov, on_tasks))
	box.add_child(tasks)
	var cancel := Ui.glass_button("Not now", Ui.GREY, 108, 34)
	cancel.pressed.connect(_wrap(ov, on_cancel))
	box.add_child(cancel)
	return ov

# First time a twist (gold, cascade, shadow, boss) shows up: a short introduction.
static func twist_intro(parent: Control, title: String, text: String, accent: Color, on_close: Callable) -> Control:
	var ov := _base(parent, 0.80)
	var box := _box(ov)
	var tag := PanelContainer.new()
	tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tag.add_theme_stylebox_override("panel", Ui.flat(Color(accent, 0.25), 40, Color(accent, 0.95), 3, 30, 8))
	tag.add_child(Ui.label("NEW", 36, accent, HORIZONTAL_ALIGNMENT_CENTER, true))
	box.add_child(tag)
	box.add_child(Ui.label(title, 56, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true))
	box.add_child(_text(text))
	var ok := Ui.pill_button("LET'S GO", "pink", 128, 42, "play")
	ok.pressed.connect(_wrap(ov, on_close))
	box.add_child(ok)
	return ov

# +CRYSTAL: pick which colour to conjure (only colours on the board are offered).
# options: [{"idx": int, "color": Color, "name": String, "enabled": bool}, ...]
# on_coins / on_watch receive the chosen colour index.
static func crystal_picker(parent: Control, options: Array, coin_text: String, coin_enabled: bool,
		watch_enabled: bool, per_ad: int, on_coins: Callable, on_watch: Callable,
		on_shop: Callable, on_tasks: Callable, on_cancel: Callable) -> Control:
	var ov := _base(parent, 0.82)
	var box := _box(ov)
	var accent := Color("#7ef0ff")
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(130, 130)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	badge.add_theme_stylebox_override("panel", Ui.flat(Color(accent, 0.25), 70, Color(accent, 0.6), 3, 0, 0))
	var cc := CenterContainer.new()
	badge.add_child(cc)
	cc.add_child(Ui.icon("diamond", 74, accent))
	box.add_child(badge)
	box.add_child(Ui.label("CONJURE CRYSTALS", 54, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true))
	box.add_child(_text("Pick a colour from your board. It lands on a matching crystal and finishes the match."))

	var state := {"sel": -1}
	var chips: Array = []
	var name_label := Ui.label("", 34, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	for opt in options:
		var o: Dictionary = opt
		var chip := PanelContainer.new()
		chip.custom_minimum_size = Vector2(96, 96)
		var enabled: bool = bool(o.get("enabled", true))
		if enabled and int(state["sel"]) < 0:
			state["sel"] = int(o["idx"])
		chips.append({"panel": chip, "idx": int(o["idx"]), "color": o["color"], "name": str(o["name"]), "enabled": enabled})
		row.add_child(chip)
	var refresh := func() -> void:
		for c in chips:
			var cd: Dictionary = c
			var picked: bool = int(cd["idx"]) == int(state["sel"])
			var col: Color = cd["color"]
			if not bool(cd["enabled"]):
				col = Color(col.r, col.g, col.b, 0.28)
			var panel: PanelContainer = cd["panel"]
			panel.add_theme_stylebox_override("panel", Ui.flat(col, 52, Color.WHITE if picked else Color(1, 1, 1, 0.25), 6 if picked else 2, 0, 0))
			if picked:
				name_label.text = str(cd["name"])
	for c in chips:
		var cd: Dictionary = c
		if bool(cd["enabled"]):
			var idx: int = int(cd["idx"])
			var choose := func() -> void:
				state["sel"] = idx
				refresh.call()
			Ui.make_tappable(cd["panel"], 52, choose)
	refresh.call()
	box.add_child(name_label)

	var coins := Ui.pill_button(coin_text, "gold", 128, 38, "coin")
	coins.disabled = not coin_enabled or int(state["sel"]) < 0
	var coins_go := func() -> void:
		if is_instance_valid(ov):
			ov.queue_free()
		if on_coins.is_valid():
			on_coins.call(int(state["sel"]))
	coins.pressed.connect(coins_go)
	box.add_child(coins)
	if not coin_enabled:
		box.add_child(Ui.label("Not enough coins", 28, Ui.RED))
	var watch := Ui.pill_button("WATCH VIDEO: +%d CRYSTALS" % per_ad if watch_enabled else "Video not ready", "pink", 128, 38, "video")
	watch.disabled = not watch_enabled or int(state["sel"]) < 0
	var watch_go := func() -> void:
		if is_instance_valid(ov):
			ov.queue_free()
		if on_watch.is_valid():
			on_watch.call(int(state["sel"]))
	watch.pressed.connect(watch_go)
	box.add_child(watch)
	if not coin_enabled:
		var more := HBoxContainer.new()
		more.add_theme_constant_override("separation", 14)
		var shop := Ui.glass_button("Shop", Ui.GOLD, 100, 32, "bag")
		shop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		shop.pressed.connect(_wrap(ov, on_shop))
		more.add_child(shop)
		var tasks := Ui.glass_button("Daily Tasks", Ui.BLUE, 100, 32, "gift")
		tasks.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tasks.pressed.connect(_wrap(ov, on_tasks))
		more.add_child(tasks)
		box.add_child(more)
	var cancel := Ui.glass_button("Cancel", Ui.GREY, 108, 34)
	cancel.pressed.connect(_wrap(ov, on_cancel))
	box.add_child(cancel)
	return ov

# Welcome back after a few days away.
static func comeback(parent: Control, away_days: int, reward_text: String, can_double: bool,
		on_claim: Callable, on_double: Callable) -> Control:
	var ov := _base(parent, 0.84)
	var box := _box(ov)
	var hero := Ui.icon("gift", 150, Color("#7ef0ff"))
	hero.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(hero)
	box.add_child(Ui.label("WELCOME BACK!", 58, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true))
	box.add_child(_text("The crystals missed you for %d days. Here is a little thank-you:" % away_days))
	box.add_child(Ui.label(reward_text, 52, Ui.GOLD, HORIZONTAL_ALIGNMENT_CENTER, true))
	var claim := Ui.pill_button("CLAIM", "pink", 132, 44, "gift")
	claim.pressed.connect(_wrap(ov, on_claim))
	box.add_child(claim)
	if can_double:
		var dbl := Ui.pill_button("WATCH VIDEO: DOUBLE IT", "gold", 120, 34, "video")
		dbl.pressed.connect(_wrap(ov, on_double))
		box.add_child(dbl)
	return ov

# Soft ask shown once before the system notification permission prompt.
static func reminders_ask(parent: Control, on_yes: Callable, on_no: Callable) -> Control:
	var ov := _base(parent, 0.84)
	var box := _box(ov)
	var hero := Ui.icon("clock", 130, Color("#ffb347"))
	hero.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(hero)
	box.add_child(Ui.label("STAY IN THE LOOP?", 54, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true))
	box.add_child(_text("Get a nudge when your lives are full, your daily reward is ready or your streak is at risk. No spam. Change it any time in Settings."))
	var yes := Ui.pill_button("YES, REMIND ME", "pink", 132, 44, "check")
	yes.pressed.connect(_wrap(ov, on_yes))
	box.add_child(yes)
	var no := Ui.glass_button("Not now", Ui.GREY, 108, 34)
	no.pressed.connect(_wrap(ov, on_no))
	box.add_child(no)
	return ov

# Daily gift pick: three sealed gifts, tap one (on_pick gets 0..2).
static func gift_pick(parent: Control, free_pick: bool, on_pick: Callable, on_close: Callable) -> Control:
	var ov := _base(parent, 0.86)
	var box := _box(ov)
	box.add_child(Ui.label("DAILY GIFT", 58, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true))
	box.add_child(_text("Pick one sealed gift!" if free_pick else "Watch a video to open another gift."))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	box.add_child(row)
	var accents := [Color("#ff7ad9"), Color("#7ef0ff"), Color("#ffd34e")]
	for i in range(3):
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(230, 260)
		card.add_theme_stylebox_override("panel", Ui.flat(Color(accents[i], 0.16), 40, Color(accents[i], 0.9), 4, 20, 20))
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 10)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(v)
		var ic := Ui.icon("gift", 120, accents[i])
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ic)
		v.add_child(Ui.label("TAP", 30, accents[i], HORIZONTAL_ALIGNMENT_CENTER, true))
		var idx: int = i
		var pick_go := func() -> void:
			if is_instance_valid(ov):
				ov.queue_free()
			if on_pick.is_valid():
				on_pick.call(idx)
		Ui.make_tappable(card, 40, pick_go)
		row.add_child(card)
	var close := Ui.glass_button("Close", Ui.GREY, 108, 34)
	close.pressed.connect(_wrap(ov, on_close))
	box.add_child(close)
	return ov
