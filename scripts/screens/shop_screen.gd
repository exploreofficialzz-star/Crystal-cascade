class_name ShopScreen
extends Control

# The whole screen is one scroll list (drag from anywhere, cards included), the
# back button floats on top. No banner ad on this screen.
signal back_pressed
signal purchase_requested(product_id: String)
signal watch_coins_requested
signal watch_hint_requested
signal watch_life_requested
signal bonus_requested
signal rewards_requested
signal coins_for_hints_requested
signal coins_for_lives_requested

const HINT_BUNDLE_COST := 100
const HINT_BUNDLE_COUNT := 3
const LIFE_REFILL_COST := 60

var save: SaveData
var prices: Dictionary = {}
var _scroll: ScrollContainer

func setup(save_data: SaveData, price_map: Dictionary) -> void:
	save = save_data
	prices = price_map
	Ui.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := Ui.gradient_rect(Color("#191a2f"), Color("#3d2968"))
	Ui.full_rect(bg)
	add_child(bg)

	_scroll = ScrollContainer.new()
	Ui.full_rect(_scroll)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_theme_constant_override("margin_left", 40)
	m.add_theme_constant_override("margin_right", 40)
	m.add_theme_constant_override("margin_top", 36 + int(Ui.inset_top))
	m.add_theme_constant_override("margin_bottom", 90 + int(Ui.inset_bottom))
	_scroll.add_child(m)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 18)
	m.add_child(list)

	# title row (the floating back button sits over the left gap)
	var head := HBoxContainer.new()
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(138, 0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(gap)
	var title := Ui.label("Shop", 54, Ui.TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	title.custom_minimum_size = Vector2(0, 112)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	list.add_child(head)

	list.add_child(_wallet())
	if save.ads_seconds_left() > 0:
		list.add_child(_ads_off_card())

	var dot := Rewards.claimable(save)
	list.add_child(_item("gift", Ui.GREEN, "Daily Rewards & Quests",
		"Login streak, daily quests and star milestones", "", _emit_rewards, "CLAIM!" if dot else ""))

	list.add_child(Ui.section_title("Free Coins"))
	list.add_child(_item("video", Ui.PURPLE, "Watch Video",
		"Get %d coins free" % ProductionConfig.REWARD_VIDEO_COINS, "", _emit_watch_coins))
	var wait := save.seconds_to_daily_bonus()
	if wait <= 0:
		list.add_child(_item("gift", Ui.GREEN, "Daily Bonus",
			"Claim your %d-coin daily reward" % SaveData.DAILY_BONUS, "", _emit_bonus))
	else:
		list.add_child(_item("gift", Ui.GREY, "Daily Bonus",
			"Next reward in %s" % Ui.format_duration(wait), "", Callable(), "", false))

	list.add_child(Ui.section_title("Lives  (you have %d / 5)" % int(save.data.lives)))
	list.add_child(_item("video", Ui.RED, "Watch Video", "Get 1 free life", "", _emit_watch_life))
	list.add_child(_item("heart", Ui.RED, "Refill All Lives", "Back to 5 lives right away",
		"%d" % LIFE_REFILL_COST, _emit_coins_lives, "", int(save.data.lives) < 5, true))

	list.add_child(Ui.section_title("Hints  (you have %d)" % int(save.data.hints)))
	list.add_child(_item("video", Color("#ffe14d"), "Watch Video",
		"Get %d free hint" % ProductionConfig.REWARD_VIDEO_HINTS, "", _emit_watch_hint))
	list.add_child(_item("bulb", Color("#ffe14d"), "%d Hints" % HINT_BUNDLE_COUNT, "Pay with coins",
		"%d" % HINT_BUNDLE_COST, _emit_coins_hints, "", true, true))
	list.add_child(_product("bulb", Ui.GOLD, "Hint Pack — Small", "5 hints, ready when you need them", "hint_pack_small"))
	list.add_child(_product("bulb", Ui.GOLD, "Hint Pack — Large", "15 hints · best value", "hint_pack_large", "BEST VALUE"))

	list.add_child(Ui.section_title("Remove Ads"))
	list.add_child(_product("sun", Color("#ffb347"), "Day Pass", "Ad-free for 24 hours", "remove_ads_day"))
	list.add_child(_product("calendar", Ui.BLUE, "Weekend Pass", "Ad-free for 48 hours — great for binge sessions", "remove_ads_weekend"))
	list.add_child(_product("moon", Ui.PURPLE, "Monthly Pass", "Ad-free for 30 days — best deal", "remove_ads_month", "BEST DEAL"))

	list.add_child(Ui.section_title("Coin Packs"))
	list.add_child(_product("coin", Ui.GOLD, "Coin Pack", "500 coins + 5 hints", "coin_pack_starter"))
	list.add_child(_product("diamond", Ui.BLUE, "Mega Pack", "2 000 coins + 20 hints + 48 h No Ads", "mega_pack", "POPULAR"))
	list.add_child(Ui.vspace(30))
	Ui.scroll_friendly(list)

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

func _emit_rewards() -> void:
	rewards_requested.emit()

func _emit_watch_coins() -> void:
	watch_coins_requested.emit()

func _emit_watch_hint() -> void:
	watch_hint_requested.emit()

func _emit_watch_life() -> void:
	watch_life_requested.emit()

func _emit_bonus() -> void:
	bonus_requested.emit()

func _emit_coins_hints() -> void:
	coins_for_hints_requested.emit()

func _emit_coins_lives() -> void:
	coins_for_lives_requested.emit()

func _on_product(product_id: String) -> void:
	purchase_requested.emit(product_id)

func _price(product_id: String) -> String:
	if prices.has(product_id):
		return str(prices[product_id])
	return str(ProductionConfig.DEFAULT_PRICES.get(product_id, ""))

func _product(icon_name: String, accent: Color, title: String, subtitle: String,
		product_id: String, badge: String = "") -> Control:
	return _item(icon_name, accent, title, subtitle, _price(product_id),
		_on_product.bind(product_id), badge)

func _wallet() -> Control:
	var card := Ui.card(Color(0.30, 0.25, 0.10, 0.35), Color(Ui.GOLD, 0.45), 34, 26)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(row)
	var cells := [
		["coin", str(int(save.data.coins)), "Coins", Ui.GOLD],
		["bulb", str(int(save.data.hints)), "Hints", Color("#ffe14d")],
		["heart", str(int(save.data.lives)), "Lives", Ui.RED],
	]
	for i in range(cells.size()):
		var c: Array = cells[i]
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 4)
		var ic := Ui.icon(c[0], 50, c[3])
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ic)
		v.add_child(Ui.label(c[1], 46, c[3], HORIZONTAL_ALIGNMENT_CENTER, true))
		v.add_child(Ui.label(c[2], 26, Ui.TEXT_DIM))
		row.add_child(v)
		if i < cells.size() - 1:
			var div := ColorRect.new()
			div.color = Color(1, 1, 1, 0.14)
			div.custom_minimum_size = Vector2(2, 96)
			div.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(div)
	return card

