class_name GameWorld
extends Node3D

# ── Quality switches ──────────────────────────────────────────────────────────
# Shadows and glow are the most expensive things the GL Compatibility renderer
# does on phones. Leave them off unless you have tested a low-end device.
const KEY_LIGHT_SHADOWS := false
const ENABLE_GLOW := false
const PARTICLE_COUNT := 60
const SPACING_X := 2.15
const SPACING_Z := 2.05

var board: Node3D
var tubes_root: Node3D
var table: Table3D
var director: CameraDirector
var camera: Camera3D
var environment: WorldEnvironment
var star_particles: CPUParticles3D

func build() -> void:
	_build_environment()
	_build_lights()
	_build_backdrop()
	_build_floor()
	board = Node3D.new()
	board.name = "Board"
	add_child(board)
	table = Table3D.new()
	board.add_child(table)
	tubes_root = Node3D.new()
	tubes_root.name = "Tubes"
	board.add_child(tubes_root)
	director = CameraDirector.new()
	add_child(director)
	camera = director.camera
	_build_particles()

func _build_environment() -> void:
	environment = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#060a20")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#6272c8")
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = ENABLE_GLOW
	env.glow_intensity = 1.15
	env.fog_enabled = true
	env.fog_light_color = Color("#172354")
	env.fog_density = 0.008
	environment.environment = env
	add_child(environment)

func _build_lights() -> void:
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-52, -25, 0)
	key.light_energy = 1.45
	key.shadow_enabled = KEY_LIGHT_SHADOWS
	if KEY_LIGHT_SHADOWS:
		key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		key.directional_shadow_max_distance = 35.0
	add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, 7, 6)
	fill.light_color = Color("#5c85ff")
	fill.light_energy = 5.5
	fill.omni_range = 20.0
	add_child(fill)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-8, 4, -5)
	rim.light_color = Color("#b45cff")
	rim.light_energy = 4.0
	rim.omni_range = 16.0
	add_child(rim)

# Curved wall behind the table (an arc of a cylinder, 156 degrees wide).
func _backdrop_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 24
	var radius := 36.0
	var y0 := -4.0
	var y1 := 26.0
	for i in range(seg):
		var t0 := float(i) / float(seg)
		var t1 := float(i + 1) / float(seg)
		var a0 := deg_to_rad(lerpf(-78.0, 78.0, t0))
		var a1 := deg_to_rad(lerpf(-78.0, 78.0, t1))
		var p00 := Vector3(sin(a0) * radius, y0, -cos(a0) * radius)
		var p10 := Vector3(sin(a1) * radius, y0, -cos(a1) * radius)
		var p11 := Vector3(sin(a1) * radius, y1, -cos(a1) * radius)
		var p01 := Vector3(sin(a0) * radius, y1, -cos(a0) * radius)
		var verts := [p00, p10, p11, p00, p11, p01]
		var uvs := [Vector2(t0, 1), Vector2(t1, 1), Vector2(t1, 0), Vector2(t0, 1), Vector2(t1, 0), Vector2(t0, 0)]
		for k in range(6):
			st.set_uv(uvs[k])
			st.set_normal(Vector3(0, 0, 1))
			st.add_vertex(verts[k])
	return st.commit()

func _build_backdrop() -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _backdrop_mesh()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var t: Texture2D = Ui.tex("res://assets/textures/lab_backdrop.png")
	if t != null:
		mat.albedo_texture = t
	else:
		mat.albedo_color = Color("#141a48")
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _build_floor() -> void:
	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(90, 90)
	floor_mi.mesh = plane
	floor_mi.position.y = Table3D.FLOOR_Y
	floor_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#0c1233")
	mat.metallic = 0.35
	mat.roughness = 0.55
	floor_mi.material_override = mat
	add_child(floor_mi)

	var rug := MeshInstance3D.new()
	var rug_plane := PlaneMesh.new()
	rug_plane.size = Vector2(30, 30)
	rug.mesh = rug_plane
	rug.position.y = Table3D.FLOOR_Y + 0.02
	rug.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var rug_mat := StandardMaterial3D.new()
	rug_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rug_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rug_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var rt: Texture2D = Ui.tex("res://assets/textures/rune_rug.png")
	if rt != null:
		rug_mat.albedo_texture = rt
	rug_mat.albedo_color = Color(0.7, 0.75, 0.9, 1.0)
	rug.material_override = rug_mat
	add_child(rug)

# Low-poly, unshaded sparkles (the old sphere mesh cost ~490k triangles/frame).
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

# The whole 3D world is hidden (and stops updating) while a menu is open.
func set_active(value: bool) -> void:
	visible = value
	set_process(value)
	if director != null:
		director.set_process(value)

func set_board_visible(value: bool) -> void:
	if board != null:
		board.visible = value

# Removed tubes leave the tree immediately (counts and indices stay correct) but
# are freed with queue_free(); freeing a node inside its own signal callback is
# a use-after-free.
func arrange(tube_count: int, capacity: int, intro: bool = true) -> void:
	for child in tubes_root.get_children():
		tubes_root.remove_child(child)
		child.queue_free()
	if tube_count <= 0:
		return
	var cols: int = mini(4, tube_count)
	var rows: int = int(ceil(float(tube_count) / float(cols)))
	for i in range(tube_count):
		var row: int = i / cols
		var col: int = i % cols
		var x: float = (float(col) - float(cols - 1) / 2.0) * SPACING_X
		var z: float = (float(row) - float(rows - 1) / 2.0) * SPACING_Z
		var tube := Tube3D.new()
		tube.setup(i, capacity)
		tube.position = Vector3(x, capacity * 0.45 - 0.1, z)
		tubes_root.add_child(tube)
	table.build(tube_count, cols, rows, SPACING_X, SPACING_Z)
	var height: float = maxf(4.9, float(capacity) * 0.9)
	var half_w: float = float(cols - 1) * SPACING_X * 0.5 + 1.0
	director.configure(capacity * 0.45 - 0.1, half_w, height)
	if intro:
		director.play_intro()

func get_tube(index: int) -> Tube3D:
	if tubes_root == null:
		return null
	if index >= 0 and index < tubes_root.get_child_count():
		return tubes_root.get_child(index) as Tube3D
	return null

func focus_on_tube(index: int) -> void:
	var tube := get_tube(index)
	if tube != null and director != null:
		director.focus_on(tube.global_position)

func release_focus() -> void:
	if director != null:
		director.release_focus()

func tube_screen_pos(index: int) -> Vector2:
	var tube := get_tube(index)
	if tube == null or camera == null:
		return Vector2.ZERO
	return camera.unproject_position(tube.global_position)

func next_camera() -> void:
	if director != null:
		director.next_mode()

func pulse_camera(intensity: float = 0.18) -> void:
	if director != null:
		director.shake(intensity)

func punch(amount: float = 1.0) -> void:
	if director != null:
		director.punch(amount)

func orbit_drag(relative: Vector2) -> void:
	if director != null:
		director.orbit_drag(relative)

func celebrate() -> void:
	if director != null:
		director.celebrate()

func defeat() -> void:
	if director != null:
		director.defeat()

func calm() -> void:
	if director != null:
		director.calm()
