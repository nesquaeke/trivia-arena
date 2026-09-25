extends CanvasLayer
## Arayüzün kökü: lobi menüsü, profil kartı, yan paneller ve oyun içi HUD.
## Oyun mantığı main.gd'de; burası yalnızca gösterir ve yönlendirir.
##
## Parçalar (hepsi scripts/ui/ altında, her biri tek dosya):
##   screens/lobby_menu.gd      sol taraf: logo + menü + kurulum
##   components/profile_card.gd sağ üst: canlı pelüş portreli bilet
##   screens/wardrobe_panel.gd  kostüm odası
##   screens/house_card.gd      ev partisi (QR)
##   screens/loge_bar.gd        loca
##   screens/playbill.gd        nasıl oynanır afişi
##   hud/hud.gd                 oyun içi arayüz
## Renkler/yazı tipleri: scripts/ui/pal.gd, ui/fonts/*.tres, ui/theme/grand_stage.tres

signal reward_clicked(step: int, index: int)
signal answer_clicked(index: int)
signal ruler_input(u: float, release: bool)

var game: Node = null
var root: Control
var menu: LobbyMenu
var card: ProfileCard
var wardrobe: WardrobePanel
var house: HouseCard
var loge: LogeBar
var playbill: Playbill
var hud: Hud
var rename_panel: GlassPanel
var name_edit: LineEdit
var grain: ColorRect
var result_panel: Control          # ekran görüntüsü aracı için (hud.result)
var pause: PauseMenu
var settings: SettingsScreen
var online: OnlinePanel
var toast: AchievementToast

var _qr_http: HTTPRequest
var _qr_for := ""
var _lobby := true
var _card_tw: Tween

const CARD_X := 1920.0 - ProfileCard.W - 34.0

