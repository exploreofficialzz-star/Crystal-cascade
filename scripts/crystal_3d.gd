class_name Crystal3D
extends Node3D

signal tapped(crystal: Crystal3D)

var color_id := "red"
var selected := false
var slot_index := 0
var phase := 0.0
var mesh: MeshInstance3D
var glow: OmniLight3D
var base_y := 0.0
var pulse := 0.0
var moving := false

func setup(color_name: String, local_pos: Vector3, seed_phase: float, index: int = 0) -> void:
	print("[CC-DEBUG]     Crystal3D.setup(color=%s, index=%d) begin" % [color_name, index])
	color_id = color_name
	position = local_pos
	base_y = local_pos.y
	phase = seed_phase
	slot_index = index

	mesh = MeshInstance3D.new()
	var crystal := PrismMesh.new()
	crystal.size = Vector3(0.82, 0.96, 0.82)
	crystal.left_to_right = 0.62
	crystal.material = _material(color_name)
	mesh.mesh = crystal
	mesh.rotation_degrees = Vector3(0, 30, 0)
	add_child(mesh)

	glow = OmniLight3D.new()
	glow.light_color = GameData.COLOR_HEX[color_name]
	glow.light_energy = 0.0
	glow.omni_range = 2.2
	add_child(glow)

	var area := Area3D.new()
	area.input_ray_pickable = true
	area.collision_layer = 2
	area.collision_mask = 0
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.65
	collision.shape = sphere
	area.add_child(collision)
	add_child(area)
	area.input_event.connect(_on_input)
	print("[CC-DEBUG]     Crystal3D.setup(color=%s, index=%d) complete" % [color_name, index])

func _material(color_name: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = GameData.COLOR_HEX[color_name]
	material.metallic = 0.35
	material.roughness = 0.16
	material.emission_enabled = true
	material.emission = GameData.COLOR_HEX[color_name] * 0.22
	return material

func _on_input(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventScreenTouch and event.pressed:
		tapped.emit(self)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped.emit(self)

func set_selected(value: bool) -> void:
	selected = value
	if glow:
		glow.light_energy = 2.2 if value else 0.0
	if mesh:
		mesh.scale = Vector3(1.08, 1.08, 1.08) if value else Vector3.ONE

# CONFIRMED (not guessed) fix: Node3D has no "modulate" property — that
# belongs to CanvasItem (2D nodes) only, per Godot's own class hierarchy.
# The original tween.tween_property(self, "modulate:a", ...) targets a
# property that does not exist on a 3D node. This is currently dead code
# (nothing in main.gd calls play_match_pop yet) so it is NOT the level-1
# crash, but it would break the moment match animations get wired up, so
# it's fixed now on its own merits.
func play_match_pop() -> void:
	if glow:
		glow.light_energy = 3.5
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector3(1.4, 1.4, 1.4), 0.08)
	tween.tween_property(self, "scale", Vector3.ZERO, 0.18).set_delay(0.08)
	if glow:
		tween.tween_property(glow, "light_energy", 0.0, 0.22)

func _process(delta: float) -> void:
	pulse += delta
	if not mesh:
		return
	mesh.rotation.y += delta * 0.7
	var bob := sin(pulse * 2.0 + phase) * 0.035
	mesh.position.y = bob
	if selected:
		var s := 1.08 + sin(pulse * 9.0) * 0.035
		mesh.scale = Vector3.ONE * s
