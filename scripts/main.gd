extends Node3D

const HINT_COST := 40
const EXTRA_MOVES_COST := 30
const EXTRA_TUBE_COST := 100

var save: SaveData
var audio: AudioManager
var world: GameWorld
var ui: Control
var screen_root: Control
var hud: VBoxContainer
var game_status := GameData.Status.IDLE
var current_level := 1
var level_info: Dictionary = {}
var tubes: Array = []
var selected := -1
var hint_destination := -1
var moves := 0
var score := 0
var combo := 0
var stars := 0
var move_serial := 0
var toast_label: Label
var tutorial_visible := false
var platform: AndroidPlatform

# BUG-002 FIX: debounce variables — both Crystal3D and Tube3D areas fire
# input_event on the same tap. Track the last-tapped tube+frame so the
# second call (same tube, same Engine frame) is silently dropped.
var _last_tap_tube := -1
var _last_tap_frame := -1

func _ready() -> void:
	save = SaveData.new()
	add_child(save)
	audio = AudioManager.new()
	add_child(audio)
	world = GameWorld.new()
	add_child(world)
	world.build()
	platform = AndroidPlatform.new()
	add_child(platform)
	platform.setup(save)
	platform.rewarded_earned.connect(_on_rewarded_earned)
	platform.purchase_completed.connect(_on_purchase_completed)
	platform.purchase_failed.connect(_on_purchase_failed)
	_build_ui()
	await get_tree().process_frame
	audio.set_music(bool(save.data.music))
	show_home()

func _build_ui() -> void:
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	screen_root = Control.new()
	screen_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(screen_root)

func _clear_ui() -> void:
	for child in screen_root.get_children():
		child.queue_free()
	toast_label = null

func _style(bg: Color, radius: int = 18, border: Color = Color(0.35, 0.5, 1.0, 0.35)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = border
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

func _button(text_value: String, action: Callable, height: int = 58) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0, height)
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _style(Color(0.10, 0.13, 0.30, 0.94)))
	button.add_theme_stylebox_override("hover", _style(Color(0.22, 0.17, 0.46, 0.98)))
	button.add_theme_stylebox_override("pressed", _style(Color(0.07, 0.09, 0.22, 1.0)))
	button.pressed.connect(action)
	return button

func _title(title_text: String, subtitle: String = "") -> VBoxContainer:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 5)
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color("#eef1ff"))
	box.add_child(title)
	if subtitle != "":
		var sub := Label.new()
		sub.text = subtitle
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.add_theme_font_size_override("font_size", 16)
		sub.add_theme_color_override("font_color", Color("#9ca8d9"))
		box.add_child(sub)
	return box

func _background(image_path: String = "res://assets/images/bg_menu.jpg") -> void:
	var texture_rect := TextureRect.new()
	texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var texture = load(image_path)
	if texture:
		texture_rect.texture = texture
	texture_rect.modulate = Color(0.32, 0.36, 0.62, 0.52)
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_root.add_child(texture_rect)
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.02, 0.03, 0.11, 0.58)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_root.add_child(overlay)

func _panel_container() -> MarginContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	screen_root.add_child(margin)
	return margin

func show_home() -> void:
	game_status = GameData.Status.IDLE
	_clear_ui()
	_background()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_root.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(430, 0)
	box.add_theme_constant_override("separation", 13)
	center.add_child(box)
	box.add_child(_title("CRYSTAL CASCADE", "A living 3D crystal puzzle"))
	var logo := TextureRect.new()
	var logo_texture = load("res://assets/images/game_logo.png")
	if logo_texture:
		logo.texture = logo_texture
	logo.custom_minimum_size = Vector2(0, 150)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(logo)
	var stats := Label.new()
	stats.text = "💎 %d     💡 %d     ♥ %d/5     ★ %d" % [int(save.data.coins), int(save.data.hints), int(save.data.lives), int(save.data.total_stars)]
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 19)
	box.add_child(stats)
	if save.can_claim_daily_bonus():
		box.add_child(_button("CLAIM DAILY BONUS  +50 💎", _claim_daily_bonus))
	else:
		var ready := Label.new()
		ready.text = "Daily bonus returns after 24 hours"
		ready.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ready.add_theme_color_override("font_color", Color("#8f9bc9"))
		box.add_child(ready)
	box.add_child(_button("PLAY", show_levels, 62))
	box.add_child(_button("SHOP", show_shop))
	box.add_child(_button("SETTINGS", show_settings))
	var foot := Label.new()
	foot.text = "by chAs • Godot 3D Edition"
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.add_theme_color_override("font_color", Color("#69749f"))
	box.add_child(foot)

