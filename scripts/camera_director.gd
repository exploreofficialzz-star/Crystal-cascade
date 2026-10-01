class_name CameraDirector
extends Node3D

# Owns the game camera. Everything is smoothed per frame (no tweens), so moves
# can overlap without fighting: preset angles, focus follow, cinematic intro,
# idle sway, drag-to-orbit with spring-back, FOV punch on matches, screen shake,
# a victory orbit and a defeat pull-back.

const BASE_FOV := 52.0
const INTRO_SECONDS := 1.8
const ORBIT_YAW_LIMIT := 32.0
const ORBIT_PITCH_LIMIT := 12.0
# x = yaw (deg), y = pitch (deg), z = distance multiplier
const PRESETS := [
	Vector3(0.0, 30.0, 1.0),
	Vector3(38.0, 26.0, 0.98),
	Vector3(-38.0, 24.0, 0.98),
	Vector3(0.0, 58.0, 0.90),
]

var camera: Camera3D
var mode := 0
var orbit := Vector2.ZERO

var _center := Vector3(0, 3.0, 0)
var _focus := Vector3(0, 3.0, 0)
var _base_dist := 17.6
var _cur_yaw := 0.0
var _cur_pitch := 30.0
var _cur_dist := 17.6
var _cur_focus := Vector3(0, 3.0, 0)
var _intro := 0.0
var _time := 0.0
var _shake := 0.0
var _punch := 0.0
var _celebrate := false
var _celebrate_yaw := 0.0
var _defeat := false
var _idle_orbit := 0.0

func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = BASE_FOV
	add_child(camera)
	camera.make_current()

# half_w: half the width of the tube rows, height: tube height (world units)
func configure(center_y: float, half_w: float, height: float) -> void:
	# Look slightly above the board centre so the board sits below the HUD.
	_center = Vector3(0.0, center_y + 0.7, 0.0)
	_focus = _center
	var vs := get_viewport().get_visible_rect().size
	var aspect := 0.5625
	if vs.y > 0.0:
		aspect = vs.x / vs.y
	var t := tan(deg_to_rad(BASE_FOV * 0.5))
	var dist_w := (half_w + 1.0) / (t * aspect)
	var dist_h := height * 0.75 / t + 2.0
	_base_dist = maxf(17.6, maxf(dist_w, dist_h))
	mode = 0
	orbit = Vector2.ZERO
	_celebrate = false
	_defeat = false
	snap()

func snap() -> void:
	var p: Vector3 = PRESETS[mode]
	_cur_yaw = p.x
	_cur_pitch = p.y
	_cur_dist = _base_dist * p.z
	_cur_focus = _focus
	_apply(0.0)

func play_intro() -> void:
	_intro = 1.0

func set_mode(i: int) -> void:
	mode = posmod(i, PRESETS.size())
	orbit = Vector2.ZERO

func next_mode() -> void:
	set_mode(mode + 1)

func focus_on(point: Vector3) -> void:
	_focus = Vector3(
		lerpf(_center.x, point.x, 0.22),
		_center.y,
		lerpf(_center.z, point.z, 0.22))

func release_focus() -> void:
	_focus = _center

func punch(amount: float = 1.0) -> void:
	_punch = maxf(_punch, amount)

func shake(amount: float = 0.18) -> void:
	_shake = maxf(_shake, amount)

func celebrate() -> void:
	_celebrate = true
	_defeat = false
	_focus = _center

func defeat() -> void:
	_defeat = true
	_celebrate = false
	_focus = _center

func calm() -> void:
	_celebrate = false
	_defeat = false
	_celebrate_yaw = 0.0

func orbit_drag(relative: Vector2) -> void:
	_celebrate = false
	_idle_orbit = 0.0
	orbit.x = clampf(orbit.x - relative.x * 0.12, -ORBIT_YAW_LIMIT, ORBIT_YAW_LIMIT)
	orbit.y = clampf(orbit.y + relative.y * 0.06, -ORBIT_PITCH_LIMIT, ORBIT_PITCH_LIMIT)

func _process(delta: float) -> void:
	if camera == null:
		return
	_time += delta
	_apply(delta)

func _apply(delta: float) -> void:
	var p: Vector3 = PRESETS[mode]
	var t_yaw := p.x + orbit.x
	var t_pitch := p.y + orbit.y
	var t_dist := _base_dist * p.z
	if _celebrate:
		_celebrate_yaw += delta * 26.0
		t_yaw += _celebrate_yaw
		t_pitch = 24.0
		t_dist *= 0.84
	elif _defeat:
		t_pitch += 6.0
		t_dist *= 1.12

	var k := 1.0 - exp(-delta * 5.0) if delta > 0.0 else 1.0
	_cur_yaw = lerpf(_cur_yaw, t_yaw, k)
	_cur_pitch = lerpf(_cur_pitch, t_pitch, k)
	_cur_dist = lerpf(_cur_dist, t_dist, k)
	_cur_focus = _cur_focus.lerp(_focus, 1.0 - exp(-delta * 6.0) if delta > 0.0 else 1.0)

	# user orbit springs back after a couple of idle seconds
	_idle_orbit += delta
	if _idle_orbit > 2.5:
		orbit = orbit.lerp(Vector2.ZERO, 1.0 - exp(-delta * 1.2))

	var e := 0.0
	if _intro > 0.0:
		_intro = maxf(0.0, _intro - delta / INTRO_SECONDS)
		e = _intro * _intro * _intro
	var s_yaw := sin(_time * 0.35) * 1.4
	var s_pitch := sin(_time * 0.27 + 1.0) * 0.6
	var s_dist := sin(_time * 0.2) * 0.12
	_punch = maxf(0.0, _punch - delta * 3.0)

	var yaw := deg_to_rad(_cur_yaw + s_yaw + 55.0 * e)
	var pitch := deg_to_rad(clampf(_cur_pitch + s_pitch + 22.0 * e, 5.0, 82.0))
	var dist := (_cur_dist + s_dist) * (1.0 + 0.9 * e) * (1.0 - _punch * 0.035)
	var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
	camera.position = _cur_focus + offset
	camera.look_at(_cur_focus, Vector3.UP)
	camera.fov = BASE_FOV + 16.0 * e - _punch * 3.0

	if _shake > 0.001:
		camera.h_offset = randf_range(-_shake, _shake)
		camera.v_offset = randf_range(-_shake, _shake)
		_shake = maxf(0.0, _shake - delta * 1.1)
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0