func setup(p_game: Node) -> void:
	game = p_game
	layer = 10
	# duraklatınca da menü çalışsın; oyun içi HUD oyunla birlikte durur
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = load("res://ui/theme/grand_stage.tres")
	add_child(root)

	hud = Hud.new()
	hud.reward_clicked.connect(func(s, i): reward_clicked.emit(s, i))
	hud.answer_clicked.connect(func(i): answer_clicked.emit(i))
	hud.ruler_input.connect(func(u, r): ruler_input.emit(u, r))
	hud.again_pressed.connect(func():
		hud.hide_result()
		game.restart_arena())
	hud.back_pressed.connect(func():
		hud.hide_result()
		game.end_arena())
	root.add_child(hud)
	hud.process_mode = Node.PROCESS_MODE_PAUSABLE
	result_panel = hud.result

	menu = LobbyMenu.new()
	root.add_child(menu)
	menu.setup(game)
	menu.start_requested.connect(func(kind: String):
		show_lobby_chrome(false)
		game.start_arena(kind))
	menu.house_requested.connect(_open_house)
	menu.wardrobe_requested.connect(_open_wardrobe)
	menu.loge_requested.connect(_open_loge)
	menu.howto_requested.connect(func(k): open_howto(k))
	menu.quit_requested.connect(_quit)
	menu.settings_requested.connect(func(): open_settings())
	menu.daily_requested.connect(_open_daily)
	menu.online_requested.connect(func():
		root.move_child(online, -1)
		online.open())

	card = ProfileCard.new()
	card.position = Vector2(CARD_X, 30)
	root.add_child(card)
	card.lang_toggled.connect(func():
		I18n.toggle()
		Profile.data.lang = I18n.lang
		Profile.save())
	card.rename_requested.connect(_open_rename)
	_build_rename()


	wardrobe = WardrobePanel.new()
	wardrobe.position = Vector2(1920 + 40, 96)
	wardrobe.visible = false
	root.add_child(wardrobe)
	wardrobe.look_changed.connect(func(k, v):
		SteamService.unlock("WARDROBE")
		Profile.set_look(k, v)
		game.apply_look_to_player_one()
		wardrobe.refresh()
		_refresh_card())
	wardrobe.done.connect(_close_wardrobe)
	wardrobe.preview.connect(func(k, v): game.preview_look(k, v))
	wardrobe.bought.connect(func(): _refresh_card())
	wardrobe.tab_changed.connect(func(c): game.wardrobe_conquest(c))

	house = HouseCard.new()
	house.position = Vector2(1920 + 40, 300)
	house.visible = false
	root.add_child(house)
	house.connect_requested.connect(func(u): game.start_house(u))
	house.close_requested.connect(_close_house)
	_qr_http = HTTPRequest.new()
	add_child(_qr_http)
	_qr_http.request_completed.connect(_on_qr)

	loge = LogeBar.new()
	loge.position = Vector2((1920 - 1000) * 0.5, 1080 + 30)
	loge.visible = false
	root.add_child(loge)
	loge.throw.connect(func(k): game.throw_item(k))
	loge.leave.connect(_leave_loge)

	playbill = Playbill.new()
	playbill.position = Vector2((1920 - Playbill.W) * 0.5 + 200, -1100)
	root.add_child(playbill)
	playbill.closed.connect(func(): playbill.lift())

	pause = PauseMenu.new()
	root.add_child(pause)
	pause.settings_requested.connect(func(): open_settings())
	settings = SettingsScreen.new()
	root.add_child(settings)
	settings.closed.connect(_settings_closed)
	settings.hints_changed.connect(func(): menu.retext())
	online = OnlinePanel.new()
	root.add_child(online)
	online.closed.connect(func():
		if _lobby and menu.menu_col.visible:
			menu.buttons["online"].grab_focus())
	online.house_requested.connect(_open_house)
	toast = AchievementToast.new()
	root.add_child(toast)
	ErrorReporter.crash_detected.connect(func(_path):
		toast.show_toast(Pal.t("crash.title"), Pal.t("crash.desc")))
	if Profile.recovered == "backup":
		toast.call_deferred("show_toast", Pal.t("profile.recovered"), "")
	if ErrorReporter.last_crash_report != "":
		toast.call_deferred("show_toast", Pal.t("crash.title"), Pal.t("crash.desc"))
	SteamService.achievement_unlocked.connect(func(id, title):
		var row: Array = SteamService.ACHIEVEMENTS[id]
		toast.show_toast(title, String(row[2] if Pal.tr_lang() else row[3]))
		root.move_child(toast, -1))
	pause.resume_requested.connect(func(): set_paused(false))
	pause.lobby_requested.connect(func():
		set_paused(false)
		hud.hide_result()
		game.end_arena())

	root.move_child(hud, -1)
	grain = ColorRect.new()
	grain.set_anchors_preset(Control.PRESET_FULL_RECT)
	grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gm := ShaderMaterial.new()
	gm.shader = preload("res://ui/shaders/grain.gdshader")
	grain.material = gm
	root.add_child(grain)

	I18n.changed.connect(func(_l): _retext())
	Profile.changed.connect(_refresh_card)
	_retext()
	_refresh_card()
	menu.intro()
	Fx.anchor(card)
	_card_tw = Fx.rise(card, 0.6, Vector2(0, -40), 0.7)

# ── dil / profil ────────────────────────────────────────────────────
func _retext() -> void:
	menu.retext()
	wardrobe.retext()
	house.retext()
	loge.retext()
	_refresh_card()
	if playbill.visible:
		playbill.fill(playbill.mode)

func _refresh_card() -> void:
	if card == null:
		return
	var n := Profile.player_name()
	var r := Profile.record(n)
	var look := Profile.look()
	card.refresh(n, {"wl": "%d / %d" % [r.wins, r.losses], "champs": r.champs, "streak": r.streak, "best": r.best},
		look, I18n.lang, PlushVisual.COLORS.get(String(look.get("color", "mustard")), Pal.GOLD))

