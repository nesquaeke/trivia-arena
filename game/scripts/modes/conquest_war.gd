class_name ConquestWar
extends Node
## Conquest — Bil ve Fethet. Web sürümünün (v1.0-web) planı, 3D haritada:
##
##  Perde I  · Kale Kurulumu    tek tahmin sorusu sırayı belirler; herkes boş,
##                              başka kaleye komşu olmayan bir bölgeye kalesini kurar
##                              (1000 puanla başlanır, kale 3 kuledir)
##  Perde II · Toprak Paylaşımı tahmin sorularında en yakın 2, ikinci 1 bölge alır
##                              (kendi sınırına komşu); bölge 200, 2× bölge 400 puan.
##                              Boş toprak bitince…
##  Perde III· Savaş Çağı       sırayla komşu bir düşman bölgesine saldırılır.
##                              Saldıran ve savunan aynı 4 şıklı soruyu cevaplar;
##                              yalnız saldıran bilirse bölge (ya da bir kule) düşer,
##                              ikisi de bilirse tahmin sorusu ayırır. Son kulesi düşen
##                              elenir; toprağı ve puanı fatihe geçer.
##  Bitiş: savaş turları dolunca ya da tek kişi kalınca. Ayakta olanlar önde, puana göre.
##
## Sayılar aşağıdaki CFG'de; web sürümüyle aynıdır.

signal finished(ranking: Array)

const CFG := {
	"base": 1000, "land": 200, "rich": 400, "turn_budget": 26,
	"estimate_s": 20.0, "reveal_s": 5.2, "castle_s": 14.0, "claim_s": 12.0,
	"target_s": 12.0, "duel_s": 14.0, "tie_s": 14.0, "result_s": 2.8, "intro_s": 4.6,
}
const BOT_ACC := {"easy": [0.7, 0.55, 0.4], "normal": [0.86, 0.7, 0.55], "hard": [0.95, 0.86, 0.72]}
const BOT_SPREAD := {"easy": 0.2, "normal": 0.12, "hard": 0.07}

var game: Node
var stage: Stage
var ui: Node
var board: MapBoard
var contestants: Array[Plush] = []
var P := {}                       # Plush -> durum sözlüğü
var holder := {}                  # bölge -> Plush (ya da yok)
var capital := {}                 # bölge -> Plush (kalesi orada olan)
var shields := {}                 # bölge -> kule sayısı
var level := "normal"
var rng := RandomNumberGenerator.new()
var phase := "idle"
var act := 0
var q_index := 0                  # (main ile uyum için) sorulan soru sayısı
var time_left := 0.0
var timer_total := 10.0
var war_rounds := 3
var war_round := 0
var log_lines: Array[String] = []
var fast_forward := 1.0
var _used_est := {}
var _mouse_click := ""
var _mouse_hover := ""
var _answer_click := -1
var _typed := {}                  # klavyeyle yazılan rakamlar (tahmin)

# ── kurulum ─────────────────────────────────────────────────────────
func setup(p_game: Node, actors: Array[Plush], _p_timer: float, p_level: String, seed_val := 0) -> void:
	game = p_game
	stage = game.stage
	ui = game.ui
	contestants = actors.duplicate()
	level = p_level
	if seed_val != 0:
		rng.seed = seed_val
	else:
		rng.randomize()
	Questions.reset_used()
	board = MapBoard.new()
	board.name = "MapBoard"
	game.add_child(board)
	board.build()
	for id in board.order:
		holder[id] = null
	var ids: Array = board.order.duplicate()
	_shuffle(ids)
	for i in 3:
		board.set_rich(ids[i], true)
	var i := 0
	for p in contestants:
		var look: Dictionary = p.look
		var culture := String(look.get("culture", CultureCostume.CULTURES[i % CultureCostume.CULTURES.size()]))
		var castle := String(look.get("castle", CastleModel.STYLES[i % CastleModel.STYLES.size()]))
		P[p] = {"points": CFG.base, "dead": false, "culture": culture, "castle": castle,
			"correct": 0, "asked": 0, "captures": 0, "seat": i}
		p.visual.set_culture(culture)
		i += 1
	var n := contestants.size()
	# maç süresi (kurulum ekranı): kısa / normal / uzun
	var budget: float = {"short": 16.0, "normal": float(CFG.turn_budget), "long": 36.0}.get(String(Profile.setting("cq_length", "normal")), float(CFG.turn_budget))
	war_rounds = clampi(int(round(budget / maxf(2.0, n))), 2, 10)
	if ui and ui.has_signal("answer_clicked"):
		ui.answer_clicked.connect(_on_answer_clicked)
	if ui and ui.has_signal("ruler_input"):
		ui.ruler_input.connect(_on_ruler)

func _exit_tree() -> void:
	for p in contestants:
		if is_instance_valid(p):
			p.visual.set_culture("")
			p.frozen_input = false
			p.visible = true
			p.freeze = false
			p.hide_plate()
	if is_instance_valid(board):
		board.queue_free()
	if is_instance_valid(stage):
		stage.set_map_light(false)
	if ui and ui.has_signal("answer_clicked") and ui.answer_clicked.is_connected(_on_answer_clicked):
		ui.answer_clicked.disconnect(_on_answer_clicked)
	if ui and ui.has_signal("ruler_input") and ui.ruler_input.is_connected(_on_ruler):
		ui.ruler_input.disconnect(_on_ruler)
	if ui and ui.has_method("hud_estimate_close"):
		ui.hud_estimate_close()

func _shuffle(a: Array) -> void:
	for k in range(a.size() - 1, 0, -1):
		var j := rng.randi() % (k + 1)
		var t = a[k]
		a[k] = a[j]
		a[j] = t

# ── yardımcılar ─────────────────────────────────────────────────────
func _hud(method: String, args: Array = []) -> void:
	if ui and ui.has_method(method):
		ui.callv(method, args)

