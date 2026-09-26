class_name MayhemTour
extends Node
## Mayhem Turu: her soru bir mini oyuna dönüşür. Kimse elenmez.
##
##   Four Doors      doğru kapağa koş; yanlış kapaktakiler fırlatılır
##   Zoom Panic      aşırı yakından başlayan 3D nesne yavaşça görünür; erken bilen çok alır
##   En Yakın        sahne bir sayı doğrusudur; durduğun yer tahminindir
##   Sıralama        dört şeyi sırayla seç (eskiden yeniye, küçükten büyüğe…)
##   Kulağına Güven  bir melodi ya da ses çalar; kaynağını bul
##   Yağan Cevaplar  şıklar gökten düşer; doğrusunu yakala, sahteler sersemletir
##   Hafıza Paniği   dört nesneyi ezberle; sonra kutular karışır
##   Final Mayhem    her 8 saniyede başka bir tür, puanlar ×1.5
##
## Puan: doğru 100 + hız 0–50; 3 seri +25, 5 seri +50. Tahmin: 150/100/50 (+50 tam isabet).
## Mayhem Metre: doğrular ve hızlı cevaplar doldurur; dolunca bir sonraki tura
## kaos olayı gelir (buz pisti, dev kafalar, ters kumanda, minik oyuncular, kaçan cevaplar).
## Geride kalan: sonuncu, lidere 150+ puan uzaksa o tur JOKER (×2) alır.

signal finished(ranking: Array)

const GAMES := ["doors", "zoom", "nearest", "order", "sound", "falling", "memory"]
const CHAOS := ["ice", "bighead", "invert", "tiny", "moving"]
const BOT_ACC := {"easy": 0.55, "normal": 0.72, "hard": 0.88}
const BOT_READ := {"easy": 1.3, "normal": 1.0, "hard": 0.75}
const BOT_EST := {"easy": 0.22, "normal": 0.12, "hard": 0.06}
const GAME_ICON := {"doors": "door", "zoom": "star", "nearest": "flag", "order": "scroll", "sound": "speaker",
	"falling": "diamond", "memory": "mask", "final": "bolt"}
const REACTIONS := ["HAHA", "OHA!", "NOOO", "EZ", "?!", "WOW"]

var rules: RulesConfig = preload("res://data/rules.tres")
var game: Node
var stage: Stage
var ui: Node
var contestants: Array[Plush] = []
var st := {}
var phase := "idle"          # idle | intro | question | reveal | standings | done
var level := "normal"
var length := "tour"
var rng := RandomNumberGenerator.new()
var fast_forward := 1.0
var data := {}
var plan: Array = []
var round_no := 0
var game_id := ""
var meter := 0.0
var chaos_next := ""
var chaos_now := ""
var joker: Plush = null
var mult := 1.0
var timer_total := 10.0
var time_left := 0.0
var log_lines: Array[String] = []
var answer_s := 10.0

var _q_t := 0.0
var _zone := {}              # Plush -> [kapak, girdiği an]
var _dead_zones: Array = []  # sıralamada kullanılmış kapaklar
var _bot_plan := {}
var _tick := 99
var _moving_at := -1.0
var _cur_options: Array = []
var _cur_correct: Array = []
var _falls: Array = []
var _catch := {}
var _line: NumberLine = null
var _est_bot := {}
var _sound: AudioStreamPlayer
var _props3d: Array[Node3D] = []
var _tiny_orig := {}
var _worst_rank := {}
const DOOR_X := [-4.8, -1.6, 1.6, 4.8]
const DOOR_Z := -4.2
var _doors: Array[AnswerDoor] = []
var _zone_mode := "grid"         # grid: 2×2 kapak · doors: arkadaki dört kapı
var _phone_pick := {}          # telefon: şık düğmesiyle verilen cevap [kapak, an]
var _est_lock := {}           # Plush -> kilitli tahmin (zıplama, klavye ya da telefon)
var _est_typed := ""
var _est_typer: Plush = null

func setup(p_game: Node, actors: Array[Plush], p_timer: float, p_level: String, seed_val := 0) -> void:
	game = p_game
	stage = game.stage
	ui = game.ui
	contestants = actors.duplicate()
	level = p_level
	answer_s = clampf(p_timer, 8.0, 12.0) if p_timer > 0.0 else 10.0
	length = String(Profile.setting("mh_length", "tour"))
	if seed_val != 0:
		rng.seed = seed_val
	else:
		rng.randomize()
	Questions.reset_used()
	data = load_data()
	for p in contestants:
		st[p] = {"points": 0, "correct": 0, "wrong": 0, "asked": 0, "streak": 0, "best_streak": 0,
			"fast_sum": 0.0, "fast_n": 0, "est_sum": 0.0, "est_n": 0, "lastsec": 0, "jumps": 0,
			"bullseye": 0, "caught": 0, "stunned": 0}
		_worst_rank[p] = 1
		p.jumped.connect(_on_jumped)
	_sound = AudioStreamPlayer.new()
	_sound.bus = "SFX"
	add_child(_sound)
	plan = build_plan(length, rng)

static func load_data() -> Dictionary:
	var f := FileAccess.open("res://data/mayhem.json", FileAccess.READ)
	if f == null:
		push_error("mayhem.json açılamadı")
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if typeof(d) == TYPE_DICTIONARY else {}

## Tur listesi: ilk tur hep Four Doors (ısınma), sonra karışık; en sonda final.
static func build_plan(p_length: String, r: RandomNumberGenerator) -> Array:
	var rest := GAMES.duplicate()
	rest.erase("doors")
	for i in range(rest.size() - 1, 0, -1):
		var j := r.randi() % (i + 1)
		var tmp = rest[i]
		rest[i] = rest[j]
		rest[j] = tmp
	var n := 2 if p_length == "quick" else 5
	var out := ["doors"]
	out.append_array(rest.slice(0, n))
	out.append("final")
	return out

func _exit_tree() -> void:
	for d in _doors:
		if is_instance_valid(d):
			d.queue_free()
	_clear_chaos()
	_clear_props()
	if _line:
		_line.queue_free()
	for p in contestants:
		if is_instance_valid(p):
			p.clear_debuffs()
			p.hide_plate()
			if p.jumped.is_connected(_on_jumped):
				p.jumped.disconnect(_on_jumped)
	for b in _falls:
		if is_instance_valid(b.node):
			b.node.queue_free()

# ── yardımcılar ─────────────────────────────────────────────────────
func _hud(method: String, args: Array = []) -> void:
	if ui and ui.has_method(method):
		ui.callv(method, args)

func _mh(method: String, args: Array = []) -> void:
	_hud("hud_mayhem", [method, args])

func _wait(s: float) -> void:
	await get_tree().create_timer(s / fast_forward, false, true).timeout

func _say(text: String, accent := Color("F2C66A"), sub := "") -> void:
	log_lines.append(text)
	_hud("hud_message", [text, accent, sub])

func pcolor(p: Plush) -> Color:
	return PlushVisual.COLORS.get(String(p.look.get("color", "mustard")), Color.WHITE)

func _notify_all(text: String) -> void:
	if game.has_method("notify_phones"):
		game.notify_phones({"t": "status", "text": text})

func _notify(p: Plush, msg: Dictionary) -> void:
	if game.has_method("notify_player"):
		game.notify_player(p, msg)

func _L() -> String:
	return I18n.lang

func _refresh_scores(deltas := {}) -> void:
	var rows := []
	for p in ranking():
		var s: Dictionary = st[p]
		rows.append({"name": p.player_name, "color": pcolor(p), "value": s.points, "combo": s.streak,
			"hp": 0, "max_hp": 1, "alive": true, "hp_mode": false, "delta": deltas.get(p, 0), "debuffs": p.debuffs.keys()})
		if _line == null:
			p.set_plate(p.player_name, "", pcolor(p))
	_hud("hud_scores", [rows])

func ranking() -> Array[Plush]:
	var r := contestants.duplicate()
	r.sort_custom(func(a, b): return st[a].points > st[b].points or (st[a].points == st[b].points and st[a].correct > st[b].correct))
	return r

