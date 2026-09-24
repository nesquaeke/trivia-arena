class_name ConquestQuiz
extends Node
## Conquest Quiz — bölge hakimiyeti.
## Sahne 7x4 karoya bölünür. Her soruda bir hedef karo (her dördüncü soruda
## 2x2'lik büyük ödül) altın spotla işaretlenir. Sahnenin kenarlarında
## A-B-C-D pirinç kürsüleri durur: doğru şıkkın kürsüsüne İLK basan hedefi
## kendi rengine boyar. Yanlış kürsüye basan elektrik çarpmasıyla yere serilir
## ve o soruda bir daha deneyemez. Kendi renginde koşan hızlanır, rakibin
## boyasında yavaşlar. Sorular bitince en çok karosu olan kazanır.

signal finished(ranking: Array)

const COLS := 7
const ROWS := 4
const TILE := Vector2(1.55, 1.45)
const ORIGIN := Vector3(-5.425, 0, -3.1)     # sol-arka karonun köşesi
const QUESTIONS := 12
const PED_POS := [Vector3(-6.45, 0, -2.3), Vector3(6.45, 0, -2.3), Vector3(-6.45, 0, 1.7), Vector3(6.45, 0, 1.7)]
const BOT_ACC := {"easy": [0.7, 0.55, 0.4], "normal": [0.86, 0.7, 0.55], "hard": [0.95, 0.86, 0.72]}
const BOT_READ := {"easy": 1.35, "normal": 1.0, "hard": 0.75}

var game: Node
var stage: Stage
var ui: Node
var contestants: Array[Plush] = []
var tile_owner := {}                  # Vector2i -> Plush
var tiles := {}                  # Vector2i -> MeshInstance3D
var pedestals: Array[Area3D] = []
var ped_labels: Array[Label3D] = []
var target: Array[Vector2i] = []
var q_index := 0
var item := {}
var face := {}
var timer_total := 10.0
var time_left := 0.0
var phase := "idle"              # idle | question | reveal | done
var level := "normal"
var rng := RandomNumberGenerator.new()
var winner_of_q: Plush = null
var log_lines: Array[String] = []
var _root: Node3D
var _locked := {}                # bu soruda yanlış kürsüye basanlar
var _bot_plan := {}
var _mats := {}
var _target_spot: SpotLight3D
var _t := 0.0
var _tick := 99

func setup(p_game: Node, actors: Array[Plush], p_timer: float, p_level: String, seed_val := 0) -> void:
	game = p_game
	stage = game.stage
	ui = game.ui
	contestants = actors.duplicate()
	timer_total = p_timer
	level = p_level
	if seed_val != 0:
		rng.seed = seed_val
	else:
		rng.randomize()
	Questions.reset_used()
	_build()

func _exit_tree() -> void:
	if _root and is_instance_valid(_root):
		_root.queue_free()
	for p in contestants:
		if is_instance_valid(p):
			p.speed_mult = 1.0

# ── sahne kurulumu ──────────────────────────────────────────────────
func _mat(key: String, c: Color, emit := 0.0, alpha := 1.0) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c, alpha)
	m.roughness = 0.6
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	_mats[key] = m
	return m

