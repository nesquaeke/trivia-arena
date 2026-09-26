class_name StageFx
## Tek atımlık sahne efektleri (konfeti, konfeti topları, parıltı, toz bulutu).
## Hepsi CPUParticles3D: düşük donanımda da çalışır, bitince kendini siler.

const CONFETTI := [Color("F2C66A"), Color("E84A5F"), Color("4FB0E8"), Color("7BD389"), Color("F7F1E3"), Color("B57BE8")]

static func _mat(unshaded := false, billboard := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

static func _ramp(colors: Array) -> Gradient:
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in colors.size():
		offs.append(float(i) / colors.size())
		cols.append(colors[i])
	g.offsets = offs
	g.colors = cols
	return g

static func _emit(parent: Node, ps: CPUParticles3D, pos: Vector3) -> CPUParticles3D:
	if parent == null or not parent.is_inside_tree():
		ps.free()
		return null
	ps.one_shot = true
	parent.add_child(ps)
	ps.global_position = pos
	ps.emitting = true
	parent.get_tree().create_timer(ps.lifetime + 0.6).timeout.connect(ps.queue_free)
	return ps

## Yukarıdan süzülen konfeti yağmuru (pos: yağmurun merkezi, zemin hizası)
static func confetti(parent: Node, pos: Vector3, colors: Array = CONFETTI, amount := 220, width := 5.5) -> void:
	var ps := CPUParticles3D.new()
	ps.amount = amount
	ps.lifetime = 3.6
	ps.explosiveness = 0.55
	var qm := QuadMesh.new()
	qm.size = Vector2(0.07, 0.11)
	qm.material = _mat()
	ps.mesh = qm
	ps.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ps.emission_box_extents = Vector3(width * 0.5, 0.2, 1.4)
	ps.direction = Vector3.DOWN
	ps.spread = 30.0
	ps.initial_velocity_min = 0.2
	ps.initial_velocity_max = 0.9
	ps.gravity = Vector3(0, -1.6, 0)
	ps.damping_min = 0.4
	ps.damping_max = 1.0
	ps.angle_max = 360.0
	ps.angular_velocity_min = -420.0
	ps.angular_velocity_max = 420.0
	ps.scale_amount_min = 0.7
	ps.scale_amount_max = 1.3
	# kâğıt çırpınması: boy ritmik daralıp açılır
	var c := Curve.new()
	for k in 7:
		c.add_point(Vector2(k / 6.0, 1.0 if k % 2 == 0 else 0.35))
	ps.scale_amount_curve = c
	ps.color_initial_ramp = _ramp(colors)
	_emit(parent, ps, pos + Vector3(0, 4.2, 0))

## İki yandan fışkıran konfeti topları + ardından yağmur (kazanan anı)
static func celebrate(parent: Node, center := Vector3(0, 0, 1.2), colors: Array = CONFETTI) -> void:
	for side: float in [-1.0, 1.0]:
		var ps := CPUParticles3D.new()
		ps.amount = 120
		ps.lifetime = 2.6
		ps.explosiveness = 0.9
		var qm := QuadMesh.new()
		qm.size = Vector2(0.07, 0.1)
		qm.material = _mat()
		ps.mesh = qm
		ps.direction = Vector3(-side * 0.55, 1.0, -0.15)
		ps.spread = 22.0
		ps.initial_velocity_min = 6.0
		ps.initial_velocity_max = 9.5
		ps.gravity = Vector3(0, -4.5, 0)
		ps.damping_min = 2.0
		ps.damping_max = 3.2
		ps.angle_max = 360.0
		ps.angular_velocity_min = -600.0
		ps.angular_velocity_max = 600.0
		ps.scale_amount_min = 0.7
		ps.scale_amount_max = 1.3
		ps.color_initial_ramp = _ramp(colors)
		_emit(parent, ps, center + Vector3(side * 6.2, 0.4, 0.8))
	if parent and parent.is_inside_tree():
		parent.get_tree().create_timer(0.7).timeout.connect(func() -> void:
			if is_instance_valid(parent):
				confetti(parent, center, colors, 260, 9.0))

## Yukarı saçılan ışıltılı yıldızcıklar (doğru cevap, ödül)
static func sparkle(parent: Node, pos: Vector3, col := Color("FFE08A"), amount := 26) -> void:
	var ps := CPUParticles3D.new()
	ps.amount = amount
	ps.lifetime = 0.9
	ps.explosiveness = 0.85
	var sm := SphereMesh.new()
	sm.radius = 0.035
	sm.height = 0.07
	sm.radial_segments = 6
	sm.rings = 3
	var m := _mat(true, false)
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 2.5
	sm.material = m
	ps.mesh = sm
	ps.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	ps.emission_sphere_radius = 0.25
	ps.direction = Vector3.UP
	ps.spread = 70.0
	ps.initial_velocity_min = 1.2
	ps.initial_velocity_max = 2.8
	ps.gravity = Vector3(0, -2.0, 0)
	ps.damping_min = 1.5
	ps.damping_max = 3.0
	var c := Curve.new()
	c.add_point(Vector2(0, 0.4))
	c.add_point(Vector2(0.15, 1.2))
	c.add_point(Vector2(1, 0))
	ps.scale_amount_curve = c
	var g := Gradient.new()
	g.set_color(0, col.lightened(0.5))
	g.set_color(1, col)
	ps.color_initial_ramp = g
	_emit(parent, ps, pos)

## Yere yayılan yumuşak toz bulutu (kapak açılışı, sert iniş)
static func puff(parent: Node, pos: Vector3, col := Color(0.86, 0.78, 0.66), amount := 18, size := 1.0) -> void:
	var ps := CPUParticles3D.new()
	ps.amount = amount
	ps.lifetime = 1.1
	ps.explosiveness = 0.95
	var sm := SphereMesh.new()
	sm.radius = 0.12 * size
	sm.height = 0.24 * size
	sm.radial_segments = 8
	sm.rings = 4
	var m := _mat(false, false)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 1.0
	sm.material = m
	ps.mesh = sm
	ps.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	ps.emission_sphere_radius = 0.3 * size
	ps.direction = Vector3.UP
	ps.spread = 85.0
	ps.flatness = 0.7
	ps.initial_velocity_min = 0.8 * size
	ps.initial_velocity_max = 2.0 * size
	ps.gravity = Vector3(0, 0.3, 0)
	ps.damping_min = 2.5
	ps.damping_max = 4.0
	var c := Curve.new()
	c.add_point(Vector2(0, 0.5))
	c.add_point(Vector2(0.3, 1.2))
	c.add_point(Vector2(1, 1.6))
	ps.scale_amount_curve = c
	var g := Gradient.new()
	g.set_color(0, Color(col, 0.55))
	g.set_color(1, Color(col, 0.0))
	ps.color_ramp = g
	_emit(parent, ps, pos)
