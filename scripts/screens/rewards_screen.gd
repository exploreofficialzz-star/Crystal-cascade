class_name RewardsScreen
extends Control

# Daily rewards hub: 7-day login streak, 3 daily quests, star milestones.
signal back_pressed
signal claim_login_pressed
signal claim_quest_pressed(id: String)
signal claim_milestone_pressed(stars: int)

var save: SaveData
var _scroll: ScrollContainer

func setup(save_data: SaveData) -> void:
	save = save_data
	save.ensure_quests()
	Ui.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := Ui.gradient_rect(Color("#191a2f"), Color("#34205f"))
	Ui.full_rect(bg)
	add_child(bg)

	var scroll := ScrollContainer.new()
	_scroll = scroll
	Ui.full_rect(scroll)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_theme_constant_override("margin_left", 40)
	m.add_theme_constant_override("margin_right", 40)
	m.add_theme_constant_override("margin_top", 36 + int(Ui.inset_top))
	m.add_theme_constant_override("margin_bottom", 70 + int(Ui.inset_bottom))
	scroll.add_child(m)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 18)
	m.add_child(list)

	var head := HBoxContainer.new()
	head.add_child(Ui.vspace(1))
	var title := Ui.label("Rewards", 54, Ui.TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	title.custom_minimum_size = Vector2(0, 112)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(138, 0)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(pad)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	list.add_child(head)

	_login_card(list)
	list.add_child(Ui.section_title("Daily Quests  ·  resets in %s" % Ui.format_duration(save.seconds_to_next_day())))
	for q in Rewards.quests_for(save.today()):
		list.add_child(_quest_card(q))
	list.add_child(Ui.section_title("Star Milestones  ·  %d ★ collected" % int(save.data.total_stars)))
	for ms in Rewards.MILESTONES:
		list.add_child(_milestone_card(ms))
	Ui.scroll_friendly(list)

	# floating back button (stays put while the list scrolls)
	var back := Ui.circle_button("back", 112)
	back.set_anchors_preset(Control.PRESET_TOP_LEFT)
	back.offset_left = 40
	back.offset_top = 36 + Ui.inset_top
	back.offset_right = 40 + 112
	back.offset_bottom = back.offset_top + 112
	back.pressed.connect(func(): back_pressed.emit())
	add_child(back)

func get_scroll() -> int:
	return _scroll.scroll_vertical if _scroll != null else 0

func set_scroll(v: int) -> void:
	if _scroll != null:
		_scroll.scroll_vertical = v

func _login_card(list: VBoxContainer) -> void:
	var card := Ui.card(Color(0.35, 0.20, 0.08, 0.40), Color(Ui.GOLD, 0.55), 34, 26)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	card.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	head.add_child(Ui.icon("flame", 56, Color("#ffb347")))
	var t := Ui.label("Daily Login", 40, Ui.TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var streak := int(save.data.login_streak)
	if not save.login_available():
		head.add_child(Ui.label("Day %d" % streak, 34, Ui.GOLD, HORIZONTAL_ALIGNMENT_RIGHT, true))
	col.add_child(head)

	var claimed_today := not save.login_available()
	var next_day := save.login_day_if_claimed()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	for i in range(1, 8):
		var r: Dictionary = Rewards.LOGIN[i - 1]
		var done := (claimed_today and i <= streak) or (not claimed_today and i < next_day)
		var current := (not claimed_today) and i == next_day
		var tile := PanelContainer.new()
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var border := Ui.GOLD if current else Color(1, 1, 1, 0.15)
		tile.add_theme_stylebox_override("panel", Ui.flat(Color(0.03, 0.04, 0.14, 0.7) if not current else Color(Ui.GOLD, 0.2), 20, border, 3 if current else 2, 6, 14))
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 4)
		tile.add_child(v)
		v.add_child(Ui.label("D%d" % i, 24, Ui.TEXT_DIM))
		var ic := Ui.icon("check" if done else Rewards.icon_for(str(r["type"])), 40, Ui.GREEN if done else Ui.GOLD)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ic)
		v.add_child(Ui.label(str(int(r["amount"])), 26, Ui.TEXT, HORIZONTAL_ALIGNMENT_CENTER, true))
		if done:
			tile.modulate = Color(1, 1, 1, 0.6)
		row.add_child(tile)
	col.add_child(row)

	if save.login_available():
		var btn := Ui.pill_button("CLAIM DAY %d  ·  %s" % [next_day, Rewards.describe(Rewards.LOGIN[next_day - 1])], "gold", 124, 36, "gift")
		btn.pressed.connect(func(): claim_login_pressed.emit())
		col.add_child(btn)
	else:
		col.add_child(Ui.label("Next reward in %s" % Ui.format_duration(save.seconds_to_next_day()), 30, Ui.TEXT_DIM))
	list.add_child(card)

