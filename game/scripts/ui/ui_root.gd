extends CanvasLayer
## Arayüzün kökü. Sol pano (ekranın ~%24'ü, yarı saydam ahşap), sağ üstte
## bilet-profil, mod kurulumu, kostüm odası, afiş rehber, loca paneli ve
## Trivia HUD'u. Oyun mantığı main.gd'de; burası yalnızca gösterir ve çağırır.

const LEFT_W := 470.0

var game: Node = null
var root: Control
var left: UIKit.WoodPanel
var marquee: UIKit.Marquee
var menu_box: VBoxContainer
var setup_box: VBoxContainer
var ticket: UIKit.Ticket
var wardrobe: UIKit.WoodPanel
var poster: UIKit.Poster
var loge_bar: UIKit.WoodPanel
var hint: Label
var hud_top: UIKit.Banner
var hud_msg: UIKit.Banner
var hud_timer: Control
var result_panel: UIKit.WoodPanel
var rename_panel: UIKit.WoodPanel
var house_card: UIKit.WoodPanel
var _qr_rect: TextureRect
var _house_code: Label
var _house_url: Label
var _house_list: Label
var _house_status: Label
var _house_edit: LineEdit
var _qr_http: HTTPRequest
var _qr_for := ""
var name_edit: LineEdit

var _plaques := {}
var _texts: Array = []            # [node, key, prop] dil değişince yenilenir
var _bot_value: Label
var _level_knobs := {}
var _timer_knobs := {}
var _ward_rows := {}
var _left_x := 22.0
var _timer_left := 0.0
var _timer_total := 1.0

func setup(p_game: Node) -> void:
	game = p_game
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var th := Theme.new()
	th.default_font = UIKit.serif(600)
	th.default_font_size = 22
	th.set_color("font_color", "Label", UIKit.CREAM)
	root.theme = th
	_build_left()
	_build_ticket()
	_build_wardrobe()
	_build_poster()
	_build_loge_bar()
	_build_hud()
	_build_result()
	_build_rename()
	_build_house()
	_build_hint()
	I18n.changed.connect(func(_l): _retext())
	Profile.changed.connect(_refresh_ticket)
	_retext()
	_refresh_ticket()

# ── yardımcılar ─────────────────────────────────────────────────────
func _label(txt: String, size := 22, col := UIKit.CREAM, font: Font = null) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if font:
		l.add_theme_font_override("font", font)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _tr(node: Object, key: String, prop := "text") -> void:
	_texts.append([node, key, prop])

func _retext() -> void:
	for row in _texts:
		if is_instance_valid(row[0]):
			row[0].set(row[2], I18n.t(row[1]))
			if row[0] is CanvasItem:
				row[0].queue_redraw()
	marquee.tagline = I18n.t("title.tagline")
	if _plaques.has("conquest"):
		_plaques.conquest.stamp = I18n.t("common.soon")
	_refresh_ticket()
	_refresh_setup()
	_refresh_wardrobe()
	if poster.visible:
		_fill_poster(poster.get_meta("mode", "trivia"))

