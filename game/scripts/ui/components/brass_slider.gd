@tool
class_name BrassSlider
extends Control
## Pirinç kaydırıcı (ses düzeyleri). Fareyle tıkla/sürükle; odaktayken
## sol/sağ (klavye, gamepad) %5 adımla değiştirir. Sağda yüzde yazar.

signal changed(value: float)

@export var value := 0.7:
	set(v):
		value = clampf(v, 0.0, 1.0)
		queue_redraw()
@export var step := 0.05

var _h := 0.0
var _drag := false
var _pulse := 0.0

const TRACK_W := 330.0

func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(430, 44)

func _ready() -> void:
	focus_entered.connect(func(): Pal.sfx("tick", -12.0, 1.6))

func _set_from_x(x: float) -> void:
	var v := clampf((x - 12.0) / TRACK_W, 0.0, 1.0)
	v = snappedf(v, step)
	if absf(v - value) > 0.001:
		value = v
		changed.emit(value)
		Pal.sfx("tick", -14.0, 0.9 + value)

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		_drag = ev.pressed
		if ev.pressed:
			grab_focus()
			_set_from_x(ev.position.x)
		accept_event()
	elif ev is InputEventMouseMotion and _drag:
		_set_from_x(ev.position.x)
		accept_event()
	elif ev.is_action_pressed("ui_left") or ev.is_action_pressed("ui_right"):
		var d := -step if ev.is_action_pressed("ui_left") else step
		var v := clampf(snappedf(value + d, step), 0.0, 1.0)
		if v != value:
			value = v
			changed.emit(value)
			_pulse = 1.0
			Pal.sfx("tick", -12.0, 0.9 + value)
		accept_event()

func _process(delta: float) -> void:
	_h = Fx.damp(_h, 1.0 if has_focus() or _drag else 0.0, 12.0, delta)
	_pulse = maxf(0.0, _pulse - delta * 4.0)
	queue_redraw()

func _draw() -> void:
	var cy := size.y * 0.5
	var x0 := 12.0
	# oluk
	draw_rect(Rect2(x0, cy - 5, TRACK_W, 10), Color(0.05, 0.02, 0.02, 0.9))
	draw_rect(Rect2(x0, cy - 5, TRACK_W, 10), Color(Pal.BRASS, 0.35 + 0.4 * _h), false, 1.0)
	# dolu kısım: pirinç
	var fw := TRACK_W * value
	draw_rect(Rect2(x0, cy - 5, fw, 10), Pal.BRASS_LO.lerp(Pal.BRASS, 0.6))
	draw_rect(Rect2(x0, cy - 5, fw, 3), Pal.GOLD)
	# çentikler
	for i in 11:
		var tx := x0 + TRACK_W * i / 10.0
		draw_line(Vector2(tx, cy + 9), Vector2(tx, cy + (15 if i % 5 == 0 else 12)), Color(Pal.CREAM, 0.3), 1.0)
	# topuz
	var kx := x0 + fw
	var r := 13.0 + 3.0 * _h + 3.0 * _pulse
	draw_circle(Vector2(kx, cy + 2), r, Color(0, 0, 0, 0.45))
	draw_circle(Vector2(kx, cy), r, Pal.BRASS)
	draw_circle(Vector2(kx - r * 0.25, cy - r * 0.25), r * 0.55, Pal.GOLD)
	draw_circle(Vector2(kx, cy), r * 0.28, Pal.BRASS_LO)
	if _h > 0.02:
		draw_arc(Vector2(kx, cy), r + 5, 0, TAU, 28, Color(Pal.GOLD, 0.6 * _h), 2.0, true)
	var pct := "%d%%" % int(round(value * 100.0))
	draw_string(Pal.display_bold(), Vector2(x0 + TRACK_W + 26, cy + 10), pct, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Pal.CREAM.lerp(Pal.CHAMPAGNE, _h))
