class_name SettingsScreen
extends Control
## Ayarlar: ortada tek pano, solda sekmeler (Ses · Görüntü · Oynanış ·
## Kontroller · Hakkında), sağda satırlar. Her satır: etiket + kontrol; odaktaki
## satır parlar ve panonun altında ne işe yaradığı yazar.
## Klavye/gamepad: yukarı/aşağı satır, sol/sağ değer, Q/E ya da LB/RB sekme,
## Esc/B geri. Lobiden ve duraklatma menüsünden açılır.

signal closed
signal hints_changed

const PW := 1280.0
const PH := 780.0
const TABS := ["sound", "video", "game", "controls", "about"]

var tab := 0
var _k := 0.0
var _panel: Control
var _tab_btns: Array[Button] = []
var _pages := {}                 # sekme -> VBoxContainer
var _desc := ""
var _rows := {}                  # ayar anahtarı -> {row, label, ctrl, desc}
var _reset_armed := false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_panel = Control.new()
	_panel.position = Vector2((1920 - PW) * 0.5, (1080 - PH) * 0.5 + 20)
	_panel.size = Vector2(PW, PH)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_panel.draw.connect(_draw_panel)
	var tabs := VBoxContainer.new()
	tabs.position = Vector2(30, 150)
	tabs.size = Vector2(250, 460)
	tabs.add_theme_constant_override("separation", 6)
	_panel.add_child(tabs)
	for i in TABS.size():
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_ALL
		b.custom_minimum_size = Vector2(250, 58)
		for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		b.pressed.connect(func(): _set_tab(i))
		b.focus_entered.connect(func(): _set_tab(i))
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.draw.connect(_draw_tab.bind(b, i))
		tabs.add_child(b)
		_tab_btns.append(b)
	for t in TABS:
		var page := VBoxContainer.new()
		page.position = Vector2(320, 150)
		page.size = Vector2(PW - 360, 520)
		page.add_theme_constant_override("separation", 10)
		page.visible = false
		_panel.add_child(page)
		_pages[t] = page
	_build_sound()
	_build_video()
	_build_game()
	_build_controls()
	_build_about()
	var back := CtaButton.new()
	back.style = "ghost"
	back.custom_minimum_size = Vector2(200, 62)
	back.font_size = 26
	back.position = Vector2(40, PH - 96)
	back.pressed.connect(close)
	back.name = "Back"
	_panel.add_child(back)

# ── satır yapıcıları ───────────────────────────────────────────────
func _row(page: String, key: String, ctrl: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.custom_minimum_size.y = 58
	var lab := Label.new()
	lab.add_theme_font_override("font", Pal.display_bold())
	lab.add_theme_font_size_override("font_size", 28)
	lab.add_theme_color_override("font_color", Pal.CREAM)
	lab.custom_minimum_size = Vector2(300, 0)
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lab)
	ctrl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ctrl)
	_pages[page].add_child(row)
	_rows[key] = {"row": row, "label": lab, "ctrl": ctrl}
	ctrl.focus_entered.connect(func():
		_desc = Pal.t("set.%s.d" % key)
		_panel.queue_redraw())
	ctrl.mouse_entered.connect(func():
		_desc = Pal.t("set.%s.d" % key)
		_panel.queue_redraw())

func _slider(page: String, key: String, def: float) -> void:
	var sl := BrassSlider.new()
	sl.value = float(Profile.setting(key, def))
	sl.changed.connect(func(v):
		Profile.set_setting(key, v)
		GameSettings.apply_audio(get_tree())
		if key == "voice_vol":
			Narrator.say("applause"))
	_row(page, key, sl)

func _seg(page: String, key: String, opts: Array, width := 420.0) -> Segmented:
	var sg := Segmented.new()
	sg.custom_minimum_size = Vector2(width, 52)
	sg.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	sg.set_meta("opts", opts)
	sg.changed.connect(func(i): _apply_seg(key, i))
	_row(page, key, sg)
	return sg

