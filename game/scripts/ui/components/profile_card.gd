class_name ProfileCard
extends Control
## Sağ üstteki kulis kartı: canlı pelüş portresi, sahne adı, karne.
## Kenarları bilet gibi oyuk; üstüne gelince hafifçe eğilir, ışık fareyi izler.
## Kapalıyken küçük bir rozettir (portre + isim); tıklayınca açılır, tekrar
## tıklayınca kapanır. İsme tıklamak adı değiştirir.

signal lang_toggled
signal rename_requested

var player_name := "OYUNCU"
var stats := {"wl": "0 / 0", "champs": 0, "streak": 0, "best": 0}
var accent := Color("F2C230")

var portrait: PlushPortrait
var _lang: Segmented
var _nums := {}
var _h := 0.0
var _hover := false
var _name_hover := false
var _mouse := Vector2.ZERO
var _t := 0.0
var expanded := false
var _k := 0.0                     # 0 = rozet, 1 = tam kart

const W := 520.0
const CW := 262.0                 # rozet genişliği
const CH := 78.0                  # rozet yüksekliği
const H := 236.0
const PORTRAIT_W := 172.0
const STUB := 62.0

func _ready() -> void:
	size = Vector2(W, H)
	custom_minimum_size = size
	pivot_offset = size * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	portrait = PlushPortrait.new()
	portrait.position = Vector2(12, 12)
	portrait.size = Vector2(PORTRAIT_W - 12, H - 24)
	add_child(portrait)
	var keys := [["champs", 300.0], ["streak", 354.0], ["best", 408.0]]
	for k in keys:
		var n := RollingNumber.new()
		n.font_size = 38
		n.align = 0
		n.color = Pal.CHAMPAGNE
		n.position = Vector2(k[1] - 2, 156)
		n.size = Vector2(52, 44)
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(n)
		_nums[k[0]] = n
	_lang = Segmented.new()
	_lang.options = ["TR", "EN"]
	_lang.font_size = 18
	_lang.custom_minimum_size = Vector2(100, 34)
	_lang.size = Vector2(100, 34)
	_lang.position = Vector2(W - STUB - 100 - 16, 16)
	_lang.focus_mode = Control.FOCUS_NONE
	_lang.changed.connect(func(_i): lang_toggled.emit())
	add_child(_lang)
	_apply_k()
	mouse_entered.connect(func(): _hover = true)
	mouse_exited.connect(func():
		_hover = false
		_name_hover = false)

func refresh(p_name: String, p_stats: Dictionary, look: Dictionary, lang: String, col: Color) -> void:
	var changed_look := portrait.look.hash() != look.hash()
	player_name = p_name
	stats = p_stats
	accent = col
	if changed_look:
		portrait.set_look(look)
		portrait.hop()
	for k in _nums:
		_nums[k].value = int(stats.get(k, 0))
	_lang.selected = 1 if lang == "en" else 0
	queue_redraw()

