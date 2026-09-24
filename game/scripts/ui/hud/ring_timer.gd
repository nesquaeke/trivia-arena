class_name RingTimer
extends Control
## Sağ üst halka sayaç. Son 5 saniyede kırmızıya döner, her saniye vurur.

var total := 10.0
var left := 0.0
var _ring: ColorRect
var _mat: ShaderMaterial
var _last_s := -1
var _pulse := 0.0
var _shown := false

func _ready() -> void:
	size = Vector2(156, 156)
	pivot_offset = size * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring = ColorRect.new()
	_ring.size = size
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://ui/shaders/ring.gdshader")
	_ring.material = _mat
	add_child(_ring)
	var num := Control.new()
	num.size = size
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	num.draw.connect(func(): _draw_num(num))
	add_child(num)
	modulate.a = 0.0
	visible = false

func set_time(p_left: float, p_total: float) -> void:
	left = p_left
	total = maxf(0.01, p_total)
	var on := left > 0.0
	if on != _shown:
		_shown = on
		if on:
			Fx.cancel_fade(self)
			visible = true
			Fx.pop(self, 0.0, 0.5, 0.45)
		else:
			Fx.fade(self, 0.0, 0.25)
	var s := int(ceil(left))
	if s != _last_s:
		_last_s = s
		if s <= 5 and s > 0:
			_pulse = 1.0
			Fx.punch(self, 0.08, 0.3)
	queue_redraw()
	for c in get_children():
		c.queue_redraw()

func _process(delta: float) -> void:
	if not visible:
		return
	_pulse = maxf(0.0, _pulse - delta * 2.0)
	var k := clampf(left / total, 0.0, 1.0)
	_mat.set_shader_parameter("progress", k)
	_mat.set_shader_parameter("danger", clampf((5.5 - left) / 3.0, 0.0, 1.0))
	_mat.set_shader_parameter("pulse", _pulse)
	get_child(1).queue_redraw()

func _draw_num(c: Control) -> void:
	var f := Pal.display()
	var s := str(int(ceil(left)))
	var fs := 66
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var col := Pal.CHAMPAGNE.lerp(Pal.BAD.lightened(0.2), clampf((5.5 - left) / 3.0, 0.0, 1.0))
	var y := size.y * 0.5 + fs * 0.36
	c.draw_string(f, Vector2((size.x - w) * 0.5, y + 4), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.6))
	c.draw_string(f, Vector2((size.x - w) * 0.5, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
