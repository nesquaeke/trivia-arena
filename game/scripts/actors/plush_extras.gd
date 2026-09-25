class_name PlushExtras
extends RefCounted
## Pelüşün yeni giysileri: kolye/takılar, kıyafetler, ek şapkalar ve gözlük parçaları.
## Hepsi ilkel şekillerden, gövdenin gerçek eğrisine oturacak şekilde hesaplanır
## (plush_visual.gd'deki ölçüler: gövde kapsülü r=0.31, y 0.19–0.95; baş r≈0.3).

const NECKLACES := ["none", "gold_chain", "locket", "beads", "lei", "tooth", "crystal", "medallion"]
const OUTFITS := ["none", "sweater", "overalls", "tutu", "cape", "vest", "tuxedo", "hoodie", "raincoat"]
const EXTRA_HATS := ["beanie", "graduate", "halo", "headphones", "bunny", "santa", "tiara", "sombrero"]
const EXTRA_GLASSES := ["heart", "aviator", "cinema3d", "nerd", "goggles"]

const BODY_R := 0.31
const BODY_Y0 := 0.50      # kapsülün düz kısmı
const BODY_Y1 := 0.64

## Gövdenin y yüksekliğindeki yarıçapı (kapsül)
static func body_r(y: float, pad := 0.0) -> float:
	var dy := 0.0
	if y < BODY_Y0:
		dy = BODY_Y0 - y
	elif y > BODY_Y1:
		dy = y - BODY_Y1
	return sqrt(maxf(0.0, BODY_R * BODY_R - dy * dy)) + pad

## Boynu önden saran bir yay üzerinde n nokta (gövde koordinatları)
static func neck_arc(n: int, y_back := 0.86, drop := 0.09, pad := 0.012, span := 0.82) -> Array:
	var pts := []
	for i in n:
		var u := i / float(max(1, n - 1))
		var th := lerpf(PI * (0.5 - span * 0.5), PI * (0.5 + span * 0.5), u)
		var s := sin(th)
		var y := y_back - drop * pow(s, 2.0)
		var r := body_r(y, pad)
		pts.append(Vector3(cos(th) * r, y, s * r))
	return pts