func _claim_daily_bonus() -> void:
	if save.claim_daily_bonus():
		audio.play("coin")
		show_home()
		_toast("+50 coins claimed!")

func show_levels() -> void:
	_clear_ui()
	_background("res://assets/images/bg_levelselect.jpg")
	var margin := _panel_container()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	var header := HBoxContainer.new()
	var back := _button("‹", show_home, 52)
	back.custom_minimum_size.x = 64
	header.add_child(back)
	var title := Label.new()
	title.text = "SELECT LEVEL"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	header.add_child(title)
	var spacer := Control.new()
	spacer.custom_minimum_size.x = 64
	header.add_child(spacer)
	box.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 9)
	grid.add_theme_constant_override("v_separation", 9)
	scroll.add_child(grid)
	var highest := int(save.data.highest_unlocked)
	var max_display := max(100, highest + 12)
	for id in range(1, max_display + 1):
		var progress: Dictionary = save.level(id)
		var locked := id > highest
		var star_count := int(progress.get("stars", 0))
		var card := Button.new()
		card.custom_minimum_size = Vector2(0, 86)
		card.add_theme_font_size_override("font_size", 17)
		if locked:
			card.text = "🔒\n%d" % id
			card.disabled = true
		else:
			card.text = "%d\n%s" % [id, "★".repeat(star_count) + "☆".repeat(3 - star_count)]
			card.pressed.connect(func(): start_level(id))
		card.add_theme_stylebox_override("normal", _style(Color(0.10, 0.13, 0.28, 0.94), 14))
		grid.add_child(card)
	box.add_child(_button("HOME", show_home, 50))

func start_level(id: int) -> void:
	current_level = id
	level_info = GameData.level_info(id)
	moves = int(level_info.moves)
	score = 0
	combo = 0
	stars = 0
	selected = -1
	hint_destination = -1
	game_status = GameData.Status.PLAYING
	_make_board()
	show_game()
	if current_level == 1 and not bool(save.data.tutorial):
		_show_tutorial()

