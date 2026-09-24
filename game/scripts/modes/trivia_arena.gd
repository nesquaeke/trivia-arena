class_name TriviaArena
extends Node
## Trivia Arena — fiziksel eleme.
## Soru arkadaki panoya düşer, zemin dört kapağa (A-B-C-D) bölünür. Oyuncular
## süre bitmeden doğru şıkkın kapağına koşar; süre dolunca yanlış kapaklar
## açılır ve üstündekiler sahnenin altına düşer. Hiçbir kapağın üstünde
## olmayanı vodvil kancası kulise çeker. Son ayakta kalan kazanır.
## Kimse doğru kapakta değilse kapaklar açılmaz, soru yenilenir.

signal finished(ranking: Array)

const BOT_ACC := {
	"easy": [0.7, 0.55, 0.4], "normal": [0.86, 0.7, 0.55], "hard": [0.95, 0.86, 0.72],
}
const BOT_READ := {"easy": 1.35, "normal": 1.0, "hard": 0.75}
const MAX_QUESTIONS := 15

var game: Node
var stage: Stage
var ui: Node
var contestants: Array[Plush] = []
var alive: Array[Plush] = []
var out_order: Array[Plush] = []
var q_index := 0
var item := {}
var face := {}
var timer_total := 10.0
var time_left := 0.0
var phase := "idle"          # idle | question | reveal | done
var level := "normal"
var rng := RandomNumberGenerator.new()
var _bot_plan := {}          # Plush -> {zone, at}
var _tick := 99
var _fell_this_round: Array[Plush] = []
var _hooked: Array[Plush] = []
var log_lines: Array[String] = []   # testler için olay kaydı

func setup(p_game: Node, actors: Array[Plush], p_timer: float, p_level: String, seed_val := 0) -> void:
	game = p_game
	stage = game.stage
	ui = game.ui
	contestants = actors.duplicate()
	alive = actors.duplicate()
	timer_total = p_timer
	level = p_level
	if seed_val != 0:
		rng.seed = seed_val
	else:
		rng.randomize()
	Questions.reset_used()

func line_up() -> void:
	var n := contestants.size()
	for i in n:
		var x := (i - (n - 1) * 0.5) * 1.05
		contestants[i].teleport(Vector3(x, 0.05, 3.35), PI)
		contestants[i].tag.zone = -1
		if contestants[i].controller is Controllers.Bot:
			contestants[i].controller.mode = "idle"

func run() -> void:
	stage.set_zones_visible(false)
	stage.close_all_trapdoors()
	_ui_top()
	await _wait(0.8)
	while phase != "done":
		await _ask()
		if phase == "done":
			break
		await _resolve()

func _wait(s: float) -> void:
	await get_tree().create_timer(s, false, true).timeout

func _say(text: String, accent := UIKit.GOLD, sub := "") -> void:
	log_lines.append(text)
	if ui:
		ui.hud_set_msg(text, accent, sub)

func _ui_top() -> void:
	if ui:
		ui.hud_set_top(I18n.t("arena.round", {"n": q_index + 1}), I18n.t("arena.alive", {"n": alive.size()}))

# ── soru ────────────────────────────────────────────────────────────
func _ask() -> void:
	item = Questions.draw(q_index, rng)
	face = Questions.face(item, I18n.lang)
	stage.board.show_question(q_index, face.prompt, face.options, face.cat_name, face.cat_color, timer_total)
	stage.set_zone_texts(face.options)
	stage.set_zones_visible(true)
	_ui_top()
	_say(I18n.t("arena.run"))
	Sfx.play("ding", -4.0, 0.9)
	_plan_bots()
	time_left = timer_total
	_tick = 99
	phase = "question"
	while time_left > 0.0 and phase == "question":
		await get_tree().physics_frame

