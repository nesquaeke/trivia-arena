class_name Playbill
extends Control
## "Nasıl oynanır" afişi: krem kağıt, kırmızı başlık bandı, numaralı adımlar.
## Yukarıdan sallanarak iner; tıklayınca ya da düğmeyle kalkar.

signal closed

var head := "BU GECE"
var title := "TRIVIA ARENA"
var steps: Array = []           # [[simge, metin]]
var foot := ""
var _swing := 0.0
var _swing_v := 0.0
var _close: CtaButton

const W := 820.0
const H := 940.0

func _ready() -> void:
	size = Vector2(W, H)
	pivot_offset = Vector2(W * 0.5, -40)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_close = CtaButton.new()
	_close.style = "velvet"
	_close.size = Vector2(300, 62)
	_close.position = Vector2((W - 300) * 0.5, H - 92)
	_close.font_size = 26
	_close.pressed.connect(func(): closed.emit())
	add_child(_close)
	visible = false

func fill(mode: String) -> void:
	head = Pal.t("howto.head")
	title = Pal.t("menu.conquest") if mode == "conquest" else Pal.t("menu.trivia")
	if mode == "conquest":
		steps = [["diamond", Pal.t("howto.c1")], ["star", Pal.t("howto.c2")], ["bolt", Pal.t("howto.c3")], ["flame", Pal.t("howto.c4")], ["crown", Pal.t("howto.c5")]]
	else:
		steps = [["star", Pal.t("howto.r_tug")], ["diamond", Pal.t("howto.r_1")], ["siphon", Pal.t("howto.r_2")], ["heart", Pal.t("howto.r_3")], ["bolt", Pal.t("howto.r_4")]]
	foot = Pal.t("howto.keys")
	_close.label = Pal.t("howto.close")
	queue_redraw()

func drop() -> void:
	visible = true
	position.y = -H - 60
	rotation = 0.0
	_swing = 0.12
	_swing_v = 0.0
	var tw := create_tween()
	tw.tween_property(self, "position:y", 60.0, 0.8).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	Pal.sfx("whoosh", -6.0, 0.7)

func lift() -> void:
	var tw := create_tween()
	tw.tween_property(self, "position:y", -H - 80.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): visible = false)

func _process(delta: float) -> void:
	if not visible:
		return
	_swing_v += (-_swing * 40.0 - _swing_v * 2.2) * delta
	_swing += _swing_v * delta
	rotation = _swing * 0.25

func _draw() -> void:
	# ipler
	draw_line(Vector2(120, 0), Vector2(W * 0.5, -300), Color(Pal.BRASS, 0.8), 2.0)
	draw_line(Vector2(W - 120, 0), Vector2(W * 0.5, -300), Color(Pal.BRASS, 0.8), 2.0)
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(Rect2(Vector2(10, 16), size), Color(0, 0, 0, 0.45))
	draw_rect(r, Color("EFE2C4"))
	# kağıt lekeleri
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 40:
		draw_circle(Vector2(rng.randf() * W, rng.randf() * H), rng.randf_range(10, 60), Color(0.6, 0.45, 0.25, 0.025))
	draw_rect(r.grow(-16), Color(Pal.VELVET, 0.8), false, 3.0)
	draw_rect(r.grow(-24), Color(Pal.VELVET, 0.5), false, 1.0)
	# kırmızı bant
	draw_rect(Rect2(24, 24, W - 48, 70), Pal.VELVET)
	var kf := Pal.kicker()
	var hs := Pal.upper(head)
	var hw := 0.0
	for i in hs.length():
		hw += kf.get_char_size(hs.unicode_at(i), 30).x + 12
	var x := (W - hw) * 0.5
	for i in hs.length():
		draw_string(kf, Vector2(x, 70), hs.substr(i, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Pal.GOLD)
		x += kf.get_char_size(hs.unicode_at(i), 30).x + 12
	Icons.draw(self, "star", Vector2(70, 59), 24, Pal.GOLD)
	Icons.draw(self, "star", Vector2(W - 70, 59), 24, Pal.GOLD)
	var f := Pal.display()
	var ts := Pal.upper(title)
	var tw := f.get_string_size(ts, HORIZONTAL_ALIGNMENT_LEFT, -1, 108).x
	draw_string(f, Vector2((W - tw) * 0.5, 206), ts, HORIZONTAL_ALIGNMENT_LEFT, -1, 108, Color("2A0A10"))
	draw_line(Vector2(80, 232), Vector2(W - 80, 232), Color(Pal.VELVET, 0.6), 2.0)
	var y := 262.0
	for i in steps.size():
		var st: Array = steps[i]
		var c := Vector2(84, y + 26)
		draw_circle(c, 28, Pal.VELVET)
		Icons.draw(self, String(st[0]), c, 30, Pal.GOLD)
		var para := TextParagraph.new()
		para.width = W - 190
		para.add_string(String(st[1]), Pal.serif(), 22)
		para.draw(get_canvas_item(), Vector2(134, y), Color("2A140C"))
		y += maxf(64.0, para.get_size().y + 22.0)
	var ff := Pal.italic()
	var fw := ff.get_string_size(foot, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	draw_string(ff, Vector2((W - fw) * 0.5, H - 116), foot, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("5A2A18"))
