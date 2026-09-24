class_name RoundBadge
extends Control
## Sol üst köşe: PERDE II · GÜÇ TURU

var kicker := ""
var title := ""
var _k := 0.0

func _ready() -> void:
	size = Vector2(420, 100)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_round(p_kicker: String, p_title: String) -> void:
	if p_kicker == kicker and p_title == title:
		return
	kicker = p_kicker
	title = p_title
	_k = 0.0
	visible = title != "" or kicker != ""
	create_tween().tween_property(self, "_k", 1.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _process(_d: float) -> void:
	queue_redraw()

func _draw() -> void:
	var kf := Pal.kicker()
	var x := -30.0 * (1.0 - _k)
	var a := _k
	draw_rect(Rect2(0, 12, 4, 72 * _k), Pal.GOLD)
	var ks := Pal.upper(kicker)
	var cx := 18.0 + x
	for i in ks.length():
		draw_string(kf, Vector2(cx, 34), ks.substr(i, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(Pal.GOLD, a))
		cx += kf.get_char_size(ks.unicode_at(i), 18).x + 4
	var f := Pal.display()
	draw_string(f, Vector2(18 + x, 82), Pal.upper(title), HORIZONTAL_ALIGNMENT_LEFT, size.x - 20, 46, Color(0, 0, 0, 0.5 * a))
	draw_string(f, Vector2(18 + x, 78), Pal.upper(title), HORIZONTAL_ALIGNMENT_LEFT, size.x - 20, 46, Color(Pal.CHAMPAGNE, a))
