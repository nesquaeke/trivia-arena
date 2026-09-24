class_name Plush
extends RigidBody3D
## Fizikli pelüş karakter (Party Panic ekolü).
## Ayakta dururken dönmesi kilitlidir ve kuvvetle yürür; sert bir omuz ya da
## çarpışmada kilitler açılır, gövde gerçekten yuvarlanır ("ragdoll" hissi),
## bir süre sonra doğrulup kalkar. Görünüş PlushVisual'da.

signal fell_out(p: Plush)
signal tumbled(p: Plush)
signal jumped(p: Plush)

enum State { NORMAL, STUMBLE, TUMBLE, GETUP, OUT }

const RADIUS := 0.32
const HEIGHT := 1.22
const RUN_SPEED := 5.4
const ACCEL_GROUND := 42.0
const ACCEL_AIR := 11.0
const JUMP_VEL := 5.25
const SHOVE_RANGE := 1.45
const SHOVE_IMPULSE := 5.2
const SHOVE_COOLDOWN := 0.65
const OUT_Y := -2.5

var player_name := "Oyuncu"
var look := {}
var is_bot := false
var controller: Object = null   # get_move() / consume_jump() / consume_shove() / poll(p, dt)
var state: int = State.NORMAL
var state_t := 0.0
var facing := 0.0
var grounded := false
## Girdi kapalıyken kontrolcü okunmaya devam eder ama tuşlar tüketilmez;
## böylece ödül seçici gibi arayüzler aynı kontrolcüyü okuyabilir.
var frozen_input := false:
	set(v):
		if frozen_input and not v and controller:
			controller.consume_jump()
			controller.consume_shove()
		frozen_input = v
## Sabotajlar: "lead" kurşun ayakkabı, "invert" ters kumanda, "ice" buz, "bighead" dev kafa
var debuffs := {}
var accel_mult := 1.0
var fragility := 1.0              # dengeye gelen hasarın çarpanı
var speed_mult := 1.0
var balance := 1.0
var visual: PlushVisual
var team_color := Color.WHITE
var tag := {}                     # modların kendi verisi (bölge vb.)

var _ray: RayCast3D
var _coyote := 0.0
var _jump_buf := 0.0
var _shove_cd := 0.0
var _tumble_dur := 1.4
var _upright_pending := false
var _getup_from := Quaternion.IDENTITY
var _last_bump := 0.0

func _init(p_name: String = "Oyuncu", p_look: Dictionary = {}, p_bot := false) -> void:
	player_name = p_name
	look = p_look.duplicate()
	is_bot = p_bot

func _ready() -> void:
	add_to_group("plush")
	collision_layer = 1
	collision_mask = 1 | 2   # 1: oyuncular ve dekorlar, 2: sahne zemini
	mass = 1.4
	can_sleep = false
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 6
	angular_damp = 2.2
	linear_damp = 0.05
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.5, 0)
	var pm := PhysicsMaterial.new()
	pm.friction = 0.55
	pm.bounce = 0.12
	physics_material_override = pm
	_lock(true)

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = RADIUS
	cap.height = HEIGHT
	col.shape = cap
	col.position = Vector3(0, HEIGHT * 0.5, 0)
	add_child(col)

	_ray = RayCast3D.new()
	_ray.position = Vector3(0, 0.3, 0)
	_ray.target_position = Vector3(0, -0.45, 0)
	_ray.collision_mask = 1 | 2
	_ray.add_exception(self)
	add_child(_ray)

	visual = PlushVisual.new(look)
	add_child(visual)
	body_entered.connect(_on_body_entered)

func _lock(on: bool) -> void:
	axis_lock_angular_x = on
	axis_lock_angular_y = on
	axis_lock_angular_z = on

func set_look(l: Dictionary) -> void:
	look = l.duplicate()
	if visual:
		visual.apply_look(look)

func is_active() -> bool:
	return state != State.OUT

