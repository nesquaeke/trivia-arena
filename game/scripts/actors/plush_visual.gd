class_name PlushVisual
extends Node3D
## Pelüş bez bebek görünümü: keçe gövde, düğme gözler, dikişli gülüş,
## kostümler (şapka / bıyık / papyon / kumaş rengi) ve fizik durumuna göre
## prosedürel animasyon (yürüyüş, esneme-sıkışma, kafa yayı, çırpınma).
## Ayaklar y=0'da, yüz +Z yönüne bakar.

const COLORS := {
	"mustard": Color("F2C230"), "butter": Color("F6DD7C"), "tangerine": Color("EE8A33"),
	"rose": Color("E77C95"), "mint": Color("7ACFAE"), "sky": Color("77B3E6"),
	"lilac": Color("B49BE0"), "charcoal": Color("4B4553"),
	"cherry": Color("C9303C"), "navy": Color("33508F"), "forest": Color("3F7D4E"), "plum": Color("7A3E6E"),
	"coral": Color("F07B5B"), "snow": Color("EFEDE6"), "cocoa": Color("7B4B32"), "gold": Color("E1B23E"),
	"teddy": Color("CFA877"),
}
const COLOR_KEYS := ["mustard", "butter", "tangerine", "rose", "mint", "sky", "lilac", "charcoal",
	"cherry", "navy", "forest", "plum", "coral", "snow", "cocoa", "gold"]
## Oyuncu rengi olarak seçilebilenler (ilk 8'i herkese açık, diğerleri Sahne Rütbesi ile)
const HATS := ["none", "tophat", "bowler", "fez", "boater", "crown", "cone",
	"beret", "party", "tricorn", "wizard", "chef", "jester", "cowboy", "propeller", "flowers", "laurel"]
const MUSTACHES := ["none", "handlebar", "chevron", "pencil", "walrus", "imperial", "goatee", "horseshoe", "curly", "beard"]
const BOWTIES := ["none", "classic", "dotted", "big", "scarf", "medal", "pearls", "ascot", "rose", "bell"]
const GLASSES := ["none", "round", "monocle", "star", "shades", "domino", "eyepatch"]

static var _felt_normal: NoiseTexture2D
static var _mats := {}

var look := {}
var culture := ""              ## Fetih kostümü (boşsa Trivia kostümü: şapka/bıyık/papyon)
var costume_color = null       ## kostümün rengi (boşsa gövde renginin koyusu)
var body_root: Node3D
var head_pivot: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var hat_anchor: Node3D
var face_anchor: Node3D
var neck_anchor: Node3D
var glasses_anchor: Node3D
var eyes: Array[Node3D] = []
var felt_parts: Array[MeshInstance3D] = []

var _t := 0.0
var _walk := 0.0
var _squash := 0.0
var _squash_v := 0.0
var _head := Vector2.ZERO
var _head_v := Vector2.ZERO
var _prev_vel := Vector3.ZERO
var _punch := 0.0
var _blink := 2.0
var _was_grounded := true
var wobble := 0.0

# ── malzemeler ──────────────────────────────────────────────────────
static func felt_normal() -> NoiseTexture2D:
	if _felt_normal == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_CELLULAR
		n.frequency = 0.09
		_felt_normal = NoiseTexture2D.new()
		_felt_normal.width = 256
		_felt_normal.height = 256
		_felt_normal.seamless = true
		_felt_normal.as_normal_map = true
		_felt_normal.bump_strength = 3.0
		_felt_normal.noise = n
	return _felt_normal

static func felt(c: Color) -> StandardMaterial3D:
	var key := "felt" + c.to_html()
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	m.normal_enabled = true
	m.normal_texture = felt_normal()
	m.normal_scale = 0.45
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(4, 4, 4)
	m.rim_enabled = true
	m.rim = 0.4
	m.rim_tint = 0.55
	# kumaş tüyü: ışığın arkasından hafif sızma
	m.backlight_enabled = true
	m.backlight = c.darkened(0.55)
	_mats[key] = m
	return m

static func mat(key: String, c: Color, rough := 0.6, metal := 0.0) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	_mats[key] = m
	return m

# ── kurulum ─────────────────────────────────────────────────────────
func _init(p_look: Dictionary = {}) -> void:
	look = p_look.duplicate()

func _ready() -> void:
	_build()
	apply_look(look)