func _build_rename() -> void:
	rename_panel = GlassPanel.new()
	rename_panel.position = Vector2(CARD_X, 290)
	rename_panel.size = Vector2(ProfileCard.W, 150)
	rename_panel.visible = false
	root.add_child(rename_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	rename_panel.add_child(v)
	var k := KickerLabel.new()
	k.text = I18n.t("wardrobe.name")
	v.add_child(k)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	name_edit = LineEdit.new()
	name_edit.max_length = 14
	name_edit.custom_minimum_size = Vector2(300, 56)
	name_edit.text_submitted.connect(func(_t): _close_rename(true))
	row.add_child(name_edit)
	var ok := CtaButton.new()
	ok.label = I18n.t("common.done")
	ok.custom_minimum_size = Vector2(140, 56)
	ok.font_size = 26
	ok.pressed.connect(func(): _close_rename(true))
	row.add_child(ok)

func _open_rename() -> void:
	name_edit.text = Profile.player_name()
	rename_panel.visible = true
	Fx.anchor(rename_panel)
	Fx.rise(rename_panel, 0.0, Vector2(0, -20), 0.35)
	name_edit.grab_focus()
	name_edit.select_all()

func _close_rename(save: bool) -> void:
	if save:
		var old := Profile.player_name()
		Profile.set_player_name(name_edit.text)
		game.rename_player_one(old, Profile.player_name())
	name_edit.release_focus()
	Fx.fade(rename_panel, 0.0, 0.2)

# ── yardımcı ────────────────────────────────────────────────────────
func _slide(c: Control, prop: String, to: float, dur := 0.5) -> Tween:
	var tw := create_tween()
	tw.tween_property(c, prop, to, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return tw

## Profil kartını göster (yerine kayar) ya da yukarı kaldır.
func _card_to(on: bool) -> void:
	if _card_tw:
		_card_tw.kill()
	card.modulate.a = 1.0
	_card_tw = _slide(card, "position:y", 30.0 if on else -320.0, 0.55)

## Lobi süsleri (menü, profil kartı, ipucu) göster/gizle.
func show_lobby_chrome(on: bool) -> void:
	_lobby = on
	menu.set_shown(on)
	_card_to(on)
	if house.visible:
		_slide(house, "position:x", (1920 - house.size.x - 34.0) if on else 1920 + 40.0)
	if rename_panel.visible and not on:
		rename_panel.visible = false

# ── kostüm odası ────────────────────────────────────────────────────
func _open_wardrobe() -> void:
	menu.set_shown(false)
	_card_to(false)
	wardrobe.visible = true
	wardrobe.open()
	_slide(wardrobe, "position:x", 1920 - wardrobe.size.x - 70.0, 0.6)
	game.enter_wardrobe()

func _close_wardrobe() -> void:
	game.apply_look_to_player_one()   # denenen (satın alınmamış) öğeyi çıkar
	menu.set_shown(true)
	_card_to(true)
	_slide(wardrobe, "position:x", 1920 + 40.0)
	game.exit_wardrobe()

# ── loca ────────────────────────────────────────────────────────────
func _open_loge() -> void:
	show_lobby_chrome(false)
	loge.visible = true
	_slide(loge, "position:y", 1080 - loge.size.y - 30.0)
	game.enter_loge()

func _leave_loge() -> void:
	_slide(loge, "position:y", 1080 + 30.0)
	show_lobby_chrome(true)
	game.exit_loge()

# ── afiş ────────────────────────────────────────────────────────────
func open_howto(mode := "trivia") -> void:
	playbill.set_meta("mode", mode)
	playbill.fill(mode)
	playbill.drop()

# ── ev partisi ──────────────────────────────────────────────────────
func _open_house() -> void:
	house.visible = true
	house.open()
	house.edit.text = game.relay_url()
	_slide(house, "position:x", 1920 - house.size.x - 34.0)
	_card_to(false)
	game.start_house()
	if not game.bridge.hosted.is_connected(_on_hosted):
		game.bridge.hosted.connect(_on_hosted)
		game.bridge.state_changed.connect(func(_s): refresh_house())
	refresh_house()

func _close_house() -> void:
	_slide(house, "position:x", 1920 + 40.0)
	if _lobby:
		_card_to(true)
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
		house.qr.texture = ImageTexture.create_from_image(img)

func refresh_house() -> void:
	if house == null or game == null or game.bridge == null:
		return
	var b: PhoneBridge = game.bridge
	house.code = b.code if b.state == "live" else "····"
	house.url_text = b.http_base().replace("https://", "").replace("http://", "") + "/pad"
	var list := []
	for pid in game.phone_players:
		var p: Plush = game.phone_players[pid]
		if is_instance_valid(p):
			list.append({"name": p.player_name, "color": PlushVisual.COLORS.get(String(p.look.get("color", "mustard")), Pal.GOLD)})
	house.phones = list
	house.status = "" if b.state == "live" else I18n.t("house.connecting" if b.state == "connecting" else "house.error")

# ── HUD köprüsü (oyun modları bunları çağırır) ─────────────────────
func hud_show(on: bool) -> void:
	hud.visible = on
	if on:
		hud.reset()

func hud_set_top(text: String, sub := "") -> void:
	hud.hud_top(text, sub)

func hud_set_msg(text: String, accent := Pal.GOLD, sub := "") -> void:
	hud.hud_message(text, accent, sub)

func hud_set_timer(left_s: float, total: float) -> void:
	hud.hud_timer(left_s, total)

func hud_message(text: String, accent := Pal.GOLD, sub := "") -> void: hud.hud_message(text, accent, sub)
func hud_scores(rows: Array) -> void: hud.hud_scores(rows)
func hud_round_card(r: int, title: String, desc: String, chips: Array) -> void: hud.hud_round_card(r, title, desc, chips)
func hud_round_card_hide() -> void: hud.hud_round_card_hide()
func hud_tug(names: Array, cols: Array, pulls: Array, left: float, total: float) -> void: hud.hud_tug(names, cols, pulls, left, total)
func hud_tug_winner(i: int) -> void: hud.hud_tug_winner(i)
func hud_tug_hide() -> void: hud.hud_tug_hide()
func hud_question(label: String, prompt: String, options: Array, cat_name: String, cat_color: Color, total: float, stake: int, pips := Vector2i(0, 0)) -> void:
	hud.hud_question(label, prompt, options, cat_name, cat_color, total, stake, pips)
func hud_question_hide() -> void: hud.hud_question_hide()
func hud_timer(left: float, total: float) -> void: hud.hud_timer(left, total)
func hud_reveal(correct: int) -> void: hud.hud_reveal(correct)
func hud_reward_open(p_name: String, color: Color, targets: Array, actions: Array) -> void: hud.hud_reward_open(p_name, color, targets, actions)
func hud_reward_select(step: int, idx: int) -> void: hud.hud_reward_select(step, idx)
func hud_reward_close() -> void: hud.hud_reward_close()
func hud_standings(rows: Array, round_no: int) -> void: hud.hud_standings(rows, round_no)
func hud_standings_hide() -> void: hud.hud_standings_hide()

func hud_estimate_open(kicker: String, q: String, unit: String, lo: float, hi: float, year: bool, entries: Array, mouse_on: bool) -> void: hud.hud_estimate_open(kicker, q, unit, lo, hi, year, entries, mouse_on)
func hud_estimate_entry(i: int, value: int, locked: bool) -> void: hud.hud_estimate_entry(i, value, locked)
func hud_estimate_reveal(answer: int, answer_text: String, ranked: Array) -> void: hud.hud_estimate_reveal(answer, answer_text, ranked)
func hud_estimate_close() -> void: hud.hud_estimate_close()
func hud_duel_marks(marks: Array, clickable: bool) -> void: hud.hud_duel_marks(marks, clickable)
func hud_track(act: int, acts: int, kind: String, total: int, done: float, colors: Array = []) -> void: hud.hud_track(act, acts, kind, total, done, colors)
## Mayhem Turu parçaları (hud/mayhem_overlay.gd)
func hud_mayhem(method: String, args: Array = []) -> void:
	if hud.mayhem.has_method(method):
		hud.mayhem.callv(method, args)
func hud_duel_splash(a: Dictionary, d: Dictionary, place: String) -> void: hud.hud_duel_splash(a, d, place)

# ── duraklatma, geri, gamepad odağı ────────────────────────────────
func set_paused(on: bool) -> void:
	get_tree().paused = on
	if on:
		pause.open()
		root.move_child(pause, -1)
	else:
		pause.close()

var word: WordPanel

func _open_daily() -> void:
	if word == null:
		word = WordPanel.new()
		root.add_child(word)
		word.closed.connect(func():
			for p in game.all_actors():
				p.frozen_input = false
			menu.refresh_daily()
			_refresh_card()
			menu.buttons["daily"].grab_focus())
		word.rewarded.connect(func(): _refresh_card())
	root.move_child(word, -1)
	for p in game.all_actors():
		p.frozen_input = true
	word.open()

func open_settings() -> void:
	root.move_child(settings, -1)
	settings.open()

func _settings_closed() -> void:
	if pause.visible:
		pause.refocus()
	elif _lobby and menu.menu_col.visible:
		menu.buttons["settings"].grab_focus()

func _quit() -> void:
	Music.stop(0.4)
	stage_curtain_then(func(): get_tree().quit())

func stage_curtain_then(cb: Callable) -> void:
	if game and game.stage:
		game.stage.set_curtain(true)
		await game.stage.curtain_done
	cb.call()

func _unhandled_input(e: InputEvent) -> void:
	if settings.visible or online.visible or (word != null and word.visible):
		return
	var back: bool = e.is_action_pressed("ui_cancel") or (e is InputEventJoypadButton and e.pressed and e.button_index == JOY_BUTTON_START)
	if back:
		if get_tree().paused:
			set_paused(false)
		elif game.mode == game.Mode.ARENA and not hud.result.visible:
			set_paused(true)
		elif menu.is_setup() or menu.is_settings():
			menu.show_menu()
		else:
			return
		get_viewport().set_input_as_handled()
		return
	# gamepad/klavye ile menüde gezinme: odak yoksa ilk düğmeyi yakala
	if _lobby and game.mode == game.Mode.LOBBY and root.get_viewport().gui_get_focus_owner() == null:
		var nav: bool = (e is InputEventJoypadButton and e.pressed) or (e is InputEventJoypadMotion and absf(e.axis_value) > 0.6 and e.axis == JOY_AXIS_LEFT_Y)
		if nav and menu.menu_col.visible:
			menu.buttons["trivia"].grab_focus()

func show_result(title: String, ranking: Array, rows: Array = []) -> void:
	hud.show_result(title, ranking, rows)

# ── ekran görüntüsü aracı ──────────────────────────────────────────
func prepare_shot(part: String) -> void:
	match part:
		"daily", "daily_done":
			Profile.data.daily = {}
			Profile.data.coins = 240
			var ans := DailyWord.answer("tr")
			for w in ["kitap", "deniz", "bulut"]:
				if w != ans and DailyWord.state("tr").guesses.size() < 2:
					DailyWord.submit("tr", w)
			if part == "daily_done":
				DailyWord.submit("tr", ans)
			_open_daily()
			if part == "daily":
				word._cur = ans.substr(0, 2)
			await get_tree().create_timer(2.2).timeout
		"wardrobe_shop":
			Profile.data.coins = 640
			_open_wardrobe()
			await get_tree().create_timer(1.6).timeout
			wardrobe._rows["outfit"]._step(4)
			await get_tree().create_timer(0.3).timeout
			wardrobe._rows["necklace"]._step(4)
			await get_tree().create_timer(1.6).timeout
		"setup":
			menu._open_setup("arena")
			await get_tree().create_timer(1.8).timeout
		"settings", "settings_video", "settings_controls", "settings_about":
			open_settings()
			var tabs := {"settings": 0, "settings_video": 1, "settings_controls": 3, "settings_about": 4}
			settings._set_tab(int(tabs[part]))
			await get_tree().create_timer(1.2).timeout
		"online":
			root.move_child(online, -1)
			online.open()
			SteamService.unlock("WARDROBE")
			await get_tree().create_timer(1.3).timeout
		"pause":
			await get_tree().create_timer(0.5).timeout
			set_paused(true)
			await get_tree().create_timer(0.6).timeout
		"menu_hover":
			await get_tree().create_timer(2.0).timeout
			menu.buttons["trivia"].grab_focus()
			await get_tree().create_timer(0.8).timeout
		"wardrobe":
			_open_wardrobe()
			await get_tree().create_timer(2.5).timeout
		"wardrobe_cq":
			_open_wardrobe()
			await get_tree().create_timer(1.5).timeout
			wardrobe._tabs.selected = 1
			wardrobe._set_tab(true)
			await get_tree().create_timer(1.8).timeout
		"howto":
			open_howto("trivia")
			await get_tree().create_timer(2.2).timeout
		"loge":
			_open_loge()
			await get_tree().create_timer(2.5).timeout
			game.throw_item("rose")
			game.throw_item("tomato")
			await get_tree().create_timer(0.7).timeout
		"house":
			_open_house()
			await get_tree().create_timer(4.0).timeout
		"en":
			I18n.set_lang("en")
			await get_tree().create_timer(1.0).timeout
		_:
			if game.has_method("prepare_game_shot"):
				await game.prepare_game_shot(part)
			else:
				await get_tree().create_timer(1.0).timeout
