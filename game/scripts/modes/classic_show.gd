class_name ClassicShow
extends Node
## Trivia Arena — klasik üç perdelik şov (web sürümünün kuralları, 3D bedenle).
##
##  Tur 1 · Kategori avı     halat → 4 soru, doğru cevap merdiveni 250/250/500/750
##  Tur 2 · Güç turu         halat → 4 soru; her sorunun en hızlı doğrusu ya
##                            400 puan çalar ya da bir rakibe sabotaj yapar
##  Tur 3 · Son ayakta kalan halat → puan cana döner; her soruda yalnız en
##                            hızlı doğru kurtulur, kalan herkes bedeli öder;
##                            canı biten kişisel kapaktan düşer. Son kalan kazanır.
##
## Cevap vermek fiziksel: süre bitince hangi kapağın (A-B-C-D) üstünde
## duruyorsan cevabın odur. "En hızlı" = doğru kapağa en son girdiği an en
## erken olan. Bütün sayılar res://data/rules.tres'ten gelir.

signal finished(ranking: Array)

const ACTIONS := ["siphon", "lead", "invert", "ice", "bighead"]
const BOT_ACC := {"easy": [0.7, 0.55, 0.4], "normal": [0.86, 0.7, 0.55], "hard": [0.95, 0.86, 0.72]}
const BOT_READ := {"easy": 1.35, "normal": 1.0, "hard": 0.75}

var rules: RulesConfig = preload("res://data/rules.tres")
var game: Node
var stage: Stage
var ui: Node
var contestants: Array[Plush] = []
var st := {}                       # Plush -> istatistik sözlüğü
var round_no := 0
var q_index := 0
var phase := "idle"                # idle | intro | tug | question | reveal | reward | standings | done
var category := ""
var used_cats: Array = []
var item := {}
var face := {}
var time_left := 0.0
var timer_total := 10.0
var hp_mode := false
var stake := 0
var stake_scale := 1.0
var level := "normal"
var rng := RandomNumberGenerator.new()
var out_order: Array[Plush] = []
var log_lines: Array[String] = []
var award_to: Plush = null

var _q_t := 0.0                    # sorunun başından beri geçen süre
var _zone := {}                    # Plush -> [bölge, girdiği an]
var _bot_plan := {}
var _tick := 99
var _tug_pull: Array = []
var _tug_cats: Array = []
var _tug_open := false
var fast_forward := 1.0            # testlerde bekleme sürelerini kısaltır
var start_round := 1               # deneme için: 2 ya da 3'ten başla (puanlar rastgele dağıtılır)

func setup(p_game: Node, actors: Array[Plush], p_timer: float, p_level: String, seed_val := 0) -> void:
	game = p_game
	stage = game.stage
	ui = game.ui
	contestants = actors.duplicate()
	level = p_level
	if p_timer > 0.0:
		rules = rules.duplicate()
		rules.answer_s = p_timer
		rules.answer_final_s = max(6.0, p_timer - 1.0)
	if seed_val != 0:
		rng.seed = seed_val
	else:
		rng.randomize()
	Questions.reset_used()
	for p in contestants:
		st[p] = {"points": 0, "combo": 0, "best_combo": 0, "hp": 0, "max_hp": 1, "alive": true,
			"correct": 0, "asked": 0, "stolen": 0, "sabotaged": 0, "debuff_left": {}, "elim": 0}
		p.jumped.connect(_on_jumped)

func _exit_tree() -> void:
	for p in contestants:
		if is_instance_valid(p):
			p.clear_debuffs()
			p.hide_plate()
			if p.jumped.is_connected(_on_jumped):
				p.jumped.disconnect(_on_jumped)
	if stage:
		stage.hide_tug()

# ── yardımcılar ─────────────────────────────────────────────────────
func _hud(method: String, args: Array = []) -> void:
	if ui and ui.has_method(method):
		ui.callv(method, args)

func _wait(s: float) -> void:
	await get_tree().create_timer(s / fast_forward, false, true).timeout

func _say(text: String, accent := Color("F2C66A"), sub := "") -> void:
	log_lines.append(text)
	_hud("hud_message", [text, accent, sub])

