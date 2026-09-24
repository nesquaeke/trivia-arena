extends Node3D
## Oyunun yönetmeni: sahneyi, dekorları, oyuncuları, kamerayı ve arayüzü kurar;
## lobi / kostüm odası / loca / Trivia Arena durumları arasında geçiş yapar.

enum Mode { LOBBY, WARDROBE, LOGE, ARENA }

const BOT_NAMES := ["Zeynep", "Mert", "Deniz", "Roket", "Aslı", "Kuzey", "Ece", "Tuna"]
const BOT_LOOKS := [
	{"color": "rose", "hat": "bowler", "mustache": "none", "bowtie": "dotted"},
	{"color": "sky", "hat": "fez", "mustache": "walrus", "bowtie": "none"},
	{"color": "mint", "hat": "boater", "mustache": "pencil", "bowtie": "classic"},
	{"color": "tangerine", "hat": "crown", "mustache": "chevron", "bowtie": "big"},
	{"color": "lilac", "hat": "cone", "mustache": "none", "bowtie": "classic"},
	{"color": "charcoal", "hat": "tophat", "mustache": "handlebar", "bowtie": "big"},
	{"color": "butter", "hat": "none", "mustache": "walrus", "bowtie": "dotted"},
	{"color": "mustard", "hat": "fez", "mustache": "chevron", "bowtie": "none"},
]
const SPAWNS := [Vector3(-1.2, 0.05, 1.0), Vector3(1.4, 0.05, 0.6), Vector3(-3.4, 0.05, -1.6), Vector3(3.2, 0.05, -2.0),
	Vector3(0.0, 0.05, -2.4), Vector3(-5.6, 0.05, 2.8), Vector3(5.4, 0.05, -0.2), Vector3(-0.4, 0.05, 3.2)]

var mode: int = Mode.LOBBY
var stage: Stage
var props: Props
var cam: BalconyCam
var ui: Node = null
var arena: Node = null
var players: Array[Plush] = []       # insanlar (yerel)
var bots: Array[Plush] = []
var actors_root: Node3D
var _joined_sets := {}               # "kb0", "kb1", "pad0"… → Plush
var bridge: PhoneBridge = null
var phone_players := {}              # pid -> Plush
var _relay_override := ""
var _shot_mode := ""
var _shot_dir := "/tmp/ta_shots"

func _ready() -> void:
	randomize()
	I18n.set_lang(String(Profile.data.get("lang", "tr")))
	stage = Stage.new()
	stage.name = "Stage"
	add_child(stage)
	props = Props.new()
	props.name = "Props"
	add_child(props)
	props.build_lobby_set()
	actors_root = Node3D.new()
	actors_root.name = "Actors"
	add_child(actors_root)
	cam = BalconyCam.new()
	cam.name = "Camera"
	add_child(cam)

	_join("kb0", Controllers.Keyboard.new(0), Profile.player_name(), Profile.look(), false)
	_refill_bots(int(Profile.setting("bots", 3)))
	_update_focus()

	if ResourceLoader.exists("res://scripts/ui/ui_root.gd"):
		ui = load("res://scripts/ui/ui_root.gd").new()
		ui.name = "UI"
		add_child(ui)
		ui.setup(self)

	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_shot_mode = a.substr(7)
		elif a.begins_with("--shotdir="):
			_shot_dir = a.substr(10)
		elif a.begins_with("--relay="):
			_relay_override = a.substr(8)
		elif a.begins_with("--timescale="):
			Engine.time_scale = float(a.substr(12))
	if _shot_mode != "":
		_run_shot_script()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_SHIFT and event.location == KEY_LOCATION_RIGHT:
		Controllers.right_shift_down = event.pressed

var _t := 0.0

func _physics_process(delta: float) -> void:
	_t += delta
	if mode == Mode.LOBBY:
		_poll_joins()
	elif mode == Mode.WARDROBE:
		var p1 := player_one()
		if p1:
			p1.facing = sin(_t * 0.7) * 0.75
	_update_streak_spot()