func _make_board() -> void:
	tubes.clear()
	var all_colors: Array = []
	for color_name in level_info.colors:
		for _i in range(int(level_info.gems)):
			all_colors.append(color_name)
	var rng := RandomNumberGenerator.new()
	rng.seed = 700001 + current_level * 7919
	for i in range(all_colors.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp = all_colors[i]
		all_colors[i] = all_colors[j]
		all_colors[j] = temp
	tubes.resize(int(level_info.tubes))
	for i in range(tubes.size()):
		tubes[i] = []
	var index := 0
	for tube_index in range(tubes.size() - 1):
		for _slot in range(int(level_info.capacity)):
			if index >= all_colors.size():
				break
			tubes[tube_index].append(all_colors[index])
			index += 1
	# world.arrange now immediately frees old tubes (BUG-001 fix in world.gd)
	world.arrange(tubes.size(), int(level_info.capacity))
	_connect_tubes()
	_sync_visuals()

func _connect_tubes() -> void:
	for i in range(world.tubes_root.get_child_count()):
		var tube := world.get_tube(i)
		if tube and not tube.tapped.is_connected(_on_tube_tapped):
			tube.tapped.connect(_on_tube_tapped)

func _sync_visuals() -> void:
	# BUG-004 FIX: iterate tubes.size(), not get_child_count() (they match
	# after the BUG-001 fix, but tubes.size() is the authoritative count).
	for i in range(tubes.size()):
		var tube_node := world.get_tube(i)
		if not tube_node:
			continue
		# BUG-005 FIX: immediately free old crystals so a same-frame
		# re-sync doesn't see stale nodes alongside the new ones.
		var old_crystals := tube_node.get_children()
		for child in old_crystals:
			if child is Crystal3D:
				tube_node.remove_child(child)
				child.free()
		var values: Array = tubes[i]
		var slot_height := 0.82
		var start_y := -((float(level_info.capacity) - 1.0) * slot_height) / 2.0
		for j in range(values.size()):
			var gem := Crystal3D.new()
			gem.setup(str(values[j]), Vector3(0, start_y + j * slot_height, 0), float(i * 17 + j), j)
			gem.tapped.connect(func(_crystal: Crystal3D, tube_index: int = i): _on_tube_tapped(tube_index))
			tube_node.add_child(gem)
		tube_node.set_highlight(i == selected or i == hint_destination)

# BUG-002 FIX: Both Crystal3D and Tube3D areas fire input_event for the
# same physical tap. Guard against the second call arriving in the same
# engine frame for the same tube index.
func _on_tube_tapped(index: int) -> void:
	var current_frame := Engine.get_process_frames()
	if index == _last_tap_tube and current_frame == _last_tap_frame:
		return  # duplicate from the other area — discard
	_last_tap_tube = index
	_last_tap_frame = current_frame

	if game_status != GameData.Status.PLAYING:
		return
	if index < 0 or index >= tubes.size():
		return
	hint_destination = -1
	if selected == -1:
		if not tubes[index].is_empty():
			selected = index
			world.focus_on_tube(index)
			world.guardian.react("surprised")
			audio.play("tap")
	elif selected == index:
		selected = -1
		world.guardian.react("idle")
		audio.play("tap")
	else:
		_move_gem(selected, index)
	_sync_visuals()
	_update_hud()

func _move_gem(from_index: int, to_index: int) -> void:
	if tubes[from_index].is_empty():
		_invalid_move()
		return
	if tubes[to_index].size() >= int(level_info.capacity):
		_invalid_move()
		return
	var color_name: String = tubes[from_index][-1]
	if not tubes[to_index].is_empty() and tubes[to_index][-1] != color_name:
		_invalid_move()
		return

	var start_node := world.get_tube(from_index)
	var destination_node := world.get_tube(to_index)
	if start_node and destination_node:
		world.focus = destination_node.global_position + Vector3(0, 0.8, 0)
		world.pulse_camera(0.12)

	tubes[from_index].pop_back()
	tubes[to_index].append(color_name)
	moves -= 1
	move_serial += 1
	score += 10
	selected = -1
	audio.play("tap")
	world.guardian.react("happy")
	combo = max(0, combo)
	_check_match(to_index)
	if game_status == GameData.Status.PLAYING and moves <= 3:
		world.guardian.react("sad")
	_check_win_condition()

func _invalid_move() -> void:
	selected = -1
	hint_destination = -1
	world.guardian.react("angry")
	world.pulse_camera(0.22)
	audio.play("tap")
	_toast("That crystal cannot move there")

func _check_match(tube_index: int) -> void:
	var tube: Array = tubes[tube_index]
	if tube.size() < 3:
		return
	var target = tube[-1]
	var count := 1
	for i in range(tube.size() - 2, -1, -1):
		if tube[i] == target:
			count += 1
		else:
			break
	if count < 3:
		return
	combo += 1
	score += combo * 50
	for _i in range(count):
		if tube.is_empty():
			break
		tube.pop_back()
	save.add_coins(2)
	audio.play("match")
	world.guardian.react("happy")
	world.pulse_camera(0.18)
	_toast("MATCH! +%d" % (combo * 50))

func _check_win_condition() -> void:
	var complete := true
	for tube in tubes:
		if not tube.is_empty():
			complete = false
			break
	if complete:
		game_status = GameData.Status.WON
		stars = 3 if moves >= int(level_info.s3) else (2 if moves >= int(level_info.s2) else 1)
		score += moves * 20
		save.set_level(current_level, stars, score)
		audio.play("victory")
		world.guardian.react("happy")
		if platform:
			platform.show_interstitial()
		_show_result(true)
	elif moves <= 0:
		game_status = GameData.Status.LOST
		audio.play("gameover")
		world.guardian.react("sad")
		_show_result(false)

func _hint() -> void:
	if game_status != GameData.Status.PLAYING:
		return
	var granted := save.use_hint()
	if not granted:
		granted = save.spend_coins(HINT_COST)
	if not granted:
		_toast("Need a hint or %d coins" % HINT_COST)
		return
	for from_index in range(tubes.size()):
		if tubes[from_index].is_empty():
			continue
		var color_name = tubes[from_index][-1]
		for to_index in range(tubes.size()):
			if from_index == to_index or tubes[to_index].size() >= int(level_info.capacity):
				continue
			if tubes[to_index].is_empty() or tubes[to_index][-1] == color_name:
				selected = from_index
				hint_destination = to_index
				world.focus_on_tube(to_index)
				world.guardian.react("surprised")
				_sync_visuals()
				_toast("Hint: highlighted source → destination")
				return
	_toast("No simple move found — try exposing another crystal")

func _extra_moves() -> void:
	if save.spend_coins(EXTRA_MOVES_COST):
		moves += 5
		_toast("+5 moves")
		_update_hud()
	else:
		_toast("You need %d coins" % EXTRA_MOVES_COST)

func _extra_tube() -> void:
	if tubes.size() >= 10:
		_toast("Maximum 10 tubes")
		return
	if not save.spend_coins(EXTRA_TUBE_COST):
		_toast("You need %d coins" % EXTRA_TUBE_COST)
		return
	tubes.append([])
	world.arrange(tubes.size(), int(level_info.capacity))
	_connect_tubes()
	_sync_visuals()
	_update_hud()
	_toast("Extra tube added")

func show_game() -> void:
	_clear_ui()
	var top := MarginContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.add_theme_constant_override("margin_left", 14)
	top.add_theme_constant_override("margin_right", 14)
	top.add_theme_constant_override("margin_top", 12)
	screen_root.add_child(top)
	hud = VBoxContainer.new()
	top.add_child(hud)
	_update_hud()

	var bottom := MarginContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.add_theme_constant_override("margin_left", 12)
	bottom.add_theme_constant_override("margin_right", 12)
	bottom.add_theme_constant_override("margin_bottom", 15)
	screen_root.add_child(bottom)
	var controls := GridContainer.new()
	controls.columns = 5
	controls.add_theme_constant_override("h_separation", 7)
	controls.add_theme_constant_override("v_separation", 7)
	bottom.add_child(controls)
	controls.add_child(_button("HINT", _hint, 54))
	controls.add_child(_button("+5", _extra_moves, 54))
	controls.add_child(_button("+TUBE", _extra_tube, 54))
	controls.add_child(_button("CAM", world.next_camera, 54))
	controls.add_child(_button("PAUSE", show_pause, 54))

	var tip := Label.new()
	tip.text = "Tap a tube, then tap a matching tube or an empty tube"
	tip.set_anchors_preset(Control.PRESET_TOP_WIDE)
	tip.position.y = 200
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_theme_font_size_override("font_size", 14)
	tip.add_theme_color_override("font_color", Color("#9da8d4"))
	screen_root.add_child(tip)

func _update_hud() -> void:
	if not hud:
		return
	for child in hud.get_children():
		child.queue_free()
	var first := HBoxContainer.new()
	first.add_theme_constant_override("separation", 10)
	hud.add_child(first)
	var title := Label.new()
	title.text = "LEVEL %d" % current_level
	title.add_theme_font_size_override("font_size", 23)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	first.add_child(title)
	var resources := Label.new()
	resources.text = "💎 %d   💡 %d   ♥ %d" % [int(save.data.coins), int(save.data.hints), int(save.data.lives)]
	resources.add_theme_font_size_override("font_size", 17)
	first.add_child(resources)
	var second := Label.new()
	second.text = "MOVES %d     SCORE %d     COMBO x%d" % [moves, score, combo]
	second.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	second.add_theme_font_size_override("font_size", 19)
	hud.add_child(second)

func show_pause() -> void:
	if game_status != GameData.Status.PLAYING:
		return
	game_status = GameData.Status.PAUSED
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.76)
	screen_root.add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(360, 0)
	box.add_theme_constant_override("separation", 11)
	center.add_child(box)
	box.add_child(_title("PAUSED"))
	box.add_child(_button("RESUME", func(): overlay.queue_free(); game_status = GameData.Status.PLAYING))
	box.add_child(_button("RESTART", func(): overlay.queue_free(); start_level(current_level)))
	box.add_child(_button("LEVELS", func(): overlay.queue_free(); show_levels()))
	box.add_child(_button("HOME", func(): overlay.queue_free(); show_home()))