func alive() -> Array[Plush]:
	var out: Array[Plush] = []
	for p in contestants:
		if is_instance_valid(p) and st[p].alive:
			out.append(p)
	return out

func pcolor(p: Plush) -> Color:
	return PlushVisual.COLORS.get(String(p.look.get("color", "mustard")), Color.WHITE)

func _notify_all(text: String) -> void:
	if game.has_method("notify_phones"):
		game.notify_phones({"t": "status", "text": text})

func _notify(p: Plush, msg: Dictionary) -> void:
	if game.has_method("notify_player"):
		game.notify_player(p, msg)

## Skor şeridi + baş üstü plakaları
func _refresh_scores(deltas := {}) -> void:
	var rows := []
	for p in _ranked():
		var s: Dictionary = st[p]
		rows.append({"name": p.player_name, "color": pcolor(p), "value": s.hp if hp_mode else s.points,
			"combo": s.combo, "hp": s.hp, "max_hp": s.max_hp, "alive": s.alive, "hp_mode": hp_mode,
			"delta": deltas.get(p, 0), "debuffs": p.debuffs.keys()})
		if s.alive:
			p.set_plate(p.player_name, "", pcolor(p))
	_hud("hud_scores", [rows])

func _ranked() -> Array[Plush]:
	var r := contestants.duplicate()
	r.sort_custom(func(a, b):
		var sa: Dictionary = st[a]
		var sb: Dictionary = st[b]
		if hp_mode:
			if sa.alive != sb.alive:
				return sa.alive
			if sa.alive:
				return sa.hp > sb.hp or (sa.hp == sb.hp and sa.points > sb.points)
			return sa.elim > sb.elim
		return sa.points > sb.points)
	return r

# ── akış ────────────────────────────────────────────────────────────
func line_up() -> void:
	var n := contestants.size()
	for i in n:
		var x := (i - (n - 1) * 0.5) * 1.05
		contestants[i].teleport(Vector3(x, 0.05, 3.35), PI)
		if contestants[i].controller is Controllers.Bot:
			contestants[i].controller.mode = "idle"

func run() -> void:
	stage.set_zones_visible(false)
	_refresh_scores()
	await _wait(0.6)
	if start_round > 1:
		round_no = start_round - 1
		for p in contestants:
			st[p].points = rng.randi_range(2, 12) * 250
		_refresh_scores()
	for r in [1, 2, 3]:
		if r < start_round:
			continue
		if r > 1:
			await _standings()
		await _round(r)
		if phase == "done":
			break
	if phase != "done":
		_finish()

func _round(r: int) -> void:
	round_no = r
	q_index = 0
	if r == 3:
		_to_hp()
	phase = "intro"
	var chips := []
	for i in 3:
		chips.append(I18n.t("round.%d.chip%d" % [r, i + 1]))
	_hud("hud_round_card", [r, I18n.t("round.%d" % r), I18n.t("round.%dd" % r), chips])
	Narrator.say("act%d_arena" % clampi(r, 1, 3))
	_notify_all(I18n.t("round.%d" % r))
	Sfx.play("whoosh", -4.0, 0.9)
	await _wait(rules.intro_s)
	_hud("hud_round_card_hide")
	await _tug()
	var n := rules.questions_in(r)
	while q_index < n and phase != "done":
		_hud("hud_track", [r, 3, "dots", n, float(q_index)])
		await _ask()
		await _resolve()
		if r == 2:
			await _reward()
		if r == 3 and alive().size() <= 1:
			_finish()
			return
		q_index += 1
		_hud("hud_track", [r, 3, "dots", n, float(q_index)])
	if r == 3 and phase != "done":
		_finish()

