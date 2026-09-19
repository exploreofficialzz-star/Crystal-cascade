class_name Tube3D
extends Node3D

signal tapped(index: int)

var tube_index := 0
var capacity   := 6
var glass:  MeshInstance3D
var rim:    MeshInstance3D
var base:   MeshInstance3D
var light:  OmniLight3D

func setup(index: int, cap: int) -> void:
	tube_index = index
	capacity   = cap
	var h := max(4.9, float(capacity) * 0.90)

	glass = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius      = 0.68
	cyl.bottom_radius   = 0.78
	cyl.height          = h
	cyl.radial_segments = 40
	var gm := StandardMaterial3D.new()
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.albedo_color  = Color(0.45, 0.72, 1.0, 0.16)
	gm.metallic      = 0.15
	gm.roughness     = 0.04
	glass.material_override = gm
	glass.mesh = cyl
	add_child(glass)

	rim = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius  = 0.60
	torus.outer_radius  = 0.75
	torus.rings         = 32
	torus.ring_segments = 12
	rim.mesh = torus
	rim.position.y = h / 2.0
	rim.material_override = gm
	add_child(rim)

	base = MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius    = 0.92
	bm.bottom_radius = 1.00
	bm.height        = 0.22
	base.mesh = bm
	base.position.y = -h / 2.0
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color("#17204a")
	bmat.metallic     = 0.65
	bmat.roughness    = 0.22
	base.material_override = bmat
	add_child(base)

	light = OmniLight3D.new()
	light.light_color  = Color(0.3, 0.65, 1.0)
	light.light_energy = 0.0
	light.omni_range   = 3.0
	add_child(light)

	# Area handles input on empty tubes. Crystal areas handle taps when
	# crystals are present. main.gd debounces both so only one call fires.
	var area := Area3D.new()
	area.input_ray_pickable = true
	area.collision_layer    = 1
	var shape := CollisionShape3D.new()
	var box   := BoxShape3D.new()
	box.size  = Vector3(1.8, h + 0.5, 1.8)
	shape.shape = box
	area.add_child(shape)
	add_child(area)
	area.input_event.connect(_on_area_input)

func _on_area_input(_camera: Node, event: InputEvent,
		_pos: Vector3, _normal: Vector3, _shape: int) -> void:
	if event is InputEventScreenTouch and event.pressed:
		tapped.emit(tube_index)
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		tapped.emit(tube_index)

func set_highlight(value: bool) -> void:
	if light: light.light_energy = 2.4 if value else 0.0
	if rim:   rim.scale = Vector3(1.08, 1.08, 1.08) if value else Vector3.ONE
