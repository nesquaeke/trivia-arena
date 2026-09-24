@tool
class_name Stepper
extends HBoxContainer
## − [sayı] +   Sayı yuvarlanarak değişir.

signal changed(value: int)

@export var value := 3:
	set(v):
		value = clampi(v, min_value, max_value)
		if _num:
			_num.value = value
		_refresh()
@export var min_value := 0
@export var max_value := 7
@export var font_size := 56

var _num: RollingNumber
var _minus: IconButton
var _plus: IconButton

func _ready() -> void:
	add_theme_constant_override("separation", 14)
	alignment = BoxContainer.ALIGNMENT_BEGIN
	_minus = IconButton.new()
	_minus.icon_name = "minus"
	_minus.pressed.connect(func(): _step(-1))
	add_child(_minus)
	_num = RollingNumber.new()
	_num.font_size = font_size
	_num.align = 1
	_num.custom_minimum_size = Vector2(84, 56)
	_num.color = Pal.GOLD
	add_child(_num)
	_num.snap(value)
	_plus = IconButton.new()
	_plus.icon_name = "plus"
	_plus.pressed.connect(func(): _step(1))
	add_child(_plus)
	_refresh()

func _step(d: int) -> void:
	var v := clampi(value + d, min_value, max_value)
	if v == value:
		if _num:
			Fx.shake(_num, 5.0, 0.25)
		return
	value = v
	changed.emit(value)

func _refresh() -> void:
	if _minus:
		_minus.disabled = value <= min_value
		_plus.disabled = value >= max_value