func _slide(c: Control, prop: String, to: float, dur := 0.45) -> void:
	var tw := create_tween()
	tw.tween_property(c, prop, to, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

# ── sol pano ────────────────────────────────────────────────────────
func _build_left() -> void:
	left = UIKit.WoodPanel.new()
	left.position = Vector2(_left_x, 22)
	left.size = Vector2(LEFT_W, 1036)
	left.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(left)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right"]:
		m.add_theme_constant_override("margin_" + s, 26)
	m.add_theme_constant_override("margin_top", 30)
	m.add_theme_constant_override("margin_bottom", 26)
	left.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	m.add_child(v)
	marquee = UIKit.Marquee.new()
	marquee.custom_minimum_size = Vector2(0, 228)
	v.add_child(marquee)

	menu_box = VBoxContainer.new()
	menu_box.add_theme_constant_override("separation", 12)
	v.add_child(menu_box)
	_add_plaque(menu_box, "trivia", "menu.trivia", "menu.trivia.sub", true, "?", _on_trivia)
	_add_plaque(menu_box, "conquest", "menu.conquest", "menu.conquest.sub", true, "#", _on_conquest)
	menu_box.add_child(_rule())
	_add_plaque(menu_box, "house", "menu.house", "menu.house.sub", false, "", _on_house)
	_add_plaque(menu_box, "customize", "menu.customize", "menu.customize.sub", false, "", _on_customize)
	_add_plaque(menu_box, "spectate", "menu.spectate", "menu.spectate.sub", false, "", _on_spectate)
	_add_plaque(menu_box, "howto", "menu.howto", "menu.howto.sub", false, "", _on_howto)

	setup_box = VBoxContainer.new()
	setup_box.add_theme_constant_override("separation", 12)
	setup_box.visible = false
	v.add_child(setup_box)
	_build_setup(setup_box)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	var foot := _label("", 16, Color(UIKit.CREAM, 0.7), UIKit.serif(500, true))
	_tr(foot, "lobby.controls")
	v.add_child(foot)
	var foot2 := _label("", 16, Color(UIKit.CREAM, 0.55), UIKit.serif(500, true))
	_tr(foot2, "lobby.controls2")
	v.add_child(foot2)

func _rule() -> Control:
	var c := ColorRect.new()
	c.color = Color(UIKit.BRASS, 0.5)
	c.custom_minimum_size = Vector2(0, 2)
	return c

func _add_plaque(parent: Container, id: String, key: String, sub_key: String, big: bool, glyph: String, cb: Callable) -> UIKit.Plaque:
	var p := UIKit.Plaque.new("", "", big)
	p.glyph = glyph
	p.custom_minimum_size.y = 92.0 if big else 68.0
	p.pressed.connect(cb)
	parent.add_child(p)
	_tr(p, key, "title")
	if sub_key != "":
		_tr(p, sub_key, "subtitle")
	_plaques[id] = p
	return p

# ── mod kurulumu ────────────────────────────────────────────────────
func _build_setup(v: VBoxContainer) -> void:
	var t := _label("", 30, UIKit.GOLD, UIKit.display())
	_tr(t, "setup.title")
	v.add_child(t)
	v.add_child(_rule())
	# bot sayısı
	var bl := _label("", 20, UIKit.CREAM, UIKit.serif(700))
	_tr(bl, "setup.bots")
	v.add_child(bl)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var minus := UIKit.Knob.new("−")
	var plus := UIKit.Knob.new("+")
	_bot_value = _label("3", 30, UIKit.GOLD, UIKit.display())
	_bot_value.custom_minimum_size = Vector2(70, 0)
	_bot_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	minus.pressed.connect(func(): _set_bots(int(Profile.setting("bots", 3)) - 1))
	plus.pressed.connect(func(): _set_bots(int(Profile.setting("bots", 3)) + 1))
	row.add_child(minus)
	row.add_child(_bot_value)
	row.add_child(plus)
	v.add_child(row)
	# zorluk
	var ll := _label("", 20, UIKit.CREAM, UIKit.serif(700))
	_tr(ll, "setup.level")
	v.add_child(ll)
	var lrow := HBoxContainer.new()
	lrow.add_theme_constant_override("separation", 8)
	for lv in ["easy", "normal", "hard"]:
		var k := UIKit.Knob.new("")
		k.custom_minimum_size = Vector2(128, 46)
		k.pressed.connect(func():
			Profile.set_setting("bot_level", lv)
			game.apply_bot_level()
			_refresh_setup())
		lrow.add_child(k)
		_level_knobs[lv] = k
		_tr(k, "setup.level." + lv, "label")
	v.add_child(lrow)
	# süre
	var tl := _label("", 20, UIKit.CREAM, UIKit.serif(700))
	_tr(tl, "setup.timer")
	v.add_child(tl)
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 8)
	for sec in [8, 10, 12]:
		var k2 := UIKit.Knob.new("")
		k2.custom_minimum_size = Vector2(128, 46)
		k2.pressed.connect(func():
			Profile.set_setting("timer", sec)
			_refresh_setup())
		trow.add_child(k2)
		_timer_knobs[sec] = k2
	v.add_child(trow)
	v.add_child(_rule())
	var go := UIKit.Plaque.new("", "", true)
	go.glyph = "!"
	go.pressed.connect(_on_start)
	_tr(go, "common.start", "title")
	v.add_child(go)
	var back := UIKit.Plaque.new("", "", false)
	back.custom_minimum_size.y = 56
	back.pressed.connect(func(): _show_setup(false))
	_tr(back, "common.back", "title")
	v.add_child(back)

