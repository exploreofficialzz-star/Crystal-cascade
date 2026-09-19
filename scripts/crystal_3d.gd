class_name Crystal3D
extends Node3D

signal tapped(crystal: Crystal3D)

var color_id   := "red"
var selected   := false
var slot_index := 0
var phase      := 0.0
var pulse      := 0.0
var mesh:  MeshInstance3D
var glow:  OmniLight3D

func setup(color_name: String, local_pos: Vector3, seed_phase: float, index: int = 0) -> void:
	color_id   = color_name
	position   = local_pos
	phase      = seed_phase
	slot_index = index

	mesh = MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.82, 0.96, 0.82)
	prism.left_to_right = 0.62
	prism.material = _make_material(color_name)
	mesh.mesh = prism
	mesh.rotation_degrees = Vector3(0, 30, 0)
	add_child(mesh)

	glow = OmniLight3D.new()
	glow.light_color  = GameData.COLOR_HEX[color_name]
	glow.light_energy = 0.0
	glow.omni_range   = 2.2
	add_child(glow)

	var area := Area3D.new()
	area.input_ray_pickable = true
	area.collision_layer    = 2
	area.collision_mask     = 0
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.65
	col.shape = sphere
	area.add_child(col)
	add_child(area)
	area.input_event.connect(_on_area_input)

func _make_material(color_name: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color     = GameData.COLOR_HEX[color_name]
	m.metallic         = 0.35
	m.roughness        = 0.16
	m.emission_enabled = true
	m.emission         = GameData.COLOR_HEX[color_name] * 0.22
	return m

func _on_area_input(_camera: Node, event: InputEvent,
		_pos: Vector3, _normal: Vector3, _shape: int) -> void:
	if event is InputEventScreenTouch and event.pressed:
		tapped.emit(self)
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		tapped.emit(self)

func set_selected(value: bool) -> void:
	selected = value
	if glow: glow.light_energy = 2.2 if value else 0.0
	if mesh: mesh.scale = Vector3(1.08, 1.08, 1.08) if value else Vector3.ONE

# BUG-003 FIX: Node3D has no `modulate` property — that's CanvasItem (2D) only.
# Tweening "modulate:a" on a Node3D throws a runtime error. Fixed with a
# 3D-compatible scale-burst + glow-fade animation.
func play_match_pop() -> void:
	if glow: glow.light_energy = 3.5
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector3(1.4, 1.4, 1.4), 0.08)
	tw.tween_property(self, "scale", Vector3.ZERO, 0.18).set_delay(0.08)
	if glow:
		tw.tween_property(glow, "light_energy", 0.0, 0.22)

func _process(delta: float) -> void:
	pulse += delta
	if not mesh: return
	mesh.rotation.y  += delta * 0.70
	mesh.position.y   = sin(pulse * 2.0 + phase) * 0.035
	if selected:
		mesh.scale = Vector3.ONE * (1.08 + sin(pulse * 9.0) * 0.035)
