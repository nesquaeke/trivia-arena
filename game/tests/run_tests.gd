extends Node
## Başsız test çalıştırıcı:
##   godot --headless --path game res://tests/tests.tscn
## Her test bir coroutine; başarısızlıklar sayılır, çıkış kodu = hata sayısı.

var failures := 0
var passes := 0
var _only := ""

func _ready() -> void:
	# güvenlik: bir test takılırsa 170 sn sonra hata ile çık
	get_tree().create_timer(400.0, true, false, true).timeout.connect(func():
		print("ZAMAN AŞIMI")
		get_tree().quit(99))
	Profile.save_enabled = false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			_only = a.substr(7)
	await get_tree().process_frame
	var tests := [
		"test_i18n", "test_questions", "test_profile",
		"test_plush_run", "test_plush_jump", "test_shove_tumble_getup", "test_fall_out",
		"test_stage_builds", "test_trapdoors", "test_arena_match",
	]
	for name in tests:
		if _only != "" and name != _only:
			continue
		if not has_method(name):
			continue
		print("── ", name)
		await call(name)
	print("")
	print("SONUÇ: %d geçti, %d kaldı" % [passes, failures])
	get_tree().quit(failures)

func check(cond: bool, msg: String) -> void:
	if cond:
		passes += 1
		print("   ✓ ", msg)
	else:
		failures += 1
		print("   ✗ ", msg)
		push_error("TEST FAILED: " + msg)

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func seconds(s: float) -> void:
	await frames(int(s * Engine.physics_ticks_per_second))

## Düz bir zemin + tek pelüş: fizik testleri için
func _sandbox() -> Node3D:
	var root := Node3D.new()
	add_child(root)
	var floor_body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	col.shape = box
	col.position = Vector3(0, -0.5, 0)
	floor_body.add_child(col)
	root.add_child(floor_body)
	return root

# ── veri ────────────────────────────────────────────────────────────
func test_i18n() -> void:
	check(I18n.missing_keys().is_empty(), "sözlükte eksik çeviri yok")
	I18n.set_lang("en")
	check(I18n.t("menu.howto") == "How to play", "EN çeviri çalışıyor")
	I18n.set_lang("tr")
	check(I18n.t("arena.alive", {"n": 3}) == "Sahnede 3 kişi", "yer tutucu dolduruluyor")

func test_questions() -> void:
	check(Questions.count() == 1200, "1200 soru yüklendi (%d)" % Questions.count())
	var bad := 0
	for k in Questions.tiers:
		for q in Questions.tiers[k]:
			if q.tr.o.size() != 4 or q.en.o.size() != 4 or int(q.a) < 0 or int(q.a) > 3:
				bad += 1
	check(bad == 0, "her sorunun 4 şıkkı ve geçerli cevabı var")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var item := Questions.draw(0, rng)
	var f := Questions.face(item, "tr")
	check(f.options.size() == 4 and f.correct >= 0 and f.correct < 4, "çekilen soru karıştırılmış ve doğru cevap izleniyor")
	check(f.options[f.correct] == item.src.tr.o[int(item.src.a)], "karıştırılmış doğru şık gerçekten doğru")
	check(Questions.tier_for(0) == "d1" and Questions.tier_for(9) == "d3", "zorluk rampası")

func test_profile() -> void:
	var before := Profile.record("TestKişi")
	Profile.record_match(["TestKişi", "Diğer"], "arena")
	var r := Profile.record("TestKişi")
	check(r.wins == before.wins + 1 and r.streak == before.streak + 1 and r.champs == before.champs + 1, "galibiyet, seri ve şampiyonluk artar")
	Profile.record_match(["Diğer", "TestKişi"], "arena")
	check(Profile.record("TestKişi").streak == 0, "yenilince seri sıfırlanır")
	check(Profile.streak_leader(["TestKişi", "Diğer"]) == "Diğer", "seri lideri bulunur")

# ── fizik ───────────────────────────────────────────────────────────
func test_plush_run() -> void:
	var root := _sandbox()
	var p := Plush.new("Koşucu", {})
	var c := Controllers.Scripted.new()
	p.controller = c
	root.add_child(p)
	p.global_position = Vector3(0, 0.05, 0)
	await seconds(0.3)
	c.set_move(Vector2(1, 0))
	await seconds(1.0)
	var x := p.global_position.x
	check(x > 3.5, "1 saniyede 3,5 m'den fazla koşar (%.2f)" % x)
	check(abs(p.global_position.y) < 0.2, "zeminde kalır (y=%.2f)" % p.global_position.y)
	check(p.state == Plush.State.NORMAL, "ayakta kalır")
	c.set_move(Vector2.ZERO)
	await seconds(0.6)
	var hs := Vector2(p.linear_velocity.x, p.linear_velocity.z).length()
	check(hs < 0.5, "bırakınca durur (%.2f m/s)" % hs)
	root.queue_free()

func test_plush_jump() -> void:
	var root := _sandbox()
	var p := Plush.new("Zıplayan", {})
	var c := Controllers.Scripted.new()
	p.controller = c
	root.add_child(p)
	p.global_position = Vector3(0, 0.05, 0)
	await seconds(0.4)
	c.press_jump()
	var top := 0.0
	for i in 60:
		await get_tree().physics_frame
		top = max(top, p.global_position.y)
	check(top > 1.1, "zıplama 1,1 m'yi aşar, jüri masasına çıkar (%.2f)" % top)
	await seconds(0.8)
	check(p.grounded, "yere geri iner")
	root.queue_free()