func _wait(s: float) -> void:
	await get_tree().create_timer(s / fast_forward, false, true).timeout

func _say(text: String, accent := Pal.GOLD, sub := "") -> void:
	log_lines.append(text)
	_hud("hud_message", [text, accent, sub])

func pcolor(p: Plush) -> Color:
	return PlushVisual.COLORS.get(String(p.look.get("color", "mustard")), Color.WHITE)

func is_bot(p: Plush) -> bool:
	return p.controller is Controllers.Bot

func alive() -> Array[Plush]:
	var out: Array[Plush] = []
	for p in contestants:
		if not P[p].dead:
			out.append(p)
	return out

func humans(list: Array) -> Array[Plush]:
	var out: Array[Plush] = []
	for p in list:
		if not is_bot(p):
			out.append(p)
	return out

func owned(p: Plush) -> Array:
	var out := []
	for id in board.order:
		if holder[id] == p:
			out.append(id)
	return out

func capital_of(p: Plush) -> String:
	for id in capital:
		if capital[id] == p:
			return id
	return ""

func free_regions() -> Array:
	var out := []
	for id in board.order:
		if holder[id] == null:
			out.append(id)
	return out

func value_of(id: String) -> int:
	return CFG.rich if board.region(id).rich else CFG.land

func _notify(p: Plush, msg: Dictionary) -> void:
	if game.has_method("notify_player"):
		game.notify_player(p, msg)

func _notify_all(text: String) -> void:
	if game.has_method("notify_phones"):
		game.notify_phones({"t": "status", "text": text})

func _cheer(p: Plush) -> void:
	if is_instance_valid(p) and p.state == Plush.State.NORMAL:
		p.apply_central_impulse(Vector3.UP * p.mass * 4.2)

func _refresh_scores(deltas := {}) -> void:
	var rows := []
	var turn_p = null
	if phase == "turn" and _turn_of != null:
		turn_p = _turn_of
	for p in _ranked():
		var s: Dictionary = P[p]
		var cap := capital_of(p)
		rows.append({"name": p.player_name, "color": pcolor(p), "value": s.points, "alive": not s.dead,
			"hp_mode": false, "combo": 0, "debuffs": [], "tiles": owned(p).size(), "look": p.look, "culture": s.culture,
			"towers": int(shields.get(cap, 0)) if cap != "" else -1, "delta": deltas.get(p, 0), "turn": p == turn_p})
		if not s.dead:
			p.set_plate(p.player_name, "", pcolor(p))
	_hud("hud_scores", [rows])

func _ranked() -> Array[Plush]:
	var r := contestants.duplicate()
	r.sort_custom(func(a, b):
		var sa: Dictionary = P[a]
		var sb: Dictionary = P[b]
		if sa.dead != sb.dead:
			return not sa.dead
		if sa.points != sb.points:
			return sa.points > sb.points
		return owned(a).size() > owned(b).size())
	return r

func ranking() -> Array[Plush]:
	return _ranked()

## Generaller maç boyunca kuliste bekler: harita onların taşlarıyla konuşur,
## skor şeridindeki portreler onları gösterir. Finalde selama çıkarlar.
func line_up() -> void:
	var n := contestants.size()
	for i in n:
		var p := contestants[i]
		p.teleport(Vector3((i - (n - 1) * 0.5) * 1.15, 0.05, 3.45), 0.0)
		p.frozen_input = true
		p.visible = false
		p.freeze = true
		if p.controller is Controllers.Bot:
			p.controller.mode = "idle"

## Final selamı: kostümlü generaller sahnenin önünde, kazanan ortada
func _curtain_call(rk: Array[Plush]) -> void:
	var n := rk.size()
	var order: Array[Plush] = []
	for i in n:
		# kazanan ortada, diğerleri sırayla iki yana
		if i % 2 == 0:
			order.append(rk[i])
		else:
			order.push_front(rk[i])
	for i in n:
		var p := order[i]
		p.visible = true
		p.freeze = false
		p.teleport(Vector3((i - (n - 1) * 0.5) * 1.2, 0.3, 3.2 if p != rk[0] else 3.6), 0.0)
		p.frozen_input = true
		p.visual.wobble = 0.6
	if game.cam:
		game.cam.set_custom({"pos": Vector3(0, 3.2, 9.6), "look": Vector3(0, 0.9, 2.4), "fov": 40.0, "h": 0.0, "sway": 0.0, "blend": 1.8})

# ── kamera ──────────────────────────────────────────────────────────
## Haritaya genel bakış: skor şeridine yer açmak için kadraj sağa kayık
func _cam_overview() -> void:
	if game.cam:
		game.cam.set_custom({"pos": Vector3(0.0, 9.4, 4.5), "look": Vector3(0.0, 0.0, -1.25), "fov": 50.0, "h": -0.6, "sway": 0.0, "blend": 2.0})

## Seçim: neredeyse tepeden, bütün bölgeler okunur
func _cam_top() -> void:
	if game.cam:
		game.cam.set_custom({"pos": Vector3(0.0, 12.8, 2.2), "look": Vector3(0.0, 0.0, -1.3), "fov": 44.0, "h": -0.75, "sway": 0.0, "blend": 2.4})

## İki bölgeye yakın plan (saldırı, düello): orta noktaya iner
func _cam_focus(ids: Array, dist := 1.0) -> void:
	if not game.cam or ids.is_empty():
		return
	var c := Vector3.ZERO
	for id in ids:
		c += board.seat(id)
	c /= ids.size()
	var spread := 0.0
	for id in ids:
		spread = maxf(spread, board.seat(id).distance_to(c))
	var d := (3.2 + spread * 1.1) * dist
	game.cam.set_custom({"pos": c + Vector3(0.0, d * 1.05, d * 0.8), "look": c + Vector3(0, 0.1, -0.15), "fov": 40.0, "h": 0.0, "sway": 0.0, "blend": 2.6})