# ── oyuncular ───────────────────────────────────────────────────────
func _spawn(p_name: String, look: Dictionary, bot: bool, ctrl: Object) -> Plush:
	var p := Plush.new(p_name, look, bot)
	p.controller = ctrl
	actors_root.add_child(p)
	var used := players.size() + bots.size()
	p.teleport(SPAWNS[used % SPAWNS.size()] + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3)), randf_range(-0.6, 0.6))
	p.fell_out.connect(_on_fell_out)
	return p

func _join(key: String, ctrl: Object, p_name: String, look: Dictionary, announce := true) -> Plush:
	var p := _spawn(p_name, look, false, ctrl)
	players.append(p)
	_joined_sets[key] = p
	if announce:
		Sfx.play("ding", -6.0, 1.2)
		if bots.size() > 0 and players.size() + bots.size() > 8:
			var b: Plush = bots.pop_back()
			b.queue_free()
	_update_focus()
	return p

func _poll_joins() -> void:
	if not _joined_sets.has("kb1") and Controllers.Keyboard.wants_join(1):
		var n := "Oyuncu %d" % (players.size() + 1)
		var look := {"color": "sky", "hat": "bowler", "mustache": "pencil", "bowtie": "classic"}
		_join("kb1", Controllers.Keyboard.new(1), n, look)
	for d in Input.get_connected_joypads():
		var key := "pad%d" % d
		if not _joined_sets.has(key) and Input.is_joy_button_pressed(d, JOY_BUTTON_A):
			var n2 := "Oyuncu %d" % (players.size() + 1)
			var look2: Dictionary = BOT_LOOKS[(players.size() + 3) % BOT_LOOKS.size()]
			_join(key, Controllers.Gamepad.new(d), n2, look2)

func _refill_bots(count: int) -> void:
	for b in bots:
		b.queue_free()
	bots.clear()
	var lvl := String(Profile.setting("bot_level", "normal"))
	var aggr: float = {"easy": 0.12, "normal": 0.25, "hard": 0.4}.get(lvl, 0.25)
	for i in count:
		var ctrl := Controllers.Bot.new(1000 + i * 17, aggr)
		var b := _spawn(BOT_NAMES[i % BOT_NAMES.size()], BOT_LOOKS[i % BOT_LOOKS.size()], true, ctrl)
		bots.append(b)
	_update_focus()

func all_actors() -> Array[Plush]:
	var a: Array[Plush] = []
	a.append_array(players)
	a.append_array(bots)
	return a

func _update_focus() -> void:
	if cam:
		cam.focus = all_actors()

func _on_fell_out(p: Plush) -> void:
	if mode == Mode.ARENA and arena:
		arena.on_fell_out(p)
		return
	# lobide düşen kulisten geri gelir
	Sfx.play("scream", -8.0, randf_range(0.9, 1.2))
	await get_tree().create_timer(1.2).timeout
	if is_instance_valid(p):
		var side := -1.0 if randf() < 0.5 else 1.0
		p.revive(Vector3(side * 7.2, 0.3, randf_range(-3.5, 0.5)))

func _update_streak_spot() -> void:
	if mode != Mode.LOBBY:
		stage.set_gold_target(null)
		return
	var names := []
	for p in all_actors():
		names.append(p.player_name)
	var leader := Profile.streak_leader(names)
	var target: Plush = null
	for p in all_actors():
		if p.player_name == leader:
			target = p
	if target != stage._gold_target:
		stage.set_gold_target(target)

func player_one() -> Plush:
	return players[0] if players.size() > 0 else null

# ── arayüzün çağırdıkları ───────────────────────────────────────────
func set_bot_count(n: int) -> void:
	_refill_bots(n)

func apply_bot_level() -> void:
	var lvl := String(Profile.setting("bot_level", "normal"))
	var aggr: float = {"easy": 0.12, "normal": 0.25, "hard": 0.4}.get(lvl, 0.25)
	for b in bots:
		b.controller.aggression = aggr