# ── kategori halatı ─────────────────────────────────────────────────
## Sahneye üç kategori dairesi iner. Bir dairenin içinde her zıplayış o
## kategoriye bir çekiş yazar; itişip birbirini daireden atmak serbest.
func _tug() -> void:
	phase = "tug"
	_tug_cats = Questions.pick_categories(3, rng, used_cats)
	if _tug_cats.size() < 2:
		_tug_cats = Questions.pick_categories(3, rng, [])
	var names := []
	var cols := []
	for c in _tug_cats:
		names.append(Questions.category_name(c, I18n.lang))
		cols.append(Questions.category_color(c))
	_tug_pull = []
	for c in _tug_cats:
		_tug_pull.append(0)
	stage.set_zones_visible(false)
	stage.show_tug(names, cols)
	_say(I18n.t("tug.title"), Color("F2C66A"), I18n.t("tug.sub"))
	_notify_all(I18n.t("tug.phone"))
	for p in alive():
		p.frozen_input = false
		if p.controller is Controllers.Bot:
			var fav := rng.randi() % _tug_cats.size()
			p.controller.hop_at(Stage.TUG_POS[fav] + Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5)))
			p.controller.hop_rate = {"easy": 0.06, "normal": 0.1, "hard": 0.16}.get(level, 0.1)
	_tug_open = true
	var left := rules.tug_s
	while left > 0.0:
		await get_tree().physics_frame
		left -= get_physics_process_delta_time() * fast_forward
		var total := 0
		for v in _tug_pull:
			total += v
		for i in _tug_pull.size():
			stage.set_tug_share(i, float(_tug_pull[i]) / max(1, total))
		_hud("hud_tug", [names, cols, _tug_pull.duplicate(), max(0.0, left), rules.tug_s])
	_tug_open = false
	var best := 0
	for i in _tug_pull.size():
		if _tug_pull[i] > _tug_pull[best] or (_tug_pull[i] == _tug_pull[best] and rng.randf() < 0.5 and i != best):
			best = i
	category = _tug_cats[best]
	used_cats.append(category)
	stage.tug_winner(best)
	_hud("hud_tug_winner", [best])
	Sfx.play("ding", -2.0, 1.2)
	_say(I18n.t("tug.won", {"cat": names[best]}), Color(cols[best]).lightened(0.3))
	log_lines.append("CAT " + category)
	await _wait(1.6)
	_hud("hud_tug_hide")
	stage.hide_tug()
	for p in alive():
		if p.controller is Controllers.Bot:
			p.controller.go_to(Vector3(rng.randf_range(-3.0, 3.0), 0, rng.randf_range(-1.0, 1.5)))

func _on_jumped(p: Plush) -> void:
	if not _tug_open or not st.has(p) or not st[p].alive:
		return
	for i in _tug_cats.size():
		var c: Vector3 = Stage.TUG_POS[i]
		if Vector2(p.global_position.x - c.x, p.global_position.z - c.z).length() < Stage.TUG_R:
			_tug_pull[i] += 1
			p.float_text("+1", Questions.category_color(_tug_cats[i]).lightened(0.3))
			return

# ── soru ────────────────────────────────────────────────────────────
func _ask() -> void:
	award_to = null
	var tier := rules.tier_for(round_no, q_index)
	item = Questions.draw_from(tier, category, rng)
	face = Questions.face(item, I18n.lang)
	timer_total = rules.answer_final_s if hp_mode else rules.answer_s
	if hp_mode:
		stake = max(1, int(round(rules.round_penalty(q_index + 1, alive().size()) * stake_scale)))
	# sabotajlar bu soruda etkin
	for p in alive():
		var dl: Dictionary = st[p].debuff_left
		for k in dl:
			p.set_debuff(k, true, rules)
	stage.board.show_question(q_index, face.prompt, face.options, face.cat_name, face.cat_color, timer_total)
	stage.set_zone_texts(face.options)
	stage.set_zones_visible(true)
	var label := I18n.t("hud.q_of", {"n": q_index + 1, "m": rules.questions_in(round_no)}) if not hp_mode else I18n.t("hud.q_final", {"n": q_index + 1})
	var pips := Vector2i(q_index, rules.questions_in(round_no)) if not hp_mode else Vector2i(0, 0)
	_hud("hud_question", [label, face.prompt, face.options, face.cat_name, face.cat_color, timer_total, stake if hp_mode else 0, pips])
	_say(I18n.t("arena.run"), Color("F2C66A"), I18n.t("hud.stake", {"n": stake}) if hp_mode else "")
	_notify_all(I18n.t("house.status_q", {"n": q_index + 1}))
	Sfx.play("ding", -4.0, 0.9)
	_zone.clear()
	for p in alive():
		p.frozen_input = false
		_zone[p] = [-1, 0.0]
	_plan_bots()
	_q_t = 0.0
	time_left = timer_total
	_tick = 99
	phase = "question"
	Music.play("think", 0.8)
	while time_left > 0.0 and phase == "question":
		await get_tree().physics_frame

