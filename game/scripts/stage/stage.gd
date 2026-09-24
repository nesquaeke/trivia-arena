class_name Stage
extends Node3D
## "The Grand Stage": kadife halı, katlı ağır perdeler, yaldızlı sahne ağzı,
## hacimsel sis ve spot ışıkları, sahne tozu, dört kapaklı zemin (A-B-C-D),
## arkada dev soru panosu, önde kapanıp açılan ana perde.
## Bütün geometri kodla üretilir; dış model yok.
##
## Koordinatlar: sahne zemini y=0; genişlik x∈[-8,8]; derinlik z∈[-5,4.5];
## kamera +Z tarafında, yukarıdan bakar. Kapak alanı: x∈[-4.9,4.9], z∈[-3.3,2.3].

signal curtain_done(closed: bool)

const STAGE_W := 16.0
const FRONT_Z := 4.5
const BACK_Z := -5.0
const TRAP_X := 4.9
const TRAP_Z0 := -3.3
const TRAP_Z1 := 2.3
const GAP := 0.04
const LETTERS := ["A", "B", "C", "D"]
const ZONE_COLORS := [Color("E9B53A"), Color("3FB6A8"), Color("D9577A"), Color("8C74E0")]

var env: Environment
var trapdoors: Array[TrapDoor] = []
var zone_labels: Array[Label3D] = []
var zone_letters: Array[Label3D] = []
var zone_lights: Array[SpotLight3D] = []
var board: BoardScreen
var board_viewport: SubViewport
var house_l: Node3D
var house_r: Node3D
var gold_spot: SpotLight3D
var solo_spot: SpotLight3D
var main_lights: Array[Light3D] = []
var bulbs_a: Array[MeshInstance3D] = []
var bulbs_b: Array[MeshInstance3D] = []
var _bulb_t := 0.0
var _bulb_phase := false
var _gold_target: Node3D = null
var curtain_closed := false
var loge: Node3D

static var _mats := {}

func _ready() -> void:
	_build_environment()
	_build_floor()
	_build_trapdoors()
	_build_pit()
	_build_curtains()
	_build_proscenium()
	_build_board()
	_build_lights()
	_build_dust()
	_build_audience()
	_build_balcony_box()
	_build_bounds()

func _process(delta: float) -> void:
	_bulb_t += delta
	if _bulb_t > 0.32:
		_bulb_t = 0.0
		_bulb_phase = not _bulb_phase
		var on := _m_bulb_on()
		var off := _m_bulb_off()
		for b in bulbs_a:
			b.material_override = on if _bulb_phase else off
		for b in bulbs_b:
			b.material_override = off if _bulb_phase else on
	if _gold_target and is_instance_valid(_gold_target) and gold_spot.visible:
		var p := _gold_target.global_position
		var want := Vector3(p.x * 0.6, 9.0, p.z + 3.0)
		gold_spot.global_position = gold_spot.global_position.lerp(want, 1.0 - exp(-4.0 * delta))
		gold_spot.look_at(p + Vector3(0, 0.6, 0), Vector3.UP)

# ── malzemeler ──────────────────────────────────────────────────────
static func _noise_normal(freq: float, strength: float, cell := false) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_CELLULAR if cell else FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	var t := NoiseTexture2D.new()
	t.width = 512
	t.height = 512
	t.seamless = true
	t.as_normal_map = true
	t.bump_strength = strength
	t.noise = n
	return t