func _quest_card(q: Dictionary) -> Control:
	var id := str(q["id"])
	var goal := int(q["goal"])
	var prog := mini(save.quest_progress_of(id), goal)
	var claimed := save.quest_is_claimed(id)
	var accent := Ui.GREEN if prog >= goal else Ui.BLUE
	var card := Ui.card(Color(accent, 0.12), Color(accent, 0.5), 30, 22)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	card.add_child(row)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 10)
	var title := Ui.label(str(q["title"]), 34, Ui.TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(title)
	var bar_bg := Panel.new()
	bar_bg.custom_minimum_size = Vector2(0, 22)
	bar_bg.add_theme_stylebox_override("panel", Ui.flat(Color(0, 0, 0, 0.4), 11, Color(0, 0, 0, 0), 0, 0, 0))
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := Panel.new()
	fill.add_theme_stylebox_override("panel", Ui.flat(accent, 11, Color(0, 0, 0, 0), 0, 0, 0))
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.anchor_right = maxf(0.04, float(prog) / float(goal))
	fill.offset_right = 0
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_bg.add_child(fill)
	col.add_child(bar_bg)
	col.add_child(Ui.label("%d / %d    ·    %s" % [prog, goal, Rewards.describe(q)], 26, Ui.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT))
	row.add_child(col)
	if claimed:
		row.add_child(Ui.icon("check", 56, Ui.GREEN))
	elif prog >= goal:
		var b := Ui.pill_button("CLAIM", "green", 96, 30)
		b.custom_minimum_size = Vector2(190, 96)
		b.pressed.connect(_on_quest.bind(id))
		row.add_child(b)
	else:
		row.add_child(Ui.icon(Rewards.icon_for(str(q["type"])), 48, Color(accent, 0.8)))
	Ui.ignore_mouse(col)
	return card

func _on_quest(id: String) -> void:
	claim_quest_pressed.emit(id)

func _on_milestone(stars: int) -> void:
	claim_milestone_pressed.emit(stars)

func _milestone_card(ms: Dictionary) -> Control:
	var need := int(ms["stars"])
	var have := int(save.data.total_stars)
	var claimed := save.milestone_is_claimed(need)
	var reached := have >= need
	var accent := Ui.GOLD if reached else Ui.PURPLE
	var card := Ui.card(Color(accent, 0.11), Color(accent, 0.45), 28, 20)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	card.add_child(row)
	row.add_child(Ui.icon("star", 52, accent))
	var t := Ui.label("%d stars" % need, 34, Ui.TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	row.add_child(Ui.label(Rewards.describe(ms), 28, accent, HORIZONTAL_ALIGNMENT_RIGHT, true))
	if claimed:
		row.add_child(Ui.icon("check", 50, Ui.GREEN))
	elif reached:
		var b := Ui.pill_button("CLAIM", "gold", 84, 28)
		b.custom_minimum_size = Vector2(170, 84)
		b.pressed.connect(_on_milestone.bind(need))
		row.add_child(b)
	else:
		row.add_child(Ui.label("%d / %d" % [have, need], 26, Ui.TEXT_DIM))
	Ui.ignore_mouse(t)
	return card