func _physics_process(delta: float) -> void:
	if phase != "question":
		return
	time_left -= delta
	stage.board.time_left = max(0.0, time_left)
	if ui:
		ui.hud_set_timer(max(0.0, time_left), timer_total)
	var s := int(ceil(time_left))
	if s < _tick and s <= 5 and s > 0:
		_tick = s
		Sfx.play("tick", -2.0, 1.0 + (5 - s) * 0.08)
	_drive_bots(delta)

func _bot_acc(tier: String) -> float:
	var arr: Array = BOT_ACC.get(level, BOT_ACC.normal)
	return float(arr[{"d1": 0, "d2": 1, "d3": 2}.get(tier, 1)])

func _plan_bots() -> void:
	_bot_plan.clear()
	var read: float = (1.0 + String(face.prompt).length() * 0.028) * float(BOT_READ.get(level, 1.0))
	for p in alive:
		if not (p.controller is Controllers.Bot):
			continue
		var correct: bool = rng.randf() < _bot_acc(item.tier)
		var zone: int = face.correct
		if not correct:
			var wrong := [0, 1, 2, 3]
			wrong.erase(face.correct)
			zone = wrong[rng.randi() % 3]
		var at: float = clamp(read + rng.randf_range(-0.6, 1.4), 0.8, timer_total - 2.5)
		_bot_plan[p] = {"zone": zone, "at": timer_total - at, "fickle": rng.randf() < 0.12}
		# düşünürken sahnenin ortasına doğru yürür
		p.controller.go_to(Vector3(rng.randf_range(-1.5, 1.5), 0, rng.randf_range(-0.8, 0.8)))

func _drive_bots(_delta: float) -> void:
	var he := stage.zone_half_extents()
	for p in _bot_plan:
		if not is_instance_valid(p) or not p.is_active():
			continue
		var plan: Dictionary = _bot_plan[p]
		if time_left <= plan.at and not plan.get("going", false):
			plan.going = true
			var c := stage.zone_center(plan.zone)
			p.controller.go_to(c + Vector3(rng.randf_range(-he.x, he.x) * 0.55, 0, rng.randf_range(-he.y, he.y) * 0.55))
		# kararsız bot son anda fikir değiştirir
		if plan.get("fickle", false) and time_left < 2.2 and not plan.get("switched", false):
			plan.switched = true
			var z2: int = (int(plan.zone) + 1 + rng.randi() % 3) % 4
			plan.zone = z2
			p.controller.go_to(stage.zone_center(z2))
		# yanındakine omuz atma (kaos)
		if plan.get("going", false) and rng.randf() < 0.006 * (2.0 if level == "hard" else 1.0):
			for o in alive:
				if o != p and o.global_position.distance_to(p.global_position) < 1.3:
					p.facing = atan2(o.global_position.x - p.global_position.x, o.global_position.z - p.global_position.z)
					p.try_shove()
					break

# ── sonuç ───────────────────────────────────────────────────────────
func _resolve() -> void:
	phase = "reveal"
	if ui:
		ui.hud_set_timer(0.0, timer_total)
	var correct: int = face.correct
	var on_right: Array[Plush] = []
	var off_zone: Array[Plush] = []
	for p in alive:
		var z := stage.zone_at(p.global_position)
		p.tag.zone = z
		if z == correct:
			on_right.append(p)
		elif z == -1:
			off_zone.append(p)
	stage.board.reveal = correct
	_fell_this_round.clear()
	if on_right.is_empty():
		_say(I18n.t("arena.nobody"), Color("F2C66A"), I18n.t("arena.correct", {"x": Stage.LETTERS[correct] + " · " + String(face.options[correct])}))
		Sfx.play("buzz", -4.0)
		for i in 4:
			stage.flash_zone(i, Color(1, 0.3, 0.2))
		await _wait(3.2)
		q_index += 1
		_prepare_next()
		return
	_say(I18n.t("arena.open"), Color("FF7A5A"), I18n.t("arena.correct", {"x": Stage.LETTERS[correct] + " · " + String(face.options[correct])}))
	Sfx.play("drumroll", -6.0)
	await _wait(0.9)
	Sfx.play("trapdoor", 0.0)
	if game.cam:
		game.cam.add_trauma(0.55)
	for i in 4:
		if i == correct:
			stage.flash_zone(i, Color(0.4, 1.0, 0.45))
		else:
			stage.open_trapdoor(i, true)
			stage.flash_zone(i, Color(1.0, 0.18, 0.12))
	# kapakta olmayanları vodvil kancası kulise çeker
	for p in off_zone:
		_hook(p)
	await _wait(2.6)
	# aşağı düşmeyip kenarda asılı kalan olursa (kapak açıkken yanlış bölgede) onu da kanca alır
	for p in alive.duplicate():
		var z := stage.zone_at(p.global_position)
		if z != -1 and z != correct and p.global_position.y > -0.5:
			_hook(p)
	await _wait(0.6)
	var names: Array[String] = []
	for p in _fell_this_round:
		names.append(p.player_name)
	if names.size() > 0:
		_say(I18n.t("arena.fell", {"names": ", ".join(names)}), Color("FF7A5A"))
	stage.close_all_trapdoors()
	await _wait(1.4)
	q_index += 1
	_prepare_next()

