extends Node
## Oyuncu profili ve sahne karnesi. user://profile.json içinde saklanır.
## Karne isim başınadır: bu makinede oynayan herkesin (botlar dahil)
## galibiyet/mağlubiyet, şampiyonluk ve seri bilgisi tutulur.

signal changed

const PATH := "user://profile.json"
const DEFAULT_LOOK := {"color": "mustard", "hat": "tophat", "mustache": "handlebar", "bowtie": "classic", "culture": "janissary", "castle": "fairy"}

var data := {}
var save_enabled := true   # testlerde kapatılır

func _ready() -> void:
	load_data()

func _defaults() -> Dictionary:
	return {
		"version": 1,
		"name": "Oyuncu",
		"look": DEFAULT_LOOK.duplicate(),
		"lang": "tr",
		"settings": {"bots": 3, "bot_level": "normal", "timer": 10},
		"records": {},
	}

func load_data() -> void:
	data = _defaults()
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for k in parsed:
		data[k] = parsed[k]
	# eksik alanları tamamla
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

func save() -> void:
	changed.emit()
	if not save_enabled:
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "  "))

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
