class_name EstimatePanel
extends Control
## Conquest tahmin sorusu: "Tahmin Cetveli".
##
##  üstte   soru kartı + katılanların durumu (düşünüyor / kilitledi)
##  altta   sorunun min–max aralığını kapsayan pirinç bir cetvel. Her oyuncu
##          kendi renginde bir sancağı cetvel üzerinde kaydırır; kilitleyince
##          sancak cetvele çakılır. Telefon ve bot tahminleri açıklamaya kadar gizli.
##  açıklama altın bir iğne doğru cevaba düşer, her sancaktan iğneye mesafe
##          çizgisi uzar, en yakının sancağına taç konur.
##
## Ölçek: aralık çok genişse (max/min ≥ 20) logaritmik, değilse doğrusal.
## Hesap yardımcıları static; Conquest kuralı aynı ölçeği kullanır.

signal ruler_input(u: float, release: bool)

const RULER_X := 250.0
const RULER_W := 1420.0
const RULER_Y := 912.0
const CARD_W := 1180.0

var kicker := ""
var question := ""
var unit := ""
var lo := 0.0
var hi := 100.0
var logk := false
var year := false
var entries: Array = []        # [{name, color, value, locked, show, human}]
var mode := "ask"              # ask | reveal
var answer := 0
var answer_text := ""
var ranked: Array = []         # [{i, guess, diff}]
var mouse_on := false          # fareyle sürüklenebilir mi (ilk insan oyuncu)
var _t := 0.0
var _k := 0.0                  # giriş animasyonu
var _rk := 0.0                 # açıklama animasyonu
var _xs: Array = []            # sancakların yumuşatılmış x'leri
var _plant: Array = []         # çakılma animasyonu (1 → 0)
var _drag := false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

# ── ölçek ───────────────────────────────────────────────────────────
static func is_log(p_lo: float, p_hi: float, p_year: bool) -> bool:
	return not p_year and p_hi / maxf(p_lo, 1.0) >= 20.0

static func to_u(v: float, p_lo: float, p_hi: float, p_log: bool) -> float:
	if p_log:
		var a := log(maxf(p_lo, 1.0))
		var b := log(maxf(p_hi, 2.0))
		return clampf((log(maxf(v, 1.0)) - a) / (b - a), 0.0, 1.0)
	return clampf((v - p_lo) / maxf(p_hi - p_lo, 1.0), 0.0, 1.0)

static func from_u(u: float, p_lo: float, p_hi: float, p_log: bool) -> float:
	u = clampf(u, 0.0, 1.0)
	if p_log:
		var a := log(maxf(p_lo, 1.0))
		var b := log(maxf(p_hi, 2.0))
		return exp(a + (b - a) * u)
	return p_lo + (p_hi - p_lo) * u

## Cetvelde kaydırırken sayılar 3 anlamlı basamağa yuvarlanır (8.849 → 8.850)
static func nice(v: float, p_year: bool) -> int:
	if p_year or absf(v) < 1000.0:
		return int(round(v))
	var mag := pow(10.0, floor(log(absf(v)) / log(10.0)) - 2.0)
	return int(round(v / mag) * mag)

## Yukarı/aşağı ince ayar adımı: değerin büyüklüğüne göre
static func fine_step(v: float, p_year: bool) -> int:
	if p_year:
		return 1
	var a := absf(v)
	if a < 100.0:
		return 1
	return int(pow(10.0, floor(log(a) / log(10.0)) - 2.0))

static func group(n: int, is_year := false) -> String:
	var neg := n < 0
	var s := str(absi(n))
	if not is_year and s.length() > 3:
		var sep := String(NumberLine.THOUSANDS.get(Pal.lang(), ","))
		var out := ""
		var c := 0
		for i in range(s.length() - 1, -1, -1):
			out = s[i] + out
			c += 1
			if c % 3 == 0 and i > 0:
				out = sep + out
		s = out
	return ("−" if neg else "") + s

