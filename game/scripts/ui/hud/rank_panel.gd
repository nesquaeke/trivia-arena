class_name RankPanel
extends Control
## Sonuç ekranında Sahne Rütbesi kartı: kazanılan XP satır satır gelir,
## çubuk dolar, sayı döner; seviye atlanırsa madalyon parlar ve açılan yeni
## kostüm/aksesuarlar kart kart düşer.

const W := 620.0
const H := 360.0

var award := {}
var _t := -1.0
var _bar := 0.0
var _shown_xp := 0.0
var _burst := 0.0
var _level_shown := 1

func _ready() -> void:
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func play(p_award: Dictionary) -> void:
	award = p_award
	if award.is_empty():
		visible = false
		return
	visible = true
	_t = 0.0
	_shown_xp = float(award.before)
	_level_shown = int(award.level_before)
	_burst = 0.0

func _process(delta: float) -> void:
	if not visible or _t < 0.0:
		return
	_t += delta
	var lines: Array = award.get("lines", [])
	# satırlar 1.2 sn'den itibaren 0.28 sn arayla; XP onlarla birlikte akar
	var shown_lines := clampi(int((_t - 1.2) / 0.28) + 1, 0, lines.size())
	var target := float(award.before)
	for i in shown_lines:
		target += float(lines[i][1])
	var prev := int(_shown_xp)
	_shown_xp = move_toward(_shown_xp, target, delta * 420.0)
	if int(_shown_xp) / 10 != prev / 10 and _shown_xp < target:
		Pal.sfx("tick", -16.0, 1.2 + Progress.level_frac(int(_shown_xp)) * 0.6)
	var lv := Progress.level_of(int(_shown_xp))
	if lv > _level_shown:
		_level_shown = lv
		_burst = 1.0
		Pal.sfx("ui_confirm", 0.0, 0.7)
		Pal.sfx("cheer", -10.0)
	_burst = maxf(0.0, _burst - delta * 0.8)
	queue_redraw()