func _build() -> void:
	_root = Node3D.new()
	_root.name = "ConquestBoard"
	stage.add_child(_root)
	for cx in COLS:
		for cz in ROWS:
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(TILE.x - 0.08, 0.03, TILE.y - 0.08)
			mi.mesh = bm
			mi.position = tile_center(Vector2i(cx, cz)) + Vector3(0, 0.016, 0)
			mi.material_override = _mat("free", Color("2B1418"), 0.0, 0.75)
			_root.add_child(mi)
			tiles[Vector2i(cx, cz)] = mi
	for i in 4:
		var a := Area3D.new()
		a.position = PED_POS[i]
		_root.add_child(a)
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.7
		cyl.height = 1.2
		cs.shape = cyl
		cs.position = Vector3(0, 0.6, 0)
		a.add_child(cs)
		# pirinç kürsü (üstüne çıkılır)
		var body := StaticBody3D.new()
		a.add_child(body)
		var bcs := CollisionShape3D.new()
		var bc := CylinderShape3D.new()
		bc.radius = 0.75
		bc.height = 0.22
		bcs.shape = bc
		bcs.position = Vector3(0, 0.11, 0)
		body.add_child(bcs)
		var mesh := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.72
		cm.bottom_radius = 0.8
		cm.height = 0.22
		cm.radial_segments = 32
		mesh.mesh = cm
		mesh.position = Vector3(0, 0.11, 0)
		mesh.material_override = Stage.m_gold()
		body.add_child(mesh)
		var top := MeshInstance3D.new()
		var tc := CylinderMesh.new()
		tc.top_radius = 0.6
		tc.bottom_radius = 0.6
		tc.height = 0.02
		top.mesh = tc
		top.position = Vector3(0, 0.23, 0)
		top.material_override = _mat("ped%d" % i, Stage.ZONE_COLORS[i], 0.6)
		body.add_child(top)
		var letter := Label3D.new()
		letter.text = Stage.LETTERS[i]
		letter.font = load("res://assets/fonts/Limelight-Regular.ttf")
		letter.font_size = 200
		letter.pixel_size = 0.005
		letter.modulate = Stage.ZONE_COLORS[i]
		letter.outline_size = 16
		letter.outline_modulate = Color(0.08, 0.03, 0.02)
		letter.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		letter.position = Vector3(0, 2.1, 0)
		a.add_child(letter)
		var lab := Label3D.new()
		lab.font = load("res://assets/fonts/PlayfairDisplay.ttf")
		lab.font_size = 56
		lab.pixel_size = 0.005
		lab.outline_size = 14
		lab.outline_modulate = Color(0.06, 0.02, 0.02, 0.95)
		lab.modulate = Color("FFF1D6")
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lab.width = 560
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.position = Vector3(0, 1.45, 0)
		a.add_child(lab)
		ped_labels.append(lab)
		a.body_entered.connect(_on_pedestal.bind(i))
		pedestals.append(a)
	_target_spot = SpotLight3D.new()
	_target_spot.light_color = Color(1.0, 0.82, 0.4)
	_target_spot.light_energy = 22.0
	_target_spot.spot_angle = 9.0
	_target_spot.spot_range = 16.0
	_target_spot.light_volumetric_fog_energy = 2.0
	_target_spot.visible = false
	_root.add_child(_target_spot)

func tile_center(c: Vector2i) -> Vector3:
	return ORIGIN + Vector3((c.x + 0.5) * TILE.x, 0, (c.y + 0.5) * TILE.y)

func tile_at(p: Vector3) -> Vector2i:
	var lx := int(floor((p.x - ORIGIN.x) / TILE.x))
	var lz := int(floor((p.z - ORIGIN.z) / TILE.y))
	if lx < 0 or lz < 0 or lx >= COLS or lz >= ROWS:
		return Vector2i(-1, -1)
	return Vector2i(lx, lz)

func count_for(p: Plush) -> int:
	var n := 0
	for k in tile_owner:
		if tile_owner[k] == p:
			n += 1
	return n

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
	_ui_top()
	await _wait(0.8)
	while phase != "done":
		await _ask()
		await _resolve()
		q_index += 1
		if q_index >= QUESTIONS or _free_tiles().is_empty():
			_finish()

func _wait(s: float) -> void:
	await get_tree().create_timer(s, false, true).timeout

func _say(text: String, accent := UIKit.GOLD, sub := "") -> void:
	log_lines.append(text)
	if ui:
		ui.hud_set_msg(text, accent, sub)

func _standings() -> String:
	var rows := []
	for p in _ranked():
		rows.append("%s %d" % [p.player_name, count_for(p)])
	return "  ·  ".join(rows)

