class_name Guardian3D
extends Node3D

# "Cass, the Crystal Keeper": a full-body stylised human built from primitives.
# Skeleton: hips > torso > head, shoulders > elbows, hips > knees. Every mood is
# a procedural pose (dance, cheer, clap, wave, point, think, sad, angry, ...)
# blended smoothly, plus facial expressions, blinking, look-at and lip-flap while
# she speaks. Poses are described from the VIEWER's side: "l" = screen left.

const SMILE_LEVELS := 9
const BROW_Y := 0.125
const HOLD := {
	"happy": 1.6, "cheer": 2.4, "dance": 3.4, "surprised": 1.4, "sad": 2.4,
	"angry": 1.6, "think": 2.8, "wave": 2.4, "point": 2.6, "clap": 2.6,
}
# eye open, brow tilt, brow raise, smile (-1..1), mouth open (0..1), head tilt
const FACES := {
	"idle": {"eye": 1.0, "brow": 0.0, "bup": 0.0, "smile": 0.35, "open": 0.0, "tilt": 0.0},
	"happy": {"eye": 0.82, "brow": -0.12, "bup": 0.03, "smile": 1.0, "open": 0.7, "tilt": 0.10},
	"cheer": {"eye": 0.78, "brow": -0.14, "bup": 0.04, "smile": 1.0, "open": 1.0, "tilt": 0.08},
	"dance": {"eye": 0.80, "brow": -0.12, "bup": 0.03, "smile": 1.0, "open": 0.8, "tilt": 0.12},
	"clap": {"eye": 0.82, "brow": -0.10, "bup": 0.03, "smile": 1.0, "open": 0.6, "tilt": 0.06},
	"wave": {"eye": 0.9, "brow": -0.08, "bup": 0.02, "smile": 0.9, "open": 0.4, "tilt": 0.06},
	"surprised": {"eye": 1.30, "brow": -0.10, "bup": 0.07, "smile": 0.0, "open": 1.0, "tilt": 0.0},
	"sad": {"eye": 0.85, "brow": -0.50, "bup": 0.0, "smile": -0.9, "open": 0.0, "tilt": -0.10},
	"angry": {"eye": 0.78, "brow": 0.60, "bup": -0.02, "smile": -0.4, "open": 0.0, "tilt": 0.0},
	"think": {"eye": 0.95, "brow": -0.25, "bup": 0.05, "smile": 0.05, "open": 0.0, "tilt": 0.16},
	"point": {"eye": 1.0, "brow": -0.05, "bup": 0.02, "smile": 0.5, "open": 0.0, "tilt": 0.05},
}

var mood := "idle"
var look_target := Vector2.ZERO          # yaw, pitch in radians
var talk := 0.0                          # seconds of lip movement left
var _mood_time := 0.0
var _time := 0.0
var _blink_in := 2.5
var _blink_t := -1.0
var _jv: Dictionary = {}
var _fv: Dictionary = {}

var _root: Node3D
var _hips: Node3D
var _torso: Node3D
var _head: Node3D
var _eye_l: Node3D
var _eye_r: Node3D
var _iris_l: Node3D
var _iris_r: Node3D
var _brow_l: Node3D
var _brow_r: Node3D
var _mouth_line: MeshInstance3D
var _mouth_open: MeshInstance3D
var _sh_l: Node3D
var _sh_r: Node3D
var _el_l: Node3D
var _el_r: Node3D
var _hip_l: Node3D
var _hip_r: Node3D
var _kn_l: Node3D
var _kn_r: Node3D
var _orb: MeshInstance3D
var _orb_mat: StandardMaterial3D
var _gem_mat: StandardMaterial3D
var _smile_meshes: Array = []

func _ready() -> void:
	_jv = _pose("idle", 0.0, 0.0)
	for key in FACES["idle"].keys():
		_fv[key] = float(FACES["idle"][key])
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

func _sph(r: float, segs: int = 20) -> SphereMesh:
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
	c.radial_segments = 14
	c.rings = 4
	return c

func _cyl(top_r: float, bottom_r: float, h: float, segs: int = 20) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top_r
	c.bottom_radius = bottom_r
	c.height = h
	c.radial_segments = segs
	c.rings = 1
	return c

