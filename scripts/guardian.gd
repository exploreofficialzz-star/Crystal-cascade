class_name Guardian3D
extends Node3D

# A reaction plays for this long, then the Guardian goes back to idle. Before,
# "happy" (bouncing) or "angry" (shaking) simply never stopped.
const MOOD_SECONDS := 1.4

var mood := "idle"
var body: MeshInstance3D
var head: MeshInstance3D
var eye_l: MeshInstance3D
var eye_r: MeshInstance3D
var mouth: MeshInstance3D
var arm_l: MeshInstance3D
var arm_r: MeshInstance3D
var timer := 0.0
var base_position := Vector3.ZERO

# Geometry is now explicit (no node-scale tricks) so the eyes and mouth sit ON
# the head. Previously they floated ~0.3 units in front of it.
func _ready() -> void:
    base_position = position
    body = _mesh(_capsule(0.42, 1.9), Vector3(0, 1.2, 0), Color("#6954d9"))
    head = _mesh(_sphere(0.55), Vector3(0, 2.65, 0), Color("#ffd0ac"))
    eye_l = _mesh(_sphere(0.09), Vector3(-0.2, 2.75, 0.47), Color("#17111e"))
    eye_r = _mesh(_sphere(0.09), Vector3(0.2, 2.75, 0.47), Color("#17111e"))
    var ring := TorusMesh.new()
    ring.inner_radius = 0.05
    ring.outer_radius = 0.13
    ring.rings = 16
    ring.ring_segments = 8
    mouth = _mesh(ring, Vector3(0, 2.47, 0.5), Color("#301b3d"))
    mouth.rotation.x = PI / 2.0
    arm_l = _mesh(_capsule(0.11, 0.9), Vector3(-0.62, 1.45, 0), Color("#6954d9"))
    arm_r = _mesh(_capsule(0.11, 0.9), Vector3(0.62, 1.45, 0), Color("#6954d9"))

func _capsule(radius: float, height: float) -> CapsuleMesh:
    var m := CapsuleMesh.new()
    m.radius = radius
    m.height = height
    m.radial_segments = 20
    m.rings = 6
    return m

func _sphere(radius: float) -> SphereMesh:
    var m := SphereMesh.new()
    m.radius = radius
    m.height = radius * 2.0
    m.radial_segments = 24
    m.rings = 12
    return m

func _mesh(shape: Mesh, pos: Vector3, color: Color) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.mesh = shape
    node.position = pos
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.42
    node.material_override = mat
    add_child(node)
    return node

func react(new_mood: String) -> void:
    mood = new_mood
    timer = 0.0

func _process(delta: float) -> void:
    if body == null:
        return
    timer += delta
    if mood != "idle" and timer > MOOD_SECONDS:
        mood = "idle"
        timer = 0.0
    var bounce := 0.0
    var lean := 0.0
    var mouth_scale := 1.0
    var arm_l_rot := 0.0
    var arm_r_rot := 0.0
    match mood:
        "happy":
            bounce = absf(sin(timer * 7.0)) * 0.30
            mouth_scale = 1.25
            arm_l_rot = sin(timer * 8.0) * 0.45
            arm_r_rot = -sin(timer * 8.0) * 0.45
        "angry":
            lean = sin(timer * 15.0) * 0.10
            mouth_scale = 0.75
            arm_l_rot = -0.25
            arm_r_rot = 0.25
        "surprised":
            bounce = absf(sin(timer * 6.0)) * 0.16
            mouth_scale = 1.35
            arm_l_rot = 0.6
            arm_r_rot = -0.6
        "sad":
            bounce = -0.08
            lean = -0.12
            mouth_scale = 0.7
            arm_l_rot = -0.35
            arm_r_rot = 0.35
        _:
            pass
    position = base_position + Vector3(0, bounce, 0)
    rotation.z = lerpf(rotation.z, lean, clampf(delta * 6.0, 0.0, 1.0))
    mouth.scale = Vector3(mouth_scale, mouth_scale, mouth_scale)
    arm_l.rotation.z = arm_l_rot
    arm_r.rotation.z = arm_r_rot