func _set_bots(n: int) -> void:
	var cap: int = 8 - game.players.size()
	n = clampi(n, 0 if game.players.size() > 1 else 1, cap)
	Profile.set_setting("bots", n)
	game.set_bot_count(n)
	_refresh_setup()

func _refresh_setup() -> void:
	if _bot_value == null:
		return
	_bot_value.text = str(Profile.setting("bots", 3))
	var lv := String(Profile.setting("bot_level", "normal"))
	for k in _level_knobs:
		_level_knobs[k].on = k == lv
		_level_knobs[k].queue_redraw()
	var sec := int(Profile.setting("timer", 10))
	for k in _timer_knobs:
		_timer_knobs[k].label = I18n.t("setup.seconds", {"n": k})
		_timer_knobs[k].on = k == sec
		_timer_knobs[k].queue_redraw()

func _show_setup(on: bool) -> void:
	menu_box.visible = not on
	setup_box.visible = on
	_refresh_setup()

# ── bilet ───────────────────────────────────────────────────────────
func _build_ticket() -> void:
	ticket = UIKit.Ticket.new()
	ticket.size = Vector2(440, 238)
	ticket.position = Vector2(1920 - 440 - 28, 26)
	root.add_child(ticket)
	ticket.lang_toggled.connect(func():
		I18n.toggle()
		Profile.data.lang = I18n.lang
		Profile.save())
	ticket.rename_requested.connect(_open_rename)

func _refresh_ticket() -> void:
	if ticket == null:
		return
	var n := Profile.player_name()
	var r := Profile.record(n)
	ticket.player_name = n
	ticket.wl = "%d / %d" % [r.wins, r.losses]
	ticket.champs = r.champs
	ticket.streak = r.streak
	ticket.best = r.best
	ticket.lang = I18n.lang
	ticket.avatar_color = PlushVisual.COLORS.get(String(Profile.look().get("color", "mustard")), Color("F2C230"))
	ticket.queue_redraw()

func _build_rename() -> void:
	rename_panel = UIKit.WoodPanel.new()
	rename_panel.size = Vector2(440, 170)
	rename_panel.position = Vector2(1920 - 440 - 28, 280)
	rename_panel.visible = false
	root.add_child(rename_panel)
	var v := VBoxContainer.new()
	v.position = Vector2(26, 22)
	v.size = Vector2(388, 130)
	v.add_theme_constant_override("separation", 10)
	rename_panel.add_child(v)
	var l := _label("", 20, UIKit.GOLD, UIKit.serif(800))
	_tr(l, "wardrobe.name")
	v.add_child(l)
	name_edit = LineEdit.new()
	name_edit.max_length = 14
	name_edit.add_theme_font_size_override("font_size", 24)
	name_edit.text_submitted.connect(func(_t): _close_rename(true))
	v.add_child(name_edit)
	var ok := UIKit.Knob.new("")
	ok.custom_minimum_size = Vector2(140, 42)
	_tr(ok, "common.done", "label")
	ok.pressed.connect(func(): _close_rename(true))
	v.add_child(ok)

