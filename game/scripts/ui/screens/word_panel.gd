class_name WordPanel
extends Control
## Günlük Kelime ekranı: 6×5 kutu, ekran klavyesi (TR/EN), kutular sırayla döner.
## Fiziksel klavyeden yazılır (Enter gönderir, Backspace siler, Esc kapatır) ya da tıklanır.
## Bitince sonuç kartı: kazanılan jeton, seri, paylaşım (panoya renkli kareler), yeni kelimeye kalan süre.

signal closed
signal rewarded

const TILE := 76.0
const GAP := 10.0
const ROWS_TR := ["ertyuıopğü", "asdfghjklşi", "zcvbnmöç"]
const ROWS_EN := ["qwertyuiop", "asdfghjkl", "zxcvbnm"]
const COL := [Color("3A3036"), Color("C9A22E"), Color("3E9A55")]   # yok / var / yerinde

var lang := "tr"
var _cur := ""
var _flip := {}             # "r,c" -> başlangıç zamanı
var _shake_row := -1
var _shake_t := 0.0
var _msg := ""
var _msg_t := 0.0
var _t := 0.0
var _keys: Array = []       # [Rect2, harf]
var _key_state := {}        # harf -> 0/1/2
var _result_t := -1.0
var _share_btn: CtaButton
var _close_btn: CtaButton
var _pop_row := -1
var _pop_t := 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_share_btn = CtaButton.new()
	_share_btn.style = "ghost"
	_share_btn.custom_minimum_size = Vector2(260, 64)
	_share_btn.size = Vector2(260, 64)
	_share_btn.font_size = 24
	_share_btn.pressed.connect(_share)
	add_child(_share_btn)
	_close_btn = CtaButton.new()
	_close_btn.custom_minimum_size = Vector2(260, 64)
	_close_btn.size = Vector2(260, 64)
	_close_btn.font_size = 26
	_close_btn.pressed.connect(close)
	add_child(_close_btn)

func open() -> void:
	lang = "en" if I18n.lang == "en" else "tr"
	_cur = ""
	_flip.clear()
	_msg = ""
	_rebuild_key_state()
	var s := DailyWord.state(lang)
	_result_t = 0.0 if bool(s.done) else -1.0
	_share_btn.label = Pal.t("word.share")
	_close_btn.label = Pal.t("common.done")
	_place_buttons()
	visible = true
	modulate.a = 0.0
	Fx.fade(self, 1.0, 0.3)
	Pal.sfx("page", -4.0)
	grab_focus()

func close() -> void:
	Fx.fade(self, 0.0, 0.25).finished.connect(func(): visible = false)
	closed.emit()

func _place_buttons() -> void:
	var done := bool(DailyWord.state(lang).done)
	_share_btn.visible = done
	_share_btn.position = Vector2(1920 * 0.5 + 330, 760)
	_close_btn.position = Vector2(1920 * 0.5 + 330, 840) if done else Vector2(1920 - 320, 960)
	_close_btn.style = "gold" if done else "ghost"

func _rebuild_key_state() -> void:
	_key_state.clear()
	var ans := DailyWord.answer(lang)
	for g in DailyWord.state(lang).guesses:
		var m := DailyWord.evaluate(String(g), ans)
		for i in DailyWord.LEN:
			var ch := String(g)[i]
			_key_state[ch] = maxi(int(_key_state.get(ch, -1)), int(m[i]))

# ── girdi ───────────────────────────────────────────────────────────
func _input(e: InputEvent) -> void:
	if not visible:
		return
	if e.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	if e is InputEventKey and e.pressed and not e.echo:
		var k := e as InputEventKey
		if k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
			_submit()
		elif k.keycode == KEY_BACKSPACE:
			_back()
		elif k.unicode > 0:
			_type(char(k.unicode))
		get_viewport().set_input_as_handled()
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		for kr in _keys:
			if (kr[0] as Rect2).has_point(e.position):
				var key: String = kr[1]
				if key == "⏎":
					_submit()
				elif key == "⌫":
					_back()
				else:
					_type(key)
				get_viewport().set_input_as_handled()
				return

func _type(ch: String) -> void:
	if bool(DailyWord.state(lang).done):
		return
	ch = DailyWord.lower(ch, lang)
	var alpha := ("".join(ROWS_TR) if lang == "tr" else "".join(ROWS_EN))
	if not alpha.contains(ch) or _cur.length() >= DailyWord.LEN:
		return
	_cur += ch
	_pop_row = DailyWord.state(lang).guesses.size()
	_pop_t = _t
	Pal.sfx("tick", -8.0, 1.2 + _cur.length() * 0.06)
	queue_redraw()

func _back() -> void:
	if _cur.length() > 0:
		_cur = _cur.substr(0, _cur.length() - 1)
		Pal.sfx("click", -10.0, 0.9)
		queue_redraw()

