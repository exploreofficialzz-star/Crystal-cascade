class_name GameWorld
extends Node3D

# ── Quality switches ──────────────────────────────────────────────────────────
# Flip these to true only after the game is confirmed stable on your phone.
# Shadows and glow are the most expensive things the GL Compatibility renderer
# does on mobile GPUs, and neither is needed for a readable puzzle board.
const KEY_LIGHT_SHADOWS := false
const ENABLE_GLOW := false
const PARTICLE_COUNT := 60

const CAMERA_OFFSETS := [
	Vector3(0, 8.4, 15.5),
	Vector3(9.8, 7.0, 10.5),
	Vector3(-10.0, 5.5, 10.5),
	Vector3(0, 13.5, 8.5),
]

var camera_rig: Node3D
var camera: Camera3D
var board: Node3D
var tubes_root: Node3D
var guardian: Guardian3D
var focus := Vector3.ZERO
var camera_mode := 0
var ambient_time := 0.0
var environment: WorldEnvironment
var star_particles: CPUParticles3D

var _board_focus := Vector3.ZERO
var _fit := 1.0
var _cam_focus := Vector3.ZERO
var _cam_offset := Vector3.ZERO
var _shake := 0.0

func build() -> void:
	_build_environment()
	_build_lights()
	board = Node3D.new()
	board.name = "Board"
	add_child(board)
	tubes_root = Node3D.new()
	tubes_root.name = "Tubes"
	board.add_child(tubes_root)
	camera_rig = Node3D.new()
	camera_rig.name = "CameraRig"
	add_child(camera_rig)
	camera = Camera3D.new()
	camera.fov = 52.0
	camera.current = true
	camera_rig.add_child(camera)
	guardian = Guardian3D.new()
	# Was (0, 0.2, -4): hidden behind the middle tube from the default camera.
	guardian.position = Vector3(0, 0.4, -6.5)
	guardian.scale = Vector3(1.5, 1.5, 1.5)
	add_child(guardian)
	_build_floor()
	_build_particles()
	_board_focus = Vector3(0, 2.5, 0)
	focus = _board_focus
	_snap_camera()

func _build_environment() -> void:
	environment = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#060a20")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#5265b0")
	env.ambient_light_energy = 0.72
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = ENABLE_GLOW
	env.glow_intensity = 1.15
	env.fog_enabled = true
	env.fog_light_color = Color("#172354")
	env.fog_density = 0.010
	environment.environment = env
	add_child(environment)

func _build_lights() -> void:
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-55, -25, 0)
	key.light_energy = 1.35
	key.shadow_enabled = KEY_LIGHT_SHADOWS
	if KEY_LIGHT_SHADOWS:
		key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		key.directional_shadow_max_distance = 35.0
	add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, 6, 5)
	fill.light_color = Color("#4d78ff")
	fill.light_energy = 5.5
	fill.omni_range = 18.0
	add_child(fill)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-8, 3, -4)
	rim.light_color = Color("#a44dff")
	rim.light_energy = 4.0
	rim.omni_range = 14.0
	add_child(rim)

func _build_floor() -> void:
	var floor_mi := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(34, 34)
	floor_mi.mesh = mesh
	floor_mi.position.y = -0.58
	floor_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#0d1430")
	mat.metallic = 0.55
	mat.roughness = 0.25
	floor_mi.material_override = mat
	add_child(floor_mi)

# The old particle mesh was a default SphereMesh: 64 x 32 segments = ~4,000
# triangles PER particle, x120 particles = ~490k triangles every frame just for
# background sparkles. Now 6 x 3 segments, unshaded.
func _build_particles() -> void:
	star_particles = CPUParticles3D.new()
	star_particles.amount = PARTICLE_COUNT
	star_particles.lifetime = 8.0
	star_particles.position = Vector3(0, 4, 1)
	star_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	star_particles.emission_box_extents = Vector3(11, 5, 7)
	star_particles.gravity = Vector3(0, -0.10, 0)
	star_particles.initial_velocity_min = 0.08
	star_particles.initial_velocity_max = 0.38
	star_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var particle_mesh := SphereMesh.new()
	particle_mesh.radius = 0.04
	particle_mesh.height = 0.08
	particle_mesh.radial_segments = 6
	particle_mesh.rings = 3
	var particle_material := StandardMaterial3D.new()
	particle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	particle_material.albedo_color = Color(0.65, 0.82, 1.0)
	particle_mesh.material = particle_material
	star_particles.mesh = particle_mesh
	add_child(star_particles)
	star_particles.emitting = true

