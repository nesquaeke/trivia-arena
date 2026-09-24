@tool
class_name RollingNumber
extends Control
## Sayaç gibi dönen sayı. value değişince eski değerden yenisine akar,
## artışta yeşil, düşüşte kırmızı parlar ve hafifçe zıplar.

@export var value := 0:
	set(v):
		if v == value:
			return
		var up := v > value
		value = v
		if not is_inside_tree() or Engine.is_editor_hint():
			_shown = v
			queue_redraw()
			return
		_flash = 1.0
		_flash_col = up_color if up else down_color
		_kick = 1.0 if up else -1.0
		set_process(true)
@export var font: Font
@export var font_size := 48
@export var color := Color("FFF1D2")
@export var up_color := Color("8EE08A")
@export var down_color := Color("FF6B57")
@export_enum("left", "center", "right") var align := 2
@export var prefix := ""
@export var suffix := ""
@export var speed := 7.0
@export var shadow := Color(0, 0, 0, 0.5)

var _shown := 0.0
var _flash := 0.0
var _flash_col := Color.WHITE
var _kick := 0.0

func _ready() -> void:
	_shown = value
	if font == null:
		font = Pal.display()

func snap(v: int) -> void:
	value = v
	_shown = v
	_flash = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	_shown = Fx.damp(_shown, value, speed, delta)
	if absf(_shown - value) < 0.5:
		_shown = value
	_flash = maxf(0.0, _flash - delta * 1.6)
	_kick = move_toward(_kick, 0.0, delta * 3.0)
	queue_redraw()
	if _shown == value and _flash <= 0.0 and _kick == 0.0:
		set_process(false)

func _draw() -> void:
	var f := font if font else Pal.display()
	var s := prefix + str(int(round(_shown))) + suffix
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var x := 0.0
	match align:
		1: x = (size.x - w) * 0.5
		2: x = size.x - w
	var y := (size.y + f.get_ascent(font_size) - f.get_descent(font_size)) * 0.5 - _kick * 6.0
	var col := color.lerp(_flash_col, _flash * 0.85)
	if shadow.a > 0.0:
		draw_string(f, Vector2(x, y + 3), s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, shadow)
	draw_string(f, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)
