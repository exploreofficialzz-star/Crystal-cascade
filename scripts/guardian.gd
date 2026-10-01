class_name Guardian3D
extends Node3D

# A stylised human character ("Cass, the Crystal Keeper") built from primitives:
# hair, forehead crystal, expressive eyes with pupils and highlights, eyebrows,
# blush, nose, a mouth that changes shape, neck, cloak, scarf, arms and hands.
# It lives in the HUD portrait viewport (see AvatarPortrait) and reacts to the
# game through react().

const MOOD_SECONDS := 1.6
const SMILE_LEVELS := 9
const BROW_Y := 0.125

const MOODS := {
	"idle":      {"brow": 0.0,   "brow_up": 0.0,  "eye": 1.0,  "smile": 0.35, "open": 0.0, "tilt": 0.0,   "arm_r": 0.12, "bounce": 0.0},
	"happy":     {"brow": -0.12, "brow_up": 0.03, "eye": 0.82, "smile": 1.0,  "open": 0.7, "tilt": 0.10,  "arm_r": 2.55, "bounce": 0.05},
	"surprised": {"brow": -0.10, "brow_up": 0.07, "eye": 1.30, "smile": 0.0,  "open": 1.0, "tilt": 0.0,   "arm_r": 0.35, "bounce": 0.02},
	"sad":       {"brow": -0.50, "brow_up": 0.0,  "eye": 0.85, "smile": -0.9, "open": 0.0, "tilt": -0.10, "arm_r": 0.05, "bounce": -0.03},
	"angry":     {"brow": 0.60,  "brow_up": -0.02, "eye": 0.78, "smile": -0.4, "open": 0.0, "tilt": 0.0,  "arm_r": 0.20, "bounce": 0.0},
	"think":     {"brow": -0.25, "brow_up": 0.05, "eye": 0.95, "smile": 0.05, "open": 0.0, "tilt": 0.16,  "arm_r": 0.12, "bounce": 0.0},
}

var mood := "idle"
var look_target := Vector2.ZERO          # yaw, pitch in radians
var _mood_time := 0.0
var _time := 0.0
var _blink_in := 2.5
var _blink_t := -1.0
var _cur: Dictionary = {}

var _root: Node3D
var _head: Node3D
var _eye_l: Node3D
var _eye_r: Node3D
var _iris_l: Node3D
var _iris_r: Node3D
var _brow_l: Node3D
var _brow_r: Node3D
var _mouth_line: MeshInstance3D
var _mouth_open: MeshInstance3D
var _arm_r: Node3D
var _orb: MeshInstance3D
var _orb_mat: StandardMaterial3D
var _gem_mat: StandardMaterial3D
var _smile_meshes: Array = []

func _ready() -> void:
	for key in MOODS["idle"].keys():
		_cur[key] = float(MOODS["idle"][key])
	_build()

# ── construction ──────────────────────────────────────────────────────────────

