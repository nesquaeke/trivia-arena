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
var debug_round := 1                 # --round=3: Trivia'yı can turundan başlat (deneme)
var debug_ff := 1.0                  # --ff=2: bekleme sürelerini kısalt (deneme)

func _ready() -> void:
	randomize()
	I18n.set_lang(String(Profile.data.get("lang", "tr")))
	# Sahne ağacı scenes/main.tscn'de: Stage, Props, Actors, Camera, UI.
	# Editörde bu düğümlere tıklayıp Inspector'dan ayarlarını değiştirebilirsin.
	stage = get_node_or_null("Stage")
	if stage == null:
		stage = Stage.new()
		stage.name = "Stage"
		add_child(stage)
	props = get_node_or_null("Props")
	if props == null:
		props = Props.new()
		props.name = "Props"
		add_child(props)
	props.build_lobby_set()
	actors_root = get_node_or_null("Actors")
	if actors_root == null:
		actors_root = Node3D.new()
		actors_root.name = "Actors"
		add_child(actors_root)
	cam = get_node_or_null("Camera")
	if cam == null:
		cam = BalconyCam.new()
		cam.name = "Camera"
		add_child(cam)

	_join("kb0", Controllers.Keyboard.new(0), Profile.player_name(), Profile.look(), false)
	_refill_bots(int(Profile.setting("bots", 3)))
	_update_focus()

	ui = get_node_or_null("UI")
	if ui == null:
		ui = load("res://scripts/ui/ui_root.gd").new()
		ui.name = "UI"
		add_child(ui)
	ui.setup(self)
	GameSettings.apply_all(get_tree())
	# Steam'deki adı ilk açılışta sahne adı yap (oyuncu sonradan değiştirebilir)
	if SteamService.available and Profile.player_name() in ["Oyuncu", "Player", ""] and SteamService.player_name() != "":
		Profile.set_player_name(SteamService.player_name())
		rename_player_one("", Profile.player_name())

	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_shot_mode = a.substr(7)
		elif a.begins_with("--shotdir="):
			_shot_dir = a.substr(10)
		elif a.begins_with("--relay="):
			_relay_override = a.substr(8)
		elif a.begins_with("--timescale="):
			Engine.time_scale = float(a.substr(12))
		elif a.begins_with("--round="):
			debug_round = int(a.substr(8))
		elif a.begins_with("--ff="):
			debug_ff = float(a.substr(5))
	if _shot_mode != "":
		Profile.save_enabled = false
		if _shot_mode.contains("result_rank"):
			Profile.data.xp = Progress.xp_for(9) - 150   # maç sonunda seviye atlasın
		elif _shot_mode.contains("unlock") or _shot_mode.contains("rank"):
			Profile.data.xp = 99999
		_run_shot_script()
	else:
		Music.play("lobby", 2.5)

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
	if _ward_castle and is_instance_valid(_ward_castle) and (_ward_castle.style != String(Profile.look().get("castle", "fairy")) or _ward_castle.banner != String(Profile.look().get("banner", "plain"))):
		wardrobe_conquest(true)

## Kostüm odasında Fetih sekmesi: pelüş kültür kostümünü giyer, yanında kalesi belirir
var _ward_castle: CastleModel = null

