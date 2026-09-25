class_name MayhemOverlay
extends Control
## Mayhem Turu'nun ekran parçaları. Mod yalnızca ui.hud_mayhem("yöntem", [..]) çağırır.
##
##   meter      sağ alt   Mayhem Metre (dolunca kaos olayı)
##   zoom       orta sağ  Zoom Panic: yakından başlayıp uzaklaşan 3D nesne penceresi
##   sound      orta sağ  Kulağına Güven: çalan ses dalgası
##   chain      üst orta  Sıralama zinciri (Order Chaos)
##   chaos      tam ekran Kaos olayı kartı
##   awards     tam ekran Maç sonu ödül töreni

const ZOOM_SIZE := 500

var meter := 0.0
var _meter_shown := 0.0
var _meter_flash := 0.0
var _t := 0.0

var _zoom: SubViewportContainer
var _zoom_vp: SubViewport
var _zoom_cam: Camera3D
var _zoom_pivot: Node3D
var _zoom_icon: Node3D
var _zoom_from := 3.0
var _zoom_to := 42.0
var _zoom_k := 0.0
var _zoom_dir := Vector3.FORWARD
var _zoom_frame: Control

var _sound: Control
var _sound_on := false
var _sound_label := ""

var _chain: Control
var _chain_items: Array = []

var _chaos: Control
var _chaos_title := ""
var _chaos_desc := ""
var _chaos_icon := "bolt"

var _awards: Control
var _award_rows: Array = []

var _joker: Control
var _joker_name := ""
var _joker_col := Color.WHITE

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build_zoom()
	_sound = _layer(Rect2(1920 - 600, 330, 540, 200), _draw_sound)
	_chain = _layer(Rect2(360, 250, 1200, 90), _draw_chain)
	_chaos = _layer(Rect2(0, 0, 1920, 1080), _draw_chaos)
	_awards = _layer(Rect2(0, 0, 1920, 1080), _draw_awards)
	_joker = _layer(Rect2(1920 - 480, 890, 420, 60), _draw_joker)

func _layer(r: Rect2, fn: Callable) -> Control:
	var c := Control.new()
	c.position = r.position
	c.size = r.size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.visible = false
	c.draw.connect(fn.bind(c))
	add_child(c)
	return c

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_meter_shown = Fx.damp(_meter_shown, meter, 6.0, delta)
	_meter_flash = max(0.0, _meter_flash - delta)
	queue_redraw()
	if _zoom.visible and _zoom_icon:
		_zoom_k = min(1.0, _zoom_k + delta * _zoom_speed)
		# üstel uzaklaşma: her an aynı hızda "açılıyor" gibi görünür
		var fov := _zoom_from * pow(_zoom_to / _zoom_from, _zoom_k)
		_zoom_cam.fov = fov
		_zoom_pivot.rotation.y += delta * 0.25
	for c in [_sound, _chain, _chaos, _awards, _joker]:
		if c.visible:
			c.queue_redraw()

func reset() -> void:
	meter = 0.0
	_meter_shown = 0.0
	for c in [_sound, _chain, _chaos, _awards, _joker]:
		c.visible = false
	zoom_close()

# ── Mayhem Metre ────────────────────────────────────────────────────
func set_meter(v: float, burst := false) -> void:
	visible = true
	meter = clampf(v, 0.0, 1.0)
	if burst:
		_meter_flash = 1.2