func _ads_off_card() -> Control:
	var card := Ui.card(Color(0.10, 0.30, 0.22, 0.45), Color(Ui.GREEN, 0.55), 30, 20)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	card.add_child(row)
	row.add_child(Ui.icon("ad_free", 46, Ui.GREEN))
	var l := Ui.label("Ads removed — %s left" % Ui.format_duration(save.ads_seconds_left()), 32, Ui.GREEN, HORIZONTAL_ALIGNMENT_LEFT, true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	return card

# price_is_coins: the right-hand pill shows a coin icon and the price in coins.
func _item(icon_name: String, accent: Color, title: String, subtitle: String, price: String,
		action: Callable, badge: String = "", enabled: bool = true, price_is_coins: bool = false) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Ui.flat(Color(accent, 0.13), 32, Color(accent, 0.55), 2, 22, 20))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	card.add_child(row)

	var badge_panel := PanelContainer.new()
	badge_panel.custom_minimum_size = Vector2(104, 104)
	badge_panel.add_theme_stylebox_override("panel", Ui.flat(Color(accent, 0.25), 60, Color(0, 0, 0, 0), 0, 0, 0))
	var cc := CenterContainer.new()
	badge_panel.add_child(cc)
	cc.add_child(Ui.icon(icon_name, 54, accent))
	row.add_child(badge_panel)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_theme_constant_override("separation", 4)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.add_child(Ui.label(title, 36, Ui.TEXT, HORIZONTAL_ALIGNMENT_LEFT, true))
	if badge != "":
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", Ui.flat(Color(accent, 0.28), 24, Color(0, 0, 0, 0), 0, 14, 4))
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.add_child(Ui.label(badge, 20, accent, HORIZONTAL_ALIGNMENT_CENTER, true))
		head.add_child(chip)
	text.add_child(head)
	var sub := Ui.label(subtitle, 27, Ui.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(sub)
	row.add_child(text)

	if price != "":
		var pill := PanelContainer.new()
		pill.add_theme_stylebox_override("panel", Ui.flat(Color(accent, 0.24), 44, Color(0, 0, 0, 0), 0, 26, 16))
		pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var prow := HBoxContainer.new()
		prow.add_theme_constant_override("separation", 10)
		if price_is_coins:
			prow.add_child(Ui.icon("coin", 36, Ui.GOLD))
		prow.add_child(Ui.label(price, 34, accent, HORIZONTAL_ALIGNMENT_CENTER, true))
		pill.add_child(prow)
		row.add_child(pill)
	elif enabled:
		var chev := Ui.icon("chevron_right", 44, accent)
		chev.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(chev)

	Ui.ignore_mouse(row)
	if enabled and action.is_valid():
		Ui.make_tappable(card, 32, action)
	else:
		card.modulate = Color(1, 1, 1, 0.55)
	return card
