class_name CastleModel
extends Node3D
## Oyuncunun başkenti: 3 kule = 3 can. Web sürümündeki altı üslup,
## tiyatro dekoru gibi boyanmış ahşap/alçı maketler olarak:
##   himeji   Beyaz Balıkçıl (Japon şatosu, iki katlı kavisli saçak)
##   pyramid  Basamaklı piramit (üç dikilitaş kule sayılır)
##   alhambra Elhamra (kum rengi sur, kiremit kubbeler)
##   fairy    Masal şatosu (beyaz kuleler, mavi sivri külahlar)
##   gothic   Gotik katedral (koyu taş, iğne kuleler)
##   steppe   Bozkır kağanlığı (otağ çadırları, tuğ)
## Kaide ve sancak oyuncunun renginde; sahibi uzaktan okunur.

##   onion    Soğan kubbeli saray (renkli, çizgili kubbeler)
##   lighthouse Deniz kalesi (ortada çizgili deniz feneri, yanık lambası)
const STYLES := ["himeji", "pyramid", "alhambra", "fairy", "gothic", "steppe", "onion", "lighthouse"]
## Sancak desenleri (oyuncunun renginde)
const BANNERS := ["plain", "stripes", "chevron", "star", "cross", "checker", "sun"]
const PALETTE := {
	"himeji": {"wall": Color("F4EBDA"), "roof": Color("2E2438"), "trim": Color("B9A98C")},
	"pyramid": {"wall": Color("DCBE86"), "roof": Color("C08A3E"), "trim": Color("B99A62")},
	"alhambra": {"wall": Color("E4C9A5"), "roof": Color("B8482A"), "trim": Color("C98F4E")},
	"fairy": {"wall": Color("F2EFE6"), "roof": Color("2C6187"), "trim": Color("A9B7C4")},
	"gothic": {"wall": Color("7A6F86"), "roof": Color("2A2238"), "trim": Color("4A4458")},
	"steppe": {"wall": Color("E9D8B4"), "roof": Color("1E6F8C"), "trim": Color("C2A470")},
	"onion": {"wall": Color("E8D6C0"), "roof": Color("2E8C6A"), "trim": Color("C9303C")},
	"lighthouse": {"wall": Color("D9D2C4"), "roof": Color("B8322E"), "trim": Color("6E6A64")},
}
const SPOTS := [Vector3(-0.34, 0, 0.02), Vector3(0.0, 0, -0.1), Vector3(0.34, 0, 0.02)]
const HEIGHTS := [0.5, 0.72, 0.5]

var style := "fairy"
var color := Color.WHITE
var banner := "plain"
var towers := 3
var _towers: Array[Node3D] = []
var _pips: Array[MeshInstance3D] = []
var _flag: MeshInstance3D
var _t := 0.0

static var _mats := {}

static func m(key: String, c: Color, rough := 0.75, metal := 0.0, emit := 0.0) -> StandardMaterial3D:
	var k := key + c.to_html() + str(emit)
	if _mats.has(k):
		return _mats[k]
	var mt := StandardMaterial3D.new()
	mt.albedo_color = c
	mt.roughness = rough
	mt.metallic = metal
	if emit > 0.0:
		mt.emission_enabled = true
		mt.emission = c
		mt.emission_energy_multiplier = emit
	_mats[k] = mt
	return mt

## Taş duvar (stone.gdshader) ve kiremit çatı (roof_tiles.gdshader) malzemeleri
static func stone(c: Color, brick := Vector2(0.085, 0.045)) -> ShaderMaterial:
	var k := "stone" + c.to_html() + str(brick)
	if _mats.has(k):
		return _mats[k]
	var mt := ShaderMaterial.new()
	mt.shader = preload("res://ui/shaders/stone.gdshader")
	mt.set_shader_parameter("tint", c)
	mt.set_shader_parameter("brick_w", brick.x)
	mt.set_shader_parameter("brick_h", brick.y)
	_mats[k] = mt
	return mt

static func tiles(c: Color) -> ShaderMaterial:
	var k := "tiles" + c.to_html()
	if _mats.has(k):
		return _mats[k]
	var mt := ShaderMaterial.new()
	mt.shader = preload("res://ui/shaders/roof_tiles.gdshader")
	mt.set_shader_parameter("tint", c)
	_mats[k] = mt
	return mt

func _init(p_style := "fairy", p_color := Color.WHITE) -> void:
	style = p_style if STYLES.has(p_style) else "fairy"
	color = p_color