## Kale düşüşü: kalenin çevresinde yavaşça dönen alçak çekim
func _cam_orbit(id: String) -> void:
	if not game.cam:
		return
	var c := board.seat(id) + Vector3(0, 0.35, 0)
	game.cam.set_custom({"pos": c + Vector3(0, 1.6, 2.6), "look": c, "fov": 38.0, "h": 0.0, "sway": 0.0, "blend": 3.0,
		"orbit": {"center": c, "radius": 3.3, "height": 1.9, "speed": 0.42, "angle": -0.5}})

# ── akış ────────────────────────────────────────────────────────────
func run() -> void:
	stage.set_zones_visible(false)
	stage.set_map_light(true)
	_cam_overview()
	_refresh_scores()
	await _wait(0.8)
	await _act_card(1)
	await _castle_act()
	if phase == "done":
		return
	await _act_card(2)
	var r := 0
	while not free_regions().is_empty() and phase != "done":
		r += 1
		await _expand(r)
	_say(I18n.t("cq.expandDone"), Pal.GOLD)
	await _wait(1.4)
	await _act_card(3)
	await _war()
	_finish()

func _act_card(n: int) -> void:
	act = n
	phase = "intro"
	var title := I18n.t("cq.act%d" % n)
	var chips := [I18n.t("cq.%d.chip1" % n), I18n.t("cq.%d.chip2" % n), I18n.t("cq.%d.chip3" % n)]
	_hud("hud_round_card", [n, title, I18n.t("cq.act%dd" % n), chips])
	_hud("hud_set_top", [title, I18n.t("round.kicker") + " " + Pal.roman(n)])
	_notify_all(title)
	Narrator.say("act%d_cq" % clampi(n, 1, 3))
	Sfx.play("sting", -3.0)
	Sfx.play("whoosh", -8.0, 0.9)
	await _wait(CFG.intro_s)
	_hud("hud_round_card_hide")
	await _wait(0.5)

# ── tahmin sorusu (bütün perdelerde ortak) ─────────────────────────
func _pick_estimate() -> Dictionary:
	# herkesin kestirebileceği sorular önce; "hard" işaretliler yalnız havuz tükenirse
	var pool: Array = Questions.estimate.filter(func(q): return not _used_est.has(q.tr.q) and not bool(q.get("hard", false)))
	if pool.is_empty():
		pool = Questions.estimate.filter(func(q): return not _used_est.has(q.tr.q))
	if pool.is_empty():
		_used_est.clear()
		pool = Questions.estimate
	var q: Dictionary = pool[rng.randi() % pool.size()]
	_used_est[q.tr.q] = true
	return q

func _est_text(q: Dictionary) -> Dictionary:
	var L: Dictionary = q.get(I18n.lang, q.tr)
	return {"q": String(L.q), "unit": String(L.get("unit", ""))}

## Katılanlardan tahmin toplar. Dönüş: [{p, guess, diff, at}] farka (sonra hıza) göre sıralı
func _estimate(who: Array[Plush], kicker: String) -> Array:
	var q := _pick_estimate()
	var tx := _est_text(q)
	var is_year := bool(q.get("year", false))
	var lo := float(q.min)
	var hi := float(q.max)
	var logk := EstimatePanel.is_log(lo, hi, is_year)
	var start_v := EstimatePanel.nice(EstimatePanel.from_u(0.5, lo, hi, logk), is_year)
	if phase != "duel_reveal":
		_cam_overview()
	var state := {}
	var entries := []
	var p1: Plush = game.player_one() if game.has_method("player_one") else null
	_mouse_p = null
	for i in who.size():
		var p := who[i]
		var bot := is_bot(p)
		var phone: bool = not bot and p.controller != null and p.controller.is_phone()
		state[p] = {"value": start_v, "u": 0.5, "locked": false, "at": INF, "hold": 0.0, "rep": 0.0, "idx": i, "typed": ""}
		entries.append({"name": p.player_name, "color": pcolor(p), "value": start_v, "locked": false,
			"show": not bot and not phone, "human": not bot})
		if phone:
			_notify(p, {"t": "mode", "m": "num", "q": tx.q, "unit": tx.unit, "min": int(lo), "max": int(hi), "year": is_year})
		elif not bot:
			_notify(p, {"t": "status", "text": I18n.t("cq.phone_est")})
		if not bot and not phone and (_mouse_p == null or p == p1):
			_mouse_p = p
	_ruler.clear()
	Music.play("think", 0.8)
	Narrator.say("estimate")
	_hud("hud_estimate_open", [kicker, tx.q, tx.unit, lo, hi, is_year, entries, _mouse_p != null])
	Sfx.play("drum", -4.0, 1.0)
	# botlar
	var guesses := {}
	var times := {}
	var spread: float = float(BOT_SPREAD.get(level, 0.12))
	for p in who:
		if is_bot(p):
			var bu := EstimatePanel.to_u(float(q.a), lo, hi, logk) + rng.randfn(0.0, spread * 0.8)
			guesses[p] = EstimatePanel.nice(EstimatePanel.from_u(bu, lo, hi, logk), is_year)
			times[p] = rng.randf_range(2.5, 10.0)
	phase = "estimate"
	q_index += 1
	timer_total = CFG.estimate_s
	time_left = timer_total
	var t := 0.0
	while time_left > 0.0:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time() * fast_forward
		time_left -= dt
		t += dt
		_hud("hud_timer", [maxf(0.0, time_left), timer_total])
		if time_left < 5.0 and time_left + dt >= 5.0:
			Narrator.say("five")
		if time_left < 5.0 and int(ceil(time_left)) != int(ceil(time_left + dt)):
			Sfx.play("heartbeat", -5.0)
		var all_locked := true
		for p in who:
			var s: Dictionary = state[p]
			if is_bot(p):
				if not s.locked and t >= float(times[p]):
					s.locked = true
					s.at = t
					_hud("hud_estimate_entry", [s.idx, int(guesses[p]), true])
				if not s.locked:
					all_locked = false
				continue
			var was := bool(s.locked)
			var before := int(s.value)
			_ruler_input(p, s, lo, hi, logk, is_year, dt)
			if s.locked and not was:
				s.at = t
			if not s.locked:
				all_locked = false
			if int(s.value) != before or bool(s.locked) != was:
				_hud("hud_estimate_entry", [s.idx, int(s.value), bool(s.locked)])
		if all_locked:
			await _wait(0.5)
			break
	for p in who:
		if not is_bot(p):
			guesses[p] = int(state[p].value)
			times[p] = float(state[p].at)
			if p.controller != null and p.controller.is_phone():
				_notify(p, {"t": "mode", "m": "pad"})
	var ranked := []
	for p in who:
		var g := int(guesses.get(p, start_v))
		ranked.append({"p": p, "guess": g, "diff": absi(g - int(q.a)), "at": float(times.get(p, INF))})
	ranked.sort_custom(func(a, b): return a.diff < b.diff or (a.diff == b.diff and a.at < b.at))
	# açıklama
	phase = "reveal"
	_hud("hud_timer", [0.0, timer_total])
	var rows := []
	for r in ranked:
		rows.append({"i": state[r.p].idx, "guess": r.guess, "diff": r.diff})
	var ans: String = EstimatePanel.group(int(q.a), is_year) + ((" " + String(tx.unit)) if String(tx.unit) != "" else "")
	_hud("hud_estimate_reveal", [int(q.a), ans, rows])
	Narrator.say("spot_on" if not ranked.is_empty() and int(ranked[0].diff) == 0 else "reveal")
	for r in ranked:
		if int(r.diff) == 0 and not is_bot(r.p):
			SteamService.unlock("SPOT_ON")
	log_lines.append("EST %s → %s" % [str(q.a), ranked[0].p.player_name])
	await _wait(1.1)
	Sfx.play("ding", -3.0, 1.2)
	if not ranked.is_empty():
		_cheer(ranked[0].p)
	await _wait(CFG.reveal_s)
	_hud("hud_estimate_close")
	Music.play("conquest", 1.2)
	return ranked

