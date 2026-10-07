class_name ResultScreen
extends Control

signal next_pressed
signal retry_pressed
signal replay_pressed
signal levels_pressed
signal home_pressed
signal extra_moves_pressed
signal free_moves_pressed
signal extra_tube_pressed
signal free_tube_pressed
signal double_coins_pressed
signal watch_life_pressed

# Level-complete / game-over screen. Everything that earns money is surfaced
# here: double the coins for a video, free moves or a free tube for a video, a
# life for a video. Buttons are solid dark pills with white text so they stay
# readable on the busy victory artwork.
#
# info keys: won, reason ("moves" | "stuck"), stars, score, coins_earned, lives,
# extra_moves_cost, extra_tube_cost, tube_available, rewarded_ready, total_coins, win_streak,
# streak_bonus, level, theme_name, gold, cascades, chest_in, boss, next_level,
# next_twists, next_boss
func setup(info: Dictionary) -> void:
	var won: bool = bool(info.get("won", false))
	var reason: String = str(info.get("reason", "moves"))
	var stars: int = int(info.get("stars", 0))
	var lives: int = int(info.get("lives", 0))
	var rewarded_ready: bool = bool(info.get("rewarded_ready", false))
	var total_coins: int = int(info.get("total_coins", 0))
	var boss: bool = bool(info.get("boss", false))

	Ui.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.background(self, "res://assets/images/bg_victory.jpg" if won else "res://assets/images/bg_menu.jpg", 0.74 if won else 0.66)
	if won:
		_confetti()

	var pad := Ui.margin(self, 60, 40 + int(Ui.inset_top), 60, 36 + int(Ui.inset_bottom))
	var scroll := ScrollContainer.new()
	Ui.full_rect(scroll)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pad.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 22)
	scroll.add_child(col)

	var hero := Ui.icon("trophy" if won else "heart", 160, Ui.GOLD if won else Ui.RED)
	hero.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(hero)
	var title_text := "LEVEL COMPLETE!"
	if won and boss:
		title_text = "BOSS DEFEATED!"
	elif not won:
		title_text = "NO MOVES LEFT" if reason == "stuck" else "OUT OF MOVES"
	var title := Ui.label(title_text, 66, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("outline_size", 10)
	col.add_child(title)
	var theme_name: String = str(info.get("theme_name", ""))
	if theme_name != "":
		col.add_child(Ui.label("Level %d  -  %s" % [int(info.get("level", 1)), theme_name], 30, Color("#c9d2ff"), HORIZONTAL_ALIGNMENT_CENTER, true))

	if won:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 20)
		col.add_child(row)
		for i in range(3):
			var filled := i < stars
			var s := Ui.icon("star" if filled else "star_outline", 118, Ui.GOLD if filled else Color(1, 1, 1, 0.40))
			s.pivot_offset = Vector2(59, 59)
			row.add_child(s)
			if filled:
				s.scale = Vector2.ZERO
				var tw := s.create_tween()
				tw.tween_property(s, "scale", Vector2.ONE, 0.45).set_delay(0.3 + 0.25 * float(i)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	elif reason == "stuck":
		col.add_child(_note("Nothing can move. Add a tube to keep going!"))
	else:
		col.add_child(_note("So close! Add moves or try again."))

	# ── score card ──
	var card := Ui.card(Color(0.02, 0.03, 0.09, 0.88), Color(1, 1, 1, 0.14), 36, 26)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 8)
	card.add_child(cv)
	cv.add_child(Ui.label("Score: %d" % int(info.get("score", 0)), 46, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true))
	if won:
		cv.add_child(_line("coin", "+%d coins earned" % int(info.get("coins_earned", 0)), Ui.GOLD, 34))
		var gold_n: int = int(info.get("gold", 0))
		if gold_n > 0:
			cv.add_child(_line("star", "Golden crystals x%d" % gold_n, Color("#ffd34e"), 30))
		var casc: int = int(info.get("cascades", 0))
		if casc >= 2:
			cv.add_child(_line("flame", "Best cascade x%d" % casc, Color("#ff944d"), 30))
		var win_streak: int = int(info.get("win_streak", 0))
		if win_streak >= 2:
			cv.add_child(_line("flame", "Win streak x%d   +%d coins" % [win_streak, int(info.get("streak_bonus", 0))], Color("#ffb347"), 32))
	col.add_child(card)

	if won:
		var chest_in: int = int(info.get("chest_in", 0))
		if chest_in > 0 and not boss:
			col.add_child(_line("chest", "Treasure chest in %d win%s" % [chest_in, "" if chest_in == 1 else "s"], Color("#ffe14d"), 30))

	# ── actions ──
	if won:
		if rewarded_ready:
			var dbl := Ui.pill_button("WATCH VIDEO: DOUBLE COINS", "gold", 128, 36, "video")
			dbl.pressed.connect(func(): double_coins_pressed.emit())
			col.add_child(dbl)
		var nxt := Ui.pill_button("NEXT LEVEL", "green", 150, 50, "arrow_right")
		nxt.pressed.connect(func(): next_pressed.emit())
		col.add_child(nxt)
		var tiles := HBoxContainer.new()
		tiles.add_theme_constant_override("separation", 16)
		var again := _tile("Replay", "restore", Ui.PURPLE)
		again.pressed.connect(func(): replay_pressed.emit())
		tiles.add_child(again)
		var lv := _tile("Levels", "grid", Ui.BLUE)
		lv.pressed.connect(func(): levels_pressed.emit())
		tiles.add_child(lv)
		var hm := _tile("Menu", "home", Ui.GREY)
		hm.pressed.connect(func(): home_pressed.emit())
		tiles.add_child(hm)
		col.add_child(tiles)
		_add_teaser(col, info)
	else:
		# continue options first: they keep the run alive
		if reason == "stuck":
			if bool(info.get("tube_available", true)):
				if rewarded_ready:
					var ft := Ui.pill_button("WATCH VIDEO: FREE TUBE", "gold", 128, 36, "video")
					ft.pressed.connect(func(): free_tube_pressed.emit())
					col.add_child(ft)
				var cost_t: int = int(info.get("extra_tube_cost", 100))
				var bt := Ui.solid_button("+TUBE  (%d coins)" % cost_t, Ui.GOLD, 118, 36, "coin")
				bt.disabled = total_coins < cost_t
				if bt.disabled:
					bt.modulate = Color(1, 1, 1, 0.55)
				bt.pressed.connect(func(): extra_tube_pressed.emit())
				col.add_child(bt)
			else:
				col.add_child(_note("The table is full. Retry for a fresh start!"))
		else:
			if rewarded_ready:
				var fm := Ui.pill_button("WATCH VIDEO: +%d MOVES" % ProductionConfig.REWARD_EXTRA_MOVES, "gold", 128, 36, "video")
				fm.pressed.connect(func(): free_moves_pressed.emit())
				col.add_child(fm)
			var cost_m: int = int(info.get("extra_moves_cost", 30))
			var bm := Ui.solid_button("+%d MOVES  (%d coins)" % [ProductionConfig.REWARD_EXTRA_MOVES, cost_m], Ui.GOLD, 118, 36, "coin")
			bm.disabled = total_coins < cost_m
			if bm.disabled:
				bm.modulate = Color(1, 1, 1, 0.55)
			bm.pressed.connect(func(): extra_moves_pressed.emit())
			col.add_child(bm)
		if lives > 0:
			var retry := Ui.pill_button("RETRY  (uses 1 life)", "pink", 136, 40, "restore")
			retry.pressed.connect(func(): retry_pressed.emit())
			col.add_child(retry)
		elif rewarded_ready:
			var life := Ui.pill_button("WATCH VIDEO: +1 LIFE", "pink", 136, 40, "video")
			life.pressed.connect(func(): watch_life_pressed.emit())
			col.add_child(life)
		else:
			col.add_child(_note("No lives left. One returns every 30 minutes."))
		var tiles2 := HBoxContainer.new()
		tiles2.add_theme_constant_override("separation", 16)
		var lv2 := _tile("Levels", "grid", Ui.BLUE)
		lv2.pressed.connect(func(): levels_pressed.emit())
		tiles2.add_child(lv2)
		var hm2 := _tile("Menu", "home", Ui.GREY)
		hm2.pressed.connect(func(): home_pressed.emit())
		tiles2.add_child(hm2)
		col.add_child(tiles2)
	col.add_child(Ui.vspace(10))
	Ui.scroll_friendly(col)

