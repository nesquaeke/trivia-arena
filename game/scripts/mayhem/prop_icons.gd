class_name PropIcons
extends RefCounted
## Mayhem'in oyuncak nesneleri: Zoom Panic'te aşırı yakından gösterilir,
## Memory Panic'te kapakların üstünde döner. Hepsi ilkel şekillerden, parlak
## plastik oyuncak hissiyle. Yeni nesne: NAMES'e ad, build()'e bir dal.

## [tr, en, pl, fr, es]
const NAMES := {
	"apple": ["Elma", "Apple", "Jabłko", "Pomme", "Manzana"],
	"banana": ["Muz", "Banana", "Banan", "Banane", "Plátano"],
	"duck": ["Lastik ördek", "Rubber duck", "Gumowa kaczka", "Canard en caoutchouc", "Patito de goma"],
	"cake": ["Doğum günü pastası", "Birthday cake", "Tort urodzinowy", "Gâteau d'anniversaire", "Tarta de cumpleaños"],
	"bell": ["Zil", "Bell", "Dzwonek", "Cloche", "Campana"],
	"gift": ["Hediye kutusu", "Gift box", "Pudełko z prezentem", "Boîte cadeau", "Caja de regalo"],
	"ball": ["Futbol topu", "Football", "Piłka nożna", "Ballon de foot", "Balón de fútbol"],
	"cactus": ["Kaktüs", "Cactus", "Kaktus", "Cactus", "Cactus"],
	"fish": ["Japon balığı", "Goldfish", "Złota rybka", "Poisson rouge", "Pez dorado"],
	"umbrella": ["Şemsiye", "Umbrella", "Parasol", "Parapluie", "Paraguas"],
	"rocket": ["Roket", "Rocket", "Rakieta", "Fusée", "Cohete"],
	"donut": ["Donut", "Doughnut", "Pączek", "Beignet", "Dónut"],
	"mushroom": ["Mantar", "Mushroom", "Grzyb", "Champignon", "Seta"],
	"snowman": ["Kardan adam", "Snowman", "Bałwan", "Bonhomme de neige", "Muñeco de nieve"],
	"icecream": ["Dondurma", "Ice cream", "Lody", "Glace", "Helado"],
	"lollipop": ["Lolipop", "Lollipop", "Lizak", "Sucette", "Piruleta"],
	"teapot": ["Çaydanlık", "Teapot", "Czajniczek", "Théière", "Tetera"],
	"dice": ["Zar", "Die", "Kostka do gry", "Dé", "Dado"],
}
const LANG_IDX := {"tr": 0, "en": 1, "pl": 2, "fr": 3, "es": 4}

static var _mats := {}

static func ids() -> Array:
	return NAMES.keys()

static func name_of(id: String, lang: String) -> String:
	var row: Array = NAMES.get(id, [id, id])
	var i: int = LANG_IDX.get(lang, 1)
	return String(row[i] if i < row.size() else row[1])

