@tool
class_name MarqueeLogo
extends Control
## Ana logo: el yazısı "Trivia" + ampullü blok harflerle "ARENA".
## play() ile açılış animasyonu: ampuller sırayla yanar, harfler titreyerek açılır.

@export var tagline := "":
	set(v):
		tagline = v
		if _kick:
			_kick.text = v
			_kick.visible = v != ""
@export var script_word := "Trivia"
@export var block_word := "ARENA"

var _halo: ColorRect
var _script: KineticText
var _block: KineticText
var _bulbs: ColorRect
var _bulb_mat: ShaderMaterial
var _kick: KickerLabel
var _sheen: ShaderMaterial

func _ready() -> void:
	custom_minimum_size = Vector2(620, 300)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in get_children():
		if c.has_meta("gen"):
			c.queue_free()
	_halo = ColorRect.new()
	var hm := ShaderMaterial.new()
	hm.shader = preload("res://ui/shaders/spot.gdshader")
	hm.set_shader_parameter("color", Color(1.0, 0.72, 0.38))
	hm.set_shader_parameter("intensity", 0.22)
	hm.set_shader_parameter("radius", Vector2(0.5, 0.42))
	hm.set_shader_parameter("dust", 0.9)
	_halo.material = hm
	_halo.position = Vector2(-120, -60)
	_halo.size = Vector2(860, 420)
	_halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mark(_halo)
	_kick = KickerLabel.new()
	_kick.text = tagline
	_kick.visible = tagline != ""
	_kick.position = Vector2(6, 0)
	_kick.size = Vector2(560, 28)
	_kick.spacing = 6.0
	_kick.font_size = 19
	_mark(_kick)
	_block = KineticText.new()
	_block.text = block_word
	_block.font = Pal.display()
	_block.font_size = 200
	_block.spacing = 6.0
	_block.color = Pal.CHAMPAGNE
	_block.shadow = Color(0.3, 0.02, 0.05, 0.9)
	_block.shadow_offset = Vector2(0, 8)
	_block.outline_size = 0
	_block.style = 2
	_block.stagger = 0.11
	_block.duration = 0.7
	_block.fit = false
	_block.position = Vector2(0, 72)
	_block.size = Vector2(620, 190)
	_mark(_block)
	_script = KineticText.new()
	_script.text = script_word
	_script.font = Pal.italic_black()
	_script.font_size = 104
	_script.color = Pal.GOLD
	_script.shadow = Color(0.12, 0.02, 0.02, 0.85)
	_script.shadow_offset = Vector2(3, 6)
	_script.style = 1
	_script.stagger = 0.05
	_script.idle_wave = 1.6
	_script.fit = false
	_script.position = Vector2(4, 8)
	_script.size = Vector2(420, 130)
	_sheen = ShaderMaterial.new()
	_sheen.shader = preload("res://ui/shaders/sheen.gdshader")
	_sheen.set_shader_parameter("size", _script.size)
	_sheen.set_shader_parameter("period", 4.5)
	_sheen.set_shader_parameter("strength", 0.8)
	_script.material = _sheen
	_mark(_script)
	_bulbs = ColorRect.new()
	_bulb_mat = ShaderMaterial.new()
	_bulb_mat.shader = preload("res://ui/shaders/bulbs.gdshader")
	_bulb_mat.set_shader_parameter("row_only", true)
	_bulb_mat.set_shader_parameter("size", Vector2(600, 24))
	_bulb_mat.set_shader_parameter("spacing", 30.0)
	_bulb_mat.set_shader_parameter("radius", 5.0)
	_bulb_mat.set_shader_parameter("inset", 8.0)
	_bulb_mat.set_shader_parameter("chase", 4.0)
	_bulbs.material = _bulb_mat
	_bulbs.position = Vector2(0, 262)
	_bulbs.size = Vector2(600, 24)
	_bulbs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mark(_bulbs)
	if not Engine.is_editor_hint():
		play()

func _mark(c: Control) -> void:
	c.set_meta("gen", true)
	add_child(c)

func play() -> void:
	_block.play(0.35)
	_script.play(1.05)
	_bulb_mat.set_shader_parameter("intro", 0.0)
	var tw := create_tween()
	tw.tween_method(func(v: float): _bulb_mat.set_shader_parameter("intro", v), 0.0, 1.0, 1.2).set_delay(0.1)
	_kick.modulate.a = 0.0
	create_tween().tween_property(_kick, "modulate:a", 1.0, 0.8).set_delay(1.4)

func _draw() -> void:
	# ARENA'nın arkasında ince bir pirinç çerçeve çizgisi
	draw_line(Vector2(0, 256), Vector2(600, 256), Color(Pal.BRASS, 0.55), 1.0)
	draw_line(Vector2(0, 292), Vector2(600, 292), Color(Pal.BRASS, 0.35), 1.0)
