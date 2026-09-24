class_name DuelSplash
extends Control
## Düello açılışı (≈1.9 sn): ekranın ortasından çapraz bir bant geçer.
## Saldıran soldan, savunan sağdan kendi renklerindeki eğik levhalarla kayarak
## gelir; üstlerinde kostümlü canlı portreleri. Ortaya çapraz kılıç mührü
## basılır, altında hedef bölgenin adı. Sonra iki levha karşıya süzülüp çıkar.

const BAND_H := 380.0
const DUR := 1.9

var a := {}
var d := {}
var place := ""
var _t := 0.0
var _pa: PlushPortrait
var _pd: PlushPortrait
var _playing := false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_pa = _make_portrait(0.55)
	_pd = _make_portrait(-0.55)

func _make_portrait(yaw: float) -> PlushPortrait:
	var p := PlushPortrait.new()
	p.yaw = yaw
	p.hop_every = 99.0
	p.size = Vector2(330, 330)
	add_child(p)
	return p

func play(p_a: Dictionary, p_d: Dictionary, p_place: String) -> void:
	a = p_a
	d = p_d
	place = p_place
	_pa.set_look(a.get("look", {}))
	_pa.set_culture(String(a.get("culture", "")))
	_pd.set_look(d.get("look", {}))
	_pd.set_culture(String(d.get("culture", "")))
	_t = 0.0
	_playing = true
	visible = true
	modulate.a = 1.0
	Pal.sfx("whoosh", -3.0, 0.8)
	get_tree().create_timer(0.36).timeout.connect(func():
		Pal.sfx("sting", -4.0)
		_pa.hop()
		_pd.hop())

func _process(delta: float) -> void:
	if not _playing:
		return
	_t += delta
	if _t >= DUR:
		_playing = false
		visible = false
		return
	# levhaların konumu: giriş (yaylı), bekleme (hafif kayma), çıkış
	var cy := 540.0
	var s := _slide()
	var la := -1920.0 + s * 1880.0
	var ra := 1920.0 - s * 1880.0 + 1920.0
	_pa.position = Vector2(la + 90, cy - 200)
	_pd.position = Vector2(ra - 90 - 330, cy - 200)
	var out := clampf((_t - 1.5) / 0.4, 0.0, 1.0)
	_pa.modulate.a = 1.0 - out
	_pd.modulate.a = 1.0 - out
	queue_redraw()

func _slide() -> float:
	if _t < 0.4:
		var k := _t / 0.4
		return 1.0 - pow(1.0 - k, 3.0) * (1.0 - 0.0) + sin(k * PI) * 0.06
	if _t < 1.5:
		return 1.0 + (_t - 0.4) * 0.02
	# çıkış: levhalar geldikleri yöne geri çekilir
	var k2 := clampf((_t - 1.5) / 0.4, 0.0, 1.0)
	return 1.022 * (1.0 - k2 * k2)

