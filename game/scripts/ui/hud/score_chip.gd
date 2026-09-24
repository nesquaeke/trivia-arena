class_name ScoreChip
extends Control
## Skor şeridindeki tek oyuncu: renk şeridi, sıra, isim, dönen sayı;
## can turunda can çubuğu (hasar izi gecikmeli erir), seri alevi, sabotaj simgeleri.

const W := 312.0
const H := 76.0

var row := {}
var rank := 1
var target_y := 0.0
var _num: RollingNumber
var _ghost := 1.0          # can çubuğunun geride kalan izi
var _hp := 1.0
var _delta_txt := ""
var _delta_col := Color.WHITE
var _delta_t := 0.0
var _flash := 0.0
var _t := 0.0
var _shake := 0.0

func _ready() -> void:
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_num = RollingNumber.new()
	_num.font_size = 40
	_num.position = Vector2(W - 124, 4)
	_num.size = Vector2(110, H - 8 if not row.get("hp_mode", false) else 50)
	_num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_num)

func apply(r: Dictionary, p_rank: int) -> void:
	var first := row.is_empty()
	var prev_mode: bool = row.get("hp_mode", false)
	row = r
	rank = p_rank
	var v := int(r.get("value", 0))
	if first or prev_mode != bool(r.get("hp_mode", false)):
		_num.snap(v)
	else:
		_num.value = v
	_num.visible = bool(r.get("alive", true))
	_num.size.y = 50.0 if r.get("hp_mode", false) else H - 8
	var mx := maxf(1.0, float(r.get("max_hp", 1)))
	_hp = clampf(float(r.get("hp", 0)) / mx, 0.0, 1.0)
	if first:
		_ghost = _hp
	var d := int(r.get("delta", 0))
	if d != 0:
		_delta_txt = ("+%d" % d) if d > 0 else ("−%d" % -d)
		_delta_col = Pal.GOOD if d > 0 else Pal.BAD
		_delta_t = 1.0
		_flash = 1.0
		if d < 0:
			_shake = 1.0
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	_ghost = move_toward(_ghost, _hp, delta * (0.0 if _flash > 0.4 else 0.35))
	_delta_t = maxf(0.0, _delta_t - delta * 0.55)
	_flash = maxf(0.0, _flash - delta * 1.5)
	position.y = Fx.damp(position.y, target_y, 9.0, delta)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 2.5)
		position.x = sin(_t * 55.0) * 9.0 * _shake
	queue_redraw()

func _draw() -> void:
	var alive: bool = row.get("alive", true)
	var col: Color = row.get("color", Color.WHITE)
	var r := Rect2(Vector2.ZERO, size)
	var pts := Icons.notched(r, 10.0)
	draw_colored_polygon(Icons.notched(Rect2(Vector2(0, 5), size), 10.0), Color(0, 0, 0, 0.35))
	draw_colored_polygon(pts, Color(0.06, 0.025, 0.03, 0.84))
	if _flash > 0.0:
		draw_colored_polygon(pts, Color(_delta_col, 0.18 * _flash))
	# oyuncu rengi şerit
	draw_colored_polygon(PackedVector2Array([Vector2(0, 10), Vector2(10, 0), Vector2(16, 0), Vector2(16, H), Vector2(10, H), Vector2(0, H - 10)]), col if alive else Color(col, 0.35))
	var line := Color(Pal.GOLD, 0.9) if rank == 1 and alive else Color(Pal.BRASS, 0.35)
	Icons.outline(self, pts, line, 1.5 if rank == 1 else 1.0)
	# sıra
	var fr := Pal.italic_black()
	if alive:
		draw_string(fr, Vector2(26, 50), str(rank), HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Pal.GOLD if rank == 1 else Color(Pal.CREAM, 0.6))
		if rank == 1:
			Icons.draw(self, "crown", Vector2(36, 14), 16, Pal.GOLD)
	else:
		Icons.draw(self, "skull", Vector2(38, 38), 26, Color(Pal.CREAM, 0.55))
	# isim
	var nf := Pal.display_bold()
	var nm := Pal.upper(String(row.get("name", "")))
	var nx := 62.0
	var ncol := Pal.CHAMPAGNE if alive else Color(Pal.CREAM, 0.4)
	draw_string(nf, Vector2(nx, 34), nm, HORIZONTAL_ALIGNMENT_LEFT, W - nx - 126, 28, ncol)
	if not alive:
		var nw := minf(nf.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x, W - nx - 126)
		draw_line(Vector2(nx - 2, 25), Vector2(nx + nw + 2, 25), Color(Pal.BAD, 0.8), 2.0)
	var hp_mode: bool = row.get("hp_mode", false)
	if hp_mode and alive:
		# can çubuğu: gecikmeli iz + gerçek değer
		var bx := nx
		var bw := W - nx - 16
		var by := 52.0
		var bh := 12.0
		draw_rect(Rect2(bx, by, bw, bh), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(bx, by, bw * _ghost, bh), Color(1, 0.95, 0.85, 0.75))
		var hc := Pal.GOOD.lerp(Color("F2C14E"), clampf((0.6 - _hp) / 0.3, 0.0, 1.0)).lerp(Pal.BAD, clampf((0.3 - _hp) / 0.2, 0.0, 1.0))
		draw_rect(Rect2(bx, by, bw * _hp, bh), hc)
		draw_rect(Rect2(bx, by, bw * _hp, bh * 0.4), Color(1, 1, 1, 0.18))
		for i in range(1, 10):
			draw_line(Vector2(bx + bw * i / 10.0, by), Vector2(bx + bw * i / 10.0, by + bh), Color(0, 0, 0, 0.35), 1.0)
		Icons.draw(self, "heart", Vector2(W - 132, 26), 18, Pal.HEART)
	elif alive:
		# seri ve sabotajlar
		var sx := nx
		var combo := int(row.get("combo", 0))
		if combo >= 2:
			var fl := 1.0 + 0.1 * sin(_t * 12.0)
			Icons.draw(self, "flame", Vector2(sx + 8, 54), 20 * fl, Color("FF8A3C"))
			draw_string(Pal.display(), Vector2(sx + 20, 63), "×%d" % combo, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("FFB35C"))
			sx += 60
		for d in row.get("debuffs", []):
			var dc := Color("9FD8FF") if d == "ice" else Pal.BAD
			draw_circle(Vector2(sx + 11, 55), 12, Color(dc, 0.2))
			Icons.draw(self, String(d), Vector2(sx + 11, 55), 18, dc)
			sx += 28
	# fark yazısı (+500 / −420) sağa doğru uçar
	if _delta_t > 0.0:
		var k := 1.0 - _delta_t
		var p := Vector2(W + 12 + k * 30.0, 48 - k * 10.0)
		var a := clampf(_delta_t * 2.0, 0.0, 1.0)
		draw_string(Pal.display(), p + Vector2(0, 3), _delta_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(0, 0, 0, 0.6 * a))
		draw_string(Pal.display(), p, _delta_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(_delta_col, a))