func _physics_process(delta: float) -> void:
	if phase != "question":
		return
	var d := delta * fast_forward
	time_left -= d
	_q_t += d
	stage.board.time_left = max(0.0, time_left)
	_hud("hud_timer", [max(0.0, time_left), timer_total])
	var s := int(ceil(time_left))
	if s < _tick and s <= 5 and s > 0:
		_tick = s
		Sfx.play("tick", -2.0, 1.0 + (5 - s) * 0.08)
	# kim hangi kapağa ne zaman girdi
	for p in _zone:
		if not is_instance_valid(p):
			continue
		var z := stage.zone_at(p.global_position)
		if z != _zone[p][0]:
			_zone[p] = [z, _q_t]
	_drive_bots()

func _bot_acc(tier: String) -> float:
	var arr: Array = BOT_ACC.get(level, BOT_ACC.normal)
	return float(arr[{"d1": 0, "d2": 1, "d3": 2}.get(tier, 1)])

func _plan_bots() -> void:
	_bot_plan.clear()
	var read: float = (1.0 + String(face.prompt).length() * 0.028) * float(BOT_READ.get(level, 1.0))
	for p in alive():
		if not (p.controller is Controllers.Bot):
			continue
		var zone: int = face.correct
		if rng.randf() > _bot_acc(item.tier):
			var wrong := [0, 1, 2, 3]
			wrong.erase(face.correct)
			zone = wrong[rng.randi() % 3]
		var at: float = clamp(read + rng.randf_range(-0.6, 1.4), 0.8, timer_total - 2.0)
		_bot_plan[p] = {"zone": zone, "at": timer_total - at}
		p.controller.go_to(Vector3(rng.randf_range(-1.5, 1.5), 0, rng.randf_range(-0.8, 0.8)))

func _drive_bots() -> void:
	var he := stage.zone_half_extents()
	for p in _bot_plan:
		if not is_instance_valid(p) or not p.is_active():
			continue
		var plan: Dictionary = _bot_plan[p]
		if time_left <= plan.at and not plan.get("going", false):
			plan.going = true
			p.controller.go_to(stage.zone_center(plan.zone) + Vector3(rng.randf_range(-he.x, he.x) * 0.55, 0, rng.randf_range(-he.y, he.y) * 0.55))
		if plan.get("going", false) and rng.randf() < 0.004 * (2.0 if level == "hard" else 1.0):
			for o in alive():
				if o != p and o.global_position.distance_to(p.global_position) < 1.3:
					p.facing = atan2(o.global_position.x - p.global_position.x, o.global_position.z - p.global_position.z)
					p.try_shove()
					break

