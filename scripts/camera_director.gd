class_name CameraDirector
extends Node3D

# Virtual cameraman. By default it films the match on its own: it glides between
# a list of shots (wide, three-quarter left/right, high angle, low hero shot,
# crane), pushes in when a tube is lifted, tracks a move from tube to tube, whips
# on a match, pulls out for a new tube, orbits for a win and drifts back on a
# loss. The player can take over at any time by dragging on the table (auto
# resumes after a few seconds), or switch the auto camera off in Settings.
# Everything is smoothed per frame, so moves can overlap without fighting.

const BASE_FOV := 52.0
const INTRO_SECONDS := 2.0
const ORBIT_YAW_LIMIT := 34.0
const ORBIT_PITCH_LIMIT := 14.0
const MANUAL_HOLD := 4.0
# yaw (deg), pitch (deg), distance multiplier, yaw drift over the shot (deg), seconds
const SHOTS := [
	[0.0, 31.0, 1.00, 5.0, 6.5],
	[-26.0, 25.0, 0.93, -7.0, 5.5],
	[6.0, 46.0, 0.97, 4.0, 5.0],
	[27.0, 23.0, 0.91, -6.0, 5.5],
	[-8.0, 19.0, 0.86, 7.0, 4.5],
	[0.0, 38.0, 0.95, 0.0, 4.0],
]

var camera: Camera3D
var auto_enabled := true
var orbit := Vector2.ZERO
var rows_pitch := 0.0

var _center := Vector3(0, 3.0, 0)
var _focus := Vector3(0, 3.0, 0)
var _base_dist := 17.6
var _min_mul := 0.85
var _cur_yaw := 0.0
var _cur_pitch := 31.0
var _cur_dist := 17.6
var _cur_focus := Vector3(0, 3.0, 0)
var _rate := 1.2
var _shot := 0
var _shot_t := 0.0
var _hold := 0.0
var _event_t := 0.0
var _ev := Vector4(0, 30, 1, 0)
var _ev_focus := Vector3.ZERO
var _last_base := Vector3(0, 31, 1)
var _intro := 0.0
var _time := 0.0
var _shake := 0.0
var _punch := 0.0
var _celebrate := false
var _cele_yaw := 0.0
var _defeat := false

func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = BASE_FOV
	add_child(camera)
	camera.make_current()

# half_w: half the width of the tube rows (incl. tube radius); height: tube height.
func configure(center_y: float, half_w: float, height: float, rows: int = 1, snap_now: bool = true) -> void:
	# Look slightly above the board centre so the board sits below the HUD.
	_center = Vector3(0.0, center_y + 0.7, 0.0)
	_focus = _center
	rows_pitch = 9.0 if rows > 1 else 0.0
	var vs := get_viewport().get_visible_rect().size
	var aspect := 0.5625
	if vs.y > 0.0:
		aspect = vs.x / vs.y
	var t := tan(deg_to_rad(BASE_FOV * 0.5))
	var need := (half_w + 1.0) / (t * aspect)
	var dist_h := height * 0.75 / t + 2.0
	_base_dist = maxf(17.6, maxf(need * 1.06, dist_h))
	# closest allowed zoom that still keeps every tube on screen
	_min_mul = clampf(need / _base_dist, 0.8, 1.0)
	if not snap_now:
		return    # extra tube: keep filming, the camera glides to the new framing
	orbit = Vector2.ZERO
	_celebrate = false
	_defeat = false
	_event_t = 0.0
	_hold = 0.0
	_shot = 0
	_shot_t = 0.0
	snap()

func snap() -> void:
	var s: Array = SHOTS[0]
	_cur_yaw = float(s[0])
	_cur_pitch = float(s[1]) + rows_pitch
	_cur_dist = _base_dist * maxf(float(s[2]), _min_mul)
	_cur_focus = _focus
	_apply(0.0)

func play_intro() -> void:
	_intro = 1.0

func set_auto(value: bool) -> void:
	auto_enabled = value
	if not value:
		orbit = Vector2.ZERO

# ── director events ───────────────────────────────────────────────────────────

func _event(shot: Vector4, point: Vector3, seconds: float) -> void:
	if _hold > 0.0 or _celebrate or _defeat or not auto_enabled:
		return
	_ev = shot
	_ev_focus = Vector3(point.x, _center.y, point.z)
	_event_t = seconds

func on_select(point: Vector3) -> void:
	_event(Vector4(signf(point.x) * 8.0, 29.0 + rows_pitch, maxf(0.9, _min_mul), 0.28), point, 1.8)

func on_move(from_point: Vector3, to_point: Vector3) -> void:
	var mid := from_point.lerp(to_point, 0.5)
	_event(Vector4(clampf(mid.x * 3.0, -14.0, 14.0), 30.0 + rows_pitch, maxf(0.92, _min_mul), 0.2), mid, 1.6)
	punch(0.4)

func on_match(point: Vector3) -> void:
	_event(Vector4(randf_range(-18.0, 18.0), 24.0 + rows_pitch, maxf(0.86, _min_mul), 0.3), point, 1.5)
	punch(1.0)
	shake(0.14)

