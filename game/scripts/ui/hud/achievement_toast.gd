class_name AchievementToast
extends Control
## Başarım açılınca sağ üstten kayan pirinç rozet (Steam'in kendi bildirimi de
## çıkar; bu, Steam olmadan da oyun içinde görünsün diye). Sıraya dizilir.

var _queue: Array = []
var _cur := {}
var _t := -1.0
const DUR := 3.6

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS

func show_toast(title: String, desc: String) -> void:
	_queue.append({"title": title, "desc": desc})
	if _t < 0.0:
		_next()

func _next() -> void:
	if _queue.is_empty():
		_t = -1.0
		return
	_cur = _queue.pop_front()
	_t = 0.0
	Pal.sfx("ui_confirm", 0.0, 0.8)
	Pal.sfx("coin", -4.0)

func _process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	if _t >= DUR:
		_next()
	queue_redraw()

func _draw() -> void:
	if _t < 0.0:
		return
	var inn := clampf(_t / 0.45, 0.0, 1.0)
	var out := clampf((_t - (DUR - 0.4)) / 0.4, 0.0, 1.0)
	var ease := 1.0 - pow(1.0 - inn, 3.0)
	var w := 520.0
	var h := 96.0
	var x := 1920 - 34 - w * ease + out * (w + 40)
	var y := 140.0
	var r := Rect2(x, y, w, h)
	var pts := Icons.notched(r, 14)
	draw_colored_polygon(Icons.notched(Rect2(r.position + Vector2(6, 8), r.size), 14), Color(0, 0, 0, 0.45))
	draw_colored_polygon(pts, Color(0.09, 0.03, 0.035, 0.97))
	Icons.outline(self, pts, Pal.GOLD, 2.0)
	# madalyon
	var c := Vector2(x + 52, y + h * 0.5)
	var spin := _t * 2.0
	draw_circle(c, 34, Pal.BRASS_LO)
	draw_circle(c, 30, Pal.GOLD)
	for i in 12:
		var a := TAU * i / 12.0 + spin
		draw_circle(c + Vector2(cos(a), sin(a)) * 38, 2.2, Color(Pal.CHAMPAGNE, 0.6 + 0.4 * sin(_t * 8.0 + i)))
	Icons.draw(self, "crown", c + Vector2(0, 2), 34, Pal.VELVET)
	var kf := Pal.kicker()
	var ks := Pal.upper(Pal.t("ach.unlocked"))
	var kx := x + 104
	for i in ks.length():
		draw_string(kf, Vector2(kx, y + 32), ks.substr(i, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.GOLD)
		kx += kf.get_char_size(ks.unicode_at(i), 15).x + 3
	draw_string(Pal.display(), Vector2(x + 104, y + 66), Pal.upper(String(_cur.get("title", ""))), HORIZONTAL_ALIGNMENT_LEFT, w - 120, 34, Pal.CHAMPAGNE)
	draw_string(Pal.italic(), Vector2(x + 104, y + 88), String(_cur.get("desc", "")), HORIZONTAL_ALIGNMENT_LEFT, w - 120, 16, Color(Pal.CREAM, 0.75))
