class_name RoundTrack
extends Control
## "Perde şeridi": maçın neresinde olduğumuzu gösterir (sol üst, perde adının altında).
##   üst satır   I · II · III  (bitenler dolu, şimdiki parlıyor)
##   alt satır   perdeye göre:
##     "castles"  kurulan kaleler (oyuncu sayısı kadar kale simgesi)
##     "hex"      16 bölge altıgeni, alınan bölge sahibinin renginde
##     "flags"    savaş turları: ipe dizili sancaklar. Oynananlar altın,
##                şimdiki tur sırası geldikçe alttan dolar, gelecekler boş
##     "dots"     Trivia: bu perdedeki sorular

var act := 1
var acts := 3
var kind := ""
var total := 0
var done := 0.0                  # tamamlanan birim (kesirli: şimdiki turun ilerlemesi)
var colors: Array = []           # "hex" / "castles" için birim renkleri (null = boş)
var _shown := 0.0                # yumuşatılmış done
var _t := 0.0
var _k := 0.0
var _pulse := 0.0

func _ready() -> void:
	size = Vector2(420, 70)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_track(p_act: int, p_acts: int, p_kind: String, p_total: int, p_done: float, p_colors: Array = []) -> void:
	if p_act != act or p_kind != kind:
		_k = 0.0
		create_tween().tween_property(self, "_k", 1.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_shown = 0.0
	if floorf(p_done) > floorf(done):
		_pulse = 1.0
	act = p_act
	acts = p_acts
	kind = p_kind
	total = p_total
	done = p_done
	colors = p_colors
	visible = true

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_shown = Fx.damp(_shown, done, 6.0, delta)
	_pulse = maxf(0.0, _pulse - delta * 1.5)
	queue_redraw()

func _draw() -> void:
	var a := clampf(_k, 0.0, 1.0)
	# perde işaretleri
	var x := 18.0
	var kf := Pal.kicker()
	for i in acts:
		var n := i + 1
		var r := Pal.roman(n)
		var cur := n == act
		var past := n < act
		var col := Pal.GOLD if cur else (Color(Pal.GOLD, 0.55) if past else Color(Pal.CREAM, 0.3))
		var w := kf.get_string_size(r, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 16
		var box := Rect2(x, 2, w, 22)
		if cur:
			draw_colored_polygon(Icons.notched(box, 5), Color(Pal.VELVET_HI, 0.9 * a))
		elif past:
			draw_colored_polygon(Icons.notched(box, 5), Color(Pal.GOLD, 0.18 * a))
		Icons.outline(self, Icons.notched(box, 5), Color(col, a), 1.0)
		draw_string(kf, Vector2(x + 8, 19), r, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(Pal.CHAMPAGNE if cur else col, a))
		x += w
		if i < acts - 1:
			draw_line(Vector2(x + 3, 13), Vector2(x + 15, 13), Color(Pal.GOLD if past else Pal.MUTED, 0.5 * a), 1.5)
			x += 18
	var y := 48.0
	match kind:
		"flags":
			_draw_flags(y, a)
		"hex":
			_draw_hex(y, a)
		"castles":
			_draw_castles(y, a)
		"dots":
			_draw_dots(y, a)

func _draw_flags(y: float, a: float) -> void:
	if total <= 0:
		return
	var step := minf(40.0, 380.0 / total)
	var x0 := 20.0
	# ip
	var pts := PackedVector2Array()
	for i in 21:
		var t := float(i) / 20.0
		pts.append(Vector2(x0 - 6 + t * (step * total + 4), y - 12 + sin(t * PI) * 5.0))
	draw_polyline(pts, Color(Pal.BRASS, 0.6 * a), 1.5, true)
	for i in total:
		var fx := x0 + i * step + step * 0.5 - 8
		var sag := sin((float(i) + 0.5) / total * PI) * 5.0
		var top := y - 12 + sag
		var fill := clampf(_shown - i, 0.0, 1.0)
		var cur := i == int(floor(done)) and done < total
		var wav := sin(_t * 5.0 + i) * (2.5 if cur else 0.0)
		var flag := PackedVector2Array([Vector2(fx, top), Vector2(fx + 16, top), Vector2(fx + 16, top + 20 + wav * 0.3),
			Vector2(fx + 8, top + 14 + wav), Vector2(fx, top + 20 + wav * 0.3)])
		draw_colored_polygon(flag, Color(0.05, 0.02, 0.02, 0.8 * a))
		if fill > 0.0:
			# alttan dolan kumaş
			var h := 20.0 * fill
			var f2 := PackedVector2Array([Vector2(fx, top + 20 - h), Vector2(fx + 16, top + 20 - h), Vector2(fx + 16, top + 20 + wav * 0.3),
				Vector2(fx + 8, top + 14 + wav), Vector2(fx, top + 20 + wav * 0.3)])
			if h < 6.0:
				f2 = PackedVector2Array([Vector2(fx, top + 20 - h), Vector2(fx + 16, top + 20 - h), Vector2(fx + 16, top + 20), Vector2(fx, top + 20)])
			var fc := Pal.GOLD if fill >= 1.0 else Pal.VELVET_HI.lerp(Pal.GOLD, fill)
			draw_colored_polygon(f2, Color(fc, a))
		var edge := Pal.GOLD if (cur or fill >= 1.0) else Color(Pal.CREAM, 0.35)
		var loop := flag.duplicate()
		loop.append(flag[0])
		draw_polyline(loop, Color(edge, a), 1.2 if not cur else 2.0, true)
		if cur and _pulse > 0.0:
			draw_arc(Vector2(fx + 8, top + 10), 14 + (1.0 - _pulse) * 12, 0, TAU, 20, Color(Pal.GOLD, _pulse * a), 2.0, true)
	var label := Pal.t("track.round", {"n": mini(int(floor(done)) + 1, total), "m": total})
	if done >= total:
		label = Pal.t("track.last")
	draw_string(Pal.italic(), Vector2(x0 + step * total + 12, y + 2), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(Pal.CREAM, 0.7 * a))

func _hexagon(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 6:
		var ang := PI / 6 + TAU * i / 6.0
		pts.append(c + Vector2(cos(ang), sin(ang)) * r)
	return pts

func _draw_hex(y: float, a: float) -> void:
	var n := maxi(total, colors.size())
	for i in n:
		var c := Vector2(26 + i * 19.5, y - 2 + (5.0 if i % 2 else 0.0))
		var col = colors[i] if i < colors.size() else null
		var h := _hexagon(c, 9.0)
		if col == null:
			draw_colored_polygon(h, Color(0.05, 0.02, 0.02, 0.7 * a))
			var loop := h.duplicate()
			loop.append(h[0])
			draw_polyline(loop, Color(Pal.CREAM, 0.3 * a), 1.0, true)
		else:
			draw_colored_polygon(h, Color(col, a))
	var free := 0
	for c in colors:
		if c == null:
			free += 1
	draw_string(Pal.italic(), Vector2(26 + n * 19.5 + 4, y + 4), Pal.t("track.free", {"n": free}), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(Pal.CREAM, 0.7 * a))

func _draw_castles(y: float, a: float) -> void:
	for i in total:
		var col = colors[i] if i < colors.size() else null
		var b := Vector2(28 + i * 32, y + 6)
		var c: Color = Color(Pal.CREAM, 0.25) if col == null else col
		draw_rect(Rect2(b + Vector2(-10, -16), Vector2(20, 16)), Color(c, a))
		for k in 3:
			draw_rect(Rect2(b + Vector2(-11 + k * 8, -21), Vector2(6, 5)), Color(c, a))

func _draw_dots(y: float, a: float) -> void:
	for i in total:
		var c := Vector2(26 + i * 20, y - 4)
		var fill := clampf(_shown - i, 0.0, 1.0)
		draw_circle(c, 7, Color(0.05, 0.02, 0.02, 0.7 * a))
		if fill > 0.0:
			draw_circle(c, 7 * fill, Color(Pal.GOLD, a))
		draw_arc(c, 7, 0, TAU, 16, Color(Pal.GOLD if i == int(floor(done)) else Color(Pal.CREAM, 0.35), a), 1.2, true)