func _draw() -> void:
	var r := Rect2(1920 - 490, 972, 440, 72)
	var pts := Icons.notched(r, 10.0)
	draw_colored_polygon(pts, Color(Pal.NIGHT, 0.88))
	Icons.outline(self, pts, Color(Pal.BRASS, 0.6), 1.5)
	var f := Pal.kicker()
	draw_string(f, r.position + Vector2(56, 26), Pal.t("mh.meter"), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(Pal.GOLD, 0.9))
	var pulse := 0.5 + 0.5 * sin(_t * 9.0)
	var full := _meter_shown > 0.98 or _meter_flash > 0.0
	Icons.draw(self, "bolt", r.position + Vector2(30, 36), 34, Pal.GOLD.lerp(Pal.CHAMPAGNE, pulse if full else 0.0))
	var bar := Rect2(r.position + Vector2(56, 38), Vector2(r.size.x - 76, 20))
	draw_rect(bar, Color(0, 0, 0, 0.5))
	var segs := 12
	var gap := 3.0
	var w := (bar.size.x - gap * (segs - 1)) / segs
	for i in segs:
		var fill := clampf(_meter_shown * segs - i, 0.0, 1.0)
		var sr := Rect2(bar.position + Vector2(i * (w + gap), 0), Vector2(w, bar.size.y))
		draw_rect(sr, Color(Pal.BRASS_LO, 0.5))
		if fill > 0.0:
			var c := Color("F2B83C").lerp(Color("FF5A3C"), float(i) / segs)
			if full:
				c = c.lerp(Pal.CHAMPAGNE, pulse * 0.6)
			draw_rect(Rect2(sr.position, Vector2(w * fill, sr.size.y)), c)
	if _meter_flash > 0.0:
		draw_rect(r.grow(6.0 * _meter_flash), Color(Pal.GOLD, _meter_flash * 0.5), false, 3.0)

# ── Zoom Panic ──────────────────────────────────────────────────────
var _zoom_speed := 0.1

func _build_zoom() -> void:
	_zoom = SubViewportContainer.new()
	_zoom.position = Vector2(1920 - ZOOM_SIZE - 70, 318)
	_zoom.size = Vector2(ZOOM_SIZE, ZOOM_SIZE)
	_zoom.stretch = true
	_zoom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zoom.visible = false
	add_child(_zoom)
	_zoom_vp = SubViewport.new()
	_zoom_vp.size = Vector2i(ZOOM_SIZE, ZOOM_SIZE)
	_zoom_vp.own_world_3d = true
	_zoom_vp.msaa_3d = Viewport.MSAA_4X
	_zoom_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_zoom.add_child(_zoom_vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("2A1418")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("8C7A70")
	e.ambient_light_energy = 0.45
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 0.85
	env.environment = e
	_zoom_vp.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.8, 0.6, 0)
	key.light_energy = 1.05
	_zoom_vp.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(-0.3, -2.4, 0)
	fill.light_energy = 0.5
	fill.light_color = Color("A8C8FF")
	_zoom_vp.add_child(fill)
	_zoom_pivot = Node3D.new()
	_zoom_vp.add_child(_zoom_pivot)
	_zoom_cam = Camera3D.new()
	_zoom_cam.near = 0.01
	_zoom_vp.add_child(_zoom_cam)
	_zoom_frame = Control.new()
	_zoom_frame.position = _zoom.position - Vector2(14, 14)
	_zoom_frame.size = _zoom.size + Vector2(28, 28)
	_zoom_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zoom_frame.visible = false
	_zoom_frame.draw.connect(func():
		var rr := Rect2(Vector2.ZERO, _zoom_frame.size)
		var p := Icons.notched(rr, 16.0)
		Icons.outline(_zoom_frame, p, Pal.GOLD, 3.0)
		Icons.outline(_zoom_frame, Icons.notched(rr.grow(-7), 12.0), Color(Pal.BRASS, 0.6), 1.0)
		var tag := Pal.t("mh.zoom_tag")
		var fk := Pal.kicker()
		var tw := fk.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		_zoom_frame.draw_rect(Rect2(Vector2((rr.size.x - tw) * 0.5 - 14, -14), Vector2(tw + 28, 28)), Pal.NIGHT)
		_zoom_frame.draw_string(fk, Vector2((rr.size.x - tw) * 0.5, 7), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Pal.GOLD))
	add_child(_zoom_frame)

