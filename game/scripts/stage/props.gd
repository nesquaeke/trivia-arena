@tool
class_name Props
extends Node3D
## Sahnedeki etkileşimli dekorlar. Hepsi fizikli (RigidBody3D) ve "prop"
## grubunda: karakterler çarpınca devrilir, omuz atınca savrulur.
## Jüri masası sabittir ama üstüne zıplanabilir. Kapak alanının (merkez)
## dışına yerleştirilir ki Trivia sırasında da sahnede kalabilsinler.

## Editörde sahneyi açınca lobi dekorlarını da göster (oyunda main.gd kurar)
@export var preview_in_editor := true

var _mats := {}

func _ready() -> void:
	if Engine.is_editor_hint() and preview_in_editor:
		build_lobby_set()

func build_lobby_set() -> void:
	clear()
	jury_table(Vector3(5.3, 0, 3.55))
	mic_stand(Vector3(-2.3, 0, 3.35))
	mic_stand(Vector3(1.4, 0, 3.5))
	column(Vector3(-7.0, 0, -4.1))
	column(Vector3(7.0, 0, -4.1))
	column(Vector3(-6.7, 0, -0.9))
	column(Vector3(6.8, 0, 1.2))
	question_cutout(Vector3(-6.3, 0, 1.6), 0.08)
	masks(Vector3(6.2, 0, -2.3), -0.3)
	crate(Vector3(-3.6, 0, -4.2), 0.2)
	crate(Vector3(-3.0, 0, -4.35), -0.1)
	crate(Vector3(-3.3, 0.62, -4.25), 0.5)
	crate(Vector3(3.9, 0, -4.2), 0.0)

## Trivia için: ön şeritteki mikrofonlar ve jüri masası kalkar (oyuncular orada dizilir).
func build_arena_set() -> void:
	clear()
	column(Vector3(-7.0, 0, -4.1))
	column(Vector3(7.0, 0, -4.1))
	column(Vector3(-6.7, 0, -0.9))
	column(Vector3(6.8, 0, 1.2))
	question_cutout(Vector3(-6.3, 0, 1.6), 0.08)
	masks(Vector3(6.2, 0, -2.3), -0.3)
	crate(Vector3(-3.6, 0, -4.2), 0.2)
	crate(Vector3(3.9, 0, -4.2), 0.0)

## Conquest için: kenar kürsülerinin yolunu kesmeyen, arkada duran dekorlar.
func build_conquest_set() -> void:
	clear()
	column(Vector3(-7.1, 0, -4.2))
	column(Vector3(7.1, 0, -4.2))
	masks(Vector3(-3.8, 0, -4.35), 0.0)
	question_cutout(Vector3(3.8, 0, -4.35), 0.0)
	crate(Vector3(-5.2, 0, -4.35), 0.2)
	crate(Vector3(5.2, 0, -4.35), -0.3)

func clear() -> void:
	for c in get_children():
		c.queue_free()

# ── malzemeler ──────────────────────────────────────────────────────
func _mat(key: String, c: Color, rough := 0.7, metal := 0.0) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	_mats[key] = m
	return m

func _chrome() -> StandardMaterial3D:
	return _mat("chrome", Color("D8D8DC"), 0.18, 1.0)

# ── yardımcılar ─────────────────────────────────────────────────────
func _body(pos: Vector3, mass: float, yaw := 0.0, com := Vector3.ZERO) -> RigidBody3D:
	var b := RigidBody3D.new()
	b.mass = mass
	b.collision_layer = 1
	b.collision_mask = 1 | 2
	b.add_to_group("prop")
	b.contact_monitor = true
	b.max_contacts_reported = 2
	if com != Vector3.ZERO:
		b.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
		b.center_of_mass = com
	var pm := PhysicsMaterial.new()
	pm.friction = 0.7
	pm.bounce = 0.15
	b.physics_material_override = pm
	b.position = pos
	b.rotation.y = yaw
	add_child(b)
	var cool := [0.0]
	b.body_entered.connect(func(_o):
		var now := Time.get_ticks_msec() / 1000.0
		if now - cool[0] > 0.25 and b.linear_velocity.length() > 2.2:
			cool[0] = now
			Sfx.play("thud", -10.0 + min(8.0, b.mass), randf_range(0.8, 1.2)))
	return b