static func mat(c: Color, rough := 0.32, metal := 0.0, emit := 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%.2f" % [c.to_html(), rough, metal, emit]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	m.clearcoat_enabled = rough < 0.5
	m.clearcoat = 0.4
	m.rim_enabled = true
	m.rim = 0.25
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	_mats[key] = m
	return m

static func _mi(parent: Node3D, mesh: Mesh, m: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = m
	n.position = pos
	n.rotation = rot
	n.scale = scl
	parent.add_child(n)
	return n

static func _sph(r: float, h := -1.0) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0 if h < 0 else h
	s.radial_segments = 32
	s.rings = 16
	return s

static func _hemi(r: float) -> SphereMesh:
	var s := _sph(r)
	s.is_hemisphere = true
	s.height = r
	return s

static func _cyl(rt: float, rb: float, h: float, seg := 28) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = rt
	c.bottom_radius = rb
	c.height = h
	c.radial_segments = seg
	return c

static func _box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b

static func _torus(inner: float, outer: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 32
	t.ring_segments = 16
	return t

static func _cap(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	return c

## Yaklaşık 1 birim yüksekliğinde, tabanı y=0'da bir nesne
static func build(id: String) -> Node3D:
	var n := Node3D.new()
	n.name = "Icon_" + id
	var ink := mat(Color("1B1210"), 0.4)
	var white := mat(Color("F7F1E6"))
	match id:
		"apple":
			_mi(n, _sph(0.42), mat(Color("D8262E")), Vector3(0, 0.42, 0), Vector3.ZERO, Vector3(1.05, 0.92, 1.05))
			_mi(n, _cyl(0.025, 0.035, 0.22), mat(Color("5A3A1E"), 0.7), Vector3(0.02, 0.86, 0), Vector3(0, 0, -0.2))
			_mi(n, _sph(0.12), mat(Color("4FA83A")), Vector3(0.14, 0.9, 0), Vector3(0, 0, 0.6), Vector3(1.4, 0.35, 0.8))
		"banana":
			var ym := mat(Color("F5D23A"))
			for i in 7:
				var a := lerpf(-1.05, 1.05, i / 6.0)
				var p := Vector3(sin(a) * 0.55, 0.62 - cos(a) * 0.45, 0)
				_mi(n, _sph(0.14 - abs(a) * 0.035), ym, p, Vector3(0, 0, a), Vector3(1.4, 1, 1))
			_mi(n, _cyl(0.03, 0.04, 0.1), mat(Color("5A3A1E"), 0.7), Vector3(-0.49, 0.42, 0), Vector3(0, 0, 0.9))
			_mi(n, _sph(0.045), mat(Color("3A2616"), 0.7), Vector3(0.5, 0.4, 0))
		"duck":
			var y := mat(Color("FFD42A"))
			_mi(n, _sph(0.36), y, Vector3(0, 0.3, 0), Vector3.ZERO, Vector3(1.25, 0.85, 1.0))
			_mi(n, _sph(0.14), y, Vector3(-0.38, 0.38, 0), Vector3(0, 0, 0.5), Vector3(1.2, 0.7, 0.9))
			_mi(n, _sph(0.22), y, Vector3(0.24, 0.72, 0))
			_mi(n, _sph(0.1), mat(Color("F07A1A")), Vector3(0.46, 0.68, 0), Vector3.ZERO, Vector3(1.4, 0.45, 1.0))
			_mi(n, _sph(0.035), ink, Vector3(0.36, 0.8, 0.12))
			_mi(n, _sph(0.035), ink, Vector3(0.36, 0.8, -0.12))
		"cake":
			_mi(n, _cyl(0.46, 0.48, 0.3), mat(Color("F2A5C0")), Vector3(0, 0.15, 0))
			_mi(n, _cyl(0.47, 0.47, 0.06), white, Vector3(0, 0.3, 0))
			_mi(n, _cyl(0.34, 0.36, 0.24), mat(Color("8A4A2A")), Vector3(0, 0.44, 0))
			_mi(n, _cyl(0.35, 0.35, 0.05), white, Vector3(0, 0.57, 0))
			for i in 8:
				var a := i * TAU / 8.0
				_mi(n, _sph(0.045), mat(Color("D8262E")), Vector3(cos(a) * 0.3, 0.62, sin(a) * 0.3))
			_mi(n, _cyl(0.03, 0.03, 0.22), mat(Color("5BB0E8")), Vector3(0, 0.71, 0))
			_mi(n, _sph(0.05), mat(Color("FFB43A"), 0.3, 0.0, 3.0), Vector3(0, 0.87, 0), Vector3.ZERO, Vector3(0.7, 1.4, 0.7))
		"bell":
			var gold := mat(Color("E7B53C"), 0.22, 0.85)
			_mi(n, _cyl(0.16, 0.44, 0.6), gold, Vector3(0, 0.38, 0))
			_mi(n, _hemi(0.16), gold, Vector3(0, 0.68, 0))
			_mi(n, _torus(0.44, 0.5), gold, Vector3(0, 0.08, 0))
			_mi(n, _torus(0.04, 0.09), gold, Vector3(0, 0.86, 0), Vector3(PI / 2, 0, 0))
			_mi(n, _sph(0.08), mat(Color("8A6A2A"), 0.4, 0.6), Vector3(0.05, 0.05, 0))
		"gift":
			_mi(n, _box(Vector3(0.7, 0.55, 0.7)), mat(Color("C8303A")), Vector3(0, 0.28, 0))
			var rib := mat(Color("F5D23A"))
			_mi(n, _box(Vector3(0.72, 0.57, 0.14)), rib, Vector3(0, 0.28, 0))
			_mi(n, _box(Vector3(0.14, 0.57, 0.72)), rib, Vector3(0, 0.28, 0))
			_mi(n, _torus(0.05, 0.13), rib, Vector3(-0.1, 0.64, 0), Vector3(0, 0, 1.2))
			_mi(n, _torus(0.05, 0.13), rib, Vector3(0.1, 0.64, 0), Vector3(0, 0, -1.2))
		"ball":
			_mi(n, _sph(0.45), white, Vector3(0, 0.45, 0))
			var dots := [Vector3(0, 1, 0), Vector3(0.9, 0.3, 0.3), Vector3(-0.8, 0.3, 0.5), Vector3(0.2, 0.2, 0.95),
				Vector3(-0.3, -0.2, -0.9), Vector3(0.6, -0.5, -0.6), Vector3(-0.6, -0.6, 0.4), Vector3(0.1, -1, 0)]
			for d in dots:
				_mi(n, _sph(0.14), ink, Vector3(0, 0.45, 0) + (d as Vector3).normalized() * 0.37, Vector3.ZERO, Vector3(1, 1, 1))
		"cactus":
			_mi(n, _cyl(0.26, 0.2, 0.26), mat(Color("C4663A"), 0.7), Vector3(0, 0.13, 0))
			var g := mat(Color("3E9A48"), 0.5)
			_mi(n, _cap(0.14, 0.72), g, Vector3(0, 0.6, 0))
			_mi(n, _cap(0.08, 0.32), g, Vector3(0.2, 0.62, 0), Vector3(0, 0, -0.1))
			_mi(n, _cap(0.07, 0.26), g, Vector3(-0.19, 0.72, 0), Vector3(0, 0, 0.15))
			_mi(n, _sph(0.06), mat(Color("F07AB0")), Vector3(0, 0.98, 0))
		"fish":
			var o := mat(Color("F4822A"))
			_mi(n, _sph(0.3), o, Vector3(0, 0.45, 0), Vector3.ZERO, Vector3(1.4, 1.0, 0.55))
			_mi(n, _sph(0.2), o, Vector3(-0.5, 0.45, 0), Vector3(0, 0, 0.0), Vector3(0.5, 1.2, 0.2))
			_mi(n, _sph(0.12), o, Vector3(0.0, 0.76, 0), Vector3.ZERO, Vector3(1.4, 0.5, 0.2))
			_mi(n, _sph(0.06), white, Vector3(0.28, 0.52, 0.13))
			_mi(n, _sph(0.035), ink, Vector3(0.3, 0.52, 0.17))
		"umbrella":
			var cols := [Color("D8262E"), Color("F7F1E6")]
			for i in 8:
				var seg := _mi(n, _hemi(0.55), mat(cols[i % 2]), Vector3(0, 0.62, 0))
				seg.scale = Vector3(1, 0.55, 1)
				seg.rotation.y = i * TAU / 8.0
			_mi(n, _cyl(0.02, 0.02, 0.62), mat(Color("3A2616"), 0.5), Vector3(0, 0.31, 0))
			_mi(n, _torus(0.07, 0.11), mat(Color("3A2616"), 0.5), Vector3(0.09, 0.02, 0), Vector3(PI / 2, 0, 0))
		"rocket":
			_mi(n, _cyl(0.2, 0.22, 0.62), white, Vector3(0, 0.42, 0))
			_mi(n, _cyl(0.0, 0.2, 0.3), mat(Color("D8262E")), Vector3(0, 0.88, 0))
			_mi(n, _sph(0.08), mat(Color("5BB0E8"), 0.15, 0.3), Vector3(0, 0.55, 0.18), Vector3.ZERO, Vector3(1, 1, 0.5))
			for i in 3:
				var fin := _mi(n, _box(Vector3(0.04, 0.26, 0.2)), mat(Color("D8262E")), Vector3.ZERO)
				var a := i * TAU / 3.0
				fin.position = Vector3(cos(a) * 0.24, 0.16, sin(a) * 0.24)
				fin.rotation.y = -a
			_mi(n, _sph(0.12), mat(Color("FFB43A"), 0.3, 0.0, 3.0), Vector3(0, 0.02, 0), Vector3.ZERO, Vector3(1, 1.6, 1))
		"donut":
			_mi(n, _torus(0.14, 0.44), mat(Color("C88A4A"), 0.6), Vector3(0, 0.16, 0))
			_mi(n, _torus(0.16, 0.42), mat(Color("F07AB0")), Vector3(0, 0.22, 0), Vector3.ZERO, Vector3(1, 0.6, 1))
			var sprinkles := [Color("5BB0E8"), Color("F5D23A"), Color("4FA83A"), Color("F7F1E6")]
			for i in 18:
				var a := i * TAU / 18.0 + 0.2
				var r := 0.29 + (i % 3) * 0.035
				_mi(n, _cap(0.012, 0.07), mat(sprinkles[i % 4]), Vector3(cos(a) * r, 0.3, sin(a) * r), Vector3(PI / 2, a * 1.7, 0))
		"mushroom":
			_mi(n, _cyl(0.13, 0.16, 0.42), white, Vector3(0, 0.21, 0))
			var cap := _mi(n, _hemi(0.42), mat(Color("D8262E")), Vector3(0, 0.4, 0))
			cap.scale = Vector3(1, 0.8, 1)
			for d in [Vector3(0, 1, 0), Vector3(0.7, 0.5, 0.2), Vector3(-0.5, 0.55, 0.6), Vector3(0.1, 0.5, -0.8), Vector3(-0.6, 0.5, -0.4), Vector3(0.4, 0.45, 0.75)]:
				var v: Vector3 = (d as Vector3).normalized()
				_mi(n, _sph(0.06), white, Vector3(0, 0.4, 0) + Vector3(v.x * 0.4, v.y * 0.32, v.z * 0.4), Vector3.ZERO, Vector3(1, 0.5, 1))
		"snowman":
			var snow := mat(Color("F4F7FA"), 0.6)
			_mi(n, _sph(0.3), snow, Vector3(0, 0.28, 0))
			_mi(n, _sph(0.22), snow, Vector3(0, 0.68, 0))
			_mi(n, _sph(0.16), snow, Vector3(0, 0.98, 0))
			_mi(n, _cyl(0.0, 0.035, 0.18), mat(Color("F07A1A")), Vector3(0, 0.98, 0.22), Vector3(PI / 2, 0, 0))
			_mi(n, _sph(0.025), ink, Vector3(0.06, 1.03, 0.14))
			_mi(n, _sph(0.025), ink, Vector3(-0.06, 1.03, 0.14))
			_mi(n, _cyl(0.1, 0.1, 0.16), ink, Vector3(0, 1.2, 0))
			_mi(n, _cyl(0.17, 0.17, 0.02), ink, Vector3(0, 1.12, 0))
			_mi(n, _torus(0.2, 0.26), mat(Color("D8262E")), Vector3(0, 0.84, 0), Vector3.ZERO, Vector3(1, 0.5, 1))
		"icecream":
			_mi(n, _cyl(0.2, 0.0, 0.55), mat(Color("D9A15A"), 0.6), Vector3(0, 0.275, 0))
			_mi(n, _sph(0.2), mat(Color("F3B6C8")), Vector3(0, 0.62, 0))
			_mi(n, _sph(0.17), mat(Color("F5ECD6")), Vector3(0, 0.84, 0))
			_mi(n, _sph(0.06), mat(Color("D8262E")), Vector3(0, 1.02, 0))
		"lollipop":
			_mi(n, _cyl(0.02, 0.02, 0.6), white, Vector3(0, 0.3, 0))
			var cols2 := [Color("F07AB0"), Color("F7F1E6")]
			for i in 5:
				_mi(n, _torus(0.02 + i * 0.06, 0.08 + i * 0.06), mat(cols2[i % 2]), Vector3(0, 0.82, 0), Vector3(PI / 2, 0, 0), Vector3(1, 1, 0.6))
		"teapot":
			var tp := mat(Color("3E78B8"))
			_mi(n, _sph(0.34), tp, Vector3(0, 0.34, 0), Vector3.ZERO, Vector3(1.15, 0.9, 1.15))
			_mi(n, _cyl(0.04, 0.07, 0.4), tp, Vector3(0.42, 0.4, 0), Vector3(0, 0, -0.9))
			_mi(n, _torus(0.05, 0.15), tp, Vector3(-0.4, 0.38, 0), Vector3(PI / 2, 0, 0))
			_mi(n, _cyl(0.14, 0.18, 0.06), tp, Vector3(0, 0.66, 0))
			_mi(n, _sph(0.05), white, Vector3(0, 0.72, 0))
		"dice":
			var die := _mi(n, _box(Vector3(0.6, 0.6, 0.6)), white, Vector3(0, 0.3, 0))
			die.rotation = Vector3(0.0, 0.3, 0.0)
			for p in [Vector3(0, 0.301, 0), Vector3(0.301, 0.12, 0.12), Vector3(0.301, -0.12, -0.12), Vector3(0.12, 0.12, 0.301), Vector3(0, 0, 0.301), Vector3(-0.12, -0.12, 0.301)]:
				var q: Vector3 = p
				var s := Vector3(1, 0.3, 1) if abs(q.y) > 0.3 else (Vector3(0.3, 1, 1) if abs(q.x) > 0.3 else Vector3(1, 1, 0.3))
				_mi(die, _sph(0.055), ink, q, Vector3.ZERO, s)
		_:
			_mi(n, _box(Vector3(0.6, 0.6, 0.6)), mat(Color("B8893B")), Vector3(0, 0.3, 0))
	return n