## Zoom: nesne en yakından başlar, `dur` saniyede tamamen görünür
func zoom_open(id: String, dur: float, seed_val: int) -> void:
	visible = true
	zoom_close()
	_zoom_icon = PropIcons.build(id)
	_zoom_pivot.add_child(_zoom_icon)
	var aabb := _aabb(_zoom_icon)
	var center := aabb.get_center()
	_zoom_icon.position = -center
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var yaw := rng.randf_range(-0.7, 0.7)
	var pitch := rng.randf_range(-0.15, 0.35)
	_zoom_dir = Vector3(sin(yaw), pitch, cos(yaw)).normalized()
	var dist := 3.2
	_zoom_cam.position = _zoom_dir * dist
	# biraz kaydırılmış bir noktaya bak: en başta ne olduğu belli olmasın
	var off := Vector3(rng.randf_range(-0.18, 0.18), rng.randf_range(-0.18, 0.18), 0)
	_zoom_cam.look_at_from_position(_zoom_cam.position, off, Vector3.UP)
	_zoom_from = 4.0
	_zoom_to = 24.0
	_zoom_k = 0.0
	_zoom_speed = 1.0 / max(0.5, dur)
	_zoom_cam.fov = _zoom_from
	_zoom.visible = true
	_zoom_frame.visible = true
	_zoom_frame.queue_redraw()
	Fx.pop(_zoom, 0.0, 0.85, 0.35)