var _mouse_p: Plush = null
var _pick_top_for_bots := true
var _ruler := {}                  # fare sürüklemesi: {"u": float, "release": bool}

## Cetvel girdisi:
##   sağ/sol   sancağı kaydırır, basılı tuttukça hızlanır
##   yukarı/aşağı ince ayar (değerin büyüklüğüne göre adım), basılı tutunca tekrarlar
##   zıpla     kilitle · omuz: kilidi aç
##   klavye    rakam yaz, Enter kilitle (1. oyuncu) · fare: cetvelde sürükle
##   telefon   sayı klavyesi
func _ruler_input(p: Plush, s: Dictionary, lo: float, hi: float, logk: bool, is_year: bool, dt: float) -> void:
	var ctrl = p.controller
	if ctrl == null:
		return
	# telefon sayı klavyesi
	var num: Dictionary = ctrl.take_number()
	if not num.is_empty():
		s.value = clampi(int(num.v), int(lo) if lo < 0 else 0, int(hi) * 10)
		s.u = EstimatePanel.to_u(float(s.value), lo, hi, logk)
		s.locked = bool(num.lock)
		return
	if ctrl.consume_shove() and s.locked:
		s.locked = false
		Sfx.play("click", -8.0, 0.8)
	if s.locked:
		ctrl.consume_jump()
		return
	var mv: Vector2 = ctrl.get_move()
	if absf(mv.x) > 0.25 and absf(mv.x) >= absf(mv.y):
		s.hold = float(s.hold) + dt
		var speed := lerpf(0.07, 0.75, clampf((float(s.hold) - 0.15) / 1.6, 0.0, 1.0)) * signf(mv.x) * absf(mv.x)
		s.u = clampf(float(s.u) + speed * dt, 0.0, 1.0)
		var nv := EstimatePanel.nice(EstimatePanel.from_u(s.u, lo, hi, logk), is_year)
		if nv != int(s.value):
			s.value = nv
			if int(Time.get_ticks_msec() / 60) % 2 == 0:
				Sfx.play("tick", -16.0, 1.2 + float(s.u) * 0.8)
		s.typed = ""
	else:
		s.hold = 0.0
	if absf(mv.y) > 0.5 and absf(mv.y) > absf(mv.x):
		s.rep = float(s.rep) - dt
		if s.rep <= 0.0:
			var step := EstimatePanel.fine_step(float(s.value), is_year)
			s.value = clampi(int(s.value) + (step if mv.y < 0.0 else -step), 0, int(hi) * 10)
			s.u = EstimatePanel.to_u(float(s.value), lo, hi, logk)
			s.rep = 0.3 if s.get("rep_first", true) else 0.06
			s.rep_first = false
			Sfx.play("tick", -12.0, 1.5 if mv.y < 0.0 else 1.3)
			s.typed = ""
	else:
		s.rep = 0.0
		s.rep_first = true
	# klavyeyle yazılan rakamlar
	if _typed.has(p):
		var buf := String(s.typed)
		for k in _typed[p]:
			if k == -1:
				buf = buf.substr(0, maxi(0, buf.length() - 1))
			elif k == -2:
				s.locked = true
			elif buf.length() < 9:
				buf += str(k)
		_typed.erase(p)
		s.typed = buf
		if buf != "":
			s.value = int(buf)
			s.u = EstimatePanel.to_u(float(s.value), lo, hi, logk)
		Sfx.play("tick", -10.0, 1.4)
	# fare
	if p == _mouse_p and not _ruler.is_empty():
		s.u = float(_ruler.u)
		s.value = EstimatePanel.nice(EstimatePanel.from_u(s.u, lo, hi, logk), is_year)
		s.typed = ""
		_ruler.clear()
	if ctrl.consume_jump():
		s.locked = true