func test_shove_tumble_getup() -> void:
	var root := _sandbox()
	var a := Plush.new("İten", {})
	var b := Plush.new("Yiyen", {})
	var ca := Controllers.Scripted.new()
	a.controller = ca
	b.controller = Controllers.Scripted.new()
	root.add_child(a)
	root.add_child(b)
	a.global_position = Vector3(0, 0.05, 0)
	b.global_position = Vector3(0, 0.05, 0.9)
	await seconds(0.4)
	a.facing = 0.0   # +Z'ye bakıyor, b önünde
	b.balance = 0.2  # dengesi zaten bozuk: kesin devrilmeli
	ca.press_shove()
	await frames(3)
	check(b.state == Plush.State.TUMBLE, "omuz yiyen yere kapaklanır")
	await seconds(0.5)
	check(b.global_position.z > 1.4, "omuz yiyen geriye savrulur (z=%.2f)" % b.global_position.z)
	var tilted := b.global_transform.basis.y.dot(Vector3.UP) < 0.95
	check(tilted, "gövde gerçekten devrilir (ragdoll hissi)")
	await seconds(3.6)
	check(b.state == Plush.State.NORMAL, "bir süre sonra kalkar")
	check(b.global_transform.basis.y.dot(Vector3.UP) > 0.99, "kalkınca dik durur")
	root.queue_free()

func test_fall_out() -> void:
	var root := _sandbox()
	var p := Plush.new("Düşen", {})
	root.add_child(p)
	var fired := [false]
	p.fell_out.connect(func(_x): fired[0] = true)
	p.global_position = Vector3(30, 2, 0)   # zeminin dışında
	await seconds(1.5)
	check(fired[0] and p.state == Plush.State.OUT, "sahneden düşen elenir")
	root.queue_free()

var _main: Node = null

func _get_main() -> Node:
	if _main == null:
		_main = load("res://scenes/main.tscn").instantiate()
		add_child(_main)
		await frames(10)
	return _main

func test_stage_builds() -> void:
	var m: Node = await _get_main()
	var st: Stage = m.stage
	check(st != null and st.trapdoors.size() == 4, "sahne ve dört kapak kuruldu")
	var ok := true
	for i in 4:
		if st.zone_at(st.zone_center(i)) != i:
			ok = false
	check(ok, "her kapağın merkezi kendi bölgesine düşer")
	check(st.zone_at(Vector3(0, 0, 4.0)) == -1, "ön şerit hiçbir kapak değildir")
	check(m.all_actors().size() == 1 + int(Profile.setting("bots", 3)), "oyuncu + botlar sahnede (%d)" % m.all_actors().size())
	check(m.ui != null and m.ui.left.visible, "sol pano kuruldu")
	var props_count := get_tree().get_nodes_in_group("prop").size()
	check(props_count >= 10, "fizikli dekorlar sahnede (%d)" % props_count)

func test_trapdoors() -> void:
	var m: Node = await _get_main()
	var st: Stage = m.stage
	var p: Plush = m.all_actors()[0]
	var fell := [0]
	var cb := func(_x): fell[0] += 1
	p.fell_out.connect(cb)
	p.teleport(st.zone_center(1) + Vector3(0, 0.1, 0))
	await seconds(0.3)
	st.open_trapdoor(1, true)
	await seconds(2.0)
	check(fell[0] == 1, "açılan kapaktaki oyuncu kuyuya düşer")
	st.open_trapdoor(1, false)
	await seconds(1.0)
	check(not st.trapdoor_open(1), "kapak geri kapanır")
	p.fell_out.disconnect(cb)
	await seconds(1.0)

func test_arena_match() -> void:
	var m: Node = await _get_main()
	Engine.time_scale = 4.0
	var names_before := []
	for a in m.all_actors():
		names_before.append(a.player_name)
	var champ_before := {}
	for n in names_before:
		champ_before[n] = Profile.record(n).champs
	m.start_arena()
	var waited := 0.0
	while (m.arena == null or m.arena.phase != "done") and waited < 120.0:
		await get_tree().process_frame
		waited += get_process_delta_time() / Engine.time_scale
	var a: TriviaArena = m.arena
	check(a != null and a.phase == "done", "maç sona erdi (%.0f sn gerçek zaman)" % waited)
	if a == null:
		Engine.time_scale = 1.0
		return
	var rk: Array[Plush] = a.ranking()
	check(rk.size() == names_before.size(), "sıralamada herkes var")
	check(a.alive.size() <= 1, "en fazla bir kişi ayakta kaldı")
	check(a.q_index >= 1, "en az bir soru soruldu (%d)" % a.q_index)
	var winner: String = rk[0].player_name
	check(Profile.record(winner).champs == champ_before[winner] + 1, "kazananın şampiyonluğu karneye yazıldı (%s)" % winner)
	var log_ok: bool = a.log_lines.any(func(l): return l.begins_with("WIN "))
	check(log_ok, "kazanan ilan edildi")
	# lobiye dönüş
	await get_tree().create_timer(1.0).timeout
	m.end_arena()
	await seconds(4.0)
	check(m.mode == 0 and m.arena == null, "lobiye dönüldü")
	var visible_all: bool = m.all_actors().all(func(p): return p.visible and p.state != Plush.State.OUT)
	check(visible_all, "herkes sahneye geri geldi")
	Engine.time_scale = 1.0
