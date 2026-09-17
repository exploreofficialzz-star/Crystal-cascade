class_name Guardian3D
extends Node3D

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

func _ready() -> void:
    base_position = position
    body = _mesh(CapsuleMesh.new(), Vector3(0, 1.25, 0), Vector3(0.78, 1.15, 0.78), Color("#6954d9"))
    head = _mesh(SphereMesh.new(), Vector3(0, 2.7, 0), Vector3(0.78, 0.78, 0.78), Color("#ffd0ac"))
    eye_l = _eye(-0.25)
    eye_r = _eye(0.25)
    mouth = _mesh(TorusMesh.new(), Vector3(0, 2.47, 0.70), Vector3(1, 0.72, 1), Color("#301b3d"))
    mouth.rotation.x = PI / 2.0
    arm_l = _mesh(CapsuleMesh.new(), Vector3(-0.92, 1.35, 0), Vector3(0.22, 0.55, 0.22), Color("#6954d9"))
    arm_r = _mesh(CapsuleMesh.new(), Vector3(0.92, 1.35, 0), Vector3(0.22, 0.55, 0.22), Color("#6954d9"))

func _mesh(shape: Mesh, pos: Vector3, scale_value: Vector3, color: Color) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.mesh = shape
    node.position = pos
    node.scale = scale_value
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.42
    node.material_override = mat
    add_child(node)
    return node

func _eye(x: float) -> MeshInstance3D:
    var eye := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.13
    sphere.height = 0.26
    eye.mesh = sphere
    eye.position = Vector3(x, 2.8, 0.69)
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color("#17111e")
    eye.material_override = mat
    add_child(eye)
    return eye

func react(new_mood: String) -> void:
    mood = new_mood
    timer = 0.0

func _process(delta: float) -> void:
    timer += delta
    var bounce := 0.0
    var lean := 0.0
    if mood == "happy":
        bounce = abs(sin(timer * 7.0)) * 0.30
    elif mood == "angry":
        lean = sin(timer * 15.0) * 0.10
    elif mood == "surprised":
        bounce = abs(sin(timer * 6.0)) * 0.16
    elif mood == "sad":
        bounce = -0.08
        lean = -0.12
    position = base_position + Vector3(0, bounce, 0)
    rotation.z = lerp(rotation.z, lean, delta * 6.0)
    if mood == "happy":
        mouth.scale = Vector3(1.25, 1.25, 1.25)
        arm_l.rotation.z = sin(timer * 8.0) * 0.45
        arm_r.rotation.z = -sin(timer * 8.0) * 0.45
    elif mood == "angry":
        mouth.scale = Vector3(0.75, 0.75, 0.75)
        arm_l.rotation.z = -0.25
        arm_r.rotation.z = 0.25
    elif mood == "surprised":
        mouth.scale = Vector3(1.35, 1.35, 1.35)
    elif mood == "sad":
        mouth.scale = Vector3(0.7, 0.7, 0.7)
    else:
        mouth.scale = Vector3.ONE
        arm_l.rotation.z = 0.0
        arm_r.rotation.z = 0.0
