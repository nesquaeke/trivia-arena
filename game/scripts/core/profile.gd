extends Node
## Oyuncu profili ve sahne karnesi. user://profile.json içinde saklanır.
## Karne isim başınadır: bu makinede oynayan herkesin (botlar dahil)
## galibiyet/mağlubiyet, şampiyonluk ve seri bilgisi tutulur.

signal changed

const PATH := "user://profile.json"
const DEFAULT_LOOK := {"color": "mustard", "hat": "tophat", "mustache": "handlebar", "bowtie": "classic", "glasses": "none",
	"culture": "janissary", "castle": "fairy", "banner": "plain"}

var data := {}
var save_enabled := true   # testlerde kapatılır

func _ready() -> void:
	load_data()

## Kayıt biçimi sürümü. Alan eklenince/değişince artır ve _migrate'e bir adım yaz.
const SAVE_VERSION := 3
const BACKUP := "user://profile.bak.json"
const TMP := "user://profile.tmp.json"

## Son yüklemede olan: "" (temiz) | "backup" (yedekten kurtarıldı) | "reset" (okunamadı, sıfırlandı)
var recovered := ""

func _defaults() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"name": "Oyuncu",
		"look": DEFAULT_LOOK.duplicate(),
		"lang": "tr",
		"settings": {"bots": 3, "bot_level": "normal", "timer": 10},
		"records": {},
		"achievements": {},
		"stats": {},
		"xp": 0,
		"unlocked": [],
		"seen_unlocks": [],
	}

func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else null

## Yükle: önce asıl dosya, bozuksa yedek; ikisi de yoksa varsayılan.
## Eski sürümler _migrate ile güncellenir, eksik alanlar tamamlanır.
func load_data() -> void:
	data = _defaults()
	recovered = ""
	var parsed = _read(PATH)
	if parsed == null and FileAccess.file_exists(PATH):
		parsed = _read(BACKUP)
		recovered = "backup" if parsed != null else "reset"
		# bozuk dosyayı incelemek için sakla
		DirAccess.rename_absolute(ProjectSettings.globalize_path(PATH), ProjectSettings.globalize_path("user://profile.corrupt.json"))
		push_warning("Profil okunamadı; %s" % ("yedekten kurtarıldı" if recovered == "backup" else "sıfırlandı"))
	if parsed == null:
		return
	parsed = _migrate(parsed)
	for k in parsed:
		data[k] = parsed[k]
	var d := _defaults()
	for k in d:
		if not data.has(k):
			data[k] = d[k]
	for k in d.settings:
		if not data.settings.has(k):
			data.settings[k] = d.settings[k]
	for k in DEFAULT_LOOK:
		if not data.look.has(k):
			data.look[k] = DEFAULT_LOOK[k]
	data.version = SAVE_VERSION

## Sürüm göçleri: her adım bir öncekinin çıktısını alır
func _migrate(p: Dictionary) -> Dictionary:
	var v := int(p.get("version", 1))
	if v < 2:
		# 0.2: ayarlar "fullscreen" bool → "window" metni
		var st: Dictionary = p.get("settings", {})
		if st.has("fullscreen") and not st.has("window"):
			st["window"] = "fullscreen" if bool(st.fullscreen) else "windowed"
		p["settings"] = st
	if v < 3:
		# 0.4: ilerleme alanları; eski oyunculara geçmiş maçları kadar XP
		var matches := 0
		var stats: Dictionary = p.get("stats", {})
		matches = int(stats.get("matches", 0))
		p["xp"] = int(p.get("xp", matches * 60))
		if not p.has("unlocked"):
			p["unlocked"] = []
	p["version"] = SAVE_VERSION
	return p

## Kaydet: önce geçici dosyaya yaz, sonra eskisini yedeğe al, geçiciyi yerine koy.
## Yazım yarıda kesilse (elektrik, çökme) bile ya eski ya yeni sağlam dosya kalır.
func save() -> void:
	changed.emit()
	if not save_enabled:
		return
	var f := FileAccess.open(TMP, FileAccess.WRITE)
	if f == null:
		push_error("Profil yazılamadı: %s" % error_string(FileAccess.get_open_error()))
		return
	f.store_string(JSON.stringify(data, "  "))
	f.flush()
	f.close()
	var g_path := ProjectSettings.globalize_path(PATH)
	if FileAccess.file_exists(PATH):
		DirAccess.copy_absolute(g_path, ProjectSettings.globalize_path(BACKUP))
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(TMP), g_path)
	if err != OK:
		push_error("Profil yerine konamadı: %s" % error_string(err))

func player_name() -> String:
	return String(data.get("name", "Oyuncu"))

func set_player_name(n: String) -> void:
	n = n.strip_edges().substr(0, 14)
	if n.is_empty():
		return
	data.name = n
	save()

func look() -> Dictionary:
	return data.look

func set_look(key: String, value: String) -> void:
	data.look[key] = value
	save()

func setting(key: String, fallback = null):
	return data.settings.get(key, fallback)

func set_setting(key: String, value) -> void:
	data.settings[key] = value
	save()

## Ayarlar → Oynanış → İstatistikleri sıfırla (kostüm ve ayarlar kalır)
func reset_stats() -> void:
	data.records = {}
	save()

func _key(n: String) -> String:
	return n.strip_edges().to_lower()

func record(n: String) -> Dictionary:
	var r: Dictionary = data.records.get(_key(n), {})
	return {
		"name": r.get("name", n), "wins": int(r.get("wins", 0)), "losses": int(r.get("losses", 0)),
		"champs": int(r.get("champs", 0)), "streak": int(r.get("streak", 0)),
		"best": int(r.get("best", 0)), "matches": int(r.get("matches", 0)),
	}

## Maç bitti. ranking: birinciden sonuncuya isimler. winner boş olabilir (kazanan yok).
func record_match(ranking: Array, mode: String = "arena") -> void:
	for i in ranking.size():
		var n := String(ranking[i])
		var r := record(n)
		r.name = n
		r.matches += 1
		if i == 0 and ranking.size() > 1:
			r.wins += 1
			r.streak += 1
			r.best = max(r.best, r.streak)
			if mode == "arena":
				r.champs += 1
		else:
			r.losses += 1
			r.streak = 0
		data.records[_key(n)] = r
	save()

## Verilen isimler arasında en uzun mevcut seriye sahip olan (seri > 0).
func streak_leader(names: Array) -> String:
	var best := ""
	var best_n := 0
	for n in names:
		var s: int = record(String(n)).streak
		if s > best_n:
			best_n = s
			best = String(n)
	return best

func win_ratio_text(n: String) -> String:
	var r := record(n)
	return "%d / %d" % [r.wins, r.losses]
