class_name Ui
extends RefCounted

# Shared look-and-feel, sampled from the Flutter reference screenshots.
# Everything here is static so any screen can build widgets without a scene.

const TEXT := Color("#f2f4ff")
const TEXT_DIM := Color("#8f9bc8")
const GOLD := Color("#f5c120")
const PINK := Color("#c43be0")
const BLUE := Color("#4b8cf5")
const GREEN := Color("#3ddc97")
const RED := Color("#ef5a6f")
const PURPLE := Color("#b04bd8")
const GREY := Color("#b9bdd0")
const CARD := Color(0.06, 0.09, 0.22, 0.86)

# Set by main.gd. UI buttons call sfx_target.ui_click() when pressed.
static var sfx_target: Object = null
# Safe-area insets in canvas units (status bar / display cut-out).
static var inset_top := 0.0
static var inset_bottom := 0.0

static var _tex_cache: Dictionary = {}
static var _bold: FontVariation = null

static func font_bold() -> Font:
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = ThemeDB.fallback_font
		_bold.variation_embolden = 0.55
	return _bold

static func tex(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path) as Texture2D
	_tex_cache[path] = t
	return t

static func icon_tex(icon_name: String) -> Texture2D:
	return tex("res://assets/icons/%s.png" % icon_name)

static func icon(icon_name: String, px: int, tint: Color = Color.WHITE) -> TextureRect:
	var r := TextureRect.new()
	r.texture = icon_tex(icon_name)
	r.custom_minimum_size = Vector2(px, px)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.modulate = tint
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

static func label(text: String, fsize: int, color: Color = TEXT,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", font_bold())
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func flat(bg: Color, radius: int = 24, border: Color = Color(0, 0, 0, 0),
		border_w: int = 0, pad_x: int = 24, pad_y: int = 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if border_w > 0:
		s.set_border_width_all(border_w)
		s.border_color = border
	s.content_margin_left = pad_x
	s.content_margin_right = pad_x
	s.content_margin_top = pad_y
	s.content_margin_bottom = pad_y
	return s

static func nine(path: String, margin: int, tint: Color = Color.WHITE) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = tex(path)
	s.texture_margin_left = margin
	s.texture_margin_right = margin
	s.texture_margin_top = margin
	s.texture_margin_bottom = margin
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.modulate_color = tint
	return s

static func gradient_rect(c0: Color, c1: Color) -> TextureRect:
	var g := Gradient.new()
	g.colors = PackedColorArray([c0, c1])
	g.offsets = PackedFloat32Array([0.0, 1.0])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 8
	gt.height = 256
	var r := TextureRect.new()
	r.texture = gt
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

static func full_rect(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

# ScrollContainers only start a drag-scroll when the press reaches them, but a
# STOP control (every Button, PanelContainer, ...) swallows it. Calling this on
# the content of a scroll list lets you start scrolling from anywhere, even on a
# card or button; BaseButton cancels its press once the scroll begins, so nothing
# is triggered by accident.
static func scroll_friendly(root: Node) -> void:
	for child in root.get_children():
		if child is Control:
			var c: Control = child
			if c is BaseButton or c is ToggleSwitch:
				c.mouse_filter = Control.MOUSE_FILTER_PASS
			elif c.mouse_filter == Control.MOUSE_FILTER_STOP:
				c.mouse_filter = Control.MOUSE_FILTER_PASS
		scroll_friendly(child)

static func ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		ignore_mouse(child)

# Transparent, full-size button laid over a card so the whole card is tappable.
static func make_tappable(p: Control, radius: int, action: Callable) -> Button:
	var b := Button.new()
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", flat(Color(1, 1, 1, 0.05), radius, Color(0, 0, 0, 0), 0, 0, 0))
	b.add_theme_stylebox_override("pressed", flat(Color(1, 1, 1, 0.13), radius, Color(0, 0, 0, 0), 0, 0, 0))
	_clear_focus_style(b)
	b.pressed.connect(action)
	hook_click(b)
	p.add_child(b)
	return b

# Gentle breathing scale, used on the PLAY button. Call once the node is in the tree.
static func pulse(c: Control, amount: float = 0.03, period: float = 1.1) -> void:
	c.resized.connect(func(): c.pivot_offset = c.size / 2.0)
	c.pivot_offset = c.size / 2.0
	var tw := c.create_tween().set_loops()
	tw.tween_property(c, "scale", Vector2(1.0 + amount, 1.0 + amount), period).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, period).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

static func hook_click(b: BaseButton) -> void:
	if sfx_target != null and sfx_target.has_method("ui_click"):
		b.pressed.connect(Callable(sfx_target, "ui_click"))

static func _clear_focus_style(b: Button) -> void:
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.focus_mode = Control.FOCUS_NONE

# Background image that covers the screen, with an optional dark wash.
static func background(parent: Control, path: String, dim: float = 0.0) -> void:
	var tr := TextureRect.new()
	full_rect(tr)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.texture = tex(path)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tr)
	if dim > 0.0:
		var wash := ColorRect.new()
		full_rect(wash)
		wash.color = Color(0.02, 0.03, 0.10, dim)
		wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(wash)

static func vspace(px: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, px)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

static func hspace_expand() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

static func margin(parent: Control, l: int, t: int, r: int, b: int) -> MarginContainer:
	var m := MarginContainer.new()
	full_rect(m)
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_bottom", b)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(m)
	return m

# ── Buttons ───────────────────────────────────────────────────────────────────

# Big gradient pill (PLAY / LEVELS / SHOP). kind: pink, blue, gold, green, purple, red
static func pill_button(text: String, kind: String, height: int = 150,
		fsize: int = 46, icon_name: String = "") -> Button:
	var path := "res://assets/ui/btn_%s.png" % kind
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, height)
	b.add_theme_stylebox_override("normal", nine(path, 64, Color.WHITE))
	b.add_theme_stylebox_override("hover", nine(path, 64, Color(1.08, 1.08, 1.08)))
	b.add_theme_stylebox_override("pressed", nine(path, 64, Color(0.80, 0.80, 0.85)))
	b.add_theme_stylebox_override("disabled", nine(path, 64, Color(0.55, 0.55, 0.6, 0.7)))
	_clear_focus_style(b)
	_add_row(b, text, fsize, Color.WHITE, icon_name, true)
	hook_click(b)
	return b