# ── fizik döngüsü ───────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	state_t += delta
	_shove_cd -= delta
	_coyote -= delta
	_jump_buf -= delta
	_last_bump -= delta
	balance = min(1.0, balance + delta * 0.5)

	grounded = _ray.is_colliding() and linear_velocity.y < 2.8
	# dondurulmuş gövde (kostüm odası, sahne dışı) havada sanılıp zıplama pozunda kalmasın
	if freeze:
		grounded = true
	if grounded:
		_coyote = 0.12

	var move := Vector2.ZERO
	if controller and state != State.OUT:
		controller.poll(self, delta)
		if frozen_input:
			pass
		elif state == State.NORMAL or state == State.STUMBLE:
			move = controller.get_move()
			if debuffs.has("invert"):
				move = -move
			if controller.consume_jump():
				_jump_buf = 0.16
			if controller.consume_shove():
				try_shove()
		else:
			controller.consume_jump()
			controller.consume_shove()

	match state:
		State.NORMAL, State.STUMBLE:
			_locomotion(delta, move)
			if state == State.STUMBLE and state_t > 0.55:
				_set_state(State.NORMAL)
		State.TUMBLE:
			if state_t > _tumble_dur and (linear_velocity.length() < 1.2 or state_t > 3.2):
				_start_getup()
		State.GETUP:
			var k: float = clamp(state_t / 0.35, 0.0, 1.0)
			var q := _getup_from.slerp(Quaternion.IDENTITY, k)
			visual.quaternion = q * Quaternion(Vector3.UP, facing)
			if k >= 1.0:
				_set_state(State.NORMAL)

	if state != State.GETUP:
		visual.rotation = Vector3(0, facing, 0)
	visual.animate(delta, linear_velocity, grounded, state)

	if global_position.y < OUT_Y and state != State.OUT:
		_set_state(State.OUT)
		fell_out.emit(self)

func _integrate_forces(s: PhysicsDirectBodyState3D) -> void:
	if _upright_pending:
		_upright_pending = false
		var tr := s.transform
		tr.basis = Basis.IDENTITY
		tr.origin.y += 0.15
		s.transform = tr
		s.angular_velocity = Vector3.ZERO
		var v := s.linear_velocity
		s.linear_velocity = Vector3(v.x * 0.3, 2.2, v.z * 0.3)

func _locomotion(delta: float, move: Vector2) -> void:
	if move.length() > 1.0:
		move = move.normalized()
	var target := Vector3(move.x, 0, move.y) * RUN_SPEED * speed_mult
	var v := linear_velocity
	var hv := Vector3(v.x, 0, v.z)
	var accel := (ACCEL_GROUND if grounded else ACCEL_AIR) * accel_mult
	if state == State.STUMBLE:
		accel *= 0.3
	var dv := target - hv
	var max_dv := accel * delta
	if dv.length() > max_dv:
		dv = dv.normalized() * max_dv
	apply_central_impulse(dv * mass)
	if move.length() > 0.15:
		facing = lerp_angle(facing, atan2(move.x, move.y), 1.0 - exp(-14.0 * delta))
	if _jump_buf > 0.0 and _coyote > 0.0:
		_jump_buf = 0.0
		_coyote = 0.0
		linear_velocity = Vector3(linear_velocity.x, JUMP_VEL, linear_velocity.z)
		Sfx.play("jump", -8.0, randf_range(0.9, 1.15))
		jumped.emit(self)

# ── omuz atma / çarpışma ────────────────────────────────────────────
func forward() -> Vector3:
	return Vector3(sin(facing), 0, cos(facing))