func _draw() -> void:
	modulate.a = 1.0 - clampf((_t - 1.6) / 0.3, 0.0, 1.0)
	var cy := 540.0
	var s := _slide()
	var out := clampf((_t - 1.5) / 0.4, 0.0, 1.0)
	var inn := clampf(_t / 0.25, 0.0, 1.0)
	# karartma bandı
	var dim := Color(0.02, 0.0, 0.01, 0.62 * inn * (1.0 - out))
	draw_rect(Rect2(0, cy - BAND_H * 0.5, 1920, BAND_H), dim)
	var ca: Color = a.get("color", Pal.GOLD)
	var cd: Color = d.get("color", Pal.BAD)
	var skew := 90.0
	var h2 := BAND_H * 0.5 - 20
	# saldıranın levhası (soldan), savunanın levhası (sağdan)
	var la := -1920.0 + s * 1880.0
	var ra := 1920.0 - s * 1880.0 + 1920.0
	var left := PackedVector2Array([Vector2(la, cy - h2), Vector2(la + 960 + skew * 0.5 - 20, cy - h2), Vector2(la + 960 - skew * 0.5 - 20, cy + h2), Vector2(la, cy + h2)])
	var right := PackedVector2Array([Vector2(ra - 960 + skew * 0.5 + 20, cy - h2), Vector2(ra, cy - h2), Vector2(ra, cy + h2), Vector2(ra - 960 - skew * 0.5 + 20, cy + h2)])
	_slab(left, ca, true)
	_slab(right, cd, false)
	# adlar
	var f := Pal.display()
	var na := Pal.upper(String(a.get("name", "")))
	var nd := Pal.upper(String(d.get("name", "")))
	var kf := Pal.kicker()
	var ax := la + 440.0
	var dx := ra - 960 + 150.0
	draw_string(kf, Vector2(ax, cy - 70), Pal.upper(Pal.t("cq.attacker")), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(ca.lightened(0.6), 0.9))
	_big_name(na, Vector2(ax, cy + 10), 88, Pal.CHAMPAGNE)
	draw_string(kf, Vector2(dx, cy - 70), Pal.upper(Pal.t("cq.defender")), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(cd.lightened(0.6), 0.9))
	_big_name(nd, Vector2(dx, cy + 10), 88, Pal.CHAMPAGNE)
	# ortada mühür
	var st := clampf((_t - 0.3) / 0.25, 0.0, 1.0)
	if st > 0.0:
		var pop := 1.0 + (1.0 - st) * 0.9
		var al := st * (1.0 - out)
		var c := Vector2(960, cy)
		draw_set_transform(c, sin(_t * 2.0) * 0.03, Vector2.ONE * pop)
		draw_circle(Vector2(0, 6), 84, Color(0, 0, 0, 0.5 * al))
		draw_circle(Vector2.ZERO, 82, Color(Pal.VELVET, al))
		draw_arc(Vector2.ZERO, 76, 0, TAU, 48, Color(Pal.GOLD, al), 3.0, true)
		for i in 16:
			var ang := TAU * i / 16.0
			draw_circle(Vector2(cos(ang), sin(ang)) * 68, 2.5, Color(Pal.GOLD, 0.8 * al))
		Icons.draw(self, "swords", Vector2(0, -4), 92, Color(Pal.CHAMPAGNE, al), 7.0)
		draw_set_transform(Vector2.ZERO)
		# hedef şeridi
		var pt := Pal.upper(place)
		var pw := kf.get_string_size(pt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + pt.length() * 3.0
		var rib := Rect2(960 - pw * 0.5 - 40, cy + 104, pw + 80, 44)
		draw_colored_polygon(PackedVector2Array([rib.position, Vector2(rib.end.x, rib.position.y), Vector2(rib.end.x - 16, rib.end.y), Vector2(rib.position.x + 16, rib.end.y)]), Color(0.06, 0.02, 0.03, 0.95 * al))
		draw_line(rib.position, Vector2(rib.end.x, rib.position.y), Color(Pal.GOLD, al), 2.0)
		var x := 960 - pw * 0.5
		for i in pt.length():
			draw_string(kf, Vector2(x, cy + 135), pt.substr(i, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(Pal.GOLD, al))
			x += kf.get_char_size(pt.unicode_at(i), 24).x + 3

func _slab(pts: PackedVector2Array, col: Color, is_left: bool) -> void:
	var sh := PackedVector2Array()
	for p in pts:
		sh.append(p + Vector2(0, 10))
	draw_colored_polygon(sh, Color(0, 0, 0, 0.4))
	var dark := col.darkened(0.55)
	var cols := PackedColorArray([dark, col.darkened(0.15), col.darkened(0.3), dark]) if is_left else PackedColorArray([col.darkened(0.15), dark, dark, col.darkened(0.3)])
	draw_polygon(pts, cols)
	# hız çizgileri
	for i in 5:
		var y := pts[0].y + 30 + i * 62
		var x0 := pts[0].x + 40 if is_left else pts[1].x - 340
		draw_line(Vector2(x0, y), Vector2(x0 + 300, y), Color(1, 1, 1, 0.06), 6.0)
	var edge := PackedVector2Array([pts[1], pts[2]]) if is_left else PackedVector2Array([pts[0], pts[3]])
	draw_line(edge[0], edge[1], Pal.GOLD, 4.0)

func _big_name(s: String, p: Vector2, fs: int, col: Color) -> void:
	var f := Pal.display()
	while fs > 44 and f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > 380:
		fs -= 4
	draw_string(f, p + Vector2(0, 6), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.5))
	draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