func set_board_visible(value: bool) -> void:
	if board:
		board.visible = value

# Removed tubes leave the tree immediately (so counts and indices are correct)
# but are freed with queue_free(). Freeing them synchronously could destroy a
# node that is still inside its own signal callback.
func arrange(tube_count: int, capacity: int) -> void:
	for child in tubes_root.get_children():
		tubes_root.remove_child(child)
		child.queue_free()
	if tube_count <= 0:
		return
	var cols: int = mini(4, tube_count)
	var rows: int = int(ceil(float(tube_count) / float(cols)))
	var spacing_x := 2.15
	var spacing_z := 2.05
	for i in range(tube_count):
		var row: int = i / cols
		var col: int = i % cols
		var x: float = (float(col) - float(cols - 1) / 2.0) * spacing_x
		var z: float = (float(row) - float(rows - 1) / 2.0) * spacing_z
		var tube := Tube3D.new()
		tube.setup(i, capacity)
		tube.position = Vector3(x, capacity * 0.45 - 0.1, z)
		tubes_root.add_child(tube)
	_board_focus = Vector3(0, capacity * 0.42, 0)
	focus = _board_focus
	# Pull the camera back a little for 3-row boards and tall tubes so the
	# whole board stays inside the narrow portrait frustum.
	_fit = 1.0 + 0.09 * float(rows - 1) + 0.03 * maxf(0.0, float(capacity - 6))
	camera_mode = 0
	_snap_camera()

func get_tube(index: int) -> Tube3D:
	if tubes_root == null:
		return null
	if index >= 0 and index < tubes_root.get_child_count():
		return tubes_root.get_child(index) as Tube3D
	return null

# The camera only leans 22% of the way toward the tapped tube. Following it
# fully panned the far side of the board out of the portrait frame.
func focus_on_tube(index: int) -> void:
	var tube := get_tube(index)
	if tube == null:
		return
	var p: Vector3 = tube.global_position
	focus = Vector3(
		lerpf(_board_focus.x, p.x, 0.22),
		_board_focus.y,
		lerpf(_board_focus.z, p.z, 0.22))

func set_camera_mode(mode: int) -> void:
	camera_mode = posmod(mode, CAMERA_OFFSETS.size())

func next_camera() -> void:
	set_camera_mode(camera_mode + 1)

func _camera_offset() -> Vector3:
	var offset: Vector3 = CAMERA_OFFSETS[camera_mode]
	return offset * _fit

func _snap_camera() -> void:
	_cam_focus = focus
	_cam_offset = _camera_offset()
	if camera:
		camera.global_position = _cam_focus + _cam_offset
		camera.look_at(_cam_focus, Vector3.UP)

# Screen shake uses the camera's own h/v offset, so it can never fight with
# camera movement (the old version tweened camera.position while another tween
# was moving it).
func pulse_camera(intensity: float = 0.18) -> void:
	_shake = maxf(_shake, intensity)

func _process(delta: float) -> void:
	ambient_time += delta
	if camera == null:
		return
	var k: float = 1.0 - exp(-delta * 7.0)
	_cam_focus = _cam_focus.lerp(focus, k)
	_cam_offset = _cam_offset.lerp(_camera_offset(), k)
	camera.global_position = _cam_focus + _cam_offset
	camera.look_at(_cam_focus, Vector3.UP)
	if _shake > 0.001:
		camera.h_offset = randf_range(-_shake, _shake)
		camera.v_offset = randf_range(-_shake, _shake)
		_shake = maxf(0.0, _shake - delta * 1.1)
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0
	if star_particles:
		star_particles.rotation.y += delta * 0.01