func stats_for(p: Plush) -> Dictionary:
	return st.get(p, {})

func _on_jumped(p: Plush) -> void:
	if st.has(p):
		st[p].jumps += 1
	_est_jump(p)

func line_up() -> void:
	var n := contestants.size()
	for i in n:
		var x := (i - (n - 1) * 0.5) * 1.05
		contestants[i].teleport(Vector3(x, 0.05, 3.35), PI)
		if contestants[i].controller is Controllers.Bot:
			contestants[i].controller.mode = "idle"

func _is_bot(p: Plush) -> bool:
	return p.controller is Controllers.Bot

# ── akış ────────────────────────────────────────────────────────────
func run() -> void:
	stage.set_zones_visible(false)
	_refresh_scores()
	_mh("set_meter", [0.0])
	await _wait(0.6)
	for i in plan.size():
		if phase == "done":
			return
		round_no = i + 1
		game_id = String(plan[i])
		log_lines.append("GAME " + game_id)
		_hud("hud_track", [round_no, plan.size(), "dots", plan.size(), float(i)])
		await _round_start()
		await call("_g_" + game_id)
		_round_end()
		if i < plan.size() - 1:
			await _standings()
	await _awards()
	_finish()

func _round_start() -> void:
	phase = "intro"
	mult = 1.5 if game_id == "final" else 1.0
	# geride kalana joker
	joker = null
	if round_no > 1 and game_id != "final" and contestants.size() >= 2:
		var rk := ranking()
		var last: Plush = rk[rk.size() - 1]
		if st[rk[0]].points - st[last].points >= 150:
			joker = last
	var chips := []
	for k in 3:
		chips.append(I18n.t("mh.%s.chip%d" % [game_id, k + 1]))
	var title := I18n.t("mh.%s" % game_id)
	_hud("hud_round_card", [round_no, title, I18n.t("mh.%s.d" % game_id), chips])
	_notify_all(title)
	Sfx.play("whoosh", -4.0, 0.9)
	Narrator.say("act3_arena" if game_id == "final" else "ready")
	await _wait(3.4)
	_hud("hud_round_card_hide")
	await _wait(0.4)
	# kaos olayı (metre bir önceki turda dolduysa)
	if chaos_next != "":
		chaos_now = chaos_next
		chaos_next = ""
		await _announce_chaos(chaos_now)
		_apply_chaos(chaos_now)
	if joker:
		_mh("joker_show", [joker.player_name, pcolor(joker)])
		_say(I18n.t("mh.joker", {"name": joker.player_name}), pcolor(joker).lightened(0.3), I18n.t("mh.joker_sub"))
		joker.float_text("JOKER ×2", Color("F6CF7B"), true)
		await _wait(1.6)
	Music.play("think", 0.8)

func _round_end() -> void:
	_clear_chaos()
	_mh("joker_show", ["", Color.WHITE])
	joker = null
	stage.set_zones_visible(false)
	_hud("hud_question_hide")
	for p in contestants:
		if _is_bot(p):
			p.controller.go_to(Vector3(rng.randf_range(-3.0, 3.0), 0, rng.randf_range(-1.0, 2.0)))

func _standings() -> void:
	phase = "standings"
	var rows := []
	var rk := ranking()
	for i in rk.size():
		var p: Plush = rk[i]
		_worst_rank[p] = max(int(_worst_rank[p]), i + 1)
		rows.append({"name": p.player_name, "color": pcolor(p), "points": st[p].points, "combo": st[p].best_streak})
	_hud("hud_standings", [rows, round_no])
	Sfx.play("whoosh", -6.0)
	await _wait(3.2)
	_hud("hud_standings_hide")
	await _wait(0.4)

# ── kaos ────────────────────────────────────────────────────────────
func _announce_chaos(kind: String) -> void:
	Sfx.play("sting", -2.0)
	Sfx.play("war_horn", -4.0)
	get_tree().create_timer(0.5).timeout.connect(func(): Sfx.play("chaos_" + kind, -1.0))
	if game.cam:
		game.cam.add_trauma(0.4)
	_mh("chaos_show", [I18n.t("mh.chaos." + kind), I18n.t("mh.chaos.%s.d" % kind), {"ice": "ice", "bighead": "bighead", "invert": "invert", "tiny": "star", "moving": "bolt"}.get(kind, "bolt")])
	_notify_all(I18n.t("mh.chaos." + kind))
	log_lines.append("CHAOS " + kind)
	await _wait(2.6)
	_mh("chaos_hide")

func _apply_chaos(kind: String) -> void:
	for p in contestants:
		match kind:
			"ice", "bighead", "invert":
				p.set_debuff(kind, true, rules)
			"tiny":
				if p.visual:
					_tiny_orig[p] = p.visual.scale
					p.create_tween().tween_property(p.visual, "scale", Vector3.ONE * 0.55, 0.4).set_trans(Tween.TRANS_BACK)

func _clear_chaos() -> void:
	if chaos_now == "":
		return
	for p in contestants:
		if not is_instance_valid(p):
			continue
		if chaos_now in ["ice", "bighead", "invert"]:
			p.set_debuff(chaos_now, false, rules)
		if chaos_now == "tiny" and p.visual:
			p.create_tween().tween_property(p.visual, "scale", _tiny_orig.get(p, Vector3.ONE), 0.4)
	chaos_now = ""

func _fill_meter(frac_right: float, frac_fast: float) -> void:
	meter += 0.07 + 0.12 * frac_right + 0.05 * frac_fast
	if meter >= 1.0 and chaos_next == "" and round_no < plan.size() - 1:
		var pool := CHAOS.duplicate()
		chaos_next = pool[rng.randi() % pool.size()]
		meter = 0.0
		_mh("set_meter", [1.0, true])
		Sfx.play("chaos_alarm", -4.0)
		_say(I18n.t("mh.meter_full"), Color("FF7A5A"), I18n.t("mh.meter_full_sub"))
		get_tree().create_timer(1.6).timeout.connect(func(): _mh("set_meter", [0.0]))
	else:
		meter = minf(meter, 0.99)
		_mh("set_meter", [meter])

# ── kapak sorusu (Four Doors, Zoom, Ses, Hafıza, Sıralama, D/Y) ────
## correct: doğru kapakların listesi. Dönüş: {Plush: {"ok", "t", "zone"}}
func _zone_question(label: String, prompt: String, options: Array, correct: Array, total: float,
		cat_name := "", cat_color := Color("B8893B"), acc_mod := 0.0) -> Dictionary:
	_cur_options = options.duplicate()
	_cur_correct = correct.duplicate()
	timer_total = total
	stage.board.show_question(round_no - 1, prompt, options, cat_name, cat_color, total)
	if _zone_mode == "doors":
		stage.set_zones_visible(false)
		for i in 4:
			_doors[i].set_answer(String(options[i]))
	else:
		stage.set_zone_texts(options)
		stage.set_zones_visible(true)
	_hud("hud_question", [label, prompt, options, cat_name, cat_color, total, 0, Vector2i(0, 0)])
	_notify_all(prompt.substr(0, 90))
	Sfx.play("ding", -4.0, 0.9)
	_zone.clear()
	_phone_pick.clear()
	for p in contestants:
		p.frozen_input = false
		_zone[p] = [-1, 0.0]
		if p.controller is Controllers.Phone:
			_notify(p, {"t": "mode", "m": "abcd", "q": prompt, "options": options})
	_plan_zone_bots(prompt, acc_mod)
	_q_t = 0.0
	time_left = total
	_tick = 99
	_moving_at = total * 0.5 if chaos_now == "moving" and game_id not in ["order", "memory"] else -1.0
	phase = "question"
	while time_left > 0.0 and phase == "question":
		await get_tree().physics_frame
	# kilit + seçimlerin gösterimi
	phase = "lock"
	_hud("hud_timer", [0.0, total])
	var res := {}
	for p in contestants:
		var z: Array = _phone_pick.get(p, _zone.get(p, [-1, 0.0]))
		if p.controller is Controllers.Phone:
			_notify(p, {"t": "mode", "m": ""})
		var zi := int(z[0])
		if _dead_zones.has(zi):
			zi = -1
		res[p] = {"zone": zi, "t": float(z[1]), "ok": _cur_correct.has(zi)}
		p.float_text(Stage.LETTERS[zi] if zi >= 0 else "—", Pal.ZONE[zi] if zi >= 0 else Color(0.7, 0.7, 0.7))
	Sfx.play("drumroll", -6.0)
	_say(I18n.t("mh.and_answer"), Color("F2C66A"))
	await _wait(1.1)
	phase = "reveal"
	stage.board.reveal = _cur_correct[0] if not _cur_correct.is_empty() else -1
	_hud("hud_reveal", [_cur_correct[0] if not _cur_correct.is_empty() else -1])
	for i in 4:
		if _dead_zones.has(i):
			continue
		if _zone_mode == "doors":
			if _cur_correct.has(i):
				_doors[i].open_right()
				Sfx.play("door_open", -3.0)
			else:
				_doors[i].shake_wrong()
				Sfx.play("door_rattle", -9.0, 0.95 + i * 0.04)
		else:
			stage.flash_zone(i, Color(0.35, 1.0, 0.45) if _cur_correct.has(i) else Color(1.0, 0.2, 0.15))
	return res