func try_shove() -> bool:
	if _shove_cd > 0.0 or state == State.OUT:
		return false
	_shove_cd = SHOVE_COOLDOWN
	var fwd := forward()
	visual.punch()
	apply_central_impulse(fwd * 1.6 * mass)
	Sfx.play("shove", -6.0, randf_range(0.9, 1.1))
	var hit := false
	for n in get_tree().get_nodes_in_group("plush"):
		var o := n as Plush
		if o == null or o == self or not o.is_active():
			continue
		var d := o.global_position - global_position
		d.y = 0.0
		var dist := d.length()
		if dist > SHOVE_RANGE or dist < 0.01:
			continue
		if fwd.dot(d / dist) < 0.3:
			continue
		o.receive_shove(fwd, self)
		hit = true
	for n in get_tree().get_nodes_in_group("prop"):
		var b := n as RigidBody3D
		if b == null:
			continue
		var d2 := b.global_position - global_position
		d2.y = 0.0
		if d2.length() < SHOVE_RANGE + 0.4 and d2.length() > 0.01 and fwd.dot(d2.normalized()) > 0.2:
			b.apply_impulse(fwd * 4.0 + Vector3.UP * 0.8, Vector3(0, 0.9, 0))
			hit = true
	return hit

func receive_shove(dir: Vector3, _from: Plush) -> void:
	if state == State.OUT:
		return
	apply_central_impulse((dir * SHOVE_IMPULSE + Vector3.UP * 1.9) * mass)
	balance -= 0.6 * fragility
	Sfx.play("bump", -4.0, randf_range(0.8, 1.2))
	if balance <= 0.0 or randf() < 0.35:
		tumble(dir, 1.0)
	else:
		stumble()

func receive_bump(dir: Vector3, speed: float) -> void:
	if state == State.OUT or _last_bump > 0.0:
		return
	_last_bump = 0.25
	apply_central_impulse(dir * speed * 0.35 * mass)
	balance -= speed * 0.13 * fragility
	if balance <= 0.1:
		tumble(dir, 0.8)
	else:
		stumble()

func stumble() -> void:
	if state == State.NORMAL:
		_set_state(State.STUMBLE)
	visual.wobble = 1.0

func tumble(dir: Vector3, strength: float = 1.0) -> void:
	if state == State.TUMBLE or state == State.OUT:
		return
	_set_state(State.TUMBLE)
	_tumble_dur = randf_range(1.0, 1.6)
	_lock(false)
	var axis := Vector3.UP.cross(dir)
	if axis.length() < 0.01:
		axis = Vector3.RIGHT
	axis = axis.normalized()
	apply_torque_impulse((axis * 1.1 + Vector3(randf_range(-0.2, 0.2), randf_range(-0.4, 0.4), 0)) * strength * mass)
	Sfx.play("oof", -3.0, randf_range(0.85, 1.25))
	tumbled.emit(self)

func _start_getup() -> void:
	# gövde bir sonraki fizik adımında dikleşir; görünüş eğik halden yumuşakça döner
	_getup_from = global_transform.basis.get_rotation_quaternion()
	_lock(true)
	_upright_pending = true
	_set_state(State.GETUP)
	balance = 1.0

func _set_state(s: int) -> void:
	state = s
	state_t = 0.0

func _on_body_entered(b: Node) -> void:
	if state == State.OUT:
		return
	if b is Plush:
		var o := b as Plush
		var toward := o.global_position - global_position
		toward.y = 0.0
		if toward.length() < 0.001:
			return
		toward = toward.normalized()
		var closing := linear_velocity.dot(toward) - o.linear_velocity.dot(toward)
		if closing > 3.8:
			o.receive_bump(toward, closing)
			Sfx.play("bump", -8.0)
	elif b is RigidBody3D:
		var rb := b as RigidBody3D
		var impact := (rb.linear_velocity - linear_velocity).length() * rb.mass
		if impact > 14.0 and rb.linear_velocity.length() > 3.0:
			tumble(rb.linear_velocity.normalized(), 0.8)

# ── modların kullandığı yardımcılar ─────────────────────────────────
func teleport(pos: Vector3, yaw: float = 0.0) -> void:
	_lock(true)
	_set_state(State.NORMAL)
	facing = yaw
	global_transform = Transform3D(Basis.IDENTITY, pos)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	visual.quaternion = Quaternion(Vector3.UP, yaw)