# ── API ─────────────────────────────────────────────────────────────
func open(p_kicker: String, p_question: String, p_unit: String, p_lo: float, p_hi: float, p_year: bool, p_entries: Array) -> void:
	kicker = p_kicker
	question = p_question
	unit = p_unit
	lo = p_lo
	hi = p_hi
	year = p_year
	logk = is_log(lo, hi, year)
	entries = p_entries
	mode = "ask"
	ranked = []
	_xs.clear()
	_plant.clear()
	for e in entries:
		_xs.append(_ux(to_u(float(e.value), lo, hi, logk)))
		_plant.append(0.0)
	visible = true
	Fx.cancel_fade(self)
	modulate.a = 1.0
	_k = 0.0
	_rk = 0.0
	create_tween().tween_property(self, "_k", 1.0, 0.7).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	Pal.sfx("whoosh", -9.0, 1.3)

func update_entry(i: int, value: int, locked: bool) -> void:
	if i < 0 or i >= entries.size():
		return
	var e: Dictionary = entries[i]
	if locked and not e.locked:
		_plant[i] = 1.0
		Pal.sfx("thud", -8.0, 1.6)
	e.value = value
	e.locked = locked

func reveal(p_answer: int, p_answer_text: String, p_ranked: Array) -> void:
	mode = "reveal"
	answer = p_answer
	answer_text = p_answer_text
	ranked = p_ranked
	for r in ranked:
		var i := int(r.i)
		if i >= 0 and i < entries.size():
			entries[i].value = int(r.guess)
			entries[i].show = true
			entries[i].locked = true
	_rk = 0.0
	_drag = false
	create_tween().tween_property(self, "_rk", 1.0, 2.2).set_trans(Tween.TRANS_LINEAR)
	Pal.sfx("drumroll", -8.0, 1.3)

func close() -> void:
	_drag = false
	Fx.fade(self, 0.0, 0.3)

# ── fare: cetvelde tut-sürükle ─────────────────────────────────────
func _input(ev: InputEvent) -> void:
	if not visible or mode != "ask" or not mouse_on:
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		var p := (get_global_transform_with_canvas().affine_inverse() * ev.position) as Vector2
		if ev.pressed and Rect2(RULER_X - 30, RULER_Y - 150, RULER_W + 60, 210).has_point(p):
			_drag = true
			ruler_input.emit(_xu(p.x), false)
			get_viewport().set_input_as_handled()
		elif not ev.pressed and _drag:
			_drag = false
			ruler_input.emit(_xu(p.x), true)
	elif ev is InputEventMouseMotion and _drag:
		var p2 := (get_global_transform_with_canvas().affine_inverse() * ev.position) as Vector2
		ruler_input.emit(_xu(p2.x), false)

func _ux(u: float) -> float:
	return RULER_X + u * RULER_W

func _xu(x: float) -> float:
	return clampf((x - RULER_X) / RULER_W, 0.0, 1.0)

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	for i in entries.size():
		var e: Dictionary = entries[i]
		var tx := _ux(to_u(float(e.value), lo, hi, logk))
		if i < _xs.size():
			_xs[i] = Fx.damp(_xs[i], tx, 18.0, delta)
			_plant[i] = maxf(0.0, _plant[i] - delta * 3.0)
	queue_redraw()

# ── çizim ───────────────────────────────────────────────────────────
func _draw() -> void:
	var k := clampf(_k, 0.0, 1.0)
	_draw_card(k)
	_draw_ruler(k)