func rename_player_one(_old: String, new_name: String) -> void:
	var p1 := player_one()
	if p1:
		p1.player_name = new_name

func apply_look_to_player_one() -> void:
	var p1 := player_one()
	if p1:
		p1.set_look(Profile.look())

func _bots_wander() -> void:
	for b in bots:
		b.controller.wander()

# ── kostüm odası ────────────────────────────────────────────────────
func enter_wardrobe() -> void:
	if mode != Mode.LOBBY:
		return
	mode = Mode.WARDROBE
	var p1 := player_one()
	if p1:
		p1.frozen_input = true
		p1.teleport(Vector3(0, 0.05, 0.7), 0.0)
		p1.freeze = true
	for b in bots:
		b.controller.go_to(Vector3(randf_range(-6.0, 6.0), 0, randf_range(-4.2, -3.4)))
	stage.set_solo(true)
	stage.set_gold_target(null)
	cam.set_shot(BalconyCam.Shot.WARDROBE)
	Sfx.play("whoosh", -8.0, 1.2)

func exit_wardrobe() -> void:
	var p1 := player_one()
	if p1:
		p1.freeze = false
		p1.frozen_input = false
	stage.set_solo(false)
	cam.set_shot(BalconyCam.Shot.LOBBY)
	_bots_wander()
	mode = Mode.LOBBY

# ── loca (izleyici) ─────────────────────────────────────────────────

var _thrown: Array[Node3D] = []

func enter_loge() -> void:
	if mode != Mode.LOBBY:
		return
	mode = Mode.LOGE
	cam.set_custom(stage.loge_camera())
	stage.set_gold_target(null)

func exit_loge() -> void:
	cam.set_shot(BalconyCam.Shot.LOBBY)
	mode = Mode.LOBBY

## Locadan sahneye bir şey fırlat: gül, domates ya da silindir şapka.
func throw_item(kind: String) -> void:
	var b := RigidBody3D.new()
	b.mass = 0.3
	b.add_to_group("prop")
	b.contact_monitor = true
	b.max_contacts_reported = 2
	var cs := CollisionShape3D.new()
	var mi := MeshInstance3D.new()
	var m := StandardMaterial3D.new()
	m.roughness = 0.5
	match kind:
		"rose":
			var sh := CapsuleShape3D.new()
			sh.radius = 0.06
			sh.height = 0.5
			cs.shape = sh
			var stem := CylinderMesh.new()
			stem.top_radius = 0.012
			stem.bottom_radius = 0.012
			stem.height = 0.45
			mi.mesh = stem
			m.albedo_color = Color("2F6B2A")
			var bloom := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.07
			sm.height = 0.12
			bloom.mesh = sm
			var bm := StandardMaterial3D.new()
			bm.albedo_color = Color("C0142A")
			bm.roughness = 0.6
			bloom.material_override = bm
			bloom.position = Vector3(0, 0.25, 0)
			b.add_child(bloom)
		"tomato":
			var ss := SphereShape3D.new()
			ss.radius = 0.1
			cs.shape = ss
			var tm := SphereMesh.new()
			tm.radius = 0.1
			tm.height = 0.18
			mi.mesh = tm
			m.albedo_color = Color("D2301E")
			m.roughness = 0.25
			b.body_entered.connect(func(_o):
				if not b.has_meta("splat"):
					b.set_meta("splat", true)
					Sfx.play("land", -2.0, 1.5)
					mi.scale = Vector3(1.8, 0.35, 1.8))
		_:
			var cy := CylinderShape3D.new()
			cy.radius = 0.2
			cy.height = 0.3
			cs.shape = cy
			var hm := CylinderMesh.new()
			hm.top_radius = 0.14
			hm.bottom_radius = 0.15
			hm.height = 0.3
			mi.mesh = hm
			m.albedo_color = Color("141014")
			var brim := MeshInstance3D.new()
			var bmesh := CylinderMesh.new()
			bmesh.top_radius = 0.24
			bmesh.bottom_radius = 0.24
			bmesh.height = 0.02
			brim.mesh = bmesh
			brim.material_override = m
			brim.position = Vector3(0, -0.14, 0)
			b.add_child(brim)
	mi.material_override = m
	b.add_child(cs)
	b.add_child(mi)
	add_child(b)
	b.global_position = stage.loge.to_global(Vector3(randf_range(-0.6, 0.6), 1.2, 1.3))
	var target := Vector3(randf_range(-4.5, 3.5), 0, randf_range(-2.5, 2.8))
	var d := target - b.global_position
	var t := 1.15
	var v := Vector3(d.x / t, (d.y + 0.5 * 9.8 * t * t) / t, d.z / t)
	b.linear_velocity = v
	b.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
	Sfx.play("whoosh", -12.0, 1.8)
	_thrown.append(b)
	while _thrown.size() > 30:
		var old: Node3D = _thrown.pop_front()
		if is_instance_valid(old):
			old.queue_free()

