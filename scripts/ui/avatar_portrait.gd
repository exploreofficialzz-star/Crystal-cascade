class_name AvatarPortrait
extends Control

# Circular HUD portrait of the 3D Guardian. It renders the character in its own
# small SubViewport (own World3D, transparent background) so camera movement in
# the main scene never affects it, and it stays crisp in the top-right corner.

const VIEW_SIZE := 320
const MASK_SHADER := "shader_type canvas_item;\nvoid fragment() {\n\tvec4 c = texture(TEXTURE, UV);\n\tfloat d = distance(UV, vec2(0.5));\n\tfloat a = 1.0 - smoothstep(0.485, 0.5, d);\n\tCOLOR = vec4(c.rgb, c.a * a);\n}\n"

var guardian: Guardian3D
var _viewport: SubViewport
var _ring_style: StyleBoxFlat
var _ring: Panel

func _init() -> void:
	custom_minimum_size = Vector2(270, 270)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	var disc := Panel.new()
	Ui.full_rect(disc)
	disc.add_theme_stylebox_override("panel", Ui.flat(Color("#241b63"), 512, Color(0, 0, 0, 0), 0, 0, 0))
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(disc)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(VIEW_SIZE, VIEW_SIZE)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.gui_disable_input = true
	add_child(_viewport)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#9aa0ff")
	env.ambient_light_energy = 0.85
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_viewport.add_child(world_env)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, 25, 0)
	key.light_energy = 1.25
	_viewport.add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-1.4, 0.8, 2.0)
	fill.light_color = Color("#6f9bff")
	fill.light_energy = 2.2
	fill.omni_range = 7.0
	_viewport.add_child(fill)
	var back := OmniLight3D.new()
	back.position = Vector3(1.6, 1.0, -1.2)
	back.light_color = Color("#c36bff")
	back.light_energy = 2.0
	back.omni_range = 6.0
	_viewport.add_child(back)

	guardian = Guardian3D.new()
	_viewport.add_child(guardian)

	var cam := Camera3D.new()
	cam.fov = 36.0
	cam.position = Vector3(0, 0.44, 2.4)
	_viewport.add_child(cam)
	cam.look_at(Vector3(0, 0.36, 0), Vector3.UP)
	cam.make_current()

	var view := TextureRect.new()
	Ui.full_rect(view)
	view.texture = _viewport.get_texture()
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_SCALE
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = MASK_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	view.material = mat
	add_child(view)

	_ring_style = Ui.flat(Color(0, 0, 0, 0), 512, Color("#7ef0ff"), 7, 0, 0)
	_ring_style.draw_center = false
	_ring_style.shadow_color = Color(0.49, 0.94, 1.0, 0.45)
	_ring_style.shadow_size = 14
	_ring = Panel.new()
	Ui.full_rect(_ring)
	_ring.add_theme_stylebox_override("panel", _ring_style)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ring)

func react(mood: String) -> void:
	if guardian != null:
		guardian.react(mood)

func set_glow(color: Color) -> void:
	if guardian != null:
		guardian.set_glow(color)
	if _ring_style != null:
		_ring_style.border_color = color
		_ring_style.shadow_color = Color(color, 0.45)
		_ring.queue_redraw()

# Makes the character glance toward a point on screen (viewport coordinates).
func look_at_screen(screen_pos: Vector2) -> void:
	if guardian == null:
		return
	var vs := get_viewport_rect().size
	var centre := global_position + size * 0.5
	var d := (screen_pos - centre) / maxf(1.0, vs.x)
	guardian.look_target = Vector2(clampf(d.x * 1.4, -0.6, 0.6), clampf(d.y * 0.9, -0.4, 0.4))