## 2. klavye oyuncusu (oklar + Enter) varsa Enter onun zıplamasıdır
func _second_keyboard() -> bool:
	for p in contestants:
		if p.controller is Controllers.Keyboard and p.controller.set_id == 1:
			return true
	return false

func _on_ruler(u: float, _release: bool) -> void:
	_ruler = {"u": u}

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and phase == "estimate":
		var p1: Plush = game.player_one() if game.has_method("player_one") else null
		if p1 == null or is_bot(p1):
			return
		var k: int = -99
		if e.keycode >= KEY_0 and e.keycode <= KEY_9:
			k = e.keycode - KEY_0
		elif e.keycode >= KEY_KP_0 and e.keycode <= KEY_KP_9:
			k = e.keycode - KEY_KP_0
		elif e.keycode == KEY_BACKSPACE:
			k = -1
		elif e.keycode == KEY_ENTER and not _second_keyboard():
			k = -2
		if k != -99:
			if not _typed.has(p1):
				_typed[p1] = []
			_typed[p1].append(k)
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and phase == "pick":
		_mouse_click = board.region_under_mouse(game.cam, e.position)
	elif e is InputEventMouseMotion and phase == "pick":
		_mouse_hover = board.region_under_mouse(game.cam, e.position)

func _on_answer_clicked(i: int) -> void:
	_answer_click = i

# ── bölge seçimi (kale, toprak, hedef) ─────────────────────────────
## İnsan için imleçle, bot için puanlamayla bölge seçer
func _pick_region(p: Plush, options: Array, title: String, sub: String, limit: float, bot_score: Callable) -> String:
	if options.is_empty():
		return ""
	board.clear_marks()
	for id in options:
		board.set_mark(id, "pickable")
	if not is_bot(p) or _pick_top_for_bots:
		_cam_top()
	_say(title, pcolor(p).lightened(0.3), sub if not is_bot(p) else "")
	if is_bot(p):
		var best: String = options[0]
		var bs := -INF
		for id in options:
			var v: float = bot_score.call(id)
			if v > bs:
				bs = v
				best = id
		await _wait(0.5)
		board.set_mark(best, "cursor")
		await _wait(0.7)
		board.clear_marks()
		return best
	_notify(p, {"t": "status", "text": I18n.t("cq.phone_pick")})
	var cur: String = options[0]
	var own := owned(p)
	if not own.is_empty():
		var anchor: Vector3 = board.region(own[0]).seat
		var bd := INF
		for id in options:
			var d: float = board.region(id).seat.distance_to(anchor)
			if d < bd:
				bd = d
				cur = id
	board.set_mark(cur, "cursor")
	_hud("hud_message", [title, pcolor(p).lightened(0.3), _region_info(cur)])
	phase = "pick"
	_mouse_click = ""
	_mouse_hover = ""
	timer_total = limit
	time_left = limit
	var cool := 0.0
	var chosen := ""
	var ctrl = p.controller
	while time_left > 0.0 and chosen == "":
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time() * fast_forward
		time_left -= dt
		cool -= dt
		_hud("hud_timer", [maxf(0.0, time_left), timer_total])
		var next := cur
		if ctrl:
			var mv: Vector2 = ctrl.get_move()
			if mv.length() > 0.55 and cool <= 0.0:
				next = board.step_towards(cur, mv.normalized(), options)
				cool = 0.25
			elif mv.length() < 0.3:
				cool = minf(cool, 0.0)
			if ctrl.consume_jump():
				chosen = cur
			ctrl.consume_shove()
		if _mouse_hover != "" and options.has(_mouse_hover):
			next = _mouse_hover
			_mouse_hover = ""
		if _mouse_click != "":
			if options.has(_mouse_click):
				chosen = _mouse_click
			else:
				Sfx.play("buzz", -10.0, 1.4)
			_mouse_click = ""
		if next != cur and chosen == "":
			board.set_mark(cur, "pickable")
			cur = next
			board.set_mark(cur, "cursor")
			Sfx.play("tick", -10.0, 1.4)
			_hud("hud_message", [title, pcolor(p).lightened(0.3), _region_info(cur)])
	if chosen == "":
		var best: String = cur
		var bs := -INF
		for id in options:
			var v: float = bot_score.call(id)
			if v > bs:
				bs = v
				best = id
		chosen = best
		log_lines.append("AUTOPICK")
	phase = "picked"
	Sfx.play("click", -3.0, 0.9)
	board.clear_marks()
	return chosen

# ── Perde I: kaleler ───────────────────────────────────────────────
func _castle_act() -> void:
	var ranked := await _estimate(contestants, I18n.t("cq.act1") + " · " + I18n.t("cq.estimate"))
	_say(I18n.t("cq.castleOrder", {"name": ranked[0].p.player_name}), Pal.GOLD)
	for r in ranked:
		var p: Plush = r.p
		var opts := _castle_options()
		if opts.is_empty():
			break
		var id := await _pick_region(p, opts, I18n.t("cq.castleTitle", {"name": p.player_name}), I18n.t("cq.castleSub"),
			CFG.castle_s, func(x): return board.region(x).adj.size() * 1.4 + (2.0 if board.region(x).rich else 0.0) + rng.randf() * 1.5)
		_build_castle(p, id)
		await _wait(0.9)
	_say(I18n.t("cq.castlesDone"), Pal.GOLD)
	await _wait(1.2)

## İmleçteki bölge: adı, değeri, sahibi / kalesi
func _region_info(id: String) -> String:
	var parts := [board.region_name(id)]
	parts.append(I18n.t("cq.worth", {"p": value_of(id)}) + ("  ·  2×" if board.region(id).rich else ""))
	var o = holder.get(id)
	if o != null:
		if capital.has(id):
			parts.append(I18n.t("cq.castleOf", {"name": o.player_name, "n": int(shields.get(id, 0))}))
		else:
			parts.append(I18n.t("cq.landOf", {"name": o.player_name}))
	return "  ·  ".join(parts)