func _prepare_next() -> void:
	stage.board.reveal = -1
	if alive.size() <= 1 or q_index >= MAX_QUESTIONS:
		_finish()
		return
	# kapakların kapanması için oyuncuları ön şeride çağır (botlar)
	for p in alive:
		if p.controller is Controllers.Bot:
			p.controller.go_to(Vector3(rng.randf_range(-3.5, 3.5), 0, 3.3))
	_ui_top()

func _hook(p: Plush) -> void:
	if not alive.has(p) or _hooked.has(p):
		return
	_hooked.append(p)
	p.frozen_input = true
	p.freeze = true
	var side := -1.0 if p.global_position.x < 0.0 else 1.0
	var tw := create_tween()
	tw.tween_property(p, "global_position", p.global_position + Vector3(0, 0.6, 0), 0.25)
	tw.tween_property(p, "global_position", Vector3(side * 10.5, 1.4, p.global_position.z), 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	Sfx.play("scream", -6.0, rng.randf_range(1.0, 1.3))
	await tw.finished
	_eliminate(p)

func on_fell_out(p: Plush) -> void:
	if not alive.has(p):
		return
	Sfx.play("scream", -4.0, rng.randf_range(0.85, 1.2))
	_eliminate(p)

func _eliminate(p: Plush) -> void:
	if not alive.has(p):
		return
	alive.erase(p)
	out_order.append(p)
	_fell_this_round.append(p)
	log_lines.append("OUT " + p.player_name)
	_ui_top()
	# kuyuda fizik yükü olmasın
	await _wait(1.2)
	if is_instance_valid(p) and not alive.has(p):
		p.freeze = true
		p.visible = false

func ranking() -> Array[Plush]:
	var r: Array[Plush] = []
	r.append_array(alive)
	var rev := out_order.duplicate()
	rev.reverse()
	r.append_array(rev)
	return r

func _finish() -> void:
	phase = "done"
	stage.set_zones_visible(false)
	stage.board.show_marquee(I18n.t("arena.lobby_board"))
	var rk := ranking()
	var names: Array = []
	for p in rk:
		names.append(p.player_name)
	var title := I18n.t("arena.draw")
	if alive.size() == 1:
		title = I18n.t("arena.winner", {"name": alive[0].player_name})
	elif alive.is_empty() and rk.size() > 0:
		title = I18n.t("arena.winner", {"name": rk[0].player_name})
	log_lines.append("WIN " + (names[0] if names.size() > 0 else "-"))
	Profile.record_match(names, "arena")
	Sfx.play("fanfare", -2.0)
	Sfx.play("applause", -6.0)
	if rk.size() > 0 and is_instance_valid(rk[0]):
		stage.set_gold_target(rk[0])
	_say(title, UIKit.GOLD)
	if ui:
		ui.hud_set_timer(0.0, 1.0)
		await _wait(1.6)
		ui.show_result(title, names)
	finished.emit(names)
