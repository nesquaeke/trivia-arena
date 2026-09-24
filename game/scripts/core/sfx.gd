extends Node
## Bütün ses efektleri çalışma anında sentezlenir; ses dosyası yok.
## Sfx.play("jump"), Sfx.play("scream", -4.0, 1.1)

const RATE := 22050
var streams := {}
var _voices: Array[AudioStreamPlayer] = []
var _next := 0
var muted := false
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 7
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_voices.append(p)
	streams.jump = _make(0.22, _jump)
	streams.land = _make(0.14, _land)
	streams.shove = _make(0.22, _shove)
	streams.bump = _make(0.12, _bump)
	streams.oof = _make(0.32, _oof)
	streams.trapdoor = _make(0.7, _trapdoor)
	streams.scream = _make(1.3, _scream)
	streams.tick = _make(0.05, _tick)
	streams.ding = _make(1.1, _ding)
	streams.buzz = _make(0.45, _buzz)
	streams.applause = _make(2.2, _applause)
	streams.drumroll = _make(1.6, _drumroll)
	streams.whoosh = _make(0.8, _whoosh)
	streams.fanfare = _make(1.6, _fanfare)
	streams.click = _make(0.06, _click)
	streams.thud = _make(0.3, _thud)

func play(name: String, db: float = 0.0, pitch: float = 1.0) -> void:
	if muted or not streams.has(name):
		return
	var p := _voices[_next]
	_next = (_next + 1) % _voices.size()
	p.stream = streams[name]
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()

# ── sentez yardımcıları ──────────────────────────────────────────────
func _make(seconds: float, fn: Callable) -> AudioStreamWAV:
	var n := int(seconds * RATE)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var v: float = clamp(fn.call(t, seconds), -1.0, 1.0)
		bytes.encode_s16(i * 2, int(v * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	return s

func _env(t: float, a: float, d: float) -> float:
	if t < a:
		return t / a
	return exp(-(t - a) / d)

func _noise() -> float:
	return _rng.randf_range(-1.0, 1.0)

var _lp := 0.0
func _lowpass(x: float, k: float) -> float:
	_lp += (x - _lp) * k
	return _lp

# ── sesler ───────────────────────────────────────────────────────────
func _jump(t: float, _l: float) -> float:
	var f := 260.0 + 900.0 * t
	return sin(TAU * f * t) * _env(t, 0.005, 0.08) * 0.5

func _land(t: float, _l: float) -> float:
	return (sin(TAU * 90.0 * t) * 0.7 + _lowpass(_noise(), 0.08) * 0.8) * _env(t, 0.002, 0.04)

func _shove(t: float, _l: float) -> float:
	var f := 160.0 - 90.0 * t
	return (sin(TAU * f * t) * 0.7 + _lowpass(_noise(), 0.12) * 0.9) * _env(t, 0.004, 0.06)

func _bump(t: float, _l: float) -> float:
	return sin(TAU * (120.0 - 200.0 * t) * t) * _env(t, 0.002, 0.03) * 0.6

func _oof(t: float, _l: float) -> float:
	# iki formantlı "hıh!" — kısa, komik bir iniş
	var f0 := 260.0 - 160.0 * t
	var v := sin(TAU * f0 * t) * 0.5 + sin(TAU * f0 * 2.0 * t) * 0.25 + sin(TAU * 700.0 * t) * 0.08
	return v * _env(t, 0.01, 0.09)

func _trapdoor(t: float, _l: float) -> float:
	# metalik gıcırtı + tok çarpma
	var creak := sin(TAU * (380.0 + 60.0 * sin(TAU * 7.0 * t)) * t) * 0.18 * _env(t, 0.02, 0.18)
	var clank := 0.0
	if t > 0.28:
		var u := t - 0.28
		clank = (sin(TAU * 523.0 * u) + sin(TAU * 1370.0 * u) * 0.6 + sin(TAU * 2210.0 * u) * 0.4) * 0.25 * _env(u, 0.001, 0.12)
		clank += _lowpass(_noise(), 0.2) * 0.6 * _env(u, 0.001, 0.05)
	return creak + clank

func _scream(t: float, l: float) -> float:
	# "aaaaa…" — vibratolu, alçalan
	var f := 780.0 * pow(0.28, t / l) + 18.0 * sin(TAU * 6.5 * t)
	var ph := TAU * f * t
	var v := sin(ph) * 0.45 + sin(ph * 2.0) * 0.2 + sin(ph * 3.0) * 0.08
	return v * min(1.0, t * 30.0) * (1.0 - t / l)

func _tick(t: float, _l: float) -> float:
	return sin(TAU * 1800.0 * t) * _env(t, 0.0005, 0.01) * 0.5

func _ding(t: float, _l: float) -> float:
	return (sin(TAU * 880.0 * t) * 0.5 + sin(TAU * 1760.0 * t) * 0.2 + sin(TAU * 2637.0 * t) * 0.1) * _env(t, 0.002, 0.35)

func _buzz(t: float, _l: float) -> float:
	var sq := 1.0 if fmod(t * 110.0, 1.0) < 0.5 else -1.0
	return sq * 0.25 * _env(t, 0.005, 0.25)

func _applause(t: float, l: float) -> float:
	# rastgele el çırpmaları
	var clap := 0.0
	if _rng.randf() < 0.012:
		clap = 1.0
	_lp = _lp * 0.93 + clap * _noise()
	var body := _noise() * 0.12
	var shape := sin(PI * t / l)
	return (_lp * 0.8 + body) * shape

func _drumroll(t: float, l: float) -> float:
	var trem := 0.55 + 0.45 * sin(TAU * 22.0 * t)
	return _lowpass(_noise(), 0.35) * trem * (0.4 + 0.6 * t / l)

func _whoosh(t: float, l: float) -> float:
	var k := 0.02 + 0.25 * sin(PI * t / l)
	return _lowpass(_noise(), k) * sin(PI * t / l) * 1.2

func _fanfare(t: float, _l: float) -> float:
	var notes := [523.25, 659.25, 783.99, 1046.5]
	var idx := int(min(3.0, t / 0.18))
	var f: float = notes[idx]
	var u := t - idx * 0.18
	var saw := fmod(f * t, 1.0) * 2.0 - 1.0
	var sq := 1.0 if fmod(f * t, 1.0) < 0.5 else -1.0
	var d := 0.5 if idx == 3 else 0.12
	return (saw * 0.2 + sq * 0.1) * _env(u, 0.01, d)

func _click(t: float, _l: float) -> float:
	return _noise() * _env(t, 0.0005, 0.006) * 0.6

func _thud(t: float, _l: float) -> float:
	return (sin(TAU * (70.0 - 40.0 * t) * t) + _lowpass(_noise(), 0.05) * 0.5) * _env(t, 0.003, 0.09)