func _draw_card(k: float) -> void:
	var y0 := 22.0 - (1.0 - k) * 80.0
	var x0 := (1920.0 - CARD_W) * 0.5
	var para := TextParagraph.new()
	para.width = CARD_W - 120
	para.alignment = HORIZONTAL_ALIGNMENT_CENTER
	para.add_string(question, Pal.serif_semi(), 34)
	var qh := para.get_size().y
	var h := 58.0 + qh + 58.0
	var r := Rect2(x0, y0, CARD_W, h)
	# gölge + kâğıt afiş (koyu), üstte kalın altın şerit, sol-sağ kesik köşeler
	var pts := Icons.notched(r, 22.0)
	draw_colored_polygon(Icons.notched(Rect2(r.position + Vector2(8, 14), r.size), 22.0), Color(0, 0, 0, 0.45 * k))
	draw_colored_polygon(pts, Color(0.075, 0.03, 0.035, 0.96 * k))
	Icons.outline(self, pts, Color(Pal.BRASS, 0.5 * k), 1.5)
	draw_rect(Rect2(x0 + 22, y0, CARD_W - 44, 5), Color(Pal.GOLD, k))
	# üst etiket: kurdele
	var kf := Pal.kicker()
	var ks := Pal.upper(kicker)
	var kw := kf.get_string_size(ks, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + ks.length() * 3.0 + 44
	var rib := Rect2(960 - kw * 0.5, y0 - 4, kw, 34)
	draw_colored_polygon(PackedVector2Array([rib.position, rib.position + Vector2(rib.size.x, 0), rib.end - Vector2(12, 0),
		Vector2(rib.position.x + 12, rib.end.y)]), Color(Pal.VELVET_HI, k))
	var x := rib.position.x + 22
	for i in ks.length():
		draw_string(kf, Vector2(x, y0 + 22), ks.substr(i, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(Pal.CHAMPAGNE, k))
		x += kf.get_char_size(ks.unicode_at(i), 18).x + 3
	if mode == "ask" or _rk < 0.35:
		para.draw(get_canvas_item(), Vector2(x0 + 60, y0 + 48), Color(Pal.CHAMPAGNE, k))
	else:
		# açıklamada soru küçülür, yerine cevap gelir
		var a := clampf((_rk - 0.35) * 4.0, 0.0, 1.0)
		var at := answer_text
		var f := Pal.display()
		var fs := 64
		var aw := f.get_string_size(at, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var lbl := Pal.t("cq.answer")
		var lw := Pal.italic().get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		var tot := lw + 18 + aw
		var sx := 960 - tot * 0.5
		draw_string(Pal.italic(), Vector2(sx, y0 + 100), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(Pal.CREAM, 0.8 * a))
		draw_string(f, Vector2(sx + lw + 18, y0 + 108 + (1.0 - a) * 20), at, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Pal.GOLD, a))
	# katılanlar: düşünüyor / kilitledi (açıklamada sıra ve fark)
	_draw_roster(y0 + h - 38, k)

func _draw_roster(y: float, k: float) -> void:
	var n := entries.size()
	if n == 0:
		return
	var f := Pal.display_bold()
	var fs := 20
	var items := []
	var order := range(n)
	if mode == "reveal" and _rk > 0.6:
		order = []
		for r in ranked:
			order.append(int(r.i))
	var total := 0.0
	for i in order:
		var e: Dictionary = entries[i]
		var txt := Pal.upper(String(e.name))
		var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 58
		if mode == "reveal" and _rk > 0.6:
			w += 110
		items.append([i, txt, w])
		total += w + 10
	var x := 960 - total * 0.5
	for it in items:
		var i: int = it[0]
		var e: Dictionary = entries[i]
		var w: float = it[2]
		var col: Color = e.color
		var r := Rect2(x, y, w, 30)
		var locked: bool = e.locked
		var bg := Color(col, 0.22 * k) if locked else Color(1, 1, 1, 0.05 * k)
		draw_colored_polygon(_skew(r, 8), bg)
		draw_rect(Rect2(x + 4, y + 4, 5, 22), Color(col, k))
		draw_string(f, Vector2(x + 18, y + 23), String(it[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Pal.CHAMPAGNE if locked else Pal.CREAM, (1.0 if locked else 0.7) * k))
		var ix := x + w - 24
		if mode == "reveal" and _rk > 0.6:
			var rank := ranked.map(func(q): return int(q.i)).find(i)
			var rr: Dictionary = ranked[rank]
			var dt := Pal.t("cq.exact") if int(rr.diff) == 0 else "±" + group(int(rr.diff), year)
			draw_string(Pal.italic(), Vector2(x + w - 128, y + 22), dt, HORIZONTAL_ALIGNMENT_RIGHT, 96, 17, Color(Pal.CREAM, 0.8 * k))
			if rank == 0:
				Icons.draw(self, "crown", Vector2(ix, y + 15), 20, Pal.GOLD)
			else:
				draw_string(Pal.italic_black(), Vector2(ix - 6, y + 23), str(rank + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(Pal.CREAM, 0.6))
		elif locked:
			Icons.draw(self, "check", Vector2(ix, y + 15), 18, Pal.GOOD, 3.0)
		else:
			for d in 3:
				var a := 0.3 + 0.7 * maxf(0.0, sin(_t * 6.0 - d * 0.9))
				draw_circle(Vector2(ix - 8 + d * 8, y + 16), 2.6, Color(Pal.CREAM, a * k))
		x += w + 10

func _skew(r: Rect2, s: float) -> PackedVector2Array:
	return PackedVector2Array([r.position + Vector2(s, 0), Vector2(r.end.x, r.position.y), r.end - Vector2(s, 0), Vector2(r.position.x, r.end.y)])

func _draw_ruler(k: float) -> void:
	var y := RULER_Y + (1.0 - k) * 200.0
	var a := k
	# alt gölge şeridi (okunurluk)
	draw_rect(Rect2(0, y - 190, 1920, 290), Color(0, 0, 0, 0.0))
	var grad := PackedVector2Array([Vector2(-1600, y - 210), Vector2(3520, y - 210), Vector2(3520, 1980), Vector2(-1600, 1980)])
	draw_polygon(grad, PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0.02, 0.0, 0.01, 0.82 * a), Color(0.02, 0.0, 0.01, 0.82 * a)]))
	# pirinç şerit
	var body := Rect2(RULER_X - 26, y, RULER_W + 52, 30)
	draw_rect(Rect2(body.position + Vector2(0, 6), body.size), Color(0, 0, 0, 0.5 * a))
	draw_rect(body, Color(Pal.BRASS_LO, a))
	draw_rect(Rect2(body.position, Vector2(body.size.x, 13)), Color(Pal.BRASS, a))
	draw_rect(Rect2(body.position, Vector2(body.size.x, 3)), Color(Pal.GOLD, a))
	for side: float in [0.0, 1.0]:
		var cx := body.position.x + side * body.size.x
		draw_circle(Vector2(cx, y + 15), 17, Color(Pal.BRASS_LO, a))
		draw_circle(Vector2(cx, y + 15), 13, Color(Pal.BRASS, a))
		draw_circle(Vector2(cx, y + 15), 4, Color(Pal.BRASS_LO, a))
	# çentikler
	var ticks := _ticks()
	var tf := Pal.display_bold()
	var last_x := -1e9
	for tk in ticks:
		var tx := _ux(to_u(float(tk[0]), lo, hi, logk))
		var major: bool = tk[1]
		draw_line(Vector2(tx, y + 3), Vector2(tx, y + (22 if major else 12)), Color(0.12, 0.06, 0.02, 0.85 * a), 2.0 if major else 1.0)
		if major:
			var s := _short(int(tk[0]))
			var sw := tf.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
			if tx - sw * 0.5 > last_x + 14:
				draw_string(tf, Vector2(tx - sw * 0.5, y + 56), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(Pal.CREAM, 0.7 * a))
				last_x = tx + sw * 0.5
	# yön ipucu
	if mode == "ask":
		var hint := Pal.t("cq.ruler_how")
		var hw := Pal.italic().get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string(Pal.italic(), Vector2(960 - hw * 0.5, y + 96), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(Pal.CREAM, 0.6 * a))
	# sancaklar
	var lanes := _lanes()
	for i in entries.size():
		var e: Dictionary = entries[i]
		if not bool(e.show):
			continue
		_draw_flag(i, e, y, int(lanes.get(i, 0)), a)
	# açıklama: altın iğne
	if mode == "reveal":
		_draw_answer(y)

const SHORT_SUFFIX := {"tr": [" mn", " bin"], "en": ["M", "k"], "pl": [" mln", " tys."], "fr": [" M", " k"], "es": [" M", " mil"]}

func _short(n: int) -> String:
	if year:
		return str(n)
	var l := Pal.lang()
	var suf: Array = SHORT_SUFFIX.get(l, SHORT_SUFFIX.en)
	if n >= 1000000:
		var m := n / 1000000.0
		return (str(snappedf(m, 0.1)).trim_suffix(".0") + String(suf[0])).replace(".", "." if l == "en" else ",")
	if n >= 10000:
		return str(n / 1000) + String(suf[1])
	return group(n)

func _ticks() -> Array:
	var out := []
	if logk:
		var e0 := int(floor(log(maxf(lo, 1.0)) / log(10.0)))
		var e1 := int(ceil(log(hi) / log(10.0)))
		for e in range(e0, e1 + 1):
			for m in [1, 2, 5]:
				var v: float = m * pow(10.0, e)
				if v >= lo and v <= hi:
					out.append([int(v), true])
				for sub in range(m + 1, [2, 5, 10][[1, 2, 5].find(m)]):
					var sv := sub * pow(10.0, e)
					if sv >= lo and sv <= hi:
						out.append([int(sv), false])
	else:
		var span := hi - lo
		var step := pow(10.0, floor(log(span) / log(10.0)))
		if span / step < 4:
			step /= 2.0
		if span / step > 10:
			step *= 2.0
		var v: float = ceil(lo / step) * step
		while v <= hi + 0.001:
			out.append([int(v), true])
			var sub: float = v + step * 0.5
			if sub < hi:
				out.append([int(sub), false])
			v += step
	return out

## Üst üste binmesin: sancakları katlara dağıt
func _lanes() -> Dictionary:
	var idx := []
	for i in entries.size():
		if bool(entries[i].show):
			idx.append(i)
	idx.sort_custom(func(a, b): return _xs[a] < _xs[b])
	var lane_end := []
	var out := {}
	for i in idx:
		var w := _tag_w(entries[i])
		var left: float = _xs[i] - 18
		var placed := false
		for L in lane_end.size():
			if left > lane_end[L]:
				out[i] = L
				lane_end[L] = left + w
				placed = true
				break
		if not placed:
			out[i] = lane_end.size()
			lane_end.append(left + w)
	return out

func _tag_w(e: Dictionary) -> float:
	var s := group(int(e.value), year)
	return maxf(Pal.display().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x, Pal.display_bold().get_string_size(Pal.upper(String(e.name)), HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x) + 40

func _draw_flag(i: int, e: Dictionary, y: float, lane: int, a: float) -> void:
	var x: float = _xs[i] if i < _xs.size() else _ux(0.5)
	var col: Color = e.color
	var locked: bool = e.locked
	var plant: float = _plant[i] if i < _plant.size() else 0.0
	var lift := 0.0 if locked else 10.0 + sin(_t * 5.0 + i) * 3.0
	lift -= plant * 16.0
	var top := y - 82.0 - lane * 74.0 - lift
	# direk
	draw_line(Vector2(x, top), Vector2(x, y + 4), Color(0.1, 0.05, 0.02, 0.9 * a), 5.0)
	draw_line(Vector2(x, top), Vector2(x, y + 4), Color(col.lightened(0.2), a), 2.5)
	# uç: cetvele iğne
	draw_colored_polygon(PackedVector2Array([Vector2(x - 6, y - 2), Vector2(x + 6, y - 2), Vector2(x, y + 14)]), Color(col, a))
	if plant > 0.0:
		for d in 5:
			var ang := PI + d * PI / 4.0
			var r0 := 10.0 + (1.0 - plant) * 30.0
			draw_line(Vector2(x, y) + Vector2(cos(ang), sin(ang)) * r0, Vector2(x, y) + Vector2(cos(ang), sin(ang)) * (r0 + 8), Color(Pal.CHAMPAGNE, plant * a), 2.0)
	# bayrak kumaşı: sağa açılır, hafif dalgalı
	var s := group(int(e.value), year)
	var w := _tag_w(e)
	var h := 66.0
	var pts := PackedVector2Array()
	var wave := 0.0 if locked else 1.0
	var steps := 10
	for q in steps + 1:
		var t := float(q) / steps
		pts.append(Vector2(x + t * w, top + sin(_t * 4.0 + t * 3.0) * 3.0 * t * wave))
	pts.append(Vector2(x + w + 12, top + h * 0.5))
	for q in range(steps, -1, -1):
		var t := float(q) / steps
		pts.append(Vector2(x + t * w, top + h + sin(_t * 4.0 + t * 3.0) * 3.0 * t * wave))
	draw_colored_polygon(pts, Color(col.darkened(0.55), 0.96 * a))
	var band := PackedVector2Array()
	for q in steps + 1:
		var t := float(q) / steps
		band.append(Vector2(x + t * w, top + sin(_t * 4.0 + t * 3.0) * 3.0 * t * wave))
	for q in range(steps, -1, -1):
		var t := float(q) / steps
		band.append(Vector2(x + t * w, top + 5 + sin(_t * 4.0 + t * 3.0) * 3.0 * t * wave))
	draw_colored_polygon(band, Color(col, a))
	draw_string(Pal.display_bold(), Vector2(x + 10, top + 24), Pal.upper(String(e.name)), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(col.lightened(0.45), a))
	draw_string(Pal.display(), Vector2(x + 10, top + 59), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(Pal.CHAMPAGNE, a))
	if locked and mode == "ask":
		Icons.draw(self, "check", Vector2(x + w - 6, top + 14), 14, Pal.GOOD, 2.5)

func _draw_answer(y: float) -> void:
	var drop := clampf(_rk * 2.2, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - drop, 3.0)
	var ux := _ux(to_u(float(answer), lo, hi, logk))
	var tip := y + 16
	var top := lerpf(y - 520, y - 150, eased)
	var bottom := lerpf(y - 380, tip, eased)
	# mesafe çizgileri: her sancaktan iğneye cetvel üstünde
	if drop >= 1.0:
		var g := clampf((_rk - 0.45) * 3.0, 0.0, 1.0)
		for rr in ranked:
			var i := int(rr.i)
			if i >= _xs.size():
				continue
			var x: float = _xs[i]
			var col: Color = entries[i].color
			var xe := lerpf(x, ux, g)
			var ly := y + 72 + ranked.find(rr) * 8
			draw_line(Vector2(x, ly), Vector2(xe, ly), Color(col, 0.9), 4.0)
			draw_circle(Vector2(x, ly), 4, col)
		var winner := int(ranked[0].i) if not ranked.is_empty() else -1
		if winner >= 0 and _rk > 0.7 and winner < _xs.size():
			var wx: float = _xs[winner]
			var bob := sin(_t * 5.0) * 4.0
			Icons.draw(self, "crown", Vector2(wx + 4, y - 150 - bob), 36, Pal.GOLD)
	# iğne
	draw_line(Vector2(ux, top), Vector2(ux, bottom), Color(0, 0, 0, 0.5), 9.0)
	draw_line(Vector2(ux, top), Vector2(ux, bottom), Pal.GOLD, 5.0)
	draw_colored_polygon(PackedVector2Array([Vector2(ux - 9, bottom - 14), Vector2(ux + 9, bottom - 14), Vector2(ux, bottom + 6)]), Pal.GOLD)
	draw_circle(Vector2(ux, top), 13, Pal.GOLD)
	draw_circle(Vector2(ux, top), 6, Pal.CHAMPAGNE)
	if drop >= 1.0:
		var ring := clampf((_rk - 0.45) * 2.0, 0.0, 1.0)
		if ring < 1.0:
			draw_arc(Vector2(ux, y + 14), 10 + ring * 60, 0, TAU, 32, Color(Pal.GOLD, 1.0 - ring), 3.0)
	# iğnenin üstünde cevap
	var f := Pal.display()
	var at := answer_text
	var aw := f.get_string_size(at, HORIZONTAL_ALIGNMENT_LEFT, -1, 46).x
	var lx := clampf(ux - aw * 0.5, 40, 1880 - aw)
	var tag := Rect2(lx - 14, top - 64, aw + 28, 54)
	draw_colored_polygon(Icons.notched(tag, 10), Color(0.07, 0.03, 0.02, 0.95 * eased))
	Icons.outline(self, Icons.notched(tag, 10), Color(Pal.GOLD, eased), 2.0)
	draw_string(f, Vector2(lx, top - 20), at, HORIZONTAL_ALIGNMENT_LEFT, -1, 46, Color(Pal.GOLD, eased))