func _castle_options() -> Array:
	var free := free_regions()
	var roomy := free.filter(func(id):
		for n in board.region(id).adj:
			if capital.has(n):
				return false
		return true)
	return roomy if not roomy.is_empty() else free

func _build_castle(p: Plush, id: String) -> void:
	holder[id] = p
	capital[id] = p
	shields[id] = 3
	board.set_owner_color(id, pcolor(p))
	var c := CastleModel.new(String(P[p].castle), pcolor(p))
	c.set_meta("base_scale", Vector3.ONE * 1.05)
	board.set_piece(id, c)
	Sfx.play("war_drum", -2.0, 1.1)
	Sfx.play("stamp", -4.0, 0.8)
	if game.cam:
		game.cam.add_trauma(0.25)
	_say(I18n.t("cq.castleBuilt", {"a": p.player_name, "t": board.region_name(id)}), pcolor(p).lightened(0.3))
	log_lines.append("CASTLE %s %s" % [p.player_name, id])
	_cheer(p)
	_refresh_scores()

# ── Perde II: toprak paylaşımı ─────────────────────────────────────
func _expand(r: int) -> void:
	var ranked := await _estimate(alive(), I18n.t("cq.act2") + " · " + I18n.t("cq.estimate_n", {"n": r}))
	var queue := []
	if ranked.size() > 0:
		queue.append([ranked[0].p, 2])
	if ranked.size() > 1:
		queue.append([ranked[1].p, 1])
	for job in queue:
		var p: Plush = job[0]
		for k in int(job[1]):
			var opts := _claim_options(p)
			if opts.is_empty():
				break
			var cap := capital_of(p)
			var id := await _pick_region(p, opts, I18n.t("cq.claimTitle", {"name": p.player_name, "n": int(job[1]) - k}), I18n.t("cq.claimSub"),
				CFG.claim_s, func(x):
					var v := 5.0 if board.region(x).rich else 0.0
					if cap != "":
						v -= board.region(x).seat.distance_to(board.region(cap).seat)
					return v + rng.randf() * 0.3)
			_claim(p, id)
			await _wait(0.6)

func _claim_options(p: Plush) -> Array:
	var free := free_regions()
	var adj := free.filter(func(id):
		for n in board.region(id).adj:
			if holder.get(n) == p:
				return true
		return false)
	return adj if not adj.is_empty() else free

func _place_warrior(p: Plush, id: String) -> void:
	var fig := ConquestPiece.new({"color": String(p.look.get("color", "mustard"))}, String(P[p].culture))
	board.set_piece(id, fig)

func _claim(p: Plush, id: String) -> void:
	holder[id] = p
	var v := value_of(id)
	P[p].points += v
	board.set_owner_color(id, pcolor(p))
	_place_warrior(p, id)
	Sfx.play("claim", -4.0, 1.0 + rng.randf() * 0.1)
	_say(I18n.t("cq.picked", {"a": p.player_name, "t": board.region_name(id), "p": v}), pcolor(p).lightened(0.3))
	log_lines.append("CLAIM %s %s" % [p.player_name, id])
	_refresh_scores({p: v})

# ── Perde III: savaş ───────────────────────────────────────────────
var _turn_of: Plush = null

func _war() -> void:
	for rr in war_rounds:
		war_round = rr
		if rr == war_rounds - 1:
			Narrator.say("last_round")
		var order := alive()
		for p in order:
			if phase == "done" or alive().size() <= 1:
				return
			if P[p].dead:
				continue
			await _turn(p, rr)
		if alive().size() <= 1:
			return

func legal_targets(p: Plush) -> Array:
	var set := {}
	for id in owned(p):
		for n in board.region(id).adj:
			var o = holder.get(n)
			if o != null and o != p:
				set[n] = true
	return set.keys()

func _turn(p: Plush, rr: int) -> void:
	_turn_of = p
	phase = "turn"
	_hud("hud_set_top", [I18n.t("cq.act3"), I18n.t("cq.round", {"n": rr + 1, "m": war_rounds})])
	_refresh_scores()
	var targets := legal_targets(p)
	if targets.is_empty():
		_say(I18n.t("cq.noTargets", {"name": p.player_name}), Pal.MUTED)
		await _wait(1.0)
		return
	var id := await _pick_region(p, targets, I18n.t("cq.turnOf", {"name": p.player_name}), I18n.t("cq.pickTarget"), CFG.target_s,
		func(x): return _bot_target_score(p, x))
	var d: Plush = holder[id]
	# saldırı oku
	var from := ""
	var bd := INF
	for o in owned(p):
		var dist: float = board.region(o).seat.distance_to(board.region(id).seat)
		if board.region(o).adj.has(id) and dist < bd:
			bd = dist
			from = o
	_cam_focus([from if from != "" else id, id], 0.8)
	Sfx.play("war_horn", -3.0)
	_say(I18n.t("cq.attackCall", {"a": p.player_name, "t": board.region_name(id)}), pcolor(p).lightened(0.3))
	await _wait(0.5)
	board.attack_arc(from if from != "" else id, id, pcolor(p))
	board.flash(id)
	Sfx.play("whoosh", -2.0, 1.2)
	log_lines.append("ATTACK %s %s %s" % [p.player_name, d.player_name, id])
	await _wait(1.1)
	Sfx.play("war_drum", -2.0)
	if game.cam:
		game.cam.add_trauma(0.2)
	await _wait(0.3)
	_hud("hud_duel_splash", [{"name": p.player_name, "color": pcolor(p), "look": p.look, "culture": P[p].culture},
		{"name": d.player_name, "color": pcolor(d), "look": d.look, "culture": P[d].culture}, board.region_name(id)])
	_cam_focus([from if from != "" else id, id], 1.35)
	Narrator.say("duel")
	await _wait(DuelSplash.DUR - 0.1)
	var win := await _duel(p, d)
	_cam_focus([id], 0.75)
	await _resolve(p, d, id, win)
	_turn_of = null
	_cam_overview()

