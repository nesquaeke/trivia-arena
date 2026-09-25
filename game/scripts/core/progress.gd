class_name Progress
extends RefCounted
## Sahne Rütbesi: her maç XP kazandırır, seviyeler ve başarımlar yeni kostüm,
## aksesuar, renk, kültür, kale ve sancak deseni açar. Veriler Profile'da
## (xp, unlocked). Kilit listesi aşağıda; yeni öğe eklemek için UNLOCKS'a bir satır.
##
## XP (1. oyuncu, maç sonunda):
##   katılım 50 · 1./2./3. olmak 120/70/40 · her doğru cevap 10
##   Conquest: her ele geçirme 15, kale yıkma 40 · Trivia: çalınan her 100 puan 5
##   ilk galibiyet günlük ikramiye: +100 (günün ilk galibiyeti)

const MAX_LEVEL := 30

## Herkese baştan açık olanlar (kategori → öğeler)
const FREE := {
	"color": ["mustard", "butter", "tangerine", "rose", "mint", "sky", "lilac", "charcoal"],
	"hat": ["none", "tophat", "bowler", "fez", "boater", "crown", "cone"],
	"mustache": ["none", "handlebar", "chevron", "pencil", "walrus"],
	"bowtie": ["none", "classic", "dotted", "big"],
	"glasses": ["none"],
	"culture": ["viking", "centurion", "pharaoh", "samurai", "mariachi", "musketeer", "highlander", "janissary", "hussar", "frontier"],
	"castle": ["himeji", "pyramid", "alhambra", "fairy", "gothic", "steppe"],
	"banner": ["plain"],
	"necklace": ["none"],
	"outfit": ["none"],
}

## Yalnız mağazada (Günlük Kelime ve maçlardan kazanılan jetonla)
const SHOP_ONLY := {
	"hat:bunny": 180, "hat:santa": 200, "hat:tiara": 260, "hat:sombrero": 220,
	"glasses:cinema3d": 150, "glasses:nerd": 150, "glasses:goggles": 200,
	"necklace:lei": 160, "necklace:tooth": 140, "necklace:crystal": 300,
	"outfit:tutu": 240, "outfit:cape": 320, "outfit:raincoat": 220,
}
## Rütbe/başarım öğelerini beklemeden almak isteyene fiyat
const ACH_PRICE := 350

## Seviye ödülleri: seviye → ["kategori:öğe", ...]
const LEVEL_UNLOCKS := {
	2: ["hat:beret"], 3: ["color:cherry"], 4: ["glasses:round"], 5: ["banner:stripes"],
	6: ["mustache:imperial"], 7: ["bowtie:scarf"], 8: ["hat:party"], 9: ["culture:knight"],
	10: ["color:navy", "glasses:star"], 11: ["hat:tricorn"], 12: ["banner:chevron"], 13: ["bowtie:medal"],
	14: ["castle:onion"], 15: ["mustache:goatee", "color:forest"], 16: ["hat:wizard"], 17: ["glasses:shades"],
	18: ["culture:pirate"], 19: ["bowtie:pearls"], 20: ["banner:cross", "color:plum"], 21: ["hat:chef"],
	22: ["mustache:horseshoe"], 23: ["hat:jester"], 24: ["castle:lighthouse"], 25: ["banner:checker", "color:snow"],
	26: ["mustache:beard"], 27: ["culture:explorer"], 28: ["hat:laurel"], 29: ["bowtie:bell"], 30: ["color:gold", "banner:sun"],
}
## Yeni giysiler (v0.6): seviyelere eklenir
const LEVEL_UNLOCKS_2 := {
	3: ["necklace:beads"], 5: ["outfit:sweater"], 7: ["hat:beanie"], 9: ["glasses:heart"],
	11: ["necklace:gold_chain"], 13: ["outfit:overalls"], 15: ["hat:headphones"], 17: ["outfit:hoodie"],
	19: ["glasses:aviator"], 21: ["necklace:locket"], 23: ["outfit:vest"], 25: ["hat:graduate"],
	27: ["outfit:tuxedo"], 29: ["necklace:medallion"], 30: ["hat:halo"],
}

