class_name LobbyMenu
extends Control
## Lobi menüsü (ekranın sol tarafı): logo, gösteri listesi, kurulum paneli.
## Sahneden bağımsız; ui_root.gd sinyallerini dinler.

signal start_requested(kind: String)
signal house_requested
signal wardrobe_requested
signal loge_requested
signal howto_requested(kind: String)
signal quit_requested
signal settings_requested
signal online_requested
signal daily_requested

const COL_X := 88.0
const COL_W := 600.0
const MENU_ORDER := ["trivia", "conquest", "mayhem", "daily", "house", "online", "customize", "spectate", "howto", "settings", "quit"]

var game: Node
var logo: MarqueeLogo
var scrim: ColorRect
var menu_col: VBoxContainer
var setup_col: VBoxContainer
var footer: KeyHint
var buttons := {}
var kind := "arena"
var shown := true

var _setup_title: KineticText
var _setup_caption: Label
var _setup_rules: Label
var _bots: Stepper
var _level: Segmented
var _timer: Segmented
var _cast: Control
var _go: CtaButton
var _back: CtaButton
var _k_bots: KickerLabel
var _k_level: KickerLabel
var _k_timer: KickerLabel
var _k_setup: KickerLabel

func setup(p_game: Node) -> void:
	game = p_game
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim = ColorRect.new()
	var sm := ShaderMaterial.new()
	sm.shader = preload("res://ui/shaders/scrim.gdshader")
	sm.set_shader_parameter("reach", 0.95)
	sm.set_shader_parameter("strength", 0.9)
	scrim.material = sm
	scrim.position = Vector2(0, 0)
	scrim.size = Vector2(1000, 1080)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)
	logo = MarqueeLogo.new()
	logo.position = Vector2(COL_X - 6, 58)
	add_child(logo)

	menu_col = VBoxContainer.new()
	menu_col.position = Vector2(COL_X, 372)
	menu_col.size = Vector2(COL_W + 160, 560)
	menu_col.add_theme_constant_override("separation", 2)
	add_child(menu_col)
	_add_btn("trivia", "masks", true, func(): _open_setup("arena"))
	_add_btn("conquest", "swords", true, func(): _open_setup("conquest"))
	_add_btn("mayhem", "bolt", true, func(): _open_setup("mayhem"))
	var gap := Control.new()
	gap.custom_minimum_size.y = 10
	menu_col.add_child(gap)
	_add_btn("daily", "star", false, func(): daily_requested.emit())
	_add_btn("house", "phone", false, func(): house_requested.emit())
	_add_btn("online", "globe", false, func(): online_requested.emit())
	_add_btn("customize", "hanger", false, func(): wardrobe_requested.emit())
	_add_btn("spectate", "opera", false, func(): loge_requested.emit())
	_add_btn("howto", "scroll", false, func(): howto_requested.emit("trivia"))
	_add_btn("settings", "gear", false, _open_settings)
	_add_btn("quit", "door", false, func(): quit_requested.emit())

	setup_col = VBoxContainer.new()
	setup_col.position = Vector2(COL_X, 64)
	setup_col.size = Vector2(COL_W - 40, 640)
	setup_col.add_theme_constant_override("separation", 10)
	setup_col.visible = false
	add_child(setup_col)
	_build_setup()

	footer = KeyHint.new()
	footer.position = Vector2(COL_X, 1030)
	footer.size = Vector2(1400, 30)
	footer.font_size = 16
	footer.color = Color(Pal.CREAM, 0.75)
	add_child(footer)
	retext()

func _add_btn(id: String, idx: String, big: bool, cb: Callable) -> void:
	var b := StageButton.new()
	b.emblem = idx
	b.big = big
	b.pressed.connect(cb)
	menu_col.add_child(b)
	buttons[id] = b