# ── Trivia Arena ────────────────────────────────────────────────────
func _reset_lobby_layout() -> void:
	if arena:
		arena.queue_free()
		arena = null
	stage.close_all_trapdoors()
	stage.set_zones_visible(false)
	stage.board.show_marquee(I18n.t("arena.lobby_board"))
	props.build_lobby_set()
	var all := all_actors()
	for i in all.size():
		all[i].visible = true
		all[i].frozen_input = false
		all[i].revive(SPAWNS[i % SPAWNS.size()])
	_bots_wander()
	cam.set_shot(BalconyCam.Shot.LOBBY, true)
	notify_phones({"t": "in_game"})
	notify_phones({"t": "status", "text": I18n.t("house.status_lobby")})

func start_arena() -> void:
	if mode != Mode.LOBBY:
		return
	mode = Mode.ARENA
	stage.set_gold_target(null)
	if ui:
		ui.show_lobby_chrome(false)
	stage.set_curtain(true)
	await stage.curtain_done
	props.build_arena_set()
	cam.set_shot(BalconyCam.Shot.ARENA, true)
	arena = TriviaArena.new()
	arena.name = "Arena"
	add_child(arena)
	var actors := all_actors()
	for p in actors:
		p.visible = true
		p.freeze = false
		p.frozen_input = false
	arena.setup(self, actors, float(Profile.setting("timer", 10)), String(Profile.setting("bot_level", "normal")))
	arena.line_up()
	if ui:
		ui.hud_show(true)
		ui.hud_set_msg("")
	await get_tree().create_timer(0.5).timeout
	stage.set_curtain(false)
	await stage.curtain_done
	arena.run()

func end_arena() -> void:
	stage.set_curtain(true)
	await stage.curtain_done
	_reset_lobby_layout()
	if ui:
		ui.hud_show(false)
		ui.show_lobby_chrome(true)
	mode = Mode.LOBBY
	await get_tree().create_timer(0.3).timeout
	stage.set_curtain(false)

func restart_arena() -> void:
	stage.set_curtain(true)
	await stage.curtain_done
	_reset_lobby_layout()
	mode = Mode.LOBBY
	stage.curtain_closed = false
	house_open_instant()
	start_arena()

func house_open_instant() -> void:
	stage.house_l.position.x = -13.8
	stage.house_r.position.x = 13.8

# ── ev partisi: telefonlar kumanda ─────────────────────────────────
func relay_url() -> String:
	if _relay_override != "":
		return _relay_override
	return String(Profile.setting("relay_url", "ws://localhost:3000/ws"))

func start_house(url := "") -> void:
	if url != "":
		Profile.set_setting("relay_url", url)
		_relay_override = ""
	if bridge == null:
		bridge = PhoneBridge.new()
		bridge.name = "PhoneBridge"
		add_child(bridge)
		bridge.pad_joined.connect(_on_pad_joined)
		bridge.pad_left.connect(_on_pad_left)
	bridge.stop()
	bridge.start(relay_url())

func stop_house() -> void:
	if bridge:
		bridge.stop()
	for pid in phone_players.keys():
		_remove_player(phone_players[pid])
	phone_players.clear()

