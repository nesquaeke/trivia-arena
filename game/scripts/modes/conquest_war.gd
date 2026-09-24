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
	"base": 1000, "land": 200, "rich": 400, "turn_budget": 16,
	"estimate_s": 16.0, "reveal_s": 4.6, "castle_s": 12.0, "claim_s": 10.0,
	"target_s": 10.0, "duel_s": 11.0, "tie_s": 12.0, "result_s": 2.6, "intro_s": 4.2,
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
	war_rounds = clampi(int(round(float(CFG.turn_budget) / maxf(2.0, n))), 2, 6)
	if ui and ui.has_signal("answer_clicked"):
		ui.answer_clicked.connect(_on_answer_clicked)

func _exit_tree() -> void:
	for p in contestants:
		if is_instance_valid(p):
			p.visual.set_culture("")
			p.frozen_input = false
			p.hide_plate()
	if is_instance_valid(board):
		board.queue_free()
	if ui and ui.has_signal("answer_clicked") and ui.answer_clicked.is_connected(_on_answer_clicked):
		ui.answer_clicked.disconnect(_on_answer_clicked)
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
			"hp_mode": false, "combo": 0, "debuffs": [], "tiles": owned(p).size(),
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

## Generaller: sahnenin önünde, haritaya dönük değil seyirciye dönük, kostümlü
func line_up() -> void:
	var n := contestants.size()
	for i in n:
		var p := contestants[i]
		p.teleport(Vector3((i - (n - 1) * 0.5) * 1.15, 0.05, 3.45), 0.0)
		p.frozen_input = true
		if p.controller is Controllers.Bot:
			p.controller.mode = "idle"

# ── akış ────────────────────────────────────────────────────────────
func run() -> void:
	stage.set_zones_visible(false)
	if game.cam:
		game.cam.set_shot(BalconyCam.Shot.MAP, false)
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
	Sfx.play("whoosh", -4.0, 0.9)
	await _wait(CFG.intro_s)
	_hud("hud_round_card_hide")
	await _wait(0.5)

# ── tahmin sorusu (bütün perdelerde ortak) ─────────────────────────
func _pick_estimate() -> Dictionary:
	var pool: Array = Questions.estimate.filter(func(q): return not _used_est.has(q.tr.q))
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
	var digits := maxi(1, str(int(q.max)).length())
	var hs := humans(who)
	var state := {}
	var dials := []
	for i in hs.size():
		var p := hs[i]
		state[p] = {"value": 0, "cursor": 0, "locked": false, "at": INF, "cool": 0.0, "idx": i}
		dials.append({"name": p.player_name, "color": pcolor(p), "value": 0, "digits": digits, "cursor": 0, "locked": false})
		_notify(p, {"t": "status", "text": I18n.t("cq.phone_est")})
	_typed.clear()
	_hud("hud_estimate_open", [kicker, tx.q, tx.unit, dials, is_year])
	# botlar
	var guesses := {}
	var times := {}
	var spread: float = (float(q.max) - float(q.min)) * float(BOT_SPREAD.get(level, 0.12))
	for p in who:
		if is_bot(p):
			guesses[p] = int(round(clampf(float(q.a) + rng.randfn(0.0, spread), float(q.min), float(q.max))))
			times[p] = rng.randf_range(2.0, 9.0)
	phase = "estimate"
	q_index += 1
	timer_total = CFG.estimate_s
	time_left = timer_total
	var t := 0.0
	var start_ms := Time.get_ticks_msec()
	while time_left > 0.0:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time() * fast_forward
		time_left -= dt
		t += dt
		_hud("hud_timer", [maxf(0.0, time_left), timer_total])
		var all_locked := true
		for p in hs:
			var s: Dictionary = state[p]
			if s.locked:
				continue
			all_locked = false
			_dial_input(p, s, digits, dt)
			_hud("hud_estimate_dial", [s.idx, s.value, s.cursor, s.locked])
			if s.locked:
				s.at = t
		if all_locked and not hs.is_empty():
			break
	for p in hs:
		guesses[p] = int(state[p].value)
		times[p] = float(state[p].at)
	var ranked := []
	for p in who:
		var g := int(guesses.get(p, int(q.min)))
		ranked.append({"p": p, "guess": g, "diff": absi(g - int(q.a)), "at": float(times.get(p, INF))})
	ranked.sort_custom(func(a, b): return a.diff < b.diff or (a.diff == b.diff and a.at < b.at))
	# açıklama
	phase = "reveal"
	_hud("hud_timer", [0.0, timer_total])
	var worst := 1
	for r in ranked:
		worst = maxi(worst, int(r.diff))
	var rows := []
	for k in ranked.size():
		var r: Dictionary = ranked[k]
		rows.append({"name": r.p.player_name, "color": pcolor(r.p), "guess_text": EstimatePanel.group(r.guess, is_year),
			"diff_text": I18n.t("cq.exact") if r.diff == 0 else I18n.t("cq.off", {"n": EstimatePanel.group(r.diff, is_year)}),
			"ratio": 1.0 - float(r.diff) / float(worst) * 0.88, "win": k == 0})
	var ans: String = EstimatePanel.group(int(q.a), is_year) + ((" " + String(tx.unit)) if String(tx.unit) != "" else "")
	_hud("hud_estimate_reveal", [ans, rows])
	Sfx.play("ding", -3.0, 1.2)
	log_lines.append("EST %s → %s" % [str(q.a), ranked[0].p.player_name])
	if not ranked.is_empty():
		_cheer(ranked[0].p)
	await _wait(CFG.reveal_s)
	_hud("hud_estimate_close")
	return ranked