# ── sonuç ───────────────────────────────────────────────────────────
func _resolve() -> void:
	phase = "reveal"
	Music.play("trivia", 1.2)
	_hud("hud_timer", [0.0, timer_total])
	var correct: int = face.correct
	var right: Array[Plush] = []
	for p in alive():
		st[p].asked += 1
		var z: Array = _zone.get(p, [-1, 0.0])
		if z[0] == correct:
			right.append(p)
			st[p].correct += 1
	# en hızlı doğru: doğru kapağa en erken girip orada kalan
	right.sort_custom(func(a, b): return _zone[a][1] < _zone[b][1])
	var fastest: Plush = right[0] if not right.is_empty() else null
	stage.board.reveal = correct
	_hud("hud_reveal", [correct])
	for i in 4:
		stage.flash_zone(i, Color(0.35, 1.0, 0.45) if i == correct else Color(1.0, 0.2, 0.15))
	var ans: String = Stage.LETTERS[correct] + " · " + String(face.options[correct])
	var deltas := {}
	var dead: Array[Plush] = []
	if not hp_mode:
		for p in alive():
			var s: Dictionary = st[p]
			if right.has(p):
				s.combo += 1
				s.best_combo = max(s.best_combo, s.combo)
				var gain := rules.combo_gain(s.combo)
				s.points += gain
				deltas[p] = gain
				p.float_text("+%d" % gain + ("  ×%d" % s.combo if s.combo >= 2 else ""), Color("9BE38B"), s.combo >= 3)
				p.visual.land(4.0)
			else:
				s.combo = 0
				p.float_text("×", Color("FF6B52"))
		if round_no == 2:
			award_to = fastest
	else:
		for p in alive():
			var s: Dictionary = st[p]
			s.combo = s.combo + 1 if right.has(p) else 0
			if p == fastest:
				p.float_text(I18n.t("hud.safe"), Color("9BE38B"), true)
				continue
			s.hp = max(0, s.hp - stake)
			deltas[p] = -stake
			p.float_text("−%d" % stake, Color("FF6B52"), true)
			if s.hp <= 0:
				dead.append(p)
	Sfx.play("applause" if not right.is_empty() else "buzz", -10.0 if not right.is_empty() else -4.0)
	if right.is_empty():
		Narrator.say("nobody")
		Sfx.play("aww", -7.0)
	else:
		Sfx.play("cheer", -12.0)
	_say(I18n.t("arena.correct", {"x": ans}), Color("9BE38B") if not right.is_empty() else Color("FF7A5A"),
		(I18n.t("hud.fastest", {"name": fastest.player_name}) if fastest else I18n.t("hud.nobody")))
	_refresh_scores(deltas)
	for p in right:
		_notify(p, {"t": "buzz", "ms": 30})
	await _wait(rules.reveal_s)
	if not dead.is_empty():
		Narrator.say("eliminated")
		Sfx.play("ooh", -6.0)
		for p in dead:
			_kill(p)
		var names := []
		for p in dead:
			names.append(p.player_name)
		_say(I18n.t("hud.died", {"names": ", ".join(names)}), Color("FF6B52"))
		await _wait(2.2)
		_refresh_scores()
	# sabotajlar bir soru sürer
	for p in contestants:
		var dl: Dictionary = st[p].debuff_left
		for k in dl.keys():
			dl[k] -= 1
			if dl[k] <= 0:
				dl.erase(k)
				p.set_debuff(k, false, rules)
	stage.board.reveal = -1
	_hud("hud_question_hide")
	_refresh_scores()

func _kill(p: Plush) -> void:
	var s: Dictionary = st[p]
	s.alive = false
	s.elim = out_order.size() + 1
	out_order.append(p)
	log_lines.append("DIE " + p.player_name)
	stage.spawn_hatch(p.global_position)
	Sfx.play("scream", -3.0, rng.randf_range(0.9, 1.2))
	if game.cam:
		game.cam.add_trauma(0.35)
	_notify(p, {"t": "out"})
	await _wait(0.25)
	if is_instance_valid(p):
		p.drop_through()

func on_fell_out(p: Plush) -> void:
	# Sahnenin önünden düşen ölmez (can turunda ölenler zaten düşüyor): kulisten geri gelir
	if st.has(p) and st[p].alive:
		Sfx.play("scream", -6.0, rng.randf_range(0.9, 1.2))
		await _wait(1.2)
		if is_instance_valid(p) and st[p].alive:
			p.revive(Vector3((-1.0 if rng.randf() < 0.5 else 1.0) * 5.4, 0.3, 3.3))
	else:
		await _wait(1.0)
		if is_instance_valid(p):
			p.freeze = true
			p.visible = false

