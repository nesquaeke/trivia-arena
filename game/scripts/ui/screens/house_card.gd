class_name HouseCard
extends GlassPanel
## Ev partisi kartı: QR, 4 harfli oda kodu, bağlı telefonlar, sunucu adresi.

signal connect_requested(url: String)
signal close_requested

var qr: TextureRect
var code := "····"
var url_text := ""
var phones: Array = []          # [{name, color}]
var status := ""
var edit: LineEdit
var _kick: KickerLabel
var _title: KineticText
var _body: Control
var _go: CtaButton
var _close: CtaButton
var _t := 0.0

func _ready() -> void:
	size = Vector2(700, 550)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	_kick = KickerLabel.new()
	v.add_child(_kick)
	_title = KineticText.new()
	_title.font = Pal.display()
	_title.font_size = 64
	_title.custom_minimum_size = Vector2(620, 70)
	v.add_child(_title)
	_body = Control.new()
	_body.custom_minimum_size = Vector2(640, 300)
	_body.draw.connect(_draw_body)
	v.add_child(_body)
	qr = TextureRect.new()
	qr.position = Vector2(14, 14)
	qr.size = Vector2(232, 232)
	qr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	qr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	qr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_body.add_child(qr)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	edit = LineEdit.new()
	edit.custom_minimum_size = Vector2(330, 56)
	edit.add_theme_font_size_override("font_size", 20)
	edit.placeholder_text = "wss://…/ws"
	row.add_child(edit)
	_go = CtaButton.new()
	_go.custom_minimum_size = Vector2(140, 56)
	_go.font_size = 26
	_go.pressed.connect(func(): connect_requested.emit(edit.text))
	row.add_child(_go)
	_close = CtaButton.new()
	_close.style = "ghost"
	_close.custom_minimum_size = Vector2(140, 56)
	_close.font_size = 26
	_close.pressed.connect(func(): close_requested.emit())
	row.add_child(_close)

func retext() -> void:
	_kick.text = Pal.t("house.kicker")
	_title.text = Pal.upper(Pal.t("house.title"))
	_go.label = Pal.t("house.connect")
	_close.label = Pal.t("house.close")
	_body.queue_redraw()

func open() -> void:
	retext()
	_title.play(0.2)

func _process(delta: float) -> void:
	_t += delta
	if is_visible_in_tree():
		_body.queue_redraw()

func _draw_body() -> void:
	# QR çerçevesi: pirinç köşeler, taranıyormuş gibi bir ışık çizgisi
	var fr := Rect2(0, 0, 260, 260)
	_body.draw_rect(fr, Color("F4E8CF"))
	for c in [Vector2(0, 0), Vector2(260, 0), Vector2(0, 260), Vector2(260, 260)]:
		var sx := 1.0 if c.x == 0 else -1.0
		var sy := 1.0 if c.y == 0 else -1.0
		_body.draw_line(c, c + Vector2(40 * sx, 0), Pal.GOLD, 5.0)
		_body.draw_line(c, c + Vector2(0, 40 * sy), Pal.GOLD, 5.0)
	if qr.texture:
		var sy2 := 14.0 + fmod(_t * 90.0, 232.0)
		_body.draw_rect(Rect2(14, sy2, 232, 2), Color(Pal.VELVET_HI, 0.5))
	else:
		var sf := Pal.italic()
		_body.draw_string(sf, Vector2(30, 136), Pal.t("house.connecting"), HORIZONTAL_ALIGNMENT_LEFT, 200, 18, Color(Pal.INK, 0.6))
	# oda kodu: dört harf kutusu
	var x0 := 290.0
	var kf := Pal.kicker()
	_body.draw_string(kf, Vector2(x0, 14), Pal.upper(Pal.t("house.code")), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(Pal.GOLD, 0.85))
	var f := Pal.display()
	for i in 4:
		var r := Rect2(x0 + i * 82, 26, 72, 92)
		_body.draw_colored_polygon(Icons.notched(r, 8.0), Color(Pal.INK, 0.8))
		Icons.outline(_body, Icons.notched(r, 8.0), Color(Pal.GOLD, 0.7), 1.5)
		var ch := code.substr(i, 1) if i < code.length() else "·"
		var w := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 76).x
		var bob := sin(_t * 3.0 + i * 0.8) * 2.0
		_body.draw_string(f, Vector2(r.position.x + (72 - w) * 0.5, 100 + bob), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 76, Pal.CHAMPAGNE)
	var sf := Pal.italic()
	var para := TextParagraph.new()
	para.width = 330
	para.add_string(Pal.t("house.scan"), sf, 17)
	para.draw(_body.get_canvas_item(), Vector2(x0, 132), Color(Pal.CREAM, 0.8))
	_body.draw_string(Pal.display_bold(), Vector2(x0, 200), url_text, HORIZONTAL_ALIGNMENT_LEFT, 340, 24, Pal.GOLD)
	# bağlı telefonlar
	var px := x0
	var py := 236.0
	if phones.is_empty():
		_body.draw_string(sf, Vector2(px, py + 8), Pal.t("house.none"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(Pal.CREAM, 0.55))
	for ph in phones:
		var col: Color = ph.color
		var nm := Pal.upper(String(ph.name))
		var nw := Pal.display_bold().get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		var r := Rect2(px, py - 12, nw + 40, 30)
		_body.draw_colored_polygon(Icons.notched(r, 6.0), Color(col, 0.25))
		Icons.draw(_body, "phone", Vector2(px + 14, py + 3), 20, col.lightened(0.3), 2.0)
		_body.draw_string(Pal.display_bold(), Vector2(px + 28, py + 10), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Pal.CHAMPAGNE)
		px += r.size.x + 8
	if status != "":
		_body.draw_string(sf, Vector2(290, 292), status, HORIZONTAL_ALIGNMENT_LEFT, 350, 16, Color(1, 0.7, 0.55))
