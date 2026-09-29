class_name Crystal3D
extends Node3D

signal tapped(crystal: Crystal3D)

# Meshes, materials and the pick shape are shared. The previous version built a
# fresh mesh, material and OmniLight3D for EVERY crystal on EVERY tap (up to
# ~85 lights on late levels). The GL Compatibility renderer only handles a
# handful of lights per object, so that was both slow and a stability risk.
static var _mesh_cache: Dictionary = {}
static var _mat_cache: Dictionary = {}
static var _sel_mat_cache: Dictionary = {}
static var _pick_shape: SphereShape3D = null

var color_id := "red"
var selected := false
var slot_index := 0
var phase := 0.0
var pulse := 0.0
var mesh: MeshInstance3D

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

static func _mesh_for(color_name: String) -> PrismMesh:
	if _mesh_cache.has(color_name):
		return _mesh_cache[color_name]
	var crystal := PrismMesh.new()
	crystal.size = Vector3(0.82, 0.96, 0.82)
	crystal.left_to_right = 0.62
	crystal.material = _material_for(color_name)
	_mesh_cache[color_name] = crystal
	return crystal

static func _shape() -> SphereShape3D:
	if _pick_shape == null:
		_pick_shape = SphereShape3D.new()
		_pick_shape.radius = 0.55
	return _pick_shape

func setup(color_name: String, local_pos: Vector3, seed_phase: float, index: int = 0) -> void:
	color_id = color_name
	position = local_pos
	phase = seed_phase
	slot_index = index

	mesh = MeshInstance3D.new()
	mesh.mesh = _mesh_for(color_name)
	mesh.rotation_degrees = Vector3(0, 30, 0)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)

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
	if event is InputEventScreenTouch and event.pressed:
		tapped.emit(self)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped.emit(self)

func set_selected(value: bool) -> void:
	selected = value
	if mesh == null:
		return
	if value:
		mesh.material_override = _selected_material_for(color_id)
	else:
		mesh.material_override = null
		mesh.scale = Vector3.ONE

# Scale tween on the node itself (the old version tweened "modulate", which
# does not exist on Node3D).
func play_match_pop() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(1.4, 1.4, 1.4), 0.08)
	tween.tween_property(self, "scale", Vector3.ZERO, 0.18)
	tween.tween_callback(queue_free)

func _process(delta: float) -> void:
	pulse += delta
	if mesh == null:
		return
	mesh.rotation.y += delta * 0.7
	var bob: float = sin(pulse * 2.0 + phase) * 0.035
	if selected:
		var s: float = 1.08 + sin(pulse * 9.0) * 0.035
		mesh.scale = Vector3.ONE * s
		bob += 0.18
	mesh.position.y = bob