func on_new_tube(point: Vector3) -> void:
	_event(Vector4(14.0, 42.0 + rows_pitch, 1.02, 0.35), point, 2.4)

func on_hint(point: Vector3) -> void:
	_event(Vector4(-6.0, 32.0 + rows_pitch, maxf(0.95, _min_mul), 0.3), point, 2.0)

func punch(amount: float = 1.0) -> void:
	_punch = maxf(_punch, amount)

func shake(amount: float = 0.18) -> void:
	_shake = maxf(_shake, amount)

func celebrate() -> void:
	_celebrate = true
	_defeat = false
	_cele_yaw = _cur_yaw

func defeat() -> void:
	_defeat = true
	_celebrate = false

func calm() -> void:
	_celebrate = false
	_defeat = false
	_event_t = 0.0

# Manual control: dragging takes over for a few seconds.
func orbit_drag(relative: Vector2) -> void:
	_celebrate = false
	_hold = MANUAL_HOLD
	orbit.x = clampf(orbit.x - relative.x * 0.12, -ORBIT_YAW_LIMIT, ORBIT_YAW_LIMIT)
	orbit.y = clampf(orbit.y + relative.y * 0.06, -ORBIT_PITCH_LIMIT, ORBIT_PITCH_LIMIT)

# ── per-frame ─────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if camera == null:
		return
	_time += delta
	_apply(delta)

func _apply(delta: float) -> void:
	var base := Vector3(0.0, 31.0, 1.0)
	var focus_t := _center
	var rate_t := 2.5
	_hold = maxf(0.0, _hold - delta)
	if _celebrate:
		_cele_yaw += delta * 24.0
		base = Vector3(_cele_yaw, 24.0, maxf(0.86, _min_mul))
		rate_t = 3.0
	elif _defeat:
		base = Vector3(0.0, 36.0, 1.0)
		rate_t = 1.5
	elif _hold > 0.0:
		base = _last_base
		focus_t = _focus
		rate_t = 3.5
	elif _event_t > 0.0:
		_event_t -= delta
		base = Vector3(_ev.x, _ev.y, _ev.z)
		focus_t = _center.lerp(_ev_focus, _ev.w)
		rate_t = 3.0
	elif auto_enabled:
		var s: Array = SHOTS[_shot]
		_shot_t += delta
		if _shot_t >= float(s[4]):
			_shot = (_shot + 1) % SHOTS.size()
			_shot_t = 0.0
			s = SHOTS[_shot]
		var prog := _shot_t / float(s[4])
		base = Vector3(float(s[0]) + float(s[3]) * prog, float(s[1]) + rows_pitch, maxf(float(s[2]), _min_mul))
		rate_t = 1.1
	else:
		base = Vector3(0.0, 31.0 + rows_pitch, 1.0)
	if _hold <= 0.0:
		_last_base = base
	_focus = focus_t if _hold <= 0.0 else _focus

	_rate = lerpf(_rate, rate_t, clampf(delta * 3.0, 0.0, 1.0))
	var k := 1.0 - exp(-delta * _rate) if delta > 0.0 else 1.0
	_cur_yaw = lerpf(_cur_yaw, base.x + orbit.x, k)
	_cur_pitch = lerpf(_cur_pitch, base.y + orbit.y, k)
	_cur_dist = lerpf(_cur_dist, _base_dist * base.z, k)
	var kf := 1.0 - exp(-delta * 4.0) if delta > 0.0 else 1.0
	_cur_focus = _cur_focus.lerp(focus_t, kf)

	# with auto camera on, the player's manual offset eases back after the hold
	if auto_enabled and _hold <= 0.0 and not _celebrate:
		orbit = orbit.lerp(Vector2.ZERO, 1.0 - exp(-delta * 0.9))

	var e := 0.0
	if _intro > 0.0:
		_intro = maxf(0.0, _intro - delta / INTRO_SECONDS)
		e = _intro * _intro * _intro
	_punch = maxf(0.0, _punch - delta * 3.0)

	var sway_yaw := sin(_time * 0.35) * 1.2
	var sway_pitch := sin(_time * 0.27 + 1.0) * 0.5
	var yaw := deg_to_rad(_cur_yaw + sway_yaw + 55.0 * e)
	var pitch := deg_to_rad(clampf(_cur_pitch + sway_pitch + 22.0 * e, 5.0, 82.0))
	var dist := _cur_dist * (1.0 + 0.9 * e) * (1.0 - _punch * 0.035)
	var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
	camera.position = _cur_focus + offset
	camera.look_at(_cur_focus, Vector3.UP)
	camera.fov = BASE_FOV + 16.0 * e - _punch * 3.0

	# hand-held feel + screen shake
	var hx := sin(_time * 1.7) * 0.02 + sin(_time * 0.7) * 0.015
	var hy := sin(_time * 1.3 + 1.0) * 0.016
	if _shake > 0.001:
		hx += randf_range(-_shake, _shake)
		hy += randf_range(-_shake, _shake)
		_shake = maxf(0.0, _shake - delta * 1.1)
	camera.h_offset = hx
	camera.v_offset = hy