func _build_setup() -> void:
	_k_setup = KickerLabel.new()
	setup_col.add_child(_k_setup)
	_setup_title = KineticText.new()
	_setup_title.font = Pal.display()
	_setup_title.font_size = 118
	_setup_title.color = Pal.CHAMPAGNE
	_setup_title.custom_minimum_size = Vector2(COL_W - 40, 120)
	_setup_title.style = 0
	_setup_title.stagger = 0.03
	setup_col.add_child(_setup_title)
	_setup_caption = _label(Pal.italic(), 24, Pal.CREAM)
	setup_col.add_child(_setup_caption)
	_setup_rules = _label(Pal.kicker(), 17, Color(Pal.GOLD, 0.8))
	setup_col.add_child(_setup_rules)
	setup_col.add_child(_spacer(14))
	_k_bots = KickerLabel.new()
	_k_bots.rules = false
	_k_bots.color = Color(Pal.CREAM, 0.75)
	_k_bots.font_size = 17
	setup_col.add_child(_k_bots)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 26)
	_bots = Stepper.new()
	_bots.max_value = 7
	_bots.changed.connect(_set_bots)
	brow.add_child(_bots)
	_cast = Control.new()
	_cast.custom_minimum_size = Vector2(260, 56)
	_cast.draw.connect(_draw_cast)
	brow.add_child(_cast)
	setup_col.add_child(brow)
	setup_col.add_child(_spacer(6))
	_k_level = KickerLabel.new()
	_k_level.rules = false
	_k_level.color = Color(Pal.CREAM, 0.75)
	_k_level.font_size = 17
	setup_col.add_child(_k_level)
	_level = Segmented.new()
	_level.custom_minimum_size = Vector2(420, 54)
	_level.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_level.changed.connect(func(i):
		Profile.set_setting("bot_level", ["easy", "normal", "hard"][i])
		game.apply_bot_level())
	setup_col.add_child(_level)
	setup_col.add_child(_spacer(6))
	_k_timer = KickerLabel.new()
	_k_timer.rules = false
	_k_timer.color = Color(Pal.CREAM, 0.75)
	_k_timer.font_size = 17
	setup_col.add_child(_k_timer)
	_timer = Segmented.new()
	_timer.custom_minimum_size = Vector2(420, 54)
	_timer.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_timer.changed.connect(func(i):
		if kind == "conquest":
			Profile.set_setting("cq_length", ["short", "normal", "long"][i])
		elif kind == "mayhem":
			Profile.set_setting("mh_length", ["quick", "tour"][i])
		else:
			Profile.set_setting("timer", [8, 10, 12][i]))
	setup_col.add_child(_timer)
	setup_col.add_child(_spacer(26))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_go = CtaButton.new()
	_go.custom_minimum_size = Vector2(340, 78)
	_go.font_size = 40
	_go.pressed.connect(func(): start_requested.emit(kind))
	row.add_child(_go)
	_back = CtaButton.new()
	_back.style = "ghost"
	_back.custom_minimum_size = Vector2(150, 78)
	_back.font_size = 28
	_back.pressed.connect(show_menu)
	row.add_child(_back)
	setup_col.add_child(row)

## Ayarlar ayrı bir ekranda (screens/settings_screen.gd); menü yalnız çağırır
func _open_settings() -> void:
	settings_requested.emit()

func is_settings() -> bool:
	return false