## Oyuncunun seçtiği şık: kapak (2×2) ya da kapı önündeki şerit
func _zone_of(p: Plush) -> int:
	var pos := p.global_position
	if _zone_mode == "doors":
		if pos.z > 0.3 or pos.y < -0.5:
			return -1
		if pos.x < -3.2:
			return 0
		if pos.x < 0.0:
			return 1
		if pos.x < 3.2:
			return 2
		return 3
	return stage.zone_at(pos)

func _zone_target(z: int) -> Vector3:
	if _zone_mode == "doors":
		return Vector3(DOOR_X[z] + rng.randf_range(-0.9, 0.9), 0, DOOR_Z + rng.randf_range(1.0, 2.6))
	var he := stage.zone_half_extents()
	return stage.zone_center(z) + Vector3(rng.randf_range(-he.x, he.x) * 0.5, 0, rng.randf_range(-he.y, he.y) * 0.5)

func _show_doors(on: bool) -> void:
	_zone_mode = "doors" if on else "grid"
	if on and _doors.is_empty():
		for i in 4:
			var d := AnswerDoor.new()
			stage.add_child(d)
			d.setup(Stage.LETTERS[i], Pal.ZONE[i])
			d.position = Vector3(DOOR_X[i], 0.0, DOOR_Z)
			_doors.append(d)
	for i in _doors.size():
		var d: AnswerDoor = _doors[i]
		if on:
			d.visible = true
			d.close()
			d.position.y = 4.0
			d.create_tween().tween_property(d, "position:y", 0.0, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT).set_delay(i * 0.08)
			get_tree().create_timer(0.25 + i * 0.08).timeout.connect(func(): Sfx.play("door_drop", -6.0, 0.95 + i * 0.05))
		else:
			d.visible = false

func _physics_process(delta: float) -> void:
	_poll_reactions()
	if phase != "question":
		return
	# Yağan Cevaplar gerçek zamanlıdır: bloklar ve pelüşler aynı saatle yarışır
	var d := delta if game_id == "falling" else delta * fast_forward
	time_left -= d
	_q_t += d
	stage.board.time_left = max(0.0, time_left)
	_hud("hud_timer", [max(0.0, time_left), timer_total])
	var s := int(ceil(time_left))
	if s < _tick and s <= 3 and s > 0:
		_tick = s
		Sfx.play("tick", -2.0, 1.0 + (3 - s) * 0.1)
	match game_id:
		"nearest":
			_tick_line()
		"falling":
			_tick_falls(delta)   # bloklar gerçek zamanlı düşer (pelüşler de gerçek hızda koşar)
		_:
			if game_id == "final" and _line:
				_tick_line()
			else:
				_tick_zones()
	_drive_bots()

func _tick_zones() -> void:
	for p in _zone:
		if not is_instance_valid(p):
			continue
		if p.controller is Controllers.Phone and not _phone_pick.has(p):
			var a: int = p.controller.take_answer()
			if a >= 0:
				_phone_pick[p] = [a, _q_t]
				p.float_text(Stage.LETTERS[a], Pal.ZONE[a])
		var z := _zone_of(p)
		if z != _zone[p][0]:
			_zone[p] = [z, _q_t]
	# kaçan cevaplar: sürenin yarısında şıklar yer değiştirir
	if _moving_at > 0.0 and time_left <= _moving_at:
		_moving_at = -1.0
		var perm := [0, 1, 2, 3]
		while perm == [0, 1, 2, 3]:
			perm.shuffle()
		var opts := []
		opts.resize(4)
		var corr := []
		for i in 4:
			opts[perm[i]] = _cur_options[i]
			if _cur_correct.has(i):
				corr.append(perm[i])
		_cur_options = opts
		_cur_correct = corr
		for pp in _phone_pick:
			_phone_pick[pp] = [perm[int(_phone_pick[pp][0])], _phone_pick[pp][1]]
		for pp in contestants:
			if pp.controller is Controllers.Phone and not _phone_pick.has(pp):
				_notify(pp, {"t": "mode", "m": "abcd", "q": stage.board.prompt, "options": opts})
		if _zone_mode == "doors":
			for i in 4:
				_doors[i].set_answer(String(opts[i]))
		else:
			stage.set_zone_texts(opts)
		stage.board.options = opts
		_hud("hud_question", [I18n.t("mh.chaos.moving"), stage.board.prompt, opts, "", Color("FF7A5A"), timer_total, 0, Vector2i(0, 0)])
		Sfx.play("whoosh", -2.0, 1.4)
		Sfx.play("chaos_moving", -3.0)
		_say(I18n.t("mh.moved"), Color("FF7A5A"))
		for p in _bot_plan:
			var plan_d: Dictionary = _bot_plan[p]
			if plan_d.has("zone") and int(plan_d.zone) >= 0:
				plan_d.zone = perm[int(plan_d.zone)]
				plan_d.going = false
				plan_d.at = time_left - rng.randf_range(0.3, 1.5)

func _bot_acc() -> float:
	return float(BOT_ACC.get(level, 0.72))

func _plan_zone_bots(prompt: String, acc_mod: float) -> void:
	_bot_plan.clear()
	var read: float = (0.8 + prompt.length() * 0.022) * float(BOT_READ.get(level, 1.0))
	var live := []
	for i in 4:
		if not _dead_zones.has(i):
			live.append(i)
	for p in contestants:
		if not _is_bot(p):
			continue
		var zone: int = _cur_correct[rng.randi() % _cur_correct.size()] if not _cur_correct.is_empty() else live[0]
		if rng.randf() > clampf(_bot_acc() + acc_mod, 0.1, 0.98):
			var wrong := live.filter(func(z): return not _cur_correct.has(z))
			if not wrong.is_empty():
				zone = wrong[rng.randi() % wrong.size()]
		var at: float = clamp(read + rng.randf_range(-0.5, 1.6), 0.6, timer_total - 1.2)
		_bot_plan[p] = {"zone": zone, "at": timer_total - at}
		p.controller.go_to(Vector3(rng.randf_range(-1.2, 1.2), 0, rng.randf_range(-0.6, 0.6)))

func _drive_bots() -> void:
	for p in _bot_plan:
		if not is_instance_valid(p) or not p.is_active():
			continue
		var plan_d: Dictionary = _bot_plan[p]
		if plan_d.has("zone"):
			if time_left <= plan_d.at and not plan_d.get("going", false):
				plan_d.going = true
				p.controller.go_to(_zone_target(plan_d.zone))
		elif plan_d.has("x"):
			if time_left <= plan_d.at and not plan_d.get("going", false):
				plan_d.going = true
				p.controller.go_to(Vector3(plan_d.x, 0, NumberLine.Z - 0.9 + rng.randf_range(-0.5, 0.3)))
		elif plan_d.has("fall"):
			_bot_fall(p, plan_d)
		if plan_d.get("going", false) and rng.randf() < 0.003 * (2.0 if level == "hard" else 1.0):
			for o in contestants:
				if o != p and o.global_position.distance_to(p.global_position) < 1.3:
					p.facing = atan2(o.global_position.x - p.global_position.x, o.global_position.z - p.global_position.z)
					p.try_shove()
					break

