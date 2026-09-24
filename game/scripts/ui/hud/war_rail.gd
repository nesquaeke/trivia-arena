class_name WarRail
extends Control
## Conquest'in sol sütunu: her general bir "sancak kartı".
##   sol    oyuncunun renginde sancak, üstünde kostümlü canlı 3D portresi
##   orta   ad · bölge sayısı · kalenin kuleleri (ayakta / yıkık)
##   sağ    dönen puan; kazanç/kayıp kartın yanından uçar
## Sırası gelen kart sağa çıkar ve nabız gibi parlar; elenen kart solar,
## portresi grileşir. Sıralama değişince kartlar yaylanarak yer değiştirir.

const GAP := 8.0
var cards := {}           # isim -> WarCard

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func update_rows(rows: Array) -> void:
	var seen := {}
	var h := WarCard.H if rows.size() <= 6 else WarCard.H_SMALL
	for i in rows.size():
		var r: Dictionary = rows[i]
		var key := String(r.get("name", ""))
		seen[key] = true
		var card: WarCard = cards.get(key)
		var ty := i * (h + GAP)
		if card == null:
			card = WarCard.new()
			card.compact = rows.size() > 6
			add_child(card)
			cards[key] = card
			card.position = Vector2(-380, ty)
			card.target_y = ty
			card.intro(0.07 * i)
		card.target_y = ty
		card.apply(r, i + 1)
	for k in cards.keys():
		if not seen.has(k):
			cards[k].queue_free()
			cards.erase(k)

func clear() -> void:
	for c in cards.values():
		c.queue_free()
	cards.clear()