# ── ağ yardımcıları ─────────────────────────────────────────────────
static func polygon_mesh(poly: PackedVector2Array, depth: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := Vector2.ZERO
	for p in poly:
		c += p
	c /= poly.size()
	var n := poly.size()
	var hz := depth * 0.5
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		# ön ve arka yüz
		st.set_normal(Vector3(0, 0, 1))
		st.add_vertex(Vector3(c.x, c.y, hz))
		st.add_vertex(Vector3(a.x, a.y, hz))
		st.add_vertex(Vector3(b.x, b.y, hz))
		st.set_normal(Vector3(0, 0, -1))
		st.add_vertex(Vector3(c.x, c.y, -hz))
		st.add_vertex(Vector3(b.x, b.y, -hz))
		st.add_vertex(Vector3(a.x, a.y, -hz))
		# kenar
		var nrm := Vector3(b.y - a.y, a.x - b.x, 0).normalized()
		st.set_normal(nrm)
		st.add_vertex(Vector3(a.x, a.y, hz))
		st.add_vertex(Vector3(a.x, a.y, -hz))
		st.add_vertex(Vector3(b.x, b.y, hz))
		st.add_vertex(Vector3(b.x, b.y, hz))
		st.add_vertex(Vector3(a.x, a.y, -hz))
		st.add_vertex(Vector3(b.x, b.y, -hz))
	return st.commit()

static func star_poly(r_out: float, r_in: float, points := 5) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in points * 2:
		var a := PI / 2 + i * PI / points
		var r := r_out if i % 2 == 0 else r_in
		p.append(Vector2(cos(a), sin(a)) * r)
	return p

static func heart_poly(s: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in 28:
		var t := TAU * i / 28.0
		var x := 16.0 * pow(sin(t), 3)
		var y := 13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t)
		p.append(Vector2(x, y) * s / 17.0)
	return p

static func _grp(n: Node, g := "extra") -> void:
	n.add_to_group(g)

static func _m(v: PlushVisual, parent: Node3D, mesh: Mesh, m: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := v._mesh(parent, mesh, m, pos, rot, scl)
	_grp(mi)
	return mi

static func _sph(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 16
	s.rings = 8
	return s

static func _cyl(t: float, b: float, h: float, seg := 20) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = t
	c.bottom_radius = b
	c.height = h
	c.radial_segments = seg
	return c

static func _cap(r: float, h: float, seg := 12, rings := 4) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.0)
	c.radial_segments = seg
	c.rings = rings
	return c

## Arkada duran kavisli kumaş (pelerin): a0..a1 açıları arası silindir yayı
static func arc_sheet(r_top: float, r_bot: float, h: float, a0: float, a1: float, thick := 0.02, seg := 20) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for layer in 2:
		var dr := 0.0 if layer == 0 else thick
		for i in seg:
			var u0 := i / float(seg)
			var u1 := (i + 1) / float(seg)
			var t0 := lerpf(a0, a1, u0)
			var t1 := lerpf(a0, a1, u1)
			var p00 := Vector3(cos(t0) * (r_top + dr), h * 0.5, sin(t0) * (r_top + dr))
			var p01 := Vector3(cos(t1) * (r_top + dr), h * 0.5, sin(t1) * (r_top + dr))
			var p10 := Vector3(cos(t0) * (r_bot + dr), -h * 0.5, sin(t0) * (r_bot + dr))
			var p11 := Vector3(cos(t1) * (r_bot + dr), -h * 0.5, sin(t1) * (r_bot + dr))
			var n0 := Vector3(cos(t0), 0, sin(t0)) * (1.0 if layer == 1 else -1.0)
			var n1 := Vector3(cos(t1), 0, sin(t1)) * (1.0 if layer == 1 else -1.0)
			var tri := [[p00, n0], [p10, n0], [p11, n1], [p00, n0], [p11, n1], [p01, n1]]
			if layer == 0:
				tri = [[p00, n0], [p11, n1], [p10, n0], [p00, n0], [p01, n1], [p11, n1]]
			for v in tri:
				st.set_normal(v[1])
				st.add_vertex(v[0])
	return st.commit()

static func _torus(i: float, o: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = i
	t.outer_radius = o
	t.rings = 24
	t.ring_segments = 10
	return t

static func _box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b

## İki nokta arasında çubuk (kapsül)
static func _rod(v: PlushVisual, parent: Node3D, a: Vector3, b: Vector3, r: float, m: Material) -> MeshInstance3D:
	var mi := _m(v, parent, _cap(r, a.distance_to(b) + r * 2.0), m)
	var mid := (a + b) * 0.5
	var dir := (b - a).normalized()
	var up := Vector3.UP
	var basis := Basis()
	var axis := up.cross(dir)
	if axis.length() < 0.0001:
		basis = Basis() if dir.y > 0 else Basis(Vector3.RIGHT, PI)
	else:
		basis = Basis(axis.normalized(), acos(clampf(up.dot(dir), -1.0, 1.0)))
	mi.transform = Transform3D(basis, mid)
	return mi

# ── kolyeler / takılar ─────────────────────────────────────────────
static func build_necklace(v: PlushVisual, kind: String) -> void:
	if kind == "none" or kind == "":
		return
	var root := v.body_root
	var gold := v.mat("gold", Color("D6A93F"), 0.25, 1.0)
	var silver := v.mat("silver", Color("D8DCE3"), 0.2, 1.0)
	match kind:
		"gold_chain":
			var pts := neck_arc(24, 0.87, 0.1)
			for i in pts.size():
				_m(v, root, _torus(0.008, 0.017), gold, pts[i], Vector3(PI / 2 if i % 2 == 0 else 0.0, float(i) * 0.4, 0))
		"locket":
			for p in neck_arc(30, 0.87, 0.1):
				_m(v, root, _sph(0.006), gold, p)
			var front: Vector3 = neck_arc(3, 0.87, 0.1)[1]
			var h := _m(v, root, polygon_mesh(heart_poly(0.045), 0.018), v.mat("locket", Color("C9303C"), 0.3, 0.2), front + Vector3(0, -0.05, 0.012), Vector3(0.18, 0, 0))
			h.scale = Vector3(1, 1, 1)
			_m(v, root, _torus(0.006, 0.012), gold, front + Vector3(0, -0.01, 0.006), Vector3(0, 0, 0))
		"beads":
			var cols := [Color("C9303C"), Color("F2C230"), Color("3FC4B2"), Color("F07B5B"), Color("7A5CC8")]
			var pts2 := neck_arc(15, 0.87, 0.1, 0.018)
			for i in pts2.size():
				_m(v, root, _sph(0.022), v.mat("bead_%d" % (i % 5), cols[i % 5], 0.35), pts2[i])
		"lei":
			var cl := [Color("F27BA8"), Color("FFD84A"), Color("FFFFFF"), Color("F2994A"), Color("C66BE0")]
			var pts3 := neck_arc(20, 0.88, 0.12, 0.025, 0.95)
			for i in pts3.size():
				var p3: Vector3 = pts3[i]
				_m(v, root, _sph(0.036), v.mat("lei_%d" % (i % 5), cl[i % 5], 0.8), p3, Vector3.ZERO, Vector3(1, 0.8, 1))
				_m(v, root, _sph(0.012), v.mat("lei_c", Color("F2C230"), 0.6), p3 + p3.normalized() * 0.03 * Vector3(1, 0, 1))
		"tooth":
			for p in neck_arc(22, 0.87, 0.1):
				_m(v, root, _sph(0.008), v.mat("cord", Color("3A2416"), 0.8), p)
			var f2: Vector3 = neck_arc(3, 0.87, 0.1)[1]
			_m(v, root, _cyl(0.0, 0.024, 0.08, 8), v.mat("tooth", Color("F5EEDB"), 0.4), f2 + Vector3(0, -0.05, 0.012), Vector3(PI, 0, 0))
		"crystal":
			for p in neck_arc(30, 0.87, 0.11):
				_m(v, root, _sph(0.005), silver, p)
			var f3: Vector3 = neck_arc(3, 0.87, 0.11)[1]
			var gem := SphereMesh.new()
			gem.radius = 0.035
			gem.height = 0.09
			gem.radial_segments = 6
			gem.rings = 2
			var gm := v.mat("gem", Color("5BC8F0"), 0.05, 0.3)
			gm.emission_enabled = true
			gm.emission = Color("5BC8F0")
			gm.emission_energy_multiplier = 0.6
			_m(v, root, gem, gm, f3 + Vector3(0, -0.05, 0.015))
		"medallion":
			var pts4 := neck_arc(18, 0.87, 0.1, 0.014)
			for i in pts4.size():
				_m(v, root, _torus(0.012, 0.024), gold, pts4[i], Vector3(PI / 2 if i % 2 == 0 else 0.0, float(i) * 0.4, 0))
			var f4: Vector3 = neck_arc(3, 0.87, 0.1)[1]
			_m(v, root, _cyl(0.055, 0.055, 0.016, 24), gold, f4 + Vector3(0, -0.07, 0.02), Vector3(PI / 2 - 0.2, 0, 0))
			_m(v, root, polygon_mesh(star_poly(0.04, 0.018, 8), 0.02), v.mat("sun", Color("FFE08A"), 0.3, 0.8), f4 + Vector3(0, -0.07, 0.03), Vector3(-0.2, 0, 0))

# ── kıyafetler ─────────────────────────────────────────────────────
static func _shell(v: PlushVisual, m: Material, y0: float, y1: float, pad := 0.016) -> MeshInstance3D:
	# gövdenin profilini (kapsül) birebir izleyen açık bir tüp: y0..y1
	var mi := _m(v, v.body_root, lathe(y0, y1, pad), m)
	for y in [y0, y1]:
		if y > 0.26 and y < 0.9:
			var rr := body_r(y, pad)
			_m(v, v.body_root, _torus(rr - 0.012, rr + 0.012), m, Vector3(0, y, 0))
	return mi

## Gövde profili etrafında dönel yüzey (kıyafet kılıfı)
static func lathe(y0: float, y1: float, pad: float, seg := 48, rings := 28) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var prof := []
	for j in rings + 1:
		var y := lerpf(y0, y1, j / float(rings))
		prof.append(Vector2(body_r(y, pad), y))
	for j in rings:
		var a: Vector2 = prof[j]
		var b: Vector2 = prof[j + 1]
		var slope := Vector2(b.y - a.y, -(b.x - a.x)).normalized()   # profilin dış normali (r, y)
		for i in seg:
			var t0 := TAU * i / seg
			var t1 := TAU * (i + 1) / seg
			var c0 := Vector3(cos(t0), 0, sin(t0))
			var c1 := Vector3(cos(t1), 0, sin(t1))
			var v00 := c0 * a.x + Vector3(0, a.y, 0)
			var v01 := c1 * a.x + Vector3(0, a.y, 0)
			var v10 := c0 * b.x + Vector3(0, b.y, 0)
			var v11 := c1 * b.x + Vector3(0, b.y, 0)
			var n0 := (c0 * slope.x + Vector3(0, slope.y, 0)).normalized()
			var n1 := (c1 * slope.x + Vector3(0, slope.y, 0)).normalized()
			for q in [[v00, n0], [v11, n1], [v10, n0], [v00, n0], [v01, n1], [v11, n1]]:
				st.set_normal(q[1])
				st.set_uv(Vector2(float(i) / seg, float(j) / rings))
				st.add_vertex(q[0])
	st.generate_tangents()
	return st.commit()

static func _front(v: PlushVisual, m: Material, y: float, size: Vector3, x := 0.0, pad := 0.018) -> MeshInstance3D:
	var r := body_r(y, pad)
	var z := sqrt(maxf(0.0, r * r - x * x))
	return _m(v, v.body_root, _box(size), m, Vector3(x, y, z), Vector3(0, asin(clampf(x / r, -1, 1)), 0))

static func _sleeves(v: PlushVisual, m: Material, length := 0.26) -> void:
	for arm in [v.arm_l, v.arm_r]:
		var s := _m(v, arm, _cap(0.09, length, 32, 8), m, Vector3(0, -0.07, 0))
		s.name = "Sleeve"

static func _stripes(v: PlushVisual, m: Material, ys: Array, pad := 0.017) -> void:
	for y in ys:
		var r := body_r(float(y), pad)
		_m(v, v.body_root, _torus(r - 0.012, r + 0.004), m, Vector3(0, float(y), 0), Vector3.ZERO, Vector3(1, 0.6, 1))

static func build_outfit(v: PlushVisual, kind: String, accent: Color) -> void:
	if kind == "none" or kind == "":
		return
	var gold := v.mat("gold", Color("D6A93F"), 0.25, 1.0)
	var cream := PlushVisual.felt(Color("F5ECD6"))
	match kind:
		"sweater":
			var sw := PlushVisual.felt(Color("C9303C"))
			_shell(v, sw, 0.36, 0.9)
			_stripes(v, PlushVisual.felt(Color("F5ECD6")), [0.48, 0.6, 0.72])
			_m(v, v.body_root, _torus(0.2, 0.26), sw, Vector3(0, 0.88, 0), Vector3.ZERO, Vector3(1, 1.6, 1))
			_sleeves(v, sw)
		"overalls":
			var denim := PlushVisual.felt(Color("3B5C9A"))
			_shell(v, denim, 0.2, 0.6, 0.014)
			_front(v, denim, 0.68, Vector3(0.24, 0.2, 0.03))
			for side: int in [-1, 1]:
				_rod(v, v.body_root, Vector3(0.1 * side, 0.76, body_r(0.76, 0.02)), Vector3(0.14 * side, 0.93, -0.05), 0.018, denim)
				_m(v, v.body_root, _sph(0.02), gold, Vector3(0.1 * side, 0.75, body_r(0.75, 0.035)))
			for leg in [v.leg_l, v.leg_r]:
				_m(v, leg, _cap(0.108, 0.26, 32, 8), denim, Vector3(0, -0.09, 0))
			_front(v, v.mat("pocket", Color("2E4A80"), 0.8), 0.66, Vector3(0.1, 0.07, 0.02), 0.0, 0.036)
		"tutu":
			var tm := v.mat("tutu", Color("F7A6C8"), 0.9)
			tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			tm.albedo_color.a = 0.85
			for k in 3:
				_m(v, v.body_root, _cyl(0.3, 0.46 - k * 0.04, 0.07, 28), tm, Vector3(0, 0.33 + k * 0.045, 0))
			_shell(v, PlushVisual.felt(Color("F7A6C8")), 0.38, 0.86)
			_m(v, v.body_root, _sph(0.03), v.mat("tutu_gem", Color("FFFFFF"), 0.1, 0.5), Vector3(0, 0.78, body_r(0.78, 0.02)))
		"cape":
			var cm := v.mat("cape", accent.darkened(0.1) if accent != Color.WHITE else Color("B21E2C"), 0.55)
			cm.cull_mode = BaseMaterial3D.CULL_DISABLED
			_m(v, v.body_root, arc_sheet(0.3, 0.42, 0.7, PI * 1.08, PI * 1.92, 0.02, 24), cm, Vector3(0, 0.54, -0.02))
			_m(v, v.body_root, _torus(0.22, 0.27), cm, Vector3(0, 0.9, -0.02), Vector3(0.25, 0, 0), Vector3(1, 1.3, 1))
			_m(v, v.body_root, _sph(0.03), gold, Vector3(0, 0.86, body_r(0.86, 0.03)))
		"vest":
			var vm := PlushVisual.felt(Color("6B3A5A"))
			_shell(v, vm, 0.42, 0.88)
			_front(v, cream, 0.66, Vector3(0.12, 0.42, 0.02), 0.0, 0.03)
			for k in 3:
				_m(v, v.body_root, _sph(0.014), gold, Vector3(0, 0.56 + k * 0.08, body_r(0.56 + k * 0.08, 0.045)))
			_m(v, v.body_root, _box(Vector3(0.01, 0.06, 0.01)), gold, Vector3(0.1, 0.62, body_r(0.62, 0.03)))
		"tuxedo":
			var tx := v.mat("tux", Color("17141B"), 0.5)
			_shell(v, tx, 0.3, 0.9)
			_front(v, v.mat("tux_shirt", Color("F7F4EC"), 0.6), 0.66, Vector3(0.14, 0.44, 0.02), 0.0, 0.03)
			for side: int in [-1, 1]:
				_front(v, v.mat("tux_lapel", Color("26222C"), 0.25), 0.73, Vector3(0.06, 0.26, 0.012), 0.09 * side, 0.036).rotation.z = 0.35 * side
			for k in 3:
				_m(v, v.body_root, _sph(0.012), v.mat("tux_btn", Color("111111"), 0.2), Vector3(0, 0.52 + k * 0.08, body_r(0.52 + k * 0.08, 0.042)))
			_sleeves(v, tx)
		"hoodie":
			var hm := PlushVisual.felt(accent.darkened(0.25) if accent != Color.WHITE else Color("5B6B7A"))
			_shell(v, hm, 0.32, 0.9)
			_front(v, hm, 0.46, Vector3(0.3, 0.12, 0.03), 0.0, 0.02)
			for side: int in [-1, 1]:
				_rod(v, v.body_root, Vector3(0.05 * side, 0.86, body_r(0.86, 0.03)), Vector3(0.06 * side, 0.72, body_r(0.72, 0.03)), 0.007, cream)
			var hood := _m(v, v.head_pivot, _sph(0.3), hm, Vector3(0, 0.06, -0.14), Vector3.ZERO, Vector3(1.08, 0.9, 0.62))
			hood.name = "Hood"
			_sleeves(v, hm)
		"raincoat":
			var rc := v.mat("rain", Color("F5C518"), 0.18)
			_shell(v, rc, 0.24, 0.9, 0.016)
			for k in 4:
				_m(v, v.body_root, _sph(0.016), v.mat("rain_btn", Color("2A2A2A"), 0.2), Vector3(0.05, 0.48 + k * 0.1, body_r(0.48 + k * 0.1, 0.03)))
			_sleeves(v, rc, 0.3)

# ── ek şapkalar (şapka çapası başın tepesinde, y=0) ─────────────────
static func build_hat(v: PlushVisual, kind: String) -> bool:
	var a := v.hat_anchor
	var gold := v.mat("gold", Color("D6A93F"), 0.25, 1.0)
	match kind:
		"beanie":
			var bn := PlushVisual.felt(Color("2F8F6B"))
			var dome := SphereMesh.new()
			dome.radius = 0.3
			dome.height = 0.3
			dome.is_hemisphere = true
			_m(v, a, dome, bn, Vector3(0, -0.11, 0), Vector3.ZERO, Vector3(1.0, 0.72, 0.98))
			_m(v, a, _torus(0.27, 0.315), PlushVisual.felt(Color("F5ECD6")), Vector3(0, -0.1, 0), Vector3.ZERO, Vector3(1, 1.3, 0.97))
			_m(v, a, _sph(0.065), PlushVisual.felt(Color("F5ECD6")), Vector3(0, 0.12, 0))
		"graduate":
			var blk := v.mat("grad", Color("17141B"), 0.5)
			_m(v, a, _cyl(0.2, 0.21, 0.1, 24), blk, Vector3(0, -0.04, 0))
			_m(v, a, _box(Vector3(0.44, 0.022, 0.44)), blk, Vector3(0, 0.02, 0), Vector3(0, PI / 4, 0))
			_m(v, a, _sph(0.016), gold, Vector3(0, 0.035, 0))
			_rod(v, a, Vector3(0, 0.035, 0), Vector3(0.2, 0.02, 0.1), 0.006, gold)
			_rod(v, a, Vector3(0.2, 0.02, 0.1), Vector3(0.22, -0.1, 0.11), 0.01, gold)
		"halo":
			var hm := v.mat("halo", Color("FFE7A0"), 0.2, 0.5)
			hm.emission_enabled = true
			hm.emission = Color("FFD86A")
			hm.emission_energy_multiplier = 1.4
			_m(v, a, _torus(0.14, 0.175), hm, Vector3(0, 0.13, 0))
		"headphones":
			var hp := v.mat("hp", Color("E9E6EF"), 0.3)
			var cup := v.mat("hp_cup", Color("F04E8C"), 0.35)
			var band := _m(v, a, _torus(0.3, 0.33), hp, Vector3(0, -0.27, -0.02), Vector3(0, 0, PI / 2), Vector3(1, 1, 0.35))
			band.name = "Band"
			for side: int in [-1, 1]:
				_m(v, a, _cyl(0.085, 0.085, 0.07, 20), cup, Vector3(0.3 * side, -0.29, -0.02), Vector3(0, 0, PI / 2))
				_m(v, a, _cyl(0.06, 0.06, 0.075, 20), hp, Vector3(0.31 * side, -0.29, -0.02), Vector3(0, 0, PI / 2))
		"bunny":
			var wf := PlushVisual.felt(Color("F4F1EC"))
			var pk := PlushVisual.felt(Color("F2A5C0"))
			for side: int in [-1, 1]:
				var ear := Node3D.new()
				_grp(ear)
				ear.position = Vector3(0.08 * side, -0.02, 0.0)
				ear.rotation = Vector3(-0.1, 0, -0.18 * side)
				a.add_child(ear)
				_m(v, ear, _cap(0.05, 0.34), wf, Vector3(0, 0.16, 0), Vector3.ZERO, Vector3(1, 1, 0.5))
				_m(v, ear, _cap(0.028, 0.26), pk, Vector3(0, 0.16, 0.02), Vector3.ZERO, Vector3(1, 1, 0.4))
			_m(v, a, _torus(0.22, 0.26), v.mat("bunny_band", Color("F04E8C"), 0.5), Vector3(0, -0.07, 0), Vector3(0, 0, PI / 2), Vector3(1, 1, 0.3))
		"santa":
			var red := PlushVisual.felt(Color("C9303C"))
			var wh := PlushVisual.felt(Color("F7F4EC"))
			_m(v, a, _cyl(0.03, 0.22, 0.36, 22), red, Vector3(0.05, 0.08, -0.03), Vector3(-0.35, 0, -0.35))
			_m(v, a, _torus(0.2, 0.27), wh, Vector3(0, -0.08, 0), Vector3.ZERO, Vector3(1, 1.4, 1))
			_m(v, a, _sph(0.055), wh, Vector3(0.17, 0.2, -0.13))
		"tiara":
			var gem := v.mat("tiara_gem", Color("7FD6F2"), 0.05, 0.4)
			gem.emission_enabled = true
			gem.emission = Color("7FD6F2")
			gem.emission_energy_multiplier = 0.5
			for i in 7:
				var ang := lerpf(-0.9, 0.9, i / 6.0)
				var p := Vector3(sin(ang) * 0.24, -0.075, cos(ang) * 0.2)
				var h := 0.1 if i == 3 else (0.07 if i % 2 == 1 else 0.05)
				_m(v, a, _cyl(0.0, 0.022, h, 6), gold, p + Vector3(0, h * 0.5, 0), Vector3(0, ang, 0))
				if i % 2 == 1 or i == 3:
					_m(v, a, _sph(0.016), gem, p + Vector3(0, 0.015, 0.012))
			_m(v, a, _torus(0.235, 0.255), gold, Vector3(0, -0.08, 0), Vector3.ZERO, Vector3(1, 0.5, 0.85))
		"sombrero":
			var st := v.mat("sombrero", Color("D9A95B"), 0.8)
			_m(v, a, _cyl(0.46, 0.46, 0.02, 36), st, Vector3(0, -0.05, 0))
			_m(v, a, _torus(0.42, 0.47), st, Vector3(0, -0.04, 0), Vector3.ZERO, Vector3(1, 1.8, 1))
			_m(v, a, _cyl(0.1, 0.17, 0.2, 24), st, Vector3(0, 0.06, 0))
			for k in 3:
				_m(v, a, _cyl(0.165 - k * 0.018, 0.17 - k * 0.018, 0.022, 24), v.mat("somb_%d" % k, [Color("C9303C"), Color("3FC4B2"), Color("F2C230")][k], 0.6), Vector3(0, -0.02 + k * 0.03, 0))
		_:
			return false
	return true

# ── gözlükler (gözlük çapası: göz hizasında, yüzün önünde) ─────────
## Gözlük sapları: ön köşeden kulağa, başın yüzeyinde
static func temples(v: PlushVisual, m: Material, y := 0.0, front_x := 0.16) -> void:
	for side: int in [-1, 1]:
		_rod(v, v.glasses_anchor, Vector3(front_x * side, y, -0.05), Vector3(0.275 * side, y + 0.01, -0.4), 0.007, m)

static func build_glasses(v: PlushVisual, kind: String) -> bool:
	var g := v.glasses_anchor
	var gold := v.mat("gold", Color("D6A93F"), 0.25, 1.0)
	match kind:
		"heart":
			var fr := v.mat("heart_f", Color("F04E8C"), 0.35)
			var ln := v.mat("heart_l", Color("5A1030"), 0.1, 0.2)
			for side: int in [-1, 1]:
				_m(v, g, polygon_mesh(heart_poly(0.075), 0.018), fr, Vector3(0.1 * side, 0, -0.005), Vector3(0, 0.3 * side, 0))
				_m(v, g, polygon_mesh(heart_poly(0.055), 0.02), ln, Vector3(0.1 * side, 0.003, 0.0), Vector3(0, 0.3 * side, 0))
			_rod(v, g, Vector3(-0.035, 0.02, 0.0), Vector3(0.035, 0.02, 0.0), 0.008, fr)
			temples(v, fr, 0.02)
		"aviator":
			var tint := v.mat("avi_l", Color(0.35, 0.22, 0.1), 0.05, 0.3)
			for side: int in [-1, 1]:
				_m(v, g, _sph(0.06), tint, Vector3(0.1 * side, -0.01, 0.0), Vector3(0, 0.3 * side, 0), Vector3(1.05, 0.95, 0.18))
				_m(v, g, _torus(0.058, 0.066), gold, Vector3(0.1 * side, -0.01, 0.0), Vector3(PI / 2, 0.3 * side, 0), Vector3(1.05, 1, 0.95))
			_rod(v, g, Vector3(-0.04, 0.03, 0.005), Vector3(0.04, 0.03, 0.005), 0.005, gold)
			temples(v, gold, 0.02)
		"cinema3d":
			var wh := v.mat("3d_f", Color("F4F1EC"), 0.5)
			_m(v, g, _box(Vector3(0.32, 0.09, 0.015)), wh, Vector3(0, 0, -0.015))
			var rl := v.mat("3d_r", Color(0.9, 0.1, 0.15), 0.1)
			var cl := v.mat("3d_c", Color(0.1, 0.8, 0.9), 0.1)
			_m(v, g, _box(Vector3(0.1, 0.06, 0.012)), rl, Vector3(-0.09, 0, -0.003), Vector3(0, -0.3, 0))
			_m(v, g, _box(Vector3(0.1, 0.06, 0.012)), cl, Vector3(0.09, 0, -0.003), Vector3(0, 0.3, 0))
			temples(v, wh, 0.0, 0.16)
		"nerd":
			var bk := v.mat("nerd", Color("141014"), 0.4)
			for side: int in [-1, 1]:
				var c := Vector3(0.1 * side, 0, 0.0)
				var rot := Vector3(0, 0.3 * side, 0)
				var lens := Node3D.new()
				_grp(lens)
				lens.position = c
				lens.rotation = rot
				g.add_child(lens)
				_m(v, lens, _box(Vector3(0.14, 0.022, 0.02)), bk, Vector3(0, 0.045, 0))
				_m(v, lens, _box(Vector3(0.14, 0.02, 0.02)), bk, Vector3(0, -0.045, 0))
				_m(v, lens, _box(Vector3(0.022, 0.11, 0.02)), bk, Vector3(-0.06, 0, 0))
				_m(v, lens, _box(Vector3(0.022, 0.11, 0.02)), bk, Vector3(0.06, 0, 0))
			_m(v, g, _box(Vector3(0.06, 0.018, 0.02)), bk, Vector3(0, 0.03, 0.01))
			temples(v, bk, 0.03)
		"goggles":
			var strap := v.mat("gog_s", Color("2B2B35"), 0.6)
			var lens := v.mat("gog_l", Color("F28A2A"), 0.05, 0.4)
			lens.emission_enabled = true
			lens.emission = Color("F28A2A")
			lens.emission_energy_multiplier = 0.25
			# baş merkezi: çapadan (0, -0.05, -0.285)
			var c := Vector3(0, -0.05, -0.285)
			_m(v, g, _torus(0.29, 0.31), strap, c + Vector3(0, 0.05, 0), Vector3.ZERO, Vector3(1.0, 2.2, 0.97))
			for i in 9:
				var ang := lerpf(-0.85, 0.85, i / 8.0)
				var p := c + Vector3(sin(ang) * 0.305, 0.05, cos(ang) * 0.29)
				_m(v, g, _box(Vector3(0.075, 0.1, 0.02)), lens, p, Vector3(0, ang, 0))
			temples(v, strap, 0.0, 0.2)
		_:
			return false
	return true