func _build_sound() -> void:
	_slider("sound", "master_vol", 1.0)
	_slider("sound", "music_vol", 0.7)
	_slider("sound", "sfx_vol", 0.9)
	_slider("sound", "voice_vol", 0.9)
	_seg("sound", "narrator", ["set.on", "set.off"], 300)

func _build_video() -> void:
	_seg("video", "window", ["set.windowed", "set.borderless", "set.full"], 560)
	_seg("video", "quality", ["set.q.low", "set.q.medium", "set.q.high"])
	_seg("video", "vsync", ["set.on", "set.off"], 300)
	_seg("video", "fps", ["30", "60", "120", "set.unlimited"], 520)
	_seg("video", "shake", ["set.on", "set.off"], 300)
	_seg("video", "grain", ["set.on", "set.off"], 300)

func _build_game() -> void:
	_seg("game", "lang", ["Türkçe", "English"], 360)
	_seg("game", "hints", ["set.on", "set.off"], 300)
	var reset := CtaButton.new()
	reset.style = "velvet"
	reset.custom_minimum_size = Vector2(300, 52)
	reset.font_size = 22
	reset.pressed.connect(_reset_pressed)
	_row("game", "reset", reset)

func _build_controls() -> void:
	var page: VBoxContainer = _pages["controls"]
	for key in ["kb1", "kb2", "pad", "phone"]:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		var lab := Label.new()
		lab.add_theme_font_override("font", Pal.kicker())
		lab.add_theme_font_size_override("font_size", 18)
		lab.add_theme_color_override("font_color", Pal.GOLD)
		lab.name = "Title"
		box.add_child(lab)
		var kh := KeyHint.new()
		kh.font_size = 20
		kh.custom_minimum_size = Vector2(880, 40)
		kh.name = "Keys"
		box.add_child(kh)
		page.add_child(box)
		_rows["ctl_" + key] = {"row": box, "label": lab, "ctrl": kh}

func _build_about() -> void:
	var page: VBoxContainer = _pages["about"]
	var lab := RichTextLabel.new()
	lab.bbcode_enabled = true
	lab.fit_content = true
	lab.custom_minimum_size = Vector2(880, 440)
	lab.add_theme_font_override("normal_font", Pal.serif())
	lab.add_theme_font_override("italics_font", Pal.italic())
	lab.add_theme_font_override("bold_font", Pal.display_bold())
	lab.add_theme_font_size_override("normal_font_size", 22)
	lab.add_theme_font_size_override("bold_font_size", 28)
	lab.add_theme_font_size_override("italics_font_size", 20)
	lab.add_theme_color_override("default_color", Pal.CREAM)
	lab.name = "About"
	lab.custom_minimum_size = Vector2(880, 330)
	page.add_child(lab)
	_rows["about"] = {"row": lab, "label": null, "ctrl": lab}
	var rrow := HBoxContainer.new()
	rrow.add_theme_constant_override("separation", 14)
	for k in ["copy", "folder"]:
		var b := CtaButton.new()
		b.style = "velvet"
		b.custom_minimum_size = Vector2(300, 52)
		b.font_size = 21
		b.name = "Rep_" + k
		b.pressed.connect(func():
			if k == "copy":
				ErrorReporter.copy_to_clipboard()
				b.label = Pal.t("set.report.copied")
			else:
				ErrorReporter.open_folder())
		b.focus_entered.connect(func():
			_desc = Pal.t("set.report.d")
			_panel.queue_redraw())
		rrow.add_child(b)
	page.add_child(rrow)
	_rows["report"] = {"row": rrow, "label": null, "ctrl": rrow}

