@tool
class_name BalconyCam
extends Camera3D
## Tiyatro balkonu açısından bakan kamera. İzometrik değil: hafif geniş açılı,
## sahneyi yukarıdan görür; oyuncuların yoğun olduğu tarafa yavaşça kayar
## (cinematic sway), hafif el kamerası nefesi ve sarsıntı (trauma) taşır.

enum Shot { LOBBY, ARENA, WARDROBE, LOGE, CURTAIN, CUSTOM, MAP }

const SHOTS := {
	Shot.LOBBY: {"pos": Vector3(0, 7.0, 15.0), "look": Vector3(0.0, 1.3, -1.0), "fov": 50.0, "h": -2.2, "sway": 1.0},
	Shot.ARENA: {"pos": Vector3(0, 6.6, 13.5), "look": Vector3(0, 2.2, -1.5), "fov": 47.0, "h": 0.0, "sway": 0.4},
	Shot.WARDROBE: {"pos": Vector3(0.0, 2.3, 5.4), "look": Vector3(0.0, 0.95, 0.4), "fov": 36.0, "h": 0.55, "sway": 0.0},
	Shot.LOGE: {"pos": Vector3(-11.4, 5.1, 6.9), "look": Vector3(-0.5, 0.8, -1.0), "fov": 46.0, "h": 0.0, "sway": 0.35},
	Shot.MAP: {"pos": Vector3(0, 8.4, 11.6), "look": Vector3(0, 0.0, -1.0), "fov": 41.0, "h": 0.0, "sway": 0.1},
	Shot.CURTAIN: {"pos": Vector3(0, 5.0, 14.5), "look": Vector3(0, 3.6, 3.0), "fov": 48.0, "h": 0.0, "sway": 0.0},
}

var shot: int = Shot.LOBBY
var custom := {}
var focus: Array = []            # takip edilecek Node3D'ler (aktif oyuncular)
var trauma := 0.0
var blend := 2.4

var _t := 0.0
var _orbit_t := 0.0
var _look := Vector3.ZERO
var _noise := FastNoiseLite.new()

func _ready() -> void:
	_noise.frequency = 0.35
	_noise.seed = 11
	var s: Dictionary = SHOTS[shot]
	position = s.pos
	_look = s.look
	fov = s.fov
	h_offset = s.h
	look_at(_look, Vector3.UP)
	current = true

func _shot_data() -> Dictionary:
	return custom if shot == Shot.CUSTOM else SHOTS[shot]

## Hazır kadrajların dışında bir çekim (loca gibi, konumu sahneye bağlı olanlar)
## data: {pos, look, fov, h, sway, blend?}
## Yörünge çekimi için data'ya "orbit": {center, radius, height, speed, angle} ekle:
## kamera merkezin çevresinde döner, merkeze bakar (kale düşüşü sinematiği).
func set_custom(data: Dictionary, instant := false) -> void:
	custom = data
	_orbit_t = 0.0
	set_shot(Shot.CUSTOM, instant)

func set_shot(p_shot: int, instant := false) -> void:
	shot = p_shot
	if instant:
		var s: Dictionary = _shot_data()
		position = s.pos
		_look = s.look
		fov = s.fov
		h_offset = s.h
		look_at(_look, Vector3.UP)

func add_trauma(x: float) -> void:
	if not Engine.is_editor_hint() and not GameSettings.shake_on():
		return
	trauma = min(1.0, trauma + x)

func _centroid() -> Vector3:
	var c := Vector3.ZERO
	var n := 0
	for f in focus:
		if is_instance_valid(f) and f.visible and (not f.has_method("is_active") or f.is_active()):
			c += f.global_position
			n += 1
	if n == 0:
		return Vector3.ZERO
	c /= n
	return Vector3(clamp(c.x, -4.0, 4.0), 0, clamp(c.z, -3.0, 2.5))

func _process(delta: float) -> void:
	_t += delta
	var s: Dictionary = _shot_data()
	var sway: float = s.sway
	var c := _centroid()
	# yavaş, nefes alan el kamerası hissi
	var breath := Vector3(_noise.get_noise_2d(_t * 0.4, 0.0), _noise.get_noise_2d(0.0, _t * 0.4), 0.0) * 0.08 * (1.0 if sway > 0.0 else 0.3)
	var want_pos: Vector3 = s.pos + Vector3(c.x * 0.32, 0.0, c.z * 0.12) * sway + breath
	var want_look: Vector3 = s.look + Vector3(c.x * 0.42, 0.0, c.z * 0.3) * sway
	if s.has("orbit"):
		_orbit_t += delta
		var o: Dictionary = s.orbit
		var ang: float = float(o.get("angle", 0.0)) + float(o.get("speed", 0.4)) * _orbit_t
		var ctr: Vector3 = o.center
		want_pos = ctr + Vector3(sin(ang) * float(o.radius), float(o.height), cos(ang) * float(o.radius))
		want_look = ctr
	var k := 1.0 - exp(-float(s.get("blend", blend)) * delta)
	position = position.lerp(want_pos, k)
	_look = _look.lerp(want_look, k)
	fov = lerp(fov, float(s.fov), k)
	h_offset = lerp(h_offset, float(s.h), k)
	look_at(_look, Vector3.UP)
	# sarsıntı
	trauma = max(0.0, trauma - delta * 1.4)
	if trauma > 0.0:
		var a := trauma * trauma
		rotate_object_local(Vector3.RIGHT, _noise.get_noise_2d(_t * 25.0, 3.0) * 0.05 * a)
		rotate_object_local(Vector3.UP, _noise.get_noise_2d(7.0, _t * 25.0) * 0.05 * a)
		rotate_object_local(Vector3.FORWARD, _noise.get_noise_2d(_t * 20.0, 9.0) * 0.04 * a)