func _show_result(won: bool) -> void:
	await get_tree().create_timer(0.55).timeout
	if game_status != (GameData.Status.WON if won else GameData.Status.LOST):
		return
	_clear_ui()
	_background("res://assets/images/bg_victory.jpg" if won else "res://assets/images/bg_menu.jpg")
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_root.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(430, 0)
	box.add_theme_constant_override("separation", 13)
	center.add_child(box)
	box.add_child(_title("LEVEL COMPLETE" if won else "GAME OVER", "★".repeat(stars) if won else "Your Guardian wants another try"))
	var result := Label.new()
	result.text = "SCORE  %d\nMOVES LEFT  %d\nBEST STARS  %d" % [score, moves, max(stars, int(save.level(current_level).get("stars", 0)))]
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.add_theme_font_size_override("font_size", 23)
	box.add_child(result)
	if won:
		box.add_child(_button("NEXT LEVEL", func(): start_level(current_level + 1), 62))
	else:
		if int(save.data.lives) > 0:
			box.add_child(_button("RETRY — USE 1 LIFE", _retry_with_life, 62))
		else:
			box.add_child(_button("WATCH REWARD — 1 LIFE", _reward_life_notice, 62))
	if not won and moves > 0:
		box.add_child(_button("+5 MOVES — %d COINS" % EXTRA_MOVES_COST, _resume_with_extra_moves))
	box.add_child(_button("REPLAY", func(): start_level(current_level)))
	box.add_child(_button("LEVELS", show_levels))
	box.add_child(_button("HOME", show_home))

