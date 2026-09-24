class_name RoundCard
extends Control
## Tur açılışı: kadife perde iner, üstünde Roma rakamı, tur adı harf harf
## düşer, kural kartları sırayla belirir. hide_card() ile perde kalkar.

var _velvet: ColorRect
var _vmat: ShaderMaterial
var _kick: KickerLabel
var _num: KineticText
var _title: KineticText
var _desc: Label
var _chips: HBoxContainer
var _spot: ColorRect

func _ready() -> void:
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_velvet = ColorRect.new()
	_velvet.size = size
	_velvet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vmat = ShaderMaterial.new()
	_vmat.shader = preload("res://ui/shaders/velvet.gdshader")
	_velvet.material = _vmat
	add_child(_velvet)
	_spot = ColorRect.new()
	var sm := ShaderMaterial.new()
	sm.shader = preload("res://ui/shaders/spot.gdshader")
	sm.set_shader_parameter("intensity", 0.35)
	sm.set_shader_parameter("radius", Vector2(0.35, 0.5))
	sm.set_shader_parameter("center", Vector2(0.5, 0.45))
	_spot.material = sm
	_spot.size = size
	_spot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_spot)
	_kick = KickerLabel.new()
	_kick.align = 1
	_kick.font_size = 26
	_kick.spacing = 12.0
	_kick.position = Vector2(560, 190)
	_kick.size = Vector2(800, 36)
	add_child(_kick)
	_num = KineticText.new()
	_num.font = Pal.italic_black()
	_num.font_size = 250
	_num.align = 1
	_num.color = Pal.GOLD
	_num.style = 1
	_num.stagger = 0.08
	_num.shadow = Color(0.15, 0.0, 0.03, 0.8)
	_num.shadow_offset = Vector2(6, 12)
	_num.position = Vector2(460, 200)
	_num.size = Vector2(1000, 280)
	var sheen := ShaderMaterial.new()
	sheen.shader = preload("res://ui/shaders/sheen.gdshader")
	sheen.set_shader_parameter("size", _num.size)
	sheen.set_shader_parameter("period", 2.2)
	sheen.set_shader_parameter("strength", 0.9)
	_num.material = sheen
	add_child(_num)
	_title = KineticText.new()
	_title.font = Pal.display()
	_title.font_size = 170
	_title.align = 1
	_title.spacing = 4.0
	_title.color = Pal.CHAMPAGNE
	_title.style = 0
	_title.stagger = 0.04
	_title.duration = 0.6
	_title.shadow = Color(0.1, 0.0, 0.02, 0.85)
	_title.shadow_offset = Vector2(0, 10)
	_title.position = Vector2(160, 470)
	_title.size = Vector2(1600, 190)
	add_child(_title)
	_desc = Label.new()
	_desc.add_theme_font_override("font", Pal.italic())
	_desc.add_theme_font_size_override("font_size", 34)
	_desc.add_theme_color_override("font_color", Pal.CREAM)
	_desc.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_desc.add_theme_constant_override("shadow_offset_y", 3)
	_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.position = Vector2(360, 672)
	_desc.size = Vector2(1200, 90)
	add_child(_desc)
	_chips = HBoxContainer.new()
	_chips.alignment = BoxContainer.ALIGNMENT_CENTER
	_chips.add_theme_constant_override("separation", 18)
	_chips.position = Vector2(160, 790)
	_chips.size = Vector2(1600, 70)
	add_child(_chips)
	visible = false

func show_card(r: int, title: String, desc: String, chips: Array) -> void:
	visible = true
	modulate.a = 1.0
	for c in [_kick, _num, _title, _desc, _chips, _spot]:
		c.modulate.a = 1.0
	_kick.text = Pal.t("round.kicker")
	_num.text = Pal.roman(r)
	_title.text = Pal.upper(title)
	_desc.text = desc
	for c in _chips.get_children():
		c.queue_free()
	for s in chips:
		var chip := _Chip.new()
		chip.text = String(s)
		_chips.add_child(chip)
	_vmat.set_shader_parameter("drop", 0.0)
	var tw := create_tween()
	tw.tween_method(func(v: float): _vmat.set_shader_parameter("drop", v), 0.0, 1.0, 0.7).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_kick.modulate.a = 0.0
	create_tween().tween_property(_kick, "modulate:a", 1.0, 0.5).set_delay(0.5)
	_num.play(0.55)
	_title.play(0.95)
	_desc.modulate.a = 0.0
	create_tween().tween_property(_desc, "modulate:a", 1.0, 0.6).set_delay(1.6)
	await get_tree().process_frame
	var i := 0
	for c in _chips.get_children():
		Fx.pop(c, 2.0 + i * 0.12, 0.6, 0.45)
		i += 1
	Pal.sfx("fanfare", -10.0, 1.2)

func hide_card() -> void:
	if not visible:
		return
	var tw := create_tween().set_parallel(true)
	for c in [_kick, _num, _title, _desc, _chips, _spot]:
		tw.tween_property(c, "modulate:a", 0.0, 0.25)
	var tw2 := create_tween()
	tw2.tween_interval(0.2)
	tw2.tween_method(func(v: float): _vmat.set_shader_parameter("drop", v), 1.0, 0.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw2.tween_callback(func(): visible = false)

class _Chip extends Control:
	var text := ""
	func _ready() -> void:
		var f := Pal.display_bold()
		custom_minimum_size = Vector2(f.get_string_size(Pal.upper(text), HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x + 70, 60)
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var pts := Icons.notched(r, 10.0)
		draw_colored_polygon(pts, Color(0.05, 0.015, 0.02, 0.7))
		Icons.outline(self, pts, Color(Pal.GOLD, 0.8), 1.5)
		Icons.draw(self, "diamond", Vector2(22, size.y * 0.5), 12, Pal.GOLD)
		draw_string(Pal.display_bold(), Vector2(40, size.y * 0.5 + 10), Pal.upper(text), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Pal.CHAMPAGNE)