# ── puanlama ───────────────────────────────────────────────────────
## res: {Plush: {"ok", "t"}}; zaman "t" sorunun başından geçen süre (erken = çok puan)
func _score(res: Dictionary, total: float, speed_w := 1.0, launch := false) -> void:
	var deltas := {}
	var right: Array[Plush] = []
	var wrong: Array[Plush] = []
	var fast := 0
	for p in contestants:
		var r: Dictionary = res.get(p, {"ok": false, "t": total})
		var s: Dictionary = st[p]
		s.asked += 1
		if bool(r.ok):
			right.append(p)
			var t := float(r.t)
			var speed := int(round(50.0 * speed_w * clampf(1.0 - t / max(1.0, total), 0.0, 1.0)))
			if t / max(1.0, total) < 0.45:
				fast += 1
			s.correct += 1
			s.streak += 1
			s.best_streak = max(s.best_streak, s.streak)
			s.fast_sum += t
			s.fast_n += 1
			if total - t < 1.0:
				s.lastsec += 1
			var bonus := 50 if s.streak >= 5 else (25 if s.streak >= 3 else 0)
			var gain := int(round((100 + speed + bonus) * mult * (2.0 if p == joker else 1.0)))
			s.points += gain
			deltas[p] = gain
			p.float_text("+%d" % gain + ("  ×%d" % s.streak if s.streak >= 3 else ""), Color("9BE38B"), s.streak >= 3)
			p.visual.land(4.0)
			StageFx.sparkle(stage, p.global_position + Vector3(0, 1.0, 0), Color("F2C66A") if s.streak >= 3 else Color("9BE38B"))
			_notify(p, {"t": "buzz", "ms": 30})
		else:
			wrong.append(p)
			s.streak = 0
			s.wrong += 1
			p.float_text("×", Color("FF6B52"))
	if launch:
		for p in wrong:
			_launch(p)
	_comedy(right, wrong)
	_refresh_scores(deltas)
	_fill_meter(right.size() / float(max(1, contestants.size())), fast / float(max(1, contestants.size())))
	_bot_reacts(right, wrong)

## Yanlış kapaktakiler: kapak yay gibi fırlatır
func _launch(p: Plush) -> void:
	if not is_instance_valid(p) or not p.is_active():
		return
	var dir := Vector3(p.global_position.x, 0, p.global_position.z + 1.0).normalized()
	if dir.length() < 0.1:
		dir = Vector3(0, 0, 1)
	p.apply_central_impulse(Vector3(dir.x * 1.6, 6.8, 1.2) * p.mass)
	p.tumble(dir, 0.8)
	StageFx.puff(stage, p.global_position, Color(0.86, 0.78, 0.66), 16)
	Sfx.play("trapdoor", -8.0, 1.4)
	Sfx.play("scream", -9.0, rng.randf_range(1.1, 1.4))

## Sunucunun kısa yorumları (yanlış cevap komik olsun)
func _comedy(right: Array[Plush], wrong: Array[Plush]) -> void:
	var n := contestants.size()
	var key := ""
	var args := {}
	if right.is_empty():
		key = "mh.c.nobody"
		Narrator.say("nobody")
		Sfx.play("aww", -7.0)
	elif wrong.is_empty() and n >= 2:
		key = "mh.c.all"
		Sfx.play("cheer", -10.0)
	elif wrong.size() == 1 and n >= 3:
		key = "mh.c.lone"
		args = {"name": wrong[0].player_name}
		Sfx.play("ooh", -8.0)
	elif right.size() == 1 and n >= 3:
		key = "mh.c.solo"
		args = {"name": right[0].player_name}
		Sfx.play("applause", -10.0)
	else:
		Sfx.play("applause", -12.0)
	if key != "":
		var line := I18n.t("%s.%d" % [key, 1 + rng.randi() % 3], args)
		_say(I18n.t("mh.answer_was", {"x": _answer_text()}), Color("9BE38B") if not right.is_empty() else Color("FF7A5A"), line)
	else:
		_say(I18n.t("mh.answer_was", {"x": _answer_text()}), Color("9BE38B"), I18n.t("mh.n_right", {"n": right.size(), "m": n}))

var _answer_override := ""
func _answer_text() -> String:
	if _answer_override != "":
		return _answer_override
	if _cur_correct.is_empty() or _cur_options.is_empty():
		return ""
	var c := int(_cur_correct[0])
	return Stage.LETTERS[c] + " · " + String(_cur_options[c])

# ── tepkiler ────────────────────────────────────────────────────────
func _poll_reactions() -> void:
	if game.get("bridge") == null or game.bridge == null:
		return
	for p in contestants:
		if not is_instance_valid(p) or not (p.controller is Controllers.Phone):
			continue
		var e: Dictionary = game.bridge.take_event(p.controller.pid, "rx")
		if not e.is_empty():
			show_reaction(p, String(e.get("r", "HAHA")))

func show_reaction(p: Plush, text: String) -> void:
	text = text.substr(0, 8).to_upper()
	p.float_text(text, Color("F6CF7B"), true)
	Sfx.play("pop" if Sfx.streams.has("pop") else "click", -6.0, rng.randf_range(0.9, 1.3))

func _bot_reacts(right: Array[Plush], wrong: Array[Plush]) -> void:
	for p in contestants:
		if _is_bot(p) and rng.randf() < 0.22:
			var pool := ["EZ", "WOW"] if right.has(p) else ["NOOO", "?!", "OHA!"]
			if right.size() == 1 and not right.has(p):
				pool = ["HAHA", "OHA!", "WOW"]
			var txt: String = pool[rng.randi() % pool.size()]
			get_tree().create_timer(rng.randf_range(0.6, 1.6)).timeout.connect(func():
				if is_instance_valid(p):
					show_reaction(p, txt))

# ── soru kaynakları ─────────────────────────────────────────────────
func _mc(tier: String) -> Dictionary:
	var item := Questions.draw_from(tier, "", rng)
	var face := Questions.face(item, I18n.lang)
	return {"prompt": face.prompt, "options": face.options, "correct": int(face.correct), "cat": face.cat_name, "col": face.cat_color}

## Doğru/Yanlış: bir çoktan seçmeli sorunun doğru ya da yanlış şıkkıyla
func _tf() -> Dictionary:
	var q := _mc("d1")
	var truth := rng.randf() < 0.5
	var shown: int = q.correct
	if not truth:
		var w := [0, 1, 2, 3]
		w.erase(q.correct)
		shown = w[rng.randi() % 3]
	var stmt := I18n.t("mh.tf.stmt", {"q": q.prompt, "a": q.options[shown]})
	var T := I18n.t("mh.true")
	var F := I18n.t("mh.false")
	return {"prompt": stmt, "options": [T, F, T, F], "correct": [0, 2] if truth else [1, 3], "cat": q.cat, "col": q.col,
		"answer": "%s · %s" % [T if truth else F, q.options[q.correct]]}

func _sound_q() -> Dictionary:
	var sounds: Array = data.get("sounds", [])
	var s: Dictionary = sounds[rng.randi() % sounds.size()]
	var kind := String(s.kind)
	var L := _L()
	if kind == "melody" and String(s.composer) != "" and rng.randf() < 0.4:
		var comps: Array = data.get("composers", []).duplicate()
		comps.erase(String(s.composer))
		comps.shuffle()
		var opts := [String(s.composer), comps[0], comps[1], comps[2]]
		var order := [0, 1, 2, 3]
		order.shuffle()
		var shuffled := []
		for i in order:
			shuffled.append(opts[i])
		return {"id": s.id, "prompt": I18n.t("mh.sound.composer"), "options": shuffled, "correct": order.find(0)}
	var others := sounds.filter(func(o): return String(o.kind) == kind and o.id != s.id)
	others.shuffle()
	var opts2 := [String(s.get(L, s.en))]
	for i in 3:
		opts2.append(String(others[i].get(L, others[i].en)))
	var order2 := [0, 1, 2, 3]
	order2.shuffle()
	var sh2 := []
	for i in order2:
		sh2.append(opts2[i])
	return {"id": s.id, "prompt": I18n.t("mh.sound.melody" if kind == "melody" else "mh.sound.sfx"), "options": sh2, "correct": order2.find(0)}

