class_name ResultScreen
extends Control
## Final: soldan karartma, "PERDE!", kazanan adı, sıralama tablosu ve
## konfeti. Kazanan pelüş sahnede altın spot altında kalır (sağda görünür).

signal again
signal back

var _scrim: ColorRect
var _head: KineticText
var _title: KineticText
var _list: VBoxContainer
var _again: CtaButton
var _back: CtaButton
var _confetti: CPUParticles2D

func _ready() -> void:
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scrim = ColorRect.new()
	var sm := ShaderMaterial.new()
	sm.shader = preload("res://ui/shaders/scrim.gdshader")
	sm.set_shader_parameter("reach", 0.62)
	sm.set_shader_parameter("strength", 0.94)
	_scrim.material = sm
	_scrim.size = Vector2(1500, 1080)
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scrim)
	_head = KineticText.new()
	_head.font = Pal.italic_black()
	_head.font_size = 150
	_head.color = Pal.GOLD
	_head.style = 1
	_head.stagger = 0.06
	_head.shadow_offset = Vector2(4, 10)
	_head.position = Vector2(84, 40)
	_head.size = Vector2(760, 180)
	_head.fit = false
	var sheen := ShaderMaterial.new()
	sheen.shader = preload("res://ui/shaders/sheen.gdshader")
	sheen.set_shader_parameter("size", _head.size)
	sheen.set_shader_parameter("period", 2.6)
	_head.material = sheen
	add_child(_head)
	_title = KineticText.new()
	_title.font = Pal.display()
	_title.font_size = 64
	_title.color = Pal.CHAMPAGNE
	_title.style = 0
	_title.stagger = 0.02
	_title.position = Vector2(92, 206)
	_title.size = Vector2(780, 80)
	add_child(_title)
	_list = VBoxContainer.new()
	_list.position = Vector2(92, 306)
	_list.size = Vector2(760, 560)
	_list.add_theme_constant_override("separation", 6)
	add_child(_list)
	var row := HBoxContainer.new()
	row.position = Vector2(92, 950)
	row.size = Vector2(700, 80)
	row.add_theme_constant_override("separation", 16)
	add_child(row)
	_again = CtaButton.new()
	_again.custom_minimum_size = Vector2(300, 74)
	_again.font_size = 38
	_again.pressed.connect(func(): again.emit())
	row.add_child(_again)
	_back = CtaButton.new()
	_back.style = "ghost"
	_back.custom_minimum_size = Vector2(280, 74)
	_back.font_size = 30
	_back.pressed.connect(func(): back.emit())
	row.add_child(_back)
	_confetti = CPUParticles2D.new()
	_confetti.emitting = false
	_confetti.amount = 220
	_confetti.lifetime = 4.5
	_confetti.one_shot = true
	_confetti.explosiveness = 0.35
	_confetti.position = Vector2(1180, -30)
	_confetti.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_confetti.emission_rect_extents = Vector2(760, 10)
	_confetti.direction = Vector2(0, 1)
	_confetti.spread = 25.0
	_confetti.gravity = Vector2(0, 260)
	_confetti.initial_velocity_min = 80.0
	_confetti.initial_velocity_max = 260.0
	_confetti.angular_velocity_min = -360.0
	_confetti.angular_velocity_max = 360.0
	_confetti.angle_min = 0.0
	_confetti.angle_max = 360.0
	_confetti.scale_amount_min = 0.6
	_confetti.scale_amount_max = 1.3
	_confetti.damping_min = 20.0
	_confetti.damping_max = 40.0
	var img := Image.create(8, 14, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_confetti.texture = ImageTexture.create_from_image(img)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	grad.colors = PackedColorArray([Pal.GOLD, Pal.ZONE[1], Pal.ZONE[2], Pal.CHAMPAGNE, Pal.ZONE[3]])
	_confetti.color_initial_ramp = grad
	add_child(_confetti)
	visible = false

func open(title: String, names: Array, rows: Array) -> void:
	visible = true
	modulate.a = 0.0
	Fx.fade(self, 1.0, 0.4)
	_head.text = Pal.upper(Pal.t("result.title"))
	_title.text = Pal.upper(title)
	_again.label = Pal.t("arena.again")
	_back.label = Pal.t("arena.back")
	_head.play(0.1)
	_title.play(0.6)
	for c in _list.get_children():
		c.queue_free()
	if rows.is_empty():
		for n in names:
			rows.append({"name": n})
	for i in mini(rows.size(), 8):
		var r := _Row.new()
		r.rank = i + 1
		r.data = rows[i]
		r.custom_minimum_size = Vector2(760, 92 if i == 0 else 62)
		_list.add_child(r)
	await get_tree().process_frame
	var j := 0
	for c in _list.get_children():
		Fx.anchor(c)
		Fx.rise(c, 0.9 + j * 0.08, Vector2(-50, 0), 0.5)
		j += 1
	_confetti.restart()
	_confetti.emitting = true
	_again.grab_focus()

func close() -> void:
	Fx.fade(self, 0.0, 0.3)

class _Row extends Control:
	var rank := 1
	var data := {}
	func _draw() -> void:
		var big := rank == 1
		var h := size.y
		var col: Color = data.get("color", Pal.GOLD)
		if big:
			var pts := Icons.notched(Rect2(Vector2.ZERO, size), 12.0)
			draw_colored_polygon(pts, Color(Pal.GOLD, 0.1))
			Icons.outline(self, pts, Color(Pal.GOLD, 0.7), 1.5)
		else:
			draw_line(Vector2(0, h - 1), Vector2(size.x, h - 1), Color(Pal.BRASS, 0.25), 1.0)
		var rf := Pal.italic_black()
		draw_string(rf, Vector2(18, h * 0.5 + (22 if big else 15)), str(rank), HORIZONTAL_ALIGNMENT_LEFT, -1, 60 if big else 40, Pal.GOLD if big else Color(Pal.CREAM, 0.7))
		var hc := Vector2(104, h * 0.5 + 2)
		var hr := 26.0 if big else 18.0
		draw_circle(hc + Vector2(-hr * 0.72, -hr * 0.7), hr * 0.4, col)
		draw_circle(hc + Vector2(hr * 0.72, -hr * 0.7), hr * 0.4, col)
		draw_circle(hc, hr, col)
		draw_circle(hc + Vector2(-hr * 0.35, -hr * 0.1), hr * 0.12, Pal.INK)
		draw_circle(hc + Vector2(hr * 0.35, -hr * 0.1), hr * 0.12, Pal.INK)
		if big:
			Icons.draw(self, "crown", hc + Vector2(0, -hr - 14), 30, Pal.GOLD)
		var alive: bool = data.get("alive", true)
		var nf := Pal.display()
		var nm := Pal.upper(String(data.get("name", "")))
		draw_string(nf, Vector2(150, h * 0.5 + (4 if data.has("points") else 14)), nm, HORIZONTAL_ALIGNMENT_LEFT, 360, 50 if big else 34, Pal.CHAMPAGNE if alive or big else Color(Pal.CREAM, 0.75))
		if data.has("points"):
			var bits := []
			if data.has("correct"):
				bits.append(Pal.t("result.correct_n", {"n": data.correct, "m": data.get("asked", 0)}))
			if int(data.get("best_combo", 0)) >= 2:
				bits.append(Pal.t("hud.best_combo", {"n": data.best_combo}))
			if int(data.get("stolen", 0)) > 0:
				bits.append(Pal.t("result.stolen_n", {"n": data.stolen}))
			draw_string(Pal.italic(), Vector2(152, h * 0.5 + (32 if big else 24)), "  ·  ".join(bits), HORIZONTAL_ALIGNMENT_LEFT, 420, 18 if big else 16, Color(Pal.CREAM, 0.7))
			var val := str(int(data.points))
			var vf := Pal.display()
			var vw := vf.get_string_size(val, HORIZONTAL_ALIGNMENT_LEFT, -1, 52 if big else 38).x
			draw_string(vf, Vector2(size.x - 24 - vw, h * 0.5 + (18 if big else 13)), val, HORIZONTAL_ALIGNMENT_LEFT, -1, 52 if big else 38, Pal.GOLD if big else Pal.CHAMPAGNE)
			if not alive:
				Icons.draw(self, "skull", Vector2(size.x - 44 - vw, h * 0.5), 20, Color(Pal.CREAM, 0.5))
			elif data.has("hp") and int(data.hp) > 0:
				Icons.draw(self, "heart", Vector2(size.x - 44 - vw, h * 0.5), 20, Pal.HEART)
