@tool
class_name GlassPanel
extends MarginContainer
## Koyu, yarı saydam panel: köşeleri kesik, pirinç kıl çizgi, köşelerde
## altın gönye. İçine istediğin kontrolleri koy; kenar boşlukları margin_*.

@export var fill := Color(0.07, 0.03, 0.035, 0.86):
	set(v):
		fill = v
		queue_redraw()
@export var line := Color(0.79, 0.63, 0.35, 0.55)
@export var cut := 14.0
@export var corner_accent := true
@export var accent := Color("F6CF7B")
@export var top_glow := true

func _init() -> void:
	for s in ["left", "right", "top", "bottom"]:
		add_theme_constant_override("margin_" + s, 28)

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var pts := Icons.notched(r, cut)
	draw_colored_polygon(pts, fill)
	if top_glow:
		var top := Color(1, 0.85, 0.6, 0.07)
		var clear := Color(1, 0.85, 0.6, 0.0)
		var hh := minf(160.0, size.y * 0.5)
		draw_polygon(PackedVector2Array([Vector2(cut, 1), Vector2(size.x - cut, 1), Vector2(size.x, hh), Vector2(0, hh)]),
			PackedColorArray([top, top, clear, clear]))
	Icons.outline(self, pts, line, 1.0)
	Icons.outline(self, Icons.notched(r.grow(-6), maxf(2.0, cut - 4.0)), Color(line, line.a * 0.35), 1.0)
	if corner_accent:
		var L := 26.0
		for q in [[Vector2(0, cut), Vector2(0, cut + L), Vector2(cut, 0), Vector2(cut + L, 0)],
				[Vector2(size.x, cut), Vector2(size.x, cut + L), Vector2(size.x - cut, 0), Vector2(size.x - cut - L, 0)],
				[Vector2(0, size.y - cut), Vector2(0, size.y - cut - L), Vector2(cut, size.y), Vector2(cut + L, size.y)],
				[Vector2(size.x, size.y - cut), Vector2(size.x, size.y - cut - L), Vector2(size.x - cut, size.y), Vector2(size.x - cut - L, size.y)]]:
			draw_line(q[0], q[1], accent, 2.0)
			draw_line(q[2], q[3], accent, 2.0)
			draw_line(q[0], q[2], accent, 2.0)
