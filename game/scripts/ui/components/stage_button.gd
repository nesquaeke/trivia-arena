@tool
class_name StageButton
extends Button
## Menü satırı: ampullü pirinç madalyon (içinde simge), büyük başlık, italik alt yazı.
## Üstüne gelince kadife bir ışık bandı soldan süzülür, başlık sağa kayar,
## altın ok belirir. Klavye/gamepad odağında da aynı şekilde yanar.

@export var index := "01":
	set(v):
		index = v
		queue_redraw()
## Madalyonun içindeki simge (Icons.draw adı). Boşsa numara yazılır.
@export var emblem := "":
	set(v):
		emblem = v
		queue_redraw()
@export var title := "Trivia Arena":
	set(v):
		title = v
		queue_redraw()
## küçük düğmede alt yazı üstüne gelince sağda belirir; iki sütunlu menüde kapalı
var side_caption := true
@export var caption := "":
	set(v):
		caption = v
		queue_redraw()
@export var big := true:
	set(v):
		big = v
		custom_minimum_size.y = 92.0 if big else 45.0
		queue_redraw()
@export var accent := Color("F6CF7B")

var _h := 0.0          # üstünde olma (yumuşatılmış)
var _press := 0.0
var _hover := false
var _intro := 1.0
var _t := 0.0

func _init() -> void:
	flat = true
	text = ""
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size.y = 92.0

func _ready() -> void:
	mouse_entered.connect(_on_enter)
	mouse_exited.connect(func(): _hover = false)
	focus_entered.connect(_on_enter)
	focus_exited.connect(func(): _hover = false)
	button_down.connect(func():
		_press = 1.0
		Pal.sfx("ui_confirm", -2.0))
	for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(st, StyleBoxEmpty.new())
	set_process(true)

func _on_enter() -> void:
	if not _hover:
		_hover = true
		Pal.sfx("ui_hover", -6.0, randf_range(0.97, 1.05))

func intro(delay: float) -> void:
	_intro = 0.0
	var tw := create_tween()
	tw.tween_property(self, "_intro", 1.0, 0.6).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	var target := 1.0 if (_hover or has_focus()) and not disabled else 0.0
	_h = Fx.damp(_h, target, 12.0, delta)
	_press = maxf(0.0, _press - delta * 3.0)
	_t += delta
	queue_redraw()

