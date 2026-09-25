class_name OnlinePanel
extends Control
## Çevrimiçi: uzaktaki arkadaşlarla oynamanın iki yolu.
##  1. Steam Remote Play Together: oyun arkadaşına yayınlanır, onun klavyesi /
##     gamepad'i burada yerel bir oyuncu olur. Davet Steam arayüzünden.
##  2. Ev partisi internetten: sunucu herkese açıksa (tools: server/) telefonlar
##     kodla her yerden bağlanır; görüntüyü Discord vb. ile paylaşırsın.
## Ayrıca başarımlar listesi (Steam yoksa da profilde tutulur).

signal closed
signal house_requested

var _k := 0.0
var _panel: Control
var _rpt: CtaButton
var _lobby: CtaButton
var _house: CtaButton
var _back: CtaButton
var _status := ""

const PW := 1180.0
const PH := 760.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_panel = Control.new()
	_panel.position = Vector2((1920 - PW) * 0.5, (1080 - PH) * 0.5 + 20)
	_panel.size = Vector2(PW, PH)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_panel.draw.connect(_draw_panel)
	var col := VBoxContainer.new()
	col.position = Vector2(40, 330)
	col.size = Vector2(460, 300)
	col.add_theme_constant_override("separation", 14)
	_panel.add_child(col)
	_rpt = _btn(col, "gold")
	_rpt.pressed.connect(func():
		if SteamService.invite_remote_play():
			_status = Pal.t("online.rpt_open")
		else:
			_status = Pal.t("online.no_steam")
		_panel.queue_redraw())
	_lobby = _btn(col, "velvet")
	_lobby.pressed.connect(func():
		if SteamService.host_lobby():
			_status = Pal.t("online.lobby_open")
		else:
			_status = Pal.t("online.no_steam")
		_panel.queue_redraw())
	_house = _btn(col, "velvet")
	_house.pressed.connect(func():
		close()
		house_requested.emit())
	_back = CtaButton.new()
	_back.style = "ghost"
	_back.custom_minimum_size = Vector2(200, 60)
	_back.font_size = 26
	_back.position = Vector2(40, PH - 92)
	_back.pressed.connect(close)
	_panel.add_child(_back)
	SteamService.lobby_ready.connect(func(_id):
		_status = Pal.t("online.lobby_ready")
		_panel.queue_redraw())

func _btn(parent: Control, style: String) -> CtaButton:
	var b := CtaButton.new()
	b.style = style
	b.custom_minimum_size = Vector2(460, 66)
	b.font_size = 24
	parent.add_child(b)
	return b

func open() -> void:
	_rpt.label = Pal.t("online.rpt")
	_lobby.label = Pal.t("online.lobby")
	_house.label = Pal.t("online.house")
	_back.label = Pal.t("common.back")
	_status = Pal.t("online.steam_on", {"name": SteamService.persona}) if SteamService.available else Pal.t("online.no_steam")
	visible = true
	_k = 0.0
	create_tween().tween_property(self, "_k", 1.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	Pal.sfx("page", -2.0)
	_rpt.grab_focus()

func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()

func _unhandled_input(e: InputEvent) -> void:
	if visible and (e.is_action_pressed("ui_cancel") or (e is InputEventJoypadButton and e.pressed and e.button_index == JOY_BUTTON_B)):
		close()
		get_viewport().set_input_as_handled()

func _process(_d: float) -> void:
	if visible:
		queue_redraw()
		_panel.queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), Color(0.02, 0.0, 0.01, 0.7 * _k))

func _draw_panel() -> void:
	var k := _k
	var off := (1.0 - k) * 30.0
	var r := Rect2(0, off, PW, PH)
	var pts := Icons.notched(r, 26)
	_panel.draw_colored_polygon(Icons.notched(Rect2(r.position + Vector2(12, 16), r.size), 26), Color(0, 0, 0, 0.5 * k))
	_panel.draw_colored_polygon(pts, Color(0.075, 0.025, 0.032, 0.97 * k))
	Icons.outline(_panel, pts, Color(Pal.GOLD, 0.55 * k), 2.0)
	_panel.draw_rect(Rect2(26, off, PW - 52, 6), Color(Pal.VELVET_HI, k))
	var kf := Pal.kicker()
	var ks := Pal.upper(Pal.t("online.kicker"))
	var x := 44.0
	for i in ks.length():
		_panel.draw_string(kf, Vector2(x, 50 + off), ks.substr(i, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(Pal.GOLD, k))
		x += kf.get_char_size(ks.unicode_at(i), 18).x + 4
	_panel.draw_string(Pal.display(), Vector2(40, 132 + off), Pal.upper(Pal.t("menu.online")), HORIZONTAL_ALIGNMENT_LEFT, -1, 78, Color(Pal.CHAMPAGNE, k))
	var para := TextParagraph.new()
	para.width = 460
	para.add_string(Pal.t("online.explain"), Pal.serif(), 21)
	para.draw(_panel.get_canvas_item(), Vector2(44, 160 + off), Color(Pal.CREAM, 0.85 * k))
	# durum
	_panel.draw_string(Pal.italic(), Vector2(44, PH - 120 + off), _status, HORIZONTAL_ALIGNMENT_LEFT, 480, 18, Color(Pal.GOLD, 0.85 * k))
	# başarımlar: sağ sütun
	var ax := 560.0
	_panel.draw_line(Vector2(ax - 24, 150 + off), Vector2(ax - 24, PH - 40 + off), Color(Pal.BRASS, 0.3 * k), 1.0)
	var title := Pal.upper(Pal.t("ach.title")) + "  %d / %d" % [SteamService.unlocked_count(), SteamService.ACHIEVEMENTS.size()]
	_panel.draw_string(Pal.display_bold(), Vector2(ax, 170 + off), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(Pal.CHAMPAGNE, k))
	var i := 0
	for id in SteamService.ACHIEVEMENTS:
		var got := SteamService.is_unlocked(id)
		var cx := ax + (i % 2) * 300.0
		var cy := 210.0 + (i / 2) * 82.0 + off
		var col := Pal.GOLD if got else Color(Pal.MUTED, 0.5)
		_panel.draw_circle(Vector2(cx + 22, cy + 24), 20, Color(col, k))
		Icons.draw(_panel, "crown" if got else "cross", Vector2(cx + 22, cy + 25), 22 if got else 14, Color(Pal.VELVET if got else Pal.INK, k))
		_panel.draw_string(Pal.display_bold(), Vector2(cx + 52, cy + 22), Pal.upper(SteamService.ach_name(id)), HORIZONTAL_ALIGNMENT_LEFT, 240, 20, Color(Pal.CHAMPAGNE if got else Pal.CREAM, (1.0 if got else 0.6) * k))
		_panel.draw_string(Pal.italic(), Vector2(cx + 52, cy + 44), SteamService.ach_desc(id), HORIZONTAL_ALIGNMENT_LEFT, 240, 15, Color(Pal.CREAM, 0.6 * k))
		i += 1
