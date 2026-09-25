class_name RewardPicker
extends Control
## Güç turu ödülü: önce hedef (kime?), sonra eylem (ne?). Seçili kart
## havaya kalkar ve parlar. Kumanda ile gez / zıpla onay / omuz geri,
## ya da fareyle tıkla.

signal clicked(step: int, index: int)

var player := ""
var player_color := Color.WHITE
var step := 0
var sel := [0, 0]
var targets: Array = []        # [{name, color, points}]
var actions: Array = []        # [{id, name, desc}]
var left := 0.0
var total := 1.0
var _cards: Array[Control] = []
var _lift: Array = []
var _t := 0.0
var _hover := -1

func _ready() -> void:
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func open(p_name: String, p_color: Color, p_targets: Array, p_actions: Array) -> void:
	player = p_name
	player_color = p_color
	targets = p_targets
	actions = p_actions
	step = 0
	sel = [0, 0]
	visible = true
	modulate.a = 0.0
	Fx.fade(self, 1.0, 0.25)
	_build()

func select(p_step: int, idx: int) -> void:
	var changed_step := p_step != step
	step = p_step
	sel[step] = idx
	if changed_step:
		_build()
	Pal.sfx("tick", -8.0, 1.3 + idx * 0.05)

func set_time(p_left: float, p_total: float) -> void:
	left = p_left
	total = p_total

func close() -> void:
	Fx.fade(self, 0.0, 0.3)

func _items() -> Array:
	return targets if step == 0 else actions

func _build() -> void:
	for c in _cards:
		c.queue_free()
	_cards.clear()
	_lift.clear()
	var items := _items()
	var cw := 250.0 if step == 0 else 262.0
	var ch := 300.0 if step == 0 else 340.0
	var gap := 26.0
	var tw := items.size() * cw + (items.size() - 1) * gap
	var x0 := (1920 - tw) * 0.5
	for i in items.size():
		var c := Control.new()
		c.position = Vector2(x0 + i * (cw + gap), 430)
		c.size = Vector2(cw, ch)
		c.pivot_offset = Vector2(cw * 0.5, ch)
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var idx := i
		c.draw.connect(func(): _draw_card(c, idx))
		c.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				clicked.emit(step, idx))
		c.mouse_entered.connect(func(): _hover = idx)
		c.mouse_exited.connect(func(): if _hover == idx: _hover = -1)
		add_child(c)
		_cards.append(c)
		_lift.append(0.0)
		Fx.pop(c, i * 0.05, 0.8, 0.4)

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	for i in _cards.size():
		_lift[i] = Fx.damp(_lift[i], 1.0 if i == sel[step] else (0.4 if i == _hover else 0.0), 14.0, delta)
		var c := _cards[i]
		c.position.y = 430 - 28.0 * _lift[i]
		c.rotation = (i - (_cards.size() - 1) * 0.5) * 0.025 * (1.0 - _lift[i])
		c.queue_redraw()
	queue_redraw()

