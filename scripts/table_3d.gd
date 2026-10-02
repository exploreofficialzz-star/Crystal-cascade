class_name Table3D
extends Node3D

# A wizard's workbench for the tubes: wooden slab, apron, turned legs, velvet
# cloth with a gold trim, glowing rune pads under every tube, a raised tier for
# the back row when there are two rows, and a few props. Sized from the layout.

const TOP_Y := -0.25          # top of the wooden slab
const CLOTH_H := 0.04         # tube bases rest on TOP_Y + CLOTH_H
const FLOOR_Y := -2.9

func _mi(mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.position = pos
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	return m

func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _mi(b, pos, mat)

func _cyl(top_r: float, bottom_r: float, h: float, pos: Vector3, mat: Material, segs: int = 20) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = top_r
	c.bottom_radius = bottom_r
	c.height = h
	c.radial_segments = segs
	c.rings = 1
	return _mi(c, pos, mat)

func _sph(r: float, pos: Vector3, mat: Material, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 6
	var m := _mi(s, pos, mat)
	m.scale = scl
	return m

func _mat(color: Color, rough: float = 0.6, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m

func _textured(path: String, tiling: float, tint: Color = Color.WHITE, rough: float = 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var t: Texture2D = Ui.tex(path)
	if t != null:
		m.albedo_texture = t
	m.albedo_color = tint
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(tiling, tiling, tiling)
	m.roughness = rough
	return m

func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func build(layout: Dictionary) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	var pos: Array = layout["pos"]
	var rows: int = int(layout["rows"])
	var min_x := 0.0
	var max_x := 0.0
	var min_z := 0.0
	var max_z := 0.0
	var back_min_x := 999.0
	var back_max_x := -999.0
	var back_z := 0.0
	for p in pos:
		var v: Vector3 = p
		min_x = minf(min_x, v.x)
		max_x = maxf(max_x, v.x)
		min_z = minf(min_z, v.z)
		max_z = maxf(max_z, v.z)
		if v.y > 0.01:
			back_min_x = minf(back_min_x, v.x)
			back_max_x = maxf(back_max_x, v.x)
			back_z = v.z
	var half_w := maxf(absf(min_x), absf(max_x)) + 1.7
	var zmin := min_z - 1.5
	var zmax := max_z + 1.5
	var w := half_w * 2.0
	var d := zmax - zmin
	var cz := (zmin + zmax) * 0.5

	var wood := _textured("res://assets/textures/wood_planks.png", 0.22, Color(1, 1, 1), 0.5)
	var wood_dark := _textured("res://assets/textures/wood_planks.png", 0.22, Color(0.55, 0.42, 0.40), 0.55)
	var cloth := _textured("res://assets/textures/velvet.png", 0.9, Color(1, 1, 1), 0.95)
	var gold := _mat(Color("#e8c243"), 0.28, 0.85)
	gold.emission_enabled = true
	gold.emission = Color("#e8c243")
	gold.emission_energy_multiplier = 0.18

	# slab, apron and cloth
	_box(Vector3(w, 0.34, d), Vector3(0, TOP_Y - 0.17, cz), wood)
	_box(Vector3(w - 0.5, 0.30, d - 0.5), Vector3(0, TOP_Y - 0.49, cz), wood_dark)
	var cw := w - 0.9
	var cd := d - 0.9
	_box(Vector3(cw, CLOTH_H, cd), Vector3(0, TOP_Y + CLOTH_H * 0.5, cz), cloth)

	# gold trim around the cloth
	var ty := TOP_Y + CLOTH_H + 0.02
	_box(Vector3(cw + 0.12, 0.05, 0.07), Vector3(0, ty, cz + cd * 0.5), gold)
	_box(Vector3(cw + 0.12, 0.05, 0.07), Vector3(0, ty, cz - cd * 0.5), gold)
	_box(Vector3(0.07, 0.05, cd + 0.12), Vector3(cw * 0.5, ty, cz), gold)
	_box(Vector3(0.07, 0.05, cd + 0.12), Vector3(-cw * 0.5, ty, cz), gold)
	for cx in [-1.0, 1.0]:
		for cs in [-1.0, 1.0]:
			_sph(0.10, Vector3(cx * cw * 0.5, ty + 0.03, cz + cs * cd * 0.5), gold)

	# raised tier for the back row
	var back_prop_y := TOP_Y
	var back_half := half_w - 0.42
	if rows > 1 and back_max_x > back_min_x - 1.0:
		var rh := BoardLayout.RISER
		var rw := (back_max_x - back_min_x) + 2.8
		var rcx := (back_min_x + back_max_x) * 0.5
		var rd := 2.9
		_box(Vector3(rw, rh, rd), Vector3(rcx, TOP_Y + rh * 0.5, back_z), wood_dark)
		_box(Vector3(rw - 0.4, CLOTH_H, rd - 0.4), Vector3(rcx, TOP_Y + rh + CLOTH_H * 0.5, back_z), cloth)
		_box(Vector3(rw - 0.2, 0.05, 0.07), Vector3(rcx, TOP_Y + rh + CLOTH_H + 0.02, back_z + rd * 0.5 - 0.22), gold)
		_box(Vector3(rw + 0.05, 0.10, 0.10), Vector3(rcx, TOP_Y + rh + 0.01, back_z + rd * 0.5), gold)
		back_prop_y = TOP_Y + rh + CLOTH_H
		back_half = rw * 0.5 - 0.45

	# turned legs
	var leg_top := TOP_Y - 0.64
	var leg_h := leg_top - FLOOR_Y
	for lx in [-1.0, 1.0]:
		for lz in [-1.0, 1.0]:
			var px: float = lx * (w * 0.5 - 0.55)
			var pz: float = cz + lz * (d * 0.5 - 0.55)
			_cyl(0.20, 0.15, leg_h, Vector3(px, FLOOR_Y + leg_h * 0.5, pz), wood_dark)
			_cyl(0.27, 0.27, 0.10, Vector3(px, leg_top - 0.10, pz), gold)
			_cyl(0.30, 0.34, 0.14, Vector3(px, FLOOR_Y + 0.07, pz), wood)

	# glowing rune pad under every tube
	var pad_mat := StandardMaterial3D.new()
	var rune: Texture2D = Ui.tex("res://assets/textures/rune_rug.png")
	if rune != null:
		pad_mat.albedo_texture = rune
	pad_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pad_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pad_mat.albedo_color = Color(0.75, 1.0, 1.0, 0.95)
	pad_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for p in pos:
		var v: Vector3 = p
		var pad := PlaneMesh.new()
		pad.size = Vector2(2.7, 2.7)
		_mi(pad, Vector3(v.x, TOP_Y + CLOTH_H + v.y + 0.008, v.z), pad_mat)

	_add_props(back_half, half_w, zmin, zmax, back_prop_y, gold)

func _add_props(back_half: float, half_w: float, zmin: float, zmax: float, back_y: float, gold: StandardMaterial3D) -> void:
	var cream := _mat(Color("#f3e6c8"), 0.7)
	var flame := _glow(Color("#ffb347"), 2.2)
	var bz := zmin + 0.45
	# candles (back corners) with emissive flames
	for s in [-1.0, 1.0]:
		var p := Vector3(s * back_half, back_y, bz)
		_cyl(0.11, 0.11, 0.55, p + Vector3(0, 0.275, 0), cream)
		_sph(0.07, p + Vector3(0, 0.66, 0), flame, Vector3(0.8, 1.5, 0.8))
		_cyl(0.17, 0.17, 0.05, p + Vector3(0, 0.025, 0), gold)
	# book stack beside the left candle
	var book_cols := [Color("#7b2cbf"), Color("#1f6feb"), Color("#c1121f")]
	for i in range(3):
		var b := _box(Vector3(0.95 - i * 0.08, 0.14, 0.68), Vector3(-back_half + 0.95, back_y + 0.07 + i * 0.145, bz + 0.1), _mat(book_cols[i], 0.7))
		b.rotation.y = 0.12 * float(i - 1)
	# potion bottles (front corners)
	var potion_cols := [Color(0.35, 1.0, 0.7, 0.85), Color(1.0, 0.45, 0.85, 0.85)]
	for k in range(2):
		var s2 := -1.0 if k == 0 else 1.0
		var glass := _mat(potion_cols[k], 0.15)
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.emission_enabled = true
		glass.emission = potion_cols[k]
		glass.emission_energy_multiplier = 0.6
		var p2 := Vector3(s2 * (half_w - 0.42), TOP_Y, zmax - 0.45)
		_sph(0.19, p2 + Vector3(0, 0.19, 0), glass)
		_cyl(0.06, 0.06, 0.22, p2 + Vector3(0, 0.44, 0), glass)
		_cyl(0.07, 0.07, 0.07, p2 + Vector3(0, 0.58, 0), _mat(Color("#7a4a2a"), 0.8))