func toggle(open := not expanded) -> void:
	expanded = open
	Pal.sfx("whoosh" if open else "click", -10.0, 1.3 if open else 1.0)
	var tw := create_tween()
	tw.tween_method(_set_k, _k, 1.0 if open else 0.0, 0.42).set_trans(Tween.TRANS_BACK if open else Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if open:
		portrait.hop()

func _set_k(v: float) -> void:
	_k = v
	_apply_k()

## Rozetten karta geçiş: portre küçülür/büyür, sayılar ve dil anahtarı belirir.
func _apply_k() -> void:
	var e := clampf(_k, 0.0, 1.2)
	var small := Rect2(W - CW + 8, 7, 64, 64)
	var big := Rect2(12, 12, PORTRAIT_W - 12, H - 24)
	portrait.position = small.position.lerp(big.position, e)
	portrait.size = small.size.lerp(big.size, clampf(e, 0.0, 1.0))
	var a := clampf((_k - 0.7) / 0.3, 0.0, 1.0)
	for n in _nums.values():
		n.modulate.a = a
		n.visible = a > 0.01
	_lang.modulate.a = a
	_lang.visible = a > 0.01
	queue_redraw()

func _cur_rect() -> Rect2:
	var e := clampf(_k, 0.0, 1.0)
	var small := Rect2(W - CW, 0, CW, CH)
	return Rect2(small.position.lerp(Vector2.ZERO, e), small.size.lerp(Vector2(W, H), e))

func _has_point(p: Vector2) -> bool:
	return _cur_rect().has_point(p)

func _name_rect() -> Rect2:
	return Rect2(PORTRAIT_W + 16, 40, W - STUB - PORTRAIT_W - 40, 70)

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		_mouse = e.position
		var over := _name_rect().has_point(e.position)
		if over != _name_hover:
			_name_hover = over
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if over else Control.CURSOR_ARROW
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if expanded and _k > 0.95 and _name_rect().has_point(e.position):
			Pal.sfx("click", -4.0, 1.2)
			rename_requested.emit()
		else:
			toggle()

func _process(delta: float) -> void:
	_t += delta
	_h = Fx.damp(_h, 1.0 if _hover else 0.0, 8.0, delta)
	var tilt := 0.0
	if _hover and expanded:
		tilt = (_mouse.x / W - 0.5) * 0.025
	rotation = Fx.damp(rotation, tilt, 8.0, delta)
	pivot_offset = Vector2(W, 0)
	scale = Vector2.ONE * (1.0 + 0.015 * _h)
	queue_redraw()

func _shape() -> PackedVector2Array:
	# bilet: köşeler kesik, koçan hizasında iki yarım daire oyuk
	var pts := PackedVector2Array()
	var sx := W - STUB
	var r := 13.0
	var cut := 12.0
	pts.append(Vector2(cut, 0))
	pts.append(Vector2(sx - r, 0))
	for i in range(0, 13):
		var a := PI - PI * i / 12.0
		pts.append(Vector2(sx + cos(a) * r, sin(a) * r))
	pts.append(Vector2(W - cut, 0))
	pts.append(Vector2(W, cut))
	pts.append(Vector2(W, H - cut))
	pts.append(Vector2(W - cut, H))
	for i in range(0, 13):
		var a := -PI * i / 12.0
		pts.append(Vector2(sx + cos(a) * r, H + sin(a) * r))
	pts.append(Vector2(cut, H))
	pts.append(Vector2(0, H - cut))
	pts.append(Vector2(0, cut))
	return pts

func _draw() -> void:
	if _k < 0.97:
		_draw_compact()
		return
	var pts := _shape()
	draw_colored_polygon(_offset(pts, Vector2(0, 10)), Color(0, 0, 0, 0.45))
	# gövde: koyu kadife gradyan
	var cols := PackedColorArray()
	for p in pts:
		var k := p.y / H
		cols.append(Color("22090F").lerp(Color("0E0507"), k))
	draw_polygon(pts, cols)
	# fareyi izleyen yumuşak ışık
	var lp := _mouse if _hover else Vector2(W * 0.3, 20)
	for i in 6:
		draw_circle(lp, 180.0 - i * 28.0, Color(1, 0.8, 0.55, 0.012 + 0.012 * _h))
	# portre arkası: spot halkası
	var pc := Vector2(12 + (PORTRAIT_W - 12) * 0.5, H * 0.52)
	for i in 8:
		draw_circle(pc, 92.0 - i * 9.0, Color(accent, 0.02 + i * 0.006))
	draw_line(Vector2(PORTRAIT_W + 4, 18), Vector2(PORTRAIT_W + 4, H - 18), Color(Pal.BRASS, 0.35), 1.0)
	Icons.outline(self, pts, Color(Pal.BRASS, 0.75), 1.5)
	# koçan: delikli çizgi + dikey yazı
	var sx := W - STUB
	var y := 20.0
	while y < H - 20.0:
		draw_circle(Vector2(sx, y), 1.6, Color(Pal.BRASS, 0.6))
		y += 9.0
	var f := Pal.kicker()
	var admit := Pal.upper(Pal.t("ticket.admit"))
	draw_set_transform(Vector2(sx + STUB * 0.5 + 7, H * 0.5), -PI / 2, Vector2.ONE)
	var aw := f.get_string_size(admit, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + admit.length() * 3.0
	var x := -aw * 0.5
	for i in admit.length():
		draw_string(f, Vector2(x, 0), admit.substr(i, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(Pal.GOLD, 0.85))
		x += f.get_char_size(admit.unicode_at(i), 17).x + 3.0
	draw_set_transform(Vector2.ZERO)
	# koçan numarası (sahte seri no)
	var serial := "Nº %04d" % (abs(player_name.hash()) % 10000)
	draw_set_transform(Vector2(sx + 16, H - 16), -PI / 2, Vector2.ONE)
	draw_string(Pal.italic(), Vector2(0, 0), serial, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(Pal.CREAM, 0.45))
	draw_set_transform(Vector2.ZERO)
	# isim
	var x0 := PORTRAIT_W + 22.0
	draw_string(f, Vector2(x0, 38), Pal.upper(Pal.t("wardrobe.name")), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(Pal.GOLD, 0.8))
	var nf := Pal.display()
	var nm := Pal.upper(player_name)
	var fs := 58
	var maxw := W - STUB - x0 - 20
	while fs > 30 and nf.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > maxw:
		fs -= 2
	draw_string(nf, Vector2(x0, 100 + 4), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.5))
	draw_string(nf, Vector2(x0, 100), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.CHAMPAGNE)
	var nw := nf.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var ul := 0.35 + (0.65 if _name_hover else 0.0)
	draw_line(Vector2(x0, 110), Vector2(x0 + nw, 110), Color(accent, ul), 2.0)
	if _name_hover:
		draw_string(Pal.italic(), Vector2(x0, 128), Pal.t("ticket.rename"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(Pal.CREAM, 0.7))
	# karne
	var labels := [["ticket.wl", x0], ["ticket.champs", 300.0], ["ticket.streak", 354.0], ["ticket.best", 408.0]]
	for l in labels:
		var s: String = Pal.upper(_short(l[0]))
		draw_string(f, Vector2(l[1], 158), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(Pal.CREAM, 0.6))
	draw_string(Pal.display(), Vector2(x0, 192), String(stats.get("wl", "0 / 0")), HORIZONTAL_ALIGNMENT_LEFT, 96, 38, Pal.CHAMPAGNE)
	if int(stats.get("streak", 0)) >= 2:
		Icons.draw(self, "flame", Vector2(392, 150), 13, Color("FF8A3C"))
	if int(stats.get("champs", 0)) > 0:
		Icons.draw(self, "crown", Vector2(340, 152), 13, Pal.GOLD)

## Rozet ve geçiş hali: köşeleri kesik küçük bilet; portre, isim, kısa karne.
func _draw_compact() -> void:
	var r := _cur_rect()
	var pts := Icons.notched(r, 10.0)
	draw_colored_polygon(Icons.notched(Rect2(r.position + Vector2(0, 8), r.size), 10.0), Color(0, 0, 0, 0.4))
	draw_colored_polygon(pts, Color("1A070C").lerp(Color("22090F"), _h * 0.5))
	Icons.outline(self, pts, Color(Pal.BRASS, 0.6 + 0.3 * _h), 1.5)
	var pc := portrait.position + portrait.size * 0.5
	for i in 5:
		draw_circle(pc, portrait.size.x * 0.5 - i * 5.0, Color(accent, 0.05 + i * 0.02))
	var a := clampf(1.0 - _k * 2.5, 0.0, 1.0)
	if a <= 0.0:
		return
	var x0 := W - CW + 82
	var nf := Pal.display()
	var nm := Pal.upper(player_name)
	var fs := 34
	while fs > 20 and nf.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > CW - 120:
		fs -= 2
	draw_string(nf, Vector2(x0, 40), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Pal.CHAMPAGNE, a))
	var sub := "%s  ·  %s  ·  %s %d" % [Pal.upper(Pal.t("rank.level", {"n": Progress.level()})), Pal.upper(Pal.t("coins.n", {"n": Progress.coins()})), Pal.upper(Pal.t("ticket.streak_s")), int(stats.get("streak", 0))]
	draw_string(Pal.kicker(), Vector2(x0, 62), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(Pal.CREAM, 0.7 * a))
	# aç/kapa oku
	Icons.draw(self, "arrow_r", Vector2(W - 24, CH * 0.5 + sin(_t * 3.0) * 2.0 * _h), 18, Color(Pal.GOLD, a * (0.6 + 0.4 * _h)), 2.5)

func _short(key: String) -> String:
	match key:
		"ticket.champs": return Pal.t("ticket.champs_s")
		"ticket.streak": return Pal.t("ticket.streak_s")
		"ticket.best": return Pal.t("ticket.best_s")
	return Pal.t(key)

func _offset(pts: PackedVector2Array, o: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + o)
	return out