func _tor(inner: float, outer: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 20
	t.ring_segments = 8
	return t

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
	var tunic := _mat(Color("#2b2f92"), 0.7)
	var tunic_dark := _mat(Color("#1c1f66"), 0.8)
	var pants := _mat(Color("#232557"), 0.75)
	var boots := _mat(Color("#5a3522"), 0.6)
	var gold := _mat(Color("#e8c243"), 0.3, 0.7)
	var scarf := _mat(Color("#e0509a"), 0.6)
	_orb_mat = _mat(Color("#7ef0ff"), 0.15, 0.0, 1.6)
	_gem_mat = _mat(Color("#7ef0ff"), 0.1, 0.0, 1.8)

	_root = _node(self, Vector3.ZERO)
	_hips = _node(_root, Vector3(0, 0.78, 0))

	# pelvis, tunic skirt, belt
	_part(_hips, _sph(0.2), Vector3(0, 0.0, 0), pants, Vector3(1.15, 0.8, 0.9))
	_part(_hips, _cyl(0.25, 0.40, 0.34, 22), Vector3(0, -0.10, 0), tunic)
	_part(_hips, _tor(0.215, 0.265), Vector3(0, 0.05, 0), gold)
	_part(_hips, _sph(0.045, 10), Vector3(0, 0.05, 0.25), gold, Vector3(1.4, 1.1, 0.6))

	# torso, cape, collar, scarf
	_torso = _node(_hips, Vector3(0, 0.02, 0))
	_part(_torso, _cap(0.235, 0.66), Vector3(0, 0.31, 0), tunic, Vector3(1, 1, 0.78))
	_part(_torso, _cyl(0.27, 0.52, 1.15, 22), Vector3(0, -0.02, -0.17), tunic_dark, Vector3(1.0, 1.0, 0.32))
	var emblem := PrismMesh.new()
	emblem.size = Vector3(0.12, 0.17, 0.05)
	_part(_torso, emblem, Vector3(0, 0.38, 0.185), _gem_mat)
	_part(_torso, _tor(0.15, 0.23), Vector3(0, 0.60, 0.0), scarf)
	_part(_torso, _cap(0.05, 0.36), Vector3(0.11, 0.42, 0.17), scarf, Vector3(1, 1, 0.6))
	_part(_torso, _cyl(0.075, 0.085, 0.16), Vector3(0, 0.68, 0), skin_dark)

	# head
	_head = _node(_torso, Vector3(0, 0.94, 0))
	_build_head(_head, skin, skin_dark, gold)

	# arms: shoulder > upper arm > elbow > forearm + hand. Viewer-left holds the orb.
	for side in [-1, 1]:
		var sh := _node(_torso, Vector3(side * 0.30, 0.52, 0))
		_part(sh, _sph(0.095, 14), Vector3.ZERO, tunic)
		_part(sh, _cap(0.07, 0.36), Vector3(0, -0.15, 0), tunic)
		var el := _node(sh, Vector3(0, -0.30, 0))
		_part(el, _cap(0.062, 0.34), Vector3(0, -0.14, 0), tunic_dark)
		_part(el, _tor(0.045, 0.08), Vector3(0, -0.25, 0), gold)
		_part(el, _sph(0.07, 14), Vector3(0, -0.31, 0), skin)
		if side < 0:
			_sh_l = sh
			_el_l = el
			_orb = _part(el, _sph(0.11, 18), Vector3(0.02, -0.43, 0.10), _orb_mat)
		else:
			_sh_r = sh
			_el_r = el

	# legs: hip > thigh > knee > shin + boot
	for side in [-1, 1]:
		var hp := _node(_hips, Vector3(side * 0.12, -0.04, 0))
		_part(hp, _cap(0.095, 0.42), Vector3(0, -0.17, 0), pants)
		var kn := _node(hp, Vector3(0, -0.36, 0))
		_part(kn, _cap(0.08, 0.38), Vector3(0, -0.16, 0), pants)
		_part(kn, _tor(0.07, 0.11), Vector3(0, -0.25, 0), gold)
		_part(kn, _sph(0.11, 14), Vector3(0, -0.35, 0.04), boots, Vector3(0.9, 0.75, 1.5))
		if side < 0:
			_hip_l = hp
			_kn_l = kn
		else:
			_hip_r = hp
			_kn_r = kn

func _build_head(head: Node3D, skin: Material, skin_dark: Material, gold: Material) -> void:
	var hair := _mat(Color("#4b2fc4"), 0.45)
	var hair_hi := _mat(Color("#8a6bff"), 0.4)
	var white := _mat(Color("#ffffff"), 0.2)
	var iris := _mat(Color("#3aa0ff"), 0.25, 0.0, 0.25)
	var pupil := _mat(Color("#0b0b1a"), 0.3)
	var lip := _mat(Color("#c8506a"), 0.5)
	lip.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mouth_in := _mat(Color("#3a1226"), 0.6)
	var blush := _mat(Color(1.0, 0.55, 0.65, 0.45), 0.9)
	blush.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	_part(head, _sph(0.29, 32), Vector3.ZERO, skin, Vector3(0.94, 1.02, 0.97))
	_part(head, _sph(0.055, 12), Vector3(-0.28, -0.03, 0), skin)
	_part(head, _sph(0.055, 12), Vector3(0.28, -0.03, 0), skin)
	_part(head, _sph(0.036, 16), Vector3(0, -0.06, 0.285), skin_dark, Vector3(1, 1, 1.15))
	_part(head, _sph(0.055, 16), Vector3(-0.17, -0.12, 0.195), blush, Vector3(1, 0.7, 0.35))
	_part(head, _sph(0.055, 16), Vector3(0.17, -0.12, 0.195), blush, Vector3(1, 0.7, 0.35))

	# hair: big sphere pushed back/up so the face shows, fringe, side locks, hair tie
	_part(head, _sph(0.34, 32), Vector3(0, 0.07, -0.09), hair)
	for fx in [-0.13, 0.0, 0.13]:
		_part(head, _sph(0.10, 16), Vector3(fx, 0.215, 0.17), hair, Vector3(1.05, 0.6, 0.85))
	_part(head, _sph(0.045, 12), Vector3(0.06, 0.225, 0.25), hair_hi, Vector3(1.6, 0.5, 0.6))
	_part(head, _cap(0.075, 0.42), Vector3(-0.29, -0.14, 0.02), hair, Vector3(1, 1, 0.9))
	_part(head, _cap(0.075, 0.42), Vector3(0.29, -0.14, 0.02), hair, Vector3(1, 1, 0.9))
	_part(head, _sph(0.06, 12), Vector3(0.30, -0.36, 0.02), hair_hi)

	# forehead crystal
	var gem := PrismMesh.new()
	gem.size = Vector3(0.09, 0.12, 0.05)
	_part(head, gem, Vector3(0, 0.20, 0.275), _gem_mat)
	_part(head, _sph(0.045, 12), Vector3(0, 0.20, 0.262), gold, Vector3(1.2, 1.2, 0.5))

	# eyes and brows
	for side in [-1, 1]:
		var eye := _node(head, Vector3(side * 0.115, 0.03, 0.245))
		_part(eye, _sph(0.062, 20), Vector3.ZERO, white, Vector3(1.0, 1.15, 0.55))
		var ir := _node(eye, Vector3(0, 0, 0.02))
		_part(ir, _sph(0.040, 16), Vector3.ZERO, iris, Vector3(1, 1, 0.5))
		_part(ir, _sph(0.021, 12), Vector3(0, 0, 0.012), pupil, Vector3(1, 1, 0.5))
		_part(ir, _sph(0.011, 8), Vector3(0.014, 0.016, 0.022), white)
		var brow := _node(head, Vector3(side * 0.115, BROW_Y, 0.272))
		var bar := _part(brow, _cap(0.013, 0.13), Vector3.ZERO, hair)
		bar.rotation.z = PI / 2.0
		if side < 0:
			_eye_l = eye
			_iris_l = ir
			_brow_l = brow
		else:
			_eye_r = eye
			_iris_r = ir
			_brow_r = brow

	# mouth: a lip ribbon (mesh swapped by smile amount) + dark opening
	for i in range(SMILE_LEVELS):
		var s := lerpf(-1.0, 1.0, float(i) / float(SMILE_LEVELS - 1))
		_smile_meshes.append(_arc_mesh(0.085 * s, 0.13, 0.016))
	_mouth_line = _part(head, _smile_meshes[SMILE_LEVELS - 1], Vector3(0, -0.155, 0.248), lip)
	_mouth_open = _part(head, _sph(0.05, 16), Vector3(0, -0.165, 0.243), mouth_in, Vector3(1.0, 0.1, 0.3))

# ── behaviour ─────────────────────────────────────────────────────────────────

func react(new_mood: String) -> void:
	if not FACES.has(new_mood):
		new_mood = "idle"
	mood = new_mood
	_mood_time = 0.0

func speak(seconds: float) -> void:
	talk = maxf(talk, seconds)

# Tint the orb, chest emblem and forehead crystal (e.g. the selected crystal).
func set_glow(color: Color) -> void:
	if _orb_mat:
		_orb_mat.albedo_color = color
		_orb_mat.emission = color
	if _gem_mat:
		_gem_mat.albedo_color = color
		_gem_mat.emission = color

# Joint targets for a mood. avl/afl/evl: viewer-left arm raise (z, negative =
# outward/up), swing (x, negative = forward), elbow (x, negative = bend forward).
func _pose(m: String, t: float, mt: float) -> Dictionary:
	var p: Dictionary = {
		"hy": 0.0, "hrz": 0.0, "hry": 0.0, "trx": 0.0, "trz": 0.0, "hdp": 0.0,
		"avl": -0.12, "afl": 0.0, "evl": -0.28, "avr": 0.12, "afr": 0.0, "evr": -0.28,
		"lvl": 0.0, "kvl": 0.04, "lvr": 0.0, "kvr": 0.04,
	}
	var b := absf(sin(t * 7.0))
	match m:
		"idle":
			var sway := sin(t * 0.55) * 0.04
			p["hy"] = sin(t * 1.8) * 0.008
			p["hrz"] = sway
			p["hry"] = sin(t * 0.3) * 0.10
			p["trz"] = -sway * 0.5
			p["avl"] = -0.14 + sin(t * 0.9) * 0.03
			p["avr"] = 0.14 - sin(t * 0.9 + 1.0) * 0.03
			p["lvl"] = sway * 0.8
		"happy":
			p["hy"] = b * 0.10
			p["trx"] = -0.05
			p["avl"] = -(1.7 + sin(t * 7.0) * 0.25)
			p["avr"] = 1.7 + sin(t * 7.0 + 1.0) * 0.25
			p["evl"] = -0.4
			p["evr"] = -0.4
			p["kvl"] = 0.25 * b
			p["kvr"] = 0.25 * b
			p["lvl"] = -0.12 * b
			p["lvr"] = -0.12 * b
		"cheer":
			var c := absf(sin(t * 6.0))
			p["hy"] = c * 0.22
			p["hrz"] = sin(t * 6.0) * 0.05
			p["avl"] = -2.6
			p["avr"] = 2.6
			p["evl"] = -0.15
			p["evr"] = -0.15
			p["kvl"] = 0.45 * c
			p["kvr"] = 0.45 * c
			p["lvl"] = -0.2 * c
			p["lvr"] = -0.2 * c
		"dance":
			var s8 := sin(t * 8.0)
			p["hry"] = sin(t * 4.0) * 0.6
			p["hrz"] = s8 * 0.10
			p["hy"] = absf(sin(t * 4.0)) * 0.12
			p["avl"] = -(1.6 + s8 * 0.9)
			p["avr"] = 1.6 - s8 * 0.9
			p["evl"] = -0.5 - s8 * 0.4
			p["evr"] = -0.5 + s8 * 0.4
			p["lvl"] = s8 * 0.45
			p["lvr"] = -s8 * 0.45
			p["kvl"] = maxf(0.0, s8) * 0.6
			p["kvr"] = maxf(0.0, -s8) * 0.6
		"clap":
			var s12 := sin(t * 12.0)
			p["hy"] = b * 0.05
			p["afl"] = -0.3
			p["afr"] = -0.3
			p["avl"] = 0.95 + s12 * 0.25
			p["avr"] = -0.95 - s12 * 0.25
			p["evl"] = -1.5
			p["evr"] = -1.5
			p["kvl"] = 0.12 * b
			p["kvr"] = 0.12 * b
		"wave":
			p["hy"] = absf(sin(t * 3.0)) * 0.03
			p["hrz"] = sin(t * 2.0) * 0.04
			p["avr"] = 2.5 + sin(t * 9.0) * 0.15
			p["evr"] = -0.9 + sin(t * 9.0) * 0.6
		"surprised":
			var pop := maxf(0.0, 1.0 - mt * 3.0)
			p["hy"] = pop * 0.25
			p["trx"] = -0.12
			p["afl"] = -1.4
			p["afr"] = -1.4
			p["avl"] = 0.6
			p["avr"] = -0.6
			p["evl"] = -1.7
			p["evr"] = -1.7
			p["kvl"] = 0.1
			p["kvr"] = 0.1
		"sad":
			p["trx"] = 0.22 + sin(t * 1.5) * 0.04
			p["hdp"] = 0.30
			p["hy"] = -0.05
			p["hrz"] = sin(t * 1.2) * 0.03
			p["avl"] = -0.05
			p["avr"] = 0.05
			p["afl"] = 0.1
			p["afr"] = 0.1
			p["evl"] = -0.15
			p["evr"] = -0.15
			p["kvl"] = 0.12
			p["kvr"] = 0.12
		"angry":
			var st := sin(t * 7.0)
			p["trx"] = 0.12
			p["hrz"] = sin(t * 14.0) * 0.03
			p["avl"] = -0.45
			p["avr"] = 0.45
			p["afl"] = -0.2
			p["afr"] = -0.2
			p["evl"] = -1.7
			p["evr"] = -1.7
			p["lvl"] = -maxf(0.0, st) * 0.45
			p["kvl"] = maxf(0.0, st) * 0.5
			p["hy"] = maxf(0.0, -st) * 0.04
		"think":
			p["trz"] = 0.05
			p["hdp"] = -0.08
			p["avr"] = -1.2
			p["afr"] = -0.9
			p["evr"] = -1.6
			p["avl"] = 0.4
			p["afl"] = -0.5
			p["evl"] = -1.4
			p["lvl"] = -maxf(0.0, sin(t * 5.0)) * 0.2
		"point":
			p["hry"] = -0.25
			p["avr"] = -0.35
			p["afr"] = -1.35
			p["evr"] = -0.15
			p["avl"] = -0.55
			p["evl"] = -1.5
			p["hrz"] = sin(t * 1.5) * 0.02
	return p

func _process(delta: float) -> void:
	if _root == null:
		return
	_time += delta
	_mood_time += delta
	if mood != "idle" and _mood_time > float(HOLD.get(mood, 1.6)):
		mood = "idle"
		_mood_time = 0.0

	# body
	var target := _pose(mood, _time, _mood_time)
	var k := clampf(1.0 - exp(-delta * 10.0), 0.0, 1.0)
	for key in target.keys():
		_jv[key] = lerpf(float(_jv.get(key, 0.0)), float(target[key]), k)
	_root.position.y = float(_jv["hy"])
	_hips.rotation = Vector3(0.0, float(_jv["hry"]), float(_jv["hrz"]))
	_torso.rotation = Vector3(float(_jv["trx"]), 0.0, float(_jv["trz"]))
	_sh_l.rotation = Vector3(float(_jv["afl"]), 0.0, float(_jv["avl"]))
	_el_l.rotation = Vector3(float(_jv["evl"]), 0.0, 0.0)
	_sh_r.rotation = Vector3(float(_jv["afr"]), 0.0, float(_jv["avr"]))
	_el_r.rotation = Vector3(float(_jv["evr"]), 0.0, 0.0)
	_hip_l.rotation = Vector3(float(_jv["lvl"]), 0.0, 0.0)
	_kn_l.rotation = Vector3(float(_jv["kvl"]), 0.0, 0.0)
	_hip_r.rotation = Vector3(float(_jv["lvr"]), 0.0, 0.0)
	_kn_r.rotation = Vector3(float(_jv["kvr"]), 0.0, 0.0)

	# face
	var face: Dictionary = FACES[mood]
	for key in face.keys():
		_fv[key] = lerpf(float(_fv[key]), float(face[key]), k)
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
	var eye_open := float(_fv["eye"]) * blink
	_eye_l.scale = Vector3(1, eye_open, 1)
	_eye_r.scale = Vector3(1, eye_open, 1)
	var bu := float(_fv["bup"])
	var ba := float(_fv["brow"])
	_brow_l.rotation.z = -ba
	_brow_r.rotation.z = ba
	_brow_l.position.y = BROW_Y + bu
	_brow_r.position.y = BROW_Y + bu
	var smile := clampf(float(_fv["smile"]), -1.0, 1.0)
	var idx := clampi(int(round((smile + 1.0) * 0.5 * float(SMILE_LEVELS - 1))), 0, SMILE_LEVELS - 1)
	_mouth_line.mesh = _smile_meshes[idx]
	var open := float(_fv["open"])
	if talk > 0.0:
		talk -= delta
		open = maxf(open, 0.35 + 0.65 * absf(sin(_time * 14.0)))
	_mouth_open.scale = Vector3(1.0 + open * 0.15, 0.1 + open * 1.1, 0.3)
	_mouth_open.position.y = -0.165 - open * 0.012

	# head: look-at, mood tilt, idle sway
	var yaw := clampf(look_target.x, -0.6, 0.6)
	var pitch := clampf(look_target.y, -0.4, 0.4) + float(_jv["hdp"])
	_head.rotation.y = lerpf(_head.rotation.y, yaw, k)
	_head.rotation.x = lerpf(_head.rotation.x, pitch, k)
	_head.rotation.z = float(_fv["tilt"]) + sin(_time * 0.9) * 0.025
	var shift := Vector3(yaw * 0.03, -pitch * 0.03, 0)
	_iris_l.position = Vector3(shift.x, shift.y, 0.02)
	_iris_r.position = Vector3(shift.x, shift.y, 0.02)

	# glowing orb pulse
	if _orb_mat:
		_orb_mat.emission_energy_multiplier = 1.4 + sin(_time * 3.0) * 0.4
	if _gem_mat:
		_gem_mat.emission_energy_multiplier = 1.6 + sin(_time * 2.4) * 0.3