func _open_rename() -> void:
	name_edit.text = Profile.player_name()
	rename_panel.visible = true
	name_edit.grab_focus()
	name_edit.select_all()

func _close_rename(save: bool) -> void:
	if save:
		var old := Profile.player_name()
		Profile.set_player_name(name_edit.text)
		game.rename_player_one(old, Profile.player_name())
	name_edit.release_focus()
	rename_panel.visible = false

# ── kostüm odası ────────────────────────────────────────────────────
func _build_wardrobe() -> void:
	wardrobe = UIKit.WoodPanel.new()
	wardrobe.size = Vector2(500, 620)
	wardrobe.position = Vector2(1920 + 20, 230)
	wardrobe.visible = false
	root.add_child(wardrobe)
	var v := VBoxContainer.new()
	v.position = Vector2(30, 30)
	v.size = Vector2(440, 560)
	v.add_theme_constant_override("separation", 14)
	wardrobe.add_child(v)
	var t := _label("", 34, UIKit.GOLD, UIKit.display())
	_tr(t, "wardrobe.title")
	v.add_child(t)
	v.add_child(_rule())
	# kumaş renkleri
	var cl := _label("", 20, UIKit.CREAM, UIKit.serif(700))
	_tr(cl, "wardrobe.color")
	v.add_child(cl)
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 8)
	for key in PlushVisual.COLOR_KEYS:
		var sw := Button.new()
		sw.flat = true
		sw.focus_mode = Control.FOCUS_NONE
		sw.custom_minimum_size = Vector2(46, 46)
		sw.tooltip_text = I18n.t("color." + key)
		sw.draw.connect(func():
			var c: Color = PlushVisual.COLORS[key]
			sw.draw_rect(Rect2(Vector2.ZERO, sw.size), UIKit.BRASS_LO)
			sw.draw_rect(Rect2(Vector2(4, 4), sw.size - Vector2(8, 8)), c)
			if String(Profile.look().get("color", "")) == key:
				sw.draw_rect(Rect2(Vector2.ZERO, sw.size), UIKit.GOLD, false, 4.0))
		sw.pressed.connect(func():
			Sfx.play("click", -4.0, 1.3)
			_set_look("color", key))
		grid.add_child(sw)
	v.add_child(grid)
	for cat in [["hat", PlushVisual.HATS], ["mustache", PlushVisual.MUSTACHES], ["bowtie", PlushVisual.BOWTIES]]:
		var key: String = cat[0]
		var opts: Array = cat[1]
		var lab := _label("", 20, UIKit.CREAM, UIKit.serif(700))
		_tr(lab, "wardrobe." + key)
		v.add_child(lab)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var prev := UIKit.Knob.new("◀")
		var nxt := UIKit.Knob.new("▶")
		var val := _label("", 26, UIKit.GOLD, UIKit.serif(800))
		val.custom_minimum_size = Vector2(290, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prev.pressed.connect(func(): _cycle(key, opts, -1))
		nxt.pressed.connect(func(): _cycle(key, opts, 1))
		row.add_child(prev)
		row.add_child(val)
		row.add_child(nxt)
		v.add_child(row)
		_ward_rows[key] = val
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sp)
	var done := UIKit.Plaque.new("", "", false)
	done.custom_minimum_size.y = 62
	_tr(done, "common.done", "title")
	done.pressed.connect(_close_wardrobe)
	v.add_child(done)

func _cycle(key: String, opts: Array, dir: int) -> void:
	var cur := opts.find(String(Profile.look().get(key, "none")))
	var nxt: String = opts[(cur + dir + opts.size()) % opts.size()]
	_set_look(key, nxt)

func _set_look(key: String, val: String) -> void:
	Profile.set_look(key, val)
	game.apply_look_to_player_one()
	_refresh_wardrobe()