# ── ödül (tur 2) ────────────────────────────────────────────────────
func _reward() -> void:
	if contestants.size() < 2:
		return
	phase = "reward"
	var p := award_to
	if p == null:
		_say(I18n.t("reward.none"), Color("F2C66A"), I18n.t("reward.none_sub"))
		await _wait(1.6)
		return
	var targets: Array[Plush] = []
	for o in contestants:
		if o != p:
			targets.append(o)
	var choice := {}
	if p.controller is Controllers.Bot:
		var leader := targets[0]
		for o in targets:
			if st[o].points > st[leader].points:
				leader = o
		choice = {"target": leader if rng.randf() < 0.7 else targets[rng.randi() % targets.size()],
			"action": "siphon" if rng.randf() < 0.5 else ACTIONS[1 + rng.randi() % 4]}
		_say(I18n.t("reward.title", {"name": p.player_name}), pcolor(p).lightened(0.3), I18n.t("reward.bot_thinking"))
		await _wait(1.4)
	else:
		choice = await _pick_reward(p, targets)
	if choice.is_empty():
		_say(I18n.t("reward.timeout"), Color("FF7A5A"))
		await _wait(1.2)
		return
	var t: Plush = choice.target
	var action: String = choice.action
	if action == "siphon":
		var amount: int = min(rules.siphon, st[t].points)
		st[t].points -= amount
		st[p].points += amount
		st[p].stolen += amount
		t.float_text("−%d" % amount, Color("FF6B52"), true)
		p.float_text("+%d" % amount, Color("F2C66A"), true)
		Sfx.play("fanfare", -8.0, 1.5)
		Narrator.say("steal")
		if not (p.controller is Controllers.Bot):
			SteamService.unlock("HEIST")
		_say(I18n.t("reward.stole", {"a": p.player_name, "b": t.player_name, "n": amount}), Color("F2C66A"))
		log_lines.append("STEAL %s %s %d" % [p.player_name, t.player_name, amount])
		_refresh_scores({t: -amount, p: amount})
	else:
		st[t].debuff_left[action] = rules.debuff_questions
		st[t].sabotaged += 1
		t.float_text(I18n.t("debuff." + action).to_upper(), Color("FF6B52"), true)
		Sfx.play("buzz", -6.0, 0.8)
		_say(I18n.t("reward.sabotaged", {"a": p.player_name, "b": t.player_name, "x": I18n.t("debuff." + action)}), Color("FF7A5A"), I18n.t("debuff." + action + ".d"))
		log_lines.append("SABOTAGE %s %s %s" % [p.player_name, t.player_name, action])
		_notify(t, {"t": "status", "text": I18n.t("debuff." + action + ".d")})
		_refresh_scores()
	await _wait(2.0)

## İnsan oyuncu seçer: sol/sağ ile gez, zıpla ile onayla, omuz ile geri.
## Klavye, gamepad ve telefon aynı şekilde çalışır; fareyle tıklamak da olur.
func _pick_reward(p: Plush, targets: Array[Plush]) -> Dictionary:
	p.frozen_input = true
	var tlist := []
	var rk := _ranked()
	for t in targets:
		tlist.append({"name": t.player_name, "color": pcolor(t), "points": st[t].points, "rank": rk.find(t) + 1})
	var alist := []
	for a in ACTIONS:
		alist.append({"id": a,
			"name": I18n.t("debuff." + a) if a != "siphon" else I18n.t("reward.siphon", {"n": rules.siphon}),
			"desc": I18n.t("debuff." + a + ".d") if a != "siphon" else I18n.t("reward.siphon_d")})
	var step := 0
	var idx := [0, 0]
	var result := {}
	_hud("hud_reward_open", [p.player_name, pcolor(p), tlist, alist])
	_hud("hud_reward_select", [0, 0])
	_notify(p, {"t": "status", "text": I18n.t("reward.phone")})
	_notify(p, {"t": "buzz", "ms": 120})
	_say(I18n.t("reward.title", {"name": p.player_name}), pcolor(p).lightened(0.3), I18n.t("reward.how"))
	var left := rules.reward_pick_s
	var cool := 0.0
	var ctrl = p.controller
	if ui and ui.has_signal("reward_clicked"):
		ui.reward_clicked.connect(func(s_: int, i_: int):
			if s_ != step:
				return
			idx[step] = i_
			if step == 0:
				step = 1
				_hud("hud_reward_select", [1, idx[1]])
			else:
				result = {"target": targets[idx[0]], "action": ACTIONS[idx[1]]}, CONNECT_ONE_SHOT)
	while left > 0.0 and result.is_empty():
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time() * fast_forward
		left -= dt
		cool -= dt
		_hud("hud_timer", [left, rules.reward_pick_s])
		if ctrl == null:
			continue
		var mv: Vector2 = ctrl.get_move()
		var count := targets.size() if step == 0 else ACTIONS.size()
		if cool <= 0.0 and abs(mv.x) + abs(mv.y) > 0.6:
			var dir := 1 if (mv.x > 0.5 or mv.y > 0.5) else -1
			idx[step] = (idx[step] + dir + count) % count
			cool = 0.22
			Sfx.play("tick", -8.0, 1.4)
			_hud("hud_reward_select", [step, idx[step]])
		elif abs(mv.x) + abs(mv.y) < 0.3:
			cool = min(cool, 0.0)
		if ctrl.consume_jump():
			Sfx.play("click", -4.0)
			if step == 0:
				step = 1
				_hud("hud_reward_select", [1, idx[1]])
			else:
				result = {"target": targets[idx[0]], "action": ACTIONS[idx[1]]}
		if ctrl.consume_shove() and step == 1:
			step = 0
			_hud("hud_reward_select", [0, idx[0]])
	_hud("hud_reward_close")
	p.frozen_input = false
	return result