func _retry_with_life() -> void:
	if save.use_life():
		start_level(current_level)
	else:
		_reward_life_notice()

func _resume_with_extra_moves() -> void:
	if save.spend_coins(EXTRA_MOVES_COST):
		moves += 5
		game_status = GameData.Status.PLAYING
		show_game()
	else:
		_toast("You need %d coins" % EXTRA_MOVES_COST)

func _reward_life_notice() -> void:
	if platform:
		platform.show_rewarded("life")
		_toast("Watch the rewarded ad to receive 1 life")

func _on_rewarded_earned(reward_type: String) -> void:
	if reward_type == "life":
		save.add_life()
		_toast("+1 life")
	elif reward_type == "hint":
		save.add_hints(1)
		_toast("+1 hint")
	elif reward_type == "coins":
		save.add_coins(50)
		_toast("+50 coins")

func _on_purchase_completed(product_id: String) -> void:
	_toast("Purchase complete: %s" % product_id)
	show_shop()

func _on_purchase_failed(product_id: String, message: String) -> void:
	_toast("Purchase unavailable: %s" % message)

func _show_tutorial() -> void:
	tutorial_visible = true
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.72)
	screen_root.add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(380, 0)
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)
	box.add_child(_title("HOW TO PLAY", "Sort every crystal into matching tubes"))
	var instructions := Label.new()
	instructions.text = "1. Tap a tube to select its top crystal.\n2. Tap an empty tube or a tube with the same color.\n3. Build groups of 3+ to clear them.\n4. Finish with moves remaining for more stars.\n\nThe camera moves around the board while you play."
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instructions.add_theme_font_size_override("font_size", 17)
	instructions.add_theme_color_override("font_color", Color("#d8def8"))
	box.add_child(instructions)
	box.add_child(_button("GOT IT", func(): overlay.queue_free(); tutorial_visible = false; save.data.tutorial = true; save.save()))