# ── uygulama ────────────────────────────────────────────────────────
func _apply_seg(key: String, i: int) -> void:
	match key:
		"narrator":
			Profile.set_setting("narrator", i == 0)
			if i == 0:
				Narrator.say("welcome")
		"window":
			Profile.set_setting("window", ["windowed", "borderless", "fullscreen"][i])
			GameSettings.apply_window()
		"quality":
			Profile.set_setting("quality", GameSettings.QUALITY[i])
			GameSettings.apply_quality(get_tree())
		"vsync":
			Profile.set_setting("vsync", i == 0)
			GameSettings.apply_window()
		"fps":
			Profile.set_setting("fps", [30, 60, 120, 0][i])
			GameSettings.apply_window()
		"shake":
			Profile.set_setting("shake", i == 0)
		"grain":
			Profile.set_setting("grain", i == 0)
			GameSettings.apply_grain(get_tree())
		"lang":
			I18n.set_lang(["tr", "en"][i])
			Profile.data.lang = I18n.lang
			Profile.save()
			retext()
		"hints":
			Profile.set_setting("hints", i == 0)
			hints_changed.emit()

func _reset_pressed() -> void:
	var b: CtaButton = _rows.reset.ctrl
	if not _reset_armed:
		_reset_armed = true
		b.label = Pal.t("set.reset.sure")
		get_tree().create_timer(3.0).timeout.connect(func():
			_reset_armed = false
			if is_instance_valid(b):
				b.label = Pal.t("set.reset.btn"))
		return
	_reset_armed = false
	Profile.reset_stats()
	b.label = Pal.t("set.reset.done")

func _sel_of(key: String) -> int:
	match key:
		"narrator": return 0 if bool(Profile.setting("narrator", true)) else 1
		"window": return maxi(0, ["windowed", "borderless", "fullscreen"].find(GameSettings.window_mode()))
		"quality": return maxi(0, GameSettings.QUALITY.find(String(Profile.setting("quality", "high"))))
		"vsync": return 0 if bool(Profile.setting("vsync", true)) else 1
		"fps": return maxi(0, [30, 60, 120, 0].find(int(Profile.setting("fps", 0))))
		"shake": return 0 if bool(Profile.setting("shake", true)) else 1
		"grain": return 0 if bool(Profile.setting("grain", true)) else 1
		"lang": return 1 if I18n.lang == "en" else 0
		"hints": return 0 if bool(Profile.setting("hints", true)) else 1
	return 0

func retext() -> void:
	var tabs_txt := ["set.tab.sound", "set.tab.video", "set.tab.game", "set.tab.controls", "set.tab.about"]
	for i in _tab_btns.size():
		_tab_btns[i].set_meta("txt", Pal.t(tabs_txt[i]))
		_tab_btns[i].queue_redraw()
	for key in _rows:
		var r: Dictionary = _rows[key]
		if key.begins_with("ctl_") or key == "about" or key == "report":
			continue
		(r.label as Label).text = Pal.t("set." + key)
		if r.ctrl is Segmented:
			var opts: Array = r.ctrl.get_meta("opts")
			var o := PackedStringArray()
			for s in opts:
				o.append(Pal.t(s) if String(s).begins_with("set.") else String(s))
			r.ctrl.options = o
			r.ctrl.selected = _sel_of(key)
		elif r.ctrl is BrassSlider:
			var defs := {"master_vol": 1.0, "music_vol": 0.7, "sfx_vol": 0.9, "voice_vol": 0.9}
			r.ctrl.value = float(Profile.setting(key, defs.get(key, 1.0)))
	(_rows.reset.ctrl as CtaButton).label = Pal.t("set.reset.btn")
	var ctl := {
		"kb1": ["WASD|" + Pal.t("hint.run"), Pal.t("key.space") + "|" + Pal.t("hint.jump"), "F|" + Pal.t("hint.shove"), "0–9|" + Pal.t("set.ctl.type"), "ESC|" + Pal.t("set.ctl.pause")],
		"kb2": [Pal.t("key.arrows") + "|" + Pal.t("hint.run"), "ENTER|" + Pal.t("hint.jump"), "SHIFT|" + Pal.t("hint.shove")],
		"pad": ["L|" + Pal.t("hint.run"), "A|" + Pal.t("hint.jump"), "X|" + Pal.t("hint.shove"), "START|" + Pal.t("set.ctl.pause"), "LB/RB|" + Pal.t("set.ctl.tabs")],
		"phone": ["QR|" + Pal.t("set.ctl.join"), "123|" + Pal.t("set.ctl.numpad"), "ABCD|" + Pal.t("set.ctl.answers")],
	}
	for key in ctl:
		var r: Dictionary = _rows["ctl_" + key]
		(r.label as Label).text = Pal.upper(Pal.t("set.ctl." + key))
		(r.ctrl as KeyHint).items = PackedStringArray(ctl[key])
	var about: RichTextLabel = _rows.about.ctrl
	about.text = "[b]TRIVIA ARENA: THE GRAND STAGE[/b]\n[i]%s %s[/i]\n\n%s" % [Pal.t("set.version"), ProjectSettings.get_setting("application/config/version", "0"), Pal.t("set.credits")]
	(_panel.get_node("Back") as CtaButton).label = Pal.t("common.back")
	var rr: HBoxContainer = _rows.report.row
	(rr.get_node("Rep_copy") as CtaButton).label = Pal.t("set.report.copy")
	(rr.get_node("Rep_folder") as CtaButton).label = Pal.t("set.report.folder")

