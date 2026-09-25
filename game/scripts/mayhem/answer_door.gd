class_name AnswerDoor
extends Node3D
## Dört Kapı: sahnenin arkasında duran oyun şovu kapısı. Pirinç kasa, renkli kapı
## kanadı, üstünde ampullü tabela (harf + cevap). Doğru kapı açılır, içinden altın
## ışık taşar; yanlış kapı sarsılır ve kırmızı yanar.

const W := 2.2
const H := 2.9

var letter := "A"
var color := Color.WHITE
var _leaf: Node3D
var _sign: Label3D
var _glow: OmniLight3D
var _inner: MeshInstance3D
var _bulbs: Array[MeshInstance3D] = []
var _t := 0.0

func setup(p_letter: String, p_color: Color) -> void:
	letter = p_letter
	color = p_color
	_build()

func _mat(c: Color, rough := 0.35, metal := 0.0, emit := 0.0) -> StandardMaterial3D:
	return PropIcons.mat(c, rough, metal, emit)

func _box(parent: Node3D, size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi

func _build() -> void:
	var brass := _mat(Color("C9A15A"), 0.28, 0.85)
	var dark := _mat(Color("1A0C08"), 0.8)
	# kasa
	_box(self, Vector3(0.18, H + 0.2, 0.3), Vector3(-W * 0.5 - 0.09, (H + 0.2) * 0.5, 0), brass)
	_box(self, Vector3(0.18, H + 0.2, 0.3), Vector3(W * 0.5 + 0.09, (H + 0.2) * 0.5, 0), brass)
	_box(self, Vector3(W + 0.36, 0.2, 0.3), Vector3(0, H + 0.1, 0), brass)
	# kapının arkası: karanlık (açılınca ışık)
	_inner = _box(self, Vector3(W, H, 0.05), Vector3(0, H * 0.5, -0.12), dark)
	_glow = OmniLight3D.new()
	_glow.position = Vector3(0, H * 0.5, 0.4)
	_glow.light_color = Color("FFD27A")
	_glow.light_energy = 0.0
	_glow.omni_range = 4.0
	add_child(_glow)
	# kanat: sol menteşeden döner
	_leaf = Node3D.new()
	_leaf.position = Vector3(-W * 0.5, 0, 0.02)
	add_child(_leaf)
	var panel := _mat(color.darkened(0.15), 0.4)
	_box(_leaf, Vector3(W, H, 0.12), Vector3(W * 0.5, H * 0.5, 0), panel)
	var trim := _mat(color.lightened(0.25), 0.3)
	for r in [Rect2(0.2, 0.25, W - 0.4, 1.05), Rect2(0.2, 1.5, W - 0.4, 1.15)]:
		_box(_leaf, Vector3(r.size.x, r.size.y, 0.03), Vector3(r.position.x + r.size.x * 0.5, r.position.y + r.size.y * 0.5, 0.075), trim)
	var knob := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.08
	sm.height = 0.16
	knob.mesh = sm
	knob.material_override = brass
	knob.position = Vector3(W - 0.22, 1.3, 0.12)
	_leaf.add_child(knob)
	var big := Label3D.new()
	big.text = letter
	big.font = Pal.display()
	big.font_size = 300
	big.pixel_size = 0.004
	big.outline_size = 24
	big.outline_modulate = Color(0.1, 0.03, 0.02)
	big.modulate = Color("FFF1D2")
	big.position = Vector3(W * 0.5, 1.95, 0.1)
	_leaf.add_child(big)
	# üstte ampullü tabela
	var board := _box(self, Vector3(W + 0.6, 0.9, 0.12), Vector3(0, H + 0.68, 0), dark)
	board.name = "Sign"
	for i in 14:
		var b := MeshInstance3D.new()
		var bs := SphereMesh.new()
		bs.radius = 0.04
		bs.height = 0.08
		b.mesh = bs
		b.material_override = _mat(Color("FFE2A0"), 0.3, 0.0, 2.2)
		var u := i / 13.0
		b.position = Vector3(lerpf(-W * 0.5 - 0.22, W * 0.5 + 0.22, u), H + 1.1, 0.08) if i < 14 else Vector3.ZERO
		add_child(b)
		_bulbs.append(b)
	_sign = Label3D.new()
	_sign.font = Pal.display()
	_sign.font_size = 72
	_sign.pixel_size = 0.004
	_sign.width = (W + 0.4) / 0.004
	_sign.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sign.outline_size = 10
	_sign.outline_modulate = Color(0.05, 0.02, 0.02)
	_sign.modulate = color.lightened(0.45)
	_sign.position = Vector3(0, H + 0.66, 0.08)
	add_child(_sign)

func set_answer(text: String) -> void:
	_sign.text = text
	_sign.font_size = 72 if text.length() <= 16 else (58 if text.length() <= 26 else 46)
	close()

func close() -> void:
	var tw := create_tween()
	tw.tween_property(_leaf, "rotation:y", 0.0, 0.3).set_trans(Tween.TRANS_BACK)
	_glow.light_energy = 0.0
	_inner.material_override = _mat(Color("1A0C08"), 0.8)

func _process(delta: float) -> void:
	_t += delta
	for i in _bulbs.size():
		var on := int(_t * 6.0 + i) % 3 != 0
		_bulbs[i].visible = on

## Doğru: kapı açılır, içeriden altın ışık
func open_right() -> void:
	var tw := create_tween()
	tw.tween_property(_leaf, "rotation:y", deg_to_rad(-105.0), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_inner.material_override = _mat(Color("FFD27A"), 0.3, 0.0, 3.0)
	create_tween().tween_property(_glow, "light_energy", 6.0, 0.4)

## Yanlış: kapı titrer, kırmızı yanar
func shake_wrong() -> void:
	var tw := create_tween()
	for k in 4:
		tw.tween_property(_leaf, "rotation:y", deg_to_rad(-8.0 if k % 2 == 0 else 4.0), 0.06)
	tw.tween_property(_leaf, "rotation:y", 0.0, 0.1)
	_glow.light_color = Color("FF4A3A")
	_glow.light_energy = 2.5
	create_tween().tween_property(_glow, "light_energy", 0.0, 1.2).set_delay(0.3)
	get_tree().create_timer(1.6).timeout.connect(func(): if is_instance_valid(_glow): _glow.light_color = Color("FFD27A"))
