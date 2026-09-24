class_name UIKit
extends RefCounted
## Diegetik arayüz parçaları: pirinç plaketler, yarı saydam ahşap pano,
## ampullü tabela, tiyatro bileti, eski afiş. Hepsi kodla çizilir; jenerik
## yuvarlak neon düğme yok. Renkler pirinç, koyu ahşap, kadife ve kağıt.

const INK := Color("1C0E08")
const WOOD := Color("1E0F09")
const CREAM := Color("F3E4C4")
const PAPER := Color("EADBB7")
const BRASS_HI := Color("F4D994")
const BRASS := Color("C39646")
const BRASS_LO := Color("6B4718")
const RED := Color("7A0E1C")
const GOLD := Color("F2C66A")
const ENGRAVE := Color("2A1706")

static var _fonts := {}

static func display() -> Font:
	if not _fonts.has("display"):
		_fonts.display = load("res://assets/fonts/Limelight-Regular.ttf")
	return _fonts.display

static func serif(weight := 500, italic := false) -> Font:
	var k := "serif%d%s" % [weight, "i" if italic else ""]
	if not _fonts.has(k):
		var fv := FontVariation.new()
		fv.base_font = load("res://assets/fonts/PlayfairDisplay.ttf")
		fv.variation_opentype = {"wght": weight}
		if italic:
			fv.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.2, 1), Vector2.ZERO)
		_fonts[k] = fv
	return _fonts[k]

## Pirinç levha: dikey gradyan, eğimli kenar, köşelerde vida.
static func draw_brass(ci: CanvasItem, r: Rect2, lit := 0.0, pressed := false, screws := true) -> void:
	var hi := BRASS_HI.lerp(Color(1, 0.95, 0.8), lit * 0.5)
	var mid := BRASS.lerp(Color("E0B45C"), lit * 0.6)
	var lo := BRASS_LO.lerp(BRASS, lit * 0.3)
	if pressed:
		var t := hi
		hi = lo
		lo = t
	var p := r.position
	var s := r.size
	var c := 7.0   # pah (köşe kesiği), yuvarlak değil
	var pts := PackedVector2Array([p + Vector2(c, 0), p + Vector2(s.x - c, 0), p + Vector2(s.x, c), p + Vector2(s.x, s.y - c),
		p + Vector2(s.x - c, s.y), p + Vector2(c, s.y), p + Vector2(0, s.y - c), p + Vector2(0, c)])
	var cols := PackedColorArray([hi, hi, mid, lo, lo, lo, mid, hi])
	ci.draw_polygon(pts, cols)
	var loop := pts.duplicate()
	loop.append(pts[0])
	ci.draw_polyline(loop, Color(0.22, 0.13, 0.04), 2.0, true)
	# iç bevel çizgisi
	var ir := r.grow(-5)
	ci.draw_rect(ir, Color(1, 0.93, 0.7, 0.35 + lit * 0.3), false, 1.0)
	if screws:
		for q in [Vector2(12, 12), Vector2(s.x - 12, 12), Vector2(12, s.y - 12), Vector2(s.x - 12, s.y - 12)]:
			draw_screw(ci, p + q, 4.0)

static func draw_screw(ci: CanvasItem, c: Vector2, rad: float) -> void:
	ci.draw_circle(c, rad + 1.0, Color(0.2, 0.12, 0.04))
	ci.draw_circle(c, rad, Color("D7B066"))
	ci.draw_line(c + Vector2(-rad * 0.7, -rad * 0.3), c + Vector2(rad * 0.7, rad * 0.3), Color(0.25, 0.15, 0.05), 1.2)

## Kazınmış yazı: koyu harf + altında ince ışık çizgisi.
static func draw_engraved(ci: CanvasItem, f: Font, pos: Vector2, text: String, size: int, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT, col := ENGRAVE) -> void:
	ci.draw_string(f, pos + Vector2(0, 1.5), text, align, width, size, Color(1, 0.95, 0.78, 0.55))
	ci.draw_string(f, pos, text, align, width, size, col)