# "Up next" teaser: curiosity is what brings people back for one more level.
func _add_teaser(col: VBoxContainer, info: Dictionary) -> void:
	var next_level: int = int(info.get("next_level", 0))
	if next_level <= 0:
		return
	var next_boss: bool = bool(info.get("next_boss", false))
	var twists: Array = info.get("next_twists", [])
	var accent: Color = Color("#ff5b8a") if next_boss else Color("#7ef0ff")
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Ui.flat(Color(0.03, 0.04, 0.14, 0.92), 34, Color(accent, 0.8), 3, 26, 14))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	var head := "BOSS LEVEL %d" % next_level if next_boss else "UP NEXT: LEVEL %d" % next_level
	v.add_child(Ui.label(head, 34, accent, HORIZONTAL_ALIGNMENT_CENTER, true))
	var parts: Array = []
	for t in twists:
		if str(t) != "boss":
			parts.append(Twists.label(str(t)))
	var line := " + ".join(parts) if not parts.is_empty() else "New board, new view"
	v.add_child(Ui.label(line, 28, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true))
	col.add_child(p)

func _line(icon_name: String, text: String, color: Color, fsize: int) -> Control:
	var r := HBoxContainer.new()
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	r.add_theme_constant_override("separation", 12)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_child(Ui.icon(icon_name, int(fsize * 1.2), color))
	r.add_child(Ui.label(text, fsize, color, HORIZONTAL_ALIGNMENT_CENTER, true))
	return r