func _mat(color: Color, rough: float = 0.6, metal: float = 0.0, emit: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emit
	return m

func _sph(r: float, segs: int = 24) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = segs
	s.rings = maxi(6, int(segs / 2))
	return s

func _cap(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.0 + 0.01)
	c.radial_segments = 16
	c.rings = 4
	return c

func _part(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.scale = scl
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func _node(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n

func _arc_mesh(curve: float, width: float, thick: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 12
	for i in range(seg):
		var t0 := float(i) / float(seg)
		var t1 := float(i + 1) / float(seg)
		var x0 := lerpf(-width * 0.5, width * 0.5, t0)
		var x1 := lerpf(-width * 0.5, width * 0.5, t1)
		var y0 := curve * pow(2.0 * t0 - 1.0, 2.0) * 0.5
		var y1 := curve * pow(2.0 * t1 - 1.0, 2.0) * 0.5
		var h := thick * 0.5
		var a := Vector3(x0, y0 - h, 0.0)
		var b := Vector3(x1, y1 - h, 0.0)
		var c := Vector3(x1, y1 + h, 0.0)
		var d := Vector3(x0, y0 + h, 0.0)
		for v in [a, b, c, a, c, d]:
			st.set_normal(Vector3(0, 0, 1))
			st.add_vertex(v)
	return st.commit()

func _build() -> void:
	var skin := _mat(Color("#f4c9a6"), 0.55)
	var skin_dark := _mat(Color("#e5aa86"), 0.6)
	var hair := _mat(Color("#4b2fc4"), 0.45)
	var hair_hi := _mat(Color("#8a6bff"), 0.4)
	var cloak := _mat(Color("#2b2f92"), 0.7)
	var cloak_dark := _mat(Color("#1c1f66"), 0.8)
	var gold := _mat(Color("#e8c243"), 0.3, 0.7)
	var scarf := _mat(Color("#e0509a"), 0.6)
	var white := _mat(Color("#ffffff"), 0.2)
	var iris := _mat(Color("#3aa0ff"), 0.25, 0.0, 0.25)
	var pupil := _mat(Color("#0b0b1a"), 0.3)
	var lip := _mat(Color("#c8506a"), 0.5)
	lip.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mouth_in := _mat(Color("#3a1226"), 0.6)
	var blush := _mat(Color(1.0, 0.55, 0.65, 0.45), 0.9)
	blush.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	_root = _node(self, Vector3.ZERO)

	# torso, cloak, collar, scarf
	_part(_root, _cap(0.31, 1.0), Vector3(0, -0.36, 0), cloak, Vector3(1.0, 1.0, 0.72))
	var back := CylinderMesh.new()
	back.top_radius = 0.30
	back.bottom_radius = 0.52
	back.height = 1.15
	back.radial_segments = 24
	_part(_root, back, Vector3(0, -0.34, -0.10), cloak_dark)
	var collar := CylinderMesh.new()
	collar.top_radius = 0.21
	collar.bottom_radius = 0.36
	collar.height = 0.20
	collar.radial_segments = 24
	_part(_root, collar, Vector3(0, 0.10, 0), cloak)
	var trim := TorusMesh.new()
	trim.inner_radius = 0.195
	trim.outer_radius = 0.225
	trim.rings = 24
	trim.ring_segments = 8
	_part(_root, trim, Vector3(0, 0.20, 0), gold)
	var neck := CylinderMesh.new()
	neck.top_radius = 0.075
	neck.bottom_radius = 0.085
	neck.height = 0.18
	_part(_root, neck, Vector3(0, 0.24, 0), skin_dark)
	var scarf_ring := TorusMesh.new()
	scarf_ring.inner_radius = 0.11
	scarf_ring.outer_radius = 0.19
	scarf_ring.rings = 20
	scarf_ring.ring_segments = 10
	_part(_root, scarf_ring, Vector3(0, 0.14, 0.02), scarf)
	_part(_root, _cap(0.055, 0.34), Vector3(0.10, -0.04, 0.17), scarf, Vector3(1, 1, 0.6))

	# shoulders and left arm holding a glowing crystal orb
	_part(_root, _sph(0.16), Vector3(-0.33, -0.03, 0), cloak)
	_part(_root, _sph(0.16), Vector3(0.33, -0.03, 0), cloak)
	var from := Vector3(-0.34, -0.06, 0.02)
	var to := Vector3(-0.30, -0.36, 0.30)
	var limb := _cap(0.07, from.distance_to(to))
	var lmi := _part(_root, limb, (from + to) * 0.5, cloak)
	lmi.basis = Basis(Quaternion(Vector3.UP, (to - from).normalized()))
	_part(_root, _sph(0.075), to, skin)
	_orb_mat = _mat(Color("#7ef0ff"), 0.15, 0.0, 1.6)
	_orb = _part(_root, _sph(0.115, 20), to + Vector3(0.02, 0.16, 0.05), _orb_mat)

	# right arm (waves on happy)
	_arm_r = _node(_root, Vector3(0.36, -0.03, 0))
	_part(_arm_r, _cap(0.07, 0.46), Vector3(0, -0.22, 0), cloak)
	_part(_arm_r, _sph(0.075), Vector3(0, -0.47, 0), skin)

	# head group (everything on the head rotates together)
	_head = _node(_root, Vector3(0, 0.55, 0))
	_part(_head, _sph(0.29, 32), Vector3.ZERO, skin, Vector3(0.94, 1.02, 0.97))
	_part(_head, _sph(0.055), Vector3(-0.28, -0.03, 0), skin)
	_part(_head, _sph(0.055), Vector3(0.28, -0.03, 0), skin)
	_part(_head, _sph(0.036, 16), Vector3(0, -0.06, 0.285), skin_dark, Vector3(1, 1, 1.15))
	_part(_head, _sph(0.055, 16), Vector3(-0.17, -0.12, 0.195), blush, Vector3(1, 0.7, 0.35))
	_part(_head, _sph(0.055, 16), Vector3(0.17, -0.12, 0.195), blush, Vector3(1, 0.7, 0.35))

	# hair: a big sphere pushed back/up so the face pokes through, plus fringe and locks
	_part(_head, _sph(0.34, 32), Vector3(0, 0.07, -0.09), hair)
	for fx in [-0.13, 0.0, 0.13]:
		_part(_head, _sph(0.10, 16), Vector3(fx, 0.215, 0.17), hair, Vector3(1.05, 0.6, 0.85))
	_part(_head, _sph(0.045, 12), Vector3(0.06, 0.225, 0.25), hair_hi, Vector3(1.6, 0.5, 0.6))
	_part(_head, _cap(0.075, 0.42), Vector3(-0.29, -0.14, 0.02), hair, Vector3(1, 1, 0.9))
	_part(_head, _cap(0.075, 0.42), Vector3(0.29, -0.14, 0.02), hair, Vector3(1, 1, 0.9))
	_part(_head, _sph(0.06, 12), Vector3(0.30, -0.36, 0.02), hair_hi)

	# forehead crystal
	_gem_mat = _mat(Color("#7ef0ff"), 0.1, 0.0, 1.8)
	var gem := PrismMesh.new()
	gem.size = Vector3(0.09, 0.12, 0.05)
	_part(_head, gem, Vector3(0, 0.20, 0.275), _gem_mat)
	_part(_head, _sph(0.045, 12), Vector3(0, 0.20, 0.262), gold, Vector3(1.2, 1.2, 0.5))

	# eyes
	for side in [-1, 1]:
		var eye := _node(_head, Vector3(side * 0.115, 0.03, 0.245))
		_part(eye, _sph(0.062, 20), Vector3.ZERO, white, Vector3(1.0, 1.15, 0.55))
		var ir := _node(eye, Vector3(0, 0, 0.02))
		_part(ir, _sph(0.040, 16), Vector3.ZERO, iris, Vector3(1, 1, 0.5))
		_part(ir, _sph(0.021, 12), Vector3(0, 0, 0.012), pupil, Vector3(1, 1, 0.5))
		_part(ir, _sph(0.011, 8), Vector3(0.014, 0.016, 0.022), white)
		if side < 0:
			_eye_l = eye
			_iris_l = ir
		else:
			_eye_r = eye
			_iris_r = ir
		var brow := _node(_head, Vector3(side * 0.115, BROW_Y, 0.272))
		var bar := _part(brow, _cap(0.013, 0.13), Vector3.ZERO, hair)
		bar.rotation.z = PI / 2.0
		if side < 0:
			_brow_l = brow
		else:
			_brow_r = brow

	# mouth: a lip ribbon (mesh swapped by smile amount) + dark opening
	for i in range(SMILE_LEVELS):
		var s := lerpf(-1.0, 1.0, float(i) / float(SMILE_LEVELS - 1))
		_smile_meshes.append(_arc_mesh(0.085 * s, 0.13, 0.016))
	_mouth_line = _part(_head, _smile_meshes[SMILE_LEVELS - 1], Vector3(0, -0.155, 0.248), lip)
	_mouth_open = _part(_head, _sph(0.05, 16), Vector3(0, -0.165, 0.243), mouth_in, Vector3(1.0, 0.1, 0.3))

# ── behaviour ─────────────────────────────────────────────────────────────────

func react(new_mood: String) -> void:
	if not MOODS.has(new_mood):
		new_mood = "idle"
	mood = new_mood
	_mood_time = 0.0

# Tint the orb and forehead gem (e.g. with the colour of the selected crystal).
func set_glow(color: Color) -> void:
	if _orb_mat:
		_orb_mat.albedo_color = color
		_orb_mat.emission = color
	if _gem_mat:
		_gem_mat.albedo_color = color
		_gem_mat.emission = color

func _process(delta: float) -> void:
	if _root == null:
		return
	_time += delta
	_mood_time += delta
	var hold := 2.6 if mood == "think" else MOOD_SECONDS
	if mood != "idle" and _mood_time > hold:
		mood = "idle"
		_mood_time = 0.0

	var target: Dictionary = MOODS[mood]
	var k := clampf(1.0 - exp(-delta * 9.0), 0.0, 1.0)
	for key in target.keys():
		_cur[key] = lerpf(float(_cur[key]), float(target[key]), k)

	# blinking
	_blink_in -= delta
	if _blink_in <= 0.0 and _blink_t < 0.0:
		_blink_t = 0.0
		_blink_in = randf_range(2.2, 5.0)
	var blink := 1.0
	if _blink_t >= 0.0:
		_blink_t += delta
		blink = clampf(absf(_blink_t - 0.07) / 0.07, 0.08, 1.0)
		if _blink_t > 0.14:
			_blink_t = -1.0
	var eye_open := float(_cur["eye"]) * blink
	_eye_l.scale = Vector3(1, eye_open, 1)
	_eye_r.scale = Vector3(1, eye_open, 1)

	# eyebrows
	var bu := float(_cur["brow_up"])
	var ba := float(_cur["brow"])
	_brow_l.rotation.z = -ba
	_brow_r.rotation.z = ba
	_brow_l.position.y = BROW_Y + bu
	_brow_r.position.y = BROW_Y + bu

	# mouth
	var smile := clampf(float(_cur["smile"]), -1.0, 1.0)
	var idx := clampi(int(round((smile + 1.0) * 0.5 * float(SMILE_LEVELS - 1))), 0, SMILE_LEVELS - 1)
	_mouth_line.mesh = _smile_meshes[idx]
	var open := float(_cur["open"])
	_mouth_open.scale = Vector3(1.0 + open * 0.15, 0.1 + open * 1.1, 0.3)
	_mouth_open.position.y = -0.165 - open * 0.012

	# head: look-at + mood tilt + idle sway
	var yaw := clampf(look_target.x, -0.6, 0.6)
	var pitch := clampf(look_target.y, -0.4, 0.4)
	_head.rotation.y = lerpf(_head.rotation.y, yaw, k)
	_head.rotation.x = lerpf(_head.rotation.x, pitch, k)
	_head.rotation.z = float(_cur["tilt"]) + sin(_time * 0.9) * 0.025
	var look_shift := Vector3(yaw * 0.03, -pitch * 0.03, 0)
	_iris_l.position = Vector3(look_shift.x, look_shift.y, 0.02)
	_iris_r.position = Vector3(look_shift.x, look_shift.y, 0.02)

	# body: breathing, bounce, wave
	var breathe := sin(_time * 1.8) * 0.012
	_root.position.y = float(_cur["bounce"]) * absf(sin(_time * 8.0)) + breathe
	_root.rotation.z = sin(_time * 0.7) * 0.02
	var arm := float(_cur["arm_r"])
	if arm > 1.5:
		arm += sin(_time * 10.0) * 0.28
	_arm_r.rotation.z = arm

	# glowing orb pulse
	if _orb_mat:
		_orb_mat.emission_energy_multiplier = 1.4 + sin(_time * 3.0) * 0.4
		_orb.position.y = -0.20 + sin(_time * 2.0) * 0.012
