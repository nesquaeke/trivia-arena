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
	var fs := 50
	while fs > 30 and f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > size.x - 120:
		fs -= 2
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var band_w := maxf(w, 400.0) + 260.0
	var a := clampf(_k * 1.6, 0.0, 1.0)
	# gradyan bant
	var y0 := 8.0
	var y1 := size.y - 8.0
	var mid := Color(0.05, 0.02, 0.025, 0.86 * a)
	var edge := Color(0.05, 0.02, 0.025, 0.0)
	var l := cx - band_w * 0.5
	var r := cx + band_w * 0.5
	draw_polygon(PackedVector2Array([Vector2(l, y0), Vector2(cx, y0), Vector2(cx, y1), Vector2(l, y1)]), PackedColorArray([edge, mid, mid, edge]))
	draw_polygon(PackedVector2Array([Vector2(cx, y0), Vector2(r, y0), Vector2(r, y1), Vector2(cx, y1)]), PackedColorArray([mid, edge, edge, mid]))
	var lw := band_w * 0.42 * _line
	draw_line(Vector2(cx - lw, y0), Vector2(cx + lw, y0), accent, 2.0)
	draw_line(Vector2(cx - lw * 0.6, y1), Vector2(cx + lw * 0.6, y1), Color(accent, 0.4), 1.0)
	Icons.draw(self, "diamond", Vector2(cx - lw, y0), 9, accent)
	Icons.draw(self, "diamond", Vector2(cx + lw, y0), 9, accent)
	var ty := (58.0 if sub != "" else 80.0) + (1.0 - _k) * 26.0
	draw_string(f, Vector2(cx - w * 0.5, ty + 4), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.6 * a))
	draw_string(f, Vector2(cx - w * 0.5, ty), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(accent.lerp(Pal.CHAMPAGNE, 0.35), a))
	if sub != "":
		var sf := Pal.italic()
		var sw := sf.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 25).x
		var sa := clampf((_k - 0.3) * 2.0, 0.0, 1.0)
		draw_string(sf, Vector2(cx - sw * 0.5, ty + 42), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color(Pal.CREAM, sa))
