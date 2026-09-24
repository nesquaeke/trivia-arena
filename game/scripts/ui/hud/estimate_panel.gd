class_name EstimatePanel
extends Control
## Conquest tahmin sorusu: üstte soru, altında her insan oyuncu için pirinç
## bir sayaç kadranı (rakamlar yukarı/aşağı döner). Kilitleyen yeşil yanar.
## Açıklama modunda doğru cevap kocaman, herkesin tahmini farkına göre sıralı.

const W := 1240.0

var kicker := ""
var question := ""
var unit := ""
var dials: Array = []          # [{name, color, value, digits, cursor, locked}]
var year := false
var mode := "ask"              # ask | reveal
var answer_text := ""
var ranked: Array = []         # [{name, color, guess_text, diff_text, ratio, win}]
var _t := 0.0
var _k := 0.0
var _roll: Array = []          # görünen rakamların yumuşak değerleri

func _ready() -> void:
	size = Vector2(W, 300)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func open(p_kicker: String, p_question: String, p_unit: String, p_dials: Array, p_year: bool) -> void:
	kicker = p_kicker
	question = p_question
	unit = p_unit
	dials = p_dials
	year = p_year
	mode = "ask"
	_roll.clear()
	for d in dials:
		var arr := []
		for i in int(d.digits):
			arr.append(0.0)
		_roll.append(arr)
	visible = true
	Fx.cancel_fade(self)
	modulate.a = 1.0
	_k = 0.0
	create_tween().tween_property(self, "_k", 1.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func update_dial(i: int, value: int, cursor: int, locked: bool) -> void:
	if i < 0 or i >= dials.size():
		return
	var d: Dictionary = dials[i]
	if locked and not d.locked:
		Pal.sfx("click", -4.0, 1.4)
	d.value = value
	d.cursor = cursor
	d.locked = locked

func reveal(p_answer: String, p_ranked: Array) -> void:
	mode = "reveal"
	answer_text = p_answer
	ranked = p_ranked
	_k = 0.0
	create_tween().tween_property(self, "_k", 1.0, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Pal.sfx("ding", -4.0, 1.1)

func close() -> void:
	Fx.fade(self, 0.0, 0.3)

static func group(n: int, is_year := false) -> String:
	var neg := n < 0
	var s := str(absi(n))
	if not is_year and s.length() > 3:
		var sep := "." if Pal.tr_lang() else ","
		var out := ""
		var c := 0
		for i in range(s.length() - 1, -1, -1):
			out = s[i] + out
			c += 1
			if c % 3 == 0 and i > 0:
				out = sep + out
		s = out
	return ("−" if neg else "") + s

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	for i in dials.size():
		var d: Dictionary = dials[i]
		var digs := _digits_of(int(d.value), int(d.digits))
		for k in digs.size():
			if i < _roll.size() and k < _roll[i].size():
				_roll[i][k] = Fx.damp(_roll[i][k], float(digs[k]), 16.0, delta)
	queue_redraw()

func _digits_of(v: int, n: int) -> Array:
	var s := str(clampi(v, 0, int(pow(10, n)) - 1)).pad_zeros(n)
	var out := []
	for ch in s:
		out.append(int(ch))
	return out

func _draw() -> void:
	var y0 := -(1.0 - _k) * 60.0
	var h := 300.0
	var r := Rect2(Vector2(0, y0), Vector2(W, h))
	var pts := Icons.notched(r, 16.0)
	draw_colored_polygon(Icons.notched(Rect2(r.position + Vector2(0, 12), r.size), 16.0), Color(0, 0, 0, 0.4))
	draw_colored_polygon(pts, Color(0.055, 0.022, 0.028, 0.94))
	draw_rect(Rect2(16, y0, W - 32, 4), Pal.GOLD)
	Icons.outline(self, pts, Color(Pal.BRASS, 0.55), 1.0)
	var kf := Pal.kicker()
	var ks := Pal.upper(kicker)
	var x := 30.0
	for i in ks.length():
		draw_string(kf, Vector2(x, y0 + 40), ks.substr(i, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Pal.GOLD)
		x += kf.get_char_size(ks.unicode_at(i), 19).x + 4
	if mode == "ask":
		_draw_ask(y0)
	else:
		_draw_reveal(y0)

func _draw_ask(y0: float) -> void:
	var para := TextParagraph.new()
	para.width = W - 80
	para.alignment = HORIZONTAL_ALIGNMENT_CENTER
	para.add_string(question, Pal.serif_semi(), 32)
	para.draw(get_canvas_item(), Vector2(40, y0 + 56), Pal.CHAMPAGNE)
	var qh := para.get_size().y
	if unit != "":
		var us := Pal.t("cq.unit", {"u": unit})
		var uw := Pal.italic().get_string_size(us, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
		draw_string(Pal.italic(), Vector2((W - uw) * 0.5, y0 + 66 + qh + 8), us, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(Pal.CREAM, 0.75))
	# kadranlar
	var n := dials.size()
	if n == 0:
		return
	var dw := 44.0
	var gap := 40.0
	var widths := []
	var total := 0.0
	for d in dials:
		var w := maxf(int(d.digits) * dw + 20.0, 170.0)
		widths.append(w)
		total += w
	total += gap * (n - 1)
	var scale_k := minf(1.0, (W - 60) / total)
	var x := (W - total * scale_k) * 0.5
	var y := y0 + 190.0
	draw_set_transform(Vector2(x, y), 0.0, Vector2.ONE * scale_k)
	var cx := 0.0
	for i in n:
		var d: Dictionary = dials[i]
		var w: float = widths[i]
		var col: Color = d.color
		var locked: bool = d.locked
		# ad
		var nm := Pal.upper(String(d.name))
		draw_string(Pal.display_bold(), Vector2(cx, -12), nm, HORIZONTAL_ALIGNMENT_LEFT, w, 22, col.lightened(0.35))
		if locked:
			Icons.draw(self, "check", Vector2(cx + w - 14, -20), 18, Pal.GOOD, 3.0)
		var digits := int(d.digits)
		var bx := cx + (w - digits * dw) * 0.5
		for k in digits:
			var rr := Rect2(bx + k * dw, 0, dw - 6, 62)
			var cur := k == int(d.cursor) and not locked
			draw_rect(rr, Color("140A0C"))
			var line := Pal.GOOD if locked else (Pal.GOLD if cur else Color(Pal.BRASS, 0.6))
			draw_rect(rr, line, false, 2.0 if cur or locked else 1.0)
			# dönen rakam: iki rakam arası kayar
			var rv: float = _roll[i][k] if i < _roll.size() and k < _roll[i].size() else 0.0
			var base := int(floor(rv))
			var frac := rv - base
			var f := Pal.display()
			for j in 2:
				var dig := (base + j) % 10
				var yy := 50.0 - (frac - j) * 58.0
				if yy < 6 or yy > 70:
					continue
				var s := str(dig)
				var sw := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 46).x
				var a := 1.0 - absf(frac - j) * 1.2
				draw_string(f, Vector2(rr.position.x + (rr.size.x - sw) * 0.5, rr.position.y + yy), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 46, Color(Pal.CHAMPAGNE, clampf(a, 0.0, 1.0)))
			if cur:
				var bob := sin(_t * 8.0) * 2.0
				Icons.draw(self, "arrow_r", Vector2(rr.position.x + rr.size.x * 0.5, -2 + bob), 12, Pal.GOLD, 2.0)
		cx += w + gap
	draw_set_transform(Vector2.ZERO)
	var hint := Pal.t("cq.dial_how")
	var hw := Pal.italic().get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(Pal.italic(), Vector2((W - hw) * 0.5, y0 + 288), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(Pal.CREAM, 0.6))

func _draw_reveal(y0: float) -> void:
	var f := Pal.display()
	draw_string(Pal.italic(), Vector2(30, y0 + 78), Pal.t("cq.answer"), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(Pal.CREAM, 0.8))
	var at := answer_text
	var fs := 92
	var aw := f.get_string_size(at, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pop := 1.0 + (1.0 - clampf(_k, 0.0, 1.0)) * 0.3
	draw_set_transform(Vector2(30 + aw * 0.5, y0 + 160), 0.0, Vector2.ONE * pop)
	draw_string(f, Vector2(-aw * 0.5, 4), at, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.5))
	draw_string(f, Vector2(-aw * 0.5, 0), at, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.GOLD)
	draw_set_transform(Vector2.ZERO)
	var q := question
	var para := TextParagraph.new()
	para.width = 460
	para.max_lines_visible = 3
	para.add_string(q, Pal.italic(), 18)
	para.draw(get_canvas_item(), Vector2(30, y0 + 196), Color(Pal.CREAM, 0.7))
	# sıralama: sağda satırlar
	var x0 := 520.0
	var rows := mini(ranked.size(), 8)
	var rh := minf(30.0, 250.0 / maxf(1, rows))
	for i in rows:
		var row: Dictionary = ranked[i]
		var a := clampf(_k * 3.0 - i * 0.25, 0.0, 1.0)
		var y := y0 + 52 + i * rh
		var col: Color = row.color
		if bool(row.get("win", false)):
			draw_rect(Rect2(x0 - 10, y - 2, W - x0 - 20, rh - 2), Color(Pal.GOLD, 0.1 * a))
			Icons.draw(self, "crown", Vector2(x0 + 8, y + rh * 0.45), 18, Color(Pal.GOLD, a))
		else:
			draw_string(Pal.italic_black(), Vector2(x0 + 2, y + rh * 0.7), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(Pal.CREAM, 0.6 * a))
		draw_circle(Vector2(x0 + 36, y + rh * 0.45), 8, Color(col, a))
		draw_string(Pal.display_bold(), Vector2(x0 + 52, y + rh * 0.72), Pal.upper(String(row.name)), HORIZONTAL_ALIGNMENT_LEFT, 170, 22, Color(Pal.CHAMPAGNE, a))
		draw_string(Pal.display(), Vector2(x0 + 230, y + rh * 0.74), String(row.guess_text), HORIZONTAL_ALIGNMENT_LEFT, 150, 24, Color(Pal.CHAMPAGNE, a))
		var bx := x0 + 390
		var bw := 170.0
		draw_rect(Rect2(bx, y + rh * 0.3, bw, 8), Color(0, 0, 0, 0.5 * a))
		draw_rect(Rect2(bx, y + rh * 0.3, bw * float(row.ratio) * a, 8), Color(col, a))
		draw_string(Pal.italic(), Vector2(bx + bw + 12, y + rh * 0.72), String(row.diff_text), HORIZONTAL_ALIGNMENT_LEFT, 140, 17, Color(Pal.CREAM, 0.7 * a))