# ── tur 3'e geçiş ───────────────────────────────────────────────────
## Web sürümündeki toHpRound: puan cana döner; en az canlı oyuncu bile
## liderin %35'i kadar (en az 1000) canla girer. Bedel masanın ortalamasına
## göre ölçeklenir ki tur, kadro ne olursa olsun 9-11 soruda bitsin.
func _to_hp() -> void:
	hp_mode = true
	var top := 0
	for p in contestants:
		top = max(top, st[p].points)
	var floor_hp: int = max(rules.hp_floor_min, int(round(top * rules.hp_floor_ratio)))
	var sum := 0.0
	for p in contestants:
		var s: Dictionary = st[p]
		s.hp = max(floor_hp, s.points)
		s.max_hp = max(1, s.hp)
		sum += s.hp
	var avg: float = sum / maxi(1, contestants.size())
	stake_scale = clamp(avg / float(rules.final_start_hp), rules.stake_scale_min, rules.stake_scale_max)
	log_lines.append("HP floor=%d scale=%.2f" % [floor_hp, stake_scale])
	_refresh_scores()

func _standings() -> void:
	phase = "standings"
	stage.set_zones_visible(false)
	var rows := []
	for p in _ranked():
		rows.append({"name": p.player_name, "color": pcolor(p), "points": st[p].points, "combo": st[p].best_combo})
	_hud("hud_standings", [rows, round_no])
	Sfx.play("whoosh", -6.0)
	await _wait(rules.standings_s)
	_hud("hud_standings_hide")

# ── final ───────────────────────────────────────────────────────────
## İlerleme için bir oyuncunun maç istatistikleri
func stats_for(p: Plush) -> Dictionary:
	return st.get(p, {})

func ranking() -> Array[Plush]:
	return _ranked()

func _finish() -> void:
	if phase == "done":
		return
	phase = "done"
	Narrator.say("winner")
	Music.stop(0.8)
	Music.sting("victory")
	stage.set_zones_visible(false)
	stage.hide_tug()
	stage.board.show_marquee(I18n.t("arena.lobby_board"))
	var rk := _ranked()
	var names: Array = []
	for p in rk:
		names.append(p.player_name)
	var title := I18n.t("arena.winner", {"name": rk[0].player_name}) if rk.size() > 0 else I18n.t("arena.draw")
	log_lines.append("WIN " + (names[0] if names.size() > 0 else "-"))
	Profile.record_match(names, "arena")
	if game.has_method("on_match_finished"):
		game.on_match_finished("arena", names)
	Sfx.play("fanfare", -2.0)
	Sfx.play("applause", -6.0)
	if rk.size() > 0 and is_instance_valid(rk[0]):
		stage.set_gold_target(rk[0])
		_notify(rk[0], {"t": "status", "text": I18n.t("house.status_win")})
	_say(title, Color("F2C66A"))
	var rows := []
	for p in rk:
		var s: Dictionary = st[p]
		rows.append({"name": p.player_name, "color": pcolor(p), "points": s.points, "hp": s.hp, "alive": s.alive,
			"best_combo": s.best_combo, "correct": s.correct, "asked": s.asked, "stolen": s.stolen})
	_hud("hud_timer", [0.0, 1.0])
	await _wait(1.6)
	if ui and ui.has_method("show_result"):
		ui.show_result(title, names, rows)
	finished.emit(names)