# ── açılış / kapanış / gezinme ─────────────────────────────────────
func open(start_tab := 0) -> void:
	retext()
	visible = true
	_k = 0.0
	create_tween().tween_property(self, "_k", 1.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	Pal.sfx("page", -2.0)
	_set_tab(start_tab)
	_tab_btns[start_tab].grab_focus()

func close() -> void:
	if not visible:
		return
	Pal.sfx("ui_back", -3.0)
	var tw := create_tween()
	tw.tween_property(self, "_k", 0.0, 0.22)
	tw.tween_callback(func():
		visible = false
		closed.emit())

func _set_tab(i: int) -> void:
	if i == tab and _pages[TABS[i]].visible:
		return
	tab = i
	for j in TABS.size():
		var pg: Control = _pages[TABS[j]]
		pg.visible = j == i
	var page: Control = _pages[TABS[i]]
	page.modulate.a = 0.0
	page.position.x = 340
	var tw := page.create_tween().set_parallel(true)
	tw.tween_property(page, "modulate:a", 1.0, 0.22)
	tw.tween_property(page, "position:x", 320.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_desc = Pal.t("set.tab.%s.d" % TABS[i])
	for b in _tab_btns:
		b.queue_redraw()
	_panel.queue_redraw()
	Pal.sfx("ui_hover", -8.0, 0.9 + i * 0.04)
	# sekme düğmesinden sağa geçince ilk satıra odaklan
	var first := _first_focusable(page)
	for b in _tab_btns:
		b.focus_neighbor_right = b.get_path_to(first) if first else NodePath()

func _first_focusable(n: Node) -> Control:
	for c in n.get_children():
		if c is Control and (c as Control).focus_mode == Control.FOCUS_ALL and c.visible:
			return c
		var f := _first_focusable(c)
		if f:
			return f
	return null

func _unhandled_input(e: InputEvent) -> void:
	if not visible:
		return
	var prev: bool = (e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_Q) or (e is InputEventJoypadButton and e.pressed and e.button_index == JOY_BUTTON_LEFT_SHOULDER)
	var nxt: bool = (e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_E) or (e is InputEventJoypadButton and e.pressed and e.button_index == JOY_BUTTON_RIGHT_SHOULDER)
	if prev or nxt:
		_set_tab(wrapi(tab + (1 if nxt else -1), 0, TABS.size()))
		_tab_btns[tab].grab_focus()
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("ui_cancel") or (e is InputEventJoypadButton and e.pressed and e.button_index == JOY_BUTTON_B):
		close()
		get_viewport().set_input_as_handled()

func _process(_d: float) -> void:
	if visible:
		queue_redraw()
		_panel.queue_redraw()

# ── çizim ───────────────────────────────────────────────────────────
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1920, 1080)), Color(0.02, 0.0, 0.01, 0.7 * _k))