func _draw() -> void:
	draw_rect(Pal.BLEED, Color(0.03, 0.01, 0.015, 0.72))
	# başlık
	var kf := Pal.kicker()
	var head := Pal.upper(Pal.t("round.2"))
	var hw := kf.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + head.length() * 6
	var x := (1920 - hw) * 0.5
	for i in head.length():
		draw_string(kf, Vector2(x, 230), head.substr(i, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Pal.GOLD)
		x += kf.get_char_size(head.unicode_at(i), 24).x + 6
	var f := Pal.display()
	var t1 := Pal.upper(player)
	var t2 := Pal.upper(Pal.t("reward.pick_target" if step == 0 else "reward.pick_action"))
	var w1 := f.get_string_size(t1 + "  ", HORIZONTAL_ALIGNMENT_LEFT, -1, 92).x
	var w2 := f.get_string_size(t2, HORIZONTAL_ALIGNMENT_LEFT, -1, 92).x
	var tx := (1920 - w1 - w2) * 0.5
	draw_string(f, Vector2(tx, 330), t1, HORIZONTAL_ALIGNMENT_LEFT, -1, 92, player_color.lightened(0.25))
	draw_string(f, Vector2(tx + w1, 330), t2, HORIZONTAL_ALIGNMENT_LEFT, -1, 92, Pal.CHAMPAGNE)
	# adım göstergesi
	for i in 2:
		var c := Vector2(1920 * 0.5 - 16 + i * 32, 370)
		Icons.draw(self, "diamond", c, 14, Pal.GOLD if i <= step else Color(Pal.CREAM, 0.25))
	# süre çubuğu
	var k := clampf(left / maxf(total, 0.01), 0.0, 1.0)
	var br := Rect2(660, 850, 600, 6)
	draw_rect(br, Color(0, 0, 0, 0.5))
	draw_rect(Rect2(br.position, Vector2(br.size.x * k, br.size.y)), Pal.GOLD if k > 0.3 else Pal.BAD)
	var hint := Pal.t("reward.how")
	var hwid := Pal.italic().get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	draw_string(Pal.italic(), Vector2((1920 - hwid) * 0.5, 900), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(Pal.CREAM, 0.8))

func _draw_card(c: Control, i: int) -> void:
	var items := _items()
	if i >= items.size():
		return
	var it: Dictionary = items[i]
	var on: bool = i == sel[step]
	var r := Rect2(Vector2.ZERO, c.size)
	var pts := Icons.notched(r, 14.0)
	c.draw_colored_polygon(Icons.notched(Rect2(Vector2(0, 16 + 10 * _lift[i]), c.size), 14.0), Color(0, 0, 0, 0.45))
	var top := Color("2A0C12") if not on else Color("4A1420")
	var bot := Color("12060A")
	var cols := PackedColorArray([top, top, top, bot, bot, bot, bot, top])
	c.draw_polygon(pts, cols)
	var line := Pal.GOLD if on else Color(Pal.BRASS, 0.5)
	Icons.outline(c, pts, line, 2.5 if on else 1.0)
	if on:
		Icons.outline(c, Icons.notched(r.grow(6), 18.0), Color(Pal.GOLD, 0.25 + 0.15 * sin(_t * 6.0)), 3.0)
	var cx := c.size.x * 0.5
	if step == 0:
		var col: Color = it.get("color", Color.WHITE)
		# pelüş kafası
		var hc := Vector2(cx, 108)
		c.draw_circle(hc + Vector2(0, 5), 58, Color(0, 0, 0, 0.35))
		c.draw_circle(hc + Vector2(-44, -40), 22, col.darkened(0.1))
		c.draw_circle(hc + Vector2(44, -40), 22, col.darkened(0.1))
		c.draw_circle(hc, 56, col)
		c.draw_circle(hc + Vector2(0, 18), 22, col.lightened(0.25))
		c.draw_circle(hc + Vector2(-19, -6), 6, Pal.INK)
		c.draw_circle(hc + Vector2(19, -6), 6, Pal.INK)
		c.draw_circle(hc + Vector2(0, 12), 5, Pal.INK)
		var nf := Pal.display()
		var nm := Pal.upper(String(it.get("name", "")))
		var nw := minf(nf.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 44).x, c.size.x - 20)
		c.draw_string(nf, Vector2(cx - nw * 0.5, 222), nm, HORIZONTAL_ALIGNMENT_LEFT, c.size.x - 20, 44, Pal.CHAMPAGNE)
		var ps := str(int(it.get("points", 0)))
		var pw := Pal.display_bold().get_string_size(ps, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		c.draw_string(Pal.display_bold(), Vector2(cx - pw * 0.5, 266), ps, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Pal.GOLD)
		if int(it.get("rank", 9)) == 1:
			Icons.draw(c, "crown", Vector2(cx, 32), 30, Pal.GOLD)
	else:
		var id := String(it.get("id", ""))
		var ic := Pal.GOLD if id == "siphon" else (Color("9FD8FF") if id == "ice" else Color("FF8A6A"))
		c.draw_circle(Vector2(cx, 96), 62, Color(ic, 0.12 + (0.1 if on else 0.0)))
		c.draw_arc(Vector2(cx, 96), 62, 0, TAU, 48, Color(ic, 0.6), 1.5, true)
		var bob := sin(_t * 4.0 + i) * (4.0 if on else 0.0)
		Icons.draw(c, id, Vector2(cx, 96 + bob), 70, ic, 5.0)
		var nf := Pal.display()
		var nm := Pal.upper(String(it.get("name", "")))
		var fs := 38
		while fs > 24 and nf.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > c.size.x - 24:
			fs -= 2
		var nw := nf.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		c.draw_string(nf, Vector2(cx - nw * 0.5, 212), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.CHAMPAGNE)
		var para := TextParagraph.new()
		para.width = c.size.x - 36
		para.alignment = HORIZONTAL_ALIGNMENT_CENTER
		para.add_string(String(it.get("desc", "")), Pal.italic(), 19)
		para.draw(c.get_canvas_item(), Vector2(18, 232), Color(Pal.CREAM, 0.85))