func _label(f: Font, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = COL_W - 60
	return l

func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	return c

func retext() -> void:
	var map := {"trivia": ["menu.trivia", "menu.trivia.sub"], "conquest": ["menu.conquest", "menu.conquest.sub"], "mayhem": ["menu.mayhem", "menu.mayhem.sub"],
		"house": ["menu.house", "menu.house.sub"], "online": ["menu.online", "menu.online.sub"], "customize": ["menu.customize", "menu.customize.sub"],
		"spectate": ["menu.spectate", "menu.spectate.sub"], "howto": ["menu.howto", "menu.howto.sub"],
		"settings": ["menu.settings", "menu.settings.sub"], "quit": ["menu.quit", "menu.quit.sub"],
		"daily": ["menu.daily", "menu.daily.sub"]}
	for id in map:
		buttons[id].title = I18n.t(map[id][0])
		buttons[id].caption = I18n.t(map[id][1])
	refresh_daily()
	footer.visible = bool(Profile.setting("hints", true))
	# tek satır: kendi tuşlar + ikinci oyuncu/gamepad nasıl katılır
	footer.items = ["WASD|" + I18n.t("hint.run"), I18n.t("key.space") + "|" + I18n.t("hint.jump"), "F|" + I18n.t("hint.shove"),
		I18n.t("key.arrows") + "+Enter|" + I18n.t("hint.p2join"), I18n.t("key.pad") + "|" + I18n.t("hint.padjoin")]
	_k_setup.text = I18n.t("setup.title")
	_k_bots.text = I18n.t("setup.bots")
	_k_level.text = I18n.t("setup.level")
	_k_timer.text = I18n.t("setup.timer")
	_level.options = [I18n.t("setup.level.easy"), I18n.t("setup.level.normal"), I18n.t("setup.level.hard")]
	_timer.options = [I18n.t("setup.seconds", {"n": 8}), I18n.t("setup.seconds", {"n": 10}), I18n.t("setup.seconds", {"n": 12})]
	_go.label = I18n.t("setup.go")
	_back.label = I18n.t("common.back")
	refresh_setup()

## Günlük Kelime satırı: bugün çözüldüyse söyle
func refresh_daily() -> void:
	if not buttons.has("daily"):
		return
	var lang := "en" if I18n.lang == "en" else "tr"
	var st := DailyWord.state(lang)
	buttons["daily"].caption = I18n.t("menu.daily.done" if bool(st.done) else "menu.daily.sub")

func refresh_setup() -> void:
	var km := {"conquest": ["menu.conquest", "menu.conquest.sub", "setup.rules_c"], "mayhem": ["menu.mayhem", "menu.mayhem.sub", "setup.rules_m"]}
	var keys: Array = km.get(kind, ["menu.trivia", "menu.trivia.sub", "setup.rules"])
	_setup_title.text = Pal.upper(I18n.t(keys[0]))
	_setup_caption.text = I18n.t(keys[1])
	_setup_rules.text = Pal.upper(I18n.t(keys[2]))
	_bots.min_value = 0 if game.players.size() > 1 else 1
	_bots.max_value = 8 - game.players.size()
	_bots.value = int(Profile.setting("bots", 3))
	_level.selected = ["easy", "normal", "hard"].find(String(Profile.setting("bot_level", "normal")))
	if kind == "conquest":
		_k_timer.text = I18n.t("setup.length")
		_timer.options = [I18n.t("setup.len.short"), I18n.t("setup.len.normal"), I18n.t("setup.len.long")]
		_timer.selected = maxi(0, ["short", "normal", "long"].find(String(Profile.setting("cq_length", "normal"))))
	elif kind == "mayhem":
		_k_timer.text = I18n.t("setup.length")
		_timer.options = [I18n.t("setup.len.quick"), I18n.t("setup.len.tour")]
		_timer.selected = maxi(0, ["quick", "tour"].find(String(Profile.setting("mh_length", "tour"))))
	else:
		_k_timer.text = I18n.t("setup.timer")
		_timer.options = [I18n.t("setup.seconds", {"n": 8}), I18n.t("setup.seconds", {"n": 10}), I18n.t("setup.seconds", {"n": 12})]
		_timer.selected = maxi(0, [8, 10, 12].find(int(Profile.setting("timer", 10))))
	_cast.queue_redraw()

func _set_bots(n: int) -> void:
	Profile.set_setting("bots", n)
	game.set_bot_count(n)
	_cast.queue_redraw()

## Sahnedeki kadro: her oyuncu için renkli bir pelüş kafası
func _draw_cast() -> void:
	var actors: Array = game.all_actors() if game.has_method("all_actors") else []
	var x := 8.0
	var cy := _cast.size.y * 0.5
	for p in actors:
		var col: Color = PlushVisual.COLORS.get(String(p.look.get("color", "mustard")), Color.WHITE)
		_cast.draw_circle(Vector2(x + 14, cy + 2), 15, Color(0, 0, 0, 0.4))
		_cast.draw_circle(Vector2(x + 14, cy), 14, col)
		_cast.draw_circle(Vector2(x + 4, cy - 12), 6, col)
		_cast.draw_circle(Vector2(x + 24, cy - 12), 6, col)
		_cast.draw_circle(Vector2(x + 9, cy - 1), 2.2, Pal.INK)
		_cast.draw_circle(Vector2(x + 19, cy - 1), 2.2, Pal.INK)
		if not (p.controller is Controllers.Bot):
			_cast.draw_arc(Vector2(x + 14, cy), 18, 0, TAU, 24, Pal.GOLD, 2.0, true)
		x += 34
	_cast.draw_string(Pal.italic(), Vector2(8, cy + 42), I18n.t("setup.players", {"n": actors.size()}), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(Pal.CREAM, 0.7))

# ── geçişler ────────────────────────────────────────────────────────
func intro() -> void:
	logo.play()
	var i := 0
	for id in MENU_ORDER:
		buttons[id].intro(0.9 + i * 0.07)
		i += 1

func _open_setup(k: String) -> void:
	kind = k
	refresh_setup()
	var i := 0
	for b: StageButton in buttons.values():
		var tw := b.create_tween()
		tw.tween_property(b, "modulate:a", 0.0, 0.18).set_delay(i * 0.025)
		i += 1
	# bütün solma tweenleri bitsin; yoksa geç kalanlar düğmeleri görünmez bırakır
	await get_tree().create_timer(0.4).timeout
	menu_col.visible = false
	for b in buttons.values():
		b.modulate.a = 1.0
	_logo_away(true)
	setup_col.visible = true
	await get_tree().process_frame
	var j := 0
	for c in setup_col.get_children():
		if c is Control:
			Fx.anchor(c)
			Fx.rise(c, j * 0.035, Vector2(-30, 0), 0.45)
			j += 1
	_setup_title.play(0.05)
	_go.grab_focus()

func show_menu() -> void:
	if not setup_col.visible:
		return
	var from_settings := false
	setup_col.visible = false
	menu_col.visible = true
	_logo_away(false)
	var i := 0
	for id in MENU_ORDER:
		buttons[id].intro(i * 0.04)
		i += 1
	buttons["settings" if from_settings else kind_button()].grab_focus()

func kind_button() -> String:
	return kind if kind in ["conquest", "mayhem"] else "trivia"

## Kurulumda logo yukarı süzülüp söner; kurulum paneli onun yerine çıkar.
func _logo_away(away: bool) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(logo, "modulate:a", 0.0 if away else 1.0, 0.3)
	tw.tween_property(logo, "position:y", 18.0 if away else 58.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func is_setup() -> bool:
	return setup_col.visible

## Lobi süslerini göster/gizle (oyun başlarken sola kayar)
func set_shown(on: bool) -> void:
	if on == shown:
		return
	shown = on
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "position:x", 0.0 if on else -1000.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT if on else Tween.EASE_IN)
	tw.tween_property(self, "modulate:a", 1.0 if on else 0.0, 0.5)
	if on:
		show_menu()
		intro()
