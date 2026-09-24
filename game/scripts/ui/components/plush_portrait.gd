class_name PlushPortrait
extends SubViewportContainer
## Canlı 3D pelüş portresi: kendi küçük dünyasında, spot ışığı altında
## nefes alır, göz kırpar, fareye bakar, arada zıplar. Kostüm değişince
## set_look() ile anında güncellenir.

@export var look := {}
@export var yaw := -0.35
@export var hop_every := 5.5
## Yakın plan (baş ve omuzlar): skor kartları için
@export var close_up := false
var culture := ""

var viewport: SubViewport
var visual: PlushVisual
var pivot: Node3D
var cam: Camera3D
var _t := 0.0
var _next_hop := 2.0
var _hop_y := 0.0
var _hop_v := 0.0
var _look_yaw := 0.0

func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.32, 0.3)
	e.ambient_light_energy = 0.35
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	e.glow_intensity = 0.15
	env.environment = e
	world.add_child(env)
	cam = Camera3D.new()
	cam.fov = 24.0
	cam.position = Vector3(0, 0.95, 4.2)
	world.add_child(cam)
	cam.look_at(Vector3(0, 0.72, 0))
	if close_up:
		cam.fov = 26.0
		cam.position = Vector3(0, 1.05, 2.35)
		cam.look_at(Vector3(0, 0.82, 0))
		viewport.msaa_3d = Viewport.MSAA_2X
	var key := SpotLight3D.new()
	key.light_color = Color(1.0, 0.86, 0.66)
	key.light_energy = 2.6
	key.spot_range = 8.0
	key.spot_angle = 26.0
	key.spot_attenuation = 0.6
	key.shadow_enabled = true
	key.position = Vector3(0.9, 3.4, 2.0)
	world.add_child(key)
	key.look_at(Vector3(0, 0.6, 0))
	var rim := OmniLight3D.new()
	rim.light_color = Color(1.0, 0.35, 0.45)
	rim.light_energy = 1.4
	rim.omni_range = 4.0
	rim.position = Vector3(-1.3, 1.3, -1.2)
	world.add_child(rim)
	var fill := OmniLight3D.new()
	fill.light_color = Color(0.55, 0.65, 1.0)
	fill.light_energy = 0.5
	fill.omni_range = 5.0
	fill.position = Vector3(-1.6, 0.6, 2.0)
	world.add_child(fill)
	# küçük yuvarlak kürsü
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.62
	cm.bottom_radius = 0.66
	cm.height = 0.08
	disc.mesh = cm
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color("3A0A12")
	dm.roughness = 0.5
	disc.material_override = dm
	disc.position.y = -0.04
	world.add_child(disc)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.64
	tm.outer_radius = 0.67
	ring.mesh = tm
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color("C9A15A")
	rm.metallic = 0.8
	rm.roughness = 0.3
	ring.material_override = rm
	world.add_child(ring)
	pivot = Node3D.new()
	world.add_child(pivot)
	set_look(look)

func set_look(l: Dictionary) -> void:
	look = l
	if pivot == null:
		return
	if visual == null:
		visual = PlushVisual.new(look)
		pivot.add_child(visual)
		if culture != "":
			visual.set_culture(culture)
	else:
		visual.apply_look(look)

## Conquest kostümü (kültür); boş: kostümsüz
func set_culture(c: String) -> void:
	culture = c
	if visual:
		visual.set_culture(c)

func hop() -> void:
	_hop_v = 3.2

func _process(delta: float) -> void:
	if visual == null or not is_visible_in_tree():
		return
	# yay hesapları büyük adımda patlar; yavaş karelerde adımı sınırla
	delta = minf(delta, 1.0 / 30.0)
	_t += delta
	# fareye bak
	var m := get_local_mouse_position()
	var target := 0.0
	if Rect2(Vector2(-400, -200), size + Vector2(800, 600)).has_point(m):
		target = clampf((m.x / maxf(size.x, 1.0) - 0.5) * 1.3, -0.8, 0.8)
	_look_yaw = Fx.damp(_look_yaw, target, 4.0, delta)
	pivot.rotation.y = yaw + sin(_t * 0.45) * 0.25 + _look_yaw
	# zıplama
	_next_hop -= delta
	if _next_hop <= 0.0:
		_next_hop = hop_every + randf() * 3.0
		hop()
	var grounded := _hop_y <= 0.0 and _hop_v <= 0.0
	if not grounded:
		_hop_v -= 12.0 * delta
		_hop_y += _hop_v * delta
		if _hop_y <= 0.0:
			_hop_y = 0.0
			_hop_v = 0.0
			visual.land(4.0)
	pivot.position.y = _hop_y
	visual.animate(delta, Vector3(0, _hop_v, 0), _hop_y <= 0.0, 0)
