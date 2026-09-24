class_name Callout
extends Control
## Alt ortadaki duyuru bandı. Yeni mesaj gelince eskisi yukarı kayıp söner,
## yenisi alttan yükselir; vurgu çizgisi ortadan iki yana açılır.

var text := ""
var sub := ""
var accent := Color("F6CF7B")
var _k := 0.0          # 0→1 giriş
var _line := 0.0
var _t := 0.0

func _ready() -> void:
	size = Vector2(1400, 130)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func say(p_text: String, p_accent := Color("F6CF7B"), p_sub := "") -> void:
	if p_text == text and p_sub == sub:
		return
	var had := text != ""
	text = p_text
	sub = p_sub
	accent = p_accent
	if text == "":
		Fx.fade(self, 0.0, 0.25)
		return
	Fx.cancel_fade(self)
	visible = true
	modulate.a = 1.0
	_k = 0.0
	_line = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "_k", 1.0, 0.45 if had else 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_line", 1.0, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	_t += delta
	if visible:
		queue_redraw()

func _draw() -> void:
	if text == "":
		return
	var cx := size.x * 0.5
	var f := Pal.display()
	var s := Pal.upper(text)
	var fs := 46
	while fs > 28 and f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > size.x - 260:
		fs -= 2
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var a := clampf(_k * 1.6, 0.0, 1.0)
	var open := 1.0 - pow(1.0 - clampf(_line, 0.0, 1.0), 3.0)
	# kurdele: ortadan iki yana açılır
	var full := w + 150.0
	var half := full * 0.5 * maxf(open, 0.08)
	var y0 := 18.0
	var y1 := 84.0
	var tail := accent.darkened(0.35)
	var tail_d := accent.darkened(0.6)
	for side: float in [-1.0, 1.0]:
		var ex := cx + side * half
		# arkada katlanan kuyruk (mesaj sahibinin renginde), kırlangıç kesikli
		var tpts := PackedVector2Array([Vector2(ex - side * 18, y0 + 12), Vector2(ex + side * 64, y0 + 12), Vector2(ex + side * 44, (y0 + y1) * 0.5 + 12),
			Vector2(ex + side * 64, y1 + 12), Vector2(ex - side * 18, y1 + 12)])
		draw_colored_polygon(tpts, Color(tail, a))
		draw_colored_polygon(PackedVector2Array([Vector2(ex - side * 18, y1), Vector2(ex, y1), Vector2(ex - side * 18, y1 + 12)]), Color(tail_d, a))
	# gölge ve gövde
	draw_rect(Rect2(cx - half + 4, y0 + 8, half * 2, y1 - y0), Color(0, 0, 0, 0.45 * a))
	var body := PackedVector2Array([Vector2(cx - half, y0), Vector2(cx + half, y0), Vector2(cx + half, y1), Vector2(cx - half, y1)])
	var top := Color(Pal.VELVET_HI.darkened(0.1), 0.97 * a)
	var bot := Color(Pal.VELVET.darkened(0.25), 0.97 * a)
	draw_polygon(body, PackedColorArray([top, top, bot, bot]))
	draw_line(Vector2(cx - half, y0 + 5), Vector2(cx + half, y0 + 5), Color(Pal.GOLD, 0.8 * a), 1.5)
	draw_line(Vector2(cx - half, y1 - 5), Vector2(cx + half, y1 - 5), Color(Pal.GOLD, 0.5 * a), 1.0)
	# ışık süzmesi (kadife parlaması) soldan sağa bir kez geçer
	var sweep := clampf(_line * 1.3 - 0.2, 0.0, 1.0)
	if sweep > 0.0 and sweep < 1.0:
		var sx := cx - half + half * 2 * sweep
		draw_polygon(PackedVector2Array([Vector2(sx - 40, y0), Vector2(sx + 10, y0), Vector2(sx - 10, y1), Vector2(sx - 60, y1)]),
			PackedColorArray([Color(1, 1, 1, 0), Color(1, 0.9, 0.7, 0.18), Color(1, 0.9, 0.7, 0.18), Color(1, 1, 1, 0)]))
	# metin: harfler ortadan açılan kurdeleyle birlikte belirir
	var ty := (y0 + y1) * 0.5 + fs * 0.36 + (1.0 - _k) * 10.0
	var ta := clampf((open - 0.35) * 2.2, 0.0, 1.0) * a
	draw_string(f, Vector2(cx - w * 0.5, ty + 3), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.55 * ta))
	draw_string(f, Vector2(cx - w * 0.5, ty), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Pal.CHAMPAGNE, ta))
	for side: float in [-1.0, 1.0]:
		Icons.draw(self, "diamond", Vector2(cx + side * (w * 0.5 + 34), (y0 + y1) * 0.5), 11, Color(accent.lightened(0.25), ta))
	if sub != "":
		var sf := Pal.italic()
		var sw := sf.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		var sa := clampf((_k - 0.3) * 2.0, 0.0, 1.0) * ta
		var sy := y1 + 40
		var mid := Color(0.03, 0.01, 0.015, 0.8 * sa)
		var edge := Color(0.03, 0.01, 0.015, 0.0)
		var sl := cx - sw * 0.5 - 90
		var sr := cx + sw * 0.5 + 90
		draw_polygon(PackedVector2Array([Vector2(sl, sy - 26), Vector2(cx, sy - 26), Vector2(cx, sy + 10), Vector2(sl, sy + 10)]), PackedColorArray([edge, mid, mid, edge]))
		draw_polygon(PackedVector2Array([Vector2(cx, sy - 26), Vector2(sr, sy - 26), Vector2(sr, sy + 10), Vector2(cx, sy + 10)]), PackedColorArray([mid, edge, edge, mid]))
		draw_string(sf, Vector2(cx - sw * 0.5, sy), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(Pal.CREAM, sa))
