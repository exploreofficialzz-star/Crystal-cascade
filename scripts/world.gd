class_name GameWorld
extends Node3D

var camera_rig: Node3D
var camera: Camera3D
var board: Node3D
var tubes_root: Node3D
var guardian: Guardian3D
var focus := Vector3.ZERO
var camera_mode := 0
var ambient_time := 0.0
var environment: WorldEnvironment
var star_particles: GPUParticles3D

func build() -> void:
    _build_environment()
    _build_lights()
    board = Node3D.new()
    board.name = "Board"
    add_child(board)
    tubes_root = Node3D.new()
    tubes_root.name = "Tubes"
    board.add_child(tubes_root)
    camera_rig = Node3D.new()
    camera_rig.name = "CameraRig"
    add_child(camera_rig)
    camera = Camera3D.new()
    camera.fov = 52.0
    camera.current = true
    camera_rig.add_child(camera)
    guardian = Guardian3D.new()
    guardian.position = Vector3(0, 0.2, -4.0)
    add_child(guardian)
    _build_floor()
    _build_particles()

func _build_environment() -> void:
    environment = WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("#060a20")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("#5265b0")
    env.ambient_light_energy = 0.72
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.glow_enabled = true
    env.glow_intensity = 1.15
    env.fog_enabled = true
    env.fog_light_color = Color("#172354")
    env.fog_density = 0.010
    environment.environment = env
    add_child(environment)

func _build_lights() -> void:
    var key := DirectionalLight3D.new()
    key.rotation_degrees = Vector3(-55, -25, 0)
    key.light_energy = 1.35
    key.shadow_enabled = true
    add_child(key)
    var fill := OmniLight3D.new()
    fill.position = Vector3(0, 6, 5)
    fill.light_color = Color("#4d78ff")
    fill.light_energy = 5.5
    fill.omni_range = 18.0
    add_child(fill)
    var rim := OmniLight3D.new()
    rim.position = Vector3(-8, 3, -4)
    rim.light_color = Color("#a44dff")
    rim.light_energy = 4.0
    rim.omni_range = 14.0
    add_child(rim)

func _build_floor() -> void:
    var floor := MeshInstance3D.new()
    var mesh := PlaneMesh.new()
    mesh.size = Vector2(34, 34)
    floor.mesh = mesh
    floor.position.y = -0.58
    var material := StandardMaterial3D.new()
    material.albedo_color = Color("#0d1430")
    material.metallic = 0.55
    material.roughness = 0.25
    floor.material_override = material
    add_child(floor)

func _build_particles() -> void:
    star_particles = GPUParticles3D.new()
    star_particles.amount = 120
    star_particles.lifetime = 8.0
    star_particles.position = Vector3(0, 4, 1)
    var process_material := ParticleProcessMaterial.new()
    process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    process_material.emission_box_extents = Vector3(11, 5, 7)
    process_material.gravity = Vector3(0, -0.10, 0)
    process_material.initial_velocity_min = 0.08
    process_material.initial_velocity_max = 0.38
    star_particles.process_material = process_material
    var particle_mesh := SphereMesh.new()
    particle_mesh.radius = 0.035
    particle_mesh.height = 0.07
    var particle_material := StandardMaterial3D.new()
    particle_material.albedo_color = Color(0.65, 0.82, 1.0)
    particle_material.emission_enabled = true
    particle_material.emission = Color(0.35, 0.55, 1.0)
    particle_mesh.material = particle_material
    star_particles.draw_pass_1 = particle_mesh
    add_child(star_particles)
    star_particles.emitting = true

func arrange(tube_count: int, capacity: int) -> void:
    for child in tubes_root.get_children():
        child.queue_free()
    var cols := min(4, tube_count)
    var rows := int(ceil(float(tube_count) / float(cols)))
    var spacing_x := 2.15
    var spacing_z := 2.05
    for i in range(tube_count):
        var row := int(i / cols)
        var col := i % cols
        var x := (col - (cols - 1) / 2.0) * spacing_x
        var z := (row - (rows - 1) / 2.0) * spacing_z
        var tube := Tube3D.new()
        tube.setup(i, capacity)
        tube.position = Vector3(x, capacity * 0.45 - 0.1, z)
        tubes_root.add_child(tube)
    focus = Vector3(0, capacity * 0.42, 0)
    camera_mode = 0
    _snap_camera()

func get_tube(index: int) -> Tube3D:
    if index >= 0 and index < tubes_root.get_child_count():
        return tubes_root.get_child(index) as Tube3D
    return null

func focus_on_tube(index: int) -> void:
    var tube := get_tube(index)
    if tube:
        focus = tube.global_position + Vector3(0, 0.7, 0)
        _camera_move(true)

func set_camera_mode(mode: int) -> void:
    camera_mode = posmod(mode, 4)
    _camera_move(true)

func next_camera() -> void:
    set_camera_mode(camera_mode + 1)

func _camera_transform() -> Vector3:
    var offsets := [
        Vector3(0, 8.4, 15.5),
        Vector3(9.8, 7.0, 10.5),
        Vector3(-10.0, 5.5, 10.5),
        Vector3(0, 13.5, 8.5)
    ]
    return focus + offsets[camera_mode]

func _camera_move(animated: bool) -> void:
    if not camera:
        return
    var destination := _camera_transform()
    if not animated:
        camera.global_position = destination
        camera.look_at(focus, Vector3.UP)
        return
    var tween := create_tween().set_parallel(true)
    tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(camera, "global_position", destination, 0.65)
    tween.tween_method(_look_camera, 0.0, 1.0, 0.65)

func _look_camera(_value: float) -> void:
    if camera:
        camera.look_at(focus, Vector3.UP)

func _snap_camera() -> void:
    _camera_move(false)

func pulse_camera(intensity: float = 0.18) -> void:
    if not camera:
        return
    var original := camera.position
    var offset := Vector3(randf_range(-intensity, intensity), randf_range(-intensity, intensity), 0)
    var tween := create_tween()
    tween.tween_property(camera, "position", original + offset, 0.06)
    tween.tween_property(camera, "position", original, 0.18)

func _process(delta: float) -> void:
    ambient_time += delta
    if not camera:
        return
    camera.look_at(focus, Vector3.UP)
    if star_particles:
        star_particles.rotation.y += delta * 0.01