func _ready() -> void:
	_build()

# ── yardımcılar ─────────────────────────────────────────────────────
func _mi(parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi

func _box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b

func _cyl(top: float, bot: float, h: float, seg := 16) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bot
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c

func _dome(r: float, seg := 18) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r
	s.is_hemisphere = true
	s.radial_segments = seg
	s.rings = 8
	return s

# ── kurulum ─────────────────────────────────────────────────────────
func _build() -> void:
	var pal: Dictionary = PALETTE[style]
	# steppe (keçe otağ) dışında duvarlar taş örgü, sivri/kubbe çatılar kiremit
	var wall: Material = m("wall", pal.wall, 0.85) if style == "steppe" else stone(pal.wall)
	var roof: Material = tiles(pal.roof) if style in ["fairy", "gothic", "alhambra", "lighthouse"] else m("roof", pal.roof, 0.5)
	var trim := m("trim", pal.trim, 0.7)
	var gold := m("gold", Color("D6A93F"), 0.3, 1.0)
	# kaide: oyuncunun renginde sekizgen, altın şerit
	_mi(self, _cyl(0.52, 0.56, 0.08, 8), PlushVisual.felt(color), Vector3(0, 0.04, 0), Vector3(0, PI / 8, 0))
	_mi(self, _cyl(0.535, 0.535, 0.018, 8), gold, Vector3(0, 0.082, 0), Vector3(0, PI / 8, 0))
	var base_y := 0.09
	if style == "pyramid":
		for i in 4:
			var w := 0.78 - i * 0.16
			_mi(self, _box(w, 0.12, w), m("wall", pal.wall.darkened(i * 0.04), 0.9), Vector3(0, base_y + 0.06 + i * 0.12, -0.02))
		_mi(self, _cyl(0.0, 0.1, 0.14, 4), m("cap", pal.roof, 0.35, 0.6), Vector3(0, base_y + 0.55, -0.02), Vector3(0, PI / 4, 0))
		_mi(self, _box(0.12, 0.12, 0.02), m("door", Color("3A2E2A")), Vector3(0, base_y + 0.06, 0.37))
	elif style == "steppe":
		# çit halkası (ahşap kazıklar)
		for i in 16:
			var a := TAU * i / 16.0
			_mi(self, _cyl(0.018, 0.022, 0.16, 6), m("stake", Color("8A5A33")), Vector3(cos(a) * 0.47, base_y + 0.08, sin(a) * 0.4))
	else:
		# sur duvarı + mazgallar + kapı
		_mi(self, _box(0.86, 0.26, 0.26), wall, Vector3(0, base_y + 0.13, 0.12))
		for i in 7:
			var x := -0.39 + i * 0.13
			_mi(self, _box(0.07, 0.07, 0.07), wall, Vector3(x, base_y + 0.295, 0.22))
		_mi(self, _box(0.18, 0.18, 0.02), m("door", Color("3A2E2A")), Vector3(0, base_y + 0.09, 0.255))
		_mi(self, _cyl(0.09, 0.09, 0.02, 14), m("door", Color("3A2E2A")), Vector3(0, base_y + 0.18, 0.255), Vector3(PI / 2, 0, 0))
		for k in 2:
			_mi(self, _box(0.19, 0.012, 0.012), trim, Vector3(0, base_y + 0.05 + k * 0.06, 0.268))
	# kuleler
	for i in 3:
		var t := Node3D.new()
		t.position = SPOTS[i] + Vector3(0, base_y, 0)
		add_child(t)
		_build_tower(t, i, pal, wall, roof, trim, gold)
		_towers.append(t)
	# can armaları: kalenin önünde, iki direkli ahşap bir tabelada üç kalkan
	var wood := m("sign_wood", Color("6A4020"), 0.8)
	_mi(self, _box(0.5, 0.05, 0.03), wood, Vector3(0, 0.25, 0.5))
	for side: int in [-1, 1]:
		_mi(self, _cyl(0.014, 0.016, 0.22, 6), wood, Vector3(0.23 * side, 0.18, 0.5))
	for i in 3:
		var pip := _mi(self, _box(0.1, 0.12, 0.02), m("pip", color, 0.5, 0.0, 0.3), Vector3((i - 1) * 0.15, 0.36, 0.5))
		var tip := MeshInstance3D.new()
		var pr := PrismMesh.new()
		pr.size = Vector3(0.1, 0.06, 0.02)
		tip.mesh = pr
		tip.rotation.z = PI
		tip.position = Vector3(0, -0.09, 0)
		tip.material_override = pip.material_override
		pip.add_child(tip)
		_pips.append(pip)
	set_towers(towers, false)

func _build_tower(t: Node3D, i: int, pal: Dictionary, wall: Material, roof: Material, trim: Material, gold: Material) -> void:
	var h: float = HEIGHTS[i]
	var tw := 0.26 if i == 1 else 0.21
	var window := m("window", Color("FFC45A"), 0.4, 0.0, 1.6)
	match style:
		"pyramid":
			# dikilitaş: ince kare gövde + altın piramidyon
			var off := Vector3(0, 0, 0.16 if i != 1 else 0.3)
			_mi(t, _cyl(0.035, 0.05, h * 0.9, 4), m("obelisk", pal.wall.lightened(0.1), 0.8), off + Vector3(0, h * 0.45, 0), Vector3(0, PI / 4, 0))
			_mi(t, _cyl(0.0, 0.036, 0.07, 4), gold, off + Vector3(0, h * 0.9 + 0.035, 0), Vector3(0, PI / 4, 0))
			return
		"steppe":
			# otağ: silindir gövde + basık kubbe + tepe halkası
			var r := tw * 0.95
			var hh := h * 0.45
			_mi(t, _cyl(r, r, hh, 20), wall, Vector3(0, hh * 0.5, 0))
			_mi(t, _cyl(r * 1.01, r * 1.01, 0.03, 20), roof, Vector3(0, hh * 0.35, 0))
			_mi(t, _cyl(r * 0.18, r * 1.08, hh * 0.7, 20), roof, Vector3(0, hh + hh * 0.35, 0))
			_mi(t, _cyl(r * 0.2, r * 0.2, 0.03, 12), trim, Vector3(0, hh + hh * 0.72, 0))
			_mi(t, _box(0.07, 0.11, 0.02), m("door", Color("B8482A")), Vector3(0, 0.06, r))
			if i == 1:
				# tuğ: direk + at kılı püskülü
				_mi(t, _cyl(0.012, 0.012, 0.7, 6), m("pole", Color("5A3A20")), Vector3(0, 0.75, 0))
				_mi(t, _sphere(0.03), gold, Vector3(0, 1.1, 0))
				for k in 5:
					var a := TAU * k / 5.0
					_mi(t, _cyl(0.004, 0.012, 0.16, 5), m("horsetail", Color("2A1E18"), 1.0), Vector3(cos(a) * 0.02, 1.0, sin(a) * 0.02), Vector3(sin(a) * 0.15, 0, cos(a) * 0.15))
			return
	var square := style == "himeji" or style == "alhambra"
	var body: Mesh = _box(tw, h, tw) if square else _cyl(tw * 0.5, tw * 0.52, h, 16)
	_mi(t, body, wall, Vector3(0, h * 0.5, 0))
	# kule başlığı (mazgal çıkıntısı)
	var cap: Mesh = _box(tw * 1.16, 0.05, tw * 1.16) if square else _cyl(tw * 0.58, tw * 0.58, 0.05, 16)
	_mi(t, cap, trim, Vector3(0, h + 0.02, 0))
	# pencere (sıcak ışık)
	_mi(t, _box(tw * 0.22, 0.08, 0.01), window, Vector3(0, h * 0.62, tw * 0.5 + 0.006))
	var top := h + 0.045
	match style:
		"himeji":
			for k in 2:
				var w := tw * (1.45 - k * 0.38)
				_mi(t, _cyl(0.0, w * 0.75, 0.11, 4), roof, Vector3(0, top + 0.04 + k * 0.13, 0), Vector3(0, PI / 4, 0))
				_mi(t, _box(w * 0.7, 0.05, w * 0.7), wall, Vector3(0, top + 0.1 + k * 0.13, 0))
			_mi(t, _sphere(0.02), gold, Vector3(0, top + 0.3, 0))
		"fairy":
			_mi(t, _cyl(0.0, tw * 0.62, 0.42, 18), roof, Vector3(0, top + 0.21, 0))
			_mi(t, _sphere(0.025), m("finial", Color("F0B02A"), 0.3, 1.0), Vector3(0, top + 0.44, 0))
		"gothic":
			_mi(t, _cyl(0.0, tw * 0.5, 0.56, 8), roof, Vector3(0, top + 0.28, 0))
			for k in 4:
				var a := TAU * k / 4.0 + PI / 4
				_mi(t, _cyl(0.0, 0.025, 0.14, 6), roof, Vector3(cos(a) * tw * 0.5, top + 0.07, sin(a) * tw * 0.5))
		"onion":
			# soğan kubbe: şişkin küre + sivri tepe, kuleye göre farklı renk ve çizgi
			var cols := [Color("2E8C6A"), Color("C9303C"), Color("2F5AA8")]
			var dm := m("onion_%d" % i, cols[i % 3], 0.45)
			var bulb := _mi(t, _sphere(tw * 0.62), dm, Vector3(0, top + tw * 0.5, 0))
			bulb.scale = Vector3(1, 1.15, 1)
			for k in 4:
				var a := TAU * k / 4.0
				var st := _mi(t, _box(0.012, tw * 1.1, 0.012), m("onion_s", Color("F2C230"), 0.4, 0.4), Vector3(cos(a) * tw * 0.58, top + tw * 0.5, sin(a) * tw * 0.58), Vector3(0, -a, 0))
				st.rotation.z = 0.0
			_mi(t, _cyl(0.0, tw * 0.3, tw * 0.9, 12), dm, Vector3(0, top + tw * 1.4, 0))
			_mi(t, _sphere(0.022), gold, Vector3(0, top + tw * 1.9, 0))
		"lighthouse":
			if i == 1:
				# fener: kule gövdesinin üstüne çizgili uzantı, cam oda, yanık lamba
				for k in 3:
					_mi(t, _cyl(tw * (0.44 - k * 0.05), tw * (0.48 - k * 0.05), 0.12, 16), m("lh_%d" % (k % 2), Color("B8322E") if k % 2 == 0 else Color("F4F0E6"), 0.6), Vector3(0, top + 0.06 + k * 0.12, 0))
				var lamp_y := top + 0.42
				_mi(t, _cyl(tw * 0.3, tw * 0.3, 0.1, 12), m("lamp", Color("FFE08A"), 0.2, 0.0, 3.0), Vector3(0, lamp_y, 0))
				_mi(t, _cyl(0.0, tw * 0.38, 0.1, 12), roof, Vector3(0, lamp_y + 0.1, 0))
				var beam := OmniLight3D.new()
				beam.light_color = Color("FFD27A")
				beam.light_energy = 0.8
				beam.omni_range = 1.2
				beam.position = Vector3(0, lamp_y, 0)
				t.add_child(beam)
			else:
				for k in 6:
					var a := TAU * k / 6.0
					_mi(t, _box(0.05, 0.06, 0.05), trim, Vector3(cos(a) * tw * 0.5, top + 0.05, sin(a) * tw * 0.5))
		"alhambra":
			_mi(t, _dome(tw * 0.55), roof, Vector3(0, top, 0))
			_mi(t, _cyl(0.008, 0.008, 0.12, 6), gold, Vector3(0, top + tw * 0.55 + 0.05, 0))
			_mi(t, _sphere(0.02), gold, Vector3(0, top + tw * 0.55 + 0.11, 0))
			# nal kemerli pencere süsü
			_mi(t, _cyl(0.035, 0.035, 0.012, 12), m("arch", pal.trim, 0.6), Vector3(0, h * 0.62 + 0.04, tw * 0.5 + 0.004), Vector3(PI / 2, 0, 0))
	if i == 1:
		# sancak: oyuncunun renginde, rüzgârda dalgalanır
		_mi(t, _cyl(0.01, 0.01, 0.42, 6), m("pole", Color("3A2A1A")), Vector3(0.0, top + 0.5, 0))
		var fm := StandardMaterial3D.new()
		fm.albedo_texture = banner_texture(banner, color)
		fm.roughness = 0.8
		fm.emission_enabled = true
		fm.emission_texture = fm.albedo_texture
		fm.emission_energy_multiplier = 0.25
		var flag_h := top + (0.62 if style != "lighthouse" else 0.8)
		if style == "lighthouse":
			_mi(t, _cyl(0.008, 0.008, 0.36, 6), m("pole", Color("3A2A1A")), Vector3(0.0, flag_h - 0.12, 0))
		# sancak deseni seçilebildiği için bayrak okunur büyüklükte
		_flag = _mi(t, _box(0.3, 0.18, 0.01), fm, Vector3(0.15, flag_h - 0.03, 0))

static var _banner_cache := {}

## Sancak kumaşı: desen oyuncunun renginde, açık/koyu tonlarla (64×40 doku)
static func banner_texture(pattern: String, col: Color) -> ImageTexture:
	var key := pattern + col.to_html()
	if _banner_cache.has(key):
		return _banner_cache[key]
	var w := 64
	var h := 40
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var base := col
	var hi := col.lightened(0.55)
	var lo := col.darkened(0.35)
	for y in h:
		for x in w:
			var c := base
			var u := float(x) / w
			var v := float(y) / h
			match pattern:
				"stripes":
					c = hi if int(y / 8) % 2 == 0 else base
				"chevron":
					c = hi if absf(v - 0.5) * 1.6 + 0.2 > u and absf(v - 0.5) * 1.6 + 0.02 < u else base
				"star":
					var p := Vector2(u - 0.5, (v - 0.5) * 0.625)
					var ang := atan2(p.y, p.x)
					var r := 0.16 + 0.1 * cos(5.0 * ang)
					c = hi if p.length() < r * 1.1 else base
				"cross":
					c = hi if absf(u - 0.38) < 0.08 or absf(v - 0.5) < 0.12 else base
				"checker":
					c = hi if (int(x / 8) + int(y / 8)) % 2 == 0 else base
				"sun":
					var q := Vector2(u - 0.5, (v - 0.5) * 0.625)
					var d := q.length()
					var rays := 0.5 + 0.5 * cos(atan2(q.y, q.x) * 12.0)
					c = hi if d < 0.1 else (hi.lerp(base, 0.4) if d < 0.24 and rays > 0.6 else base)
			# kenar dikişi
			if x < 2 or y < 2 or y >= h - 2:
				c = lo
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	_banner_cache[key] = tex
	return tex

func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 10
	s.rings = 6
	return s

# ── can ─────────────────────────────────────────────────────────────
## Ayakta kalan kule sayısı. Düşen kule sarsılıp yıkılır, yerinde moloz ve toz kalır.
func set_towers(n: int, animate := true) -> void:
	var prev := towers
	towers = clampi(n, 0, 3)
	for i in 3:
		var standing := i < towers
		var t := _towers[i]
		if not standing and (animate and i < prev):
			_topple(t)
		elif not standing:
			t.visible = false
		else:
			t.visible = true
			t.rotation = Vector3.ZERO
			t.scale = Vector3.ONE
		var pip := _pips[i]
		pip.material_override = m("pip", color, 0.5, 0.0, 0.3) if standing else m("pip_dead", Color("5A5364"), 0.8)

func _topple(t: Node3D) -> void:
	var tw := t.create_tween()
	tw.tween_property(t, "rotation:z", 0.08, 0.06)
	tw.tween_property(t, "rotation:z", -0.08, 0.06)
	tw.tween_property(t, "rotation:z", 0.05, 0.06)
	tw.set_parallel(true)
	tw.tween_property(t, "rotation:z", 1.35 * (1.0 if t.position.x >= 0.0 else -1.0), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(0.18)
	tw.tween_property(t, "position:y", t.position.y - 0.25, 0.55).set_delay(0.18)
	tw.chain().tween_property(t, "scale", Vector3(1, 0.01, 1), 0.2)
	tw.tween_callback(func():
		t.visible = false
		_rubble(t.position))
	_dust(t.position + Vector3(0, 0.3, 0))

func _rubble(p: Vector3) -> void:
	var stone := m("rubble", PALETTE[style].wall.darkened(0.35), 0.95)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(p.x * 1000.0) + 7
	for k in 6:
		var b := _mi(self, _box(rng.randf_range(0.04, 0.09), rng.randf_range(0.03, 0.07), rng.randf_range(0.04, 0.09)), stone,
			Vector3(p.x + rng.randf_range(-0.1, 0.1), 0.12 + rng.randf_range(0.0, 0.05), p.z + rng.randf_range(-0.08, 0.08)),
			Vector3(rng.randf(), rng.randf(), rng.randf()))
		b.name = "Rubble"

func _dust(p: Vector3, amount := 26, life := 1.3, size := 1.0) -> void:
	var ps := CPUParticles3D.new()
	ps.one_shot = true
	ps.amount = amount
	ps.lifetime = life
	ps.explosiveness = 0.85
	ps.position = p
	ps.direction = Vector3(0, 1, 0)
	ps.spread = 80.0
	ps.initial_velocity_min = 0.25 * size
	ps.initial_velocity_max = 0.8 * size
	ps.gravity = Vector3(0, 0.05, 0)
	ps.damping_min = 0.6
	ps.damping_max = 1.2
	ps.scale_amount_min = 0.6 * size
	ps.scale_amount_max = 1.4 * size
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.35))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1, 1.6))
	ps.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.86, 0.8, 0.7, 0.55))
	ramp.set_color(1, Color(0.7, 0.64, 0.56, 0.0))
	ps.color_ramp = ramp
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.16)
	ps.mesh = q
	ps.material_override = _puff_mat()
	add_child(ps)
	ps.emitting = true
	get_tree().create_timer(life + 1.0).timeout.connect(ps.queue_free)