## Cevap: tamamen aç
func zoom_reveal() -> void:
	_zoom_k = 1.0
	if _zoom_cam:
		var tw := create_tween()
		tw.tween_property(_zoom_cam, "fov", 30.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_zoom_cam.look_at(Vector3.ZERO, Vector3.UP)

func zoom_close() -> void:
	if _zoom_icon and is_instance_valid(_zoom_icon):
		_zoom_icon.queue_free()
	_zoom_icon = null
	if _zoom:
		_zoom.visible = false
		_zoom_frame.visible = false

static func _aabb(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var b := mi.get_aabb()
		var xf := n.global_transform.affine_inverse() * mi.global_transform if n.is_inside_tree() else _rel(n, mi)
		b = xf * b
		out = b if first else out.merge(b)
		first = false
	return out

static func _rel(root: Node3D, n: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur and cur != root:
		xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf

# ── Kulağına Güven ──────────────────────────────────────────────────
func sound_show(on: bool, label := "") -> void:
	visible = true
	_sound_on = on
	_sound_label = label
	_sound.visible = on
	if on:
		Fx.pop(_sound, 0.0, 0.85, 0.3)

func _draw_sound(c: Control) -> void:
	var r := Rect2(Vector2.ZERO, c.size)
	var pts := Icons.notched(r, 14.0)
	c.draw_colored_polygon(pts, Color(Pal.NIGHT, 0.9))
	Icons.outline(c, pts, Pal.GOLD, 2.0)
	Icons.draw(c, "speaker", Vector2(60, r.size.y * 0.5), 64, Pal.GOLD)
	var bars := 22
	for i in bars:
		var x := 120.0 + i * 18.0
		var h: float = 14.0 + 60.0 * abs(sin(_t * (3.0 + i * 0.37) + i * 1.3)) * (0.5 + 0.5 * sin(_t * 1.7 + i))
		c.draw_rect(Rect2(Vector2(x, r.size.y * 0.5 - h * 0.5), Vector2(10, h)), Pal.GOLD.lerp(Color("FF5A3C"), float(i) / bars))
	if _sound_label != "":
		c.draw_string(Pal.kicker(), Vector2(120, r.size.y - 16), _sound_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(Pal.CREAM, 0.8))

# ── Sıralama zinciri ───────────────────────────────────────────────
## items: [{text, label, ok}] şimdiye kadar yerleşenler
func chain_set(items: Array) -> void:
	visible = true
	_chain_items = items
	_chain.visible = not items.is_empty()

func _draw_chain(c: Control) -> void:
	var n := _chain_items.size()
	if n == 0:
		return
	var w := 280.0
	var gap := 20.0
	var total := n * w + (n - 1) * gap
	var x0 := (c.size.x - total) * 0.5
	var f := Pal.display()
	var fi := Pal.italic()
	for i in n:
		var it: Dictionary = _chain_items[i]
		var r := Rect2(Vector2(x0 + i * (w + gap), 0), Vector2(w, 80))
		var pts := Icons.notched(r, 10.0)
		c.draw_colored_polygon(pts, Color(Pal.NIGHT, 0.92))
		Icons.outline(c, pts, Color(Pal.GOOD, 0.8) if it.get("ok", true) else Color(Pal.BAD, 0.8), 1.5)
		c.draw_string(Pal.italic_black(), r.position + Vector2(14, 50), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Pal.GOLD)
		c.draw_string(f, r.position + Vector2(50, 38), Pal.upper(String(it.get("text", ""))), HORIZONTAL_ALIGNMENT_LEFT, w - 60, 26, Pal.CHAMPAGNE)
		c.draw_string(fi, r.position + Vector2(52, 64), String(it.get("label", "")), HORIZONTAL_ALIGNMENT_LEFT, w - 60, 17, Color(Pal.CREAM, 0.75))
		if i < n - 1:
			Icons.draw(c, "arrow_l", r.position + Vector2(w + gap * 0.5, 40), 16, Color(Pal.GOLD, 0.7))

# ── Kaos olayı ──────────────────────────────────────────────────────
func chaos_show(title: String, desc: String, icon := "bolt") -> void:
	visible = true
	_chaos_title = title
	_chaos_desc = desc
	_chaos_icon = icon
	_chaos.visible = true
	_chaos.modulate.a = 1.0
	_chaos.scale = Vector2.ONE
	Fx.shake(_chaos, 18.0, 0.5)

func chaos_hide() -> void:
	Fx.fade(_chaos, 0.0, 0.35).finished.connect(func(): _chaos.visible = false)

func _draw_chaos(c: Control) -> void:
	var s := c.size
	c.draw_rect(Rect2(Vector2.ZERO, s), Color(0.05, 0.0, 0.02, 0.55))
	# kırmızı-altın ikaz şeritleri
	var band_h := 300.0
	var y0 := s.y * 0.5 - band_h * 0.5
	c.draw_rect(Rect2(0, y0, s.x, band_h), Color("7A0F1E"))
	var stripe := 60.0
	var off := fmod(_t * 160.0, stripe * 2.0)
	for i in range(-2, int(s.x / stripe) + 3):
		var x := i * stripe * 2.0 + off
		for yy in [y0, y0 + band_h - 22]:
			c.draw_colored_polygon(PackedVector2Array([Vector2(x, yy), Vector2(x + stripe, yy), Vector2(x + stripe + 22, yy + 22), Vector2(x + 22, yy + 22)]), Pal.GOLD)
	var f := Pal.display()
	var kick := Pal.t("mh.chaos_kicker")
	var fk := Pal.kicker()
	var kw := fk.get_string_size(kick, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	c.draw_string(fk, Vector2((s.x - kw) * 0.5, y0 + 64), kick, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Pal.GOLD)
	var title := Pal.upper(_chaos_title)
	var fs := 110
	var tw := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var wob := sin(_t * 14.0) * 3.0
	c.draw_string(f, Vector2((s.x - tw) * 0.5 + 4, y0 + 176 + 4 + wob), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.6))
	c.draw_string(f, Vector2((s.x - tw) * 0.5, y0 + 176 + wob), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.CHAMPAGNE)
	Icons.draw(c, _chaos_icon, Vector2((s.x - tw) * 0.5 - 70, y0 + 140), 72, Pal.GOLD)
	var fi := Pal.italic()
	var dw := fi.get_string_size(_chaos_desc, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	c.draw_string(fi, Vector2((s.x - dw) * 0.5, y0 + 236), _chaos_desc, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Pal.CREAM)

# ── Joker (geride kalana ×2) ───────────────────────────────────────
func joker_show(p_name: String, col: Color) -> void:
	visible = true
	_joker_name = p_name
	_joker_col = col
	_joker.visible = p_name != ""
	if _joker.visible:
		Fx.pop(_joker, 0.0, 0.7, 0.35)

func _draw_joker(c: Control) -> void:
	var r := Rect2(Vector2.ZERO, c.size)
	var pts := Icons.notched(r, 10.0)
	c.draw_colored_polygon(pts, Color(Pal.NIGHT, 0.9))
	Icons.outline(c, pts, _joker_col, 2.0)
	Icons.draw(c, "star", Vector2(30, 30), 30, _joker_col)
	var txt := Pal.t("mh.joker_badge", {"name": _joker_name})
	c.draw_string(Pal.kicker(), Vector2(56, 38), txt, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 70, 20, Pal.CHAMPAGNE)

# ── Ödül töreni ─────────────────────────────────────────────────────
## rows: [{title, desc, name, color}]
func awards_show(rows: Array) -> void:
	visible = true
	_award_rows = rows
	_awards.visible = true
	_awards.modulate.a = 0.0
	Fx.fade(_awards, 1.0, 0.3)
	_award_t0 = _t

var _award_t0 := 0.0

func awards_hide() -> void:
	Fx.fade(_awards, 0.0, 0.3).finished.connect(func(): _awards.visible = false)

func _draw_awards(c: Control) -> void:
	var s := c.size
	c.draw_rect(Rect2(Vector2.ZERO, s), Color(0.03, 0.01, 0.02, 0.78))
	var f := Pal.display()
	var head := Pal.upper(Pal.t("mh.awards"))
	var hw := f.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, 84).x
	c.draw_string(f, Vector2((s.x - hw) * 0.5, 170), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 84, Pal.GOLD)
	var n := _award_rows.size()
	var cols := 2 if n > 3 else 1
	var w := 760.0
	var h := 150.0
	var rows_n := int(ceil(n / float(cols)))
	var x0 := (s.x - (cols * w + (cols - 1) * 40.0)) * 0.5
	var y0: float = 230.0 + max(0.0, (4 - rows_n) * 40.0)
	for i in n:
		var a: Dictionary = _award_rows[i]
		var k := clampf((_t - _award_t0 - i * 0.35) / 0.4, 0.0, 1.0)
		if k <= 0.0:
			continue
		var cx := i % cols
		var cy := i / cols
		var r := Rect2(Vector2(x0 + cx * (w + 40.0), y0 + cy * (h + 26.0) + (1.0 - ease(k, 0.3)) * 40.0), Vector2(w, h))
		var pts := Icons.notched(r, 14.0)
		var col: Color = a.get("color", Pal.GOLD)
		c.draw_colored_polygon(pts, Color(Pal.NIGHT, 0.95 * k))
		Icons.outline(c, pts, Color(col, k), 2.0)
		Icons.draw(c, String(a.get("icon", "star")), r.position + Vector2(62, h * 0.5), 58, Color(col, k))
		c.draw_string(Pal.kicker(), r.position + Vector2(118, 42), Pal.upper(String(a.get("title", ""))), HORIZONTAL_ALIGNMENT_LEFT, w - 140, 24, Color(Pal.GOLD, k))
		c.draw_string(f, r.position + Vector2(116, 96), Pal.upper(String(a.get("name", ""))), HORIZONTAL_ALIGNMENT_LEFT, w - 140, 50, Color(Pal.CHAMPAGNE, k))
		c.draw_string(Pal.italic(), r.position + Vector2(118, 130), String(a.get("desc", "")), HORIZONTAL_ALIGNMENT_LEFT, w - 140, 19, Color(Pal.CREAM, 0.8 * k))