func _note(text: String) -> Label:
	var l := Ui.label(text, 32, Color(1, 1, 1, 0.9), HORIZONTAL_ALIGNMENT_CENTER, true)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(0, 44)
	return l

# Compact secondary action: icon over a label, solid dark fill, bright border.
func _tile(text: String, icon_name: String, accent: Color) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 150)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_stylebox_override("normal", Ui.flat(Color(0.07, 0.09, 0.27, 0.96), 36, Color(accent, 0.95), 3, 0, 0))
	b.add_theme_stylebox_override("hover", Ui.flat(Color(0.10, 0.13, 0.34, 0.98), 36, accent, 3, 0, 0))
	b.add_theme_stylebox_override("pressed", Ui.flat(Color(0.14, 0.17, 0.42, 1.0), 36, accent, 3, 0, 0))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.focus_mode = Control.FOCUS_NONE
	var v := VBoxContainer.new()
	Ui.full_rect(v)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 6)
	v.add_child(Ui.icon(icon_name, 56, accent))
	v.add_child(Ui.label(text, 28, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true))
	b.add_child(v)
	Ui.ignore_mouse(v)
	Ui.hook_click(b)
	return b

func _confetti() -> void:
	var p := CPUParticles2D.new()
	p.position = Vector2(540, -30)
	p.amount = 70
	p.lifetime = 3.2
	p.one_shot = true
	p.explosiveness = 0.85
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(520, 10)
	p.direction = Vector2(0, 1)
	p.spread = 25.0
	p.gravity = Vector2(0, 520)
	p.initial_velocity_min = 240.0
	p.initial_velocity_max = 620.0
	p.scale_amount_min = 8.0
	p.scale_amount_max = 16.0
	var g := Gradient.new()
	g.colors = PackedColorArray([Color("#ff5b8a"), Color("#ffd34e"), Color("#4b8cf5"), Color("#3ddc97"), Color("#b04bd8")])
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	p.color_initial_ramp = g
	add_child(p)
	p.emitting = true