func _ui_top() -> void:
	if ui:
		ui.hud_set_top(I18n.t("arena.round", {"n": q_index + 1}) + " / %d" % QUESTIONS, _standings())

func _free_tiles() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for k in tiles:
		if not tile_owner.has(k):
			out.append(k)
	return out

func _pick_target() -> void:
	target.clear()
	var pool := _free_tiles()
	if pool.is_empty():
		for k in tiles:
			pool.append(k)
	var c: Vector2i = pool[rng.randi() % pool.size()]
	target.append(c)
	if (q_index + 1) % 4 == 0:
		# büyük ödül: 2x2 blok
		var bx := clampi(c.x, 0, COLS - 2)
		var bz := clampi(c.y, 0, ROWS - 2)
		target.clear()
		for dx in 2:
			for dz in 2:
				target.append(Vector2i(bx + dx, bz + dz))
	var mid := Vector3.ZERO
	for k in target:
		mid += tile_center(k)
		tiles[k].material_override = _mat("target", Color("F2C66A"), 1.4, 0.95)
	mid /= target.size()
	_target_spot.visible = true
	_target_spot.global_position = mid + Vector3(0, 9.0, 2.5)
	_target_spot.look_at(mid, Vector3.UP)

func _ask() -> void:
	_locked.clear()
	winner_of_q = null
	_pick_target()
	item = Questions.draw(q_index, rng)
	face = Questions.face(item, I18n.lang)
	stage.board.show_question(q_index, face.prompt, face.options, face.cat_name, face.cat_color, timer_total)
	for i in 4:
		ped_labels[i].text = String(face.options[i])
	_ui_top()
	_say(I18n.t("conquest.run") if target.size() == 1 else I18n.t("conquest.big"))
	Sfx.play("ding", -4.0, 1.1)
	if game.has_method("notify_phones"):
		game.notify_phones({"t": "status", "text": I18n.t("conquest.phone", {"n": q_index + 1})})
	_plan_bots()
	time_left = timer_total
	_tick = 99
	phase = "question"
	while time_left > 0.0 and phase == "question":
		await get_tree().physics_frame

func _physics_process(delta: float) -> void:
	_t += delta
	# kendi boyanda hız, rakip boyasında yavaşlama
	for p in contestants:
		if not is_instance_valid(p) or not p.is_active():
			continue
		var c := tile_at(p.global_position)
		var o: Plush = tile_owner.get(c)
		p.speed_mult = 1.0 if o == null else (1.15 if o == p else 0.82)
	for k in target:
		if tiles.has(k) and not tile_owner.has(k):
			var m := _mat("target", Color("F2C66A"), 1.4, 0.95)
			m.emission_energy_multiplier = 1.0 + 0.8 * sin(_t * 6.0)
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
	_drive_bots()

func _on_pedestal(body: Node3D, i: int) -> void:
	if phase != "question" or not (body is Plush):
		return
	var p := body as Plush
	if not contestants.has(p) or _locked.has(p):
		return
	if i == int(face.correct):
		winner_of_q = p
		phase = "reveal"
		Sfx.play("fanfare", -8.0, 1.3)
	else:
		_locked[p] = true
		Sfx.play("buzz", -2.0)
		p.apply_central_impulse(Vector3(0, 4.5, 0) * p.mass)
		p.tumble(Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized(), 0.9)
		if game.has_method("notify_player"):
			game.notify_player(p, {"t": "buzz", "ms": 250})

func _bot_acc(tier: String) -> float:
	var arr: Array = BOT_ACC.get(level, BOT_ACC.normal)
	return float(arr[{"d1": 0, "d2": 1, "d3": 2}.get(tier, 1)])

