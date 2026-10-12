class_name Crystal3D
extends Node3D

signal tapped(crystal: Crystal3D)

# Meshes, materials and the pick shape are shared. The previous version built a
# fresh mesh, material and OmniLight3D for EVERY crystal on EVERY tap (up to
# ~85 lights on late levels). The GL Compatibility renderer only handles a
# handful of lights per object, so that was both slow and a stability risk.
static var _mesh_cache: Dictionary = {}
# Cosmetic crystal cut for the current level (see LookBook): 0 prism, 1 gem, 2 shard, 3 cube.
static var cut_style := 0
static var _mat_cache: Dictionary = {}
static var _sel_mat_cache: Dictionary = {}
static var _pick_shape: SphereShape3D = null
static var _mystery_mat: StandardMaterial3D = null
static var _orb: SphereMesh = null
static var _halo_mesh: TorusMesh = null
static var _halo_mat: StandardMaterial3D = null

var color_id := "red"
var selected := false
var slot_index := 0
var phase := 0.0
var pulse := 0.0
var mesh: MeshInstance3D
var is_hidden := false
var is_gold := false
var _halo: MeshInstance3D = null
var _tap := TapFilter.new()

static func _base_color(color_name: String) -> Color:
	if GameData.COLOR_HEX.has(color_name):
		return GameData.COLOR_HEX[color_name]
	return Color.WHITE

static func _material_for(color_name: String) -> StandardMaterial3D:
	if _mat_cache.has(color_name):
		return _mat_cache[color_name]
	var c: Color = _base_color(color_name)
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = 0.35
	m.roughness = 0.16
	m.emission_enabled = true
	m.emission = c * 0.22
	_mat_cache[color_name] = m
	return m

static func _selected_material_for(color_name: String) -> StandardMaterial3D:
	if _sel_mat_cache.has(color_name):
		return _sel_mat_cache[color_name]
	var c: Color = _base_color(color_name)
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = 0.2
	m.roughness = 0.12
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 0.9
	_sel_mat_cache[color_name] = m
	return m

static func _mesh_for(color_name: String) -> Mesh:
	var key := "%d_%s" % [cut_style, color_name]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var made: Mesh
	match cut_style:
		1:
			# gem: a faceted double cone
			var gem := CylinderMesh.new()
			gem.top_radius = 0.0
			gem.bottom_radius = 0.46
			gem.height = 0.96
			gem.radial_segments = 6
			gem.material = _material_for(color_name)
			made = gem
		2:
			# shard: a tall, slim prism
			var shard := PrismMesh.new()
			shard.size = Vector3(0.62, 1.12, 0.62)
			shard.left_to_right = 0.5
			shard.material = _material_for(color_name)
			made = shard
		3:
			# cube: a small cut block
			var cube := BoxMesh.new()
			cube.size = Vector3(0.70, 0.74, 0.70)
			cube.material = _material_for(color_name)
			made = cube
		_:
			var crystal := PrismMesh.new()
			crystal.size = Vector3(0.82, 0.96, 0.82)
			crystal.left_to_right = 0.62
			crystal.material = _material_for(color_name)
			made = crystal
	_mesh_cache[key] = made
	return made

# Shadow crystal: colour hidden until it reaches the top of its tube.
static func _mystery_material() -> StandardMaterial3D:
	if _mystery_mat == null:
		_mystery_mat = StandardMaterial3D.new()
		_mystery_mat.albedo_color = Color("#2a2150")
		_mystery_mat.metallic = 0.5
		_mystery_mat.roughness = 0.3
		_mystery_mat.emission_enabled = true
		_mystery_mat.emission = Color("#6a4cff")
		_mystery_mat.emission_energy_multiplier = 0.55
	return _mystery_mat

# Shadow crystals are dark orbs, so they cannot be mistaken for coloured prisms.
static func _orb_mesh() -> SphereMesh:
	if _orb == null:
		_orb = SphereMesh.new()
		_orb.radius = 0.40
		_orb.height = 0.80
		_orb.radial_segments = 16
		_orb.rings = 8
	return _orb

static func _halo_parts() -> void:
	if _halo_mesh == null:
		_halo_mesh = TorusMesh.new()
		_halo_mesh.inner_radius = 0.50
		_halo_mesh.outer_radius = 0.60
		_halo_mesh.rings = 24
		_halo_mesh.ring_segments = 8
		_halo_mat = StandardMaterial3D.new()
		_halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_halo_mat.albedo_color = Color(1.0, 0.82, 0.25)

static func _shape() -> SphereShape3D:
	if _pick_shape == null:
		_pick_shape = SphereShape3D.new()
		_pick_shape.radius = 0.55
	return _pick_shape

# flags: Rules.F_HIDDEN (shadow crystal, hidden until on top), Rules.F_GOLD (bonus coins).
func setup(color_name: String, local_pos: Vector3, seed_phase: float, index: int = 0, flags: int = 0) -> void:
	color_id = color_name
	position = local_pos
	phase = seed_phase
	slot_index = index
	is_hidden = (flags & Rules.F_HIDDEN) != 0
	is_gold = (flags & Rules.F_GOLD) != 0

	mesh = MeshInstance3D.new()
	mesh.mesh = _orb_mesh() if is_hidden else _mesh_for(color_name)
	mesh.rotation_degrees = Vector3(0, 30, 0)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if is_hidden:
		mesh.material_override = _mystery_material()
	add_child(mesh)
	if is_gold:
		_halo_parts()
		_halo = MeshInstance3D.new()
		_halo.mesh = _halo_mesh
		_halo.material_override = _halo_mat
		_halo.position = Vector3(0, -0.02, 0)
		_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_halo)

	var area := Area3D.new()
	area.input_ray_pickable = true
	area.collision_layer = 2
	area.collision_mask = 0
	var collision := CollisionShape3D.new()
	collision.shape = _shape()
	area.add_child(collision)
	add_child(area)
	area.input_event.connect(_on_input)

func _on_input(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if _tap.feed(event):
		tapped.emit(self)

func set_selected(value: bool) -> void:
	selected = value
	if mesh == null:
		return
	if value:
		mesh.material_override = _selected_material_for(color_id)
	else:
		mesh.material_override = _mystery_material() if is_hidden else null
		mesh.scale = Vector3.ONE

# Scale tween on the node itself (the old version tweened "modulate", which
# does not exist on Node3D).
func play_match_pop() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(1.4, 1.4, 1.4), 0.08)
	tween.tween_property(self, "scale", Vector3(0.02, 0.02, 0.02), 0.18)
	tween.tween_callback(queue_free)

# A shadow crystal just surfaced: quick pop.
func play_reveal() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(1.4, 1.4, 1.4), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector3.ONE, 0.16)

# A conjured crystal drops in.
func play_spawn() -> void:
	scale = Vector3(0.05, 0.05, 0.05)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	pulse += delta
	if mesh == null:
		return
	if _halo != null:
		var hs: float = 1.0 + sin(pulse * 3.0 + phase) * 0.07
		_halo.scale = Vector3(hs, 1.0, hs)
	mesh.rotation.y += delta * 0.7
	var bob: float = sin(pulse * 2.0 + phase) * 0.035
	if selected:
		var s: float = 1.08 + sin(pulse * 9.0) * 0.035
		mesh.scale = Vector3.ONE * s
		bob += 0.18
	mesh.position.y = bob