func _mesh(parent: Node3D, mesh: Mesh, m: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi

func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 20
	c.rings = 6
	return c

func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 24
	s.rings = 12
	return s

func _cyl(top: float, bottom: float, h: float, seg := 20) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c

func _build() -> void:
	var base := felt(Color.WHITE)   # yer tutucu; apply_look renkler
	var thread := mat("thread", Color("1B100A"), 0.7)
	var button := mat("button", Color("0F0908"), 0.08)
	var shine := mat("shine", Color(1, 1, 1), 0.2)
	var cheek := mat("cheek", Color("F08C8C"), 1.0)

	body_root = Node3D.new()
	add_child(body_root)

	# bacaklar
	for side: int in [-1, 1]:
		var hip := Node3D.new()
		hip.position = Vector3(0.13 * side, 0.31, 0.0)
		body_root.add_child(hip)
		felt_parts.append(_mesh(hip, _capsule(0.095, 0.36), base, Vector3(0, -0.15, 0)))
		_mesh(hip, _sphere(0.1), mat("shoe", Color("3A2418"), 0.55), Vector3(0, -0.29, 0.04), Vector3.ZERO, Vector3(1.0, 0.6, 1.35))
		if side < 0:
			leg_l = hip
		else:
			leg_r = hip

	# gövde
	felt_parts.append(_mesh(body_root, _capsule(0.31, 0.76), base, Vector3(0, 0.57, 0)))
	# karın yaması + dikişler
	var belly := _mesh(body_root, _sphere(0.17), felt(Color("FFF3D6")), Vector3(0, 0.52, 0.2), Vector3.ZERO, Vector3(1.0, 1.15, 0.45))
	belly.name = "Belly"
	for i in 8:
		var a := TAU * i / 8.0
		_mesh(body_root, _capsule(0.008, 0.035), thread, Vector3(cos(a) * 0.16, 0.52 + sin(a) * 0.19, 0.265), Vector3(0, 0, a + PI / 2))
	_mesh(body_root, _cyl(0.028, 0.028, 0.02, 12), mat("btn2", Color("7A1F24"), 0.3), Vector3(0, 0.6, 0.29), Vector3(PI / 2, 0, 0))
	_mesh(body_root, _cyl(0.028, 0.028, 0.02, 12), mat("btn2", Color("7A1F24"), 0.3), Vector3(0, 0.47, 0.285), Vector3(PI / 2, 0, 0))

	# kollar
	for side: int in [-1, 1]:
		var sh := Node3D.new()
		sh.position = Vector3(0.3 * side, 0.77, 0.0)
		sh.rotation.z = 0.28 * side
		body_root.add_child(sh)
		felt_parts.append(_mesh(sh, _capsule(0.075, 0.36), base, Vector3(0, -0.15, 0)))
		felt_parts.append(_mesh(sh, _sphere(0.085), base, Vector3(0, -0.31, 0.01)))
		if side < 0:
			arm_l = sh
		else:
			arm_r = sh

	# baş
	head_pivot = Node3D.new()
	head_pivot.position = Vector3(0, 0.9, 0)
	body_root.add_child(head_pivot)
	felt_parts.append(_mesh(head_pivot, _sphere(0.3), base, Vector3(0, 0.14, 0), Vector3.ZERO, Vector3(1.0, 0.94, 0.95)))
	# kulaklar (oyuncak ayı gibi yuvarlak)
	for side: int in [-1, 1]:
		felt_parts.append(_mesh(head_pivot, _sphere(0.085), base, Vector3(0.21 * side, 0.36, -0.02), Vector3.ZERO, Vector3(1, 1, 0.6)))
		_mesh(head_pivot, _sphere(0.05), felt(Color("FFF3D6")), Vector3(0.21 * side, 0.36, 0.03), Vector3.ZERO, Vector3(1, 1, 0.35))
	# düğme gözler
	for side: int in [-1, 1]:
		var eye := Node3D.new()
		eye.position = Vector3(0.1 * side, 0.19, 0.262)
		head_pivot.add_child(eye)
		_mesh(eye, _cyl(0.052, 0.052, 0.03, 16), button, Vector3.ZERO, Vector3(PI / 2, 0, 0))
		_mesh(eye, _sphere(0.013), shine, Vector3(0.018, 0.018, 0.018))
		# iplik çarpısı
		_mesh(eye, _capsule(0.005, 0.05), thread, Vector3(0, 0, 0.017), Vector3(0, 0, PI / 4))
		_mesh(eye, _capsule(0.005, 0.05), thread, Vector3(0, 0, 0.017), Vector3(0, 0, -PI / 4))
		eyes.append(eye)
	# yanaklar
	for side: int in [-1, 1]:
		_mesh(head_pivot, _sphere(0.05), cheek, Vector3(0.17 * side, 0.1, 0.225), Vector3.ZERO, Vector3(1, 0.6, 0.35))
	# dikişli gülüş
	var smile := [[-0.05, 0.075, 0.5], [-0.017, 0.062, 0.12], [0.017, 0.062, -0.12], [0.05, 0.075, -0.5]]
	for s in smile:
		_mesh(head_pivot, _capsule(0.009, 0.042), thread, Vector3(s[0], s[1], 0.275), Vector3(0, 0, PI / 2 + float(s[2])))

	hat_anchor = Node3D.new()
	hat_anchor.position = Vector3(0, 0.41, -0.01)
	head_pivot.add_child(hat_anchor)
	face_anchor = Node3D.new()
	face_anchor.position = Vector3(0, 0.1, 0.28)
	head_pivot.add_child(face_anchor)
	neck_anchor = Node3D.new()
	neck_anchor.position = Vector3(0, 0.86, 0.23)
	body_root.add_child(neck_anchor)
	glasses_anchor = Node3D.new()
	glasses_anchor.position = Vector3(0, 0.19, 0.29)
	head_pivot.add_child(glasses_anchor)

# ── kostüm ──────────────────────────────────────────────────────────
func apply_look(l: Dictionary) -> void:
	look = l.duplicate()
	var c: Color = COLORS.get(String(look.get("color", "mustard")), COLORS.mustard)
	# Fetih kostümünde gövde klasik oyuncak ayı keçesi, kıyafet oyuncunun renginde
	var fm := felt(c if culture == "" else COLORS.teddy)
	for mi in felt_parts:
		mi.material_override = fm
	for a in [hat_anchor, face_anchor, neck_anchor, glasses_anchor]:
		if a == null:
			continue
		for ch in a.get_children():
			ch.queue_free()
	CultureCostume.undress(self)
	if culture != "":
		CultureCostume.dress(self, culture, costume_color if costume_color != null else c)
		return
	_build_hat(String(look.get("hat", "none")))
	_build_mustache(String(look.get("mustache", "none")))
	_build_bowtie(String(look.get("bowtie", "none")))
	_build_glasses(String(look.get("glasses", "none")))

## Fetih kostümünü giy ("" verilirse Trivia kostümüne döner)
func set_culture(c: String) -> void:
	culture = c
	if body_root:
		apply_look(look)

func _build_hat(kind: String) -> void:
	var satin := mat("satin", Color("171217"), 0.32)
	var band := mat("band", Color("A3182A"), 0.5)
	var gold := mat("gold", Color("D6A93F"), 0.28, 1.0)
	match kind:
		"tophat":
			_mesh(hat_anchor, _cyl(0.27, 0.27, 0.025, 28), satin, Vector3(0, -0.06, 0))
			_mesh(hat_anchor, _cyl(0.165, 0.17, 0.34, 28), satin, Vector3(0, 0.12, 0))
			_mesh(hat_anchor, _cyl(0.172, 0.172, 0.06, 28), band, Vector3(0, -0.02, 0))
		"bowler":
			_mesh(hat_anchor, _cyl(0.25, 0.25, 0.022, 28), mat("bowler", Color("2B1B12"), 0.45), Vector3(0, -0.07, 0))
			var dome := SphereMesh.new()
			dome.radius = 0.18
			dome.height = 0.18
			dome.is_hemisphere = true
			_mesh(hat_anchor, dome, mat("bowler", Color("2B1B12"), 0.45), Vector3(0, -0.06, 0), Vector3.ZERO, Vector3(1, 1.25, 1))
		"fez":
			_mesh(hat_anchor, _cyl(0.12, 0.155, 0.22, 24), mat("fez", Color("B21E2C"), 0.75), Vector3(0, 0.03, 0))
			_mesh(hat_anchor, _cyl(0.008, 0.008, 0.12, 6), satin, Vector3(0.07, 0.12, 0), Vector3(0, 0, 0.9))
			_mesh(hat_anchor, _sphere(0.028), satin, Vector3(0.12, 0.08, 0))
		"boater":
			var straw := mat("straw", Color("D8B366"), 0.95)
			_mesh(hat_anchor, _cyl(0.3, 0.3, 0.02, 30), straw, Vector3(0, -0.06, 0))
			_mesh(hat_anchor, _cyl(0.17, 0.175, 0.12, 28), straw, Vector3(0, 0.0, 0))
			_mesh(hat_anchor, _cyl(0.178, 0.178, 0.045, 28), mat("navy", Color("1F2B57"), 0.6), Vector3(0, -0.02, 0))
		"crown":
			_mesh(hat_anchor, _cyl(0.16, 0.16, 0.1, 24), gold, Vector3(0, -0.03, 0))
			for i in 6:
				var a := TAU * i / 6.0
				_mesh(hat_anchor, _cyl(0.0, 0.045, 0.11, 8), gold, Vector3(cos(a) * 0.14, 0.07, sin(a) * 0.14))
				_mesh(hat_anchor, _sphere(0.02), mat("ruby", Color("C2183A"), 0.1), Vector3(cos(a) * 0.162, -0.02, sin(a) * 0.162))
		"cone":
			_mesh(hat_anchor, _cyl(0.0, 0.14, 0.34, 20), mat("cone", Color("3C8DDB"), 0.6), Vector3(0, 0.1, 0), Vector3(-0.15, 0, 0.12))
			_mesh(hat_anchor, _sphere(0.045), mat("pom", Color("FFF1C4"), 1.0), Vector3(0.04, 0.28, -0.05))
		"beret":
			var bf := felt(Color("2A2A33"))
			_mesh(hat_anchor, _sphere(0.23), bf, Vector3(0.05, -0.02, 0), Vector3(0, 0, -0.25), Vector3(1.1, 0.32, 1.05))
			_mesh(hat_anchor, _cyl(0.01, 0.018, 0.05, 8), bf, Vector3(0.03, 0.06, 0))
		"party":
			var pm := mat("party", Color("F04E8C"), 0.55)
			_mesh(hat_anchor, _cyl(0.0, 0.13, 0.32, 20), pm, Vector3(0, 0.1, 0))
			for k in 4:
				_mesh(hat_anchor, _cyl(0.132 - k * 0.03, 0.135 - k * 0.03, 0.02, 20), mat("party_s", Color("FFD84A"), 0.5), Vector3(0, -0.02 + k * 0.075, 0))
			_mesh(hat_anchor, _sphere(0.05), mat("pom2", Color("7CE0FF"), 1.0), Vector3(0, 0.27, 0))
		"tricorn":
			var tc := mat("tricorn", Color("1E1A20"), 0.6)
			_mesh(hat_anchor, _cyl(0.16, 0.17, 0.12, 24), tc, Vector3(0, 0.02, 0))
			for i in 3:
				var a := TAU * i / 3.0 + PI / 2
				_mesh(hat_anchor, BoxMesh.new(), tc, Vector3(cos(a) * 0.17, 0.02, sin(a) * 0.17), Vector3(0, -a, 0.35), Vector3(0.05, 0.14, 0.34))
			_mesh(hat_anchor, _cyl(0.175, 0.175, 0.015, 24), gold, Vector3(0, 0.07, 0))
			var skull := _mesh(hat_anchor, _sphere(0.03), mat("bone", Color("F2EAD8"), 0.8), Vector3(0, 0.04, 0.2))
			skull.scale = Vector3(1, 0.9, 0.5)
		"wizard":
			var wz := mat("wizard", Color("3B2C8C"), 0.7)
			_mesh(hat_anchor, _cyl(0.3, 0.3, 0.02, 30), wz, Vector3(0, -0.06, 0))
			_mesh(hat_anchor, _cyl(0.02, 0.17, 0.46, 20), wz, Vector3(0.03, 0.18, -0.02), Vector3(-0.2, 0, -0.18))
			for k in 5:
				var a := k * 1.3
				_mesh(hat_anchor, _sphere(0.02), gold, Vector3(cos(a) * 0.13, 0.02 + k * 0.07, sin(a) * 0.13))
		"chef":
			var wt := mat("chef", Color("F8F6F0"), 0.95)
			_mesh(hat_anchor, _cyl(0.17, 0.17, 0.12, 24), wt, Vector3(0, 0.0, 0))
			for i in 5:
				var a := TAU * i / 5.0
				_mesh(hat_anchor, _sphere(0.1), wt, Vector3(cos(a) * 0.09, 0.14, sin(a) * 0.09))
			_mesh(hat_anchor, _sphere(0.12), wt, Vector3(0, 0.18, 0))
		"jester":
			for side: int in [-1, 1]:
				var jm := mat("jester_%d" % side, Color("C9303C") if side < 0 else Color("2E7D4F"), 0.6)
				_mesh(hat_anchor, _cyl(0.02, 0.1, 0.32, 14), jm, Vector3(0.12 * side, 0.12, 0), Vector3(0, 0, -0.9 * side))
				_mesh(hat_anchor, _sphere(0.04), gold, Vector3(0.27 * side, 0.21, 0))
			_mesh(hat_anchor, _cyl(0.17, 0.17, 0.07, 24), mat("jester_b", Color("F2C230"), 0.6), Vector3(0, -0.03, 0))
		"cowboy":
			var cb := mat("cowboy", Color("8A5A33"), 0.8)
			_mesh(hat_anchor, _cyl(0.34, 0.34, 0.02, 32), cb, Vector3(0, -0.06, 0), Vector3.ZERO, Vector3(1, 1, 0.85))
			for side: int in [-1, 1]:
				_mesh(hat_anchor, _cyl(0.1, 0.1, 0.02, 20), cb, Vector3(0.27 * side, -0.02, 0), Vector3(0, 0, 0.6 * side), Vector3(1, 1, 2.2))
			_mesh(hat_anchor, _cyl(0.14, 0.17, 0.18, 24), cb, Vector3(0, 0.04, 0))
			_mesh(hat_anchor, _cyl(0.172, 0.172, 0.03, 24), mat("cowboy_b", Color("3A2416"), 0.6), Vector3(0, -0.02, 0))
		"propeller":
			var cap_m := felt(Color("3C8DDB"))
			var dome2 := SphereMesh.new()
			dome2.radius = 0.2
			dome2.height = 0.2
			dome2.is_hemisphere = true
			_mesh(hat_anchor, dome2, cap_m, Vector3(0, -0.07, 0), Vector3.ZERO, Vector3(1, 0.8, 1))
			_mesh(hat_anchor, _cyl(0.012, 0.012, 0.08, 8), gold, Vector3(0, 0.1, 0))
			var prop := Node3D.new()
			prop.name = "Propeller"
			prop.position = Vector3(0, 0.14, 0)
			hat_anchor.add_child(prop)
			for side: int in [-1, 1]:
				_mesh(prop, BoxMesh.new(), mat("prop_%d" % side, Color("F24E4E") if side < 0 else Color("FFD84A"), 0.5), Vector3(0.09 * side, 0, 0), Vector3(0.3 * side, 0, 0), Vector3(0.16, 0.012, 0.05))
			_propeller = prop
		"flowers":
			var cols := [Color("F27BA8"), Color("FFD84A"), Color("A98BEA"), Color("FFFFFF"), Color("F2994A")]
			for i in 9:
				var a := TAU * i / 9.0
				var fp := Vector3(cos(a) * 0.2, -0.04, sin(a) * 0.2)
				_mesh(hat_anchor, _sphere(0.045), mat("flw_%d" % (i % 5), cols[i % 5], 0.7), fp)
				_mesh(hat_anchor, _sphere(0.02), mat("flw_c", Color("F2C230"), 0.6), fp + Vector3(0, 0.03, 0))
			_mesh(hat_anchor, _cyl(0.2, 0.2, 0.02, 24), mat("leaf", Color("4E9A45"), 0.8), Vector3(0, -0.07, 0))
		"laurel":
			for side: int in [-1, 1]:
				for k in 6:
					var a := PI / 2 + side * (0.3 + k * 0.38)
					_mesh(hat_anchor, _sphere(0.04), gold, Vector3(cos(a) * 0.2, -0.05 + k * 0.012, sin(a) * 0.2), Vector3(0, -a, 0.5 * side), Vector3(1.6, 0.5, 0.8))

func _build_mustache(kind: String) -> void:
	var hair := mat("hair", Color("2A1A10"), 0.9)
	match kind:
		"handlebar":
			for side: int in [-1, 1]:
				_mesh(face_anchor, _capsule(0.026, 0.17), hair, Vector3(0.065 * side, 0, 0.012), Vector3(0, 0, PI / 2 - 0.25 * side))
				_mesh(face_anchor, _sphere(0.024), hair, Vector3(0.14 * side, 0.03, 0.0))
		"chevron":
			_mesh(face_anchor, BoxMesh.new(), hair, Vector3(0, -0.005, 0.01), Vector3.ZERO, Vector3(0.2, 0.05, 0.035))
		"pencil":
			_mesh(face_anchor, _capsule(0.01, 0.18), hair, Vector3(0, 0, 0.012), Vector3(0, 0, PI / 2))
		"walrus":
			for i in 3:
				_mesh(face_anchor, _sphere(0.055), hair, Vector3((i - 1) * 0.06, -0.02 - abs(i - 1) * 0.01, 0.0), Vector3.ZERO, Vector3(1, 1.1, 0.5))
		"imperial":
			for side: int in [-1, 1]:
				_mesh(face_anchor, _capsule(0.018, 0.12), hair, Vector3(0.055 * side, 0.005, 0.012), Vector3(0, 0, PI / 2 - 0.1 * side))
				_mesh(face_anchor, _capsule(0.012, 0.09), hair, Vector3(0.12 * side, 0.05, 0.0), Vector3(0, 0, -0.3 * side))
		"goatee":
			_mesh(face_anchor, _capsule(0.012, 0.13), hair, Vector3(0, 0.005, 0.012), Vector3(0, 0, PI / 2))
			_mesh(face_anchor, _sphere(0.045), hair, Vector3(0, -0.12, -0.01), Vector3.ZERO, Vector3(0.7, 1.2, 0.55))
		"horseshoe":
			_mesh(face_anchor, _capsule(0.018, 0.14), hair, Vector3(0, 0.005, 0.012), Vector3(0, 0, PI / 2))
			for side: int in [-1, 1]:
				_mesh(face_anchor, _capsule(0.017, 0.14), hair, Vector3(0.07 * side, -0.06, 0.0))
		"curly":
			for side: int in [-1, 1]:
				_mesh(face_anchor, _capsule(0.02, 0.12), hair, Vector3(0.05 * side, 0, 0.012), Vector3(0, 0, PI / 2))
				var t := TorusMesh.new()
				t.inner_radius = 0.018
				t.outer_radius = 0.034
				_mesh(face_anchor, t, hair, Vector3(0.12 * side, 0.025, 0.0), Vector3(PI / 2, 0, 0))
		"beard":
			var bm := felt(Color("3A2616"))
			_mesh(face_anchor, _capsule(0.022, 0.18), hair, Vector3(0, 0.005, 0.015), Vector3(0, 0, PI / 2))
			_mesh(face_anchor, _sphere(0.13), bm, Vector3(0, -0.13, -0.05), Vector3.ZERO, Vector3(1.25, 0.8, 0.6))

func _build_bowtie(kind: String) -> void:
	if kind == "none":
		return
	if _build_neck_extra(kind):
		return
	var c := mat("bt_classic", Color("B21E2C"), 0.45)
	var s := 1.0
	if kind == "dotted":
		c = mat("bt_dotted", Color("3A2D7A"), 0.45)
	elif kind == "big":
		c = mat("bt_big", Color("D6A93F"), 0.3, 0.6)
		s = 1.6
	for side: int in [-1, 1]:
		var wing := CylinderMesh.new()
		wing.top_radius = 0.0
		wing.bottom_radius = 0.06 * s
		wing.height = 0.11 * s
		wing.radial_segments = 3
		_mesh(neck_anchor, wing, c, Vector3(0.055 * s * side, 0, 0), Vector3(0, 0, -PI / 2 * side))
	_mesh(neck_anchor, _sphere(0.028 * s), c, Vector3.ZERO)
	if kind == "dotted":
		for side: int in [-1, 1]:
			_mesh(neck_anchor, _sphere(0.012), mat("dot", Color(1, 1, 1), 0.5), Vector3(0.06 * side, 0.01, 0.03))

var _propeller: Node3D

## Yeni boyun süsleri (atkı, madalya, inci, fular, gül, çıngırak)
func _build_neck_extra(kind: String) -> bool:
	var gold := mat("gold", Color("D6A93F"), 0.28, 1.0)
	match kind:
		"scarf":
			var sc := felt(Color("C9303C"))
			var t := TorusMesh.new()
			t.inner_radius = 0.2
			t.outer_radius = 0.28
			_mesh(neck_anchor, t, sc, Vector3(0, 0.0, -0.2), Vector3(0.2, 0, 0))
			_mesh(neck_anchor, BoxMesh.new(), sc, Vector3(0.1, -0.16, 0.02), Vector3(0, 0, 0.15), Vector3(0.09, 0.26, 0.04))
			for k in 3:
				_mesh(neck_anchor, BoxMesh.new(), felt(Color("F2E6CC")), Vector3(0.1 + k * 0.0, -0.1 - k * 0.06, 0.045), Vector3(0, 0, 0.15), Vector3(0.095, 0.015, 0.01))
		"medal":
			_mesh(neck_anchor, BoxMesh.new(), mat("ribbon", Color("2F4A8A"), 0.6), Vector3(0, -0.05, 0.005), Vector3.ZERO, Vector3(0.06, 0.12, 0.01))
			_mesh(neck_anchor, _cyl(0.05, 0.05, 0.015, 20), gold, Vector3(0, -0.14, 0.02), Vector3(PI / 2, 0, 0))
			_mesh(neck_anchor, _cyl(0.0, 0.03, 0.01, 5), mat("medal_s", Color("FFF1C4"), 0.4, 0.5), Vector3(0, -0.14, 0.03), Vector3(PI / 2, 0, 0))
		"pearls":
			for i in 13:
				var a := PI * i / 12.0
				_mesh(neck_anchor, _sphere(0.025), mat("pearl", Color("F6F1E6"), 0.2, 0.1), Vector3(cos(a) * 0.2, -0.05 - sin(a) * 0.08, -0.08 + sin(a) * 0.08))
		"ascot":
			var am := mat("ascot", Color("7A3E6E"), 0.4)
			_mesh(neck_anchor, _sphere(0.05), am, Vector3(0, -0.01, 0.0))
			_mesh(neck_anchor, _sphere(0.07), am, Vector3(0, -0.09, 0.0), Vector3.ZERO, Vector3(0.8, 1.3, 0.4))
			_mesh(neck_anchor, _sphere(0.012), gold, Vector3(0, -0.07, 0.03))
		"rose":
			for i in 5:
				var a := TAU * i / 5.0
				_mesh(neck_anchor, _sphere(0.03), mat("rose_p", Color("C9183A"), 0.6), Vector3(0.14 + cos(a) * 0.022, -0.06 + sin(a) * 0.022, 0.02))
			_mesh(neck_anchor, _sphere(0.022), mat("rose_c", Color("8E0F28"), 0.6), Vector3(0.14, -0.06, 0.04))
			_mesh(neck_anchor, _capsule(0.006, 0.08), mat("stem", Color("4E9A45"), 0.8), Vector3(0.15, -0.11, 0.02))
		"bell":
			_mesh(neck_anchor, _cyl(0.2, 0.2, 0.03, 24), mat("collar", Color("C9303C"), 0.6), Vector3(0, 0, -0.18))
			_mesh(neck_anchor, _sphere(0.045), gold, Vector3(0, -0.04, 0.02))
			_mesh(neck_anchor, BoxMesh.new(), mat("bell_slit", Color("3A2A10"), 0.6), Vector3(0, -0.055, 0.06), Vector3.ZERO, Vector3(0.05, 0.008, 0.01))
		_:
			return false
	return true

## Gözlükler ve yüz aksesuarları (göz hizasında)
func _build_glasses(kind: String) -> void:
	if glasses_anchor == null or kind == "none":
		return
	var frame := mat("frame", Color("2A1D14"), 0.5)
	var gold := mat("gold", Color("D6A93F"), 0.28, 1.0)
	match kind:
		"round":
			for side: int in [-1, 1]:
				var t := TorusMesh.new()
				t.inner_radius = 0.055
				t.outer_radius = 0.068
				_mesh(glasses_anchor, t, frame, Vector3(0.1 * side, 0, 0), Vector3(PI / 2, 0, 0))
			_mesh(glasses_anchor, _capsule(0.008, 0.07), frame, Vector3(0, 0.005, 0), Vector3(0, 0, PI / 2))
		"monocle":
			var t2 := TorusMesh.new()
			t2.inner_radius = 0.058
			t2.outer_radius = 0.07
			_mesh(glasses_anchor, t2, gold, Vector3(0.1, 0, 0.005), Vector3(PI / 2, 0, 0))
			_mesh(glasses_anchor, _capsule(0.004, 0.24), gold, Vector3(0.15, -0.14, -0.02), Vector3(0, 0, 0.3))
		"star":
			for side: int in [-1, 1]:
				_mesh(glasses_anchor, _cyl(0.085, 0.085, 0.02, 5), mat("star_g", Color("F04E8C"), 0.4), Vector3(0.1 * side, 0, 0), Vector3(PI / 2, 0, PI / 10))
				_mesh(glasses_anchor, _cyl(0.06, 0.06, 0.022, 5), mat("star_l", Color("2A1A2A"), 0.2), Vector3(0.1 * side, 0, 0.004), Vector3(PI / 2, 0, PI / 10))
		"shades":
			_mesh(glasses_anchor, BoxMesh.new(), mat("shades", Color("111114"), 0.15, 0.3), Vector3(0, 0, 0.005), Vector3.ZERO, Vector3(0.32, 0.075, 0.02))
			_mesh(glasses_anchor, BoxMesh.new(), mat("shades_hi", Color("5A6A8A"), 0.1, 0.5), Vector3(-0.08, 0.02, 0.016), Vector3(0, 0, 0.3), Vector3(0.05, 0.01, 0.005))
		"domino":
			var dm := mat("domino", Color("1E1A2E"), 0.4)
			_mesh(glasses_anchor, _sphere(0.1), dm, Vector3(0, 0, -0.015), Vector3.ZERO, Vector3(1.75, 0.6, 0.35))
			for side: int in [-1, 1]:
				_mesh(glasses_anchor, _sphere(0.035), mat("domino_eye", Color("F2C230"), 0.3, 0.3), Vector3(0.1 * side, 0, 0.012), Vector3.ZERO, Vector3(1.2, 0.9, 0.3))
		"eyepatch":
			_mesh(glasses_anchor, _cyl(0.06, 0.06, 0.02, 16), mat("patch", Color("141014"), 0.6), Vector3(-0.1, 0, 0.006), Vector3(PI / 2, 0, 0))
			_mesh(glasses_anchor, _capsule(0.006, 0.42), mat("patch", Color("141014"), 0.6), Vector3(0, 0.03, -0.02), Vector3(0, 0, PI / 2 - 0.3))

# ── sabotaj görünüşleri ─────────────────────────────────────────────
var _boots: Array[MeshInstance3D] = []
var _frost: MeshInstance3D

## Kurşun ayakkabı: ayaklarda ağır, gri metal pabuçlar
func set_boots(on: bool) -> void:
	if on and _boots.is_empty():
		for leg in [leg_l, leg_r]:
			var b := _mesh(leg, _cyl(0.14, 0.16, 0.16, 12), mat("lead", Color("4A4E57"), 0.35, 0.9), Vector3(0, -0.3, 0.03))
			_boots.append(b)
	for b in _boots:
		b.visible = on

## Buz pisti: ayak altında buz parçası ve soğuk mavi bir parıltı
func set_frost(on: bool) -> void:
	if on and _frost == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.7, 0.9, 1.0, 0.55)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.05
		m.emission_enabled = true
		m.emission = Color(0.5, 0.8, 1.0)
		m.emission_energy_multiplier = 0.6
		_frost = _mesh(self, _cyl(0.5, 0.55, 0.04, 20), m, Vector3(0, 0.02, 0))
	if _frost:
		_frost.visible = on

