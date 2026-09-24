@tool
class_name Segmented
extends Control
## Yan yana seçenekler; seçili olanın altına altın blok kayar.
## Fareyle tıkla ya da odaktayken sol/sağ ok.

signal changed(index: int)

@export var options: PackedStringArray = ["Kolay", "Normal", "Zor"]:
	set(v):
		options = v
		queue_redraw()
@export var selected := 1:
	set(v):
		selected = clampi(v, 0, maxi(0, options.size() - 1))
		queue_redraw()
@export var font_size := 26

var _x := -1.0
var _hover := -1

func _init() -> void:
	custom_minimum_size = Vector2(360, 54)
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _ready() -> void:
	set_process(true)
	mouse_exited.connect(func(): _hover = -1)

func _seg_w() -> float:
	return size.x / maxf(1.0, options.size())

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		_hover = clampi(int(e.position.x / _seg_w()), 0, options.size() - 1)
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_pick(clampi(int(e.position.x / _seg_w()), 0, options.size() - 1))
		accept_event()
	if e.is_action_pressed("ui_left"):
		_pick(selected - 1)
		accept_event()
	elif e.is_action_pressed("ui_right"):
		_pick(selected + 1)
		accept_event()

func _pick(i: int) -> void:
	i = clampi(i, 0, options.size() - 1)
	if i == selected:
		return
	selected = i
	Pal.sfx("click", -6.0, 1.2 + i * 0.06)
	changed.emit(i)

func _process(delta: float) -> void:
	var target := selected * _seg_w()
	_x = target if _x < 0.0 else Fx.damp(_x, target, 16.0, delta)
	queue_redraw()

func _draw() -> void:
	var sw := _seg_w()
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(Pal.INK, 0.55))
	Icons.outline(self, Icons.notched(r, 8.0), Color(Pal.BRASS, 0.5), 1.0)
	if _hover >= 0 and _hover != selected:
		draw_rect(Rect2(_hover * sw + 3, 3, sw - 6, size.y - 6), Color(Pal.VELVET_HI, 0.25))
	var hr := Rect2(_x + 3, 3, sw - 6, size.y - 6)
	draw_colored_polygon(Icons.notched(hr, 6.0), Pal.GOLD)
	draw_rect(Rect2(hr.position, Vector2(hr.size.x, hr.size.y * 0.45)), Color(1, 1, 1, 0.12))
	var f := Pal.display_bold()
	for i in options.size():
		var s := Pal.upper(options[i])
		var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var cx := i * sw + sw * 0.5
		var over := clampf(1.0 - absf(cx - (_x + sw * 0.5)) / sw, 0.0, 1.0)
		var col := Pal.CREAM.lerp(Pal.INK, over)
		draw_string(f, Vector2(cx - w * 0.5, (size.y + f.get_ascent(font_size) - f.get_descent(font_size)) * 0.5), s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)
	if has_focus():
		Icons.outline(self, Icons.notched(r.grow(3), 10.0), Color(Pal.GOLD, 0.6), 1.0)