func _play_sound(id: String) -> void:
	var path := "res://assets/audio/mayhem/%s.ogg" % id
	var pro: AudioStream = AudioPack.find("mayhem", id)
	if pro == null and not ResourceLoader.exists(path):
		return
	_sound.stream = pro if pro else load(path)
	_sound.volume_db = 0.0
	_sound.play()

func _icons_q(exclude: Array = []) -> Dictionary:
	var ids := PropIcons.ids().filter(func(i): return not exclude.has(i))
	ids.shuffle()
	var pick: Array = ids.slice(0, 4)
	var names := []
	for i in pick:
		names.append(PropIcons.name_of(i, I18n.lang))
	return {"ids": pick, "names": names}

# ── 1 · Four Doors ─────────────────────────────────────────────────
func _g_doors() -> void:
	_show_doors(true)
	await _wait(0.8)
	for i in 3:
		var q := _mc(["d1", "d1", "d2"][i])
		var res := await _zone_question(I18n.t("mh.q_of", {"n": i + 1, "m": 3}), q.prompt, q.options, [q.correct], answer_s, q.cat, q.col)
		_score(res, answer_s, 1.0, true)
		await _wait(2.6)
		_hud("hud_question_hide")
		stage.board.reveal = -1
		for d in _doors:
			d.close()
	_show_doors(false)

# ── 2 · Zoom Panic ─────────────────────────────────────────────────
func _g_zoom() -> void:
	var used := []
	for i in 2:
		var q := _icons_q(used)
		var target := rng.randi() % 4
		used.append(q.ids[target])
		var total := answer_s + 3.0
		_mh("zoom_open", [q.ids[target], total, rng.randi()])
		Sfx.play("zoom", -4.0)
		var res := await _zone_question(I18n.t("mh.q_of", {"n": i + 1, "m": 2}), I18n.t("mh.zoom.q"), q.names, [target], total, "", Color("B8893B"), -0.1)
		_mh("zoom_reveal")
		_score(res, total, 2.0)
		await _wait(2.6)
		_mh("zoom_close")
		_hud("hud_question_hide")
		stage.board.reveal = -1

# ── 3 · Kulağına Güven ─────────────────────────────────────────────
func _g_sound() -> void:
	Music.stop(0.4)
	for i in 3:
		var q := _sound_q()
		_mh("sound_show", [true, I18n.t("mh.sound.playing")])
		_play_sound(String(q.id))
		var total := answer_s + 2.0
		var res := await _zone_question(I18n.t("mh.q_of", {"n": i + 1, "m": 3}), q.prompt, q.options, [q.correct], total)
		_score(res, total)
		await _wait(2.4)
		_sound.stop()
		_mh("sound_show", [false])
		_hud("hud_question_hide")
		stage.board.reveal = -1
	Music.play("think", 0.8)

# ── 4 · Sıralama ───────────────────────────────────────────────────
func _g_order() -> void:
	var sets: Array = data.get("order", [])
	var picked := []
	for s in 2:
		var o: Dictionary = sets[rng.randi() % sets.size()]
		while picked.has(o) and sets.size() > 2:
			o = sets[rng.randi() % sets.size()]
		picked.append(o)
		var L: Dictionary = o.get(_L(), o.get("en", o.tr))
		var items: Array = L.items
		var labels: Array = L.labels
		var slot := [0, 1, 2, 3]       # slot[k] = k. sıradaki öğenin kapağı
		slot.shuffle()
		var opts := ["", "", "", ""]
		for k in 4:
			opts[slot[k]] = items[k]
		_dead_zones = []
		var chain := []
		_mh("chain_set", [chain])
		for step in 3:
			var prompt := String(L.q) + "\n" + (String(L.first) if step == 0 else I18n.t("mh.order.next"))
			var shown := opts.duplicate()
			for dz in _dead_zones:
				shown[dz] = "✓"
			var res := await _zone_question(I18n.t("mh.order.step", {"n": step + 1, "m": 3}), prompt, shown, [slot[step]], answer_s - 1.0)
			_answer_override = "%s · %s" % [items[step], labels[step]]
			_score(res, answer_s - 1.0)
			_answer_override = ""
			chain.append({"text": items[step], "label": labels[step], "ok": true})
			_mh("chain_set", [chain.duplicate()])
			_dead_zones.append(slot[step])
			await _wait(2.0)
			_hud("hud_question_hide")
			stage.board.reveal = -1
		chain.append({"text": items[3], "label": labels[3], "ok": true})
		_mh("chain_set", [chain])
		Sfx.play("ding", -4.0, 1.3)
		await _wait(1.8)
		_mh("chain_set", [[]])
		_dead_zones = []