## Kadran: yukarı/aşağı rakam, sol/sağ basamak, zıpla kilit; klavyeden yazmak da olur
func _dial_input(p: Plush, s: Dictionary, digits: int, dt: float) -> void:
	var ctrl = p.controller
	if ctrl == null:
		return
	s.cool -= dt
	var mv: Vector2 = ctrl.get_move()
	var place := digits - 1 - int(s.cursor)
	if s.cool <= 0.0:
		if mv.y < -0.5:
			s.value = _bump(int(s.value), place, 1, digits)
			s.cool = 0.16
			Sfx.play("tick", -12.0, 1.5)
		elif mv.y > 0.5:
			s.value = _bump(int(s.value), place, -1, digits)
			s.cool = 0.16
			Sfx.play("tick", -12.0, 1.3)
		elif mv.x > 0.5:
			s.cursor = mini(digits - 1, int(s.cursor) + 1)
			s.cool = 0.2
		elif mv.x < -0.5:
			s.cursor = maxi(0, int(s.cursor) - 1)
			s.cool = 0.2
	if absf(mv.x) < 0.3 and absf(mv.y) < 0.3:
		s.cool = minf(s.cool, 0.0)
	if _typed.has(p):
		var typed: Array = _typed[p]
		for k in typed:
			if k == -1:
				s.value = int(s.value) / 10
			elif k == -2:
				s.locked = true
			else:
				s.value = (int(s.value) * 10 + int(k)) % int(pow(10, digits))
		_typed.erase(p)
	if ctrl.consume_jump():
		s.locked = true
	ctrl.consume_shove()

func _bump(v: int, place: int, d: int, digits: int) -> int:
	var p10 := int(pow(10, place))
	var dig := (v / p10) % 10
	var nd := (dig + d + 10) % 10
	return clampi(v + (nd - dig) * p10, 0, int(pow(10, digits)) - 1)

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
		elif e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER:
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
	Sfx.play("thud", -2.0, 0.7)
	Sfx.play("fanfare", -12.0, 1.4)
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
	Sfx.play("ding", -6.0, 1.3)
	_say(I18n.t("cq.picked", {"a": p.player_name, "t": board.region_name(id), "p": v}), pcolor(p).lightened(0.3))
	log_lines.append("CLAIM %s %s" % [p.player_name, id])
	_refresh_scores({p: v})

# ── Perde III: savaş ───────────────────────────────────────────────
var _turn_of: Plush = null

func _war() -> void:
	for rr in war_rounds:
		war_round = rr
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
	board.attack_arc(from if from != "" else id, id, pcolor(p))
	board.flash(id)
	Sfx.play("whoosh", -2.0, 1.2)
	log_lines.append("ATTACK %s %s %s" % [p.player_name, d.player_name, id])
	await _wait(1.0)
	var win := await _duel(p, d)
	await _resolve(p, d, id, win)
	_turn_of = null

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

## Düello: iki kişi aynı soruyu cevaplar. Dönüş: saldıran kazandı mı?
func _duel(a: Plush, d: Plush) -> bool:
	phase = "duel"
	var tiers := ["d1", "d2", "d3"]
	var tier: String = tiers[rng.randi() % 3]
	var item := Questions.draw_from(tier, "", rng)
	var face := Questions.face(item, I18n.lang)
	var extra := clampf((String(face.prompt).length() - 60) * 0.03, 0.0, 4.0)
	timer_total = CFG.duel_s + extra
	time_left = timer_total
	var label := I18n.t("cq.duel", {"a": a.player_name, "d": d.player_name})
	_hud("hud_question", [label, face.prompt, face.options, face.cat_name, face.cat_color, timer_total, 0, Vector2i(0, 0)])
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
	if ra and rd:
		_say(I18n.t("cq.tieBreak"), Pal.GOLD)
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
		Sfx.play("buzz", -4.0, 0.8)
		_cheer(d)
		log_lines.append("REPEL %s" % d.player_name)
	elif capital.has(id):
		shields[id] = int(shields[id]) - 1
		P[a].captures += 1
		var castle := board.piece(id) as CastleModel
		if shields[id] > 0:
			if castle:
				castle.set_towers(shields[id])
			Sfx.play("thud", 0.0, 0.6)
			if game.cam:
				game.cam.add_trauma(0.35)
			_say(I18n.t("cq.towerFell", {"a": a.player_name, "d": d.player_name, "n": shields[id]}), pcolor(a).lightened(0.3))
			log_lines.append("TOWER %s %d" % [d.player_name, shields[id]])
			_cheer(a)
		else:
			if castle:
				castle.collapse()
			Sfx.play("thud", 2.0, 0.5)
			Sfx.play("scream", -4.0, 0.9)
			if game.cam:
				game.cam.add_trauma(0.6)
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
		holder[id] = a
		P[a].points += loot
		P[d].points -= loot
		P[a].captures += 1
		board.set_owner_color(id, pcolor(a))
		_place_warrior(a, id)
		Sfx.play("fanfare", -10.0, 1.3)
		_say(I18n.t("cq.captured", {"a": a.player_name, "t": board.region_name(id), "p": loot}), pcolor(a).lightened(0.3))
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
	Sfx.play("fanfare", -2.0)
	Sfx.play("applause", -6.0)
	if rk.size() > 0:
		stage.set_gold_target(rk[0])
		_notify(rk[0], {"t": "status", "text": I18n.t("house.status_win")})
		_cheer(rk[0])
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