func _refresh_wardrobe() -> void:
	for key in _ward_rows:
		var v := String(Profile.look().get(key, "none"))
		_ward_rows[key].text = I18n.t("look." + v)
	if wardrobe:
		for c in wardrobe.get_children():
			c.queue_redraw()
		wardrobe.propagate_call("queue_redraw")

# ── afiş ────────────────────────────────────────────────────────────
func _build_poster() -> void:
	poster = UIKit.Poster.new()
	poster.size = Vector2(760, 900)
	poster.position = Vector2((1920 - 760) * 0.5 + 180, -1000)
	poster.visible = false
	root.add_child(poster)
	poster.closed.connect(_close_howto)

func _fill_poster(mode: String) -> void:
	poster.set_meta("mode", mode)
	poster.head = I18n.t("howto.head")
	poster.title = I18n.t("menu.conquest") if mode == "conquest" else I18n.t("menu.trivia")
	if mode == "conquest":
		poster.lines = [I18n.t("howto.c1"), I18n.t("howto.c2"), I18n.t("howto.t5")]
	else:
		poster.lines = [I18n.t("howto.t1"), I18n.t("howto.t2"), I18n.t("howto.t3"), I18n.t("howto.t4"), I18n.t("howto.t5")]
	poster.foot = I18n.t("howto.keys")
	poster.queue_redraw()

func open_howto(mode := "trivia") -> void:
	_fill_poster(mode)
	poster.visible = true
	poster.drop()
	poster.position.y = -1000
	Sfx.play("whoosh", -6.0, 0.7)
	var tw := create_tween()
	tw.tween_property(poster, "position:y", 70.0, 0.9).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func _close_howto() -> void:
	var tw := create_tween()
	tw.tween_property(poster, "position:y", -1000.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): poster.visible = false)

# ── loca ────────────────────────────────────────────────────────────
func _build_loge_bar() -> void:
	loge_bar = UIKit.WoodPanel.new()
	loge_bar.size = Vector2(900, 150)
	loge_bar.position = Vector2((1920 - 900) * 0.5, 1080 + 20)
	loge_bar.visible = false
	root.add_child(loge_bar)
	var v := VBoxContainer.new()
	v.position = Vector2(30, 20)
	v.size = Vector2(840, 110)
	loge_bar.add_child(v)
	var t := _label("", 20, UIKit.GOLD, UIKit.serif(800))
	_tr(t, "spectate.hint")
	v.add_child(t)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	for kind in ["rose", "tomato", "hat"]:
		var k := UIKit.Knob.new("")
		k.custom_minimum_size = Vector2(170, 52)
		_tr(k, "spectate." + kind, "label")
		k.pressed.connect(func(): game.throw_item(kind))
		row.add_child(k)
	var leave := UIKit.Knob.new("")
	leave.custom_minimum_size = Vector2(250, 52)
	_tr(leave, "spectate.leave", "label")
	leave.pressed.connect(_leave_loge)
	row.add_child(leave)

# ── alt ipucu ───────────────────────────────────────────────────────
func _build_hint() -> void:
	hint = _label("", 18, Color(UIKit.CREAM, 0.85), UIKit.serif(600, true))
	hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(LEFT_W + 60, 1030)
	hint.size = Vector2(1920 - LEFT_W - 120, 30)
	hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	hint.add_theme_constant_override("shadow_offset_y", 2)
	_tr(hint, "lobby.join")
	root.add_child(hint)

# ── Trivia HUD ──────────────────────────────────────────────────────
func _build_hud() -> void:
	hud_top = UIKit.Banner.new()
	hud_top.position = Vector2(0, 20)
	hud_top.size = Vector2(1920, 120)
	hud_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_top.visible = false
	root.add_child(hud_top)
	hud_msg = UIKit.Banner.new()
	hud_msg.position = Vector2(0, 880)
	hud_msg.size = Vector2(1920, 120)
	hud_msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_msg.visible = false
	root.add_child(hud_msg)
	hud_timer = Control.new()
	hud_timer.position = Vector2(1920 - 190, 26)
	hud_timer.size = Vector2(150, 150)
	hud_timer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_timer.visible = false
	hud_timer.draw.connect(_draw_timer)
	root.add_child(hud_timer)

