extends Node
## Sunucu (anlatıcı): oyunun önemli anlarını seslendirir.
##   Narrator.say("castle_fall")
## Dosyalar res://assets/audio/voice/<tr|en>/<anahtar>.ogg (tools/voice/narrate.py).
## Gerçek seslendirme için aynı adlarla dosyaları değiştirmek yeter.
## Konuşurken müzik kısılır; peş peşe gelen replikler üst üste binmez
## (önemli olan bekler, önemsiz olan atlanır). "Voice" veri yolunda çalar;
## Ayarlar'dan açılıp kapanır, sesi ayrı ayarlanır.

const DIR := "res://assets/audio/voice/"
## Önemli replikler kuyruğa girer; diğerleri konuşma sürerken atlanır
const IMPORTANT := ["act1_arena", "act2_arena", "act3_arena", "act1_cq", "act2_cq", "act3_cq",
	"castle_fall", "winner", "tie", "duel"]

var _player: AudioStreamPlayer
var _cache := {}
var _queue: Array[String] = []
var _last := {}                  # anahtar -> son çalma zamanı (ms)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index("Voice") == -1:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, "Voice")
		AudioServer.set_bus_send(i, "Master")
	_player = AudioStreamPlayer.new()
	_player.bus = "Voice"
	add_child(_player)
	_player.finished.connect(_next)

func enabled() -> bool:
	var prof := get_node_or_null("/root/Profile")
	return prof == null or bool(prof.setting("narrator", true))

func _stream(key: String) -> AudioStream:
	var lang := "tr"
	var i18n := get_node_or_null("/root/I18n")
	if i18n and String(i18n.lang) == "en":
		lang = "en"
	var path := DIR + lang + "/" + key + ".ogg"
	if _cache.has(path):
		return _cache[path]
	var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
	_cache[path] = s
	return s

func say(key: String) -> void:
	if not enabled():
		return
	var now := Time.get_ticks_msec()
	# aynı replik 4 sn içinde tekrar etmesin
	if now - int(_last.get(key, -99999)) < 4000:
		return
	_last[key] = now
	if _player.playing:
		if IMPORTANT.has(key) and _queue.size() < 2:
			_queue.append(key)
		return
	_play(key)

func _play(key: String) -> void:
	var s := _stream(key)
	if s == null:
		return
	_player.stream = s
	_player.play()
	var m := get_node_or_null("/root/Music")
	if m and m.has_method("duck_voice"):
		m.duck_voice(true)

func _next() -> void:
	if not _queue.is_empty():
		_play(_queue.pop_front())
		return
	var m := get_node_or_null("/root/Music")
	if m and m.has_method("duck_voice"):
		m.duck_voice(false)

func stop() -> void:
	_queue.clear()
	_player.stop()
	_next()
