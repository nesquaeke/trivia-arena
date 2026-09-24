extends Node
## Soru bankası: web sürümünden aktarılan 1200 çoktan seçmeli + tahmin sorusu.
## Veri: res://data/questions.json  (tiers.d1/d2/d3, estimate, categories)

var tiers := {}          # "d1" -> Array[Dictionary]
var estimate := []
var categories := {}     # "geo" -> [tr, en, renk]
var _used := {}          # soru metni -> true (bu oturumda soruldu)

func _ready() -> void:
	load_bank()

func load_bank() -> void:
	var f := FileAccess.open("res://data/questions.json", FileAccess.READ)
	if f == null:
		push_error("questions.json açılamadı")
		return
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		push_error("questions.json bozuk")
		return
	tiers = d.get("tiers", {})
	estimate = d.get("estimate", [])
	categories = d.get("categories", {})

func count() -> int:
	var n := 0
	for k in tiers:
		n += tiers[k].size()
	return n

## Zorluk rampası: ilk sorular kolay, sonra orta, sonra zor.
func tier_for(index: int) -> String:
	if index < 3:
		return "d1"
	if index < 7:
		return "d2"
	return "d3"

## Yeni bir soru çek. Dönüş: {prompt, options[4], correct, cat, cat_name, tier}
## Şıkların sırası karıştırılır; doğru cevabın yeni yeri "correct".
func draw(index: int, rng: RandomNumberGenerator = null) -> Dictionary:
	var r := rng if rng else RandomNumberGenerator.new()
	if rng == null:
		r.randomize()
	var tier := tier_for(index)
	var pool: Array = tiers.get(tier, [])
	var fresh := pool.filter(func(q): return not _used.has(q.tr.q))
	if fresh.is_empty():
		_used.clear()
		fresh = pool
	var q: Dictionary = fresh[r.randi() % fresh.size()]
	_used[q.tr.q] = true
	var order := [0, 1, 2, 3]
	for i in range(3, 0, -1):
		var j := r.randi() % (i + 1)
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
	return {"src": q, "order": order, "correct": order.find(int(q.a)), "cat": q.c, "tier": tier}

## Soruyu aktif dilde metne çevirir (dil değişirse aynı soru yeniden okunur).
func face(item: Dictionary, lang: String) -> Dictionary:
	var q: Dictionary = item.src
	var L: Dictionary = q.get(lang, q.tr)
	var opts := []
	for i in item.order:
		opts.append(L.o[i])
	var cat_row: Array = categories.get(item.cat, [item.cat, item.cat, "#B8893B"])
	return {
		"prompt": L.q, "options": opts, "correct": item.correct,
		"cat_name": cat_row[1 if lang == "en" else 0], "cat_color": Color(cat_row[2]),
	}

func reset_used() -> void:
	_used.clear()
