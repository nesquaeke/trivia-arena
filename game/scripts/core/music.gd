extends Node
## Müzik: iki oynatıcı arasında yumuşak geçiş (crossfade).
##   Music.play("conquest")      parçaya geç (döngü)
##   Music.play("think", 0.6)    soru sırasında gerilim yatağı
##   Music.sting("victory")      döngüsüz fanfar; müzik o sırada kısılır
##   Music.stop()
## Parçalar res://assets/audio/music/*.ogg — hepsi tools/music/compose.py ile
## notalardan üretilir. Ses düzeyleri Ayarlar'dan gelir (Music ve SFX veri yolları).

const DIR := "res://assets/audio/music/"
const LOOPS := ["lobby", "conquest", "trivia", "think"]
const LEVEL := {"lobby": -4.0, "conquest": -3.0, "trivia": -4.0, "think": -2.0, "victory": 0.0}

var current := ""
var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _sting: AudioStreamPlayer
var _cache := {}
var _duck := 0.0
var _duck_target := 0.0
var _voice_duck := false
var _tweens: Array = [null, null]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("Music")
	_ensure_bus("SFX")
	_ensure_bus("Voice")
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.volume_db = -80.0
		add_child(p)
		_players.append(p)
	_sting = AudioStreamPlayer.new()
	_sting.bus = "Music"
	add_child(_sting)
	_sting.finished.connect(func(): _duck_target = 0.0)
	apply_volumes()

static func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, bus_name)
	AudioServer.set_bus_send(i, "Master")

## Ayarlardaki ses düzeylerini (0–1) veri yollarına uygula
func apply_volumes() -> void:
	var prof := get_node_or_null("/root/Profile")
	var mv := 0.7
	var sv := 0.9
	var vv := 0.9
	var master := 1.0
	if prof:
		mv = float(prof.setting("music_vol", 0.7))
		sv = float(prof.setting("sfx_vol", 0.9))
		vv = float(prof.setting("voice_vol", 0.9))
		master = float(prof.setting("master_vol", 1.0))
	_set_bus("Master", master)
	_set_bus("Music", mv)
	_set_bus("SFX", sv)
	_set_bus("Voice", vv)

## Anlatıcı konuşurken müziği kıs
func duck_voice(on: bool) -> void:
	_voice_duck = on

var _bus_level := 0.7

func _set_bus(bus_name: String, v: float) -> void:
	if bus_name == "Music":
		_bus_level = v
	var i := AudioServer.get_bus_index(bus_name)
	if i == -1:
		return
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
	AudioServer.set_bus_mute(i, v <= 0.001)

func _stream(track: String) -> AudioStream:
	if _cache.has(track):
		return _cache[track]
	var path := DIR + track + ".ogg"
	var s = AudioPack.find("music", track)   # profesyonel parça varsa o çalar
	if s == null:
		if not ResourceLoader.exists(path):
			_cache[track] = null
			return null
		s = load(path)
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = LOOPS.has(track)
	elif s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = LOOPS.has(track)
	elif s is AudioStreamWAV and LOOPS.has(track):
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		(s as AudioStreamWAV).loop_end = int((s as AudioStreamWAV).get_length() * (s as AudioStreamWAV).mix_rate)
	_cache[track] = s
	return s

func play(track: String, fade := 1.4) -> void:
	if track == current:
		return
	var s := _stream(track)
	current = track
	var old := _players[_active]
	_active = 1 - _active
	var nw := _players[_active]
	_fade(1 - _active, old, -80.0, fade, true)
	if s == null:
		return
	nw.stream = s
	nw.volume_db = -40.0
	nw.play()
	_fade(_active, nw, float(LEVEL.get(track, -4.0)), fade * 0.8, false)

func stop(fade := 1.2) -> void:
	current = ""
	for i in 2:
		_fade(i, _players[i], -80.0, fade, true)

func _fade(slot: int, p: AudioStreamPlayer, to: float, dur: float, stop_after: bool) -> void:
	var old = _tweens[slot]
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	var tw := create_tween()
	_tweens[slot] = tw
	tw.tween_property(p, "volume_db", to, maxf(dur, 0.01)).set_trans(Tween.TRANS_SINE)
	if stop_after:
		tw.tween_callback(p.stop)

## Döngüsüz çalgı (fanfar): döngüdeki müziği kısıp üstüne çalar
func sting(track: String, db := 0.0) -> void:
	var s := _stream(track)
	if s == null:
		return
	_sting.stream = s
	_sting.volume_db = db + float(LEVEL.get(track, 0.0))
	_sting.play()
	_duck_target = 1.0

func _process(delta: float) -> void:
	var want := maxf(_duck_target, 0.55 if _voice_duck else 0.0)
	_duck = lerpf(_duck, want, 1.0 - exp(-(6.0 if want > _duck else 2.5) * delta))
	var i := AudioServer.get_bus_index("Music")
	if i == -1:
		return
	# kısma veri yolu üstünden: çalan parçaların kendi geçişleri bozulmaz
	var base := linear_to_db(maxf(_bus_level, 0.0001))
	AudioServer.set_bus_volume_db(i, base - 12.0 * _duck)