func wardrobe_conquest(on: bool) -> void:
	var p1 := player_one()
	if p1 == null:
		return
	var look := Profile.look()
	p1.visual.set_culture(String(look.get("culture", "janissary")) if on else "")
	if _ward_castle and is_instance_valid(_ward_castle):
		_ward_castle.queue_free()
		_ward_castle = null
	if on:
		_ward_castle = CastleModel.new(String(look.get("castle", "fairy")), PlushVisual.COLORS.get(String(look.get("color", "mustard")), Color.WHITE))
		_ward_castle.banner = String(look.get("banner", "plain"))
		add_child(_ward_castle)
		_ward_castle.position = Vector3(-1.25, 0.02, 0.35)
		_ward_castle.rotation.y = 0.35
		_ward_castle.scale = Vector3.ONE * 0.05
		create_tween().tween_property(_ward_castle, "scale", Vector3.ONE * 1.1, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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
		# koşarken açılırsa adım pozunda donmasın
		p1.linear_velocity = Vector3.ZERO
		p1.angular_velocity = Vector3.ZERO
		p1.freeze = true
	for b in bots:
		b.controller.go_to(Vector3(randf_range(-6.0, 6.0), 0, randf_range(-4.2, -3.4)))
	stage.set_solo(true)
	stage.set_gold_target(null)
	cam.set_shot(BalconyCam.Shot.WARDROBE)
	SteamService.presence("wardrobe")
	Sfx.play("whoosh", -8.0, 1.2)

func exit_wardrobe() -> void:
	wardrobe_conquest(false)
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
	b.collision_mask = 1 | 2
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
	Music.play("lobby", 2.0)
	SteamService.presence("lobby")
	notify_phones({"t": "in_game"})
	notify_phones({"t": "status", "text": I18n.t("house.status_lobby")})

var match_kind := "arena"
var _demo_map: MapBoard

func start_arena(kind := "") -> void:
	if mode != Mode.LOBBY:
		return
	if kind != "":
		match_kind = kind
	mode = Mode.ARENA
	stage.set_gold_target(null)
	if ui:
		ui.show_lobby_chrome(false)
	stage.set_curtain(true)
	Music.play("conquest" if match_kind == "conquest" else "trivia", 2.0)
	SteamService.presence("conquest" if match_kind == "conquest" else "trivia")
	Progress.begin_match()
	Narrator.say("ready")
	await stage.curtain_done
	if match_kind == "conquest":
		props.clear()
		arena = ConquestWar.new()
	else:
		props.build_arena_set()
		arena = ClassicShow.new()
	cam.set_shot(BalconyCam.Shot.ARENA, true)
	arena.name = "Arena"
	add_child(arena)
	var actors := all_actors()
	for p in actors:
		p.visible = true
		p.freeze = false
		p.frozen_input = false
	arena.setup(self, actors, float(Profile.setting("timer", 10)), String(Profile.setting("bot_level", "normal")))
	if arena is ClassicShow:
		arena.start_round = debug_round
	if "fast_forward" in arena:
		arena.fast_forward = debug_ff
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
	start_arena(match_kind)

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

## Maç bitti: başarımlar ve istatistikler (bu makinenin sahibi = 1. oyuncu)
func on_match_finished(kind: String, names: Array, extra := {}) -> void:
	var matches := SteamService.add_stat("matches", 1)
	if matches >= 25:
		SteamService.unlock("MARATHON")
	if not phone_players.is_empty():
		SteamService.unlock("HOUSE_PARTY")
	if all_actors().size() >= 8:
		SteamService.unlock("FULL_HOUSE")
	var p1 := player_one()
	if p1 == null or names.is_empty():
		return
	# Sahne Rütbesi: XP ve açılanlar (sonuç ekranı gösterir)
	var rank := names.find(p1.player_name)
	var stats: Dictionary = arena.stats_for(p1) if arena and arena.has_method("stats_for") else {}
	Progress.award(rank, stats, kind)
	if String(names[0]) != p1.player_name:
		return
	SteamService.add_stat("wins", 1)
	SteamService.unlock("FIRST_WIN")
	SteamService.unlock("CONQUEROR" if kind == "conquest" else "TRIVIA_CHAMP")
	if kind == "conquest" and bool(extra.get("untouched", false)):
		SteamService.unlock("UNTOUCHED")
	if int(Profile.record(p1.player_name).streak) >= 3:
		SteamService.unlock("STREAK_3")

func start_conquest() -> void:
	start_arena("conquest")

func prepare_game_shot(part: String) -> void:
	match part:
		"cq_estimate":
			start_arena("conquest")
			while arena == null or arena.phase != "estimate" or arena.time_left > arena.timer_total - 3.0:
				await get_tree().process_frame
		"cq_reveal":
			while arena == null or arena.phase != "reveal":
				await get_tree().process_frame
			await get_tree().create_timer(1.2).timeout
		"cq_claim":
			if arena == null:
				start_arena("conquest")
			while arena == null or arena.act < 2 or arena.log_lines.filter(func(l): return l.begins_with("CLAIM")).size() < 5:
				await get_tree().process_frame
			await get_tree().create_timer(0.4).timeout
		"cq_pick":
			if arena == null:
				start_arena("conquest")
			while arena == null or arena.phase != "pick":
				await get_tree().process_frame
			await get_tree().create_timer(1.4).timeout
		"cq_splash":
			if arena == null:
				start_arena("conquest")
			while arena == null or arena.log_lines.filter(func(l): return l.begins_with("ATTACK")).size() < 1:
				await get_tree().process_frame
			await get_tree().create_timer(0.95).timeout
		"cq_duel":
			if arena == null:
				start_arena("conquest")
			while arena == null or arena.phase != "duel" or arena.time_left > arena.timer_total - 2.5:
				await get_tree().process_frame
		"cq_war":
			while arena == null or arena.phase != "resolve":
				await get_tree().process_frame
			await get_tree().create_timer(1.0).timeout
		"arena_q":
			start_arena("arena")
			while arena == null or arena.phase != "question" or arena.time_left > arena.timer_total - 4.0:
				await get_tree().process_frame
		"arena_open":
			while arena == null or arena.phase != "reveal":
				await get_tree().process_frame
			await get_tree().create_timer(1.5).timeout
		"arena_intro":
			start_arena("arena")
			while arena == null or arena.phase != "intro":
				await get_tree().process_frame
			await get_tree().create_timer(1.6).timeout
		"arena_tug":
			if arena == null:
				start_arena("arena")
			while arena == null or arena.phase != "tug":
				await get_tree().process_frame
			await get_tree().create_timer(5.0).timeout
		"arena_reward":
			while arena == null or arena.phase != "reward":
				await get_tree().process_frame
			await get_tree().create_timer(0.7).timeout
		"result_rank":
			# maç sonu: sonuç ekranı + rütbe paneli (XP dökümü, açılanlar)
			start_arena("conquest")
			while arena == null or arena.phase != "done":
				await get_tree().process_frame
			await get_tree().create_timer(3.5).timeout
		"post_a", "post_c":
			# maçı bitir, lobiye dön, Karakterim'i aç (maç sonrası hataları için)
			start_arena("conquest" if part == "post_c" else "arena")
			while arena == null or arena.phase != "done":
				await get_tree().process_frame
			await get_tree().create_timer(3.0).timeout
			ui.hud.hide_result()
			await end_arena()
			await get_tree().create_timer(1.5).timeout
			ui._open_wardrobe()
			await get_tree().create_timer(2.5).timeout
		"post_tab":
			ui.wardrobe._tabs.selected = 1
			ui.wardrobe._tabs.changed.emit(1)
			await get_tree().create_timer(2.0).timeout
		"map_demo":
			# yalnız görüntü: haritayı kur, birkaç bölgeyi boya
			props.clear()
			stage.set_zones_visible(false)
			stage.set_map_light(true)
			var mb := MapBoard.new()
			add_child(mb)
			mb.build()
			for a in all_actors():
				a.visible = false
				a.freeze = true
			_demo_map = mb
			var ids := mb.order
			for i in 8:
				var col: Color = PlushVisual.COLORS[PlushVisual.COLOR_KEYS[i % 4]]
				mb.set_owner_color(ids[i * 2 % ids.size()], col)
			mb.set_rich(ids[3], true)
			# her bölgeye bir kale ya da kostümlü taş
			for i in ids.size():
				var col: Color = PlushVisual.COLORS[PlushVisual.COLOR_KEYS[i % 8]]
				if i < 6:
					var c := CastleModel.new(CastleModel.STYLES[i], col)
					c.set_meta("base_scale", Vector3.ONE * 1.0)
					mb.set_piece(ids[i], c)
					if i == 2:
						c.set_towers(1, false)
				else:
					var fig := ConquestPiece.new({"color": PlushVisual.COLOR_KEYS[i % 8]}, CultureCostume.CULTURES[(i - 6) % 10])
					mb.set_piece(ids[i], fig)
			mb.set_mark(ids[5], "cursor")
			mb.set_mark(ids[6], "pickable")
			cam.set_custom({"pos": Vector3(0.0, 9.4, 4.5), "look": Vector3(0.0, 0.0, -1.25), "fov": 50.0, "h": -0.6, "sway": 0.0}, true)
			if ui:
				ui.show_lobby_chrome(false)
			await get_tree().create_timer(2.0).timeout
		"map_top":
			cam.set_custom({"pos": Vector3(0.0, 12.8, 2.2), "look": Vector3(0.0, 0.0, -1.3), "fov": 44.0, "h": -0.75, "sway": 0.0}, true)
			await get_tree().create_timer(1.0).timeout
		"castle_fall":
			var id: String = _demo_map.order[0]
			var c := _demo_map.seat(id) + Vector3(0, 0.35, 0)
			cam.set_custom({"pos": c + Vector3(0, 1.6, 2.6), "look": c, "fov": 36.0, "h": 0.0, "sway": 0.0,
				"orbit": {"center": c, "radius": 3.3, "height": 1.9, "speed": 0.42, "angle": -0.5}}, true)
			await get_tree().create_timer(0.6).timeout
			(_demo_map.piece(id) as CastleModel).collapse()
			await get_tree().create_timer(1.25).timeout
		"hats_demo", "faces_demo":
			# yeni kozmetik vitrini: 10 pelüş, her birinde farklı açılan öğe
			props.clear()
			for a in all_actors():
				a.visible = false
				a.freeze = true
			var root2 := Node3D.new()
			add_child(root2)
			var hats := ["beret", "party", "tricorn", "wizard", "chef", "jester", "cowboy", "propeller", "flowers", "laurel"]
			var must := ["imperial", "goatee", "horseshoe", "curly", "beard", "handlebar", "walrus", "imperial", "curly", "goatee"]
			var neck := ["scarf", "medal", "pearls", "ascot", "rose", "bell", "scarf", "medal", "pearls", "ascot"]
			var gl := ["round", "monocle", "star", "shades", "domino", "eyepatch", "round", "star", "shades", "monocle"]
			var cols := ["cherry", "navy", "forest", "plum", "coral", "snow", "cocoa", "gold", "sky", "rose"]
			for i in 10:
				var look := {"color": cols[i], "hat": hats[i], "mustache": must[i], "bowtie": neck[i], "glasses": gl[i]}
				var pv := PlushVisual.new(look)
				root2.add_child(pv)
				var row := i / 5
				pv.position = Vector3((i % 5 - 2) * 1.05, 0.02, -0.4 + row * 1.3)
				pv.rotation.y = 0.0
			cam.set_custom({"pos": Vector3(0, 1.9, 5.6), "look": Vector3(0, 0.8, 0.2), "fov": 42.0, "h": 0.0, "sway": 0.0}, true)
			stage.set_solo(true)
			if ui:
				ui.show_lobby_chrome(false)
			await get_tree().create_timer(2.0).timeout
		"cult_demo":
			props.clear()
			for a in all_actors():
				a.visible = false
				a.freeze = true
			var root3 := Node3D.new()
			add_child(root3)
			var cs := ["knight", "pirate", "explorer"]
			for i in 3:
				var fig := ConquestPiece.new({"color": ["navy", "cherry", "forest"][i]}, cs[i])
				root3.add_child(fig)
				fig.position = Vector3(-2.3 + i * 1.1, 0.02, 0.6)
				fig.scale = Vector3.ONE * 1.4
			for j in 2:
				var c := CastleModel.new(["onion", "lighthouse"][j], PlushVisual.COLORS[["plum", "sky"][j]])
				c.banner = ["star", "sun"][j]
				root3.add_child(c)
				c.position = Vector3(1.4 + j * 1.5, 0.02, 0.2)
				c.scale = Vector3.ONE * 1.3
			cam.set_custom({"pos": Vector3(0.3, 2.0, 5.2), "look": Vector3(0.3, 0.8, 0.2), "fov": 42.0, "h": 0.0, "sway": 0.0}, true)
			stage.set_solo(true)
			if ui:
				ui.show_lobby_chrome(false)
			await get_tree().create_timer(2.0).timeout
		"costume_demo", "costume_demo2", "castle_demo":
			props.clear()
			for a in all_actors():
				a.visible = false
				a.freeze = true
			var root := Node3D.new()
			add_child(root)
			if part.begins_with("costume"):
				var first := 0 if part == "costume_demo" else 5
				for i in range(first, first + 5):
					var fig := ConquestPiece.new({"color": PlushVisual.COLOR_KEYS[i % 8]}, CultureCostume.CULTURES[i])
					root.add_child(fig)
					fig.position = Vector3((i - first - 2) * 1.25, 0, 0.3)
					fig.rotation.y = 0.0
					fig.scale = Vector3.ONE * 1.3
				cam.set_custom({"pos": Vector3(0, 2.6, 5.6), "look": Vector3(0, 0.7, 0.1), "fov": 40.0, "h": 0.0, "sway": 0.0}, true)
			else:
				for i in 6:
					var c := CastleModel.new(CastleModel.STYLES[i], PlushVisual.COLORS[PlushVisual.COLOR_KEYS[i]])
					root.add_child(c)
					c.position = Vector3((i % 3 - 1) * 2.0, 0, -0.8 + int(i / 3) * 1.8)
					c.scale = Vector3.ONE * 1.5
					if i == 4:
						c.set_towers(2, false)
				cam.set_custom({"pos": Vector3(0, 3.2, 6.2), "look": Vector3(0, 0.6, 0.0), "fov": 42.0, "h": 0.0, "sway": 0.0}, true)
			if ui:
				ui.show_lobby_chrome(false)
			await get_tree().create_timer(2.0).timeout
		"reward_demo":
			# ödül seçiciyi insan oyuncu kazanmış gibi aç (yalnız görüntü için)
			if arena is ClassicShow:
				var p1 := player_one()
				arena.award_to = p1
				arena.phase = "reward"
				arena._pick_reward(p1, arena.contestants.filter(func(x): return x != p1))
				await get_tree().create_timer(1.2).timeout
				ui.hud_reward_select(1, 2)
				await get_tree().create_timer(0.8).timeout
		"arena_standings":
			if arena == null:
				start_arena("arena")
			while arena == null or arena.phase != "standings":
				await get_tree().process_frame
			await get_tree().create_timer(1.4).timeout
		"arena_final":
			if arena == null:
				start_arena("arena")
			while arena == null or not arena.hp_mode or arena.phase != "reveal" or arena.q_index < 1:
				await get_tree().process_frame
			await get_tree().create_timer(1.2).timeout
		"result":
			if arena == null and mode == Mode.LOBBY:
				start_arena("arena")
			while ui == null or not ui.result_panel.visible:
				await get_tree().process_frame
			await get_tree().create_timer(2.6).timeout
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