## Başarım ödülleri
const ACH_UNLOCKS := {
	"FIRST_WIN": ["color:coral"], "TRIVIA_CHAMP": ["bowtie:rose"], "CONQUEROR": ["color:cocoa"],
	"CASTLE_BREAKER": ["hat:cowboy"], "SPOT_ON": ["glasses:monocle"], "HEIST": ["glasses:domino"],
	"STREAK_3": ["mustache:curly"], "HOUSE_PARTY": ["hat:propeller"], "FULL_HOUSE": ["glasses:eyepatch"],
	"WARDROBE": ["bowtie:ascot"], "MARATHON": ["hat:flowers"], "UNTOUCHED": ["banner:star"],
}

const TITLES := [[1, "rank.extra"], [4, "rank.prompter"], [7, "rank.dresser"], [10, "rank.chorus"],
	[13, "rank.support"], [16, "rank.lead"], [20, "rank.star"], [25, "rank.legend"], [30, "rank.owner"]]

## Son maçın dökümü (sonuç ekranı gösterir)
static var last_award := {}
static var _start_ids: Array = []

## Maç başında: maç içinde başarımla açılanlar da sonuç ekranında görünsün
static func begin_match() -> void:
	_start_ids = unlocked_ids()

static func _prof() -> Node:
	var ml := Engine.get_main_loop()
	return ml.root.get_node_or_null("Profile") if ml is SceneTree else null

## n. seviyeye çıkmak için gereken toplam XP
static func xp_for(level: int) -> int:
	var total := 0
	for k in range(1, level):
		total += 120 + 30 * k
	return total

static func level_of(xp: int) -> int:
	var lv := 1
	while lv < MAX_LEVEL and xp >= xp_for(lv + 1):
		lv += 1
	return lv

static func xp() -> int:
	var p := _prof()
	return int(p.data.get("xp", 0)) if p else 0

static func level() -> int:
	return level_of(xp())

## Bu seviyedeki ilerleme 0–1
static func level_frac(p_xp: int) -> float:
	var lv := level_of(p_xp)
	if lv >= MAX_LEVEL:
		return 1.0
	var a := xp_for(lv)
	var b := xp_for(lv + 1)
	return clampf(float(p_xp - a) / float(b - a), 0.0, 1.0)

static func title_key(lv: int) -> String:
	var key := "rank.extra"
	for t in TITLES:
		if lv >= int(t[0]):
			key = String(t[1])
	return key

# ── kilitler ────────────────────────────────────────────────────────
static var _levels_cache := {}

## Seviye → öğeler (iki tablonun birleşimi)
static func level_table() -> Dictionary:
	if _levels_cache.is_empty():
		for l in LEVEL_UNLOCKS:
			_levels_cache[l] = LEVEL_UNLOCKS[l].duplicate()
		for l in LEVEL_UNLOCKS_2:
			if not _levels_cache.has(l):
				_levels_cache[l] = []
			_levels_cache[l].append_array(LEVEL_UNLOCKS_2[l])
	return _levels_cache

static func is_unlocked(cat: String, item: String) -> bool:
	if FREE.get(cat, []).has(item):
		return true
	var p := _prof()
	if p == null:
		return true
	var id := cat + ":" + item
	if p.data.get("unlocked", []).has(id) or p.data.get("owned", []).has(id):
		return true
	var lv := level()
	var lt := level_table()
	for l in lt:
		if int(l) <= lv and lt[l].has(id):
			return true
	var ach: Dictionary = p.data.get("achievements", {})
	for a in ACH_UNLOCKS:
		if bool(ach.get(a, false)) and ACH_UNLOCKS[a].has(id):
			return true
	return false

## Kilitliyse nasıl açılır: {"level": n} ya da {"ach": id}; açıksa boş
static func requirement(cat: String, item: String) -> Dictionary:
	if is_unlocked(cat, item):
		return {}
	var id := cat + ":" + item
	if SHOP_ONLY.has(id):
		return {"shop": true, "price": int(SHOP_ONLY[id])}
	var lt := level_table()
	for l in lt:
		if lt[l].has(id):
			return {"level": int(l), "price": price(cat, item)}
	for a in ACH_UNLOCKS:
		if ACH_UNLOCKS[a].has(id):
			return {"ach": a, "price": ACH_PRICE}
	return {"level": MAX_LEVEL, "price": price(cat, item)}

## Jeton fiyatı (açıksa 0)
static func price(cat: String, item: String) -> int:
	if FREE.get(cat, []).has(item):
		return 0
	var id := cat + ":" + item
	if SHOP_ONLY.has(id):
		return int(SHOP_ONLY[id])
	var lt := level_table()
	for l in lt:
		if lt[l].has(id):
			return 60 + int(l) * 14
	return ACH_PRICE