func _draw_panel() -> void:
	var k := _k
	var off := (1.0 - k) * 30.0
	var r := Rect2(0, off, PW, PH)
	var pts := Icons.notched(r, 26)
	_panel.draw_colored_polygon(Icons.notched(Rect2(r.position + Vector2(12, 16), r.size), 26), Color(0, 0, 0, 0.5 * k))
	_panel.draw_colored_polygon(pts, Color(0.075, 0.025, 0.032, 0.97 * k))
	Icons.outline(_panel, pts, Color(Pal.GOLD, 0.55 * k), 2.0)
	_panel.draw_rect(Rect2(26, off, PW - 52, 6), Color(Pal.VELVET_HI, k))
	# sekme sütununu ayıran ince çizgi
	_panel.draw_line(Vector2(296, 150 + off), Vector2(296, PH - 130 + off), Color(Pal.BRASS, 0.3 * k), 1.0)
	var kf := Pal.kicker()
	var ks := Pal.upper(Pal.t("settings.kicker"))
	var x := 44.0
	for i in ks.length():
		_panel.draw_string(kf, Vector2(x, 50 + off), ks.substr(i, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(Pal.GOLD, k))
		x += kf.get_char_size(ks.unicode_at(i), 18).x + 4
	_panel.draw_string(Pal.display(), Vector2(40, 132 + off), Pal.upper(Pal.t("menu.settings")), HORIZONTAL_ALIGNMENT_LEFT, -1, 78, Color(Pal.CHAMPAGNE, k))
	# alt bilgi şeridi: odaktaki ayarın açıklaması
	var dy := PH - 70 + off
	_panel.draw_rect(Rect2(296, dy - 36, PW - 330, 58), Color(0, 0, 0, 0.25 * k))
	_panel.draw_string(Pal.italic(), Vector2(320, dy), _desc, HORIZONTAL_ALIGNMENT_LEFT, PW - 380, 21, Color(Pal.CREAM, 0.85 * k))
	var hint := Pal.t("set.nav")
	var hw := Pal.italic().get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	_panel.draw_string(Pal.italic(), Vector2(PW - hw - 40, 60 + off), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(Pal.CREAM, 0.5 * k))

func _draw_tab(b: Button, i: int) -> void:
	var on := i == tab
	var foc := b.has_focus()
	var sz := b.size
	if on:
		b.draw_colored_polygon(PackedVector2Array([Vector2(0, 4), Vector2(sz.x - 14, 4), Vector2(sz.x, sz.y * 0.5), Vector2(sz.x - 14, sz.y - 4), Vector2(0, sz.y - 4)]), Color(Pal.VELVET_HI, 0.85))
		b.draw_rect(Rect2(0, 4, 5, sz.y - 8), Pal.GOLD)
	elif foc or b.is_hovered():
		b.draw_rect(Rect2(0, 4, sz.x - 14, sz.y - 8), Color(Pal.VELVET_HI, 0.25))
	var icons := ["speaker", "screen", "gear", "pad", "scroll"]
	Icons.draw(b, icons[i], Vector2(28, sz.y * 0.5), 26, Pal.CHAMPAGNE if on else Color(Pal.CREAM, 0.6))
	var txt := String(b.get_meta("txt", ""))
	b.draw_string(Pal.display_bold(), Vector2(56, sz.y * 0.5 + 10), Pal.upper(txt), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Pal.CHAMPAGNE if on else Color(Pal.CREAM, 0.7))
	if foc:
		Icons.outline(b, Icons.notched(Rect2(Vector2.ZERO, sz).grow(1), 6), Color(Pal.GOLD, 0.6), 1.0)