func _plan_bots() -> void:
	_bot_plan.clear()
	var read: float = (1.0 + String(face.prompt).length() * 0.028) * float(BOT_READ.get(level, 1.0))
	for p in contestants:
		if not (p.controller is Controllers.Bot):
			continue
		var pick: int = face.correct
		if rng.randf() > _bot_acc(item.tier):
			var wrong := [0, 1, 2, 3]
			wrong.erase(face.correct)
			pick = wrong[rng.randi() % 3]
		var at: float = clamp(read + rng.randf_range(-0.5, 1.5), 0.8, timer_total - 1.0)
		_bot_plan[p] = {"ped": pick, "at": timer_total - at}
		p.controller.go_to(Vector3(rng.randf_range(-2.0, 2.0), 0, rng.randf_range(-1.0, 1.0)))

func _drive_bots() -> void:
	for p in _bot_plan:
		if not is_instance_valid(p) or not p.is_active():
			continue
		var plan: Dictionary = _bot_plan[p]
		if _locked.has(p):
			if not plan.get("retreat", false):
				plan.retreat = true
				p.controller.go_to(Vector3(rng.randf_range(-2.5, 2.5), 0, rng.randf_range(-1.5, 1.0)))
			continue
		if time_left <= plan.at and not plan.get("going", false):
			plan.going = true
			p.controller.go_to(PED_POS[plan.ped])

func _resolve() -> void:
	phase = "reveal"
	if ui:
		ui.hud_set_timer(0.0, timer_total)
	var correct: int = face.correct
	stage.board.reveal = correct
	var ans: String = Stage.LETTERS[correct] + " · " + String(face.options[correct])
	if winner_of_q:
		var col: Color = PlushVisual.COLORS.get(String(winner_of_q.look.get("color", "mustard")), Color.WHITE)
		for k in target:
			tile_owner[k] = winner_of_q
			tiles[k].material_override = _mat("own" + col.to_html(), col, 0.35)
		Sfx.play("applause", -10.0)
		if game.cam:
			game.cam.add_trauma(0.25)
		_say(I18n.t("conquest.claim", {"name": winner_of_q.player_name, "n": target.size()}), col.lightened(0.2), I18n.t("arena.correct", {"x": ans}))
		log_lines.append("CLAIM %s %d" % [winner_of_q.player_name, target.size()])
	else:
		for k in target:
			if not tile_owner.has(k):
				tiles[k].material_override = _mat("free", Color("2B1418"), 0.0, 0.75)
		_say(I18n.t("conquest.nobody"), Color("F2C66A"), I18n.t("arena.correct", {"x": ans}))
		Sfx.play("buzz", -6.0)
	_target_spot.visible = false
	_ui_top()
	await _wait(2.6)
	stage.board.reveal = -1

func on_fell_out(p: Plush) -> void:
	# Conquest'te eleme yok: öne düşen kulisten geri gelir
	Sfx.play("scream", -6.0, rng.randf_range(0.9, 1.2))
	await _wait(1.4)
	if is_instance_valid(p):
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		p.revive(Vector3(side * 5.2, 0.3, 3.4))

func _ranked() -> Array[Plush]:
	var r := contestants.duplicate()
	r.sort_custom(func(a, b): return count_for(a) > count_for(b))
	return r

func ranking() -> Array[Plush]:
	return _ranked()

func _finish() -> void:
	phase = "done"
	_target_spot.visible = false
	stage.board.show_marquee(I18n.t("arena.lobby_board"))
	var rk := _ranked()
	var names: Array = []
	for p in rk:
		names.append(p.player_name)
	var title := I18n.t("conquest.winner", {"name": rk[0].player_name, "n": count_for(rk[0])})
	log_lines.append("WIN " + rk[0].player_name)
	Profile.record_match(names, "conquest")
	Sfx.play("fanfare", -2.0)
	Sfx.play("applause", -6.0)
	stage.set_gold_target(rk[0])
	if game.has_method("notify_player"):
		game.notify_player(rk[0], {"t": "status", "text": I18n.t("house.status_win")})
	_say(title, UIKit.GOLD)
	if ui:
		await _wait(1.6)
		ui.show_result(title, names)
	finished.emit(names)
