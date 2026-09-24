class_name PauseMenu
extends Control
## Oyun içinde Esc / gamepad Start: perde arası. Oyun durur (müzik çalar),
## ortada kadife bir pano: Devam · Lobiye dön, altında hızlı ses ayarı.

signal resume_requested
signal lobby_requested
signal settings_requested

var _panel: Control
var _resume: StageButton
var _lobby: StageButton
var _settings: StageButton
var _music: BrassSlider
var _sfx: BrassSlider
var _k := 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_panel = Control.new()
	_panel.position = Vector2(660, 250)
	_panel.size = Vector2(600, 560)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var col := VBoxContainer.new()
	col.position = Vector2(40, 150)
	col.size = Vector2(540, 400)
	col.add_theme_constant_override("separation", 4)
	_panel.add_child(col)
	_resume = StageButton.new()
	_resume.emblem = "masks"
	_resume.big = false
	_resume.pressed.connect(func(): resume_requested.emit())
	col.add_child(_resume)
	_settings = StageButton.new()
	_settings.emblem = "gear"
	_settings.big = false
	_settings.pressed.connect(func(): settings_requested.emit())
	col.add_child(_settings)
	_lobby = StageButton.new()
	_lobby.emblem = "door"
	_lobby.big = false
	_lobby.pressed.connect(func(): lobby_requested.emit())
	col.add_child(_lobby)
	var sp := Control.new()
	sp.custom_minimum_size.y = 26
	col.add_child(sp)
	for key in ["music_vol", "sfx_vol"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var lab := Label.new()
		lab.add_theme_font_override("font", Pal.display_bold())
		lab.add_theme_font_size_override("font_size", 22)
		lab.add_theme_color_override("font_color", Pal.CREAM)
		lab.custom_minimum_size.x = 110
		lab.name = "L_" + key
		row.add_child(lab)
		var sl := BrassSlider.new()
		sl.changed.connect(func(v):
			Profile.set_setting(key, v)
			GameSettings.apply_audio(get_tree()))
		row.add_child(sl)
		col.add_child(row)
		if key == "music_vol":
			_music = sl
		else:
			_sfx = sl
	_panel.draw.connect(_draw_panel)

func open() -> void:
	_resume.title = Pal.t("pause.resume")
	_lobby.title = Pal.t("pause.lobby")
	_settings.title = Pal.t("menu.settings")
	(_music.get_parent().get_node("L_music_vol") as Label).text = Pal.t("settings.music")
	(_sfx.get_parent().get_node("L_sfx_vol") as Label).text = Pal.t("settings.sfx")
	_music.value = float(Profile.setting("music_vol", 0.7))
	_sfx.value = float(Profile.setting("sfx_vol", 0.9))
	visible = true
	_k = 0.0
	var tw := create_tween()
	tw.tween_property(self, "_k", 1.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_resume.intro(0.05)
	_settings.intro(0.08)
	_lobby.intro(0.1)
	_resume.grab_focus()
	Pal.sfx("whoosh", -8.0, 0.7)

func refocus() -> void:
	_settings.grab_focus()
	_music.value = float(Profile.setting("music_vol", 0.7))
	_sfx.value = float(Profile.setting("sfx_vol", 0.9))

func close() -> void:
	visible = false

func _process(_d: float) -> void:
	if visible:
		queue_redraw()
		_panel.queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.0, 0.01, 0.72 * _k))

func _draw_panel() -> void:
	var k := _k
	var r := Rect2(0, (1.0 - k) * 40.0, _panel.size.x, _panel.size.y)
	var pts := Icons.notched(r, 24)
	var sh := Icons.notched(Rect2(r.position + Vector2(10, 14), r.size), 24)
	_panel.draw_colored_polygon(sh, Color(0, 0, 0, 0.5 * k))
	_panel.draw_colored_polygon(pts, Color(0.09, 0.025, 0.035, 0.97 * k))
	Icons.outline(_panel, pts, Color(Pal.GOLD, 0.6 * k), 2.0)
	_panel.draw_rect(Rect2(24, r.position.y, r.size.x - 48, 6), Color(Pal.VELVET_HI, k))
	var kf := Pal.kicker()
	var ks := Pal.upper(Pal.t("settings.kicker"))
	var x := 44.0
	for i in ks.length():
		_panel.draw_string(kf, Vector2(x, r.position.y + 56), ks.substr(i, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(Pal.GOLD, k))
		x += kf.get_char_size(ks.unicode_at(i), 18).x + 4
	_panel.draw_string(Pal.display(), Vector2(44, r.position.y + 128), Pal.upper(Pal.t("pause.title")), HORIZONTAL_ALIGNMENT_LEFT, -1, 84, Color(Pal.CHAMPAGNE, k))
	var hint := Pal.t("pause.hint")
	_panel.draw_string(Pal.italic(), Vector2(44, r.end.y - 22), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(Pal.CREAM, 0.6 * k))