func show_shop() -> void:
	_clear_ui()
	_background()
	var margin := _panel_container()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	box.add_child(_title("SHOP", "Coins, hints and premium entitlements"))
	var balance := Label.new()
	balance.text = "COINS: %d     HINTS: %d     LIVES: %d/5" % [int(save.data.coins), int(save.data.hints), int(save.data.lives)]
	balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	balance.add_theme_font_size_override("font_size", 20)
	box.add_child(balance)
	box.add_child(_button("DAILY BONUS — +50 COINS", _claim_daily_bonus))
	box.add_child(_button("HINT PACK — 5 HINTS", func(): _purchase_notice("hint_pack_small")))
	box.add_child(_button("HINT PACK — 15 HINTS", func(): _purchase_notice("hint_pack_large")))
	box.add_child(_button("COIN PACK — 500 COINS", func(): _purchase_notice("coin_pack_starter")))
	box.add_child(_button("MEGA PACK — 2000 COINS + 20 HINTS", func(): _purchase_notice("mega_pack")))
	box.add_child(_button("REMOVE ADS — DAY", func(): _purchase_notice("remove_ads_day")))
	box.add_child(_button("REMOVE ADS — WEEKEND", func(): _purchase_notice("remove_ads_weekend")))
	box.add_child(_button("REMOVE ADS — MONTH", func(): _purchase_notice("remove_ads_month")))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	box.add_child(_button("BACK", show_home))

func _purchase_notice(product_id: String) -> void:
	if platform:
		platform.purchase(product_id)
		_toast("Opening Google Play checkout…")
	else:
		_toast("Google Play Billing is unavailable")

func show_settings() -> void:
	_clear_ui()
	_background()
	var margin := _panel_container()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	box.add_child(_title("SETTINGS"))
	box.add_child(_button("SOUND: %s" % ("ON" if bool(save.data.sound) else "OFF"), _toggle_sound))
	box.add_child(_button("MUSIC: %s" % ("ON" if bool(save.data.music) else "OFF"), _toggle_music))
	box.add_child(_button("VIBRATION: %s" % ("ON" if bool(save.data.vibration) else "OFF"), _toggle_vibration))
	box.add_child(_button("RESET PROGRESS", _confirm_reset))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	box.add_child(_button("BACK", show_home))

func _toggle_sound() -> void:
	save.set_setting("sound", not bool(save.data.sound))
	audio.enabled = bool(save.data.sound)
	show_settings()

func _toggle_music() -> void:
	var enabled := not bool(save.data.music)
	save.set_setting("music", enabled)
	audio.set_music(enabled)
	show_settings()

func _toggle_vibration() -> void:
	save.set_setting("vibration", not bool(save.data.vibration))
	show_settings()

func _confirm_reset() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Reset progress?"
	dialog.dialog_text = "This permanently resets coins, lives, stars, levels and settings on this device."
	screen_root.add_child(dialog)
	dialog.confirmed.connect(func(): save.reset_all(); show_home())
	dialog.popup_centered()

func _toast(message: String) -> void:
	if not is_inside_tree() or not screen_root:
		return
	if toast_label and is_instance_valid(toast_label):
		toast_label.queue_free()
	toast_label = Label.new()
	toast_label.text = message
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	toast_label.position.y = -115
	toast_label.add_theme_font_size_override("font_size", 18)
	toast_label.add_theme_color_override("font_color", Color.WHITE)
	screen_root.add_child(toast_label)
	var label_ref := toast_label
	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(label_ref, "modulate:a", 0.0, 0.35)
	tween.tween_callback(label_ref.queue_free)
