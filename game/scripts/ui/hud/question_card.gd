class_name QuestionCard
extends Control
## Üst ortadaki soru kartı: kategori etiketi, soru sayacı, soru metni
## (kelime kelime yazılır), yerdeki kapaklarla aynı renkte dört şık.
## Can turunda sağda kırmızı "bedel" mührü.

const W := 1180.0
const H := 262.0

var label := ""
var cat_name := ""
var cat_color := Color("B8893B")
var stake := 0
var reveal := -1
var pips := Vector2i(0, 0)        # (şimdiki, toplam)

var _q: Label
var _answers: Array[Control] = []
var _texts: Array = []
var _t := 0.0
var _reveal_t := 0.0
var _shown := false
var _tw: Tween

func _ready() -> void:
	size = Vector2(W, H)
	pivot_offset = Vector2(W * 0.5, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_q = Label.new()
	_q.add_theme_font_override("font", Pal.serif_semi())
	_q.add_theme_font_size_override("font_size", 36)
	_q.add_theme_color_override("font_color", Pal.CHAMPAGNE)
	_q.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_q.add_theme_constant_override("shadow_offset_y", 3)
	_q.add_theme_constant_override("line_spacing", -4)
	_q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_q.position = Vector2(60, 58)
	_q.size = Vector2(W - 120, 104)
	add_child(_q)
	for i in 4:
		var a := Control.new()
		a.position = Vector2(24 + i * ((W - 48) / 4.0), 176)
		a.size = Vector2((W - 48) / 4.0 - 12, 66)
		a.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var idx := i
		a.draw.connect(func(): _draw_answer(a, idx))
		add_child(a)
		_answers.append(a)
	visible = false

func show_question(p_label: String, prompt: String, options: Array, p_cat: String, p_col: Color, p_stake: int, p_pips: Vector2i) -> void:
	label = p_label
	cat_name = p_cat
	cat_color = p_col
	stake = p_stake
	pips = p_pips
	reveal = -1
	_texts = options
	_q.text = prompt
	var fs := 36
	if prompt.length() > 110:
		fs = 30
	elif prompt.length() > 80:
		fs = 33
	_q.add_theme_font_size_override("font_size", fs)
	visible = true
	modulate.a = 1.0
	# giriş: kart yukarıdan düşer, metin yazılır, şıklar sırayla fırlar
	position.y = -H - 20
	if _tw:
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(self, "position:y", 22.0, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_q.visible_ratio = 0.0
	var tw2 := create_tween()
	tw2.tween_property(_q, "visible_ratio", 1.0, clampf(prompt.length() * 0.012, 0.35, 1.1)).set_delay(0.3)
	for i in 4:
		_answers[i].modulate.a = 0.0
		Fx.pop(_answers[i], 0.55 + i * 0.07 + prompt.length() * 0.006, 0.7, 0.4)
	_shown = true

func show_reveal(correct: int) -> void:
	reveal = correct
	_reveal_t = 0.0
	if correct >= 0 and correct < 4:
		Fx.punch(_answers[correct], 0.1, 0.5)

func hide_card() -> void:
	if not _shown:
		return
	_shown = false
	if _tw:
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(self, "position:y", -H - 40.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_tw.tween_callback(func(): visible = false)

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_reveal_t += delta
	queue_redraw()
	for a in _answers:
		a.queue_redraw()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var pts := Icons.notched(r, 16.0)
	draw_colored_polygon(Icons.notched(Rect2(Vector2(0, 12), size), 16.0), Color(0, 0, 0, 0.4))
	draw_colored_polygon(pts, Color(0.055, 0.022, 0.028, 0.93))
	# kategori renginde üst ışık
	var glow := Color(cat_color, 0.22)
	var clear := Color(cat_color, 0.0)
	draw_polygon(PackedVector2Array([Vector2(16, 0), Vector2(W - 16, 0), Vector2(W, 16), Vector2(W, 120), Vector2(0, 120), Vector2(0, 16)]),
		PackedColorArray([glow, glow, glow, clear, clear, glow]))
	draw_rect(Rect2(16, 0, W - 32, 4), cat_color)
	Icons.outline(self, pts, Color(Pal.BRASS, 0.55), 1.0)
	# kategori etiketi (paralelkenar)
	var f := Pal.italic_black()
	var cn := cat_name
	var cw := f.get_string_size(cn, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	var tag := PackedVector2Array([Vector2(24, 16), Vector2(24 + cw + 44, 16), Vector2(24 + cw + 30, 52), Vector2(10, 52)])
	draw_colored_polygon(tag, cat_color)
	draw_string(f, Vector2(34, 43), cn, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Pal.INK)
	# soru sayacı + noktalar
	var kf := Pal.kicker()
	var lab := Pal.upper(label)
	var lx := 24 + cw + 64
	draw_string(kf, Vector2(lx, 42), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(Pal.CREAM, 0.85))
	var px := lx + kf.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 22
	if pips.y > 0 and pips.y <= 16:
		for i in pips.y:
			var on := i <= pips.x
			var cur := i == pips.x
			var c := Vector2(px + i * 20, 35)
			var s := 12.0 + (3.0 * sin(_t * 6.0) if cur else 0.0)
			Icons.draw(self, "diamond", c, s, Pal.GOLD if on else Color(Pal.CREAM, 0.2))
	# can turunda bedel mührü
	if stake > 0:
		var sr := Rect2(W - 250, 12, 226, 44)
		draw_colored_polygon(Icons.notched(sr, 8.0), Pal.VELVET)
		Icons.outline(self, Icons.notched(sr, 8.0), Color(Pal.HEART, 0.9), 1.5)
		Icons.draw(self, "heart", Vector2(sr.position.x + 26, sr.position.y + 23), 22 + 2.0 * sin(_t * 7.0), Pal.HEART)
		draw_string(kf, Vector2(sr.position.x + 48, sr.position.y + 30), Pal.upper(Pal.t("hud.stake_s")), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(Pal.CREAM, 0.8))
		draw_string(Pal.display(), Vector2(sr.position.x + 110, sr.position.y + 36), "−%d" % stake, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Pal.CHAMPAGNE)

func _draw_answer(a: Control, i: int) -> void:
	var r := Rect2(Vector2.ZERO, a.size)
	var zc: Color = Pal.ZONE[i]
	var is_right := reveal == i
	var is_wrong := reveal >= 0 and reveal != i
	var alpha := 0.38 if is_wrong else 1.0
	var pts := Icons.notched(r, 8.0)
	var bg := Color(0.1, 0.045, 0.05, 0.95)
	if is_right:
		var k := clampf(_reveal_t * 3.0, 0.0, 1.0)
		bg = bg.lerp(zc.darkened(0.35), k)
	a.draw_colored_polygon(pts, Color(bg, alpha))
	Icons.outline(a, pts, Color(zc, (0.9 if is_right else 0.55) * alpha), 2.0 if is_right else 1.0)
	# harf kutusu
	var lr := Rect2(0, 0, 58, a.size.y)
	a.draw_colored_polygon(PackedVector2Array([Vector2(8, 0), Vector2(58, 0), Vector2(58, a.size.y), Vector2(8, a.size.y), Vector2(0, a.size.y - 8), Vector2(0, 8)]), Color(zc, alpha))
	var lf := Pal.display()
	var L: String = Pal.LETTERS[i]
	var lw := lf.get_string_size(L, HORIZONTAL_ALIGNMENT_LEFT, -1, 44).x
	a.draw_string(lf, Vector2((lr.size.x - lw) * 0.5, a.size.y * 0.5 + 16), L, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color(Pal.INK, alpha))
	# şık metni (iki satıra kadar)
	var txt := String(_texts[i]) if i < _texts.size() else ""
	var tf := Pal.serif_semi()
	var fs := 24
	var maxw := a.size.x - 58 - 22
	var para := TextParagraph.new()
	para.width = maxw
	para.max_lines_visible = 2
	para.add_string(txt, tf, fs)
	while para.get_line_count() > 2 and fs > 16:
		fs -= 2
		para.clear()
		para.width = maxw
		para.add_string(txt, tf, fs)
	var ph := para.get_size().y
	para.draw(a.get_canvas_item(), Vector2(70, (a.size.y - ph) * 0.5), Color(Pal.CHAMPAGNE, alpha))
	if is_right:
		Icons.draw(a, "check", Vector2(a.size.x - 22, 16), 22, Pal.GOOD, 3.0)
	if is_wrong:
		var pw := minf(para.get_size().x, maxw)
		a.draw_line(Vector2(66, a.size.y * 0.5), Vector2(74 + pw, a.size.y * 0.5), Color(Pal.BAD, 0.7), 2.0)
