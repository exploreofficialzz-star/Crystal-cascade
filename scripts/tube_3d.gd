class_name Tube3D
extends Node3D

signal tapped(index: int)

const EMISSION_IDLE := 0.35
const EMISSION_ACTIVE := 2.8
const EMISSION_TARGET := 1.1
const RIM_IDLE := Color(0.25, 0.55, 1.0)
const GOLD_GLOW := Color(1.0, 0.85, 0.35)

# 0 = idle, 1 = selected, 2 = legal destination of the selected crystal
const MODE_IDLE := 0
const MODE_SELECTED := 1
const MODE_TARGET := 2

var tube_index := 0
var capacity := 6
var glass: MeshInstance3D
var rim: MeshInstance3D
var base: MeshInstance3D
var _rim_mat: StandardMaterial3D
var _base_mat: StandardMaterial3D
var _mode := 0
var _glow_color := Color(1.0, 0.85, 0.35)
var _tap := TapFilter.new()

# Height of a tube holding `cap` crystals; slot_y() is where crystal j sits inside it.
static func height_for(cap: int) -> float:
	return maxf(4.9, float(cap) * 0.9)

static func slot_y(cap: int, j: int) -> float:
	return -height_for(cap) * 0.5 + 0.65 + float(j) * 0.82

func setup(index: int, cap: int, look: Dictionary = {}) -> void:
	tube_index = index
	capacity = cap
	var height: float = height_for(capacity)
	var style: int = int(look.get("tube_style", 0))
	var glass_tint: Color = look.get("glass_tint", Color(0.45, 0.72, 1.0))
	var rim_tint: Color = look.get("rim_tint", Color(0.55, 0.78, 1.0))

	var glass_mat := StandardMaterial3D.new()
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.albedo_color = Color(glass_tint.r, glass_tint.g, glass_tint.b, 0.16)
	glass_mat.metallic = 0.15
	glass_mat.roughness = 0.04
	glass_mat.emission_enabled = true
	glass_mat.emission = Color(0.12, 0.28, 0.8) * 0.12

	glass = MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.68
	cylinder.bottom_radius = 0.78
	cylinder.radial_segments = 40
	# Cosmetic tube shapes (crystals always fit: the inner width never shrinks).
	match style:
		1:
			cylinder.top_radius = 0.68
			cylinder.bottom_radius = 0.90
		2:
			cylinder.top_radius = 0.86
			cylinder.bottom_radius = 0.78
		3:
			cylinder.top_radius = 0.78
			cylinder.bottom_radius = 0.86
			cylinder.radial_segments = 6
		4:
			cylinder.top_radius = 0.76
			cylinder.bottom_radius = 0.82
			cylinder.radial_segments = 12
	cylinder.height = height
	glass.mesh = cylinder
	glass.material_override = glass_mat
	# The glass wall must not cast a shadow, otherwise it darkens the crystals
	# inside it (alpha materials still write an opaque shadow).
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glass)

	_rim_mat = StandardMaterial3D.new()
	_rim_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_rim_mat.albedo_color = Color(rim_tint.r, rim_tint.g, rim_tint.b, 0.55)
	_rim_mat.metallic = 0.15
	_rim_mat.roughness = 0.1
	_rim_mat.emission_enabled = true
	_rim_mat.emission = Color(0.25, 0.55, 1.0)
	_rim_mat.emission_energy_multiplier = EMISSION_IDLE

	rim = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.60 + (cylinder.top_radius - 0.68) * 0.9
	torus.outer_radius = 0.75 + (cylinder.top_radius - 0.68) * 0.9
	torus.rings = 32
	torus.ring_segments = 12
	rim.mesh = torus
	rim.position.y = height / 2.0
	rim.material_override = _rim_mat
	rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rim)

	_base_mat = StandardMaterial3D.new()
	_base_mat.albedo_color = Color("#17204a")
	_base_mat.metallic = 0.65
	_base_mat.roughness = 0.22
	_base_mat.emission_enabled = true
	_base_mat.emission = Color(0.2, 0.4, 1.0)
	_base_mat.emission_energy_multiplier = 0.0

	base = MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.92
	base_mesh.bottom_radius = 1.0
	base_mesh.height = 0.22
	base.mesh = base_mesh
	base.position.y = -height / 2.0
	base.material_override = _base_mat
	base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(base)

	# No per-tube OmniLight3D any more: highlight is done with emission.
	var area := Area3D.new()
	area.input_ray_pickable = true
	area.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.7, height + 0.5, 1.5)
	shape.shape = box
	area.add_child(shape)
	add_child(area)
	area.input_event.connect(_on_input)

func _on_input(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if _tap.feed(event):
		tapped.emit(tube_index)

# Pop-in (and optional drop-in) used when tubes appear on the table.
func play_spawn(delay: float = 0.0, drop: bool = false) -> void:
	var target := position
	scale = Vector3(0.05, 0.05, 0.05)
	if drop:
		position = target + Vector3(0, 5.0, 0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector3.ONE, 0.5).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if drop:
		tw.tween_property(self, "position", target, 0.75).set_delay(delay).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

# Existing tubes glide to their new place when the layout changes.
func slide_to(target: Vector3, duration: float = 0.6) -> void:
	var tw := create_tween()
	tw.tween_property(self, "position", target, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# Glow for a moment (used to draw the eye to a freshly added tube).
func pulse_highlight(seconds: float) -> void:
	set_highlight(true)
	var tw := create_tween()
	tw.tween_interval(seconds)
	tw.tween_callback(set_highlight.bind(false))

# Selected tube: rim and base glow in `color`, the colour of the crystal about to move.
func set_highlight(value: bool, color: Color = Color(1.0, 0.85, 0.35)) -> void:
	_glow_color = color
	_mode = MODE_SELECTED if value else MODE_IDLE
	_apply_glow()

# Soft glow on a tube that can receive the selected crystal.
func set_target(value: bool, color: Color = Color(1.0, 0.85, 0.35)) -> void:
	if value:
		_glow_color = color
		_mode = MODE_TARGET
	elif _mode == MODE_TARGET:
		_mode = MODE_IDLE
	_apply_glow()

func _apply_glow() -> void:
	if _rim_mat == null or _base_mat == null:
		return
	if _mode == MODE_SELECTED:
		_rim_mat.emission_energy_multiplier = EMISSION_ACTIVE
		_rim_mat.emission = _glow_color
		_base_mat.emission = _glow_color
		_base_mat.emission_energy_multiplier = 1.6
		rim.scale = Vector3(1.08, 1.08, 1.08)
	elif _mode == MODE_TARGET:
		_rim_mat.emission_energy_multiplier = EMISSION_TARGET
		_rim_mat.emission = _glow_color
		_base_mat.emission = _glow_color
		_base_mat.emission_energy_multiplier = 0.7
		rim.scale = Vector3.ONE
	else:
		_rim_mat.emission_energy_multiplier = EMISSION_IDLE
		_rim_mat.emission = RIM_IDLE
		_base_mat.emission = Color(0.2, 0.4, 1.0)
		_base_mat.emission_energy_multiplier = 0.0
		rim.scale = Vector3.ONE