func _draw_timer() -> void:
	var c := hud_timer.size * 0.5
	var k: float = clamp(_timer_left / max(_timer_total, 0.01), 0.0, 1.0)
	hud_timer.draw_circle(c + Vector2(4, 5), 66, Color(0, 0, 0, 0.5))
	hud_timer.draw_circle(c, 66, UIKit.BRASS_LO)
	hud_timer.draw_circle(c, 60, Color("1E0C08"))
	var col := UIKit.GOLD if k > 0.35 else Color("E0493A")
	hud_timer.draw_arc(c, 52, -PI / 2, -PI / 2 + TAU * k, 48, col, 9.0)
	var s := str(int(ceil(_timer_left)))
	hud_timer.draw_string(UIKit.display(), c + Vector2(-60, 22), s, HORIZONTAL_ALIGNMENT_CENTER, 120, 58, UIKit.CREAM)

func hud_show(on: bool) -> void:
	hud_top.visible = on
	hud_msg.visible = on
	hud_timer.visible = on

func hud_set_top(text: String, sub := "") -> void:
	hud_top.text = text
	hud_top.sub = sub
	hud_top.queue_redraw()

func hud_set_msg(text: String, accent := UIKit.GOLD, sub := "") -> void:
	hud_msg.text = text
	hud_msg.sub = sub
	hud_msg.accent = accent
	hud_msg.queue_redraw()

func hud_set_timer(left_s: float, total: float) -> void:
	_timer_left = left_s
	_timer_total = total
	hud_timer.visible = left_s > 0.0
	hud_timer.queue_redraw()

func _build_result() -> void:
	result_panel = UIKit.WoodPanel.new()
	result_panel.size = Vector2(640, 560)
	result_panel.position = Vector2(90, 230)
	result_panel.alpha = 0.92
	result_panel.visible = false
	root.add_child(result_panel)

func show_result(title: String, ranking: Array) -> void:
	for c in result_panel.get_children():
		c.queue_free()
	var v := VBoxContainer.new()
	v.position = Vector2(34, 30)
	v.size = Vector2(572, 500)
	v.add_theme_constant_override("separation", 10)
	result_panel.add_child(v)
	var t := _label(I18n.t("result.title"), 46, UIKit.GOLD, UIKit.display())
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sub := _label(title, 24, UIKit.CREAM, UIKit.serif(700, true))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	v.add_child(_rule())
	for i in min(ranking.size(), 6):
		var row := HBoxContainer.new()
		var n := _label(I18n.t("result.place", {"n": i + 1}), 28, UIKit.GOLD if i == 0 else UIKit.CREAM, UIKit.display())
		n.custom_minimum_size = Vector2(70, 0)
		row.add_child(n)
		var nm := _label(String(ranking[i]), 28, UIKit.CREAM, UIKit.serif(800))
		nm.autowrap_mode = TextServer.AUTOWRAP_OFF
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nm)
		var rec := Profile.record(String(ranking[i]))
		var st := _label("%s %d" % [I18n.t("ticket.streak"), rec.streak], 18, Color(UIKit.CREAM, 0.7), UIKit.serif(600, true))
		st.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(st)
		v.add_child(row)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sp)
	var again := UIKit.Plaque.new(I18n.t("arena.again"), "", false)
	again.custom_minimum_size.y = 60
	again.pressed.connect(func():
		result_panel.visible = false
		game.restart_arena())
	v.add_child(again)
	var back := UIKit.Plaque.new(I18n.t("arena.back"), "", false)
	back.custom_minimum_size.y = 60
	back.pressed.connect(func():
		result_panel.visible = false
		game.end_arena())
	v.add_child(back)
	result_panel.visible = true
	result_panel.modulate.a = 0.0
	create_tween().tween_property(result_panel, "modulate:a", 1.0, 0.4)

