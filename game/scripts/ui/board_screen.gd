class_name BoardScreen
extends Control
## Sahnenin arkasındaki dev panoya yansıtılan ekran (SubViewport içinde çizilir).
## Lobi: kayan ilan. Trivia: kategori, soru, dört şık, süre çubuğu.

const W := 1600
const H := 720
const LETTERS := ["A", "B", "C", "D"]
const ZONE_COLORS := [Color("E9B53A"), Color("3FB6A8"), Color("D9577A"), Color("8C74E0")]

var mode := "marquee"
var marquee_text := ""
var prompt := ""
var options: Array = []
var cat_name := ""
var cat_color := Color("B8893B")
var q_index := 0
var time_left := 0.0
var time_total := 1.0
var reveal := -1            # doğru şık (açılınca)
var banner := ""            # büyük tek satır ("Kapaklar açılıyor!")
var _t := 0.0

var f_head: Font
var f_body: Font

func _ready() -> void:
	size = Vector2(W, H)
	f_head = load("res://assets/fonts/Limelight-Regular.ttf")
	var pf: FontFile = load("res://assets/fonts/PlayfairDisplay.ttf")
	var fv := FontVariation.new()
	fv.base_font = pf
	fv.variation_opentype = {"wght": 700}
	f_body = fv

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func show_marquee(text: String) -> void:
	mode = "marquee"
	marquee_text = text
	banner = ""

func show_question(p_index: int, p_prompt: String, p_options: Array, p_cat: String, p_color: Color, total: float) -> void:
	mode = "question"
	q_index = p_index
	prompt = p_prompt
	options = p_options
	cat_name = p_cat
	cat_color = p_color
	time_total = total
	time_left = total
	reveal = -1
	banner = ""

func _draw() -> void:
	# koyu, hafif kumlu projeksiyon zemini
	draw_rect(Rect2(0, 0, W, H), Color("120709"))
	var glow := Color(1.0, 0.86, 0.6, 0.06 + 0.02 * sin(_t * 1.3))
	draw_circle(Vector2(W * 0.5, H * 0.45), 620, glow)
	# ince çift çerçeve
	draw_rect(Rect2(22, 22, W - 44, H - 44), Color("C99A45"), false, 4.0)
	draw_rect(Rect2(36, 36, W - 72, H - 72), Color(0.79, 0.6, 0.27, 0.45), false, 2.0)
	if mode == "marquee":
		_draw_marquee()
	else:
		_draw_question()

func _draw_marquee() -> void:
	var title := "TRIVIA ARENA"
	var fs := 150
	var tw := f_head.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pulse := 0.85 + 0.15 * sin(_t * 2.0)
	_glow_text(f_head, Vector2((W - tw) * 0.5, 330), title, fs, Color(1.0, 0.82, 0.45) * pulse)
	# kayan şerit
	var fs2 := 44
	var line := marquee_text + "   ✦   "
	var lw := f_body.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
	var x := -fmod(_t * 140.0, lw)
	while x < W:
		draw_string(f_body, Vector2(x, 520), line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color("F3E2C0"))
		x += lw
	draw_rect(Rect2(60, 455, W - 120, 3), Color("C99A45"))
	draw_rect(Rect2(60, 545, W - 120, 3), Color("C99A45"))

func _draw_question() -> void:
	# üst şerit: kategori + soru no + süre
	draw_rect(Rect2(60, 60, 360, 64), cat_color)
	draw_string(f_body, Vector2(80, 106), cat_name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 320, 34, Color("1A0D06"))
	var qn := I18n.t("arena.round", {"n": q_index + 1})
	draw_string(f_head, Vector2(W - 460, 110), qn, HORIZONTAL_ALIGNMENT_RIGHT, 400, 44, Color("E9C27A"))
	# süre çubuğu
	var k: float = clamp(time_left / max(time_total, 0.01), 0.0, 1.0)
	var bar := Rect2(60, 140, W - 120, 16)
	draw_rect(bar, Color("2A1316"))
	var col := Color("E9B53A") if k > 0.35 else Color("E0493A")
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * k, bar.size.y)), col)
	# soru metni (sarmalı)
	var fs := 50 if prompt.length() < 90 else 42
	var para := TextParagraph.new()
	para.add_string(prompt, f_body, fs)
	para.width = W - 160
	para.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var py := 190.0
	para.draw(get_canvas_item(), Vector2(80, py), Color("FFF1D6"))
	# dört şık, 2x2
	var top := 420.0
	var cw := (W - 160) * 0.5 - 12
	for i in mini(4, options.size()):
		var cx := 80.0 + (i % 2) * (cw + 24)
		var cy := top + int(i / 2) * 118.0
		var r := Rect2(cx, cy, cw, 100)
		var zc: Color = ZONE_COLORS[i]
		var bg := Color("1E0E10")
		if reveal >= 0:
			bg = Color("214D2A") if i == reveal else Color("3A1214")
		draw_rect(r, bg)
		draw_rect(r, zc, false, 4.0)
		draw_rect(Rect2(cx, cy, 92, 100), zc)
		draw_string(f_head, Vector2(cx, cy + 74), LETTERS[i], HORIZONTAL_ALIGNMENT_CENTER, 92, 64, Color("1A0D06"))
		var ofs := 36 if String(options[i]).length() < 34 else 28
		draw_string(f_body, Vector2(cx + 112, cy + 64), String(options[i]), HORIZONTAL_ALIGNMENT_LEFT, cw - 124, ofs, Color("FFF1D6"))
	if banner != "":
		var bw := f_head.get_string_size(banner, HORIZONTAL_ALIGNMENT_LEFT, -1, 70).x
		draw_rect(Rect2((W - bw) * 0.5 - 40, 300, bw + 80, 110), Color(0.07, 0.02, 0.03, 0.92))
		_glow_text(f_head, Vector2((W - bw) * 0.5, 380), banner, 70, Color(1.0, 0.8, 0.4))

func _glow_text(f: Font, pos: Vector2, s: String, fs: int, c: Color) -> void:
	for r in [10, 6, 3]:
		draw_string_outline(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, r, Color(c.r, c.g * 0.7, c.b * 0.4, 0.12))
	draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