static func coins() -> int:
	var p := _prof()
	return int(p.data.get("coins", 0)) if p else 0

static func add_coins(n: int) -> void:
	var p := _prof()
	if p == null:
		return
	p.data["coins"] = max(0, int(p.data.get("coins", 0)) + n)
	p.save()

## Satın al: yeterli jeton varsa öğe kalıcı olarak açılır
static func buy(cat: String, item: String) -> bool:
	var p := _prof()
	if p == null or is_unlocked(cat, item):
		return false
	var cost := price(cat, item)
	if coins() < cost:
		return false
	p.data["coins"] = coins() - cost
	var owned: Array = p.data.get("owned", [])
	owned.append(cat + ":" + item)
	p.data["owned"] = owned
	p.save()
	return true

## Şu an açık olan bütün kilitli öğeler (açılış anını yakalamak için)
static func unlocked_ids() -> Array:
	var out := []
	for id in SHOP_ONLY:
		var sp0: PackedStringArray = String(id).split(":")
		if is_unlocked(sp0[0], sp0[1]):
			out.append(id)
	var lt := level_table()
	for l in lt:
		for id in lt[l]:
			var sp: PackedStringArray = String(id).split(":")
			if is_unlocked(sp[0], sp[1]):
				out.append(id)
	for a in ACH_UNLOCKS:
		for id in ACH_UNLOCKS[a]:
			var sp2: PackedStringArray = String(id).split(":")
			if is_unlocked(sp2[0], sp2[1]) and not out.has(id):
				out.append(id)
	return out

static func total_unlockables() -> int:
	var n := SHOP_ONLY.size()
	var lt := level_table()
	for l in lt:
		n += lt[l].size()
	for a in ACH_UNLOCKS:
		n += ACH_UNLOCKS[a].size()
	return n

# ── ödül ────────────────────────────────────────────────────────────
## Maç sonu XP'si. lines: [[metin anahtarı, xp, sayı], ...]; dönen döküm last_award'a da yazılır.
static func award(rank: int, stats: Dictionary, kind: String) -> Dictionary:
	var p := _prof()
	if p == null:
		return {}
	var before_ids := _start_ids if not _start_ids.is_empty() else unlocked_ids()
	_start_ids = []
	var before := int(p.data.get("xp", 0))
	var lines := []
	lines.append(["xp.play", 50, 0])
	if rank >= 0 and rank < 3:
		lines.append(["xp.rank%d" % (rank + 1), [120, 70, 40][rank], 0])
	var correct := int(stats.get("correct", 0))
	if correct > 0:
		lines.append(["xp.correct", correct * 10, correct])
	if kind == "conquest":
		var cap := int(stats.get("captures", 0))
		if cap > 0:
			lines.append(["xp.capture", cap * 15, cap])
		var top := int(stats.get("toppled", 0))
		if top > 0:
			lines.append(["xp.topple", top * 40, top])
	else:
		var st := int(stats.get("stolen", 0)) / 100
		if st > 0:
			lines.append(["xp.steal", st * 5, st])
	if rank == 0:
		var today := Time.get_date_string_from_system()
		if String(p.data.get("daily_win", "")) != today:
			p.data["daily_win"] = today
			lines.append(["xp.daily", 100, 0])
	var gain := 0
	for l in lines:
		gain += int(l[1])
	p.data["xp"] = before + gain
	# jeton: katılım 15, ilk üç 40/25/10, her doğru 2 (en çok 30)
	var coin_gain: int = 15 + ([40, 25, 10][rank] if rank >= 0 and rank < 3 else 0) + mini(30, correct * 2)
	p.data["coins"] = int(p.data.get("coins", 0)) + coin_gain
	p.save()
	var after_ids := unlocked_ids()
	var fresh := after_ids.filter(func(id): return not before_ids.has(id))
	last_award = {"before": before, "after": before + gain, "gain": gain, "lines": lines, "coins": coin_gain,
		"level_before": level_of(before), "level_after": level_of(before + gain), "new": fresh}
	return last_award

## Başarımla açılanlar maç sonunda da haber verilsin
static func note_achievement_unlocks(ach_id: String) -> Array:
	return ACH_UNLOCKS.get(ach_id, [])
