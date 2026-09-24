class_name TugMeter
extends Control
## Kategori halatı göstergesi: üç sütun, her birinde kategori adı, çekiş
## sayısı ve pay çubuğu. Öndeki kategorinin üstünde taç sallanır.

var names: Array = []
var colors: Array = []
var pulls: Array = []
var left := 0.0
var total := 8.0
var winner := -1
var _share: Array = [0.0, 0.0, 0.0]
var _nums: Array[RollingNumber] = []
var _t := 0.0
var _title := ""
var _sub := ""

const W := 1180.0
const H := 236.0

func _ready() -> void:
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 3:
		var n := RollingNumber.new()
		n.font_size = 72
		n.align = 1
		n.position = Vector2(_col_x(i), 128)
		n.size = Vector2(_col_w(), 70)
		n.speed = 14.0
		add_child(n)
		_nums.append(n)
	visible = false

func _col_w() -> float:
	return (W - 80) / 3.0

func _col_x(i: int) -> float:
	return 40 + i * (_col_w())

func open(p_names: Array, p_colors: Array, title: String, sub: String) -> void:
	names = p_names
	colors = p_colors
	_title = title
	_sub = sub
	winner = -1
	pulls = [0, 0, 0]
	for i in 3:
		_nums[i].snap(0)
		_nums[i].visible = i < names.size()
		_nums[i].up_color = Color(colors[i]).lightened(0.4) if i < colors.size() else Pal.GOOD
	Fx.cancel_fade(self)
	visible = true
	Fx.anchor(self)
	Fx.rise(self, 0.0, Vector2(0, -120), 0.6)

func update_state(p_pulls: Array, p_left: float, p_total: float) -> void:
	pulls = p_pulls
	left = p_left
	total = p_total
	for i in mini(3, pulls.size()):
		if int(pulls[i]) > _nums[i].value:
			Fx.punch(_nums[i], 0.06, 0.2)
		_nums[i].value = int(pulls[i])

func set_winner(i: int) -> void:
	winner = i
	if i >= 0 and i < 3:
		Fx.punch(_nums[i], 0.25, 0.6)

func close() -> void:
	Fx.fade(self, 0.0, 0.35)

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	var tot := 0
	for v in pulls:
		tot += int(v)
	for i in 3:
		var target := float(pulls[i]) / maxf(1.0, tot) if i < pulls.size() else 0.0
		_share[i] = Fx.damp(_share[i], target, 10.0, delta)
	queue_redraw()

func _lead() -> int:
	var best := -1
	var bv := 0
	for i in pulls.size():
		if int(pulls[i]) > bv:
			bv = int(pulls[i])
			best = i
	return best

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var pts := Icons.notched(r, 16.0)
	draw_colored_polygon(pts, Color(0.05, 0.02, 0.025, 0.9))
	Icons.outline(self, pts, Color(Pal.BRASS, 0.5), 1.0)
	# başlık
	var kf := Pal.kicker()
	var ts := Pal.upper(_title)
	var tw := 0.0
	for i in ts.length():
		tw += kf.get_char_size(ts.unicode_at(i), 22).x + 5
	var x := (W - tw) * 0.5
	for i in ts.length():
		draw_string(kf, Vector2(x, 36), ts.substr(i, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Pal.GOLD)
		x += kf.get_char_size(ts.unicode_at(i), 22).x + 5
	var sf := Pal.italic()
	var sw := sf.get_string_size(_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	draw_string(sf, Vector2((W - sw) * 0.5, 64), _sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(Pal.CREAM, 0.8))
	var lead := winner if winner >= 0 else _lead()
	for i in mini(3, names.size()):
		var cx := _col_x(i)
		var cw := _col_w()
		var col: Color = colors[i]
		var dim := winner >= 0 and winner != i
		var a := 0.35 if dim else 1.0
		if i == lead:
			var gr := Rect2(cx + 10, 80, cw - 20, 150)
			draw_colored_polygon(Icons.notched(gr, 10.0), Color(col, 0.14 + 0.05 * sin(_t * 6.0)))
			Icons.outline(self, Icons.notched(gr, 10.0), Color(col, 0.7), 1.5)
			Icons.draw(self, "crown", Vector2(cx + cw * 0.5, 84 + sin(_t * 5.0) * 3.0), 30, Pal.GOLD)
		var nf := Pal.italic_black()
		var nm := String(names[i])
		var nw := nf.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
		draw_string(nf, Vector2(cx + (cw - nw) * 0.5, 122), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(col.lightened(0.35), a))
		_nums[i].modulate.a = a
		# pay çubuğu
		var br := Rect2(cx + 30, 212, cw - 60, 12)
		draw_rect(br, Color(0, 0, 0, 0.55))
		draw_rect(Rect2(br.position, Vector2(br.size.x * _share[i], br.size.y)), Color(col, a))
		draw_rect(Rect2(br.position, Vector2(br.size.x * _share[i], 5)), Color(1, 1, 1, 0.25 * a))
	# süre çizgisi
	var k := clampf(left / maxf(total, 0.01), 0.0, 1.0)
	draw_rect(Rect2(16, H - 6, (W - 32) * k, 3), Pal.GOLD if k > 0.3 else Pal.BAD)
