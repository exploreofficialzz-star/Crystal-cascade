class_name ResultScreen
extends Control

signal next_pressed
signal retry_pressed
signal replay_pressed
signal levels_pressed
signal home_pressed
signal extra_moves_pressed
signal free_moves_pressed
signal double_coins_pressed
signal watch_life_pressed

# Level-complete / game-over screen. Everything that earns money is surfaced
# here: double the coins for a video, free moves for a video, a life for a video.
func setup(won: bool, stars: int, score: int, coins_earned: int, lives: int,
		extra_moves_cost: int, rewarded_ready: bool, total_coins: int) -> void:
	Ui.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.background(self, "res://assets/images/bg_victory.jpg" if won else "res://assets/images/bg_menu.jpg", 0.45 if won else 0.62)

	var pad := Ui.margin(self, 60, 60 + int(Ui.inset_top), 60, 40 + int(Ui.inset_bottom))
	var scroll := ScrollContainer.new()
	Ui.full_rect(scroll)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pad.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 26)
	scroll.add_child(col)

	col.add_child(Ui.vspace(40))
	var hero := Ui.icon("trophy" if won else "heart", 190, Ui.GOLD if won else Ui.RED)
	hero.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(hero)
	var title := Ui.label("LEVEL COMPLETE!" if won else "OUT OF MOVES", 68, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
	col.add_child(title)

	if won:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 20)
		col.add_child(row)
		for i in range(3):
			var filled := i < stars
			var s := Ui.icon("star" if filled else "star_outline", 128, Ui.GOLD if filled else Color(1, 1, 1, 0.35))
			s.pivot_offset = Vector2(64, 64)
			row.add_child(s)
			if filled:
				s.scale = Vector2.ZERO
				var tw := s.create_tween()
				tw.tween_property(s, "scale", Vector2.ONE, 0.45).set_delay(0.3 + 0.25 * float(i)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_confetti()
	else:
		col.add_child(Ui.label("So close! Try again or use a power-up.", 34, Color(1, 1, 1, 0.8)))

	var card := Ui.card(Color(0.02, 0.03, 0.09, 0.62), Color(1, 1, 1, 0.08), 36, 30)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 10)
	card.add_child(cv)
	cv.add_child(Ui.label("Score: %d" % score, 46, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true))
	if won:
		var earn := HBoxContainer.new()
		earn.alignment = BoxContainer.ALIGNMENT_CENTER
		earn.add_theme_constant_override("separation", 12)
		earn.add_child(Ui.icon("coin", 40, Ui.GOLD))
		earn.add_child(Ui.label("+%d coins earned" % coins_earned, 34, Ui.GOLD))
		cv.add_child(earn)
	col.add_child(card)

	col.add_child(Ui.vspace(8))
	if won:
		if rewarded_ready:
			var dbl := Ui.pill_button("WATCH VIDEO: DOUBLE COINS", "gold", 128, 36, "video")
			dbl.pressed.connect(func(): double_coins_pressed.emit())
			col.add_child(dbl)
		var nxt := Ui.glass_button("Next Level", Ui.GREEN, 128, 40, "arrow_right")
		nxt.pressed.connect(func(): next_pressed.emit())
		col.add_child(nxt)
	else:
		if lives > 0:
			var retry := Ui.pill_button("RETRY  (uses 1 life)", "pink", 136, 40, "restore")
			retry.pressed.connect(func(): retry_pressed.emit())
			col.add_child(retry)
		elif rewarded_ready:
			var life := Ui.pill_button("WATCH VIDEO: +1 LIFE", "pink", 136, 40, "video")
			life.pressed.connect(func(): watch_life_pressed.emit())
			col.add_child(life)
		else:
			col.add_child(Ui.label("No lives left. One returns every 30 minutes.", 32, Ui.RED))
		if rewarded_ready:
			var free_btn := Ui.pill_button("WATCH VIDEO: +%d MOVES" % ProductionConfig.REWARD_EXTRA_MOVES, "gold", 128, 36, "video")
			free_btn.pressed.connect(func(): free_moves_pressed.emit())
			col.add_child(free_btn)
		var buy := Ui.glass_button("+%d MOVES  (%d coins)" % [ProductionConfig.REWARD_EXTRA_MOVES, extra_moves_cost], Ui.GOLD, 118, 36, "coin")
		buy.disabled = total_coins < extra_moves_cost
		buy.pressed.connect(func(): extra_moves_pressed.emit())
		col.add_child(buy)
	if won:
		var again := Ui.glass_button("Replay", Ui.PURPLE, 118, 36, "restore")
		again.pressed.connect(func(): replay_pressed.emit())
		col.add_child(again)
	var lv := Ui.glass_button("Level Select", Ui.BLUE, 118, 36, "grid")
	lv.pressed.connect(func(): levels_pressed.emit())
	col.add_child(lv)
	var hm := Ui.glass_button("Main Menu", Ui.GREY, 118, 36, "home")
	hm.pressed.connect(func(): home_pressed.emit())
	col.add_child(hm)
	col.add_child(Ui.vspace(30))

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
