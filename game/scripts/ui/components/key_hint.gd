@tool
class_name KeyHint
extends Control
## Tuş kapakları ile kısa ipuçları:  [WASD] koş   [BOŞLUK] zıpla   [F] omuz
## items: ["WASD|Koş", "BOŞLUK|Zıpla"] biçiminde (tuş|açıklama)

@export var items: PackedStringArray = ["WASD|Koş", "BOŞLUK|Zıpla", "F|Omuz at"]:
	set(v):
		items = v
		queue_redraw()
@export var font_size := 19
@export var color := Color("EAD9B8")
@export_enum("left", "center", "right") var align := 0
@export var lead := ""        ## başa italik bir söz (ör. "Katıl:")

func _init() -> void:
	custom_minimum_size.y = 36
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _layout() -> Array:
	var fk := Pal.display_bold()
	var fl := Pal.italic()
	var parts := []
	var x := 0.0
	if lead != "":
		var lw := fl.get_string_size(lead, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		parts.append(["lead", x, lead, lw])
		x += lw + 14
	for it in items:
		var sp := String(it).split("|")
		var keys := sp[0].split("+")
		for k in keys:
			var ks := Pal.upper(k.strip_edges())
			var kw := maxf(font_size * 1.5, fk.get_string_size(ks, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 2).x + 18)
			parts.append(["key", x, ks, kw])
			x += kw + 6
		if sp.size() > 1:
			var lw := fl.get_string_size(sp[1], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			parts.append(["label", x + 4, sp[1], lw])
			x += lw + 30
	return [parts, x - 30]

func _draw() -> void:
	var lay := _layout()
	var parts: Array = lay[0]
	var total: float = lay[1]
	var ox := 0.0
	match align:
		1: ox = (size.x - total) * 0.5
		2: ox = size.x - total
	var h := font_size * 1.55
	var cy := size.y * 0.5
	var fk := Pal.display_bold()
	var fl := Pal.italic()
	for p in parts:
		var x: float = ox + p[1]
		match p[0]:
			"key":
				var r := Rect2(x, cy - h * 0.5, p[3], h)
				draw_rect(Rect2(r.position + Vector2(0, 3), r.size), Color(0, 0, 0, 0.5))
				draw_colored_polygon(Icons.notched(r, 4.0), Color(Pal.INK, 0.75))
				Icons.outline(self, Icons.notched(r, 4.0), Color(Pal.GOLD, 0.7), 1.0)
				draw_line(r.position + Vector2(4, h - 3), Vector2(r.end.x - 4, r.end.y - 3), Color(Pal.GOLD, 0.35), 2.0)
				var kw := fk.get_string_size(p[2], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 2).x
				draw_string(fk, Vector2(x + (p[3] - kw) * 0.5, cy + (font_size - 2) * 0.36), p[2], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 2, Pal.CHAMPAGNE)
			"label", "lead":
				draw_string(fl, Vector2(x + 1, cy + font_size * 0.36 + 2), p[2], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.6))
				draw_string(fl, Vector2(x, cy + font_size * 0.36), p[2], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color if p[0] == "label" else Pal.GOLD)
