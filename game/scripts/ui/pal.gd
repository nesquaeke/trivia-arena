@tool
class_name Pal
extends RefCounted
## Arayüzün renkleri ve yazı tipleri tek yerde.
##
## Renkleri buradan değiştir; bütün arayüz takip eder.
## Yazı tipleri res://ui/fonts/*.tres dosyalarıdır (FontVariation): Godot'da
## dosyaya tıklayıp Inspector'dan kalınlığı (wght), optik boyutu (opsz) ve
## harf aralığını değiştirebilirsin.

# ── renkler ─────────────────────────────────────────────────────────
const INK := Color("0D0607")          # en koyu zemin
const NIGHT := Color("170B0D")        # panel zemini
const VELVET := Color("5E0F1C")
const VELVET_HI := Color("A3203A")
const BRASS := Color("C9A15A")
const BRASS_LO := Color("6E4A1C")
const GOLD := Color("F6CF7B")
const CHAMPAGNE := Color("FFF1D2")
const CREAM := Color("EAD9B8")
const MUTED := Color("A8927A")
const GOOD := Color("8EE08A")
const BAD := Color("FF6B57")
const HEART := Color("FF4D5E")

## Sahnedeki A-B-C-D kapaklarının renkleri (panoda ve yerde aynı)
const ZONE := [Color("F2B83C"), Color("3FC4B2"), Color("EE5C86"), Color("9A7CF2")]
const LETTERS := ["A", "B", "C", "D"]
## Arayüz 1920×1080 tasarım alanında ortalanır; ekran başka oranda ise
## tam ekran karartmalar bu taşkın dikdörtgenle kenarlara kadar uzanır
const BLEED := Rect2(-1600, -900, 5120, 2880)

## Soldan sönen karartmayı (scrim) ekranın sol kenarına ve üst/alt taşkına uzatır
static func bleed_scrim(scrim: Control, strength: float) -> void:
	scrim.position.y = BLEED.position.y
	scrim.size.y = BLEED.size.y
	var fill := ColorRect.new()
	fill.color = Color(0.05, 0.02, 0.03, strength)
	fill.position = Vector2(BLEED.position.x - scrim.position.x, 0)
	fill.size = Vector2(-BLEED.position.x, BLEED.size.y)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.add_child(fill)

# ── yazı tipleri ───────────────────────────────────────────────────
const FONT_DIR := "res://ui/fonts/"
static var _cache := {}

static func font(name: String) -> Font:
	if not _cache.has(name):
		_cache[name] = load(FONT_DIR + name + ".tres")
	return _cache[name]

## Big Shoulders Display 900: başlıklar, sayılar
static func display() -> Font: return font("display_black")
## Big Shoulders 750: isimler, düğmeler
static func display_bold() -> Font: return font("display_bold")
## Big Shoulders 700, harf aralıklı: küçük üst başlıklar
static func kicker() -> Font: return font("kicker")
## Fraunces: gövde metni, sorular
static func serif() -> Font: return font("serif_body")
static func serif_semi() -> Font: return font("serif_semibold")
static func serif_display() -> Font: return font("serif_display")
static func italic() -> Font: return font("serif_italic")
static func italic_black() -> Font: return font("serif_italic_black")

# ── metin yardımcıları ─────────────────────────────────────────────
## Dil kurallarına uygun büyük harf (Türkçede i → İ, ı → I).
static func upper(s: String) -> String:
	if tr_lang():
		s = s.replace("i", "İ").replace("ı", "I")
	s = s.to_upper()
	# özel adlar ve tuş adları İngilizce kalır
	for w in KEEP:
		s = s.replace(w.replace("I", "İ"), w)
	return s

const KEEP := ["TRIVIA", "QUIZ", "SHIFT", "ARENA", "WASD", "PAD", "ENTER"]

static func lang() -> String:
	if Engine.is_editor_hint():
		return "tr"
	var i18n := _i18n()
	return "tr" if i18n == null else String(i18n.get("lang"))

static func tr_lang() -> bool:
	if Engine.is_editor_hint():
		return true
	var i18n := _i18n()
	return i18n == null or String(i18n.get("lang")) == "tr"

## Sözlükten metin; editörde (autoload yokken) anahtarı döndürür.
static func t(key: String, args := {}) -> String:
	var i18n := _i18n()
	if i18n == null:
		return key
	return i18n.t(key, args)

static func _i18n() -> Node:
	var ml := Engine.get_main_loop()
	if ml is SceneTree and ml.root.has_node("I18n"):
		return ml.root.get_node("I18n")
	return null

static func sfx(name: String, db := 0.0, pitch := 1.0) -> void:
	if Engine.is_editor_hint():
		return
	var ml := Engine.get_main_loop()
	if ml is SceneTree and ml.root.has_node("Sfx"):
		ml.root.get_node("Sfx").play(name, db, pitch)

## Roma rakamı (tur kartları için)
static func roman(n: int) -> String:
	return ["", "I", "II", "III", "IV", "V", "VI"][clampi(n, 0, 6)]

static func with_alpha(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)