static func m_velvet(c: Color, key := "velvet") -> StandardMaterial3D:
	var k := key + c.to_html()
	if _mats.has(k):
		return _mats[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.82
	m.rim_enabled = true
	m.rim = 0.9
	m.rim_tint = 0.75
	m.normal_enabled = true
	m.normal_texture = _noise_normal(0.02, 1.4)
	m.normal_scale = 0.35
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[k] = m
	return m

static func m_carpet() -> StandardMaterial3D:
	if _mats.has("carpet"):
		return _mats.carpet
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("3C0B13")
	m.roughness = 0.95
	m.rim_enabled = true
	m.rim = 0.6
	m.rim_tint = 0.8
	m.normal_enabled = true
	m.normal_texture = _noise_normal(0.12, 2.2, true)
	m.normal_scale = 0.4
	m.uv1_scale = Vector3(6, 6, 6)
	m.uv1_triplanar = true
	_mats.carpet = m
	return m

static func m_gold() -> StandardMaterial3D:
	if _mats.has("gold"):
		return _mats.gold
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("C8973C")
	m.metallic = 1.0
	m.roughness = 0.32
	_mats.gold = m
	return m

static func m_brass_dark() -> StandardMaterial3D:
	if _mats.has("brassd"):
		return _mats.brassd
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("7A5320")
	m.metallic = 0.9
	m.roughness = 0.45
	_mats.brassd = m
	return m

static func m_wood(c: Color) -> StandardMaterial3D:
	var k := "wood" + c.to_html()
	if _mats.has(k):
		return _mats[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.5
	m.clearcoat_enabled = true
	m.clearcoat = 0.35
	m.clearcoat_roughness = 0.3
	m.normal_enabled = true
	m.normal_texture = _noise_normal(0.006, 0.8)
	m.normal_scale = 0.25
	m.uv1_triplanar = true
	_mats[k] = m
	return m

static func m_plain(c: Color, rough := 0.8, key := "") -> StandardMaterial3D:
	var k := "plain" + c.to_html() + str(rough) + key
	if _mats.has(k):
		return _mats[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	_mats[k] = m
	return m

func _m_bulb_on() -> StandardMaterial3D:
	if _mats.has("bulb_on"):
		return _mats.bulb_on
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("FFE7B0")
	m.emission_enabled = true
	m.emission = Color("FFC766")
	m.emission_energy_multiplier = 4.0
	_mats.bulb_on = m
	return m

func _m_bulb_off() -> StandardMaterial3D:
	if _mats.has("bulb_off"):
		return _mats.bulb_off
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("B08A55")
	m.emission_enabled = true
	m.emission = Color("FF9A40")
	m.emission_energy_multiplier = 0.6
	_mats.bulb_off = m
	return m

# ── yardımcılar ─────────────────────────────────────────────────────
func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, collide := false, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	if collide:
		var sb := StaticBody3D.new()
		sb.collision_layer = 2
		sb.collision_mask = 0
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		sb.add_child(cs)
		sb.position = pos
		sb.rotation = rot
		parent.add_child(sb)
		mi.position = Vector3.ZERO
		mi.rotation = Vector3.ZERO
		sb.add_child(mi)
	else:
		parent.add_child(mi)
	return mi

func _cyl(parent: Node3D, r_top: float, r_bot: float, h: float, pos: Vector3, mat: Material, rot := Vector3.ZERO, seg := 24) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = seg
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi

func _sphere(parent: Node3D, r: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

## Kıvrımlı kumaş: x boyunca sinüs katlar, altta derinleşir.
## scallop > 0 ise alt kenar fistolu (sahne üst saçağı için).
static func curtain_mesh(width: float, height: float, folds: float, depth: float, scallop := 0.0, cols := 72, rows := 20) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in rows + 1:
		var v := float(r) / rows
		for c in cols + 1:
			var u := float(c) / cols
			var x := (u - 0.5) * width
			var y := height * (1.0 - v)
			if scallop > 0.0 and r == rows:
				y += scallop * (1.0 - abs(sin(u * PI * folds * 0.5)))
			var z := sin(u * folds * TAU) * depth * (0.55 + 0.45 * v) + sin(u * folds * TAU * 2.3) * depth * 0.12
			st.set_uv(Vector2(u * folds, v * 2.0))
			st.add_vertex(Vector3(x, y, z))
	for r in rows:
		for c in cols:
			var i := r * (cols + 1) + c
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + cols + 1)
			st.add_index(i + 1)
			st.add_index(i + cols + 2)
			st.add_index(i + cols + 1)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()

func _curtain(parent: Node3D, width: float, height: float, folds: float, depth: float, pos: Vector3, rot_y := 0.0, mat: Material = null, scallop := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = curtain_mesh(width, height, folds, depth, scallop)
	mi.material_override = mat if mat else m_velvet(Color("6E0B19"))
	mi.position = pos
	mi.rotation.y = rot_y
	parent.add_child(mi)
	return mi

# ── ortam ───────────────────────────────────────────────────────────
func _build_environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("050306")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("3A2A36")
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.65
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.5
	env.ssao_enabled = true
	env.ssao_radius = 1.1
	env.ssao_intensity = 1.8
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.018
	env.volumetric_fog_albedo = Color(0.95, 0.9, 0.85)
	env.volumetric_fog_anisotropy = 0.55
	env.volumetric_fog_length = 40.0
	env.volumetric_fog_ambient_inject = 0.05
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.12
	we.environment = env
	add_child(we)

# ── zemin ───────────────────────────────────────────────────────────
func _build_floor() -> void:
	var root := Node3D.new()
	root.name = "Floor"
	add_child(root)
	var carpet := m_carpet()
	var t := 0.3
	# kapak alanının etrafındaki halı şeritleri (çarpışmalı)
	_box(root, Vector3(STAGE_W, t, TRAP_Z0 - BACK_Z), Vector3(0, -t / 2, (BACK_Z + TRAP_Z0) / 2), carpet, true)
	_box(root, Vector3(STAGE_W, t, FRONT_Z - TRAP_Z1), Vector3(0, -t / 2, (TRAP_Z1 + FRONT_Z) / 2), carpet, true)
	var side_w := STAGE_W / 2 - TRAP_X
	for s: int in [-1, 1]:
		_box(root, Vector3(side_w, t, TRAP_Z1 - TRAP_Z0), Vector3(s * (TRAP_X + side_w / 2), -t / 2, (TRAP_Z0 + TRAP_Z1) / 2), carpet, true)
	# kenardaki cilalı sahne tahtaları (halının altından görünür)
	var woods := [Color("5A3518"), Color("61391B"), Color("4E2E14"), Color("6A4020")]
	for i in 14:
		var x := -STAGE_W / 2 - 1.2 + i * ((STAGE_W + 2.4) / 13.0)
		_box(root, Vector3((STAGE_W + 2.4) / 13.0 - 0.02, 0.2, 0.9), Vector3(x, -0.12, FRONT_Z + 0.02), m_wood(woods[i % woods.size()]), false)
	# sahne ağzı ön yüzü (apron) + yaldızlı pervaz
	_box(root, Vector3(STAGE_W + 2.6, 1.7, 0.2), Vector3(0, -0.95, FRONT_Z + 0.45), m_wood(Color("3A1F0E")), true)
	_box(root, Vector3(STAGE_W + 2.6, 0.08, 0.1), Vector3(0, -0.06, FRONT_Z + 0.52), m_gold())
	_box(root, Vector3(STAGE_W + 2.6, 0.05, 0.08), Vector3(0, -1.75, FRONT_Z + 0.55), m_gold())
	# ön ışık oluğu: pirinç kapaklı ampuller
	var n := 13
	for i in n:
		var x := lerpf(-7.2, 7.2, float(i) / (n - 1))
		_cyl(root, 0.12, 0.16, 0.16, Vector3(x, 0.06, FRONT_Z + 0.25), m_brass_dark(), Vector3(-0.5, 0, 0), 12)
		var b := _sphere(root, 0.07, Vector3(x, 0.1, FRONT_Z + 0.33), _m_bulb_on())
		(bulbs_a if i % 2 == 0 else bulbs_b).append(b)
	# orkestra çukuru tabanı (öne düşen buraya iner)
	_box(root, Vector3(STAGE_W + 6, 0.4, 5.0), Vector3(0, -2.2, FRONT_Z + 3.2), m_plain(Color("120709")), true)

func _build_trapdoors() -> void:
	var root := Node3D.new()
	root.name = "Trapdoors"
	add_child(root)
	var w := TRAP_X - GAP / 2
	var d := (TRAP_Z1 - TRAP_Z0) / 2 - GAP / 2
	var t := 0.14
	for i in 4:
		var left := i % 2 == 0
		var back := i < 2
		var x0 := -TRAP_X if left else GAP / 2
		var z0 := TRAP_Z0 if back else TRAP_Z0 + d + GAP
		# menteşe dış kenarda: soldakiler sola, sağdakiler sağa doğru aşağı açılır
		var hinge_x := x0 if left else x0 + w
		var body := TrapDoor.new()
		body.name = "Trap" + LETTERS[i]
		body.hinge = Transform3D(Basis.IDENTITY, Vector3(hinge_x, 0, z0 + d / 2))
		body.offset = Vector3((w / 2) * (1 if left else -1), -t / 2, 0)
		root.add_child(body)
		body.angle = 0.0
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(w, t, d)
		cs.shape = sh
		body.add_child(cs)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(w, t, d)
		mi.mesh = bm
		mi.material_override = m_carpet()
		body.add_child(mi)
		# pirinç kenar çıtaları (lobide de kapakların yeri sezilsin)
		for s: int in [-1, 1]:
			var rail := MeshInstance3D.new()
			var rb := BoxMesh.new()
			rb.size = Vector3(w, 0.03, 0.05)
			rail.mesh = rb
			rail.material_override = m_brass_dark()
			rail.position = Vector3(0, t / 2 + 0.005, s * (d / 2 - 0.03))
			body.add_child(rail)
		# harf ve şık yazısı zemine işli (yalnızca Trivia'da görünür); kameraya doğru hafif eğik
		var letter := Label3D.new()
		letter.text = LETTERS[i]
		letter.font = load("res://assets/fonts/Limelight-Regular.ttf")
		letter.font_size = 300
		letter.pixel_size = 0.0034
		letter.modulate = Color(ZONE_COLORS[i], 0.9)
		letter.outline_size = 0
		letter.rotation = Vector3(-PI / 2, 0, 0)
		letter.position = Vector3(0, t / 2 + 0.01, -d * 0.18)
		letter.visible = false
		body.add_child(letter)
		zone_letters.append(letter)
		var lab := Label3D.new()
		lab.font = load("res://assets/fonts/PlayfairDisplay.ttf")
		lab.font_size = 64
		lab.pixel_size = 0.0052
		lab.outline_size = 14
		lab.outline_modulate = Color(0.06, 0.02, 0.02, 0.95)
		lab.modulate = Color("FFF1D6")
		lab.width = 820
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.rotation = Vector3(-PI / 2 + 0.55, 0, 0)
		lab.position = Vector3(0, t / 2 + 0.05, d * 0.27)
		lab.visible = false
		body.add_child(lab)
		zone_labels.append(lab)
		trapdoors.append(body)

func zone_center(i: int) -> Vector3:
	var w := TRAP_X - GAP / 2
	var d := (TRAP_Z1 - TRAP_Z0) / 2 - GAP / 2
	var left := i % 2 == 0
	var back := i < 2
	var x := -TRAP_X + w / 2 if left else GAP / 2 + w / 2
	var z := TRAP_Z0 + d / 2 if back else TRAP_Z0 + d + GAP + d / 2
	return Vector3(x, 0, z)

## Konumun hangi kapağın üstünde olduğu; hiçbiri değilse -1.
func zone_at(p: Vector3) -> int:
	if p.x < -TRAP_X or p.x > TRAP_X or p.z < TRAP_Z0 or p.z > TRAP_Z1:
		return -1
	var col := 0 if p.x < 0.0 else 1
	var row := 0 if p.z < (TRAP_Z0 + TRAP_Z1) / 2 else 1
	return row * 2 + col

func zone_half_extents() -> Vector2:
	return Vector2((TRAP_X - GAP / 2) / 2, ((TRAP_Z1 - TRAP_Z0) / 2 - GAP / 2) / 2)

func set_zones_visible(on: bool) -> void:
	for l in zone_letters:
		l.visible = on
	for l in zone_labels:
		l.visible = on
	for s in zone_lights:
		s.visible = on

func set_zone_texts(opts: Array) -> void:
	for i in 4:
		zone_labels[i].text = String(opts[i]) if i < opts.size() else ""

## Kapağı aç (aşağı sarkar) / kapat. Fizik karesinde döner ki üstündekiler düşsün.
func open_trapdoor(i: int, open := true, dur := 0.45) -> Tween:
	var door := trapdoors[i]
	var left := i % 2 == 0
	var ang := deg_to_rad(-100.0) if left else deg_to_rad(100.0)
	var tw := create_tween()
	tw.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_property(door, "angle", ang if open else 0.0, dur).set_trans(Tween.TRANS_QUAD if open else Tween.TRANS_BACK).set_ease(Tween.EASE_IN if open else Tween.EASE_OUT)
	return tw

func close_all_trapdoors() -> void:
	for i in 4:
		open_trapdoor(i, false, 0.6)

func trapdoor_open(i: int) -> bool:
	return abs(trapdoors[i].angle) > 0.5

func flash_zone(i: int, c: Color) -> void:
	var s := zone_lights[i]
	s.light_color = c
	var tw := create_tween()
	s.light_energy = 60.0
	tw.tween_property(s, "light_energy", 18.0, 0.8)

func _build_pit() -> void:
	# kapakların altı: derin, karanlık kuyu; dipte kırmızı bir ışık
	var root := Node3D.new()
	root.name = "Pit"
	add_child(root)
	var dark := m_plain(Color("0B0506"), 0.95)
	var wdt := TRAP_X * 2 + 0.4
	var dpt := TRAP_Z1 - TRAP_Z0 + 0.4
	var cz := (TRAP_Z0 + TRAP_Z1) / 2
	_box(root, Vector3(wdt, 0.4, dpt), Vector3(0, -7.2, cz), dark, true)
	for s: int in [-1, 1]:
		_box(root, Vector3(0.3, 7, dpt), Vector3(s * (wdt / 2 + 0.15), -3.6, cz), dark, true)
		_box(root, Vector3(wdt, 7, 0.3), Vector3(0, -3.6, cz + s * (dpt / 2 + 0.15)), dark, true)
	var glow := OmniLight3D.new()
	glow.position = Vector3(0, -5.5, cz)
	glow.light_color = Color("FF3A2A")
	glow.light_energy = 3.0
	glow.omni_range = 9.0
	root.add_child(glow)

# ── perdeler ────────────────────────────────────────────────────────
func _build_curtains() -> void:
	var root := Node3D.new()
	root.name = "Curtains"
	add_child(root)
	var red := m_velvet(Color("6E0B19"))
	var deep := m_velvet(Color("4A0610"), "deep")
	# arka fon perdesi (iki kat, derin kıvrımlı)
	_curtain(root, 19.0, 9.5, 11.0, 0.32, Vector3(0, 0, BACK_Z - 0.9), 0.0, deep)
	_curtain(root, 18.0, 9.0, 14.0, 0.26, Vector3(0, 0, BACK_Z - 0.45), 0.0, red)
	# yan kanat perdeleri (üç kat, kulis)
	for s: int in [-1, 1]:
		for k in 3:
			var z := -3.6 + k * 2.6
			var mi := _curtain(root, 2.6, 9.0, 3.0, 0.22, Vector3(s * (8.6 - k * 0.15), 0, z), s * deg_to_rad(-70.0), red if k % 2 == 0 else deep)
			mi.name = "Wing"
	# üst saçak (fistolu), altın saçakla
	var border := _curtain(root, 19.4, 1.5, 9.0, 0.16, Vector3(0, 7.25, FRONT_Z + 0.1), 0.0, red, 0.4)
	border.name = "Border"
	_box(root, Vector3(19.2, 0.06, 0.06), Vector3(0, 7.02, FRONT_Z + 0.22), m_gold())
	# ana perde (önde, geçişlerde kapanır) — iki yarım
	house_l = Node3D.new()
	house_r = Node3D.new()
	root.add_child(house_l)
	root.add_child(house_r)
	for pair in [[house_l, -1], [house_r, 1]]:
		var n: Node3D = pair[0]
		var s: int = pair[1]
		var c := _curtain(n, 9.4, 8.2, 6.5, 0.34, Vector3.ZERO, 0.0, red)
		c.position = Vector3(0, -0.3, 0)
		# altın püskül ve bağ
		_box(n, Vector3(9.4, 0.12, 0.05), Vector3(0, -0.2, 0.3), m_gold())
		n.position = Vector3(s * 13.8, 0, FRONT_Z + 0.35)
	# açıkken kenarlarda toplanmış perde dökümü (bağlı)
	for s: int in [-1, 1]:
		var g := _curtain(root, 2.2, 8.0, 5.0, 0.2, Vector3(s * 8.3, 0, FRONT_Z + 0.35), 0.0, red)
		g.name = "Swag"
		_cyl(root, 0.05, 0.05, 1.3, Vector3(s * 8.3, 3.2, FRONT_Z + 0.62), m_gold(), Vector3(0, 0, PI / 2), 10)
		_sphere(root, 0.12, Vector3(s * 7.7, 3.05, FRONT_Z + 0.65), m_gold())

## Ana perdeyi kapat/aç. Kapanınca sinyal verir.
func set_curtain(closed: bool, dur := 1.3) -> void:
	curtain_closed = closed
	Sfx.play("whoosh", -4.0, 0.8 if closed else 1.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(house_l, "position:x", -4.62 if closed else -13.8, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(house_r, "position:x", 4.62 if closed else 13.8, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.chain().tween_callback(func(): curtain_done.emit(closed))

# ── sahne ağzı ──────────────────────────────────────────────────────
func _build_proscenium() -> void:
	var root := Node3D.new()
	root.name = "Proscenium"
	add_child(root)
	var lacquer := m_wood(Color("3B0A10"))
	var gold := m_gold()
	var z := FRONT_Z + 0.75
	for s: int in [-1, 1]:
		var x: float = s * 9.6
		_box(root, Vector3(1.6, 11.0, 0.9), Vector3(x, 3.6, z), lacquer, true)
		# yaldızlı yivli sütun
		for k in 4:
			_cyl(root, 0.07, 0.07, 8.8, Vector3(x - 0.45 + k * 0.3, 3.6, z + 0.5), gold, Vector3.ZERO, 10)
		_box(root, Vector3(1.9, 0.35, 1.1), Vector3(x, -0.2, z), gold)
		_box(root, Vector3(1.9, 0.5, 1.1), Vector3(x, 8.1, z), gold)
	# üst kiriş + arma
	_box(root, Vector3(20.8, 1.6, 0.9), Vector3(0, 9.0, z), lacquer)
	_box(root, Vector3(20.8, 0.12, 1.0), Vector3(0, 8.2, z + 0.05), gold)
	_box(root, Vector3(20.8, 0.12, 1.0), Vector3(0, 9.8, z + 0.05), gold)
	var crest := _cyl(root, 1.05, 1.05, 0.2, Vector3(0, 9.0, z + 0.5), gold, Vector3(PI / 2, 0, 0), 32)
	crest.name = "Crest"
	var mask := Label3D.new()
	mask.text = "TA"
	mask.font = load("res://assets/fonts/Limelight-Regular.ttf")
	mask.font_size = 160
	mask.pixel_size = 0.006
	mask.modulate = Color("3B0A10")
	mask.outline_size = 0
	mask.position = Vector3(0, 9.0, z + 0.62)
	root.add_child(mask)

# ── soru panosu ─────────────────────────────────────────────────────
func _build_board() -> void:
	var root := Node3D.new()
	root.name = "Board"
	root.position = Vector3(0, 5.35, BACK_Z - 0.2)
	add_child(root)
	board_viewport = SubViewport.new()
	board_viewport.size = Vector2i(BoardScreen.W, BoardScreen.H)
	board_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	board_viewport.transparent_bg = false
	add_child(board_viewport)
	board = BoardScreen.new()
	board_viewport.add_child(board)
	board.show_marquee(I18n.t("arena.lobby_board"))

	var w := 7.6
	var h := w * BoardScreen.H / BoardScreen.W
	var screen := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	screen.mesh = q
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_texture = board_viewport.get_texture()
	sm.emission_enabled = false
	screen.material_override = sm
	screen.position = Vector3(0, 0, 0.08)
	root.add_child(screen)
	# yaldızlı çerçeve + ampul dizisi
	var gold := m_gold()
	var fw := 0.28
	_box(root, Vector3(w + fw * 2, fw, 0.3), Vector3(0, h / 2 + fw / 2, 0), gold)
	_box(root, Vector3(w + fw * 2, fw, 0.3), Vector3(0, -h / 2 - fw / 2, 0), gold)
	_box(root, Vector3(fw, h, 0.3), Vector3(-w / 2 - fw / 2, 0, 0), gold)
	_box(root, Vector3(fw, h, 0.3), Vector3(w / 2 + fw / 2, 0, 0), gold)
	_box(root, Vector3(w + 1.2, h + 1.0, 0.12), Vector3(0, 0, -0.12), m_wood(Color("2A0B0E")))
	var count := 0
	var per := [[22, h / 2 + fw + 0.14, true], [22, -h / 2 - fw - 0.14, true], [9, -w / 2 - fw - 0.14, false], [9, w / 2 + fw + 0.14, false]]
	for side in per:
		var n: int = side[0]
		for i in n:
			var k := (float(i) + 0.5) / n
			var pos := Vector3.ZERO
			if side[2]:
				pos = Vector3(lerp(-w / 2 - 0.2, w / 2 + 0.2, k), side[1], 0.18)
			else:
				pos = Vector3(side[1], lerp(-h / 2, h / 2, k), 0.18)
			var b := _sphere(root, 0.075, pos, _m_bulb_on())
			(bulbs_a if count % 2 == 0 else bulbs_b).append(b)
			count += 1
	# asma zincirleri
	for s: int in [-1, 1]:
		_cyl(root, 0.025, 0.025, 4.0, Vector3(s * (w / 2 - 0.4), h / 2 + 2.2, 0), m_brass_dark(), Vector3.ZERO, 8)

# ── ışık ────────────────────────────────────────────────────────────
func _spot(pos: Vector3, look: Vector3, color: Color, energy: float, angle: float, vol: float, shadows := false, rng := 28.0) -> SpotLight3D:
	var s := SpotLight3D.new()
	s.light_color = color
	s.light_energy = energy
	s.spot_angle = angle
	s.spot_range = rng
	s.spot_attenuation = 0.6
	s.spot_angle_attenuation = 1.4
	s.light_volumetric_fog_energy = vol
	s.shadow_enabled = shadows
	add_child(s)
	s.global_position = pos
	s.look_at(look, Vector3.UP)
	return s

func _build_lights() -> void:
	main_lights.append(_spot(Vector3(0, 11.0, 10.5), Vector3(0, 0, -0.8), Color(1.0, 0.88, 0.74), 7.5, 29.0, 1.1, true, 30.0))
	main_lights.append(_spot(Vector3(-9.5, 10.5, 6.5), Vector3(-3.4, 0, -0.8), Color(1.0, 0.8, 0.55), 11.0, 13.0, 2.6, true))
	main_lights.append(_spot(Vector3(9.5, 10.5, 6.5), Vector3(3.4, 0, -0.8), Color(0.95, 0.78, 1.0), 10.0, 13.0, 2.6, false))
	main_lights.append(_spot(Vector3(0, 9.5, -7.5), Vector3(0, 0, -1.0), Color(0.75, 0.25, 0.6), 3.0, 40.0, 0.9, false))
	main_lights.append(_spot(Vector3(0, 8.0, -3.0), Vector3(0, 5.3, BACK_Z), Color(1.0, 0.8, 0.55), 2.0, 40.0, 0.4, false, 14.0))
	for i in 4:
		var x := lerpf(-6.0, 6.0, i / 3.0)
		var o := OmniLight3D.new()
		o.position = Vector3(x, 0.35, FRONT_Z + 0.2)
		o.light_color = Color(1.0, 0.72, 0.42)
		o.light_energy = 0.4
		o.omni_range = 4.5
		add_child(o)
	# sahne ağzını yıkayan sıcak yukarı ışıklar ve salonun loş ışığı
	for sx: int in [-1, 1]:
		var up := _spot(Vector3(sx * 9.6, -0.5, FRONT_Z + 2.6), Vector3(sx * 9.6, 7.5, FRONT_Z + 0.9), Color(1.0, 0.7, 0.4), 6.0, 22.0, 0.3, false, 14.0)
		up.name = "ProsUp"
	var house := OmniLight3D.new()
	house.position = Vector3(0, 2.2, FRONT_Z + 6.0)
	house.light_color = Color(1.0, 0.62, 0.42)
	house.light_energy = 1.2
	house.omni_range = 9.0
	add_child(house)
	# kapak bölgesi ışıkları (Trivia)
	for i in 4:
		var c := zone_center(i)
		var s := _spot(c + Vector3(0, 8.5, 2.5), c, ZONE_COLORS[i], 18.0, 16.0, 1.2, false, 16.0)
		s.visible = false
		zone_lights.append(s)
	# seri liderinin altın spotu
	gold_spot = _spot(Vector3(0, 9, 3), Vector3.ZERO, Color(1.0, 0.8, 0.35), 40.0, 6.5, 2.5, false, 16.0)
	gold_spot.visible = false
	# kostüm odası için tek spot
	solo_spot = _spot(Vector3(0, 9.5, 2.6), Vector3(0, 0, 0.7), Color(1.0, 0.93, 0.82), 9.0, 11.0, 2.2, true, 16.0)
	solo_spot.visible = false

# ── kişisel kapak (tur 3'te ölüm) ───────────────────────────────────
## Oyuncunun ayağının altında küçük yuvarlak bir kapak açılır, sonra kapanır.
func spawn_hatch(pos: Vector3) -> void:
	var root := Node3D.new()
	add_child(root)
	root.global_position = Vector3(pos.x, 0.012, pos.z)
	var hole := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.62
	hm.bottom_radius = 0.62
	hm.height = 0.01
	hole.mesh = hm
	hole.material_override = m_plain(Color("020102"), 1.0, "hole")
	root.add_child(hole)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.6
	tm.outer_radius = 0.7
	ring.mesh = tm
	ring.material_override = m_gold()
	root.add_child(ring)
	var flaps: Array[Node3D] = []
	for side: int in [-1, 1]:
		var hinge := Node3D.new()
		hinge.position = Vector3(side * 0.6, 0, 0)
		root.add_child(hinge)
		var flap := MeshInstance3D.new()
		var fb := BoxMesh.new()
		fb.size = Vector3(0.6, 0.04, 1.1)
		flap.mesh = fb
		flap.material_override = m_carpet()
		flap.position = Vector3(-side * 0.3, 0.0, 0)
		hinge.add_child(flap)
		flaps.append(hinge)
	root.scale = Vector3(0.2, 1, 0.2)
	var tw := create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.set_parallel(true)
	tw.tween_property(flaps[0], "rotation:z", deg_to_rad(-95.0), 0.3).set_delay(0.18)
	tw.tween_property(flaps[1], "rotation:z", deg_to_rad(95.0), 0.3).set_delay(0.18)
	tw.set_parallel(false)
	tw.tween_interval(1.4)
	tw.set_parallel(true)
	tw.tween_property(flaps[0], "rotation:z", 0.0, 0.25)
	tw.tween_property(flaps[1], "rotation:z", 0.0, 0.25)
	tw.set_parallel(false)
	tw.tween_property(root, "scale", Vector3(0.01, 1, 0.01), 0.25)
	tw.tween_callback(root.queue_free)
	if not Engine.is_editor_hint():
		Sfx.play("trapdoor", -2.0, 1.3)

# ── kategori halatı daireleri ───────────────────────────────────────
const TUG_POS := [Vector3(-3.7, 0, -0.3), Vector3(0, 0, -0.3), Vector3(3.7, 0, -0.3)]
const TUG_R := 1.35
var _tug_nodes: Array[Node3D] = []

func show_tug(names: Array, colors: Array) -> void:
	hide_tug()
	for i in names.size():
		var root := Node3D.new()
		add_child(root)
		root.position = TUG_POS[i] + Vector3(0, 0.02, 0)
		var disc := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = TUG_R
		cm.bottom_radius = TUG_R
		cm.height = 0.02
		cm.radial_segments = 48
		disc.mesh = cm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(colors[i], 0.55)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.emission_enabled = true
		m.emission = colors[i]
		m.emission_energy_multiplier = 0.4
		disc.material_override = m
		disc.name = "Disc"
		root.add_child(disc)
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = TUG_R - 0.05
		tm.outer_radius = TUG_R + 0.06
		tm.ring_segments = 12
		tm.rings = 48
		ring.mesh = tm
		ring.material_override = m_gold()
		root.add_child(ring)
		var lab := Label3D.new()
		lab.text = String(names[i]).to_upper()
		lab.font = load("res://assets/fonts/BigShoulders.ttf")
		lab.font_size = 96
		lab.pixel_size = 0.006
		lab.outline_size = 16
		lab.outline_modulate = Color(0.06, 0.02, 0.02)
		lab.modulate = Color(colors[i]).lightened(0.35)
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lab.position = Vector3(0, 2.3, 0)
		lab.name = "Label"
		root.add_child(lab)
		root.scale = Vector3(0.01, 1, 0.01)
		create_tween().tween_property(root, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(i * 0.12)
		_tug_nodes.append(root)

## Halattaki payına göre dairenin parlaklığı ve yazının boyu
func set_tug_share(i: int, share: float) -> void:
	if i >= _tug_nodes.size():
		return
	var disc: MeshInstance3D = _tug_nodes[i].get_node("Disc")
	(disc.material_override as StandardMaterial3D).emission_energy_multiplier = 0.3 + share * 2.5
	_tug_nodes[i].get_node("Label").scale = Vector3.ONE * (0.9 + share * 0.8)

func tug_winner(i: int) -> void:
	for k in _tug_nodes.size():
		var n := _tug_nodes[k]
		var tw := create_tween()
		if k == i:
			tw.tween_property(n, "scale", Vector3(1.25, 1, 1.25), 0.3).set_trans(Tween.TRANS_BACK)
		else:
			tw.tween_property(n, "scale", Vector3(0.01, 1, 0.01), 0.3)

func hide_tug() -> void:
	for n in _tug_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_tug_nodes.clear()

## İzleyici kamerası: locanın içinden, korkuluğun arkasından sahneye bakar.
func loge_camera() -> Dictionary:
	return {"pos": loge.to_global(Vector3(0, 1.45, 0.8)), "look": Vector3(0.5, -0.2, -0.6), "fov": 50.0, "h": 0.0, "sway": 0.25}

func set_gold_target(n: Node3D) -> void:
	_gold_target = n
	gold_spot.visible = n != null
	if n:
		gold_spot.global_position = Vector3(n.global_position.x, 9.0, n.global_position.z + 3.0)

## Kostüm odası: ana ışıkları kıs, tek spotu aç.
func set_solo(on: bool) -> void:
	solo_spot.visible = on
	var tw := create_tween().set_parallel(true)
	for l in main_lights:
		var base: float = l.get_meta("base", l.light_energy)
		l.set_meta("base", base)
		tw.tween_property(l, "light_energy", base * (0.12 if on else 1.0), 0.6)

# ── sahne tozu ──────────────────────────────────────────────────────
func _build_dust() -> void:
	var p := GPUParticles3D.new()
	p.name = "Dust"
	p.amount = 700
	p.lifetime = 18.0
	p.preprocess = 18.0
	p.visibility_aabb = AABB(Vector3(-12, -2, -8), Vector3(24, 14, 20))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(9.5, 4.5, 6.0)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.01
	pm.initial_velocity_max = 0.07
	pm.gravity = Vector3(0, -0.012, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	pm.turbulence_noise_scale = 6.0
	pm.scale_min = 0.5
	pm.scale_max = 1.6
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.016, 0.016)
	var qm := StandardMaterial3D.new()
	qm.albedo_color = Color(1.0, 0.95, 0.85, 0.6)
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.emission_enabled = false
	quad.material = qm
	p.draw_pass_1 = quad
	p.position = Vector3(0, 4.2, -0.5)
	add_child(p)

# ── seyirci koltukları + loca ───────────────────────────────────────
func _build_audience() -> void:
	var root := Node3D.new()
	root.name = "Audience"
	add_child(root)
	var seat := m_velvet(Color("5B0914"), "seat")
	var frame := m_wood(Color("24120A"))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var bm := BoxMesh.new()
	bm.size = Vector3(0.6, 0.75, 0.16)
	mm.mesh = bm
	var xs := []
	for row in 5:
		for col in 22:
			xs.append([row, col])
	mm.instance_count = xs.size()
	for i in xs.size():
		var row: int = xs[i][0]
		var col: int = xs[i][1]
		var x := (col - 10.5) * 0.72 + (0.36 if row % 2 else 0.0)
		var z := FRONT_Z + 3.4 + row * 1.0
		var y := -1.55 + row * 0.38
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.RIGHT, -0.15), Vector3(x, y, z)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = seat
	root.add_child(mmi)
	for row in 5:
		_box(root, Vector3(17.0, 0.38, 1.0), Vector3(0, -1.95 + row * 0.38, FRONT_Z + 3.5 + row * 1.0), frame)

func _build_balcony_box() -> void:
	# sol tarafta yaldızlı bir loca (izleyici kamerası buradan bakar)
	var root := Node3D.new()
	root.name = "Loge"
	root.position = Vector3(-10.8, 4.0, 9.6)
	# locanın önü (+Z yerel) sahnenin ortasına baksın
	root.rotation.y = atan2(0.0 - root.position.x, -0.5 - root.position.z)
	add_child(root)
	loge = root
	var gold := m_gold()
	_box(root, Vector3(2.6, 1.0, 0.14), Vector3(0, 0, 1.1), m_wood(Color("3B0A10")))
	_box(root, Vector3(2.7, 0.1, 0.22), Vector3(0, 0.52, 1.1), gold)
	_box(root, Vector3(2.7, 0.1, 0.22), Vector3(0, -0.5, 1.1), gold)
	for k in 7:
		_cyl(root, 0.03, 0.03, 0.9, Vector3(-1.2 + k * 0.4, 0.02, 1.2), gold, Vector3.ZERO, 8)
	_curtain(root, 1.2, 3.2, 2.0, 0.12, Vector3(-1.3, -0.5, 1.0), 0.0, m_velvet(Color("6E0B19")))
	_curtain(root, 1.2, 3.2, 2.0, 0.12, Vector3(1.3, -0.5, 1.0), 0.0, m_velvet(Color("6E0B19")))
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 0.9, 0.4)
	lamp.light_color = Color(1.0, 0.7, 0.4)
	lamp.light_energy = 1.4
	lamp.omni_range = 3.0
	root.add_child(lamp)

# ── görünmez duvarlar ───────────────────────────────────────────────
func _build_bounds() -> void:
	var root := Node3D.new()
	root.name = "Bounds"
	add_child(root)
	var inv := StandardMaterial3D.new()
	inv.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	inv.albedo_color = Color(0, 0, 0, 0)
	for s: int in [-1, 1]:
		var mi := _box(root, Vector3(0.4, 6, 12), Vector3(s * 8.25, 3, -0.3), inv, true)
		mi.visible = false
	var back := _box(root, Vector3(18, 6, 0.4), Vector3(0, 3, BACK_Z - 0.25), inv, true)
	back.visible = false