static func draw_glow_text(ci: CanvasItem, f: Font, pos: Vector2, text: String, size: int, col: Color, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	for rr in [12, 7, 3]:
		ci.draw_string_outline(f, pos, text, align, width, size, rr, Color(col.r, col.g * 0.7, col.b * 0.3, 0.1))
	ci.draw_string(f, pos, text, align, width, size, col)

## Koyu ahşap, yarı saydam; pirinç çerçeve ve köşe bağlantıları.
static func draw_wood_frame(ci: CanvasItem, r: Rect2, alpha := 0.78) -> void:
	ci.draw_rect(r, Color(WOOD, alpha))
	# ahşap damarları
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 26:
		var x := r.position.x + rng.randf() * r.size.x
		ci.draw_line(Vector2(x, r.position.y), Vector2(x + rng.randf_range(-8, 8), r.end.y), Color(0.45, 0.25, 0.12, 0.05), rng.randf_range(1, 3))
	# pirinç çerçeve (çift çizgi)
	ci.draw_rect(r, BRASS_LO, false, 6.0)
	ci.draw_rect(r.grow(-3), BRASS, false, 2.0)
	ci.draw_rect(r.grow(-10), Color(BRASS, 0.35), false, 1.0)
	# köşe gönyeleri
	for corner in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
		var sx := 1.0 if corner.x == r.position.x else -1.0
		var sy := 1.0 if corner.y == r.position.y else -1.0
		var pts := PackedVector2Array([corner, corner + Vector2(34 * sx, 0), corner + Vector2(34 * sx, 8 * sy),
			corner + Vector2(8 * sx, 8 * sy), corner + Vector2(8 * sx, 34 * sy), corner + Vector2(0, 34 * sy)])
		ci.draw_colored_polygon(pts, BRASS)
		draw_screw(ci, corner + Vector2(14 * sx, 14 * sy), 3.5)

# ════════════════════════════════════════════════════════════════════
## Yarı saydam ahşap pano. İçerik için içine bir MarginContainer koyun.
class WoodPanel extends Control:
	var alpha := 0.78
	func _draw() -> void:
		UIKit.draw_wood_frame(self, Rect2(Vector2.ZERO, size), alpha)

## Pirinç plaket düğme: başlık + alt yazı + isteğe bağlı kırmızı mühür.
class Plaque extends Button:
	var title := ""
	var subtitle := ""
	var stamp := ""
	var glyph := ""
	var big := false
	var _lit := 0.0
	var _hover := false
	func _init(p_title := "", p_sub := "", p_big := false) -> void:
		title = p_title
		subtitle = p_sub
		big = p_big
		flat = true
		focus_mode = Control.FOCUS_NONE
		text = ""
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		custom_minimum_size = Vector2(0, 96 if big else (74 if p_sub != "" else 56))
		mouse_entered.connect(func():
			_hover = true
			if not disabled:
				Sfx.play("tick", -14.0, 1.3))
		mouse_exited.connect(func(): _hover = false)
		pressed.connect(func(): Sfx.play("click", -4.0))
	func _process(delta: float) -> void:
		var want := 1.0 if (_hover and not disabled) else 0.0
		if abs(_lit - want) > 0.01:
			_lit = lerp(_lit, want, 1.0 - exp(-14.0 * delta))
			queue_redraw()
	func _draw() -> void:
		var off := Vector2(-3 * _lit, -2 * _lit)
		var r := Rect2(off, size)
		# gölge
		draw_rect(Rect2(Vector2(4, 5), size), Color(0, 0, 0, 0.45))
		UIKit.draw_brass(self, r, _lit, button_pressed and _hover, true)
		var x := 28.0
		if glyph != "":
			draw_circle(off + Vector2(44, size.y * 0.5), 22, Color(0.22, 0.12, 0.04, 0.85))
			draw_string(UIKit.display(), off + Vector2(24, size.y * 0.5 + 12), glyph, HORIZONTAL_ALIGNMENT_CENTER, 40, 30, UIKit.GOLD)
			x = 80.0
		var tf := UIKit.serif(800)
		var ts := 34 if big else (27 if subtitle != "" else 24)
		if stamp != "":
			ts = 25
		var ty := size.y * 0.5 + (ts * 0.35 if subtitle == "" else -2.0)
		UIKit.draw_engraved(self, tf, off + Vector2(x, ty), title, ts, size.x - x - 20)
		if subtitle != "":
			draw_string(UIKit.serif(500, true), off + Vector2(x, ty + 26), subtitle, HORIZONTAL_ALIGNMENT_LEFT, size.x - x - 20, 17, Color(0.2, 0.11, 0.03, 0.85))
		if stamp != "":
			# köşe kuşağı: sağ üst köşeden çapraz geçen kırmızı şerit
			draw_set_transform(off + Vector2(size.x - 30, 30), PI / 4, Vector2.ONE)
			var sw := 150.0
			draw_rect(Rect2(-sw * 0.5, -13, sw, 26), Color(0.55, 0.06, 0.09, 0.95))
			draw_rect(Rect2(-sw * 0.5, -10, sw, 20), Color(0.95, 0.75, 0.4, 0.6), false, 1.0)
			draw_string(UIKit.display(), Vector2(-sw * 0.5, 7), stamp, HORIZONTAL_ALIGNMENT_CENTER, sw, 15, UIKit.GOLD)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if disabled:
			draw_rect(r, Color(0.1, 0.05, 0.02, 0.35))

## Küçük pirinç anahtar (seçim / sayaç düğmeleri için)
class Knob extends Button:
	var label := ""
	var on := false
	var _hover := false
	func _init(p_label := "") -> void:
		label = p_label
		flat = true
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		custom_minimum_size = Vector2(56, 44)
		mouse_entered.connect(func():
			_hover = true
			queue_redraw())
		mouse_exited.connect(func():
			_hover = false
			queue_redraw())
		pressed.connect(func(): Sfx.play("click", -6.0, 1.2))
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if on:
			draw_rect(r, UIKit.RED)
			draw_rect(r, UIKit.GOLD, false, 2.0)
			draw_string(UIKit.serif(800), Vector2(0, size.y * 0.5 + 8), label, HORIZONTAL_ALIGNMENT_CENTER, size.x, 21, UIKit.GOLD)
		else:
			UIKit.draw_brass(self, r, 0.6 if _hover else 0.0, false, false)
			UIKit.draw_engraved(self, UIKit.serif(800), Vector2(0, size.y * 0.5 + 8), label, 21, size.x, HORIZONTAL_ALIGNMENT_CENTER)

## Ampullü tabela: koyu kırmızı zemin, çevrede kovalayan ampuller, parlayan başlık.
class Marquee extends Control:
	var top := "TRIVIA"
	var bottom := "ARENA"
	var tagline := ""
	var _t := 0.0
	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		# asma zincirleri
		for x in [size.x * 0.2, size.x * 0.8]:
			draw_line(Vector2(x, -40), Vector2(x, 8), UIKit.BRASS_LO, 3.0)
		draw_rect(Rect2(Vector2(5, 7), size), Color(0, 0, 0, 0.5))
		draw_rect(r, Color("3A0710"))
		draw_rect(r.grow(-14), Color("520B16"))
		draw_rect(r, UIKit.BRASS, false, 5.0)
		draw_rect(r.grow(-14), UIKit.BRASS_LO, false, 2.0)
		# kovalayan ampuller
		var per := 2.0 * (size.x + size.y)
		var n := int(per / 30.0)
		for i in n:
			var d := (float(i) + 0.5) / n * per
			var pt := _along(d)
			var phase := int(_t * 6.0) % 3
			var on := (i % 3) == phase
			var c := Color(1.0, 0.86, 0.5) if on else Color(0.55, 0.36, 0.16)
			if on:
				draw_circle(pt, 9.0, Color(1.0, 0.75, 0.3, 0.18))
			draw_circle(pt, 4.6, c)
		# başlık
		var f := UIKit.display()
		var flick := 0.92 + 0.08 * sin(_t * 9.0) * sin(_t * 2.3)
		UIKit.draw_glow_text(self, f, Vector2(0, size.y * 0.45), top, 58, Color(1.0, 0.84, 0.48) * flick, size.x, HORIZONTAL_ALIGNMENT_CENTER)
		UIKit.draw_glow_text(self, f, Vector2(0, size.y * 0.45 + 60), bottom, 64, Color(1.0, 0.5, 0.36) * flick, size.x, HORIZONTAL_ALIGNMENT_CENTER)
		if tagline != "":
			draw_string(UIKit.serif(600, true), Vector2(0, size.y - 26), "— " + tagline + " —", HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, UIKit.CREAM)
	func _along(d: float) -> Vector2:
		var w := size.x - 14.0
		var h := size.y - 14.0
		var o := Vector2(7, 7)
		if d < w:
			return o + Vector2(d, 0)
		d -= w
		if d < h:
			return o + Vector2(w, d)
		d -= h
		if d < w:
			return o + Vector2(w - d, h)
		d -= w
		return o + Vector2(0, h - minf(d, h))

## Tiyatro bileti: profil, TR/EN şalteri ve sahne karnesi.
class Ticket extends Control:
	signal rename_requested
	signal lang_toggled
	var player_name := ""
	var avatar_color := Color("F2C230")
	var wl := "0 / 0"
	var champs := 0
	var streak := 0
	var best := 0
	var lang := "tr"
	var _name_rect := Rect2()
	var _lang_rect := Rect2()
	var _lever := 0.0
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		custom_minimum_size = Vector2(430, 238)
	func _process(delta: float) -> void:
		var want := 1.0 if lang == "en" else 0.0
		if abs(_lever - want) > 0.005:
			_lever = lerp(_lever, want, 1.0 - exp(-16.0 * delta))
			queue_redraw()
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			if _lang_rect.has_point(e.position):
				lang_toggled.emit()
				Sfx.play("click", -3.0, 0.8)
			elif _name_rect.has_point(e.position):
				rename_requested.emit()
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var stub := 92.0
		draw_rect(Rect2(Vector2(5, 6), size), Color(0, 0, 0, 0.5))
		# kağıt gövde (kenarlarda zımba delikleri)
		draw_rect(Rect2(0, 0, w, h), UIKit.PAPER)
		draw_rect(Rect2(6, 6, w - 12, h - 12), Color("B8893B"), false, 2.0)
		draw_rect(Rect2(11, 11, w - 22, h - 22), Color(0.72, 0.54, 0.23, 0.5), false, 1.0)
		for i in 9:
			var y := 16.0 + i * (h - 32.0) / 8.0
			draw_circle(Vector2(w - stub, y), 4.0, Color(0.14, 0.07, 0.04))
		for side_x in [0.0, w]:
			draw_circle(Vector2(side_x, h * 0.5), 14.0, Color(0.05, 0.02, 0.02))
		# koçan (sağ)
		var sx := w - stub
		draw_set_transform(Vector2(sx + stub * 0.5, h * 0.5), -PI / 2, Vector2.ONE)
		draw_string(UIKit.display(), Vector2(-h * 0.5, 8), I18n.t("ticket.admit"), HORIZONTAL_ALIGNMENT_CENTER, h, 22, UIKit.RED)
		draw_string(UIKit.serif(700), Vector2(-h * 0.5, 34), "Nº %04d" % (abs(player_name.hash()) % 10000), HORIZONTAL_ALIGNMENT_CENTER, h, 16, Color(0.2, 0.1, 0.05))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# avatar madalyonu
		var ac := Vector2(52, 58)
		draw_circle(ac, 30, UIKit.BRASS_LO)
		draw_circle(ac, 26, avatar_color)
		draw_circle(ac + Vector2(-8, -3), 3.5, Color(0.08, 0.05, 0.04))
		draw_circle(ac + Vector2(8, -3), 3.5, Color(0.08, 0.05, 0.04))
		draw_arc(ac + Vector2(0, 4), 9, 0.3, PI - 0.3, 10, Color(0.08, 0.05, 0.04), 2.0)
		# isim plaketi (tıklanınca yeniden adlandır)
		_name_rect = Rect2(94, 32, sx - 110, 50)
		UIKit.draw_brass(self, _name_rect, 0.0, false, false)
		var nm := player_name if player_name != "" else "—"
		UIKit.draw_engraved(self, UIKit.serif(800), _name_rect.position + Vector2(14, 34), nm, 26, _name_rect.size.x - 24)
		# TR / EN şalteri
		_lang_rect = Rect2(sx - 120, 94, 104, 36)
		var lr := _lang_rect
		draw_rect(lr, Color(0.16, 0.08, 0.04))
		draw_rect(lr, UIKit.BRASS, false, 2.0)
		var knob_x := lerpf(lr.position.x + 4.0, lr.position.x + lr.size.x * 0.5, _lever)
		UIKit.draw_brass(self, Rect2(knob_x, lr.position.y + 4, lr.size.x * 0.5 - 4, lr.size.y - 8), 0.3, false, false)
		draw_string(UIKit.serif(800), lr.position + Vector2(0, 25), "TR", HORIZONTAL_ALIGNMENT_CENTER, lr.size.x * 0.5, 17, UIKit.ENGRAVE if lang == "tr" else Color(0.8, 0.65, 0.4))
		draw_string(UIKit.serif(800), lr.position + Vector2(lr.size.x * 0.5, 25), "EN", HORIZONTAL_ALIGNMENT_CENTER, lr.size.x * 0.5, 17, UIKit.ENGRAVE if lang == "en" else Color(0.8, 0.65, 0.4))
		# karne
		draw_string(UIKit.display(), Vector2(22, 118), I18n.t("ticket.record"), HORIZONTAL_ALIGNMENT_LEFT, sx - 150, 19, UIKit.RED)
		draw_line(Vector2(22, 128), Vector2(sx - 16, 128), Color(0.45, 0.3, 0.12, 0.6), 1.0)
		var rows := [[I18n.t("ticket.wl"), wl], [I18n.t("ticket.champs"), str(champs)], [I18n.t("ticket.streak"), str(streak) + ("  ★" if streak >= 3 else "")]]
		for i in rows.size():
			var y := 156.0 + i * 26.0
			draw_string(UIKit.serif(600), Vector2(22, y), String(rows[i][0]), HORIZONTAL_ALIGNMENT_LEFT, sx - 140, 18, Color(0.18, 0.09, 0.04))
			draw_string(UIKit.serif(900), Vector2(sx - 130, y), String(rows[i][1]), HORIZONTAL_ALIGNMENT_RIGHT, 110, 20, Color(0.18, 0.09, 0.04))
			draw_line(Vector2(22, y + 7), Vector2(sx - 16, y + 7), Color(0.45, 0.3, 0.12, 0.25), 1.0)

## Eski tiyatro afişi (nasıl oynanır). İpten sarkar, hafifçe sallanır.
class Poster extends Control:
	signal closed
	var head := ""
	var title := ""
	var lines: Array = []
	var foot := ""
	var _swing := 0.0
	var _t := 0.0
	var _close_rect := Rect2()
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _process(delta: float) -> void:
		_t += delta
		_swing = sin(_t * 1.6) * 0.012 * exp(-_t * 0.35)
		queue_redraw()
	func drop() -> void:
		_t = 0.0
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and _close_rect.has_point(e.position):
			Sfx.play("whoosh", -8.0, 1.3)
			closed.emit()
	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_set_transform(Vector2(w * 0.5, 0), _swing, Vector2.ONE)
		var o := Vector2(-w * 0.5, 0)
		# ipler
		draw_line(o + Vector2(w * 0.2, -400), o + Vector2(w * 0.2, 14), Color(0.55, 0.42, 0.25), 3.0)
		draw_line(o + Vector2(w * 0.8, -400), o + Vector2(w * 0.8, 14), Color(0.55, 0.42, 0.25), 3.0)
		draw_rect(Rect2(o + Vector2(8, 10), size), Color(0, 0, 0, 0.5))
		# yıllanmış kağıt
		draw_rect(Rect2(o, size), Color("E6D2A6"))
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		for i in 70:
			var p := o + Vector2(rng.randf() * w, rng.randf() * h)
			draw_circle(p, rng.randf_range(4, 40), Color(0.55, 0.38, 0.18, 0.035))
		draw_rect(Rect2(o + Vector2(16, 16), size - Vector2(32, 32)), Color("5A1A10"), false, 4.0)
		draw_rect(Rect2(o + Vector2(26, 26), size - Vector2(52, 52)), Color("5A1A10"), false, 1.5)
		# başlık blokları
		draw_string(UIKit.serif(900), o + Vector2(0, 86), head, HORIZONTAL_ALIGNMENT_CENTER, w, 30, Color("8A1A12"))
		draw_line(o + Vector2(w * 0.2, 100), o + Vector2(w * 0.8, 100), Color("5A1A10"), 2.0)
		draw_string(UIKit.display(), o + Vector2(0, 170), title, HORIZONTAL_ALIGNMENT_CENTER, w, 62, Color("2A0E08"))
		draw_string(UIKit.serif(700, true), o + Vector2(0, 210), "✦  " + I18n.t("title.tagline") + "  ✦", HORIZONTAL_ALIGNMENT_CENTER, w, 22, Color("8A1A12"))
		var y := 262.0
		for i in lines.size():
			var num: String = ["I", "II", "III", "IV", "V", "VI"][i % 6]
			draw_string(UIKit.display(), o + Vector2(52, y), num + ".", HORIZONTAL_ALIGNMENT_LEFT, 60, 26, Color("8A1A12"))
			var para := TextParagraph.new()
			para.add_string(String(lines[i]), UIKit.serif(600), 23)
			para.width = w - 150
			para.draw(get_canvas_item(), o + Vector2(112, y - 24), Color("2A0E08"))
			y += max(para.get_size().y, 30.0) + 18.0
		if foot != "":
			draw_line(o + Vector2(w * 0.15, y + 4), o + Vector2(w * 0.85, y + 4), Color("5A1A10"), 1.5)
			draw_string(UIKit.serif(800), o + Vector2(0, y + 40), foot, HORIZONTAL_ALIGNMENT_CENTER, w, 22, Color("2A0E08"))
		# kaldır düğmesi (kırmızı damga)
		var bw := 300.0
		_close_rect = Rect2(Vector2((w - bw) * 0.5, h - 86), Vector2(bw, 52))
		var cr := Rect2(o + _close_rect.position, _close_rect.size)
		draw_rect(cr, Color("7A0E1C"))
		draw_rect(cr.grow(-4), UIKit.GOLD, false, 2.0)
		draw_string(UIKit.serif(800), cr.position + Vector2(0, 35), I18n.t("howto.close"), HORIZONTAL_ALIGNMENT_CENTER, bw, 22, UIKit.GOLD)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Pirinç isim levhası şeklinde duyuru bandı (HUD)
class Banner extends Control:
	var text := ""
	var sub := ""
	var accent := Color("F2C66A")
	func _draw() -> void:
		if text == "":
			return
		var f := UIKit.display()
		var fs := 40
		var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var w := maxf(tw + 120.0, 420.0)
		var r := Rect2((size.x - w) * 0.5, 0, w, 74 if sub == "" else 104)
		draw_rect(Rect2(r.position + Vector2(5, 6), r.size), Color(0, 0, 0, 0.5))
		draw_rect(r, Color(0.13, 0.05, 0.04, 0.92))
		draw_rect(r, UIKit.BRASS, false, 4.0)
		draw_rect(r.grow(-8), Color(UIKit.BRASS, 0.4), false, 1.0)
		UIKit.draw_glow_text(self, f, Vector2(r.position.x, r.position.y + 52), text, fs, accent, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		if sub != "":
			draw_string(UIKit.serif(600, true), Vector2(r.position.x, r.position.y + 88), sub, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 20, UIKit.CREAM)
