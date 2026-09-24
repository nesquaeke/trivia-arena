@tool
class_name KickerLabel
extends Control
## Küçük, harf aralıklı üst başlık; iki yanında ince çizgi olabilir.
##   ── BU GECEKİ GÖSTERİ ──

@export var text := "KICKER":
	set(v):
		text = v
		queue_redraw()
@export var font_size := 20
@export var color := Color("F6CF7B")
@export var spacing := 4.0
@export var rules := true
@export_enum("left", "center", "right") var align := 0

func _init() -> void:
	custom_minimum_size.y = 28
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var f := Pal.kicker()
	var s := Pal.upper(text)
	var w := 0.0
	for i in s.length():
		w += f.get_char_size(s.unicode_at(i), font_size).x + spacing
	w -= spacing
	var x := 0.0
	match align:
		1: x = (size.x - w) * 0.5
		2: x = size.x - w
	var y := (size.y + f.get_ascent(font_size) - f.get_descent(font_size)) * 0.5
	if rules:
		var ly := size.y * 0.5 + 1
		if align == 1:
			draw_line(Vector2(0, ly), Vector2(x - 14, ly), Color(color, 0.5), 1.0)
			draw_line(Vector2(x + w + 14, ly), Vector2(size.x, ly), Color(color, 0.5), 1.0)
		elif align == 0:
			draw_line(Vector2(x + w + 14, ly), Vector2(minf(size.x, x + w + 120), ly), Color(color, 0.5), 1.0)
		else:
			draw_line(Vector2(maxf(0, x - 120), ly), Vector2(x - 14, ly), Color(color, 0.5), 1.0)
	for i in s.length():
		draw_string(f, Vector2(x, y), s.substr(i, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		x += f.get_char_size(s.unicode_at(i), font_size).x + spacing
