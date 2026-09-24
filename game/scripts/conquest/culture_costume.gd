class_name CultureCostume
extends RefCounted
## Fetih taşları için kültür kostümleri. Web sürümündeki on savaşçı,
## burada pelüş oyuncakların tiyatro kostümleri olarak: keçe, saten, boyalı
## tahta ve pirinç. Yüz her zaman açık kalır; oyuncu rengi kostümün ana rengidir.
##
## Kullanım: CultureCostume.dress(plush_visual, "viking", oyuncu_rengi)
## Yeni kostüm: CULTURES'a ekle, aşağıdaki match'e bir dal yaz.

const CULTURES := ["viking", "centurion", "pharaoh", "samurai", "mariachi",
	"musketeer", "highlander", "janissary", "hussar", "frontier"]

const STEEL := Color("C3CEDC")
const STEEL_D := Color("8D99AA")
const GOLD := Color("E0B040")
const LEATHER := Color("8A5A33")
const WOOD := Color("9A6A3A")
const INK := Color("241C22")

static func _mat(key: String, c: Color, rough := 0.6, metal := 0.0) -> StandardMaterial3D:
	return PlushVisual.mat("cc_" + key + c.to_html(), c, rough, metal)

static func _add(parent: Node3D, mesh: Mesh, mt: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mt
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	mi.add_to_group("costume")
	parent.add_child(mi)
	return mi

static func _cyl(top: float, bot: float, h: float, seg := 18) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bot
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c

static func _sph(r: float, hemi := false) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r if hemi else r * 2.0
	s.is_hemisphere = hemi
	s.radial_segments = 20
	s.rings = 10
	return s

static func _box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b

static func _cap(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.0)
	c.radial_segments = 10
	c.rings = 4
	return c

static func _torus(inner: float, outer: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 24
	t.ring_segments = 8
	return t

## Gövdeyi saran kıyafet (tunik, gömlek, ceket): göbek yamasını da örter
static func _shirt(body: Node3D, mt: Material, y := 0.6, h := 0.44, flare := 0.0) -> MeshInstance3D:
	return _add(body, _cyl(0.323, 0.336 + flare, h, 24), mt, Vector3(0, y, 0))

## Önceki kostümü söker
static func undress(v: PlushVisual) -> void:
	for a in [v.hat_anchor, v.face_anchor, v.neck_anchor, v.body_root, v.arm_l, v.arm_r, v.head_pivot]:
		if a == null:
			continue
		for ch in a.get_children():
			if ch.is_in_group("costume"):
				ch.queue_free()

static func dress(v: PlushVisual, culture: String, accent: Color) -> void:
	undress(v)
	var hat := v.hat_anchor
	var face := v.face_anchor
	var neck := v.neck_anchor
	var body := v.body_root
	var hand_r := Node3D.new()
	hand_r.position = Vector3(0, -0.33, 0.05)
	hand_r.add_to_group("costume")
	v.arm_r.add_child(hand_r)
	var hand_l := Node3D.new()
	hand_l.position = Vector3(0, -0.2, 0.0)
	hand_l.add_to_group("costume")
	v.arm_l.add_child(hand_l)
	var cloth := PlushVisual.felt(accent)
	var cloth_d := PlushVisual.felt(accent.darkened(0.3))
	var steel := _mat("steel", STEEL, 0.32, 0.45)
	var steel_d := _mat("steel_d", STEEL_D, 0.4, 0.45)
	var gold := _mat("gold", GOLD, 0.34, 0.4)
	var leather := _mat("leather", LEATHER, 0.8)
	var wood := _mat("wood", WOOD, 0.85)
	var ink := _mat("ink", INK, 0.5)
	match culture:
		"viking":
			_shirt(body, cloth, 0.55, 0.5, 0.03)
			_add(body, _cyl(0.34, 0.34, 0.05, 24), leather, Vector3(0, 0.42, 0))
			_add(body, _box(0.08, 0.06, 0.02), gold, Vector3(0, 0.42, 0.34))
			_add(hat, _sph(0.27, true), steel, Vector3(0, -0.12, 0), Vector3.ZERO, Vector3(1, 1.05, 1))
			_add(hat, _cyl(0.285, 0.285, 0.05, 24), _mat("bronze", Color("B07A3A"), 0.4, 0.8), Vector3(0, -0.11, 0))
			for s: float in [-1.0, 1.0]:
				_add(hat, _cyl(0.0, 0.055, 0.26, 10), _mat("ivory", Color("F2E8D0"), 0.6), Vector3(0.27 * s, 0.0, 0.0), Vector3(0, 0, -1.05 * s))
				_add(hat, _cyl(0.0, 0.03, 0.1, 8), _mat("ivory", Color("F2E8D0"), 0.6), Vector3(0.37 * s, 0.11, 0.0), Vector3(0, 0, -0.35 * s))
			_add(face, _box(0.035, 0.12, 0.03), steel, Vector3(0, 0.09, 0.02))
			var beard := _mat("ginger", Color("C8612A"), 0.95)
			for k in 3:
				_add(face, _cap(0.026, 0.13), beard, Vector3((k - 1) * 0.05, -0.23, -0.03), Vector3(0.25, 0, (k - 1) * 0.2))
			_add(face, _cap(0.055, 0.19), beard, Vector3(0, -0.14, -0.04), Vector3(0, 0, PI / 2), Vector3(1.0, 1.0, 0.7))
			for s2: float in [-1.0, 1.0]:
				_add(face, _cap(0.022, 0.12), beard, Vector3(0.07 * s2, -0.01, 0.0), Vector3(0, 0, PI / 2 - 0.5 * s2))
			_add(body, _box(0.64, 0.3, 0.06), cloth, Vector3(0, 0.62, -0.28), Vector3(0.15, 0, 0))
			var sh := _add(hand_l, _cyl(0.2, 0.2, 0.03, 20), wood, Vector3(-0.07, 0.02, 0.04), Vector3(0, 0, PI / 2))
			_add(sh, _cyl(0.205, 0.205, 0.02, 20), cloth, Vector3(0, 0.005, 0), Vector3.ZERO, Vector3(1, 1, 1)).scale = Vector3(0.6, 1.1, 0.6)
			_add(sh, _sph(0.05), gold, Vector3(0, 0.02, 0))
			_add(sh, _torus(0.19, 0.215), steel_d, Vector3.ZERO)
			var axe := Node3D.new()
			axe.rotation = Vector3(1.15, 0, 0)
			hand_r.add_child(axe)
			axe.add_to_group("costume")
			_add(axe, _cyl(0.018, 0.018, 0.5, 8), wood, Vector3(0, 0.18, 0))
			var blade := PrismMesh.new()
			blade.size = Vector3(0.18, 0.16, 0.02)
			_add(axe, blade, steel, Vector3(0.06, 0.4, 0), Vector3(0, 0, -PI / 2))
		"centurion":
			_add(hat, _sph(0.27, true), steel, Vector3(0, -0.12, 0), Vector3.ZERO, Vector3(1, 1.05, 1))
			_add(hat, _cyl(0.3, 0.3, 0.03, 24), gold, Vector3(0, -0.11, 0))
			for s: float in [-1.0, 1.0]:
				_add(hat, _box(0.03, 0.18, 0.14), steel, Vector3(0.27 * s, -0.22, 0.08))
			var crest := _mat("crest", Color("B21E2C"), 0.95)
			for k in 7:
				var a := -0.9 + k * 0.3
				_add(hat, _cap(0.035, 0.14), crest, Vector3(0, 0.1 + cos(a) * 0.12, sin(a) * 0.16), Vector3(a, 0, 0))
			_add(body, _box(0.66, 0.7, 0.05), cloth, Vector3(0, 0.5, -0.3), Vector3(0.1, 0, 0))
			# lorika: kumaş rengi göğüslük + deri şeritli etek
			_add(body, _cyl(0.325, 0.335, 0.34, 24), steel_d, Vector3(0, 0.6, 0))
			_add(body, _cyl(0.33, 0.33, 0.04, 24), gold, Vector3(0, 0.42, 0))
			for k in 9:
				var a := -1.2 + k * 0.3
				_add(body, _box(0.07, 0.16, 0.02), leather, Vector3(sin(a) * 0.33, 0.32, cos(a) * 0.33), Vector3(0, a, 0))
			var sc := _add(hand_l, _box(0.05, 0.42, 0.3), cloth, Vector3(-0.09, 0.02, 0.06))
			_add(sc, _box(0.052, 0.44, 0.04), gold, Vector3(0, 0, 0))
			_add(sc, _box(0.052, 0.04, 0.32), gold, Vector3(0, 0, 0))
			var sw := Node3D.new()
			sw.rotation = Vector3(1.2, 0, 0)
			sw.add_to_group("costume")
			hand_r.add_child(sw)
			_add(sw, _box(0.045, 0.3, 0.012), steel, Vector3(0, 0.2, 0))
			_add(sw, _box(0.12, 0.025, 0.04), gold, Vector3(0, 0.05, 0))
		"pharaoh":
			_add(body, _cyl(0.33, 0.38, 0.26, 24), _mat("linen", Color("F4EEDD"), 0.9), Vector3(0, 0.3, 0))
			_add(body, _cyl(0.335, 0.335, 0.05, 24), cloth, Vector3(0, 0.44, 0))
			_add(body, _box(0.1, 0.22, 0.02), cloth, Vector3(0, 0.3, 0.37))
			_shirt(body, _mat("linen", Color("F4EEDD"), 0.9), 0.66, 0.34)
			var blue := _mat("lapis", Color("2A4F9A"), 0.5)
			_add(hat, _sph(0.29, true), gold, Vector3(0, -0.14, 0), Vector3.ZERO, Vector3(1.05, 0.9, 1.05))
			for k in 4:
				_add(hat, _torus(0.27 - k * 0.04, 0.29 - k * 0.04), blue, Vector3(0, -0.12 + k * 0.05, 0), Vector3.ZERO, Vector3(1, 1.5, 1))
			for s: float in [-1.0, 1.0]:
				var lap := _add(hat, _box(0.1, 0.34, 0.08), gold, Vector3(0.27 * s, -0.36, 0.05))
				for k in 4:
					_add(lap, _box(0.102, 0.03, 0.082), blue, Vector3(0, -0.12 + k * 0.08, 0))
			_add(hat, _cap(0.02, 0.1), _mat("cobra", Color("2E9A58"), 0.4), Vector3(0, -0.06, 0.28), Vector3(-0.3, 0, 0))
			_add(face, _cyl(0.025, 0.035, 0.12, 8), gold, Vector3(0, -0.15, -0.02))
			var collar := _add(neck, _cyl(0.3, 0.33, 0.04, 24), gold, Vector3(0, -0.02, -0.2))
			_add(collar, _cyl(0.24, 0.26, 0.045, 24), cloth, Vector3(0, 0.002, 0))
			var crook := Node3D.new()
			crook.rotation = Vector3(0.9, 0, 0)
			crook.add_to_group("costume")
			hand_r.add_child(crook)
			_add(crook, _cyl(0.018, 0.018, 0.5, 8), blue, Vector3(0, 0.2, 0))
			var hook := _add(crook, _torus(0.05, 0.075), gold, Vector3(0.05, 0.47, 0), Vector3(PI / 2, 0, 0))
			hook.scale = Vector3(1, 1, 1)
		"samurai":
			var lacquer := _mat("lacquer", Color("1C1418"), 0.25)
			_add(hat, _sph(0.27, true), lacquer, Vector3(0, -0.12, 0), Vector3.ZERO, Vector3(1, 0.95, 1))
			_add(hat, _cyl(0.29, 0.4, 0.12, 24), lacquer, Vector3(0, -0.22, -0.05), Vector3(-0.15, 0, 0))
			for k in 3:
				_add(hat, _torus(0.3 + k * 0.035, 0.31 + k * 0.035), cloth, Vector3(0, -0.2 - k * 0.035, -0.05), Vector3(-0.15, 0, 0))
			# kuwagata: alından V biçiminde iki altın boynuz
			for s2: float in [-1.0, 1.0]:
				_add(hat, _box(0.035, 0.26, 0.015), gold, Vector3(0.08 * s2, 0.02, 0.26), Vector3(0.15, 0, -0.45 * s2))
			_add(hat, _cyl(0.035, 0.035, 0.02, 12), gold, Vector3(0, -0.08, 0.27), Vector3(PI / 2, 0, 0))
			# dō zırhı: ipek bağlı pul sıraları
			var cuir := _add(body, _cyl(0.325, 0.34, 0.44, 24), cloth, Vector3(0, 0.56, 0))
			for k in 4:
				_add(cuir, _cyl(0.33, 0.345, 0.015, 24), gold if k == 0 else cloth_d, Vector3(0, -0.15 + k * 0.1, 0))
			var kat := Node3D.new()
			kat.rotation = Vector3(0.7, 0, 0.3)
			kat.add_to_group("costume")
			hand_r.add_child(kat)
			_add(kat, _box(0.03, 0.62, 0.012), steel, Vector3(0, 0.38, 0))
			_add(kat, _cyl(0.05, 0.05, 0.015, 12), gold, Vector3(0, 0.07, 0))
			_add(kat, _cyl(0.018, 0.018, 0.14, 8), ink, Vector3(0, -0.01, 0))
		"mariachi":
			_shirt(body, _mat("charro", Color("1E1A1C"), 0.6), 0.58, 0.48, 0.02)
			_add(body, _box(0.14, 0.4, 0.02), _mat("shirt", Color("F2EDE2"), 0.9), Vector3(0, 0.62, 0.325))
			var black := _mat("sombrero", Color("1E1A1C"), 0.6)
			_add(hat, _cyl(0.52, 0.52, 0.03, 32), black, Vector3(0, -0.07, 0))
			_add(hat, _torus(0.5, 0.53), gold, Vector3(0, -0.06, 0))
			_add(hat, _cyl(0.07, 0.19, 0.22, 24), black, Vector3(0, 0.04, 0))
			_add(hat, _sph(0.075), black, Vector3(0, 0.15, 0))
			_add(hat, _cyl(0.195, 0.195, 0.05, 24), gold, Vector3(0, -0.03, 0))
			var hair := _mat("hair", Color("2A1A10"), 0.9)
			for s: float in [-1.0, 1.0]:
				_add(face, _cap(0.026, 0.17), hair, Vector3(0.065 * s, 0, 0.012), Vector3(0, 0, PI / 2 - 0.35 * s))
			_add(neck, _sph(0.06), cloth, Vector3.ZERO, Vector3.ZERO, Vector3(2.4, 0.8, 0.8))
			for s: float in [-1.0, 1.0]:
				for k in 5:
					_add(body, _sph(0.016), gold, Vector3(0.2 * s, 0.4 + k * 0.08, 0.26))
			var gt := Node3D.new()
			gt.position = Vector3(0.02, 0.5, 0.36)
			gt.rotation = Vector3(0.1, 0, -0.9)
			gt.add_to_group("costume")
			body.add_child(gt)
			_add(gt, _cyl(0.15, 0.15, 0.07, 20), wood, Vector3(0, -0.06, 0), Vector3(PI / 2, 0, 0))
			_add(gt, _cyl(0.12, 0.12, 0.07, 20), wood, Vector3(0, 0.12, 0), Vector3(PI / 2, 0, 0))
			_add(gt, _cyl(0.04, 0.04, 0.072, 12), ink, Vector3(0, 0.02, 0), Vector3(PI / 2, 0, 0))
			_add(gt, _box(0.05, 0.36, 0.03), _mat("neck", Color("5A3A20"), 0.7), Vector3(0, 0.38, 0))
		"musketeer":
			_shirt(body, cloth_d, 0.56, 0.5, 0.02)
			var hatm := PlushVisual.felt(accent.darkened(0.15))
			var h := Node3D.new()
			h.rotation = Vector3(0, 0, 0.22)
			h.add_to_group("costume")
			hat.add_child(h)
			_add(h, _cyl(0.34, 0.34, 0.025, 30), hatm, Vector3(0, -0.07, 0))
			_add(h, _cyl(0.16, 0.18, 0.16, 24), hatm, Vector3(0, 0.02, 0))
			var plume := _mat("plume", Color("F7F2E8"), 0.95)
			for k in 3:
				_add(h, _cap(0.045, 0.34), plume, Vector3(-0.1 - k * 0.04, 0.12 + k * 0.03, -0.08 - k * 0.03), Vector3(-0.8 - k * 0.2, 0, 0.9))
			var hair := _mat("hair", Color("2A1A10"), 0.9)
			for s: float in [-1.0, 1.0]:
				_add(face, _cap(0.018, 0.12), hair, Vector3(0.06 * s, 0, 0.012), Vector3(0, 0, PI / 2 - 0.4 * s))
				_add(face, _sph(0.02), hair, Vector3(0.12 * s, 0.03, 0.0))
			_add(face, _cap(0.015, 0.06), hair, Vector3(0, -0.1, 0.0))
			_add(body, _box(0.36, 0.5, 0.03), cloth, Vector3(0, 0.55, 0.335))
			_add(body, _box(0.06, 0.34, 0.035), _mat("cross", Color("F5F0E4"), 0.8), Vector3(0, 0.58, 0.345))
			_add(body, _box(0.24, 0.06, 0.035), _mat("cross", Color("F5F0E4"), 0.8), Vector3(0, 0.63, 0.345))
			var rp := Node3D.new()
			rp.rotation = Vector3(1.1, 0, 0)
			rp.add_to_group("costume")
			hand_r.add_child(rp)
			_add(rp, _cyl(0.008, 0.012, 0.66, 6), steel, Vector3(0, 0.38, 0))
			_add(rp, _sph(0.06, true), gold, Vector3(0, 0.05, 0))
		"highlander":
			_shirt(body, _mat("shirt", Color("F2EDE2"), 0.9), 0.66, 0.34)
			var tartan := accent
			_add(hat, _sph(0.26), PlushVisual.felt(Color("233A5E")), Vector3(0.03, -0.04, 0), Vector3(0, 0, 0.18), Vector3(1.1, 0.35, 1.1))
			_add(hat, _torus(0.24, 0.27), PlushVisual.felt(tartan), Vector3(0, -0.08, 0))
			_add(hat, _sph(0.055), _mat("pom", Color("C8242E"), 1.0), Vector3(0.06, 0.05, 0))
			var ginger := _mat("ginger", Color("C8612A"), 0.95)
			_add(face, _cap(0.06, 0.2), ginger, Vector3(0, -0.14, -0.04), Vector3(0, 0, PI / 2), Vector3(1.0, 1.0, 0.7))
			for s2: float in [-1.0, 1.0]:
				_add(face, _cap(0.02, 0.11), ginger, Vector3(0.065 * s2, -0.01, 0.0), Vector3(0, 0, PI / 2 - 0.35 * s2))
			var kilt := _add(body, _cyl(0.33, 0.38, 0.24, 24), PlushVisual.felt(tartan), Vector3(0, 0.3, 0))
			for k in 3:
				_add(kilt, _cyl(0.335 + k * 0.016, 0.34 + k * 0.016, 0.018, 24), PlushVisual.felt(tartan.darkened(0.45)), Vector3(0, -0.08 + k * 0.08, 0))
			_add(body, _box(0.07, 0.72, 0.05), PlushVisual.felt(tartan), Vector3(0.14, 0.62, 0.26), Vector3(0, 0, 0.55))
			_add(body, _box(0.12, 0.14, 0.06), leather, Vector3(0, 0.22, 0.33))
			var cl := Node3D.new()
			cl.rotation = Vector3(0.4, 0, 0)
			cl.add_to_group("costume")
			hand_r.add_child(cl)
			_add(cl, _box(0.05, 0.8, 0.012), steel, Vector3(0, 0.5, 0))
			_add(cl, _box(0.24, 0.03, 0.04), steel_d, Vector3(0, 0.08, 0))
			_add(cl, _cyl(0.02, 0.02, 0.16, 8), leather, Vector3(0, -0.02, 0))
		"janissary":
			_shirt(body, cloth, 0.62, 0.4)
			var white := PlushVisual.felt(Color("F4EFE4"))
			_add(hat, _cyl(0.2, 0.2, 0.08, 22), gold, Vector3(0, -0.04, -0.02))
			_add(hat, _cyl(0.13, 0.19, 0.3, 22), white, Vector3(0, 0.14, -0.04), Vector3(-0.12, 0, 0))
			# yatırılmış yen (börkün arkaya sarkan kısmı)
			_add(hat, _cap(0.1, 0.46), white, Vector3(0, 0.2, -0.26), Vector3(1.15, 0, 0))
			_add(hat, _box(0.06, 0.16, 0.03), gold, Vector3(0, 0.06, 0.2), Vector3(-0.12, 0, 0))
			_add(hat, _sph(0.03), _mat("ruby", Color("C2183A"), 0.2), Vector3(0, 0.02, 0.22))
			var hair := _mat("hair", Color("2A1A10"), 0.9)
			for s: float in [-1.0, 1.0]:
				_add(face, _cap(0.024, 0.2), hair, Vector3(0.08 * s, -0.05, 0.012), Vector3(0, 0, 0.35 * s))
			var coat := _add(body, _cyl(0.33, 0.39, 0.3, 24), cloth, Vector3(0, 0.28, 0))
			_add(coat, _box(0.05, 0.3, 0.02), gold, Vector3(0, 0, 0.37))
			for s2: float in [-1.0, 1.0]:
				_add(body, _box(0.12, 0.42, 0.03), cloth, Vector3(0.2 * s2, 0.6, 0.25), Vector3(0, -0.55 * s2, 0))
			_add(body, _cyl(0.335, 0.335, 0.07, 24), _mat("sash", Color("B21E2C"), 0.8), Vector3(0, 0.46, 0))
			var yt := Node3D.new()
			yt.rotation = Vector3(1.1, 0, 0)
			yt.add_to_group("costume")
			hand_r.add_child(yt)
			for k in 4:
				_add(yt, _box(0.04, 0.12, 0.01), steel, Vector3(-0.01 * k * k, 0.1 + k * 0.1, 0), Vector3(0, 0, 0.12 * k))
			_add(yt, _cyl(0.018, 0.018, 0.12, 8), _mat("ivory", Color("F2E8D0"), 0.6), Vector3(0, -0.02, 0))
		"hussar":
			_shirt(body, cloth_d, 0.58, 0.46)
			var fur := _mat("fur", Color("2A2024"), 1.0)
			_add(hat, _cyl(0.17, 0.2, 0.28, 22), fur, Vector3(0, 0.07, 0))
			_add(hat, _cap(0.03, 0.24), _mat("plume", Color("F7F2E8"), 0.95), Vector3(0.1, 0.3, 0.02), Vector3(0, 0, -0.3))
			_add(hat, _torus(0.19, 0.21), gold, Vector3(0, -0.02, 0))
			var hair := _mat("hair", Color("2A1A10"), 0.9)
			for s: float in [-1.0, 1.0]:
				_add(face, _cap(0.022, 0.16), hair, Vector3(0.065 * s, 0, 0.012), Vector3(0, 0, PI / 2 - 0.2 * s))
			_add(body, _box(0.4, 0.44, 0.03), cloth, Vector3(0, 0.58, 0.33))
			for k in 5:
				_add(body, _cyl(0.008, 0.008, 0.34, 6), gold, Vector3(0, 0.42 + k * 0.08, 0.35), Vector3(0, 0, PI / 2))
				_add(body, _sph(0.014), gold, Vector3(0.17, 0.42 + k * 0.08, 0.35))
				_add(body, _sph(0.014), gold, Vector3(-0.17, 0.42 + k * 0.08, 0.35))
			_add(body, _box(0.66, 0.66, 0.05), cloth, Vector3(0, 0.52, -0.28), Vector3(0.12, 0, 0))
			# kanatlar: sırtta tahta çerçeveye dizili tüyler
			var frame := _mat("wingframe", Color("6A3A1E"), 0.6)
			var feather := _mat("feather", Color("FBF7EE"), 0.95)
			for s: float in [-1.0, 1.0]:
				var w := Node3D.new()
				w.position = Vector3(0.18 * s, 0.7, -0.34)
				w.rotation = Vector3(-0.15, 0, -0.18 * s)
				w.add_to_group("costume")
				body.add_child(w)
				for k in 8:
					var a := -0.3 + k * 0.16
					var p := Vector3(sin(a) * 0.12 * s, 0.1 + k * 0.1, -0.04 * k * 0.3)
					_add(w, _cap(0.03, 0.2), feather, p + Vector3(0.05 * s, 0, 0), Vector3(0, 0, -0.9 * s))
				_add(w, _cyl(0.02, 0.02, 0.9, 8), frame, Vector3(0.0, 0.45, 0), Vector3(0, 0, 0.08 * s))
			var ln := Node3D.new()
			ln.rotation = Vector3(0.25, 0, 0)
			ln.add_to_group("costume")
			hand_r.add_child(ln)
			_add(ln, _cyl(0.014, 0.018, 1.3, 8), wood, Vector3(0, 0.45, 0))
			_add(ln, _cyl(0.0, 0.03, 0.1, 8), steel, Vector3(0, 1.14, 0))
			var pen := PrismMesh.new()
			pen.size = Vector3(0.22, 0.12, 0.01)
			_add(ln, pen, PlushVisual.felt(accent), Vector3(0.1, 0.98, 0), Vector3(0, 0, -PI / 2))
		"frontier":
			var tan := PlushVisual.felt(Color("9A6B3E"))
			var brim := _add(hat, _cyl(0.38, 0.38, 0.025, 30), tan, Vector3(0, -0.07, 0), Vector3.ZERO, Vector3(1.0, 1.0, 0.9))
			for s: float in [-1.0, 1.0]:
				_add(hat, _cyl(0.14, 0.14, 0.025, 20), tan, Vector3(0.3 * s, -0.02, 0), Vector3(0, 0, 0.7 * s), Vector3(1, 1, 1.8))
			_add(hat, _cyl(0.15, 0.18, 0.2, 22), tan, Vector3(0, 0.04, 0))
			_add(hat, _cyl(0.185, 0.185, 0.035, 22), leather, Vector3(0, -0.03, 0))
			var bandana := PrismMesh.new()
			bandana.size = Vector3(0.3, 0.18, 0.04)
			_add(neck, bandana, cloth, Vector3(0, -0.06, 0.02), Vector3(0, 0, PI))
			var vest := _add(body, _cyl(0.325, 0.335, 0.42, 24), leather, Vector3(0, 0.6, 0))
			_add(vest, _box(0.13, 0.42, 0.03), cloth, Vector3(0, 0, 0.32))
			var star := _add(body, _cyl(0.05, 0.05, 0.015, 5), gold, Vector3(-0.19, 0.7, 0.29), Vector3(PI / 2, 0, 0))
			star.name = "Star"
			var rope := _mat("rope", Color("C9A46A"), 0.95)
			var ls := Node3D.new()
			ls.rotation = Vector3(0.9, 0, 0)
			ls.add_to_group("costume")
			hand_r.add_child(ls)
			_add(ls, _torus(0.12, 0.145), rope, Vector3(0, 0.12, 0), Vector3(0, 0, PI / 2))
			_add(ls, _torus(0.1, 0.125), rope, Vector3(0.02, 0.12, 0), Vector3(0, 0.3, PI / 2))