func _submit() -> void:
	if bool(DailyWord.state(lang).done):
		return
	var row: int = DailyWord.state(lang).guesses.size()
	var r := DailyWord.submit(lang, _cur)
	if not bool(r.ok):
		_shake_row = row
		_shake_t = 0.45
		_msg = Pal.t("word.short" if r.why == "len" else "word.unknown")
		_msg_t = 1.6
		Pal.sfx("buzz", -8.0, 1.3)
		return
	_cur = ""
	for c in DailyWord.LEN:
		_flip["%d,%d" % [row, c]] = _t + c * 0.22
	for c in DailyWord.LEN:
		get_tree().create_timer(c * 0.22 + 0.12).timeout.connect(func(): Pal.sfx("page", -12.0, 1.4 + c * 0.05))
	var reveal := DailyWord.LEN * 0.22 + 0.35
	get_tree().create_timer(reveal).timeout.connect(func():
		_rebuild_key_state()
		if bool(r.done):
			_result_t = _t
			_place_buttons()
			if bool(r.won):
				Pal.sfx("fanfare", -4.0, 1.1)
				Pal.sfx("coin", -2.0)
				_msg = Pal.t(["word.win1", "word.win2", "word.win3", "word.win4", "word.win5", "word.win6"][clampi(DailyWord.state(lang).guesses.size() - 1, 0, 5)])
			else:
				Pal.sfx("aww", -6.0)
				_msg = Pal.t("word.lose", {"w": DailyWord.upper(DailyWord.answer(lang), lang)})
			_msg_t = 3.0
			rewarded.emit()
		queue_redraw())

func _share() -> void:
	DisplayServer.clipboard_set(DailyWord.share_text(lang))
	_msg = Pal.t("word.copied")
	_msg_t = 1.6
	Pal.sfx("ui_confirm", -4.0)

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_shake_t = maxf(0.0, _shake_t - delta)
	_msg_t = maxf(0.0, _msg_t - delta)
	queue_redraw()

