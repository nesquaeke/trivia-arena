class_name Controllers
extends RefCounted
## Plush'u süren girdi kaynakları. Hepsi aynı arayüzü uygular:
##   poll(p: Plush, dt)      her fizik karesinde bir kez
##   get_move() -> Vector2   x sağ, y ekrana doğru (dünyada +Z)
##   consume_jump() / consume_shove() -> bool   basış başına bir kez true

## Sağ Shift yalnızca olaylarla ayırt edilebiliyor; main.gd bunu günceller.
static var right_shift_down := false

class Base extends RefCounted:
	var _move := Vector2.ZERO
	var _jump := false
	var _shove := false
	var label := ""
	func poll(_p, _dt: float) -> void:
		pass
	func get_move() -> Vector2:
		return _move
	func consume_jump() -> bool:
		var j := _jump
		_jump = false
		return j
	func consume_shove() -> bool:
		var s := _shove
		_shove = false
		return s

## Klavye: set 0 = WASD + Boşluk + F ; set 1 = Oklar + Enter + Sağ Shift
class Keyboard extends Base:
	var set_id := 0
	var _prev_jump := false
	var _prev_shove := false
	func _init(p_set := 0) -> void:
		set_id = p_set
		label = "WASD" if set_id == 0 else "⟵⟶"
	func _k(k: Key) -> bool:
		return Input.is_physical_key_pressed(k)
	func poll(_p, _dt: float) -> void:
		var x := 0.0
		var y := 0.0
		var j := false
		var s := false
		if set_id == 0:
			x = float(_k(KEY_D)) - float(_k(KEY_A))
			y = float(_k(KEY_S)) - float(_k(KEY_W))
			j = _k(KEY_SPACE)
			s = _k(KEY_F) or _k(KEY_E)
		else:
			x = float(_k(KEY_RIGHT)) - float(_k(KEY_LEFT))
			y = float(_k(KEY_DOWN)) - float(_k(KEY_UP))
			j = _k(KEY_ENTER) or _k(KEY_KP_0)
			s = Controllers.right_shift_down or _k(KEY_KP_ENTER)
		_move = Vector2(x, y)
		if _move.length() > 1.0:
			_move = _move.normalized()
		if j and not _prev_jump:
			_jump = true
		if s and not _prev_shove:
			_shove = true
		_prev_jump = j
		_prev_shove = s
	## Bu set katılmak için bir tuşa basıyor mu?
	static func wants_join(p_set: int) -> bool:
		if p_set == 0:
			return Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_W)
		return Input.is_physical_key_pressed(KEY_ENTER) or Input.is_physical_key_pressed(KEY_UP)

## Gamepad: sol çubuk / d-pad, Ⓐ zıpla, Ⓧ veya Ⓑ omuz at
class Gamepad extends Base:
	var device := 0
	var _prev_jump := false
	var _prev_shove := false
	func _init(p_device := 0) -> void:
		device = p_device
		label = "🎮%d" % (device + 1)
	func poll(_p, _dt: float) -> void:
		var v := Vector2(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y))
		if v.length() < 0.22:
			v = Vector2.ZERO
		var dx := float(Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_RIGHT)) - float(Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_LEFT))
		var dy := float(Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_DOWN)) - float(Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_UP))
		if dx != 0.0 or dy != 0.0:
			v = Vector2(dx, dy)
		_move = v.limit_length(1.0)
		var j := Input.is_joy_button_pressed(device, JOY_BUTTON_A)
		var s := Input.is_joy_button_pressed(device, JOY_BUTTON_X) or Input.is_joy_button_pressed(device, JOY_BUTTON_B)
		if j and not _prev_jump:
			_jump = true
		if s and not _prev_shove:
			_shove = true
		_prev_jump = j
		_prev_shove = s

## Test ve senaryo için elle sürülen kontrolcü.
class Scripted extends Base:
	func set_move(v: Vector2) -> void:
		_move = v
	func press_jump() -> void:
		_jump = true
	func press_shove() -> void:
		_shove = true

## Bot: lobide dolaşır, ara sıra birine omuz atar; modda hedefe koşar.
class Bot extends Base:
	var mode := "wander"          # wander | goto | idle
	var target := Vector3.ZERO
	var aggression := 0.25
	var bounds := Rect2(-6.6, -4.0, 13.2, 7.4)   # x, z, genişlik, derinlik
	var rng := RandomNumberGenerator.new()
	var _think := 0.0
	var _stuck := 0.0
	var _chase: Node3D = null
	func _init(p_seed: int = 0, p_aggr := 0.25) -> void:
		rng.seed = p_seed if p_seed != 0 else randi()
		aggression = p_aggr
		label = "BOT"
	func go_to(p: Vector3) -> void:
		mode = "goto"
		target = p
		_chase = null
	func wander() -> void:
		mode = "wander"
		_think = 0.0
	func _pick_wander(p) -> void:
		_chase = null
		if rng.randf() < aggression:
			var best: Node3D = null
			var bd := 99.0
			for n in p.get_tree().get_nodes_in_group("plush"):
				if n == p or not n.is_active():
					continue
				var d: float = n.global_position.distance_to(p.global_position)
				if d < bd:
					bd = d
					best = n
			if best and bd < 6.0:
				_chase = best
				_think = rng.randf_range(1.5, 3.0)
				return
		target = Vector3(rng.randf_range(bounds.position.x, bounds.end.x), 0, rng.randf_range(bounds.position.y, bounds.end.y))
		_think = rng.randf_range(1.8, 4.5)
	func poll(p, dt: float) -> void:
		_think -= dt
		if mode == "idle":
			_move = Vector2.ZERO
			return
		if mode == "wander":
			if _think <= 0.0:
				_pick_wander(p)
			if _chase and is_instance_valid(_chase) and _chase.is_active():
				target = _chase.global_position
		var to: Vector3 = target - p.global_position
		to.y = 0.0
		var dist := to.length()
		var arrive := 0.35 if mode == "goto" else 0.6
		if dist < arrive:
			_move = Vector2.ZERO
			if mode == "wander" and _chase == null:
				_think = min(_think, rng.randf_range(0.2, 1.2))
		else:
			var slow: float = clamp(dist / 1.2, 0.35, 1.0)
			_move = Vector2(to.x, to.z).normalized() * slow
		# kovaladığına yetişince omuz at
		if _chase and dist < 1.2 and rng.randf() < 0.08:
			_shove = true
			_chase = null
			_think = rng.randf_range(0.8, 2.0)
		# sıkıştıysa zıpla
		var hs := Vector2(p.linear_velocity.x, p.linear_velocity.z).length()
		if _move.length() > 0.5 and hs < 0.4:
			_stuck += dt
			if _stuck > 0.5:
				_jump = true
				_stuck = 0.0
		else:
			_stuck = 0.0
		if mode == "wander" and rng.randf() < 0.002:
			_jump = true