func revive(pos: Vector3) -> void:
	freeze = false
	visible = true
	restore_collision()
	frozen_input = false
	teleport(pos, 0.0)


# ── sabotajlar, isim plakası, uçan yazılar, kişisel kapak ───────────
const DEBUFF_KEYS := ["lead", "invert", "ice", "bighead"]
var _plate: Label3D
var _badge: Label3D

## Sabotajı aç/kapat. Değerler RulesConfig'ten gelir.
func set_debuff(kind: String, on: bool, rules: Resource = null) -> void:
	if on:
		debuffs[kind] = true
	else:
		debuffs.erase(kind)
	speed_mult = rules.lead_speed if (debuffs.has("lead") and rules) else 1.0
	accel_mult = rules.ice_accel if (debuffs.has("ice") and rules) else 1.0
	fragility = (1.0 / max(0.05, rules.bighead_balance)) if (debuffs.has("bighead") and rules) else 1.0
	if physics_material_override:
		physics_material_override.friction = 0.04 if debuffs.has("ice") else 0.55
	if visual:
		var tw := create_tween()
		tw.tween_property(visual.head_pivot, "scale", Vector3.ONE * (2.1 if debuffs.has("bighead") else 1.0), 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		visual.set_boots(debuffs.has("lead"))
		visual.set_frost(debuffs.has("ice"))
	_update_badge()

func clear_debuffs() -> void:
	for k in debuffs.keys():
		set_debuff(k, false)

func _update_badge() -> void:
	if _badge == null:
		_badge = Label3D.new()
		_badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_badge.no_depth_test = true
		_badge.font = Pal.display()
		_badge.font_size = 44
		_badge.pixel_size = 0.006
		_badge.outline_size = 10
		_badge.outline_modulate = Color(0.1, 0.0, 0.02)
		_badge.modulate = Color("FF6B52")
		_badge.position = Vector3(0, 2.15, 0)
		add_child(_badge)
	var names := []
	for k in debuffs:
		names.append(Pal.upper(I18n.t("debuff." + k)))
	_badge.text = " · ".join(names)
	_badge.visible = not names.is_empty()

## Başın üstünde isim + değer (puan ya da can). Maç sırasında görünür.
func set_plate(top: String, bottom: String, col: Color) -> void:
	if _plate == null:
		_plate = Label3D.new()
		_plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_plate.no_depth_test = true
		_plate.font = Pal.display()
		_plate.font_size = 40
		_plate.pixel_size = 0.0058
		_plate.outline_size = 12
		_plate.outline_modulate = Color(0.05, 0.02, 0.02, 0.95)
		_plate.line_spacing = -6
		_plate.position = Vector3(0, 1.82, 0)
		add_child(_plate)
	_plate.visible = top != ""
	_plate.text = Pal.upper(top) + ("\n" + Pal.upper(bottom) if bottom != "" else "")
	_plate.modulate = col.lightened(0.25)

func hide_plate() -> void:
	if _plate:
		_plate.visible = false

## Yükselip kaybolan yazı: "+250", "−540", "GÜVENDE"…
func float_text(text: String, col: Color, big := false) -> void:
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font = Pal.display()
	l.font_size = 72 if big else 56
	l.pixel_size = 0.007
	l.outline_size = 14
	l.outline_modulate = Color(0.05, 0.02, 0.02)
	l.modulate = col
	l.text = text
	l.position = Vector3(0, 2.1, 0)
	add_child(l)
	l.scale = Vector3.ONE * 0.3
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", 3.1, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(1.2)
	tw.chain().tween_callback(l.queue_free)

## Tur 3'te canı biten: ayağının altında bir kapak açılır, zemini delip düşer.
func drop_through() -> void:
	collision_mask = 0
	collision_layer = 0
	frozen_input = true
	_lock(false)
	apply_central_impulse(Vector3(0, -2.0, 0) * mass)
	apply_torque_impulse(Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * 0.4 * mass)
	hide_plate()

func restore_collision() -> void:
	collision_layer = 1
	collision_mask = 1 | 2
