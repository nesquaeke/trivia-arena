class_name PhoneBridge
extends Node
## Ev partisi: oyun ile telefon kumandası sunucusu arasındaki köprü.
## Sunucuya "sahne" olarak WebSocket ile bağlanır, 4 harfli oda kodu alır,
## telefonlardan gelen joystick/tuş girdilerini saklar, telefonlara kısa
## mesajlar yollar. Bağlantı koparsa aynı kod ve anahtarla yeniden bağlanır
## (sunucu odayı 30 sn bekletir, telefonlar kopmaz).

signal hosted(code: String)
signal pad_joined(pid: String, pad_name: String)
signal pad_left(pid: String)
signal state_changed(state: String)

var url := ""
var code := ""
var state := "off"            # off | connecting | live | error
var inputs := {}              # pid -> {x, y, j, s}
var names := {}               # pid -> ad
var events := {}              # pid -> {tür: son olay} (sayı klavyesi, şık düğmesi)

var _ws: WebSocketPeer = null
var _key := ""
var _hosted_sent := false
var _retry_in := -1.0
var _tries := 0

func start(p_url: String) -> void:
	url = p_url.strip_edges()
	if _key == "":
		_key = "%x%x" % [randi(), Time.get_ticks_usec()]
	_tries = 0
	_open()

func stop() -> void:
	_retry_in = -1.0
	if _ws:
		_ws.close()
	_ws = null
	_set_state("off")
	inputs.clear()
	names.clear()

func _set_state(s: String) -> void:
	if s != state:
		state = s
		state_changed.emit(s)

func _open() -> void:
	_ws = WebSocketPeer.new()
	_ws.inbound_buffer_size = 1 << 18
	_hosted_sent = false
	var err := _ws.connect_to_url(url)
	if err != OK:
		_set_state("error")
		_schedule_retry()
		return
	_set_state("connecting")

func _schedule_retry() -> void:
	_tries += 1
	_retry_in = min(8.0, 0.5 * pow(2.0, _tries))

func _process(delta: float) -> void:
	if _retry_in > 0.0:
		_retry_in -= delta
		if _retry_in <= 0.0:
			_open()
		return
	if _ws == null:
		return
	_ws.poll()
	var st := _ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		if not _hosted_sent:
			_hosted_sent = true
			_send({"t": "host", "code": code, "key": _key})
		while _ws.get_available_packet_count() > 0:
			var txt := _ws.get_packet().get_string_from_utf8()
			var m = JSON.parse_string(txt)
			if typeof(m) == TYPE_DICTIONARY:
				_handle(m)
	elif st == WebSocketPeer.STATE_CLOSED:
		_ws = null
		if state != "off":
			_set_state("error")
			_schedule_retry()

func _handle(m: Dictionary) -> void:
	match String(m.get("t", "")):
		"hosted":
			code = String(m.get("code", ""))
			_tries = 0
			_set_state("live")
			hosted.emit(code)
		"pad_join":
			var pid := String(m.get("pid", ""))
			names[pid] = String(m.get("name", "Oyuncu"))
			inputs[pid] = {"x": 0.0, "y": 0.0, "j": false, "s": false}
			pad_joined.emit(pid, names[pid])
		"pad_left":
			var pid2 := String(m.get("pid", ""))
			inputs.erase(pid2)
			pad_left.emit(pid2)
		"in":
			var pid3 := String(m.get("pid", ""))
			inputs[pid3] = {"x": float(m.get("x", 0.0)), "y": float(m.get("y", 0.0)), "j": bool(m.get("j", false)), "s": bool(m.get("s", false))}
		"num":
			_push(String(m.get("pid", "")), "num", {"v": int(m.get("v", 0)), "lock": bool(m.get("lock", false))})
		"ans":
			_push(String(m.get("pid", "")), "ans", {"i": int(m.get("i", -1))})
		"rx":
			_push(String(m.get("pid", "")), "rx", {"r": String(m.get("r", "HAHA"))})

func _push(pid: String, kind: String, e: Dictionary) -> void:
	if pid == "":
		return
	if not events.has(pid):
		events[pid] = {}
	events[pid][kind] = e

## Bir kumandanın bekleyen olayını al (yoksa boş sözlük)
func take_event(pid: String, kind: String) -> Dictionary:
	var box: Dictionary = events.get(pid, {})
	if not box.has(kind):
		return {}
	var e: Dictionary = box[kind]
	box.erase(kind)
	return e

func _send(obj: Dictionary) -> void:
	if _ws and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(JSON.stringify(obj))

func send_to(pid: String, msg: Dictionary) -> void:
	_send({"t": "to", "pid": pid, "msg": msg})

func broadcast(msg: Dictionary) -> void:
	_send({"t": "all", "msg": msg})

func http_base() -> String:
	var b := url.replace("wss://", "https://").replace("ws://", "http://")
	if b.ends_with("/ws"):
		b = b.substr(0, b.length() - 3)
	return b.trim_suffix("/")

func pad_url() -> String:
	return http_base() + "/pad?c=" + code

func qr_url() -> String:
	return http_base() + "/qr.png?text=" + pad_url().uri_encode()
