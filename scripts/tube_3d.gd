class_name Tube3D
extends Node3D

signal tapped(index: int)

var tube_index := 0
var capacity := 6
var glass: MeshInstance3D
var rim: MeshInstance3D
var base: MeshInstance3D
var light: OmniLight3D

func setup(index: int, cap: int) -> void:
    tube_index = index
    capacity = cap
    var height := max(4.9, float(capacity) * 0.9)

    glass = MeshInstance3D.new()
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = 0.68
    cylinder.bottom_radius = 0.78
    cylinder.height = height
    cylinder.radial_segments = 40
    var glass_mat := StandardMaterial3D.new()
    glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    glass_mat.albedo_color = Color(0.45, 0.72, 1.0, 0.16)
    glass_mat.metallic = 0.15
    glass_mat.roughness = 0.04
    glass_mat.emission_enabled = true
    glass_mat.emission = Color(0.12, 0.28, 0.8) * 0.12
    glass.material_override = glass_mat
    glass.mesh = cylinder
    add_child(glass)

    rim = MeshInstance3D.new()
    var torus := TorusMesh.new()
    torus.inner_radius = 0.60
    torus.outer_radius = 0.75
    torus.rings = 32
    torus.ring_segments = 12
    rim.mesh = torus
    rim.position.y = height / 2.0
    rim.material_override = glass_mat
    add_child(rim)

    base = MeshInstance3D.new()
    var base_mesh := CylinderMesh.new()
    base_mesh.top_radius = 0.92
    base_mesh.bottom_radius = 1.0
    base_mesh.height = 0.22
    base.mesh = base_mesh
    base.position.y = -height / 2.0
    var base_mat := StandardMaterial3D.new()
    base_mat.albedo_color = Color("#17204a")
    base_mat.metallic = 0.65
    base_mat.roughness = 0.22
    base.material_override = base_mat
    add_child(base)

    light = OmniLight3D.new()
    light.light_color = Color(0.3, 0.65, 1.0)
    light.light_energy = 0.0
    light.omni_range = 3.0
    add_child(light)

    var area := Area3D.new()
    area.input_ray_pickable = true
    area.collision_layer = 1
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(1.8, height + 0.5, 1.8)
    shape.shape = box
    area.add_child(shape)
    add_child(area)
    area.input_event.connect(_on_input)

func _on_input(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
    if event is InputEventScreenTouch and event.pressed:
        tapped.emit(tube_index)
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        tapped.emit(tube_index)

func set_highlight(value: bool) -> void:
    if light:
        light.light_energy = 2.4 if value else 0.0
    if rim:
        rim.scale = Vector3(1.08, 1.08, 1.08) if value else Vector3.ONE
