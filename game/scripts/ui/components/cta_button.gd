@tool
class_name CtaButton
extends Button
## Ana eylem düğmesi: köşeleri kesik altın levha, üstünden parıltı geçer.
## style = "gold" (ana), "ghost" (ince çerçeve), "velvet" (kırmızı)

@export var label := "PERDE AÇILSIN":
	set(v):
		label = v
		queue_redraw()
@export_enum("gold", "ghost", "velvet") var style := "gold":
	set(v):
		style = v
		_apply_material()
		queue_redraw()
@export var font_size := 34
@export var icon_name := ""

var _h := 0.0
var _hover := false
var _press := 0.0
var _mat: ShaderMaterial

func _init() -> void:
	flat = true
	text = ""
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(220, 64)

func _ready() -> void:
	for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(st, StyleBoxEmpty.new())
	mouse_entered.connect(func():
		_hover = true
		Pal.sfx("ui_hover", -6.0, 0.9))
	mouse_exited.connect(func(): _hover = false)
	button_down.connect(func():
		_press = 1.0
		Pal.sfx("ui_back" if style == "ghost" else "ui_confirm", -2.0))
	_apply_material()
	set_process(true)

func _apply_material() -> void:
	if style == "gold":
		if _mat == null:
			_mat = ShaderMaterial.new()
			_mat.shader = preload("res://ui/shaders/sheen.gdshader")
			_mat.set_shader_parameter("offset", randf() * 3.0)
		material = _mat
	else:
		material = null

func _process(delta: float) -> void:
	_h = Fx.damp(_h, 1.0 if (_hover or has_focus()) else 0.0, 12.0, delta)
	_press = maxf(0.0, _press - delta * 4.0)
	if _mat:
		_mat.set_shader_parameter("size", size)
		_mat.set_shader_parameter("hover", _h)
	queue_redraw()

func _draw() -> void:
	var grow := 3.0 * _h - 3.0 * _press
	var r := Rect2(Vector2(-grow, -grow), size + Vector2(grow, grow) * 2.0)
	var pts := Icons.notched(r, 12.0)
	var ink := Pal.INK
	var txt_col := ink
	match style:
		"gold":
			var top := Pal.GOLD.lightened(0.12 + 0.1 * _h)
			var bot := Color("B8863A").lerp(Pal.GOLD, 0.2 * _h)
			draw_polygon(pts, PackedColorArray([top, top, top.lerp(bot, 0.3), bot, bot, bot, bot.lerp(top, 0.3), top]))
			Icons.outline(self, Icons.notched(r.grow(-4), 9.0), Color(1, 0.96, 0.8, 0.55), 1.0)
			Icons.outline(self, pts, Color("5A3A12"), 1.5)
		"velvet":
			var top := Pal.VELVET_HI.lightened(0.1 * _h)
			var bot := Pal.VELVET
			draw_polygon(pts, PackedColorArray([top, top, top, bot, bot, bot, bot, top]))
			Icons.outline(self, pts, Color(Pal.GOLD, 0.8), 1.5)
			txt_col = Pal.CHAMPAGNE
		_:
			draw_colored_polygon(pts, Color(Pal.VELVET, 0.55 * _h + 0.12))
			Icons.outline(self, pts, Color(Pal.BRASS, 0.55 + 0.45 * _h), 1.5)
			txt_col = Pal.CREAM.lerp(Pal.CHAMPAGNE, _h)
	var f := Pal.display()
	var s := Pal.upper(label)
	var spacing := 1.0 + 2.0 * _h
	var w := 0.0
	for i in s.length():
		w += f.get_char_size(s.unicode_at(i), font_size).x + spacing
	var icon_w := 0.0
	if icon_name != "":
		icon_w = font_size * 1.2
	var x := (size.x - w - icon_w) * 0.5 + icon_w
	var y := (size.y + f.get_ascent(font_size) - f.get_descent(font_size)) * 0.5
	if icon_name != "":
		Icons.draw(self, icon_name, Vector2(x - icon_w * 0.55, size.y * 0.5), font_size * 1.0, txt_col if style != "ghost" else Pal.GOLD)
	for i in s.length():
		var ch := s.substr(i, 1)
		draw_string(f, Vector2(x, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, txt_col)
		x += f.get_char_size(s.unicode_at(i), font_size).x + spacing