# ── 5 · Hafıza Paniği ──────────────────────────────────────────────
func _g_memory() -> void:
	for round_i in 2:
		var q := _icons_q()
		var ids: Array = q.ids
		stage.set_zone_texts(["", "", "", ""])
		stage.set_zones_visible(true)
		var nodes: Array[Node3D] = []
		for z in 4:
			var holder := Node3D.new()
			stage.add_child(holder)
			holder.position = stage.zone_center(z) + Vector3(0, 0.12, 0)
			var icon := PropIcons.build(ids[z])
			holder.add_child(icon)
			icon.scale = Vector3.ONE * 1.7
			holder.scale = Vector3.ONE * 0.01
			holder.create_tween().tween_property(holder, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(z * 0.12)
			nodes.append(holder)
			_props3d.append(holder)
		_say(I18n.t("mh.memory.look"), Color("F2C66A"), I18n.t("mh.memory.look_sub"))
		Sfx.play("page", -4.0)
		var spin_t := 0.0
		phase = "memorize"
		while spin_t < 3.6:
			await get_tree().process_frame
			var dt := get_process_delta_time() * fast_forward
			spin_t += dt
			for n in nodes:
				n.rotation.y += dt * 1.4
		var target := rng.randi() % 4
		var answer_zone := target
		if round_i == 0:
			# kaybolurlar
			for n in nodes:
				n.create_tween().tween_property(n, "scale", Vector3.ONE * 0.01, 0.3)
		else:
			# kutulara girer, kutular karışır
			var crates: Array[Node3D] = []
			for z in 4:
				var c := _crate()
				stage.add_child(c)
				c.position = stage.zone_center(z) + Vector3(0, 5.0, 0)
				c.create_tween().tween_property(c, "position:y", 0.9, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
				crates.append(c)
				_props3d.append(c)
				nodes[z].create_tween().tween_property(nodes[z], "scale", Vector3.ONE * 0.01, 0.3).set_delay(0.3)
			await _wait(0.9)
			Sfx.play("thud", -4.0)
			var where := [0, 1, 2, 3]    # where[kutu] = kapak
			var swaps := 3 + (1 if level == "hard" else 0)
			for k in swaps:
				var a := rng.randi() % 4
				var b := (a + 1 + rng.randi() % 3) % 4
				var ca: Node3D = crates[where.find(a)]
				var cb: Node3D = crates[where.find(b)]
				var pa := stage.zone_center(a) + Vector3(0, 0.9, 0)
				var pb := stage.zone_center(b) + Vector3(0, 0.9, 0)
				var tw := create_tween().set_parallel(true)
				tw.tween_property(ca, "position", pb, 0.55).set_trans(Tween.TRANS_SINE)
				tw.tween_property(cb, "position", pa, 0.55).set_trans(Tween.TRANS_SINE)
				Sfx.play("whoosh", -8.0, 1.3)
				var ia := where.find(a)
				var ib := where.find(b)
				where[ia] = b
				where[ib] = a
				await _wait(0.7)
			answer_zone = where[target]
		var total := answer_s
		var res := await _zone_question(I18n.t("mh.q_of", {"n": round_i + 1, "m": 2}),
			I18n.t("mh.memory.q" if round_i == 0 else "mh.memory.q2", {"x": PropIcons.name_of(ids[target], I18n.lang)}),
			["?", "?", "?", "?"], [answer_zone], total, "", Color("B8893B"), -0.12)
		_answer_override = "%s · %s" % [Stage.LETTERS[answer_zone], PropIcons.name_of(ids[target], I18n.lang)]
		# cevabı göster: nesne doğru kapakta belirir
		var reveal_icon := PropIcons.build(ids[target])
		var h := Node3D.new()
		stage.add_child(h)
		h.add_child(reveal_icon)
		reveal_icon.scale = Vector3.ONE * 1.7
		h.position = stage.zone_center(answer_zone) + Vector3(0, 0.12, 0)
		_props3d.append(h)
		_score(res, total)
		_answer_override = ""
		await _wait(2.6)
		_clear_props()
		_hud("hud_question_hide")
		stage.board.reveal = -1

func _crate() -> Node3D:
	var n := Node3D.new()
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.9, 1.8, 1.9)
	m.mesh = bm
	m.material_override = PropIcons.mat(Color("8A5A2E"), 0.7)
	n.add_child(m)
	for y in [-0.6, 0.6]:
		var band := MeshInstance3D.new()
		var b2 := BoxMesh.new()
		b2.size = Vector3(1.95, 0.12, 1.95)
		band.mesh = b2
		band.material_override = PropIcons.mat(Color("3A2616"), 0.6)
		band.position.y = y
		n.add_child(band)
	var q := Label3D.new()
	q.text = "?"
	q.font = Pal.display()
	q.font_size = 160
	q.pixel_size = 0.006
	q.modulate = Color("F6CF7B")
	q.outline_size = 16
	q.position = Vector3(0, 0, 0.97)
	n.add_child(q)
	return n

func _clear_props() -> void:
	for n in _props3d:
		if is_instance_valid(n):
			n.queue_free()
	_props3d.clear()

# ── 6 · En Yakın Kazanır ───────────────────────────────────────────
func _g_nearest() -> void:
	for i in 2:
		await _nearest_one(I18n.t("mh.q_of", {"n": i + 1, "m": 2}), answer_s + 4.0)

func _nearest_one(label: String, total: float) -> void:
	var pool: Array = Questions.estimate
	var q: Dictionary = pool[rng.randi() % pool.size()]
	var L: Dictionary = q.get(_L(), q.get("en", q.tr))
	var a := float(q.a)
	var lo := float(q.min)
	var hi := float(q.max)
	var year := bool(q.get("year", false))
	_line = NumberLine.new()
	stage.add_child(_line)
	_line.setup(lo, hi, year)
	stage.set_zones_visible(false)
	var unit := String(L.get("unit", ""))
	var prompt := String(L.q) + ("  (%s)" % unit if unit != "" else "")
	timer_total = total
	stage.board.show_question(round_no - 1, prompt, [], "", Color("B8893B"), total)
	_hud("hud_question", [label, prompt, [], I18n.t("mh.nearest"), Color("F2B83C"), total, 0, Vector2i(0, 0)])
	_say(I18n.t("mh.nearest.how"), Color("F2C66A"), I18n.t("mh.nearest.how_sub"))
	_notify_all(String(L.q).substr(0, 90))
	_est_lock.clear()
	_est_typed = ""
	_est_typer = null
	for p in contestants:
		if p.controller is Controllers.Keyboard and _est_typer == null:
			_est_typer = p
		if p.controller is Controllers.Phone:
			_notify(p, {"t": "mode", "m": "num", "q": String(L.q), "unit": unit, "min": int(lo), "max": int(hi), "year": year})
	_bot_plan.clear()
	for p in contestants:
		p.frozen_input = false
		if _is_bot(p):
			var err := float(BOT_EST.get(level, 0.12))
			var ax := _line.x_of(a)
			var x := clampf(ax + rng.randfn(0.0, err) * (NumberLine.X1 - NumberLine.X0), NumberLine.X0, NumberLine.X1)
			_bot_plan[p] = {"x": x, "at": total - rng.randf_range(1.5, total * 0.7)}
			p.controller.go_to(Vector3(rng.randf_range(-2, 2), 0, 1.0))
	_q_t = 0.0
	time_left = total
	_tick = 99
	phase = "question"
	while time_left > 0.0 and phase == "question":
		await get_tree().physics_frame
	phase = "lock"
	_hud("hud_timer", [0.0, total])
	var guesses := {}
	for p in contestants:
		guesses[p] = _est_value(p)
		if p.controller is Controllers.Phone:
			_notify(p, {"t": "mode", "m": ""})
	_mh("est_readout", [[]])
	Sfx.play("drumroll", -6.0)
	_say(I18n.t("mh.and_answer"), Color("F2C66A"))
	await _wait(1.1)
	phase = "reveal"
	var at := NumberLine.fmt(a, year, I18n.lang) + (" " + unit if unit != "" else "")
	_line.drop_pin(a, at)
	Sfx.play("stamp", -2.0)
	var ranked := contestants.duplicate()
	ranked.sort_custom(func(x, y): return _line.distance(guesses[x], a) < _line.distance(guesses[y], a))
	var deltas := {}
	var pts := [150, 100, 50]
	var right: Array[Plush] = []
	var wrong: Array[Plush] = []
	for k in ranked.size():
		var p: Plush = ranked[k]
		var s: Dictionary = st[p]
		s.asked += 1
		s.est_sum += k + 1
		s.est_n += 1
		var d := _line.distance(guesses[p], a)
		var gain := int(pts[k]) if k < 3 and k < ranked.size() - (1 if ranked.size() > 1 else 0) else 0
		if ranked.size() == 1:
			gain = 150
		var bull := d < (0.035 if not _line.log_scale else 0.08)
		if bull:
			gain += 50
			s.bullseye += 1
			p.float_text(I18n.t("mh.bullseye"), Color("F6CF7B"), true)
		gain = int(round(gain * mult * (2.0 if p == joker else 1.0)))
		if gain > 0:
			s.points += gain
			s.correct += 1 if k == 0 else 0
			deltas[p] = gain
			p.float_text("+%d" % gain, Color("9BE38B"), k == 0)
			right.append(p)
		else:
			wrong.append(p)
			p.float_text(NumberLine.fmt(guesses[p], year, I18n.lang), Color("FF6B52"))
	var best: Plush = ranked[0]
	_say(I18n.t("mh.answer_was", {"x": at}), Color("9BE38B"), I18n.t("mh.nearest.best", {"name": best.player_name, "v": NumberLine.fmt(guesses[best], year, I18n.lang)}))
	_refresh_scores(deltas)
	_fill_meter(right.size() / float(max(1, contestants.size())), 0.0)
	_bot_reacts(right, wrong)
	await _wait(3.0)
	_line.queue_free()
	_line = null
	_hud("hud_question_hide")
	_refresh_scores()

## Oyuncunun tahmini: kilitlediyse o, değilse durduğu yer
func _est_value(p: Plush) -> float:
	if _est_lock.has(p):
		return float(_est_lock[p])
	return _line.value_at(p.global_position.x) if _line else 0.0

func _set_est(p: Plush, v: float) -> void:
	if _line == null:
		return
	v = clampf(v, _line.lo, _line.hi)
	var first := not _est_lock.has(p)
	_est_lock[p] = v
	_line.set_marker(p.get_instance_id(), v, pcolor(p))
	if first:
		Sfx.play("stamp", -8.0, 1.4)

func _tick_line() -> void:
	if _line == null:
		return
	var rows := []
	for p in contestants:
		if not is_instance_valid(p):
			continue
		# telefonun sayı klavyesi
		if p.controller is Controllers.Phone and phase == "question":
			var e: Dictionary = p.controller.take_number()
			if not e.is_empty():
				_set_est(p, float(e.get("v", 0)))
		var locked := _est_lock.has(p)
		var txt := NumberLine.fmt(_est_value(p), _line.year, I18n.lang)
		p.set_plate(p.player_name, ("✓ " if locked else "") + txt, pcolor(p))
		if not _is_bot(p):
			var typed := p == _est_typer and _est_typed != "" and not locked
			rows.append({"name": p.player_name, "color": pcolor(p), "text": _est_typed if typed else txt, "locked": locked, "typing": typed})
	_mh("est_readout", [rows])

## Zıplayan insan oyuncu tahminini durduğu yerde kilitler (yeniden zıplarsa günceller)
func _est_jump(p: Plush) -> void:
	if _line and phase == "question" and not _is_bot(p) and (game_id == "nearest" or game_id == "final"):
		_set_est(p, _line.value_at(p.global_position.x))

## Klavyeden rakam yazmak: 1. klavye oyuncusu; Enter kilitler, Backspace siler
func _unhandled_input(e: InputEvent) -> void:
	if _line == null or phase != "question" or _est_typer == null:
		return
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	var k := (e as InputEventKey).keycode
	var digit := -1
	if k >= KEY_0 and k <= KEY_9:
		digit = k - KEY_0
	elif k >= KEY_KP_0 and k <= KEY_KP_9:
		digit = k - KEY_KP_0
	if digit >= 0 and _est_typed.length() < 9:
		_est_typed += str(digit)
		_est_lock.erase(_est_typer)
		Sfx.play("tick", -8.0, 1.3)
	elif k == KEY_BACKSPACE and _est_typed != "":
		_est_typed = _est_typed.substr(0, _est_typed.length() - 1)
	elif (k == KEY_ENTER or k == KEY_KP_ENTER) and _est_typed != "":
		_set_est(_est_typer, float(_est_typed))
		_est_typed = ""
	else:
		return
	get_viewport().set_input_as_handled()

# ── 7 · Yağan Cevaplar ─────────────────────────────────────────────
func _g_falling() -> void:
	for i in 2:
		var q := _mc(["d1", "d2"][i])
		await _falling_one(I18n.t("mh.q_of", {"n": i + 1, "m": 2}), q)

func _falling_one(label: String, q: Dictionary) -> void:
	var total := answer_s + 2.0
	_cur_options = q.options
	_cur_correct = [q.correct]
	timer_total = total
	stage.set_zones_visible(false)
	stage.board.show_question(round_no - 1, q.prompt, q.options, q.cat, q.col, total)
	_hud("hud_question", [label, q.prompt, q.options, q.cat, q.col, total, 0, Vector2i(0, 0)])
	_say(I18n.t("mh.falling.how"), Color("F2C66A"), I18n.t("mh.falling.how_sub"))
	_catch.clear()
	_falls.clear()
	_bot_plan.clear()
	for p in contestants:
		p.frozen_input = false
		if _is_bot(p):
			_bot_plan[p] = {"fall": true, "smart": rng.randf() < _bot_acc(), "next": 0.0}
	_spawn_t = 0.0
	_q_t = 0.0
	time_left = total
	_tick = 99
	phase = "question"
	while time_left > 0.0 and phase == "question":
		await get_tree().physics_frame
	phase = "reveal"
	_hud("hud_timer", [0.0, total])
	_hud("hud_reveal", [q.correct])
	var res := {}
	for p in contestants:
		var c: Dictionary = _catch.get(p, {})
		res[p] = {"ok": c.get("ok", false), "t": float(c.get("t", total))}
	for b in _falls:
		if is_instance_valid(b.node):
			var n: Node3D = b.node
			n.create_tween().tween_property(n, "scale", Vector3.ONE * 0.01, 0.3).finished.connect(n.queue_free)
	_falls.clear()
	_score(res, total, 1.0)
	await _wait(2.6)
	_hud("hud_question_hide")

var _spawn_t := 0.0

func _tick_falls(d: float) -> void:
	_spawn_t -= d
	var per := 0.42 if contestants.size() > 4 else 0.55
	if _spawn_t <= 0.0 and time_left > 1.5:
		_spawn_t = per
		var giant := rng.randf() < 0.07
		var opt := rng.randi() % 4
		# doğru şık biraz daha sık düşsün ki herkese şans çıksın
		if rng.randf() < 0.3:
			opt = int(_cur_correct[0])
		_spawn_block(opt, giant)
	for b in _falls.duplicate():
		var n: Node3D = b.node
		if not is_instance_valid(n):
			_falls.erase(b)
			continue
		if n.position.y > 0.45:
			b.vy -= 9.0 * d * 0.35
			n.position.y = max(0.45, n.position.y + b.vy * d)
			n.rotation.y += d * b.spin
		else:
			b.life -= d
			if b.life <= 0.0:
				_falls.erase(b)
				n.queue_free()
				continue
		# yakalama
		for p in contestants:
			if not is_instance_valid(p) or not p.is_active():
				continue
			var dx := Vector2(p.global_position.x - n.position.x, p.global_position.z - n.position.z).length()
			var reach := 1.3 if b.giant else 1.0
			if dx < reach and n.position.y < p.global_position.y + 2.0:
				_caught(p, b)
				break

func _spawn_block(opt: int, giant: bool) -> void:
	var n := Node3D.new()
	stage.add_child(n)
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.2, 0.9, 0.5) if giant else Vector3(1.5, 0.55, 0.35)
	m.mesh = bm
	var col: Color = Color("FF3A2A") if giant else Pal.ZONE[opt]
	m.material_override = PropIcons.mat(col, 0.35, 0.0, 0.25)
	n.add_child(m)
	var big := Label3D.new()
	big.text = I18n.t("mh.falling.fake") if giant else Stage.LETTERS[opt]
	big.font = Pal.display()
	big.font_size = 90 if giant else 130
	big.pixel_size = 0.0055
	big.outline_size = 16
	big.outline_modulate = Color(0.05, 0.02, 0.02)
	big.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	big.no_depth_test = true
	big.position = Vector3(0, 0.95 if giant else 0.75, 0)
	n.add_child(big)
	if not giant:
		var small := Label3D.new()
		var txt := String(_cur_options[opt])
		small.text = txt if txt.length() <= 16 else txt.substr(0, 15) + "…"
		small.font = Pal.display()
		small.font_size = 48
		small.pixel_size = 0.0045
		small.outline_size = 10
		small.outline_modulate = Color(0.05, 0.02, 0.02)
		small.modulate = Pal.ZONE[opt].lightened(0.35)
		small.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		small.no_depth_test = true
		small.position = Vector3(0, 0.3, 0)
		n.add_child(small)
	n.position = Vector3(rng.randf_range(-5.5, 5.5), 8.0, rng.randf_range(-3.0, 2.4))
	_falls.append({"node": n, "opt": opt, "vy": -1.5, "life": 2.8, "giant": giant, "spin": rng.randf_range(-1.5, 1.5)})

