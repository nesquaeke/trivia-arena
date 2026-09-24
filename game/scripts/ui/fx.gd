class_name Fx
extends RefCounted
## Arayüz hareketleri: yaylı girişler, sıralı (stagger) belirme, vuruş.
## Hepsi Tween; süreler burada, istersen buradan yavaşlat/hızlandır.

const SPRING := Tween.TRANS_BACK
const SMOOTH := Tween.TRANS_CUBIC
const SNAP := Tween.TRANS_QUINT

## Kontrolü aşağıdan/yukarıdan kayarak, saydamdan getirir.
static func rise(c: CanvasItem, delay := 0.0, from := Vector2(0, 28), dur := 0.55) -> Tween:
	var ctl := c as Control
	var base: Vector2 = c.get_meta("fx_base", ctl.position if ctl else Vector2.ZERO)
	c.set_meta("fx_base", base)
	c.modulate.a = 0.0
	if ctl:
		ctl.position = base + from
	var tw := c.create_tween().set_parallel(true)
	tw.tween_property(c, "modulate:a", 1.0, dur * 0.7).set_delay(delay)
	if ctl:
		tw.tween_property(ctl, "position", base, dur).set_delay(delay).set_trans(SPRING).set_ease(Tween.EASE_OUT)
	return tw

## Ölçekle belirme (pivot ortada)
static func pop(c: Control, delay := 0.0, from := 0.6, dur := 0.5) -> Tween:
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2.ONE * from
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel(true)
	tw.tween_property(c, "scale", Vector2.ONE, dur).set_delay(delay).set_trans(SPRING).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, dur * 0.5).set_delay(delay)
	return tw

## Kısa vuruş: büyüyüp geri döner
static func punch(c: Control, amount := 0.12, dur := 0.35) -> void:
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2.ONE * (1.0 + amount), dur * 0.3).set_trans(SNAP).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, dur * 0.7).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

## Yatay sarsıntı (yanlış, hasar)
static func shake(c: Control, amount := 10.0, dur := 0.4) -> void:
	var base: Vector2 = c.get_meta("fx_base", c.position)
	var tw := c.create_tween()
	var steps := 6
	for i in steps:
		var k := 1.0 - float(i) / steps
		tw.tween_property(c, "position", base + Vector2(amount * k * (1 if i % 2 == 0 else -1), 0), dur / steps)
	tw.tween_property(c, "position", base, dur / steps)

static func fade(c: CanvasItem, to: float, dur := 0.3, delay := 0.0) -> Tween:
	# aynı düğümdeki önceki solma yarıda kalsın (yoksa geç gelen "gizle" yeni gösterimi söndürür)
	var old = c.get_meta("fx_fade") if c.has_meta("fx_fade") else null
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	var tw := c.create_tween()
	c.set_meta("fx_fade", tw)
	tw.tween_property(c, "modulate:a", to, dur).set_delay(delay)
	if to <= 0.0:
		tw.tween_callback(func(): c.visible = false)
	else:
		c.visible = true
	return tw

## Süren bir solmayı iptal et (düğümü hemen yeniden göstermeden önce çağır)
static func cancel_fade(c: CanvasItem) -> void:
	var old = c.get_meta("fx_fade") if c.has_meta("fx_fade") else null
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()

## Kontrolün temel konumunu kaydet (rise/shake buna döner)
static func anchor(c: Control) -> void:
	c.set_meta("fx_base", c.position)

## Kritik sönümlü yay: değeri hedefe yumuşakça yaklaştırır (her karede çağır)
static func damp(cur: float, target: float, rate: float, dt: float) -> float:
	return lerpf(cur, target, 1.0 - exp(-rate * dt))

static func damp2(cur: Vector2, target: Vector2, rate: float, dt: float) -> Vector2:
	return cur.lerp(target, 1.0 - exp(-rate * dt))
