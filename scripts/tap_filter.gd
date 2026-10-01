class_name TapFilter
extends RefCounted

# Turns raw press/release input into a single "tap". A tap is a press followed by
# a release that stayed within MAX_MOVE pixels and MAX_MS milliseconds, so
# dragging to orbit the camera never selects a tube. One physical touch also
# produces an emulated mouse click; sharing one filter lets the first release
# win and swallows the duplicate.

const MAX_MOVE := 28.0
const MAX_MS := 500

var _down := false
var _pos := Vector2.ZERO
var _ms := 0

func feed(event: InputEvent) -> bool:
	var p := Vector2.ZERO
	var pressed := false
	if event is InputEventScreenTouch:
		p = event.position
		pressed = event.pressed
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		p = event.position
		pressed = event.pressed
	else:
		return false
	if pressed:
		_down = true
		_pos = p
		_ms = Time.get_ticks_msec()
		return false
	if not _down:
		return false
	_down = false
	return p.distance_to(_pos) <= MAX_MOVE and Time.get_ticks_msec() - _ms <= MAX_MS