static var _puff: StandardMaterial3D
## Yumuşak kenarlı toz bulutu: ışınsal geçişli doku, kameraya dönük kare
static func _puff_mat() -> StandardMaterial3D:
	if _puff:
		return _puff
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.85))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.4))
	g.add_point(0.7, Color(1, 1, 1, 0.08))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 64
	tex.height = 64
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_puff = m
	return m

## Bütün kale yıkılır (son kule düştüğünde): gümbürtüyle sarsılır, kuleler
## sırayla devrilir, taşlar dört yana saçılır, koca bir toz bulutu kalkar,
## sancak iner, kaide çöker. Geriye isli bir harabe kalır.
func collapse() -> void:
	var base := position
	var rumble := create_tween()
	for i in 12:
		var k := 1.0 - i / 12.0
		rumble.tween_property(self, "position", base + Vector3(randf_range(-1, 1) * 0.03 * k, 0, randf_range(-1, 1) * 0.02 * k), 0.05)
	rumble.tween_property(self, "position", base, 0.05)
	for i in 3:
		if i < towers:
			var t := _towers[i]
			get_tree().create_timer(0.25 + i * 0.22).timeout.connect(func(): if is_instance_valid(t): _topple(t))
	towers = 0
	for pip in _pips:
		pip.material_override = m("pip_dead", Color("5A5364"), 0.8)
		pip.create_tween().tween_property(pip, "scale", Vector3(0.01, 0.01, 0.01), 0.4).set_delay(0.3)
	if _flag:
		var fl := _flag
		_flag = null
		var ft := fl.create_tween()
		ft.tween_property(fl, "position:y", fl.position.y - 0.45, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(0.5)
		ft.tween_property(fl, "scale", Vector3(1, 0.01, 1), 0.2)
	get_tree().create_timer(0.7).timeout.connect(func():
		if not is_instance_valid(self):
			return
		_debris(18)
		_dust(Vector3(0, 0.25, 0), 70, 1.8, 2.2))
	var tw := create_tween()
	tw.tween_interval(0.9)
	tw.tween_property(self, "scale", Vector3(1.08, 0.3, 1.08), 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		for mi in find_children("*", "MeshInstance3D", true, false):
			var gm := mi as MeshInstance3D
			if gm.material_override is StandardMaterial3D and gm.name != "Rubble":
				var dm := (gm.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
				dm.albedo_color = dm.albedo_color.darkened(0.28)
				gm.material_override = dm)

## Taş parçaları: merkezden yay çizerek saçılır, dönerek yere düşer
func _debris(n: int) -> void:
	var stone := m("rubble", PALETTE[style].wall.darkened(0.3), 0.95)
	for k in n:
		var sz := randf_range(0.035, 0.08)
		var b := _mi(get_parent() if get_parent() else self, _box(sz, sz * 0.8, sz), stone, global_position + Vector3(0, 0.3, 0), Vector3.ZERO)
		b.global_position = global_position + Vector3(randf_range(-0.1, 0.1), 0.35, randf_range(-0.1, 0.1))
		var dir := Vector2.from_angle(randf() * TAU) * randf_range(0.35, 0.95)
		var start := b.position
		var end := start + Vector3(dir.x, -0.2, dir.y)
		var peak := randf_range(0.25, 0.6)
		var spin := Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9))
		var tw := b.create_tween()
		tw.tween_method(func(q: float):
			if is_instance_valid(b):
				b.position = start.lerp(end, q) + Vector3(0, sin(q * PI) * peak - q * q * 0.05, 0)
				b.rotation = spin * q, 0.0, 1.0, randf_range(0.55, 0.85))
		tw.tween_interval(2.5)
		tw.tween_property(b, "scale", Vector3(0.01, 0.01, 0.01), 0.6)
		tw.tween_callback(b.queue_free)

func _process(delta: float) -> void:
	_t += delta
	if _flag:
		_flag.rotation.y = sin(_t * 5.0) * 0.25
		_flag.scale.x = 1.0 + sin(_t * 7.0) * 0.06
