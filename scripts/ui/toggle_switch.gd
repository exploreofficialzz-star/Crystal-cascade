class_name ToggleSwitch
extends Control

# iOS-style switch drawn in code (matches the purple switches in the reference).
# It toggles on release, and a scroll gesture that starts on it cancels the press,
# so scrolling the settings list can never flip a switch by accident.
signal toggled(value: bool)

var value := true
var _t := 1.0
var _pressed := false

func _init() -> void:
	custom_minimum_size = Vector2(150, 84)
	mouse_filter = Control.MOUSE_FILTER_STOP

func set_value(v: bool, animate: bool = false) -> void:
	value = v
	if animate:
		var tw := create_tween()
		tw.tween_method(_set_t, _t, 1.0 if v else 0.0, 0.16)
	else:
		_t = 1.0 if v else 0.0
		queue_redraw()

func _set_t(x: float) -> void:
	_t = x
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_SCROLL_BEGIN:
		_pressed = false

func _gui_input(event: InputEvent) -> void:
	# Mouse only: touches arrive as emulated mouse clicks, handling both would
	# toggle the switch twice.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressed = true
		elif _pressed:
			_pressed = false
			if Rect2(Vector2.ZERO, size).has_point(event.position):
				accept_event()
				set_value(not value, true)
				toggled.emit(value)

func _draw() -> void:
	var w := size.x
	var h := size.y
	var track_off := Color(0.20, 0.22, 0.36, 1.0)
	var track_on := Color(0.55, 0.28, 0.78, 1.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = track_off.lerp(track_on, _t)
	sb.set_corner_radius_all(int(h / 2))
	draw_style_box(sb, Rect2(0, 0, w, h))
	var r := h * 0.36
	var x := lerpf(h * 0.5, w - h * 0.5, _t)
	draw_circle(Vector2(x, h * 0.5), r, Color(0.86, 0.34, 0.98).lerp(Color(0.72, 0.74, 0.86), 1.0 - _t))
