extends Node
## Soru bankası: web sürümünden aktarılan 1200 çoktan seçmeli + tahmin sorusu.
## Veri: res://data/questions.json  (tiers.d1/d2/d3, estimate, categories)

var tiers := {}          # "d1" -> Array[Dictionary]
var estimate := []
var categories := {}     # "geo" -> [tr, en, renk, pl, fr, es]
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
	var L: Dictionary = q.get(lang, q.get("en", q.tr))
	var opts := []
	for i in item.order:
		opts.append(L.o[i])
	var cat_row: Array = categories.get(item.cat, [item.cat, item.cat, "#B8893B"])
	return {
		"prompt": L.q, "options": opts, "correct": item.correct,
		"cat_name": category_name(item.cat, lang), "cat_color": Color(cat_row[2]),
	}

## Belirli bir zorluk ve (varsa) kategoriden soru çek. Kategoride uygun soru
## kalmazsa aynı zorluğun genel havuzuna düşer (web sürümüyle aynı davranış).
func draw_from(tier: String, category: String, rng: RandomNumberGenerator) -> Dictionary:
	var pool: Array = tiers.get(tier, tiers.get("d1", []))
	var cands := pool.filter(func(q): return (category == "" or q.c == category) and not _used.has(q.tr.q))
	if cands.is_empty():
		cands = pool.filter(func(q): return not _used.has(q.tr.q))
	if cands.is_empty():
		_used.clear()
		cands = pool
	var q: Dictionary = cands[rng.randi() % cands.size()]
	_used[q.tr.q] = true
	var order := [0, 1, 2, 3]
	for i in range(3, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
	return {"src": q, "order": order, "correct": order.find(int(q.a)), "cat": q.c, "tier": tier}

## Kategori halatı için: her zorlukta en az `depth` sorusu olan kategorilerden n tane.
func pick_categories(n: int, rng: RandomNumberGenerator, exclude: Array = [], depth := 6) -> Array:
	var ok := []
	for c in categories:
		if exclude.has(c):
			continue
		var enough := true
		for t in ["d1", "d2", "d3"]:
			var cnt: int = tiers.get(t, []).filter(func(q): return q.c == c).size()
			if cnt < depth:
				enough = false
		if enough:
			ok.append(c)
	for i in range(ok.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = ok[i]
		ok[i] = ok[j]
		ok[j] = tmp
	return ok.slice(0, n)

## Kategori satırı: [tr, en, renk, pl, fr, es]
const CAT_IDX := {"tr": 0, "en": 1, "pl": 3, "fr": 4, "es": 5}

func category_name(c: String, lang: String) -> String:
	var row: Array = categories.get(c, [c, c, "#B8893B"])
	var i: int = CAT_IDX.get(lang, 1)
	return String(row[i] if i < row.size() else row[1])

func category_color(c: String) -> Color:
	var row: Array = categories.get(c, [c, c, "#B8893B"])
	return Color(row[2])

func reset_used() -> void:
	_used.clear()