func _shape(b: CollisionObject3D, sh: Shape3D, pos := Vector3.ZERO, rot := Vector3.ZERO) -> void:
	var cs := CollisionShape3D.new()
	cs.shape = sh
	cs.position = pos
	cs.rotation = rot
	b.add_child(cs)

func _mesh(parent: Node3D, mesh: Mesh, m: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi

func _boxm(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b

func _boxs(size: Vector3) -> BoxShape3D:
	var b := BoxShape3D.new()
	b.size = size
	return b

func _cylm(rt: float, rb: float, h: float, seg := 20) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = rt
	c.bottom_radius = rb
	c.height = h
	c.radial_segments = seg
	return c

func _cyls(r: float, h: float) -> CylinderShape3D:
	var c := CylinderShape3D.new()
	c.radius = r
	c.height = h
	return c

func _sph(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2
	return s

# ── dekorlar ────────────────────────────────────────────────────────
## Vintage ayaklı mikrofon (devrilir, yuvarlanır)
func mic_stand(pos: Vector3) -> RigidBody3D:
	var b := _body(pos, 2.4, 0.0, Vector3(0, 0.35, 0))
	var chrome := _chrome()
	var black := _mat("mic_black", Color("141214"), 0.35, 0.3)
	_mesh(b, _cylm(0.26, 0.3, 0.06, 28), black, Vector3(0, 0.03, 0))
	_mesh(b, _cylm(0.022, 0.022, 1.45, 10), chrome, Vector3(0, 0.78, 0))
	_mesh(b, _cylm(0.04, 0.04, 0.08, 12), chrome, Vector3(0, 0.95, 0))
	# 1950'ler usulü kapsül mikrofon
	_mesh(b, _cylm(0.03, 0.03, 0.12, 10), chrome, Vector3(0, 1.52, 0.02), Vector3(0.5, 0, 0))
	var head := _mesh(b, _sph(0.085), chrome, Vector3(0, 1.62, 0.07), Vector3.ZERO, Vector3(1, 1.45, 0.9))
	for k in 5:
		_mesh(head, _cylm(0.088, 0.088, 0.006, 16), black, Vector3(0, -0.06 + k * 0.03, 0))
	_shape(b, _cyls(0.28, 0.06), Vector3(0, 0.03, 0))
	_shape(b, _cyls(0.03, 1.5), Vector3(0, 0.8, 0))
	var hs := SphereShape3D.new()
	hs.radius = 0.1
	_shape(b, hs, Vector3(0, 1.62, 0.07))
	return b

## Karton sütun: boyalı mermer görünümlü, hafif — kolay devrilir
func column(pos: Vector3) -> RigidBody3D:
	var b := _body(pos, 2.6, randf() * TAU, Vector3(0, 0.9, 0))
	var marble := _mat("marble", Color("D9CDBA"), 0.85)
	var trim := _mat("coltrim", Color("B8893B"), 0.4, 0.6)
	_mesh(b, _boxm(Vector3(0.9, 0.3, 0.9)), marble, Vector3(0, 0.15, 0))
	_mesh(b, _boxm(Vector3(0.94, 0.05, 0.94)), trim, Vector3(0, 0.31, 0))
	_mesh(b, _cylm(0.3, 0.34, 2.6, 12), marble, Vector3(0, 1.62, 0))
	_mesh(b, _boxm(Vector3(0.84, 0.22, 0.84)), marble, Vector3(0, 3.03, 0))
	_mesh(b, _boxm(Vector3(0.88, 0.05, 0.88)), trim, Vector3(0, 2.9, 0))
	# kartonun iç yüzü görünsün diye tepeye kahverengi kapak
	_mesh(b, _boxm(Vector3(0.8, 0.02, 0.8)), _mat("cardboard", Color("8C6A43"), 1.0), Vector3(0, 3.15, 0))
	_shape(b, _boxs(Vector3(0.9, 0.3, 0.9)), Vector3(0, 0.15, 0))
	_shape(b, _cyls(0.32, 2.6), Vector3(0, 1.62, 0))
	_shape(b, _boxs(Vector3(0.84, 0.22, 0.84)), Vector3(0, 3.03, 0))
	return b

## Dev karton soru işareti
func question_cutout(pos: Vector3, yaw := 0.0) -> RigidBody3D:
	var b := _body(pos, 1.6, yaw, Vector3(0, 0.6, 0))
	var tm := TextMesh.new()
	tm.text = "?"
	tm.font = Pal.display()
	tm.font_size = 180
	tm.pixel_size = 0.012
	tm.depth = 0.12
	var face := _mat("q_face", Color("E9B53A"), 0.75)
	_mesh(b, tm, face, Vector3(0, 1.25, 0))
	# arka destek ayağı ve taban
	var card := _mat("cardboard", Color("8C6A43"), 1.0)
	_mesh(b, _boxm(Vector3(0.9, 0.08, 0.6)), card, Vector3(0, 0.04, 0))
	_mesh(b, _boxm(Vector3(0.06, 1.2, 0.5)), card, Vector3(0, 0.6, -0.25), Vector3(0.35, 0, 0))
	_shape(b, _boxs(Vector3(1.3, 2.2, 0.16)), Vector3(0, 1.2, 0))
	_shape(b, _boxs(Vector3(0.9, 0.08, 0.6)), Vector3(0, 0.04, 0))
	return b

## Komedi ve trajedi maskeleri bir direk üstünde
func masks(pos: Vector3, yaw := 0.0) -> RigidBody3D:
	var b := _body(pos, 2.0, yaw, Vector3(0, 0.5, 0))
	var wood := _mat("pole", Color("3A2212"), 0.5)
	var dark := _mat("maskhole", Color("140A06"), 0.9)
	_mesh(b, _cylm(0.3, 0.35, 0.08, 20), wood, Vector3(0, 0.04, 0))
	_mesh(b, _cylm(0.04, 0.04, 1.6, 10), wood, Vector3(0, 0.85, 0))
	var defs := [[-0.32, _mat("mask_gold", Color("D6A93F"), 0.3, 0.9), 1.0, -0.25], [0.32, _mat("mask_silver", Color("C9CCD6"), 0.3, 0.9), -1.0, 0.25]]
	for d in defs:
		var m := Node3D.new()
		m.position = Vector3(d[0], 1.75, 0.06)
		m.rotation.z = d[3]
		b.add_child(m)
		_mesh(m, _sph(0.3), d[1], Vector3.ZERO, Vector3.ZERO, Vector3(0.85, 1.05, 0.28))
		for s: int in [-1, 1]:
			_mesh(m, _sph(0.06), dark, Vector3(s * 0.11, 0.09, 0.075), Vector3(0, 0, s * 0.3 * d[2]), Vector3(1.3, 0.7, 0.3))
		# ağız: gülen maske geniş ve yukarıda, ağlayan dar ve aşağıda
		var smile: bool = d[2] > 0
		_mesh(m, _sph(0.07), dark, Vector3(0, -0.1 if smile else -0.14, 0.075), Vector3(0, 0, 0), Vector3(1.9 if smile else 1.2, 0.55 if smile else 0.45, 0.3))
	_shape(b, _cyls(0.33, 0.08), Vector3(0, 0.04, 0))
	_shape(b, _cyls(0.05, 1.6), Vector3(0, 0.85, 0))
	_shape(b, _boxs(Vector3(1.2, 0.65, 0.2)), Vector3(0, 1.75, 0.06))
	return b

## Jüri masası: sabit; üstüne zıplanır. Önünde kadife örtü, üstünde zil.
func jury_table(pos: Vector3) -> StaticBody3D:
	var s := StaticBody3D.new()
	s.position = pos
	add_child(s)
	var wood := _mat("jury_wood", Color("4A2A14"), 0.45)
	var velvet := Stage.m_velvet(Color("6E0B19"))
	var gold := Stage.m_gold()
	_mesh(s, _boxm(Vector3(3.3, 0.09, 1.0)), wood, Vector3(0, 0.95, 0))
	_mesh(s, _boxm(Vector3(3.3, 0.86, 0.05)), velvet, Vector3(0, 0.5, -0.46))
	_mesh(s, _boxm(Vector3(3.34, 0.05, 0.08)), gold, Vector3(0, 0.9, -0.5))
	for x: float in [-1.55, 1.55]:
		for z: float in [-0.4, 0.4]:
			_mesh(s, _boxm(Vector3(0.09, 0.92, 0.09)), wood, Vector3(x, 0.46, z))
	_shape(s, _boxs(Vector3(3.3, 0.09, 1.0)), Vector3(0, 0.95, 0))
	_shape(s, _boxs(Vector3(3.3, 0.9, 0.08)), Vector3(0, 0.45, -0.44))
	for x: float in [-1.55, 1.55]:
		_shape(s, _boxs(Vector3(0.1, 0.92, 0.9)), Vector3(x, 0.46, 0))
	var plate := Label3D.new()
	plate.text = "JÜRİ"
	plate.font = Pal.display()
	plate.font_size = 96
	plate.pixel_size = 0.004
	plate.modulate = Color("E9C27A")
	plate.outline_size = 8
	plate.outline_modulate = Color(0.1, 0.03, 0.02)
	plate.position = Vector3(0, 0.55, -0.49)
	plate.rotation.y = PI
	s.add_child(plate)
	# sandalyeler (hafif, devrilir) ve zil
	for x: float in [-1.0, 0.0, 1.0]:
		chair(pos + Vector3(x, 0, 0.85))
	bell(pos + Vector3(0.9, 1.0, -0.1))
	return s

func chair(pos: Vector3) -> RigidBody3D:
	var b := _body(pos, 1.2, PI, Vector3(0, 0.4, 0))
	var wood := _mat("chair", Color("3A1E0E"), 0.5)
	var seat := Stage.m_velvet(Color("7A0E1C"), "chair")
	_mesh(b, _boxm(Vector3(0.5, 0.08, 0.5)), seat, Vector3(0, 0.5, 0))
	_mesh(b, _boxm(Vector3(0.5, 0.62, 0.06)), wood, Vector3(0, 0.83, 0.22))
	for x: float in [-0.2, 0.2]:
		for z: float in [-0.2, 0.2]:
			_mesh(b, _boxm(Vector3(0.05, 0.5, 0.05)), wood, Vector3(x, 0.25, z))
	_shape(b, _boxs(Vector3(0.5, 0.5, 0.5)), Vector3(0, 0.27, 0))
	_shape(b, _boxs(Vector3(0.5, 0.62, 0.08)), Vector3(0, 0.83, 0.22))
	return b

func bell(pos: Vector3) -> RigidBody3D:
	var b := _body(pos, 0.4)
	var brass := _mat("bell", Color("D6A93F"), 0.25, 1.0)
	_mesh(b, _cylm(0.09, 0.1, 0.03, 18), _mat("bell_base", Color("2A1A10"), 0.4), Vector3(0, 0.015, 0))
	var dome := SphereMesh.new()
	dome.radius = 0.08
	dome.height = 0.08
	dome.is_hemisphere = true
	_mesh(b, dome, brass, Vector3(0, 0.03, 0))
	_mesh(b, _sph(0.015), brass, Vector3(0, 0.12, 0))
	_shape(b, _cyls(0.1, 0.12), Vector3(0, 0.06, 0))
	var cool := [0.0]
	b.body_entered.connect(func(_o):
		var now := Time.get_ticks_msec() / 1000.0
		if now - cool[0] > 0.4:
			cool[0] = now
			Sfx.play("ding", -6.0))
	return b

func crate(pos: Vector3, yaw := 0.0) -> RigidBody3D:
	var b := _body(pos, 1.0, yaw)
	var wood := _mat("crate", Color("7A5230"), 0.8)
	var dark := _mat("crate_d", Color("4A301A"), 0.8)
	_mesh(b, _boxm(Vector3(0.6, 0.6, 0.6)), wood, Vector3(0, 0.3, 0))
	for s: int in [-1, 1]:
		_mesh(b, _boxm(Vector3(0.62, 0.08, 0.62)), dark, Vector3(0, 0.3 + s * 0.24, 0))
	_mesh(b, _boxm(Vector3(0.62, 0.62, 0.08)), dark, Vector3(0, 0.3, 0), Vector3(0, 0, PI / 4), Vector3(1.2, 0.12, 1))
	_shape(b, _boxs(Vector3(0.6, 0.6, 0.6)), Vector3(0, 0.3, 0))
	return b