# ── çizim ───────────────────────────────────────────────────────────
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.01, 0.02, 0.9))
	var s := DailyWord.state(lang)
	var guesses: Array = s.guesses
	var ans := DailyWord.answer(lang)
	var done := bool(s.done)
	var f := Pal.display()
	# başlık
	var kick := Pal.upper(Pal.t("word.kicker", {"n": DailyWord.day_index() + 1}))
	var kf := Pal.kicker()
	var kw := kf.get_string_size(kick, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var cx := 1920 * 0.5 - (330.0 if done else 0.0)
	draw_string(kf, Vector2(cx - kw * 0.5, 64), kick, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Pal.GOLD)
	var title := Pal.upper(Pal.t("word.title"))
	var tw := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 72).x
	draw_string(f, Vector2(cx - tw * 0.5, 134), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 72, Pal.CHAMPAGNE)
	# jeton + seri (sağ üst)
	var coins := str(Progress.coins())
	Icons.draw(self, "coins", Vector2(100, 70), 30, Pal.GOLD)
	draw_string(Pal.display_bold(), Vector2(124, 82), coins, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Pal.GOLD)
	var stk := DailyWord.streak()
	if stk > 0:
		Icons.draw(self, "flame", Vector2(100, 120), 26, Color("FF8A3C"))
		draw_string(Pal.italic(), Vector2(124, 128), Pal.t("word.streak", {"n": stk}), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Pal.CREAM)
	# ızgara
	var gw := DailyWord.LEN * TILE + (DailyWord.LEN - 1) * GAP
	var x0 := cx - gw * 0.5
	var y0 := 170.0
	for r in DailyWord.TRIES:
		var off := 0.0
		if r == _shake_row and _shake_t > 0.0:
			off = sin(_shake_t * 60.0) * 12.0 * (_shake_t / 0.45)
		var word := ""
		var marks: Array = []
		if r < guesses.size():
			word = String(guesses[r])
			marks = DailyWord.evaluate(word, ans)
		elif r == guesses.size() and not done:
			word = _cur
		for c in DailyWord.LEN:
			var rect := Rect2(x0 + c * (TILE + GAP) + off, y0 + r * (TILE + GAP), TILE, TILE)
			var ch := word[c] if c < word.length() else ""
			var col := Color(0.09, 0.05, 0.06)
			var border := Color(Pal.BRASS, 0.35)
			var sy := 1.0
			var key := "%d,%d" % [r, c]
			var revealed := not marks.is_empty()
			if revealed and _flip.has(key):
				var k := clampf((_t - float(_flip[key])) / 0.3, 0.0, 1.0)
				sy = abs(cos(k * PI))
				revealed = k >= 0.5
			if revealed:
				col = COL[int(marks[c])]
				border = col.lightened(0.2)
			elif ch != "":
				border = Pal.CREAM
			if r == _pop_row and c == word.length() - 1 and ch != "" and not revealed:
				var pk := clampf((_t - _pop_t) / 0.12, 0.0, 1.0)
				rect = rect.grow((1.0 - pk) * 5.0)
			var rr := Rect2(rect.position + Vector2(0, rect.size.y * (1.0 - sy) * 0.5), Vector2(rect.size.x, rect.size.y * sy))
			draw_rect(rr, col)
			draw_rect(rr, border, false, 2.5)
			if ch != "" and sy > 0.2:
				var up := DailyWord.upper(ch, lang)
				var cw := f.get_string_size(up, HORIZONTAL_ALIGNMENT_LEFT, -1, 50).x
				draw_string(f, Vector2(rect.position.x + (TILE - cw) * 0.5, rect.position.y + TILE * 0.5 + 18), up, HORIZONTAL_ALIGNMENT_LEFT, -1, 50, Pal.CHAMPAGNE)
	# mesaj
	if _msg_t > 0.0 and _msg != "":
		var mw := Pal.italic().get_string_size(_msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
		var mr := Rect2(Vector2(cx - mw * 0.5 - 24, 700), Vector2(mw + 48, 50))
		draw_rect(mr, Color(Pal.NIGHT, 0.95 * minf(1.0, _msg_t * 3.0)))
		draw_rect(mr, Color(Pal.GOLD, 0.8 * minf(1.0, _msg_t * 3.0)), false, 2.0)
		draw_string(Pal.italic(), Vector2(cx - mw * 0.5, 735), _msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(Pal.CHAMPAGNE, minf(1.0, _msg_t * 3.0)))
	# klavye
	_keys.clear()
	var rows: Array = ROWS_TR if lang == "tr" else ROWS_EN
	var kwid := 70.0
	var kh := 68.0
	var ky := 770.0
	for ri in rows.size():
		var row: String = rows[ri]
		var n := row.length() + (2 if ri == rows.size() - 1 else 0)
		var total := row.length() * (kwid + 8) + (2 * (kwid * 1.5 + 8) if ri == rows.size() - 1 else 0.0) - 8
		var kx := cx - total * 0.5
		var items := []
		if ri == rows.size() - 1:
			items.append("⏎")
		for i in row.length():
			items.append(row[i])
		if ri == rows.size() - 1:
			items.append("⌫")
		for it in items:
			var wide: bool = it == "⏎" or it == "⌫"
			var w := kwid * 1.5 if wide else kwid
			var rect2 := Rect2(kx, ky + ri * (kh + 8), w, kh)
			var st := int(_key_state.get(it, -1))
			var kc: Color = Color(0.2, 0.13, 0.14) if st < 0 else (COL[st] if st > 0 else Color(0.1, 0.07, 0.08))
			var hov := rect2.has_point(get_local_mouse_position())
			draw_rect(rect2, kc.lightened(0.12 if hov else 0.0))
			draw_rect(rect2, Color(Pal.BRASS, 0.4), false, 1.5)
			var label: String = Pal.t("word.enter") if it == "⏎" else (it if it == "⌫" else DailyWord.upper(it, lang))
			var fs := 22 if it == "⏎" else 32
			var lw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(f, Vector2(kx + (w - lw) * 0.5, rect2.position.y + kh * 0.5 + fs * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Pal.CHAMPAGNE, 0.35 if st == 0 else 1.0))
			_keys.append([rect2, it])
			kx += w + 8
	# sonuç kartı
	if done and _result_t >= 0.0:
		var a := clampf((_t - _result_t) / 0.5, 0.0, 1.0)
		var card := Rect2(Vector2(1920 * 0.5 + 60, 190), Vector2(540, 540))
		var pts := Icons.notched(card, 16.0)
		draw_colored_polygon(pts, Color(Pal.NIGHT, 0.95 * a))
		Icons.outline(self, pts, Color(Pal.GOLD, a), 2.0)
		var won := bool(s.won)
		var head := Pal.upper(Pal.t("word.won" if won else "word.lost"))
		draw_string(f, card.position + Vector2(36, 80), head, HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 72, 56, Color(Pal.GOOD if won else Pal.BAD, a))
		draw_string(Pal.italic(), card.position + Vector2(38, 124), Pal.t("word.answer", {"w": DailyWord.upper(ans, lang)}), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(Pal.CREAM, a))
		Icons.draw(self, "coins", card.position + Vector2(62, 200), 48, Color(Pal.GOLD, a))
		draw_string(f, card.position + Vector2(100, 220), "+%d" % int(s.reward), HORIZONTAL_ALIGNMENT_LEFT, -1, 64, Color(Pal.GOLD, a))
		draw_string(Pal.italic(), card.position + Vector2(40, 268), Pal.t("word.reward_note"), HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 80, 19, Color(Pal.CREAM, 0.75 * a))
		# küçük renkli özet
		var mini_y := card.position.y + 300
		for gi in guesses.size():
			var mk := DailyWord.evaluate(String(guesses[gi]), ans)
			for c in DailyWord.LEN:
				draw_rect(Rect2(card.position.x + 40 + c * 26, mini_y + gi * 26, 22, 22), Color(COL[int(mk[c])], a))
		var left := DailyWord.seconds_to_next()
		var nxt := Pal.t("word.next", {"t": "%02d:%02d:%02d" % [left / 3600, (left / 60) % 60, left % 60]})
		draw_string(Pal.kicker(), Vector2(card.position.x + 200, mini_y + 30), nxt, HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 220, 18, Color(Pal.GOLD, a))
	elif not done:
		var hint := Pal.t("word.hint")
		var hw := Pal.italic().get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		draw_string(Pal.italic(), Vector2(cx - hw * 0.5, 1040), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(Pal.CREAM, 0.65))
