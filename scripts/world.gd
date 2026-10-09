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
var _env: Environment
var _fill_light: OmniLight3D
var _rim_light: OmniLight3D
var _backdrop_mat: StandardMaterial3D
var _particle_mat: StandardMaterial3D
var _burst_fx: CPUParticles3D

# One look per level theme (see LevelGen.THEME_NAMES): sky, lights, backdrop and
# cloth tint, so every level feels like a different place.
const THEMES := [
	{"bg": Color("#060a20"), "ambient": Color("#6272c8"), "fog": Color("#172354"), "fill": Color("#5c85ff"), "rim": Color("#b45cff"), "tint": Color(1.0, 1.0, 1.0), "cloth": Color(1.0, 1.0, 1.0), "particle": Color(0.65, 0.82, 1.0)},
	{"bg": Color("#0d0626"), "ambient": Color("#8a62d8"), "fog": Color("#2a1560"), "fill": Color("#a56bff"), "rim": Color("#ff5cd6"), "tint": Color(1.25, 0.8, 1.3), "cloth": Color(1.15, 0.9, 1.2), "particle": Color(0.85, 0.7, 1.0)},
	{"bg": Color("#041428"), "ambient": Color("#62a8d8"), "fog": Color("#123a66"), "fill": Color("#7fd8ff"), "rim": Color("#9fb8ff"), "tint": Color(0.7, 1.1, 1.45), "cloth": Color(0.85, 1.05, 1.25), "particle": Color(0.8, 0.95, 1.0)},
	{"bg": Color("#031a14"), "ambient": Color("#62d8a0"), "fog": Color("#0f4a36"), "fill": Color("#5cffb0"), "rim": Color("#c8ff5c"), "tint": Color(0.7, 1.3, 0.95), "cloth": Color(0.85, 1.2, 0.95), "particle": Color(0.7, 1.0, 0.8)},
	{"bg": Color("#1a0805"), "ambient": Color("#d88a62"), "fog": Color("#4a1c10"), "fill": Color("#ff9a5c"), "rim": Color("#ff4f5c"), "tint": Color(1.5, 0.95, 0.6), "cloth": Color(1.25, 0.95, 0.8), "particle": Color(1.0, 0.8, 0.55)},
	{"bg": Color("#1a0516"), "ambient": Color("#d862b8"), "fog": Color("#4a1038"), "fill": Color("#ff7ac8"), "rim": Color("#ffa05c"), "tint": Color(1.4, 0.8, 1.05), "cloth": Color(1.25, 0.9, 1.0), "particle": Color(1.0, 0.75, 0.9)},
	{"bg": Color("#030816"), "ambient": Color("#4a62d8"), "fog": Color("#0c1c4a"), "fill": Color("#5cffd0"), "rim": Color("#b45cff"), "tint": Color(0.75, 1.15, 1.1), "cloth": Color(0.85, 1.05, 1.15), "particle": Color(0.6, 1.0, 0.9)},
	{"bg": Color("#181206"), "ambient": Color("#d8c062"), "fog": Color("#4a3a10"), "fill": Color("#ffe05c"), "rim": Color("#ffb05c"), "tint": Color(1.45, 1.2, 0.8), "cloth": Color(1.2, 1.1, 0.85), "particle": Color(1.0, 0.92, 0.6)},
	{"bg": Color("#12061f"), "ambient": Color("#b862d8"), "fog": Color("#3a1060"), "fill": Color("#ffd05c"), "rim": Color("#c05cff"), "tint": Color(1.3, 0.95, 1.35), "cloth": Color(1.2, 0.95, 1.2), "particle": Color(1.0, 0.85, 0.5)},
]

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
	_build_burst()

func _build_environment() -> void:
	environment = WorldEnvironment.new()
	var env := Environment.new()
	_env = env
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
	_fill_light = fill
	add_child(fill)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-8, 4, -5)
	rim.light_color = Color("#b45cff")
	rim.light_energy = 4.0
	rim.omni_range = 16.0
	_rim_light = rim
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
	_backdrop_mat = mat
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
	_particle_mat = particle_material
	star_particles.mesh = particle_mesh
	add_child(star_particles)
	star_particles.emitting = true