# Translucent outline button (Next Level / Level Select / Main Menu).
static func glass_button(text: String, accent: Color, height: int = 130,
		fsize: int = 40, icon_name: String = "") -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, height)
	var r := int(height / 2)
	b.add_theme_stylebox_override("normal", flat(Color(accent, 0.14), r, Color(accent, 0.70), 3))
	b.add_theme_stylebox_override("hover", flat(Color(accent, 0.24), r, Color(accent, 0.90), 3))
	b.add_theme_stylebox_override("pressed", flat(Color(accent, 0.34), r, Color(accent, 1.0), 3))
	b.add_theme_stylebox_override("disabled", flat(Color(accent, 0.06), r, Color(accent, 0.25), 2))
	_clear_focus_style(b)
	_add_row(b, text, fsize, accent, icon_name, true)
	hook_click(b)
	return b

static func circle_button(icon_name: String, diameter: int = 120,
		accent: Color = Color(1, 1, 1, 1)) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(diameter, diameter)
	var r := int(diameter / 2)
	b.add_theme_stylebox_override("normal", flat(Color(0.03, 0.03, 0.09, 0.78), r, Color(accent, 0.30), 2, 0, 0))
	b.add_theme_stylebox_override("hover", flat(Color(0.10, 0.12, 0.26, 0.85), r, Color(accent, 0.5), 2, 0, 0))
	b.add_theme_stylebox_override("pressed", flat(Color(0.16, 0.18, 0.36, 0.9), r, Color(accent, 0.7), 2, 0, 0))
	_clear_focus_style(b)
	var ic := icon(icon_name, int(diameter * 0.44), Color(0.93, 0.94, 1.0))
	ic.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	ic.offset_left = -diameter * 0.22
	ic.offset_right = diameter * 0.22
	ic.offset_top = -diameter * 0.22
	ic.offset_bottom = diameter * 0.22
	b.add_child(ic)
	hook_click(b)
	return b

static func _add_row(b: Button, text: String, fsize: int, color: Color,
		icon_name: String, bold: bool) -> void:
	var row := HBoxContainer.new()
	full_rect(row)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon_name != "":
		row.add_child(icon(icon_name, int(fsize * 1.15), color))
	var l := label(text, fsize, color, HORIZONTAL_ALIGNMENT_CENTER, bold)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	b.add_child(row)

# ── Small widgets ─────────────────────────────────────────────────────────────

# Dark glass pill with an icon and a value (coins, lives, moves ...).
static func chip(icon_name: String, text: String, accent: Color, fsize: int = 38) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", flat(Color(0.03, 0.03, 0.09, 0.80), 60, Color(accent, 0.55), 2, 24, 12))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	row.add_child(icon(icon_name, int(fsize * 1.2), accent))
	var l := label(text, fsize, TEXT, HORIZONTAL_ALIGNMENT_CENTER, true)
	row.add_child(l)
	p.set_meta("value_label", l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

static func set_chip(p: Control, text: String) -> void:
	if p != null and p.has_meta("value_label"):
		var l = p.get_meta("value_label")
		if is_instance_valid(l):
			(l as Label).text = text

static func section_title(text: String) -> Label:
	var l := label(text, 32, PURPLE, HORIZONTAL_ALIGNMENT_LEFT, true)
	l.custom_minimum_size = Vector2(0, 60)
	return l

# Rounded translucent panel container with padding.
static func card(bg: Color = CARD, border: Color = Color(0.35, 0.5, 1.0, 0.25),
		radius: int = 30, pad: int = 26) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", flat(bg, radius, border, 2, pad, pad))
	return p

static func scroll_column(parent: Control, side: int = 44, top: int = 0, bottom: int = 60) -> VBoxContainer:
	var sc := ScrollContainer.new()
	full_rect(sc)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(sc)
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_theme_constant_override("margin_left", side)
	m.add_theme_constant_override("margin_right", side)
	m.add_theme_constant_override("margin_top", top)
	m.add_theme_constant_override("margin_bottom", bottom)
	sc.add_child(m)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 16)
	m.add_child(v)
	return v

# Header row: circular back button + title. Returns the back button.
static func header(parent: Control, title: String, back_icon: String = "back") -> Button:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	var back := circle_button(back_icon, 112)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(back)
	var t := label(title, 54, TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	parent.add_child(row)
	return back

static func format_duration(seconds: int) -> String:
	if seconds <= 0:
		return "0m"
	var h := int(seconds / 3600)
	var m := int((seconds % 3600) / 60)
	if h >= 24:
		return "%dd %dh" % [int(h / 24), h % 24]
	if h > 0:
		return "%dh %dm" % [h, m]
	return "%dm" % maxi(1, m)