class WarCard extends Control:
	const W := 318.0
	const H := 86.0
	const H_SMALL := 64.0
	const PW := 84.0

	var row := {}
	var rank := 1
	var compact := false
	var target_y := 0.0
	var _x := -380.0
	var _num: RollingNumber
	var _portrait: PlushPortrait
	var _look_key := ""
	var _turn := 0.0
	var _dead := 0.0
	var _t := 0.0
	var _flash := 0.0
	var _delta_txt := ""
	var _delta_col := Color.WHITE
	var _delta_t := 0.0
	var _towers_prev := -1
	var _tower_hit := 0.0

	func _ready() -> void:
		var h := H_SMALL if compact else H
		size = Vector2(W, h)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = false
		_portrait = PlushPortrait.new()
		_portrait.hop_every = 9.0
		_portrait.size = Vector2(PW, h - 6)
		_portrait.position = Vector2(8, 3)
		_portrait.close_up = true
		add_child(_portrait)
		_num = RollingNumber.new()
		_num.font_size = 34 if compact else 40
		_num.position = Vector2(W - 118, 4)
		_num.size = Vector2(106, h - 8)
		_num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_num)

	func intro(delay: float) -> void:
		_x = -380.0
		modulate.a = 0.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(self, "_x", 0.0, 0.6).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "modulate:a", 1.0, 0.3).set_delay(delay)

	func apply(r: Dictionary, p_rank: int) -> void:
		var first := row.is_empty()
		row = r
		rank = p_rank
		var v := int(r.get("value", 0))
		if first:
			_num.snap(v)
		else:
			_num.value = v
		var look: Dictionary = r.get("look", {})
		var culture := String(r.get("culture", ""))
		var key := str(look) + culture
		if key != _look_key and _portrait:
			_look_key = key
			_portrait.set_look(look)
			_portrait.set_culture(culture)
		var d := int(r.get("delta", 0))
		if d != 0:
			_delta_txt = ("+%d" % d) if d > 0 else ("−%d" % -d)
			_delta_col = Pal.GOOD if d > 0 else Pal.BAD
			_delta_t = 1.8
			_flash = 1.0
			if d > 0 and _portrait:
				_portrait.hop()
		var tw := int(r.get("towers", -1))
		if _towers_prev >= 0 and tw >= 0 and tw < _towers_prev:
			_tower_hit = 1.0
		_towers_prev = tw

	func _process(delta: float) -> void:
		_t += delta
		var turn_on := bool(row.get("turn", false))
		var alive := bool(row.get("alive", true))
		_turn = Fx.damp(_turn, 1.0 if turn_on else 0.0, 9.0, delta)
		_dead = Fx.damp(_dead, 0.0 if alive else 1.0, 5.0, delta)
		_flash = maxf(0.0, _flash - delta * 2.0)
		_delta_t = maxf(0.0, _delta_t - delta)
		_tower_hit = maxf(0.0, _tower_hit - delta * 1.5)
		position = Vector2(_x + _turn * 22.0, Fx.damp(position.y, target_y, 10.0, delta))
		if _portrait:
			_portrait.modulate = Color(1, 1, 1).lerp(Color(0.45, 0.42, 0.45), _dead)
		_num.modulate.a = 1.0 - _dead * 0.6
		queue_redraw()

	func _draw() -> void:
		var h := size.y
		var col: Color = row.get("color", Pal.GOLD)
		var sk := 12.0
		# gölge + gövde (eğik kart)
		var body := PackedVector2Array([Vector2(sk, 0), Vector2(W, 0), Vector2(W - sk, h), Vector2(0, h)])
		var sh := PackedVector2Array()
		for p in body:
			sh.append(p + Vector2(5, 6))
		draw_colored_polygon(sh, Color(0, 0, 0, 0.45))
		var base := Color(0.07, 0.03, 0.035, 0.93).lerp(Color(0.05, 0.05, 0.05, 0.8), _dead)
		draw_colored_polygon(body, base)
		# sıra sende: renkli ışık bandı
		if _turn > 0.01:
			var glow := 0.55 + 0.45 * sin(_t * 5.0)
			draw_colored_polygon(body, Color(col, 0.16 * _turn * glow))
			draw_polyline(_closed(body), Color(col.lightened(0.3), _turn), 2.5, true)
		else:
			draw_polyline(_closed(body), Color(Pal.BRASS, 0.3), 1.0, true)
		# sancak: portrenin arkasında renkli kumaş, altı kırlangıç kuyruğu
		var bx := sk * 0.3
		var bw := PW + 16.0
		var flag := PackedVector2Array([Vector2(bx + sk, 0), Vector2(bx + bw + sk * 0.2, 0), Vector2(bx + bw - sk * 0.6, h),
			Vector2(bx + bw * 0.5, h - 12), Vector2(bx, h)])
		var fcol := col.darkened(0.25).lerp(Color(0.3, 0.3, 0.32), _dead)
		draw_colored_polygon(flag, fcol)
		draw_line(Vector2(bx + sk, 2), Vector2(bx + bw + sk * 0.2, 2), Color(col.lightened(0.4), 0.8 * (1.0 - _dead)), 2.0)
		if _flash > 0.0:
			draw_colored_polygon(body, Color(1, 0.95, 0.8, 0.18 * _flash))
		# ad
		var x0 := bx + bw + 14.0
		var name_fs := 22 if compact else 26
		var nm := Pal.upper(String(row.get("name", "")))
		var ncol := Pal.CHAMPAGNE.lerp(Pal.MUTED, _dead)
		if _turn > 0.05:
			var tag := Pal.upper(Pal.t("cq.yourTurn"))
			var kf := Pal.kicker()
			draw_string(kf, Vector2(x0, 16), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(col.lightened(0.45), _turn))
		draw_string(Pal.display_bold(), Vector2(x0, (h * 0.46) + (4 if _turn > 0.05 else 0)), nm, HORIZONTAL_ALIGNMENT_LEFT, W - x0 - 118, name_fs, ncol)
		if rank == 1 and _dead < 0.5:
			Icons.draw(self, "crown", Vector2(x0 + Pal.display_bold().get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, name_fs).x + 14, h * 0.46 - name_fs * 0.4), 16, Pal.GOLD)
		# alt satır: bölge + kuleler (ya da DÜŞTÜ)
		var y2 := h - (14.0 if compact else 18.0)
		if _dead > 0.5:
			Icons.draw(self, "skull", Vector2(x0 + 8, y2 - 5), 15, Pal.BAD)
			draw_string(Pal.kicker(), Vector2(x0 + 22, y2), Pal.upper(Pal.t("cq.fallen")), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.BAD)
		else:
			var tiles := int(row.get("tiles", 0))
			_hex(Vector2(x0 + 7, y2 - 6), 7.0, col.lightened(0.2))
			draw_string(Pal.display_bold(), Vector2(x0 + 19, y2), str(tiles), HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Pal.CREAM)
			var towers := int(row.get("towers", -1))
			if towers >= 0:
				var tx := x0 + 50.0
				for i in 3:
					var up := i < towers
					var shake := sin(_t * 40.0) * 2.0 * _tower_hit if i == towers else 0.0
					_tower(Vector2(tx + i * 16 + shake, y2 + 1), up, col)
		# kazanç/kayıp uçar
		if _delta_t > 0.0:
			var k := 1.0 - _delta_t / 1.8
			var a := clampf(_delta_t * 1.5, 0.0, 1.0)
			draw_string(Pal.display(), Vector2(W + 14 + k * 20, h * 0.62 - k * 18), _delta_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(_delta_col, a))

	func _closed(p: PackedVector2Array) -> PackedVector2Array:
		var o := p.duplicate()
		o.append(p[0])
		return o

	func _hex(c: Vector2, r: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 6:
			var a := PI / 6 + TAU * i / 6.0
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(pts, col)

	## Minik kule: dişli tepe; yıkıksa yalnız kırık taban
	func _tower(b: Vector2, up: bool, col: Color) -> void:
		if up:
			draw_rect(Rect2(b + Vector2(-5, -15), Vector2(10, 15)), col.lightened(0.15))
			for k in 3:
				draw_rect(Rect2(b + Vector2(-6 + k * 4.5, -19), Vector2(3, 4)), col.lightened(0.15))
			draw_rect(Rect2(b + Vector2(-1.5, -7), Vector2(3, 7)), Color(0, 0, 0, 0.45))
		else:
			draw_colored_polygon(PackedVector2Array([b + Vector2(-5, 0), b + Vector2(-5, -6), b + Vector2(-1, -4), b + Vector2(2, -8), b + Vector2(5, -5), b + Vector2(5, 0)]), Color(Pal.MUTED, 0.5))
