@tool
class_name IconButton
extends Button
## Küçük sekizgen simge düğmesi (+, −, ok…)

@export var icon_name := "plus":
	set(v):
		icon_name = v
		queue_redraw()
@export var diameter := 54.0

var _h := 0.0
var _hover := false
var _press := 0.0

func _init() -> void:
	flat = true
	text = ""
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(54, 54)

func _ready() -> void:
	custom_minimum_size = Vector2(diameter, diameter)
	for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(st, StyleBoxEmpty.new())
	mouse_entered.connect(func(): _hover = true)
	mouse_exited.connect(func(): _hover = false)
	button_down.connect(func():
		_press = 1.0
		Pal.sfx("click", -6.0, 1.3))
	set_process(true)

func _process(delta: float) -> void:
	_h = Fx.damp(_h, 1.0 if _hover and not disabled else 0.0, 14.0, delta)
	_press = maxf(0.0, _press - delta * 5.0)
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var rad := minf(size.x, size.y) * 0.5 - 2.0 - _press * 3.0
	var pts := PackedVector2Array()
	for i in 8:
		var a := PI / 8.0 + TAU * i / 8.0
		pts.append(c + Vector2(cos(a), sin(a)) * rad)
	draw_colored_polygon(pts, Pal.INK.lerp(Pal.VELVET_HI, 0.2 + 0.5 * _h) if not disabled else Color(Pal.INK, 0.5))
	Icons.outline(self, pts, Color(Pal.GOLD, (0.55 + 0.45 * _h) * (0.4 if disabled else 1.0)), 1.5)
	Icons.draw(self, icon_name, c, rad * 0.9, Color(Pal.CHAMPAGNE, 0.35 if disabled else 1.0), 3.0)