func _caught(p: Plush, b: Dictionary) -> void:
	var n: Node3D = b.node
	_falls.erase(b)
	n.create_tween().tween_property(n, "scale", Vector3.ONE * 1.4, 0.12).finished.connect(n.queue_free)
	var c: Dictionary = _catch.get(p, {})
	if b.giant or int(b.opt) != int(_cur_correct[0]):
		st[p].stunned += 1
		p.tumble(Vector3(rng.randf_range(-1, 1), 0, 1).normalized(), 0.9 if b.giant else 0.5)
		p.float_text(I18n.t("mh.falling.stunned"), Color("FF6B52"))
		Sfx.play("bump", -2.0, 0.8)
		Sfx.play("dizzy", -5.0)
		return
	if c.get("ok", false):
		return
	_catch[p] = {"ok": true, "t": _q_t}
	st[p].caught += 1
	p.float_text("✓", Color("9BE38B"), true)
	Sfx.play("coin", -6.0, 1.2)

func _bot_fall(p: Plush, plan_d: Dictionary) -> void:
	plan_d.next = float(plan_d.next) - get_physics_process_delta_time() * fast_forward
	if plan_d.next > 0.0:
		return
	plan_d.next = rng.randf_range(0.25, 0.55)
	if _catch.get(p, {}).get("ok", false):
		p.controller.go_to(Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-2, 2)))
		return
	var best: Node3D = null
	var bd := 99.0
	for b in _falls:
		if b.giant:
			continue
		var good := int(b.opt) == int(_cur_correct[0])
		if good != bool(plan_d.smart) and rng.randf() < 0.85:
			continue
		var n: Node3D = b.node
		if float(b.life) < 0.6 and n.position.y <= 0.46:
			continue
		var dd := Vector2(p.global_position.x - n.position.x, p.global_position.z - n.position.z).length()
		if dd < bd:
			bd = dd
			best = n
	if best:
		p.controller.go_to(Vector3(best.position.x, 0, best.position.z))