# ── ev partisi kartı ────────────────────────────────────────────────
func _build_house() -> void:
	house_card = UIKit.WoodPanel.new()
	house_card.size = Vector2(620, 420)
	house_card.position = Vector2(1920 + 20, 290)
	house_card.visible = false
	root.add_child(house_card)
	var t := _label("", 34, UIKit.GOLD, UIKit.display())
	_tr(t, "house.title")
	t.position = Vector2(30, 26)
	t.size = Vector2(560, 44)
	house_card.add_child(t)
	var frame := ColorRect.new()
	frame.color = UIKit.BRASS_LO
	frame.position = Vector2(28, 84)
	frame.size = Vector2(244, 244)
	house_card.add_child(frame)
	_qr_rect = TextureRect.new()
	_qr_rect.position = Vector2(34, 90)
	_qr_rect.size = Vector2(232, 232)
	_qr_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_qr_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_qr_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	house_card.add_child(_qr_rect)
	_house_code = _label("----", 76, UIKit.GOLD, UIKit.display())
	_house_code.autowrap_mode = TextServer.AUTOWRAP_OFF
	_house_code.position = Vector2(292, 78)
	_house_code.size = Vector2(300, 90)
	house_card.add_child(_house_code)
	var scan := _label("", 17, Color(UIKit.CREAM, 0.85), UIKit.serif(500, true))
	_tr(scan, "house.scan")
	scan.position = Vector2(294, 170)
	scan.size = Vector2(300, 70)
	house_card.add_child(scan)
	_house_url = _label("", 17, UIKit.GOLD, UIKit.serif(700))
	_house_url.position = Vector2(294, 240)
	_house_url.size = Vector2(300, 50)
	house_card.add_child(_house_url)
	_house_list = _label("", 18, UIKit.CREAM, UIKit.serif(700))
	_house_list.position = Vector2(294, 290)
	_house_list.size = Vector2(300, 60)
	house_card.add_child(_house_list)
	_house_status = _label("", 16, Color(1, 0.7, 0.55), UIKit.serif(500, true))
	_house_status.position = Vector2(30, 334)
	_house_status.size = Vector2(560, 26)
	house_card.add_child(_house_status)
	var row := HBoxContainer.new()
	row.position = Vector2(28, 362)
	row.size = Vector2(564, 44)
	row.add_theme_constant_override("separation", 8)
	house_card.add_child(row)
	_house_edit = LineEdit.new()
	_house_edit.custom_minimum_size = Vector2(300, 40)
	_house_edit.add_theme_font_size_override("font_size", 16)
	_house_edit.placeholder_text = "wss://…/ws"
	row.add_child(_house_edit)
	var go := UIKit.Knob.new("")
	go.custom_minimum_size = Vector2(120, 40)
	_tr(go, "house.connect", "label")
	go.pressed.connect(func(): game.start_house(_house_edit.text))
	row.add_child(go)
	var close := UIKit.Knob.new("")
	close.custom_minimum_size = Vector2(120, 40)
	_tr(close, "house.close", "label")
	close.pressed.connect(_close_house)
	row.add_child(close)
	_qr_http = HTTPRequest.new()
	add_child(_qr_http)
	_qr_http.request_completed.connect(_on_qr)

func _on_house() -> void:
	house_card.visible = true
	_house_edit.text = game.relay_url()
	_slide(house_card, "position:x", 1920 - 620 - 28.0)
	game.start_house()
	if not game.bridge.hosted.is_connected(_on_hosted):
		game.bridge.hosted.connect(_on_hosted)
		game.bridge.state_changed.connect(func(_s): refresh_house())
	refresh_house()

func _close_house() -> void:
	_slide(house_card, "position:x", 1920 + 20.0)
	game.stop_house()

