class_name StandingsBoard
extends Control
## Tur arası sıralama: satırlar sırayla kayarak gelir, çubuklar dolar, puanlar döner.

var rows: Array = []
var round_no := 1
var _k: Array = []
var _nums: Array[RollingNumber] = []
var _t := 0.0

const W := 980.0
const ROW_H := 74.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func open(p_rows: Array, p_round: int) -> void:
	rows = p_rows
	round_no = p_round
	for n in _nums:
		n.queue_free()
	_nums.clear()
	_k.clear()
	size = Vector2(W, 190 + rows.size() * ROW_H)
	position = Vector2((1920 - W) * 0.5, maxf(110.0, (1080 - size.y) * 0.5 - 20))
	var top := 0
	for r in rows:
		top = maxi(top, int(r.get("points", 0)))
	for i in rows.size():
		_k.append(0.0)
		var n := RollingNumber.new()
		n.font_size = 44
		n.position = Vector2(W - 190, 150 + i * ROW_H)
		n.size = Vector2(150, ROW_H - 10)
		n.snap(0)
		add_child(n)
		_nums.append(n)
		var tw := create_tween()
		var idx := i
		tw.tween_method(func(v: float): _k[idx] = v, 0.0, 1.0, 0.6).set_delay(0.25 + i * 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var val := int(rows[i].get("points", 0))
		get_tree().create_timer(0.35 + i * 0.12).timeout.connect(func(): if is_instance_valid(n): n.value = val)
	visible = true
	modulate.a = 0.0
	Fx.fade(self, 1.0, 0.3)

func close() -> void:
	Fx.fade(self, 0.0, 0.35)

func _process(delta: float) -> void:
	if visible:
		_t += delta
		queue_redraw()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var pts := Icons.notched(r, 18.0)
	draw_colored_polygon(Icons.notched(Rect2(Vector2(0, 14), size), 18.0), Color(0, 0, 0, 0.45))
	draw_colored_polygon(pts, Color(0.05, 0.02, 0.025, 0.94))
	Icons.outline(self, pts, Color(Pal.BRASS, 0.6), 1.0)
	var kf := Pal.kicker()
	var k1 := Pal.upper(Pal.t("hud.standings"))
	var x := 48.0
	for i in k1.length():
		draw_string(kf, Vector2(x, 60), k1.substr(i, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Pal.GOLD)
		x += kf.get_char_size(k1.unicode_at(i), 22).x + 5
	draw_string(Pal.display(), Vector2(46, 124), Pal.upper(Pal.t("hud.after", {"n": round_no})), HORIZONTAL_ALIGNMENT_LEFT, -1, 62, Pal.CHAMPAGNE)
	draw_line(Vector2(48, 140), Vector2(W - 48, 140), Color(Pal.BRASS, 0.4), 1.0)
	var top := 1
	for row in rows:
		top = maxi(top, int(row.get("points", 0)))
	for i in rows.size():
		var k: float = _k[i] if i < _k.size() else 1.0
		var row: Dictionary = rows[i]
		var y := 150 + i * ROW_H
		var a := clampf(k, 0.0, 1.0)
		var ox := (1.0 - k) * -80.0
		var col: Color = row.get("color", Color.WHITE)
		if i == 0:
			draw_rect(Rect2(24 + ox, y + 2, W - 48, ROW_H - 8), Color(Pal.GOLD, 0.08 * a))
		draw_string(Pal.italic_black(), Vector2(52 + ox, y + 50), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 42, Color(Pal.GOLD if i == 0 else Pal.CREAM, a))
		var hc := Vector2(128 + ox, y + 34)
		draw_circle(hc + Vector2(-15, -14), 8, Color(col, a))
		draw_circle(hc + Vector2(15, -14), 8, Color(col, a))
		draw_circle(hc, 20, Color(col, a))
		draw_circle(hc + Vector2(-7, -2), 2.5, Color(Pal.INK, a))
		draw_circle(hc + Vector2(7, -2), 2.5, Color(Pal.INK, a))
		draw_string(Pal.display_bold(), Vector2(170 + ox, y + 46), Pal.upper(String(row.get("name", ""))), HORIZONTAL_ALIGNMENT_LEFT, 260, 34, Color(Pal.CHAMPAGNE, a))
		var bx := 440.0 + ox
		var bw := 300.0
		var share := float(row.get("points", 0)) / float(top)
		draw_rect(Rect2(bx, y + 26, bw, 14), Color(0, 0, 0, 0.5 * a))
		draw_rect(Rect2(bx, y + 26, bw * share * k, 14), Color(col, a))
		var combo := int(row.get("combo", 0))
		if combo >= 2:
			Icons.draw(self, "flame", Vector2(bx + 10, y + 58), 14, Color("FF8A3C", a))
			draw_string(Pal.italic(), Vector2(bx + 22, y + 63), Pal.t("hud.best_combo", {"n": combo}), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(Pal.CREAM, 0.7 * a))
		if i < _nums.size():
			_nums[i].modulate.a = a
