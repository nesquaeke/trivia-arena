@tool
class_name KineticText
extends Control
## Harf harf canlanan başlık yazısı. play() ile oynat.
##
## Stiller:
##   drop    harfler yukarıdan düşüp yerine oturur (tur başlıkları)
##   rise    aşağıdan yükselir
##   flicker neon tabela gibi titreyerek yanar (logo)
##   type    daktilo
## Inspector'dan yazıyı, fontu, boyutu değiştir; editörde canlı görünür.

@export var text := "TRIVIA":
	set(v):
		text = v
		_measure()
		queue_redraw()
@export var font: Font:
	set(v):
		font = v
		_measure()
		queue_redraw()
@export var font_size := 96:
	set(v):
		font_size = v
		_measure()
		queue_redraw()
@export var color := Color("FFF1D2")
@export var shadow := Color(0, 0, 0, 0.55)
@export var shadow_offset := Vector2(0, 6)
@export var outline_color := Color(0, 0, 0, 0)
@export var outline_size := 0
@export var spacing := 0.0:
	set(v):
		spacing = v
		_measure()
		queue_redraw()
@export_enum("left", "center", "right") var align := 0:
	set(v):
		align = v
		queue_redraw()
@export_enum("drop", "rise", "flicker", "type", "none") var style := 0
@export var stagger := 0.045
@export var duration := 0.55
@export var idle_wave := 0.0          ## harflerin hafif dalgalanması (piksel)
@export var fit := true               ## genişliğe sığmazsa küçült
@export var autoplay := false

var _t := 99.0
var _widths: PackedFloat32Array = []
var _total := 0.0
var _fs := 96
var _seed := 0.0

func _ready() -> void:
	_seed = randf() * 10.0
	_measure()
	if autoplay and not Engine.is_editor_hint():
		play()

func play(delay := 0.0) -> void:
	_t = -delay
	set_process(true)
	queue_redraw()

func finish() -> void:
	_t = 99.0
	queue_redraw()

func set_text_play(s: String, delay := 0.0) -> void:
	text = s
	play(delay)

func _measure() -> void:
	if font == null:
		font = Pal.display()
	_fs = font_size
	_widths.resize(text.length())
	_total = 0.0
	for i in text.length():
		var w := font.get_char_size(text.unicode_at(i), _fs).x + spacing
		_widths[i] = w
		_total += w
	if fit and size.x > 10.0 and _total > size.x:
		var k := size.x / _total
		_fs = maxi(8, int(font_size * k))
		_total = 0.0
		for i in text.length():
			var w := font.get_char_size(text.unicode_at(i), _fs).x + spacing * k
			_widths[i] = w
			_total += w

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_measure()

func _process(delta: float) -> void:
	_t += delta
	if _t > 60.0 and idle_wave <= 0.0 and style != 2:
		set_process(false)
	queue_redraw()

func _ease_out_back(x: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3) + c1 * pow(x - 1.0, 2)

func _draw() -> void:
	if font == null or text.is_empty():
		return
	var asc := font.get_ascent(_fs)
	var desc := font.get_descent(_fs)
	var base_y := (size.y + asc - desc) * 0.5
	var x := 0.0
	match align:
		1: x = (size.x - _total) * 0.5
		2: x = size.x - _total
	var n := text.length()
	for i in n:
		var ch := text.substr(i, 1)
		var w := _widths[i]
		var k := 1.0
		if style != 4:
			k = clampf((_t - i * stagger) / duration, 0.0, 1.0)
		var a := 1.0
		var off := Vector2.ZERO
		var sc := 1.0
		var rot := 0.0
		match style:
			0:
				var e := _ease_out_back(k)
				off.y = -(1.0 - e) * _fs * 0.7
				a = clampf(k * 2.5, 0.0, 1.0)
				rot = (1.0 - e) * (0.25 if i % 2 == 0 else -0.25)
			1:
				var e := _ease_out_back(k)
				off.y = (1.0 - e) * _fs * 0.5
				a = clampf(k * 2.0, 0.0, 1.0)
			2:
				# neon: rastgele titreyip yanar, sonra ara sıra göz kırpar
				var on := k >= 1.0
				if not on:
					a = 0.15 + 0.85 * float(fmod(sin((i + 1) * 91.7 + _t * 43.0) * 43758.5, 1.0) > 0.45) * k
				else:
					var blink := sin(_t * 0.9 + i * 1.7 + _seed) > 0.995
					a = 0.35 if blink else 1.0
			3:
				a = 1.0 if k > 0.0 else 0.0
				sc = 1.0 + (1.0 - k) * 0.4
		if idle_wave > 0.0:
			off.y += sin(_t * 2.2 + i * 0.55) * idle_wave
		if a <= 0.001:
			x += w
			continue
		var cx := x + w * 0.5
		draw_set_transform(Vector2(cx, base_y) + off, rot, Vector2.ONE * sc)
		var p := Vector2(-w * 0.5 + spacing * 0.5, 0)
		if shadow.a > 0.0:
			draw_string(font, p + shadow_offset, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs, Color(shadow, shadow.a * a))
		if outline_size > 0:
			draw_string_outline(font, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs, outline_size, Color(outline_color, outline_color.a * a))
		draw_string(font, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs, Color(color, color.a * a))
		x += w
	draw_set_transform(Vector2.ZERO)

func text_width() -> float:
	return _total
