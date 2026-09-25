class_name NumberLine
extends Node3D
## "En Yakın Kazanır": sahnenin boyunca uzanan pirinç bir sayı doğrusu.
## Oyuncunun sahnedeki x konumu onun tahminidir. Geniş aralıklarda logaritmik.

const X0 := -5.9
const X1 := 5.9
const Z := 3.05

var lo := 0.0
var hi := 100.0
var year := false
var log_scale := false
var _pin: Node3D

func setup(p_lo: float, p_hi: float, p_year: bool) -> void:
	lo = p_lo
	hi = max(p_hi, p_lo + 1.0)
	year = p_year
	log_scale = (not year) and lo > 0.0 and hi / lo >= 50.0
	_build()

func value_at(x: float) -> float:
	var u := clampf((x - X0) / (X1 - X0), 0.0, 1.0)
	var v: float
	if log_scale:
		v = exp(lerpf(log(lo), log(hi), u))
	else:
		v = lerpf(lo, hi, u)
	return round3(v) if not year else round(v)

func x_of(v: float) -> float:
	var u: float
	if log_scale:
		u = inverse_lerp(log(lo), log(hi), log(maxf(v, lo)))
	else:
		u = inverse_lerp(lo, hi, v)
	return lerpf(X0, X1, clampf(u, 0.0, 1.0))

## Uzaklık (sıralama için): logaritmik ölçekte oran, doğrusal ölçekte fark
func distance(v: float, answer: float) -> float:
	if log_scale:
		return abs(log(maxf(v, 0.0001)) - log(maxf(answer, 0.0001)))
	return abs(v - answer) / max(1.0, hi - lo)

static func round3(v: float) -> float:
	if abs(v) < 10.0:
		return snappedf(v, 0.1)
	var mag := pow(10.0, floor(log(abs(v)) / log(10.0)) - 2.0)
	return round(v / mag) * mag

static func fmt(v: float, is_year: bool, lang := "tr") -> String:
	if is_year:
		return str(int(v))
	if abs(v) < 10.0 and v != floor(v):
		return ("%.1f" % v).replace(".", "," if lang == "tr" else ".")
	var s := str(int(round(v)))
	var out := ""
	var n := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		n += 1
		if n % 3 == 0 and i > 0 and s[i - 1] != "-":
			out = ("." if lang == "tr" else ",") + out
	return out

func _build() -> void:
	for c in get_children():
		c.queue_free()
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color("C9A15A")
	brass.metallic = 0.8
	brass.roughness = 0.3
	var strip := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(X1 - X0 + 0.3, 0.03, 0.12)
	strip.mesh = bm
	strip.material_override = brass
	strip.position = Vector3(0, 0.02, Z)
	add_child(strip)
	# renk geçişli şerit: soldan sağa büyür
	var grad := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(X1 - X0, 0.012, 0.5)
	grad.mesh = gm
	var gmat := ShaderMaterial.new()
	gmat.shader = _grad_shader()
	grad.material_override = gmat
	grad.position = Vector3(0, 0.012, Z - 0.34)
	add_child(grad)
	var ticks := 6
	for i in ticks:
		var u := i / float(ticks - 1)
		var x := lerpf(X0, X1, u)
		var t := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(0.05, 0.05, 0.34)
		t.mesh = tm
		t.material_override = brass
		t.position = Vector3(x, 0.03, Z)
		add_child(t)
		var l := Label3D.new()
		l.text = fmt(value_at(x), year, I18n.lang)
		l.font = Pal.display()
		l.font_size = 64
		l.pixel_size = 0.005
		l.outline_size = 12
		l.outline_modulate = Color(0.05, 0.02, 0.02)
		l.modulate = Color("FFF1D2")
		l.rotation = Vector3(-PI / 2 + 0.35, 0, 0)
		l.position = Vector3(x, 0.05, Z + 0.42)
		add_child(l)

func _grad_shader() -> Shader:
	var s := Shader.new()
	s.code = """shader_type spatial;
render_mode unshaded, cull_disabled;
void fragment() {
	vec3 a = vec3(0.24, 0.55, 0.9);
	vec3 b = vec3(0.95, 0.72, 0.24);
	vec3 c = vec3(0.93, 0.33, 0.28);
	float u = UV.x;
	ALBEDO = u < 0.5 ? mix(a, b, u * 2.0) : mix(b, c, (u - 0.5) * 2.0);
	ALPHA = 0.55 * smoothstep(0.0, 0.25, UV.y) * smoothstep(1.0, 0.75, UV.y);
}"""
	return s

## Doğru cevaba altın bir iğne düşer
func drop_pin(v: float, text: String) -> void:
	if _pin:
		_pin.queue_free()
	_pin = Node3D.new()
	add_child(_pin)
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color("F6CF7B")
	gold.metallic = 0.9
	gold.roughness = 0.2
	gold.emission_enabled = true
	gold.emission = Color("F2B83C")
	gold.emission_energy_multiplier = 0.6
	var shaft := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.05
	cm.bottom_radius = 0.0
	cm.height = 2.4
	shaft.mesh = cm
	shaft.material_override = gold
	shaft.position = Vector3(0, 1.2, 0)
	_pin.add_child(shaft)
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.44
	head.mesh = sm
	head.material_override = gold
	head.position = Vector3(0, 2.45, 0)
	_pin.add_child(head)
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font = Pal.display()
	l.font_size = 90
	l.pixel_size = 0.006
	l.outline_size = 16
	l.outline_modulate = Color(0.1, 0.04, 0.0)
	l.modulate = Color("F6CF7B")
	l.position = Vector3(0, 3.05, 0)
	_pin.add_child(l)
	_pin.position = Vector3(x_of(v), 6.0, Z - 0.3)
	var tw := create_tween()
	tw.tween_property(_pin, "position:y", 0.0, 0.55).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
