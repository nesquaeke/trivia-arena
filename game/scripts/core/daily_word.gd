class_name DailyWord
extends RefCounted
## Günlük Kelime (Wordle tarzı): her gün herkes için aynı 5 harfli kelime, 6 hak.
## Türkçe ve İngilizce ayrı listeler (data/words.json, tools/words/build_words.py).
## Çözene jeton: 1. denemede 150 … 6. denemede 50, seri bonusu (gün başına +10, en çok +50).
## Durum Profile.data.daily içinde: {"tr": {date, guesses, done, won, reward}, "streak", "last_win"}

const LEN := 5
const TRIES := 6
const EPOCH := "2026-01-01"
const REWARD := [150, 120, 100, 80, 60, 50]
const LOSE_REWARD := 15

static var _data := {}
static var _valid := {}

static func _load() -> void:
	if not _data.is_empty():
		return
	var f := FileAccess.open("res://data/words.json", FileAccess.READ)
	if f == null:
		push_error("words.json açılamadı")
		return
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return
	_data = d
	for lang in ["tr", "en"]:
		var s := {}
		for w in d.get(lang, {}).get("valid", []):
			s[String(w)] = true
		_valid[lang] = s

static func today() -> String:
	return Time.get_date_string_from_system()

## Bugün kaçıncı gün (EPOCH'tan beri)
static func day_index(date := "") -> int:
	if date == "":
		date = today()
	var a := Time.get_unix_time_from_datetime_string(EPOCH + "T00:00:00")
	var b := Time.get_unix_time_from_datetime_string(date + "T00:00:00")
	return int(floor((b - a) / 86400.0))

static func answer(lang: String, date := "") -> String:
	_load()
	var arr: Array = _data.get(lang, {}).get("answers", [])
	if arr.is_empty():
		return "kalem" if lang == "tr" else "apple"
	return String(arr[posmod(day_index(date), arr.size())])

static func is_valid(word: String, lang: String) -> bool:
	_load()
	return _valid.get(lang, {}).has(word) or word == answer(lang)

## Türkçe küçük harf (I → ı, İ → i)
static func lower(s: String, lang: String) -> String:
	if lang == "tr":
		s = s.replace("I", "ı").replace("İ", "i")
	return s.to_lower()

static func upper(s: String, lang: String) -> String:
	if lang == "tr":
		s = s.replace("i", "İ").replace("ı", "I")
	return s.to_upper()

## Her harf: 2 doğru yerde, 1 kelimede var, 0 yok (tekrar eden harfler doğru sayılır)
static func evaluate(guess: String, ans: String) -> Array:
	var res := [0, 0, 0, 0, 0]
	var left := {}
	for i in LEN:
		if guess[i] == ans[i]:
			res[i] = 2
		else:
			left[ans[i]] = int(left.get(ans[i], 0)) + 1
	for i in LEN:
		if res[i] == 2:
			continue
		var c := guess[i]
		if int(left.get(c, 0)) > 0:
			res[i] = 1
			left[c] = int(left[c]) - 1
	return res

# ── kayıt ───────────────────────────────────────────────────────────
static func _prof() -> Node:
	var ml := Engine.get_main_loop()
	return ml.root.get_node_or_null("Profile") if ml is SceneTree else null

static func state(lang: String) -> Dictionary:
	var p := _prof()
	var fresh := {"date": today(), "guesses": [], "done": false, "won": false, "reward": 0}
	if p == null:
		return fresh
	var daily: Dictionary = p.data.get("daily", {})
	var s: Dictionary = daily.get(lang, {})
	if String(s.get("date", "")) != today():
		s = fresh
		daily[lang] = s
		p.data["daily"] = daily
	return s

static func streak() -> int:
	var p := _prof()
	if p == null:
		return 0
	var daily: Dictionary = p.data.get("daily", {})
	# dün ya da bugün kazanılmadıysa seri bozulmuştur
	var last := String(daily.get("last_win", ""))
	if last == "":
		return 0
	var d := day_index() - day_index(last)
	return int(daily.get("streak", 0)) if d <= 1 else 0

## Tahmin gönder. Dönüş: {"ok": false, "why": "len|word|done"} ya da {"ok": true, "marks", "won", "done", "reward"}
static func submit(lang: String, guess: String) -> Dictionary:
	var s := state(lang)
	if bool(s.done):
		return {"ok": false, "why": "done"}
	guess = lower(guess, lang)
	if guess.length() != LEN:
		return {"ok": false, "why": "len"}
	if not is_valid(guess, lang):
		return {"ok": false, "why": "word"}
	var ans := answer(lang)
	var marks := evaluate(guess, ans)
	var g: Array = s.guesses
	g.append(guess)
	var won := guess == ans
	var out := {"ok": true, "marks": marks, "won": won, "done": false, "reward": 0}
	if won or g.size() >= TRIES:
		s.done = true
		s.won = won
		var p := _prof()
		var reward := LOSE_REWARD
		if won:
			var daily: Dictionary = p.data.get("daily", {}) if p else {}
			var st := streak()
			# aynı gün iki dilde de kazanan seriyi iki kez artırmasın
			if String(daily.get("last_win", "")) != today():
				st += 1
			daily["streak"] = st
			daily["last_win"] = today()
			reward = int(REWARD[g.size() - 1]) + mini(st, 5) * 10
		s.reward = reward
		if p:
			p.data["coins"] = int(p.data.get("coins", 0)) + reward
			if won:
				p.data["xp"] = int(p.data.get("xp", 0)) + 30
		out.done = true
		out.reward = reward
	var pr := _prof()
	if pr:
		pr.save()
	return out

## Paylaşım metni (renkli kareler)
static func share_text(lang: String) -> String:
	var s := state(lang)
	var ans := answer(lang)
	var lines := []
	for g in s.guesses:
		var row := ""
		for m in evaluate(String(g), ans):
			row += ["⬛", "🟨", "🟩"][int(m)]
		lines.append(row)
	var head := "Trivia Arena · %s #%d  %s/6" % ["Günlük Kelime" if lang == "tr" else "Daily Word", day_index() + 1, str(s.guesses.size()) if s.won else "X"]
	return head + "\n" + "\n".join(lines)

## Yeni kelimeye kalan süre (sn)
static func seconds_to_next() -> int:
	var t := Time.get_datetime_dict_from_system()
	return (23 - int(t.hour)) * 3600 + (59 - int(t.minute)) * 60 + (60 - int(t.second))