# ── animasyon ───────────────────────────────────────────────────────
func punch() -> void:
	_punch = 0.28

func land(impact: float) -> void:
	_squash_v -= clamp(impact, 0.0, 12.0) * 0.55

## Her fizik karesinde Plush tarafından çağrılır.
## state: 0 normal, 1 sendeleme, 2 yuvarlanma, 3 kalkma, 4 elendi
func animate(delta: float, vel: Vector3, grounded: bool, state: int) -> void:
	if _propeller and is_instance_valid(_propeller):
		_propeller.rotation.y += delta * (5.0 + vel.length() * 4.0)
	_t += delta
	var hv := Vector2(vel.x, vel.z)
	var speed := hv.length()
	var move_k: float = clamp(speed / 5.0, 0.0, 1.0)

	# yürüyüş
	_walk += delta * (4.0 + speed * 2.4)
	var sw := sin(_walk) * 0.8 * move_k
	if grounded:
		leg_l.rotation.x = sw
		leg_r.rotation.x = -sw
		body_root.position.y = abs(sin(_walk)) * 0.05 * move_k
	else:
		leg_l.rotation.x = lerp(leg_l.rotation.x, -0.5, delta * 8.0)
		leg_r.rotation.x = lerp(leg_r.rotation.x, 0.3, delta * 8.0)
		body_root.position.y = lerp(body_root.position.y, 0.0, delta * 8.0)

	# kollar: yürürken sallanır, havada açılır, omuz atarken öne fırlar
	var arm_x := -sw * 0.9
	var arm_z := 0.28
	if not grounded:
		arm_z = 1.1 + sin(_t * 18.0) * 0.15
	if _punch > 0.0:
		_punch -= delta
		arm_x = -1.5
		arm_z = 0.1
	if state == 2:
		arm_x = sin(_t * 17.0) * 1.2
		arm_z = 1.3 + cos(_t * 13.0) * 0.4
		leg_l.rotation.x = sin(_t * 15.0) * 0.9
		leg_r.rotation.x = cos(_t * 14.0) * 0.9
	arm_l.rotation.x = lerp(arm_l.rotation.x, arm_x, delta * 14.0)
	arm_r.rotation.x = lerp(arm_r.rotation.x, arm_x if _punch > 0.0 else -arm_x, delta * 14.0)
	arm_l.rotation.z = lerp(arm_l.rotation.z, -arm_z, delta * 10.0)
	arm_r.rotation.z = lerp(arm_r.rotation.z, arm_z, delta * 10.0)

	# iniş sıkışması (yay)
	if grounded and not _was_grounded:
		land(-_prev_vel.y)
	_was_grounded = grounded
	_squash_v += (-_squash * 170.0 - _squash_v * 13.0) * delta
	_squash += _squash_v * delta
	var sq: float = clamp(_squash, -0.25, 0.3)
	body_root.scale = Vector3(1.0 - sq * 0.55, 1.0 + sq, 1.0 - sq * 0.55)

	# öne eğilme + sendeleme salınımı
	body_root.rotation.x = lerp(body_root.rotation.x, move_k * 0.22, delta * 6.0)
	wobble = max(0.0, wobble - delta * 1.2)
	body_root.rotation.z = sin(_t * 13.0) * 0.28 * wobble

	# kafa yayı: ivmeye gecikmeyle tepki verir
	var acc: Vector3 = (vel - _prev_vel) / maxf(delta, 0.0001)
	_prev_vel = vel
	var target := Vector2(clamp(acc.z * 0.006, -0.35, 0.35), clamp(-acc.x * 0.006, -0.35, 0.35))
	_head_v += ((target - _head) * 90.0 - _head_v * 9.0) * delta
	_head += _head_v * delta
	head_pivot.rotation.x = _head.x
	head_pivot.rotation.z = _head.y + sin(_t * 1.7) * 0.03

	# göz kırpma
	_blink -= delta
	var closed := _blink < 0.0
	if _blink < -0.11:
		_blink = randf_range(1.8, 4.6)
	for e in eyes:
		e.scale.y = 0.15 if closed or state == 2 else 1.0