func _draw() -> void:
	var h := _h
	var ia := clampf(_intro * 1.4, 0.0, 1.0)
	var slide := (1.0 - _intro) * -60.0
	# ışık bandı: soldan kadife, sağa doğru sönüyor
	if h > 0.01:
		var r := Rect2(-48, 2, size.x + 90, size.y - 4)
		var c0 := Color(Pal.VELVET_HI, 0.62 * h)
		var c1 := Color(Pal.VELVET, 0.0)
		var reach := r.position.x + r.size.x * (0.35 + 0.65 * h)
		draw_polygon(PackedVector2Array([r.position, Vector2(reach, r.position.y), Vector2(reach, r.end.y), Vector2(r.position.x, r.end.y)]),
			PackedColorArray([c0, c1, c1, c0]))
		# üst ve alt kıl çizgi
		draw_line(Vector2(-48, 2), Vector2(reach * 0.8, 2), Color(Pal.GOLD, 0.35 * h), 1.0)
		draw_line(Vector2(-48, size.y - 2), Vector2(reach * 0.8, size.y - 2), Color(Pal.GOLD, 0.2 * h), 1.0)
		# sol altın çubuk
		var bh := (size.y - 20) * h
		draw_rect(Rect2(-22, (size.y - bh) * 0.5, 4, bh), Pal.GOLD)
	if _press > 0.0:
		draw_rect(Rect2(-48, 2, size.x + 90, size.y - 4), Color(1, 0.9, 0.7, 0.18 * _press))
	var f_title := Pal.display()
	var fs := 62 if big else 33
	var cap_fs := 20 if big else 19
	var x0 := (84.0 if emblem != "" else 64.0) + 18.0 * h + slide
	var title_y := 58.0 if big else 34.0
	# madalyon (ya da numara)
	var idx_col := Pal.MUTED.lerp(accent, h)
	var iy := title_y - fs * 0.5
	if emblem != "":
		_draw_medallion(Vector2(slide + 30, title_y - fs * 0.36), 24.0 if big else 17.0, h, ia)
	else:
		draw_string(Pal.italic(), Vector2(slide + 4, iy), index, HORIZONTAL_ALIGNMENT_LEFT, -1, 24 if big else 19, Color(idx_col, ia))
		draw_line(Vector2(slide + 6, iy + 8), Vector2(slide + 38 + 10 * h, iy + 8), Color(idx_col, 0.6 * ia), 1.0)
	# başlık
	var tcol := Pal.CREAM.lerp(Pal.CHAMPAGNE, h)
	var ttl := Pal.upper(title)
	# uzun dillerde düğme genişliğine sığdır (ok için pay bırak)
	while fs > 20 and x0 + f_title.get_string_size(ttl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 48 > size.x:
		fs -= 1
	draw_string(f_title, Vector2(x0, title_y + 4), ttl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.45 * ia))
	draw_string(f_title, Vector2(x0, title_y), ttl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(tcol, ia))
	var tw := f_title.get_string_size(ttl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	# ok
	if h > 0.02:
		var ax := x0 + tw + 22 + 10 * h
		var ay := title_y - fs * 0.36
		Icons.draw(self, "arrow_r", Vector2(ax, ay), fs * 0.55, Color(accent, h), 3.0)
	# alt yazı: büyüklerde hep altta; küçüklerde yalnız üstüne gelince, sağda belirir
	if caption != "":
		if big:
			var ca := (0.62 + 0.38 * h) * ia
			draw_string(Pal.italic(), Vector2(x0 + 2, title_y + cap_fs + 7), caption, HORIZONTAL_ALIGNMENT_LEFT, size.x - x0, cap_fs, Color(Pal.CREAM, ca))
		elif h > 0.02 and side_caption:
			var cx := x0 + tw + 58 + 12 * h
			draw_string(Pal.italic(), Vector2(cx, title_y - 8), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, cap_fs, Color(Pal.CREAM, 0.85 * h * ia))

## Tiyatro tabelası gibi: koyu pirinç disk, çevresinde küçük ampuller.
## Üstüne gelince ampuller sırayla yanıp döner, simge altına kesilir.
func _draw_medallion(c: Vector2, r: float, h: float, a: float) -> void:
	var spin := _t * 1.6
	draw_circle(c + Vector2(0, 3), r + 9, Color(0, 0, 0, 0.35 * a))
	draw_circle(c, r + 8, Color(Pal.BRASS_LO.lerp(Pal.BRASS, h * 0.5), a))
	draw_circle(c, r + 2, Color(0.09, 0.035, 0.04, a))
	draw_arc(c, r + 2, 0, TAU, 40, Color(Pal.GOLD, (0.35 + 0.5 * h) * a), 1.5, true)
	var n := 12
	for i in n:
		var ang := TAU * i / n - PI / 2
		var p := c + Vector2(cos(ang), sin(ang)) * (r + 5)
		# sırayla yanan ampuller (hover), sönükken hafif kor
		var chase := 0.5 + 0.5 * sin(spin * 4.0 - i * 0.9)
		var lit := lerpf(0.18, 0.35 + 0.65 * chase, h)
		draw_circle(p, 2.4 if r > 22 else 2.0, Color(Pal.CHAMPAGNE.lerp(Pal.GOLD, 1.0 - lit), lit * a))
		if lit > 0.6:
			draw_circle(p, 5.0, Color(Pal.GOLD, (lit - 0.6) * 0.5 * a))
	var ic := Color(Pal.BRASS.lerp(Pal.GOLD, h), a)
	Icons.draw(self, emblem, c + Vector2(0, 1), r * 1.25, ic)