func _on_hosted(_code: String) -> void:
	refresh_house()
	var u: String = game.bridge.qr_url()
	if u != _qr_for:
		_qr_for = u
		_qr_http.cancel_request()
		_qr_http.request(u)

func _on_qr(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var img := Image.new()
	if img.load_png_from_buffer(body) == OK:
		_qr_rect.texture = ImageTexture.create_from_image(img)

func refresh_house() -> void:
	if house_card == null or game == null or game.bridge == null:
		return
	var b: PhoneBridge = game.bridge
	_house_code.text = b.code if b.state == "live" else "····"
	_house_url.text = b.http_base().replace("https://", "").replace("http://", "") + "/pad"
	var n := 0
	var names: Array[String] = []
	for pid in game.phone_players:
		var p: Plush = game.phone_players[pid]
		if is_instance_valid(p):
			n += 1
			names.append(p.player_name)
	_house_list.text = I18n.t("house.phones", {"n": n}) + ("\n" + ", ".join(names) if n > 0 else "")
	_house_status.text = "" if b.state == "live" else I18n.t("house.connecting" if b.state == "connecting" else "house.error")

# ── akışlar ─────────────────────────────────────────────────────────
func _on_trivia() -> void:
	_show_setup(true)

func _on_conquest() -> void:
	if game.has_method("start_conquest"):
		game.start_conquest()

func _on_start() -> void:
	_show_setup(false)
	show_lobby_chrome(false)
	game.start_arena()

func _on_customize() -> void:
	_slide(left, "position:x", -LEFT_W + 60.0)
	_slide(ticket, "position:y", -300.0)
	hint.visible = false
	wardrobe.visible = true
	_refresh_wardrobe()
	_slide(wardrobe, "position:x", 1920 - 500 - 60.0, 0.55)
	game.enter_wardrobe()

func _close_wardrobe() -> void:
	_slide(left, "position:x", _left_x)
	_slide(ticket, "position:y", 26.0)
	_slide(wardrobe, "position:x", 1920 + 20.0)
	hint.visible = true
	game.exit_wardrobe()

func _on_spectate() -> void:
	show_lobby_chrome(false)
	loge_bar.visible = true
	_slide(loge_bar, "position:y", 1080 - 150 - 26.0)
	game.enter_loge()

func _leave_loge() -> void:
	_slide(loge_bar, "position:y", 1080 + 20.0)
	show_lobby_chrome(true)
	game.exit_loge()

func _on_howto() -> void:
	open_howto("trivia")

## Lobi süsleri (sol pano, bilet, ipucu) göster/gizle.
func show_lobby_chrome(on: bool) -> void:
	_slide(left, "position:x", _left_x if on else -LEFT_W - 40.0)
	if house_card and house_card.visible:
		_slide(house_card, "position:x", (1920 - 620 - 28.0) if on else 1920 + 20.0)
	_slide(ticket, "position:y", 26.0 if on else -300.0)
	hint.visible = on

## Ekran görüntüsü aracı için hazır sahneler
func prepare_shot(part: String) -> void:
	match part:
		"setup":
			_show_setup(true)
			await get_tree().create_timer(1.5).timeout
		"wardrobe":
			_on_customize()
			await get_tree().create_timer(2.5).timeout
		"howto":
			open_howto("trivia")
			await get_tree().create_timer(2.0).timeout
		"loge":
			_on_spectate()
			await get_tree().create_timer(2.5).timeout
			game.throw_item("rose")
			game.throw_item("tomato")
			await get_tree().create_timer(0.7).timeout
		"house":
			_on_house()
			await get_tree().create_timer(4.0).timeout
		"en":
			I18n.set_lang("en")
			await get_tree().create_timer(1.0).timeout
		_:
			if game.has_method("prepare_game_shot"):
				await game.prepare_game_shot(part)
			else:
				await get_tree().create_timer(1.0).timeout