# Re-colours the sky, lights, backdrop and cloth for a level theme. Call before arrange().
func apply_theme(index: int) -> void:
	var t: Dictionary = THEMES[clampi(index, 0, THEMES.size() - 1)]
	if _env != null:
		_env.background_color = t["bg"]
		_env.ambient_light_color = t["ambient"]
		_env.fog_light_color = t["fog"]
	if _fill_light != null:
		_fill_light.light_color = t["fill"]
	if _rim_light != null:
		_rim_light.light_color = t["rim"]
	if _backdrop_mat != null and _backdrop_mat.albedo_texture != null:
		_backdrop_mat.albedo_color = t["tint"]
	if _particle_mat != null:
		_particle_mat.albedo_color = t["particle"]
	if table != null:
		table.cloth_tint = t["cloth"]

# ONE shared one-shot emitter for the match sparkle. (Creating a fresh particle
# node, mesh and material for every cleared triple churned the GPU resources of
# the GL Compatibility renderer; re-using one emitter does not.)
func _build_burst() -> void:
	var p := CPUParticles3D.new()
	p.name = "MatchBurst"
	p.amount = 24
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.5
	p.direction = Vector3(0, 1, 0)
	p.spread = 180.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.5
	p.gravity = Vector3(0, -4.0, 0)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := SphereMesh.new()
	m.radius = 0.07
	m.height = 0.14
	m.radial_segments = 6
	m.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	m.material = mat
	p.mesh = m
	add_child(p)
	_burst_fx = p

# Sparkle burst above a tube (a cleared triple).
func burst(tube_index: int, color: Color) -> void:
	var tube := get_tube(tube_index)
	if tube == null or _burst_fx == null:
		return
	_burst_fx.global_position = tube.global_position + Vector3(0, 0.6, 0)
	_burst_fx.color = color
	_burst_fx.restart()

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
# a use-after-free. `old_positions` (extra-tube case) makes existing tubes glide
# to their new places and the new tube drop in.
func arrange(tube_count: int, capacity: int, intro: bool = true, old_positions: Array = []) -> void:
	for child in tubes_root.get_children():
		tubes_root.remove_child(child)
		child.queue_free()
	if tube_count <= 0:
		return
	var tube_h: float = Tube3D.height_for(capacity)
	var layout := BoardLayout.compute(tube_count, tube_h)
	var pos: Array = layout["pos"]
	var rows: int = int(layout["rows"])
	var riser: float = float(layout["riser"])
	var base_y: float = tube_h * 0.5 - 0.1
	for i in range(tube_count):
		var p: Vector3 = pos[i]
		var target := Vector3(p.x, base_y + p.y, p.z)
		var tube := Tube3D.new()
		tube.setup(i, capacity)
		tube.position = target
		tubes_root.add_child(tube)
		if old_positions.size() > 0:
			if i < old_positions.size():
				var from: Vector3 = old_positions[i]
				tube.position = from
				tube.slide_to(target)
			else:
				tube.play_spawn(0.25, true)
				tube.pulse_highlight(1.8)
		elif intro:
			tube.play_spawn(0.1 * float(i), false)
	table.build(layout)
	var height: float = tube_h + ((riser + float(layout["back_dz"]) * 0.75) if rows > 1 else 0.0)
	var center_y: float = base_y + (riser * 0.5 if rows > 1 else 0.0)
	director.configure(center_y, float(layout["half_w"]), height, rows, old_positions.size() == 0)
	if intro:
		director.play_intro()
	elif old_positions.size() > 0:
		cam_new_tube(tube_count - 1)

func tube_positions() -> Array:
	var out: Array = []
	for child in tubes_root.get_children():
		out.append((child as Node3D).position)
	return out

func get_tube(index: int) -> Tube3D:
	if tubes_root == null:
		return null
	if index >= 0 and index < tubes_root.get_child_count():
		return tubes_root.get_child(index) as Tube3D
	return null

func _tube_point(index: int) -> Vector3:
	var tube := get_tube(index)
	if tube == null:
		return Vector3.ZERO
	return tube.global_position

func focus_on_tube(index: int) -> void:
	if director != null:
		director.on_select(_tube_point(index))

func release_focus() -> void:
	pass

func cam_move(from_index: int, to_index: int) -> void:
	if director != null:
		director.on_move(_tube_point(from_index), _tube_point(to_index))

func cam_match(index: int) -> void:
	if director != null:
		director.on_match(_tube_point(index))

func cam_new_tube(index: int) -> void:
	if director != null:
		director.on_new_tube(_tube_point(index))

func cam_hint(index: int) -> void:
	if director != null:
		director.on_hint(_tube_point(index))

func set_auto_camera(value: bool) -> void:
	if director != null:
		director.set_auto(value)

func tube_screen_pos(index: int) -> Vector2:
	var tube := get_tube(index)
	if tube == null or camera == null:
		return Vector2.ZERO
	return camera.unproject_position(tube.global_position)

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