func _bot_target_score(p: Plush, id: String) -> float:
	var v := rng.randf() * 2.0
	if capital.has(id):
		v += (4 - int(shields.get(id, 3))) * 3.0
	else:
		v += 4.0
	if board.region(id).rich:
		v += 3.0
	var o = holder.get(id)
	if o != null and P[o].points > P[p].points:
		v += 2.0
	return v

## Düello zorluğu: ilk turlarda çoğunlukla kolay, son turlarda biraz orta
func _duel_tier() -> String:
	var late := war_rounds > 0 and float(war_round) / war_rounds >= 0.5
	var r := rng.randf()
	if not late:
		return "d1" if r < 0.8 else "d2"
	return "d1" if r < 0.55 else ("d2" if r < 0.95 else "d3")

## Düello: iki kişi aynı soruyu cevaplar. Dönüş: saldıran kazandı mı?
func _duel(a: Plush, d: Plush) -> bool:
	phase = "duel"
	var tiers := ["d1", "d2", "d3"]
	var tier := _duel_tier()
	var item := Questions.draw_from(tier, "", rng)
	# uzun, okunması zor sorular düelloya uygun değil: birkaç kez yeniden çek
	for _k in 6:
		if String(Questions.face(item, I18n.lang).prompt).length() <= 95:
			break
		item = Questions.draw_from(tier, "", rng)
	var face := Questions.face(item, I18n.lang)
	var extra := clampf((String(face.prompt).length() - 60) * 0.03, 0.0, 4.0)
	timer_total = CFG.duel_s + extra
	time_left = timer_total
	var label := I18n.t("cq.duel", {"a": a.player_name, "d": d.player_name})
	_hud("hud_question", [label, face.prompt, face.options, face.cat_name, face.cat_color, timer_total, 0, Vector2i(0, 0)])
	Music.play("think", 0.6)
	_say(I18n.t("cq.duel_s"), Pal.BAD, I18n.t("cq.duelSub", {"a": a.player_name, "d": d.player_name}))
	var duellists: Array[Plush] = [a, d]
	var st := {}
	for p in duellists:
		st[p] = {"sel": 0, "locked": false, "ans": -1, "at": INF, "cool": 0.0}
		P[p].asked += 1
		if is_bot(p):
			var acc: float = float(BOT_ACC.get(level, BOT_ACC.normal)[tiers.find(tier)])
			var ok := rng.randf() < acc
			var wrong := [0, 1, 2, 3]
			wrong.erase(face.correct)
			st[p].ans = face.correct if ok else wrong[rng.randi() % 3]
			st[p].at = clampf((1.0 + String(face.prompt).length() * 0.03) * rng.randf_range(0.7, 1.4), 1.0, timer_total - 0.5)
		elif p.controller != null and p.controller.is_phone():
			_notify(p, {"t": "mode", "m": "abcd", "q": face.prompt, "options": face.options})
		else:
			_notify(p, {"t": "status", "text": I18n.t("cq.phone_duel")})
	var p1: Plush = game.player_one() if game.has_method("player_one") else null
	var mouse_p: Plush = p1 if duellists.has(p1) and not is_bot(p1) else null
	if mouse_p == null:
		for p in duellists:
			if not is_bot(p):
				mouse_p = p
				break
	_answer_click = -1
	var t := 0.0
	while time_left > 0.0:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time() * fast_forward
		time_left -= dt
		t += dt
		_hud("hud_timer", [maxf(0.0, time_left), timer_total])
		var done := true
		for p in duellists:
			var s: Dictionary = st[p]
			if is_bot(p):
				if not s.locked and t >= float(s.at):
					s.locked = true
					s.sel = s.ans
				if not s.locked:
					done = false
				continue
			if s.locked:
				continue
			done = false
			var ctrl = p.controller
			s.cool -= dt
			if ctrl:
				var tap: int = ctrl.take_answer()
				if tap >= 0:
					s.sel = tap
					s.ans = tap
					s.locked = true
					s.at = t
					continue
				var mv: Vector2 = ctrl.get_move()
				if s.cool <= 0.0 and absf(mv.x) + absf(mv.y) > 0.6:
					var dir := 1 if (mv.x > 0.5 or mv.y > 0.5) else -1
					s.sel = (int(s.sel) + dir + 4) % 4
					s.cool = 0.22
					Sfx.play("tick", -10.0, 1.3 + s.sel * 0.05)
				elif absf(mv.x) + absf(mv.y) < 0.3:
					s.cool = minf(s.cool, 0.0)
				if ctrl.consume_jump():
					s.locked = true
					s.ans = s.sel
					s.at = t
				ctrl.consume_shove()
			if p == mouse_p and _answer_click >= 0:
				s.sel = _answer_click
				s.ans = _answer_click
				s.locked = true
				s.at = t
				_answer_click = -1
		var marks := []
		for p in duellists:
			var s: Dictionary = st[p]
			# botların seçimi kilitlenene kadar gizli
			if is_bot(p) and not s.locked:
				continue
			marks.append({"idx": s.sel, "color": pcolor(p), "name": p.player_name, "locked": s.locked})
		_hud("hud_duel_marks", [marks, mouse_p != null and not st[mouse_p].locked])
		if done:
			break
	for p in duellists:
		if not is_bot(p) and p.controller != null and p.controller.is_phone():
			_notify(p, {"t": "mode", "m": "pad"})
	var ra: bool = st[a].locked and int(st[a].ans) == int(face.correct)
	var rd: bool = st[d].locked and int(st[d].ans) == int(face.correct)
	if ra:
		P[a].correct += 1
	if rd:
		P[d].correct += 1
	phase = "duel_reveal"
	_hud("hud_timer", [0.0, timer_total])
	_hud("hud_reveal", [face.correct])
	Sfx.play("ding" if ra or rd else "buzz", -4.0)
	log_lines.append("DUEL %s:%s %s:%s" % [a.player_name, str(ra), d.player_name, str(rd)])
	await _wait(1.8)
	_hud("hud_question_hide")
	Music.play("conquest", 1.0)
	if ra and rd:
		_say(I18n.t("cq.tieBreak"), Pal.GOLD)
		Narrator.say("tie")
		await _wait(1.0)
		var duo: Array[Plush] = [a, d]
		var ranked := await _estimate(duo, I18n.t("cq.tieBreak"))
		return ranked[0].p == a
	return ra and not rd