func _draw() -> void:
	if award.is_empty():
		return
	var a := clampf((_t - 0.8) / 0.4, 0.0, 1.0)
	var r := Rect2(0, (1.0 - a) * 30.0, W, H)
	var pts := Icons.notched(r, 18)
	draw_colored_polygon(Icons.notched(Rect2(r.position + Vector2(8, 12), r.size), 18), Color(0, 0, 0, 0.45 * a))
	draw_colored_polygon(pts, Color(0.075, 0.025, 0.032, 0.94 * a))
	Icons.outline(self, pts, Color(Pal.GOLD, 0.55 * a), 1.5)
	var y0 := r.position.y
	# madalyon: seviye
	var c := Vector2(76, y0 + 84)
	var glow := _burst
	if glow > 0.0:
		for k in 3:
			draw_arc(c, 56 + k * 10 + (1.0 - glow) * 30, 0, TAU, 40, Color(Pal.GOLD, glow * 0.5 * a), 3.0, true)
	draw_circle(c, 52, Color(Pal.BRASS_LO, a))
	draw_circle(c, 46, Color(Pal.VELVET, a))
	draw_arc(c, 46, 0, TAU, 40, Color(Pal.GOLD, a), 3.0, true)
	var lvs := str(_level_shown)
	var f := Pal.display()
	var lw := f.get_string_size(lvs, HORIZONTAL_ALIGNMENT_LEFT, -1, 54).x
	draw_string(f, Vector2(c.x - lw * 0.5, c.y + 19), lvs, HORIZONTAL_ALIGNMENT_LEFT, -1, 54, Color(Pal.CHAMPAGNE, a))
	# başlık
	var kf := Pal.kicker()
	var ks := Pal.upper(Pal.t("rank.kicker"))
	var x := 146.0
	for i in ks.length():
		draw_string(kf, Vector2(x, y0 + 44), ks.substr(i, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(Pal.GOLD, a))
		x += kf.get_char_size(ks.unicode_at(i), 16).x + 3
	draw_string(Pal.display(), Vector2(146, y0 + 90), Pal.upper(Pal.t(Progress.title_key(_level_shown))), HORIZONTAL_ALIGNMENT_LEFT, W - 170, 42, Color(Pal.CHAMPAGNE, a))
	if int(award.level_after) > int(award.level_before) and _level_shown == int(award.level_after):
		draw_string(Pal.italic_black(), Vector2(146, y0 + 118), Pal.t("rank.up"), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(Pal.GOLD, a))
	# XP çubuğu
	var bx := 146.0
	var by := y0 + 132.0
	var bw := W - 176.0
	var frac := Progress.level_frac(int(_shown_xp))
	draw_rect(Rect2(bx, by, bw, 14), Color(0, 0, 0, 0.5 * a))
	draw_rect(Rect2(bx, by, bw * frac, 14), Color(Pal.GOLD, a))
	draw_rect(Rect2(bx, by, bw * frac, 4), Color(1, 1, 1, 0.25 * a))
	var gain_txt := "+%d XP" % int(_shown_xp - float(award.before))
	draw_string(Pal.display_bold(), Vector2(bx, by + 38), gain_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(Pal.GOOD, a))
	if int(award.get("coins", 0)) > 0:
		var gx := bx + Pal.display_bold().get_string_size(gain_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 26
		Icons.draw(self, "coins", Vector2(gx + 10, by + 30), 22, Color(Pal.GOLD, a))
		draw_string(Pal.display_bold(), Vector2(gx + 26, by + 38), "+%d" % int(award.coins), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(Pal.GOLD, a))
	if _level_shown < Progress.MAX_LEVEL:
		var nxt := Pal.t("rank.next", {"n": Progress.xp_for(_level_shown + 1) - int(_shown_xp)})
		var nw := Pal.italic().get_string_size(nxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string(Pal.italic(), Vector2(bx + bw - nw, by + 36), nxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(Pal.CREAM, 0.7 * a))
	# döküm
	var lines: Array = award.get("lines", [])
	var ly := y0 + 200.0
	for i in lines.size():
		var la := clampf((_t - 1.2 - i * 0.28) / 0.25, 0.0, 1.0) * a
		if la <= 0.0:
			break
		var line: Array = lines[i]
		var txt := Pal.t(String(line[0]), {"n": int(line[2])})
		var col := i % 2
		var row := i / 2
		var lx := 24.0 + col * 300.0
		var yy := ly + row * 26.0
		draw_string(Pal.italic(), Vector2(lx, yy), txt, HORIZONTAL_ALIGNMENT_LEFT, 210, 17, Color(Pal.CREAM, 0.85 * la))
		draw_string(Pal.display_bold(), Vector2(lx + 216, yy + 1), "+%d" % int(line[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(Pal.GOLD, la))
	# yeni açılanlar
	var fresh: Array = award.get("new", [])
	if not fresh.is_empty():
		var ua := clampf((_t - 1.4 - lines.size() * 0.28) / 0.4, 0.0, 1.0) * a
		var uy := y0 + H - 44.0
		draw_string(Pal.kicker(), Vector2(24, uy), Pal.upper(Pal.t("rank.new")), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(Pal.GOLD, ua))
		var ux := 24.0 + Pal.kicker().get_string_size(Pal.upper(Pal.t("rank.new")), HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 20
		for i in mini(fresh.size(), 4):
			var sp: PackedStringArray = String(fresh[i]).split(":")
			var nm := Pal.t(RankPanel.item_key(sp[0], sp[1]))
			var drop := clampf((ua - i * 0.15) * 1.5, 0.0, 1.0)
			var box := Rect2(ux, uy - 26 - (1.0 - drop) * 20, 30 + Pal.display_bold().get_string_size(Pal.upper(nm), HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x, 34)
			if ux + box.size.x > W - 10:
				break
			draw_colored_polygon(Icons.notched(box, 6), Color(Pal.VELVET_HI, 0.9 * drop))
			RankPanel.draw_item_icon(self, sp[0], sp[1], box.position + Vector2(15, 17), 18, drop)
			draw_string(Pal.display_bold(), box.position + Vector2(28, 24), Pal.upper(nm), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(Pal.CHAMPAGNE, drop))
			ux += box.size.x + 8

## Öğenin metin anahtarı (kategoriye göre önek)
static func item_key(cat: String, item: String) -> String:
	match cat:
		"culture":
			return "culture." + item
		"castle":
			return "castle." + item
		"banner":
			return "banner." + item
		"color":
			return "color." + item
	return "look." + item

## Küçük simge: renk için keçe damlası, diğerleri için kategori simgesi
static func draw_item_icon(ci: CanvasItem, cat: String, item: String, c: Vector2, s: float, a := 1.0) -> void:
	match cat:
		"color":
			ci.draw_circle(c, s * 0.45, Color(PlushVisual.COLORS.get(item, Color.WHITE), a))
		"banner":
			var tex := CastleModel.banner_texture(item, Pal.GOLD)
			ci.draw_texture_rect(tex, Rect2(c - Vector2(s * 0.5, s * 0.32), Vector2(s, s * 0.64)), false, Color(1, 1, 1, a))
		_:
			var ic := {"hat": "hat", "mustache": "mask", "bowtie": "star", "glasses": "opera", "culture": "swords", "castle": "castle"}
			Icons.draw(ci, String(ic.get(cat, "star")), c, s, Color(Pal.GOLD, a))
