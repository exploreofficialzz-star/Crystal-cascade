class_name AvatarPortrait
extends Control

# Cass, full body, standing at the right edge of the game screen. She is drawn in
# her own small SubViewport (own World3D, transparent background) so camera
# movement in the main scene never affects her. Tap her upper body to make her
# wave; only that area takes input, so she never blocks the tubes below.

signal poked

const VIEW := Vector2i(340, 470)

var guardian: Guardian3D
var _viewport: SubViewport

func _init() -> void:
	custom_minimum_size = Vector2(300, 414)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	# soft glowing floor under her feet
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0.49, 0.94, 1.0, 0.55), Color(0.49, 0.94, 1.0, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 1.0])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 128
	gt.height = 128
	var glow := TextureRect.new()
	glow.texture = gt
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	glow.offset_top = -78
	glow.offset_bottom = 8
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)

	_viewport = SubViewport.new()
	_viewport.size = VIEW
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.gui_disable_input = true
	add_child(_viewport)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#9aa0ff")
	env.ambient_light_energy = 0.9
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_viewport.add_child(world_env)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-32, 25, 0)
	key.light_energy = 1.3
	_viewport.add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-1.6, 1.2, 2.4)
	fill.light_color = Color("#6f9bff")
	fill.light_energy = 2.4
	fill.omni_range = 8.0
	_viewport.add_child(fill)
	var back := OmniLight3D.new()
	back.position = Vector3(1.8, 1.6, -1.4)
	back.light_color = Color("#c36bff")
	back.light_energy = 2.2
	back.omni_range = 7.0
	_viewport.add_child(back)

	# glowing rune disc she stands on
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = 0.62
	disc_mesh.bottom_radius = 0.62
	disc_mesh.height = 0.02
	disc_mesh.radial_segments = 28
	var disc_mat := StandardMaterial3D.new()
	disc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc_mat.albedo_color = Color(0.45, 0.9, 1.0, 0.35)
	disc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var disc := MeshInstance3D.new()
	disc.mesh = disc_mesh
	disc.material_override = disc_mat
	disc.position = Vector3(0, -0.02, 0)
	_viewport.add_child(disc)

	guardian = Guardian3D.new()
	_viewport.add_child(guardian)

	var cam := Camera3D.new()
	cam.fov = 28.0
	cam.position = Vector3(0, 1.17, 5.35)
	_viewport.add_child(cam)
	cam.look_at(Vector3(0, 1.17, 0), Vector3.UP)
	cam.make_current()

	var view := TextureRect.new()
	Ui.full_rect(view)
	view.texture = _viewport.get_texture()
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_SCALE
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)

	# tap zone over her head and torso only
	var zone := Button.new()
	zone.set_anchors_preset(Control.PRESET_FULL_RECT)
	zone.anchor_bottom = 0.55
	zone.offset_left = 0
	zone.offset_right = 0
	zone.offset_top = 0
	zone.offset_bottom = 0
	zone.flat = true
	zone.focus_mode = Control.FOCUS_NONE
	zone.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	zone.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	zone.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	zone.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	zone.pressed.connect(_on_poked)
	add_child(zone)

func _on_poked() -> void:
	poked.emit()

func react(mood: String) -> void:
	if guardian != null:
		guardian.react(mood)

func speak(seconds: float) -> void:
	if guardian != null:
		guardian.speak(seconds)

func set_glow(color: Color) -> void:
	if guardian != null:
		guardian.set_glow(color)

# Makes the character glance toward a point on screen (viewport coordinates).
func look_at_screen(screen_pos: Vector2) -> void:
	if guardian == null:
		return
	var vs := get_viewport_rect().size
	var centre := global_position + Vector2(size.x * 0.5, size.y * 0.22)
	var d := (screen_pos - centre) / maxf(1.0, vs.x)
	guardian.look_target = Vector2(clampf(d.x * 1.4, -0.6, 0.6), clampf(d.y * 0.9, -0.4, 0.4))