func _free_color() -> String:
	var used := {}
	for p in all_actors():
		used[String(p.look.get("color", ""))] = true
	for c in PlushVisual.COLOR_KEYS:
		if not used.has(c):
			return c
	return PlushVisual.COLOR_KEYS[randi() % PlushVisual.COLOR_KEYS.size()]

func _on_pad_joined(pid: String, pad_name: String) -> void:
	var p: Plush = phone_players.get(pid)
	if p and is_instance_valid(p):
		p.set_meta("left_at", -1.0)      # geri döndü
	else:
		var look: Dictionary = BOT_LOOKS[(players.size() * 3 + 1) % BOT_LOOKS.size()].duplicate()
		look.color = _free_color()
		p = _join("ph:" + pid, Controllers.Phone.new(bridge, pid), pad_name, look)
		phone_players[pid] = p
		if mode == Mode.ARENA:
			p.visible = false
			p.freeze = true
	bridge.send_to(pid, {"t": "you", "name": p.player_name, "lang": I18n.lang, "color": "#" + PlushVisual.COLORS[p.look.color].to_html(false)})
	bridge.send_to(pid, {"t": "status", "text": I18n.t("house.status_lobby")})
	if ui and ui.has_method("refresh_house"):
		ui.refresh_house()

func _on_pad_left(pid: String) -> void:
	var p: Plush = phone_players.get(pid)
	if p == null:
		return
	var stamp := Time.get_ticks_msec() / 1000.0
	p.set_meta("left_at", stamp)
	if ui and ui.has_method("refresh_house"):
		ui.refresh_house()
	# 20 sn içinde geri gelmezse sahneden çıkar
	await get_tree().create_timer(20.0).timeout
	if is_instance_valid(p) and float(p.get_meta("left_at", -1.0)) == stamp and mode != Mode.ARENA:
		phone_players.erase(pid)
		_remove_player(p)
		if ui and ui.has_method("refresh_house"):
			ui.refresh_house()

func _remove_player(p: Plush) -> void:
	if not is_instance_valid(p):
		return
	players.erase(p)
	for k in _joined_sets.keys():
		if _joined_sets[k] == p:
			_joined_sets.erase(k)
	p.queue_free()
	_update_focus()

## Telefon oyuncusuna kısa mesaj (renk, durum, elendin…)
func notify_player(p: Plush, msg: Dictionary) -> void:
	if bridge and p and p.controller is Controllers.Phone:
		bridge.send_to(p.controller.pid, msg)

func notify_phones(msg: Dictionary) -> void:
	if bridge and bridge.state == "live":
		bridge.broadcast(msg)

func start_conquest() -> void:
	if ui:
		ui.open_howto("conquest")

func prepare_game_shot(part: String) -> void:
	match part:
		"arena_q":
			start_arena()
			while arena == null or arena.phase != "question" or arena.time_left > arena.timer_total - 4.0:
				await get_tree().process_frame
		"arena_open":
			while arena == null or arena.phase != "reveal":
				await get_tree().process_frame
			await get_tree().create_timer(1.5).timeout
		"result":
			while ui == null or not ui.result_panel.visible:
				await get_tree().process_frame
			await get_tree().create_timer(0.8).timeout
		_:
			await get_tree().create_timer(1.0).timeout

# ── ekran görüntüsü senaryoları (araç) ─────────────────────────────
func _run_shot_script() -> void:
	var dir := _shot_dir.trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(dir)
	var parts := _shot_mode.split(",")
	for part in parts:
		await _prepare_shot(part)
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(dir + part + ".png")
		print("SHOT ", part)
	get_tree().quit()

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _prepare_shot(part: String) -> void:
	match part:
		"lobby":
			await _wait(3.0)
		"lobby_en":
			I18n.set_lang("en")
			await _wait(1.0)
		_:
			if ui and ui.has_method("prepare_shot"):
				await ui.prepare_shot(part)
			else:
				await _wait(1.0)
