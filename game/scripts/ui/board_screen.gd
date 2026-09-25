@tool
class_name BoardScreen
extends Control
## Sahnenin arkasındaki dev pano (SubViewport içinde çizilir, 3D'de bir yüzeye yansır).
##   marquee   lobide: el yazısı "Trivia" + blok "ARENA", kayan ilan şeridi
##   question  soru sırasında: kategori, dev geri sayım, (can turunda) bedel
## Okunaklı soru metni HUD'daki soru kartında; pano sahnenin gösterisidir.

const W := 1600
const H := 720
const LETTERS := ["A", "B", "C", "D"]
const ZONE_COLORS := Pal.ZONE

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
var banner := ""
var stake := 0
var _t := 0.0
var _lobby_text := false     # kayan yazı lobi metniyse dil değişince yenilenir

func _ready() -> void:
	size = Vector2(W, H)
	I18n.changed.connect(func(_l: String):
		if mode == "marquee" and _lobby_text:
			marquee_text = I18n.t("arena.lobby_board"))

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func show_marquee(text: String) -> void:
	mode = "marquee"
	marquee_text = text
	_lobby_text = text == I18n.t("arena.lobby_board")
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
	draw_rect(Rect2(0, 0, W, H), Color("100607"))
	var glow_c := cat_color if mode == "question" else Color(1.0, 0.7, 0.4)
	for i in 10:
		draw_circle(Vector2(W * 0.5, H * 0.5), 760 - i * 60, Color(glow_c, 0.012 + 0.004 * sin(_t * 1.3)))
	draw_rect(Rect2(22, 22, W - 44, H - 44), Color("C99A45"), false, 4.0)
	draw_rect(Rect2(36, 36, W - 72, H - 72), Color(0.79, 0.6, 0.27, 0.45), false, 2.0)
	if mode == "marquee":
		_draw_marquee()
	else:
		_draw_question()

func _draw_marquee() -> void:
	var f := Pal.display()
	var fs := 250
	var title := "ARENA"
	var tw := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pulse := 0.9 + 0.1 * sin(_t * 2.0)
	_glow_text(f, Vector2((W - tw) * 0.5, 400), title, fs, Color(1.0, 0.94, 0.8) * pulse)
	var sf := Pal.italic_black()
	var s := "Trivia"
	var sw := sf.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 150).x
	draw_string(sf, Vector2((W - tw) * 0.5 - 30, 222 + 6), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 150, Color(0.2, 0.02, 0.04, 0.9))
	draw_string(sf, Vector2((W - tw) * 0.5 - 30, 222), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 150, Pal.GOLD)
	# kayan şerit
	var fb := Pal.kicker()
	var fs2 := 44
	var line := Pal.upper(marquee_text) + "     —     "
	var lw := fb.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
	var x := -fmod(_t * 140.0, lw)
	while x < W:
		draw_string(fb, Vector2(x, 560), line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color("F3E2C0"))
		x += lw
	draw_rect(Rect2(60, 490, W - 120, 3), Color("C99A45"))
	draw_rect(Rect2(60, 590, W - 120, 3), Color("C99A45"))

func _draw_question() -> void:
	# kategori bandı
	var ff := Pal.italic_black()
	var cw := ff.get_string_size(cat_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 90).x
	draw_rect(Rect2((W - cw) * 0.5 - 60, 70, cw + 120, 120), cat_color)
	draw_string(ff, Vector2((W - cw) * 0.5, 162), cat_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 90, Color("1A0D06"))
	# dev geri sayım
	var f := Pal.display()
	var s: String = str(int(ceil(time_left))) if reveal < 0 else LETTERS[clampi(reveal, 0, 3)]
	var fs := 380
	var k: float = clampf(time_left / maxf(time_total, 0.01), 0.0, 1.0)
	var col := Color(1.0, 0.94, 0.8) if k > 0.35 else Color("FF6B57")
	if reveal >= 0:
		col = ZONE_COLORS[clampi(reveal, 0, 3)]
	var sw := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	_glow_text(f, Vector2((W - sw) * 0.5, 590), s, fs, col)
	# süre çubuğu
	var bar := Rect2(80, H - 90, W - 160, 22)
	draw_rect(bar, Color("2A1316"))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * k, bar.size.y)), Color("E9B53A") if k > 0.35 else Color("E0493A"))
	# dört şık rengi (yerdeki kapaklarla eşleşir)
	for i in 4:
		var r := Rect2(80 + i * ((W - 160) / 4.0), H - 60, (W - 160) / 4.0 - 10, 12)
		draw_rect(r, Color(ZONE_COLORS[i], 1.0 if reveal < 0 or reveal == i else 0.25))

func _glow_text(f: Font, pos: Vector2, s: String, fs: int, c: Color) -> void:
	for r in [16, 9, 4]:
		draw_string_outline(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, r, Color(c.r, c.g * 0.7, c.b * 0.4, 0.1))
	draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
