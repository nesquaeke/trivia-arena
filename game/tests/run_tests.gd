extends Node
## Başsız test çalıştırıcı:
##   godot --headless --path game res://tests/tests.tscn
## Her test bir coroutine; başarısızlıklar sayılır, çıkış kodu = hata sayısı.

var failures := 0
var passes := 0
var _only := ""

func _ready() -> void:
	# güvenlik: bir test takılırsa 170 sn sonra hata ile çık
	get_tree().create_timer(900.0, true, false, true).timeout.connect(func():
		print("ZAMAN AŞIMI")
		get_tree().quit(99))
	Profile.save_enabled = false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			_only = a.substr(7)
	await get_tree().process_frame
	var tests := [
		"test_i18n", "test_questions", "test_profile", "test_save_file", "test_error_reporter", "test_progress", "test_shop", "test_daily_word", "test_round_track",
		"test_plush_run", "test_plush_jump", "test_shove_tumble_getup", "test_fall_out",
		"test_stage_builds", "test_trapdoors", "test_rules", "test_arena_match", "test_conquest_map", "test_conquest_match", "test_mayhem_data", "test_mayhem_match", "test_estimate_ruler", "test_phone_events", "test_steam_local", "test_voice_and_audio",
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
	var expect := {"pl": "150 000", "fr": "150 000", "es": "150.000"}
	for l in ["pl", "fr", "es"]:
		check(I18n.missing_extra(l).is_empty(), "%s: eksik arayüz metni yok (%d eksik)" % [l, I18n.missing_extra(l).size()])
		I18n.set_lang(l)
		check(I18n.t("menu.howto") != "How to play" and I18n.fmt_int(150000) == expect[l], "%s: çeviri ve sayı biçimi (%s)" % [l, I18n.fmt_int(150000)])
	I18n.set_lang("tr")

func test_questions() -> void:
	check(Questions.count() >= 2100, "2100+ soru yüklendi (%d)" % Questions.count())
	var bad := 0
	for k in Questions.tiers:
		for q in Questions.tiers[k]:
			if q.tr.o.size() != 4 or q.en.o.size() != 4 or int(q.a) < 0 or int(q.a) > 3:
				bad += 1
	check(bad == 0, "her sorunun 4 şıkkı ve geçerli cevabı var")
	var untranslated := 0
	for k in Questions.tiers:
		for q in Questions.tiers[k]:
			for l in ["pl", "fr", "es"]:
				if not q.has(l) or q[l].o.size() != 4 or String(q[l].q).is_empty():
					untranslated += 1
	check(untranslated == 0, "her soru PL/FR/ES dillerinde de var (%d eksik)" % untranslated)
	var est_bad := Questions.estimate.filter(func(e): return ["pl", "fr", "es"].any(func(l): return not e.has(l) or String(e[l].q).is_empty()))
	check(est_bad.is_empty(), "tahmin soruları PL/FR/ES dillerinde de var (%d eksik)" % est_bad.size())
	var cats_ok := Questions.categories.keys().all(func(c): return Questions.category_name(c, "pl") != Questions.category_name(c, "en") or c == "")
	check(cats_ok, "kategori adları yeni dillerde çevrilmiş")
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

## Kayıt dosyası: göç, atomik yazım, bozuk dosyada yedekten kurtarma.
## Oyuncunun gerçek profili test başında saklanır, sonunda geri yazılır.
func test_save_file() -> void:
	var paths := [Profile.PATH, Profile.BACKUP]
	var keep := {}
	for p in paths:
		keep[p] = FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else null
	var old_data: Dictionary = Profile.data.duplicate(true)
	var v1 := {"version": 1, "name": "Eski", "settings": {"fullscreen": true}, "stats": {"matches": 5}}
	var m: Dictionary = Profile._migrate(v1.duplicate(true))
	check(m.settings.get("window") == "fullscreen", "v1 → v3: fullscreen ayarı window'a dönüşür")
	check(int(m.xp) == 300 and m.version == Profile.SAVE_VERSION, "v1 → v3: geçmiş maçlar kadar XP verilir")
	Profile.save_enabled = true
	Profile.data = Profile._defaults()
	Profile.data.name = "Birinci"
	Profile.save()
	Profile.data.name = "İkinci"
	Profile.save()
	check(FileAccess.file_exists(Profile.BACKUP) and not FileAccess.file_exists(Profile.TMP), "kayıt yedek bırakır, geçici dosya kalmaz")
	var f := FileAccess.open(Profile.PATH, FileAccess.WRITE)
	f.store_string("{bozuk json")
	f.close()
	Profile.load_data()
	check(Profile.recovered == "backup" and Profile.data.name == "Birinci", "bozuk kayıt yedekten kurtarılır")
	check(FileAccess.file_exists("user://profile.corrupt.json"), "bozuk dosya incelemek için saklanır")
	Profile.save_enabled = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://profile.corrupt.json"))
	for p in paths:
		if keep[p] == null:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
		else:
			var w := FileAccess.open(p, FileAccess.WRITE)
			w.store_string(keep[p])
			w.close()
	Profile.data = old_data
	Profile.recovered = ""

func test_error_reporter() -> void:
	var n := ErrorReporter.error_count
	push_error("test: kasıtlı hata")
	await frames(2)
	check(ErrorReporter.error_count >= n + 1, "push_error yakalanır")
	check(ErrorReporter.entries.any(func(e): return String(e).contains("kasıtlı hata")), "hata metni kayda girer")
	var rep := ErrorReporter.report_text()
	check(rep.contains("kasıtlı hata") and rep.length() > 40, "rapor metni üretilir")

func test_progress() -> void:
	var old_data: Dictionary = Profile.data.duplicate(true)
	check(Progress.level_of(0) == 1 and Progress.level_of(Progress.xp_for(2)) == 2, "seviye eşikleri")
	check(Progress.xp_for(Progress.MAX_LEVEL) > Progress.xp_for(Progress.MAX_LEVEL - 1), "XP eğrisi artar")
	Profile.data.xp = 0
	Profile.data.unlocked = []
	Profile.data.achievements = {}
	check(Progress.is_unlocked("hat", "tophat") and not Progress.is_unlocked("hat", "wizard"), "ücretsiz açık, sihirbaz şapkası kilitli")
	check(int(Progress.requirement("hat", "wizard").get("level", 0)) == 16, "kilit şartı seviye 16")
	Progress.begin_match()
	Profile.data.daily_win = ""
	var a := Progress.award(0, {"correct": 6, "captures": 4, "toppled": 1}, "conquest")
	check(a.gain == 50 + 120 + 60 + 60 + 40 + 100, "XP dökümü toplanır (%d)" % a.gain)
	check(a.level_after > a.level_before and not a.new.is_empty(), "seviye atlanır, yeni öğe açılır")
	check(Progress.is_unlocked("hat", "beret"), "seviye 2 ödülü açıldı")
	var b := Progress.award(0, {}, "trivia")
	check(b.gain == 50 + 120, "günlük ikramiye günde bir kez")
	Profile.data = old_data

func test_shop() -> void:
	var old_data: Dictionary = Profile.data.duplicate(true)
	Profile.data.xp = 0
	Profile.data.coins = 0
	Profile.data.owned = []
	check(not Progress.is_unlocked("outfit", "cape") and Progress.requirement("outfit", "cape").has("shop"), "pelerin yalnız mağazada")
	check(not Progress.buy("outfit", "cape"), "jeton yetmezse alınamaz")
	Profile.data.coins = 1000
	var cost := Progress.price("outfit", "cape")
	check(Progress.buy("outfit", "cape") and Progress.is_unlocked("outfit", "cape"), "satın alınan öğe açılır")
	check(Progress.coins() == 1000 - cost, "jeton düşer (%d)" % cost)
	check(Progress.price("hat", "wizard") > 0 and Progress.buy("hat", "wizard"), "rütbe öğesi de jetonla alınabilir")
	Progress.begin_match()
	var a := Progress.award(0, {"correct": 5}, "arena")
	check(int(a.get("coins", 0)) == 15 + 40 + 10, "maç sonunda jeton kazanılır (%d)" % int(a.get("coins", 0)))
	var pv := PlushVisual.new({"color": "sky", "outfit": "tuxedo", "necklace": "locket", "hat": "tiara", "glasses": "goggles"})
	add_child(pv)
	await get_tree().process_frame
	var extras := pv.find_children("*", "MeshInstance3D", true, false).filter(func(n): return n.is_in_group("extra"))
	check(extras.size() > 20, "yeni giysiler giyilir (%d parça)" % extras.size())
	pv.apply_look({"color": "sky"})
	await get_tree().process_frame
	var left := pv.find_children("*", "MeshInstance3D", true, false).filter(func(n): return n.is_in_group("extra"))
	check(left.is_empty(), "giysi değişince eskisi temizlenir")
	pv.queue_free()
	Profile.data = old_data

func test_daily_word() -> void:
	var old_data: Dictionary = Profile.data.duplicate(true)
	check(DailyWord.evaluate("kalem", "kalem") == [2, 2, 2, 2, 2], "tam isabet")
	check(DailyWord.evaluate("aaxxx", "abcda") == [2, 1, 0, 0, 0], "tekrar eden harf doğru sayılır")
	check(DailyWord.evaluate("lllll", "hello") == [0, 0, 2, 2, 0], "fazla harf gri kalır")
	var tr := DailyWord.answer("tr")
	check(tr.length() == 5 and DailyWord.is_valid(tr, "tr"), "bugünün Türkçe kelimesi geçerli (%s)" % tr)
	check(DailyWord.answer("en").length() == 5, "İngilizce kelime var")
	check(DailyWord.answer("tr", "2026-03-01") != DailyWord.answer("tr", "2026-03-02"), "her gün farklı kelime")
	check(DailyWord.lower("IŞIK", "tr") == "ışık" and DailyWord.upper("iyi", "tr") == "İYİ", "Türkçe büyük/küçük harf")
	for l in ["pl", "fr", "es"]:
		var w := DailyWord.answer(l)
		check(w.length() == 5 and DailyWord.is_valid(w, l), "%s: bugünün kelimesi geçerli (%s)" % [l, w])
	check(DailyWord.lower("ÉCOLE", "fr") == "ecole" and DailyWord.lower("NIÑOS", "es") == "niños", "FR/ES aksanları atılır, ñ kalır")
	Profile.data.daily = {}
	Profile.data.coins = 0
	var r0 := DailyWord.submit("tr", "abc")
	check(not r0.ok and r0.why == "len", "kısa tahmin reddedilir")
	var r1 := DailyWord.submit("tr", "qqqqq")
	check(not r1.ok and r1.why == "word", "sözlükte olmayan reddedilir")
	var wrong := "kitap" if tr != "kitap" else "kalem"
	var r2 := DailyWord.submit("tr", wrong)
	check(r2.ok and not r2.done, "geçerli yanlış tahmin kaydedilir")
	var r3 := DailyWord.submit("tr", tr)
	check(r3.ok and r3.won and r3.done and int(r3.reward) == 120 + 10, "2. denemede çözene 120 + seri 10 jeton")
	check(Progress.coins() == 130 and DailyWord.streak() == 1, "jeton ve seri kaydedildi")
	check(not DailyWord.submit("tr", tr).ok, "aynı gün tekrar oynanmaz")
	check(DailyWord.share_text("tr").contains("🟩🟩🟩🟩🟩"), "paylaşım metni")
	Profile.data = old_data

func test_round_track() -> void:
	var t := RoundTrack.new()
	add_child(t)
	for kind in ["flags", "hex", "castles", "dots"]:
		t.set_track(2, 3, kind, 5, 2.5, [Color.RED, Color.BLUE])
		await get_tree().process_frame
	check(t.kind == "dots" and t.done == 2.5 and t.visible, "tur çubuğu tüm türlerde çizilir")
	t.queue_free()

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
	# orkestra çukuruna (sahnenin önü) düşen de "düştü" sayılmalı ki geri gelebilsin
	var m: Node = await _get_main()
	var q: Plush = m.all_actors()[0]
	var fired2 := [false]
	var cb := func(_x): fired2[0] = true
	q.fell_out.connect(cb)
	q.teleport(Vector3(0, 0.6, Stage.FRONT_Z + 2.6))
	await seconds(2.5)
	check(fired2[0], "orkestra çukuruna düşen sahneye geri çağrılır")
	q.fell_out.disconnect(cb)
	await seconds(2.0)
	check(q.global_position.y > -0.5 and q.state != Plush.State.OUT, "lobide kulisten geri geldi")

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
	check(m.ui != null and m.ui.menu.visible and m.ui.card != null, "lobi menüsü ve profil kartı kuruldu")
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

func test_rules() -> void:
	var r: RulesConfig = load("res://data/rules.tres")
	check(r != null, "kurallar dosyası (rules.tres) yüklendi")
	check(r.combo_gain(1) == 250 and r.combo_gain(2) == 250 and r.combo_gain(3) == 500 and r.combo_gain(7) == 750, "kombo merdiveni 250/250/500/750")
	check(r.round_penalty(1, 4) == 210 and r.round_penalty(5, 2) == 600, "tur 3 bedeli web formülüyle aynı")
	check(r.tier_for(1, 0) == "d1" and r.tier_for(1, 3) == "d3" and r.tier_for(2, 1) == "d2", "tur 1-2 zorluk sırası")
	check(r.tier_for(3, 2) == "d2" and r.tier_for(3, 3) == "d3", "tur 3: önce orta, sonra zor")
	var n := r.penalty_rounds(r.final_start_hp, 4)
	check(n >= 7 and n <= 14, "4 kişilik masada 4500 can %d soruda biter" % n)

func test_arena_match() -> void:
	var m: Node = await _get_main()
	Engine.time_scale = 4.0
	var names_before := []
	for a in m.all_actors():
		names_before.append(a.player_name)
	var champ_before := {}
	for n in names_before:
		champ_before[n] = Profile.record(n).champs
	m.start_arena("arena")
	var waited := 0.0
	var saw := {}
	while (m.arena == null or m.arena.phase != "done") and waited < 260.0:
		await get_tree().process_frame
		waited += get_process_delta_time() / Engine.time_scale
		if m.arena:
			saw[m.arena.phase] = true
	var a = m.arena
	check(a is ClassicShow and a.phase == "done", "klasik şov bitti (%.0f sn gerçek zaman)" % waited)
	if not (a is ClassicShow):
		Engine.time_scale = 1.0
		return
	for ph in ["intro", "tug", "question", "reveal", "reward", "standings"]:
		check(saw.has(ph), "evre görüldü: " + ph)
	var cats: Array = a.log_lines.filter(func(l): return l.begins_with("CAT "))
	check(cats.size() == 3, "her tur bir kategori halatıyla açıldı (%d)" % cats.size())
	check(a.round_no == 3 and a.hp_mode, "can turuna geçildi")
	var steals: int = a.log_lines.filter(func(l): return l.begins_with("STEAL ") or l.begins_with("SABOTAGE ")).size()
	check(steals >= 1, "tur 2'de soygun/sabotaj yapıldı (%d)" % steals)
	var deaths: int = a.log_lines.filter(func(l): return l.begins_with("DIE ")).size()
	check(deaths >= 1, "can turunda en az biri öldü (%d)" % deaths)
	var any_points: bool = a.st.values().any(func(s): return s.points > 0)
	check(any_points, "puan kazanıldı")
	var rk: Array[Plush] = a.ranking()
	check(rk.size() == names_before.size(), "sıralamada herkes var")
	check(a.alive().size() <= 1 or a.q_index >= a.rules.final_max_questions - 1, "en fazla bir kişi ayakta ya da soru sınırı doldu")
	var winner: String = rk[0].player_name
	check(Profile.record(winner).champs == champ_before[winner] + 1, "kazananın şampiyonluğu karneye yazıldı (%s)" % winner)
	# lobiye dönüş
	await get_tree().create_timer(1.0).timeout
	m.end_arena()
	await seconds(4.0)
	check(m.mode == 0 and m.arena == null, "lobiye dönüldü")
	var visible_all: bool = m.all_actors().all(func(p): return p.visible and p.state != Plush.State.OUT)
	check(visible_all, "herkes sahneye geri geldi")
	var clean: bool = m.all_actors().all(func(p): return p.debuffs.is_empty() and p.collision_layer == 1)
	check(clean, "sabotajlar ve çarpışma katmanları temizlendi")
	Engine.time_scale = 1.0

# ── Mayhem Turu ─────────────────────────────────────────────────────
func test_mayhem_data() -> void:
	var d := MayhemTour.load_data()
	var order: Array = d.get("order", [])
	check(order.size() >= 30, "sıralama setleri yüklendi (%d)" % order.size())
	var ok_sets := order.all(func(o): return o.tr.items.size() == 4 and o.en.items.size() == 4 and o.tr.labels.size() == 4)
	check(ok_sets, "her sıralama setinde 4 öğe ve etiket var")
	var ok_langs := order.all(func(o): return ["pl", "fr", "es"].all(func(l): return o.has(l) and o[l].items.size() == 4 and o[l].labels.size() == 4 and not String(o[l].q).is_empty()))
	check(ok_langs, "sıralama setleri PL/FR/ES dillerinde de var")
	var sounds: Array = d.get("sounds", [])
	var missing := sounds.filter(func(x): return not ResourceLoader.exists("res://assets/audio/mayhem/%s.ogg" % x.id))
	check(sounds.size() >= 30 and missing.is_empty(), "ses dosyaları mevcut (%d, eksik %d)" % [sounds.size(), missing.size()])
	var built := 0
	for id in PropIcons.ids():
		var n := PropIcons.build(id)
		if n.get_child_count() > 0:
			built += 1
		n.free()
	check(built == PropIcons.ids().size(), "bütün oyuncak nesneler kuruldu (%d)" % built)
	var line := NumberLine.new()
	add_child(line)
	line.setup(1.0, 10000.0, false)
	check(line.log_scale and abs(line.x_of(line.value_at(1.0)) - 1.0) < 0.2, "sayı doğrusu logaritmik ve tutarlı")
	line.setup(1900.0, 2000.0, true)
	check(not line.log_scale and int(line.value_at(NumberLine.X1)) == 2000, "yıl doğrusu uçta 2000")
	line.queue_free()
	var r := RandomNumberGenerator.new()
	r.seed = 5
	var plan := MayhemTour.build_plan("tour", r)
	check(plan[0] == "doors" and plan[plan.size() - 1] == "final" and plan.size() == 7, "tam tur planı: Four Doors ile başlar, finalle biter")
	check(MayhemTour.build_plan("quick", r).size() == 4, "hızlı tur 3 oyun + final")

func test_mayhem_match() -> void:
	var m: Node = await _get_main()
	Engine.time_scale = 4.0
	m.debug_ff = 2.5
	var names_before := []
	for a in m.all_actors():
		names_before.append(a.player_name)
	m.start_arena("mayhem")
	var waited := 0.0
	var saw := {}
	var injected := false
	while (m.arena == null or m.arena.phase != "done") and waited < 420.0:
		await get_tree().process_frame
		waited += get_process_delta_time() / Engine.time_scale
		if m.arena and m.arena is MayhemTour:
			if not injected:
				injected = true
				# her mini oyun bir kez + final; ilk turdan sonra kaos
				m.arena.plan = ["doors", "zoom", "nearest", "order", "sound", "falling", "memory", "final"]
				m.arena.chaos_next = "moving"
			saw[m.arena.phase] = true
	var a = m.arena
	check(a is MayhemTour and a.phase == "done", "Mayhem Turu bitti (%.0f sn gerçek zaman)" % waited)
	if not (a is MayhemTour):
		Engine.time_scale = 1.0
		m.debug_ff = 1.0
		return
	var games: Array = a.log_lines.filter(func(l): return l.begins_with("GAME ")).map(func(l): return l.substr(5))
	check(games.size() == 8, "sekiz tur oynandı: %s" % ", ".join(games))
	check(a.log_lines.any(func(l): return l.begins_with("CHAOS ")), "kaos olayı oldu")
	var awards: Array = a.log_lines.filter(func(l): return l.begins_with("AWARD "))
	check(awards.size() == names_before.size(), "herkese bir ödül (%d)" % awards.size())
	var asked_ok: bool = a.st.values().all(func(s): return s.asked >= 15)
	check(asked_ok, "herkes bütün soruları oynadı (eleme yok)")
	var scored: bool = a.st.values().any(func(s): return s.points > 0)
	check(scored, "puan kazanıldı")
	check(a.st.values().any(func(s): return s.est_n >= 2), "tahmin turu sayıldı")
	check(a.st.values().any(func(s): return s.caught + s.stunned > 0), "yağan cevaplarda bloklar yakalandı")
	for p in a.ranking():
		var s: Dictionary = a.st[p]
		print("     %s: %d puan, %d/%d doğru, yakalama %d, sersem %d, tahmin sırası %.1f, zıplama %d" % [p.player_name, s.points, s.correct, s.asked, s.caught, s.stunned, s.est_sum / max(1, s.est_n), s.jumps])
	await get_tree().create_timer(1.0).timeout
	m.end_arena()
	await seconds(4.0)
	check(m.mode == 0 and m.arena == null, "lobiye dönüldü")
	var clean: bool = m.all_actors().all(func(p): return p.debuffs.is_empty() and p.visible)
	check(clean, "kaos etkileri temizlendi")
	Engine.time_scale = 1.0
	m.debug_ff = 1.0

func test_estimate_ruler() -> void:
	# logaritmik cetvel: gidiş-dönüş aynı değeri verir, uçlar 0 ve 1
	check(EstimatePanel.is_log(500, 15000, false), "geniş aralık logaritmik")
	check(not EstimatePanel.is_log(1000, 2000, true), "yıl sorusu doğrusal")
	var u := EstimatePanel.to_u(8849, 500, 15000, true)
	var back := EstimatePanel.from_u(u, 500, 15000, true)
	check(absf(back - 8849) < 1.0, "cetvel gidiş-dönüş (%f)" % back)
	check(EstimatePanel.to_u(500, 500, 15000, true) == 0.0 and EstimatePanel.to_u(15000, 500, 15000, true) == 1.0, "cetvel uçları")
	check(EstimatePanel.nice(8849.0, false) == 8850, "3 anlamlı basamağa yuvarlama")
	check(EstimatePanel.nice(1453.4, true) == 1453, "yıl yuvarlanmaz")
	check(EstimatePanel.fine_step(8849, false) == 10 and EstimatePanel.fine_step(42, false) == 1, "ince ayar adımı")

func test_steam_local() -> void:
	# Steam yokken başarım profilde tutulur ve bir kez açılır
	var got := []
	var cb := func(id, _t): got.append(id)
	SteamService.achievement_unlocked.connect(cb)
	var had: Dictionary = Profile.data.get("achievements", {}).duplicate()
	Profile.data["achievements"] = {}
	SteamService.unlock("SPOT_ON")
	SteamService.unlock("SPOT_ON")
	SteamService.unlock("NOPE")
	check(got == ["SPOT_ON"], "başarım bir kez açılır, bilinmeyen yok sayılır")
	check(SteamService.is_unlocked("SPOT_ON") and SteamService.unlocked_count() == 1, "başarım profilde")
	Profile.data["achievements"] = had
	SteamService.achievement_unlocked.disconnect(cb)
	check(not SteamService.invite_remote_play() or SteamService.available, "Steam yokken davet sessizce reddedilir")

func test_voice_and_audio() -> void:
	var missing := []
	for lang in I18n.LANGS:
		for key in ["welcome", "act1_cq", "act3_arena", "castle_fall", "winner", "duel", "five", "spot_on"]:
			if not ResourceLoader.exists("res://assets/audio/voice/%s/%s.ogg" % [lang, key]):
				missing.append(lang + "/" + key)
	check(missing.is_empty(), "sunucu replikleri tüm dillerde var " + str(missing))
	for n in ["ooh", "aww", "cheer", "ui_confirm", "curtain", "heartbeat", "war_drum", "collapse"]:
		check(Sfx.streams.has(n), "efekt yüklü: " + n)
	check(AudioServer.get_bus_index("Voice") != -1 and AudioServer.get_bus_index("Music") != -1, "ses veri yolları (Music, SFX, Voice)")

func test_phone_events() -> void:
	var b := PhoneBridge.new()
	b._handle({"t": "num", "pid": "p1", "v": 1453, "lock": true})
	b._handle({"t": "ans", "pid": "p1", "i": 2})
	var ctrl := Controllers.Phone.new(b, "p1")
	var n: Dictionary = ctrl.take_number()
	check(int(n.get("v", 0)) == 1453 and bool(n.get("lock", false)), "telefon sayı klavyesi olayı")
	check(ctrl.take_number().is_empty(), "olay bir kez alınır")
	check(ctrl.take_answer() == 2 and ctrl.take_answer() == -1, "telefon şık düğmesi")
	check(ctrl.is_phone() and not Controllers.Keyboard.new(0).is_phone(), "telefon kontrolcüsü tanınır")
	b.free()

func test_conquest_map() -> void:
	var mb := MapBoard.new()
	add_child(mb)
	mb.build()
	check(mb.order.size() == 16, "Türkiye haritası 16 bölge (%d)" % mb.order.size())
	var sym := true
	for id in mb.order:
		for n in mb.region(id).adj:
			if not mb.region(n).adj.has(id):
				sym = false
	check(sym, "komşuluklar iki yönlü")
	check(mb.region("trakya").adj.has("batikaradeniz"), "İstanbul Boğazı geçişi var")
	var inside := true
	for id in mb.order:
		if mb.region_at(mb.region(id).seat) != id:
			inside = false
	check(inside, "her bölgenin taş yeri kendi içinde")
	var c := CastleModel.new("gothic", Color.RED)
	add_child(c)
	c.set_towers(1, false)
	check(c.towers == 1, "kale kulesi düşer")
	c.queue_free()
	mb.queue_free()

func test_conquest_match() -> void:
	var m: Node = await _get_main()
	await seconds(1.0)
	Engine.time_scale = 4.0
	m.debug_ff = 3.0
	m.start_arena("conquest")
	var waited := 0.0
	var saw := {}
	while (m.arena == null or m.arena.phase != "done") and waited < 300.0:
		await get_tree().process_frame
		waited += get_process_delta_time() / Engine.time_scale
		if m.arena:
			saw[m.arena.phase] = true
	var c = m.arena
	check(c is ConquestWar and c.phase == "done", "Conquest maçı bitti (%.0f sn gerçek zaman)" % waited)
	if not (c is ConquestWar):
		Engine.time_scale = 1.0
		m.debug_ff = 1.0
		return
	var castles: int = c.log_lines.filter(func(l): return l.begins_with("CASTLE ")).size()
	check(castles == c.contestants.size(), "herkes kalesini kurdu (%d)" % castles)
	check(c.free_regions().is_empty(), "toprak paylaşımında harita doldu")
	var claims: int = c.log_lines.filter(func(l): return l.begins_with("CLAIM ")).size()
	check(claims >= 12 - (c.contestants.size() - 4), "boş bölgeler tahminle paylaşıldı (%d)" % claims)
	var duels: int = c.log_lines.filter(func(l): return l.begins_with("DUEL ")).size()
	check(duels >= 1, "savaşta düello yapıldı (%d)" % duels)
	var ok_castle := true
	for id in c.capital:
		if c.holder[id] != c.capital[id]:
			ok_castle = false
	check(ok_castle, "kaleler sahibinin elinde")
	for ph in ["estimate", "reveal", "duel"]:
		check(saw.has(ph), "evre görüldü: " + ph)
	var rk: Array[Plush] = c.ranking()
	check(rk.size() == c.contestants.size(), "sıralamada herkes var")
	var sorted_ok := true
	for i in rk.size() - 1:
		var a: Dictionary = c.P[rk[i]]
		var b: Dictionary = c.P[rk[i + 1]]
		if not a.dead and not b.dead and a.points < b.points:
			sorted_ok = false
	check(sorted_ok, "sıralama puana göre")
	await get_tree().create_timer(1.0).timeout
	m.end_arena()
	await seconds(4.0)
	check(m.mode == 0 and m.arena == null, "Conquest'ten lobiye dönüldü")
	var clean: bool = m.all_actors().all(func(p): return p.visual.culture == "" and not p.frozen_input)
	check(clean, "kostümler çıkarıldı, kontrol geri verildi")
	check(m.get_node_or_null("MapBoard") == null, "harita kaldırıldı")
	var shown: bool = m.all_actors().all(func(p): return p.visible and not p.freeze)
	check(shown, "maçtan sonra herkes sahnede ve serbest")
	# maç sonrası kostüm odası: pelüş kostüm giyebilir, sonra çıkarır
	m.ui._open_wardrobe()
	await seconds(1.0)
	check(m.mode == m.Mode.WARDROBE, "maçtan sonra Karakterim açılıyor")
	m.wardrobe_conquest(true)
	await seconds(0.5)
	var p1: Plush = m.player_one()
	check(p1.visual.culture != "" and p1.grounded, "Fetih sekmesinde kostüm giyildi, pelüş yerde")
	m.ui._close_wardrobe()
	await seconds(1.0)
	check(m.mode == 0 and p1.visual.culture == "" and not p1.freeze, "Karakterim kapanınca lobi temiz")
	Engine.time_scale = 1.0
	m.debug_ff = 1.0