func _resolve(a: Plush, d: Plush, id: String, win: bool) -> void:
	phase = "resolve"
	board.flash(id)
	if not win:
		_say(I18n.t("cq.repelled", {"d": d.player_name}), pcolor(d).lightened(0.3))
		Narrator.say("repel")
		Sfx.play("aww", -6.0)
		Sfx.play("buzz", -4.0, 0.8)
		_cheer(d)
		log_lines.append("REPEL %s" % d.player_name)
	elif capital.has(id):
		shields[id] = int(shields[id]) - 1
		P[a].captures += 1
		var castle := board.piece(id) as CastleModel
		if shields[id] > 0:
			_cam_focus([id], 0.55)
			await _wait(0.35)
			if castle:
				castle.set_towers(shields[id])
			Narrator.say("tower")
			Sfx.play("war_drum", 0.0, 0.9)
			Sfx.play("thud", -2.0, 0.6)
			if game.cam:
				game.cam.add_trauma(0.35)
			_say(I18n.t("cq.towerFell", {"a": a.player_name, "d": d.player_name, "n": shields[id]}), pcolor(a).lightened(0.3))
			log_lines.append("TOWER %s %d" % [d.player_name, shields[id]])
			_cheer(a)
		else:
			_cam_orbit(id)
			Music.play("", 0.8)
			await _wait(0.6)
			if not is_bot(a):
				SteamService.unlock("CASTLE_BREAKER")
			if castle:
				castle.collapse()
			Narrator.say("castle_fall")
			Sfx.play("ooh", -3.0)
			Sfx.play("collapse", 0.0)
			Sfx.play("sting", -4.0)
			if game.cam:
				game.cam.add_trauma(0.45)
			await _wait(2.6)
			Music.play("conquest", 1.5)
			var loot: int = P[d].points
			P[a].points += loot
			P[d].points = 0
			P[d].dead = true
			capital.erase(id)
			shields.erase(id)
			_hud("hud_message", [I18n.t("cq.bannerFall"), Pal.BAD, I18n.t("cq.castleFell", {"a": a.player_name, "d": d.player_name, "p": loot})])
			log_lines.append("FALL %s" % d.player_name)
			await _wait(1.2)
			for r in owned(d):
				holder[r] = a
				board.set_owner_color(r, pcolor(a))
				_place_warrior(a, r)
				await _wait(0.12)
			if is_instance_valid(d):
				d.visual.wobble = 1.0
				d.apply_central_impulse(Vector3(0, 2.0, -1.2) * d.mass)
			_notify(d, {"t": "out"})
			_cheer(a)
			_refresh_scores({a: loot, d: -loot})
			await _wait(CFG.result_s)
			return
	else:
		var loot := mini(value_of(id), maxi(0, int(P[d].points)))
		P[d].lost = int(P[d].get("lost", 0)) + 1
		holder[id] = a
		P[a].points += loot
		P[d].points -= loot
		P[a].captures += 1
		board.set_owner_color(id, pcolor(a))
		_place_warrior(a, id)
		Sfx.play("claim", -2.0)
		_say(I18n.t("cq.captured", {"a": a.player_name, "t": board.region_name(id), "p": loot}), pcolor(a).lightened(0.3))
		Narrator.say("capture")
		Sfx.play("coin", -4.0)
		log_lines.append("CAPTURE %s %s" % [a.player_name, id])
		_cheer(a)
		_refresh_scores({a: loot, d: -loot})
		await _wait(CFG.result_s)
		return
	_refresh_scores()
	await _wait(CFG.result_s)

# ── bitiş ───────────────────────────────────────────────────────────
func on_fell_out(p: Plush) -> void:
	await _wait(1.0)
	if is_instance_valid(p):
		p.revive(Vector3(p.global_position.x, 0.3, 3.45))
		p.frozen_input = true

func _finish() -> void:
	if phase == "done":
		return
	phase = "done"
	board.clear_marks()
	var rk := _ranked()
	var names: Array = []
	for p in rk:
		names.append(p.player_name)
	var title := I18n.t("cq.winner", {"name": rk[0].player_name}) if rk.size() > 0 else I18n.t("arena.draw")
	log_lines.append("WIN " + (names[0] if names.size() > 0 else "-"))
	Profile.record_match(names, "conquest")
	if game.has_method("on_match_finished"):
		game.on_match_finished("conquest", names, {"untouched": rk.size() > 0 and int(P[rk[0]].get("lost", 0)) == 0})
	Narrator.say("winner")
	Sfx.play("cheer", -3.0)
	Music.stop(0.6)
	Music.sting("victory")
	Sfx.play("applause", -6.0)
	_curtain_call(rk)
	if rk.size() > 0:
		stage.set_gold_target(rk[0])
		_notify(rk[0], {"t": "status", "text": I18n.t("house.status_win")})
		get_tree().create_timer(0.6).timeout.connect(func(): _cheer(rk[0]))
	_say(title, Pal.GOLD)
	var rows := []
	for p in rk:
		var s: Dictionary = P[p]
		rows.append({"name": p.player_name, "color": pcolor(p), "points": s.points, "alive": not s.dead,
			"correct": s.correct, "asked": s.asked, "tiles": owned(p).size()})
	_hud("hud_timer", [0.0, 1.0])
	await _wait(1.6)
	if ui and ui.has_method("show_result"):
		ui.show_result(title, names, rows)
	finished.emit(names)
