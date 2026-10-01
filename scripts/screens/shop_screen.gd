class_name ShopScreen
extends Control

signal back_pressed
signal purchase_requested(product_id: String)
signal watch_coins_requested
signal watch_hint_requested
signal bonus_requested

var save: SaveData
var prices: Dictionary = {}
var _pad: MarginContainer
var _scroll: ScrollContainer

func setup(save_data: SaveData, price_map: Dictionary) -> void:
	save = save_data
	prices = price_map
	Ui.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := Ui.gradient_rect(Color("#191a2f"), Color("#3d2968"))
	Ui.full_rect(bg)
	add_child(bg)

	_pad = Ui.margin(self, 40, 36 + int(Ui.inset_top), 40, 0 + int(Ui.inset_bottom))
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 22)
	_pad.add_child(outer)
	var back := Ui.header(outer, "Shop")
	back.pressed.connect(func(): back_pressed.emit())

	var scroll := ScrollContainer.new()
	_scroll = scroll
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 18)
	scroll.add_child(list)

	list.add_child(_wallet())
	if save.ads_seconds_left() > 0:
		list.add_child(_ads_off_card())

	list.add_child(Ui.section_title("Free Coins"))
	list.add_child(_item("video", Ui.PURPLE, "Watch Video",
		"Get %d coins free" % ProductionConfig.REWARD_VIDEO_COINS, "", func(): watch_coins_requested.emit()))
	var wait := save.seconds_to_daily_bonus()
	if wait <= 0:
		list.add_child(_item("gift", Ui.GREEN, "Daily Bonus",
			"Claim your %d-coin daily reward" % SaveData.DAILY_BONUS, "", func(): bonus_requested.emit()))
	else:
		list.add_child(_item("gift", Ui.GREY, "Daily Bonus",
			"Next reward in %s" % Ui.format_duration(wait), "", Callable(), "", false))

	list.add_child(Ui.section_title("Hints  (you have %d)" % int(save.data.hints)))
	list.add_child(_item("video", Color("#ffe14d"), "Watch Video",
		"Get %d free hint" % ProductionConfig.REWARD_VIDEO_HINTS, "", func(): watch_hint_requested.emit()))
	list.add_child(_product("bulb", Ui.GOLD, "Hint Pack — Small", "5 hints, ready when you need them", "hint_pack_small"))
	list.add_child(_product("bulb", Ui.GOLD, "Hint Pack — Large", "15 hints · best value", "hint_pack_large", "BEST VALUE"))

	list.add_child(Ui.section_title("Remove Ads"))
	list.add_child(_product("sun", Color("#ffb347"), "Day Pass", "Ad-free for 24 hours", "remove_ads_day"))
	list.add_child(_product("calendar", Ui.BLUE, "Weekend Pass", "Ad-free for 48 hours — great for binge sessions", "remove_ads_weekend"))
	list.add_child(_product("moon", Ui.PURPLE, "Monthly Pass", "Ad-free for 30 days — best deal", "remove_ads_month", "BEST DEAL"))

	list.add_child(Ui.section_title("Coin Packs"))
	list.add_child(_product("coin", Ui.GOLD, "Coin Pack", "500 coins + 5 hints", "coin_pack_starter"))
	list.add_child(_product("diamond", Ui.BLUE, "Mega Pack", "2 000 coins + 20 hints + 48 h No Ads", "mega_pack", "POPULAR"))
	list.add_child(Ui.vspace(40))

func get_scroll() -> int:
	return _scroll.scroll_vertical if _scroll != null else 0

func set_scroll(v: int) -> void:
	if _scroll != null:
		_scroll.scroll_vertical = v

func set_bottom_reserve(px: int) -> void:
	if _pad != null:
		_pad.add_theme_constant_override("margin_bottom", int(Ui.inset_bottom) + px)

func _price(product_id: String) -> String:
	if prices.has(product_id):
		return str(prices[product_id])
	return str(ProductionConfig.DEFAULT_PRICES.get(product_id, ""))

func _product(icon_name: String, accent: Color, title: String, subtitle: String,
		product_id: String, badge: String = "") -> Control:
	var act := func(): purchase_requested.emit(product_id)
	return _item(icon_name, accent, title, subtitle, _price(product_id), act, badge)

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

func _item(icon_name: String, accent: Color, title: String, subtitle: String, price: String,
		action: Callable, badge: String = "", enabled: bool = true) -> Control:
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
	var t := Ui.label(title, 36, Ui.TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	head.add_child(t)
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
		pill.add_theme_stylebox_override("panel", Ui.flat(Color(accent, 0.24), 44, Color(0, 0, 0, 0), 0, 30, 16))
		pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pill.add_child(Ui.label(price, 34, accent, HORIZONTAL_ALIGNMENT_CENTER, true))
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