# ── 8 · Final Mayhem ───────────────────────────────────────────────
func _g_final() -> void:
	_mh("chaos_show", [I18n.t("mh.final"), I18n.t("mh.final.d"), "bolt"])
	Sfx.play("war_drum", -2.0)
	await _wait(2.2)
	_mh("chaos_hide")
	var seq := ["tf", "doors", "zoom", "nearest", "sound", "tf"]
	var n := seq.size()
	for i in n:
		var kind: String = seq[i]
		var label := I18n.t("mh.final.step", {"n": i + 1, "m": n}) + " · " + I18n.t("mh.final.k." + kind)
		var total := 8.0
		match kind:
			"tf":
				var q := _tf()
				var res := await _zone_question(label, q.prompt, q.options, q.correct, total, q.cat, q.col)
				_answer_override = q.answer
				_score(res, total)
				_answer_override = ""
			"doors":
				var q2 := _mc("d1")
				_show_doors(true)
				var res2 := await _zone_question(label, q2.prompt, q2.options, [q2.correct], total + 1.5, q2.cat, q2.col)
				_score(res2, total + 1.5, 1.0, true)
				await _wait(1.6)
				_show_doors(false)
			"zoom":
				var q3 := _icons_q()
				var tg := rng.randi() % 4
				_mh("zoom_open", [q3.ids[tg], total, rng.randi()])
				var res3 := await _zone_question(label, I18n.t("mh.zoom.q"), q3.names, [tg], total)
				_mh("zoom_reveal")
				_score(res3, total, 2.0)
			"nearest":
				await _nearest_one(label, total + 2.0)
				continue
			"sound":
				var q4 := _sound_q()
				Music.stop(0.3)
				_mh("sound_show", [true, I18n.t("mh.sound.playing")])
				_play_sound(String(q4.id))
				var res4 := await _zone_question(label, q4.prompt, q4.options, [q4.correct], total)
				_score(res4, total)
		await _wait(2.0)
		_sound.stop()
		_mh("sound_show", [false])
		_mh("zoom_close")
		_hud("hud_question_hide")
		stage.board.reveal = -1

# ── ödüller ve final ───────────────────────────────────────────────
func compute_awards() -> Array:
	var out := []
	var taken := {}
	var cands := [
		["brain", "crown", func(p): return st[p].correct * 1000 + st[p].points / 10.0, func(p): return st[p].correct >= 1],
		["panic", "clock", func(p): return -st[p].fast_sum / max(1, st[p].fast_n), func(p): return st[p].fast_n >= 2],
		["guesser", "flag", func(p): return -st[p].est_sum / max(1, st[p].est_n), func(p): return st[p].est_n >= 1],
		["menace", "skull", func(p): return st[p].wrong, func(p): return st[p].wrong >= 2],
		["lastsec", "flame", func(p): return st[p].lastsec, func(p): return st[p].lastsec >= 1],
		["comeback", "arrow_l", func(p): return int(_worst_rank[p]) - (ranking().find(p) + 1), func(p): return int(_worst_rank[p]) - (ranking().find(p) + 1) >= 2],
		["jumper", "star", func(p): return st[p].jumps, func(p): return st[p].jumps >= 5],
	]
	for c in cands:
		var best: Plush = null
		var bv := -INF
		for p in contestants:
			if taken.has(p) or not c[3].call(p):
				continue
			var v: float = float(c[2].call(p))
			if v > bv:
				bv = v
				best = p
		if best:
			taken[best] = c[0]
			out.append({"id": c[0], "icon": c[1], "player": best, "name": best.player_name, "color": pcolor(best),
				"title": I18n.t("mh.award.%s" % c[0]), "desc": _award_desc(c[0], best)})
	for p in contestants:
		if not taken.has(p):
			taken[p] = "light"
			out.append({"id": "light", "icon": "star", "player": p, "name": p.player_name, "color": pcolor(p),
				"title": I18n.t("mh.award.light"), "desc": I18n.t("mh.award.light.d")})
	return out

func _award_desc(id: String, p: Plush) -> String:
	var s: Dictionary = st[p]
	match id:
		"brain": return I18n.t("mh.award.brain.d", {"n": s.correct})
		"panic": return I18n.t("mh.award.panic.d", {"s": "%.1f" % (s.fast_sum / max(1, s.fast_n))})
		"guesser": return I18n.t("mh.award.guesser.d", {"n": s.bullseye})
		"menace": return I18n.t("mh.award.menace.d", {"n": s.wrong})
		"lastsec": return I18n.t("mh.award.lastsec.d", {"n": s.lastsec})
		"comeback": return I18n.t("mh.award.comeback.d", {"n": _worst_rank[p]})
		"jumper": return I18n.t("mh.award.jumper.d", {"n": s.jumps})
	return ""

var awards: Array = []

func _awards() -> void:
	phase = "awards"
	stage.set_zones_visible(false)
	awards = compute_awards()
	var rows := []
	for a in awards:
		rows.append({"title": a.title, "desc": a.desc, "name": a.name, "color": a.color, "icon": a.icon})
		log_lines.append("AWARD %s %s" % [a.id, a.name])
	Music.play("trivia", 0.8)
	_mh("awards_show", [rows])
	Sfx.play("fanfare", -6.0, 1.1)
	StageFx.confetti(stage, Vector3(0, 0, 1.2), StageFx.CONFETTI, 160, 8.0)
	for i in rows.size():
		get_tree().create_timer(0.3 + i * 0.35).timeout.connect(func(): Sfx.play("award", -5.0, 1.0 + i * 0.03))
	await _wait(3.5 + rows.size() * 0.6)
	_mh("awards_hide")
	await _wait(0.4)

func _finish() -> void:
	if phase == "done":
		return
	phase = "done"
	Narrator.say("winner")
	Music.stop(0.8)
	Music.sting("victory")
	stage.set_zones_visible(false)
	stage.board.show_marquee(I18n.t("arena.lobby_board"))
	var rk := ranking()
	var names: Array = []
	for p in rk:
		names.append(p.player_name)
	var title := I18n.t("mh.winner", {"name": rk[0].player_name}) if rk.size() > 0 else I18n.t("arena.draw")
	log_lines.append("WIN " + (names[0] if names.size() > 0 else "-"))
	Profile.record_match(names, "mayhem")
	if game.has_method("on_match_finished"):
		game.on_match_finished("mayhem", names)
	Sfx.play("fanfare", -2.0)
	Sfx.play("applause", -6.0)
	StageFx.celebrate(stage)
	if rk.size() > 0 and is_instance_valid(rk[0]):
		stage.set_gold_target(rk[0])
		_notify(rk[0], {"t": "status", "text": I18n.t("house.status_win")})
	_say(title, Color("F2C66A"))
	var by_player := {}
	for a in awards:
		by_player[a.player] = a.title
	var rows := []
	for p in rk:
		var s: Dictionary = st[p]
		rows.append({"name": p.player_name, "color": pcolor(p), "points": s.points, "alive": true,
			"best_combo": s.best_streak, "correct": s.correct, "asked": s.asked, "award": by_player.get(p, "")})
	_hud("hud_timer", [0.0, 1.0])
	await _wait(1.6)
	if ui and ui.has_method("show_result"):
		ui.show_result(title, names, rows)
	finished.emit(names)

func on_fell_out(p: Plush) -> void:
	# kimse elenmez: sahneden düşen kulisten geri gelir
	Sfx.play("scream", -6.0, rng.randf_range(0.9, 1.2))
	await _wait(1.0)
	if is_instance_valid(p):
		p.revive(Vector3((-1.0 if rng.randf() < 0.5 else 1.0) * 5.4, 0.3, 3.3))
