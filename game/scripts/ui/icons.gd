@tool
class_name Icons
extends RefCounted
## Kodla çizilen simgeler (yazı tipinde olmayan işaretler yerine).
## Kullanım: Icons.draw(self, "heart", merkez, boyut, renk)
## Yeni simge eklemek için aşağıdaki match'e bir dal ekle.

static func draw(ci: CanvasItem, name: String, c: Vector2, s: float, col: Color, w := -1.0) -> void:
	var lw := w if w > 0.0 else maxf(1.5, s * 0.11)
	match name:
		"heart":
			var pts := PackedVector2Array()
			for i in 40:
				var t := TAU * i / 40.0
				var x := 16.0 * pow(sin(t), 3)
				var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
				pts.append(c + Vector2(x, y + 1.0) * (s / 34.0))
			ci.draw_colored_polygon(pts, col)
		"skull":
			ci.draw_circle(c + Vector2(0, -s * 0.08), s * 0.4, col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.22, s * 0.12), Vector2(s * 0.44, s * 0.3)), col)
			var eye := Color(0, 0, 0, 0.85)
			ci.draw_circle(c + Vector2(-s * 0.15, -s * 0.06), s * 0.1, eye)
			ci.draw_circle(c + Vector2(s * 0.15, -s * 0.06), s * 0.1, eye)
			for k: float in [-1.0, 0.0, 1.0]:
				ci.draw_line(c + Vector2(k * s * 0.1, s * 0.22), c + Vector2(k * s * 0.1, s * 0.42), eye, maxf(1.0, s * 0.05))
		"crown":
			var h := s * 0.5
			var pts := PackedVector2Array([c + Vector2(-s * 0.46, h * 0.6), c + Vector2(-s * 0.5, -h * 0.55), c + Vector2(-s * 0.22, -h * 0.05),
				c + Vector2(0, -h * 0.85), c + Vector2(s * 0.22, -h * 0.05), c + Vector2(s * 0.5, -h * 0.55), c + Vector2(s * 0.46, h * 0.6)])
			ci.draw_colored_polygon(pts, col)
			for p in [Vector2(-s * 0.5, -h * 0.55), Vector2(0, -h * 0.85), Vector2(s * 0.5, -h * 0.55)]:
				ci.draw_circle(c + p, s * 0.07, col)
		"flame":
			for layer in 2:
				var k := 1.0 if layer == 0 else 0.55
				var pts := PackedVector2Array()
				for i in 36:
					var t := TAU * i / 36.0
					pts.append(c + Vector2(s * 0.36 * k * sin(t) * pow(sin(t * 0.5), 1.4), -s * 0.5 * k * cos(t) + s * 0.5 * (1.0 - k) * 0.6))
				ci.draw_colored_polygon(pts, col if layer == 0 else Color(1, 0.95, 0.75, col.a))
		"bolt":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.1, -s * 0.5), c + Vector2(-s * 0.3, s * 0.08), c + Vector2(-s * 0.02, s * 0.08),
				c + Vector2(-s * 0.12, s * 0.5), c + Vector2(s * 0.3, -s * 0.1), c + Vector2(s * 0.02, -s * 0.1)]), col)
		"check":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.36, 0), c + Vector2(-s * 0.1, s * 0.26), c + Vector2(s * 0.38, -s * 0.3)]), col, lw * 1.4, true)
		"cross":
			ci.draw_line(c + Vector2(-s * 0.3, -s * 0.3), c + Vector2(s * 0.3, s * 0.3), col, lw * 1.4, true)
			ci.draw_line(c + Vector2(s * 0.3, -s * 0.3), c + Vector2(-s * 0.3, s * 0.3), col, lw * 1.4, true)
		"star":
			var pts := PackedVector2Array()
			for i in 10:
				var r := s * (0.5 if i % 2 == 0 else 0.21)
				var a := -PI / 2 + TAU * i / 10.0
				pts.append(c + Vector2(cos(a), sin(a)) * r)
			ci.draw_colored_polygon(pts, col)
		"diamond":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.5), c + Vector2(s * 0.5, 0), c + Vector2(0, s * 0.5), c + Vector2(-s * 0.5, 0)]), col)
		"coins", "siphon":
			for k in 3:
				var o := c + Vector2(-s * 0.12 + k * s * 0.02, s * 0.28 - k * s * 0.2)
				_ellipse(ci, o, Vector2(s * 0.34, s * 0.12), col.darkened(0.25))
				_ellipse(ci, o - Vector2(0, s * 0.05), Vector2(s * 0.34, s * 0.12), col)
			ci.draw_line(c + Vector2(s * 0.28, -s * 0.46), c + Vector2(s * 0.46, -s * 0.28), col, lw)
			ci.draw_line(c + Vector2(s * 0.46, -s * 0.46), c + Vector2(s * 0.46, -s * 0.28), col, lw)
			ci.draw_line(c + Vector2(s * 0.28, -s * 0.28), c + Vector2(s * 0.46, -s * 0.28), col, lw)
		"lead":
			# kurşun ayakkabı: kalın bot + ağırlık
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.3, -s * 0.42), c + Vector2(s * 0.02, -s * 0.42), c + Vector2(s * 0.02, s * 0.05),
				c + Vector2(s * 0.44, s * 0.12), c + Vector2(s * 0.46, s * 0.34), c + Vector2(-s * 0.3, s * 0.34)]), col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.34, s * 0.34), Vector2(s * 0.84, s * 0.12)), col.darkened(0.3))
		"invert":
			for k: float in [-1.0, 1.0]:
				var y := k * s * 0.18
				ci.draw_line(c + Vector2(-s * 0.4, y), c + Vector2(s * 0.4, y), col, lw)
				var tip := c + Vector2(s * 0.42 * k, y)
				ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(k * s * 0.08, 0), tip + Vector2(-k * s * 0.14, -s * 0.13), tip + Vector2(-k * s * 0.14, s * 0.13)]), col)
		"ice":
			for i in 3:
				var a := PI * i / 3.0
				var d := Vector2(cos(a), sin(a)) * s * 0.46
				ci.draw_line(c - d, c + d, col, lw)
				for sgn in [-1.0, 1.0]:
					var p: Vector2 = c + d * 0.55 * sgn
					var n := d.normalized().orthogonal() * s * 0.12
					ci.draw_line(p, p + d.normalized() * s * 0.12 * sgn + n, col, lw * 0.8)
					ci.draw_line(p, p + d.normalized() * s * 0.12 * sgn - n, col, lw * 0.8)
		"bighead":
			ci.draw_circle(c + Vector2(0, -s * 0.1), s * 0.36, col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.1, s * 0.24), Vector2(s * 0.2, s * 0.24)), col)
			var e := Color(0, 0, 0, 0.8)
			ci.draw_circle(c + Vector2(-s * 0.12, -s * 0.12), s * 0.05, e)
			ci.draw_circle(c + Vector2(s * 0.12, -s * 0.12), s * 0.05, e)
		"clock":
			ci.draw_arc(c, s * 0.42, 0, TAU, 32, col, lw, true)
			ci.draw_line(c, c + Vector2(0, -s * 0.28), col, lw)
			ci.draw_line(c, c + Vector2(s * 0.2, 0), col, lw)
		"phone":
			var r := Rect2(c - Vector2(s * 0.24, s * 0.44), Vector2(s * 0.48, s * 0.88))
			ci.draw_rect(r, col, false, lw)
			ci.draw_circle(c + Vector2(0, s * 0.32), s * 0.05, col)
		"rose":
			ci.draw_line(c + Vector2(0, 0), c + Vector2(s * 0.05, s * 0.5), Color("5FA35A"), lw)
			for i in 5:
				var a := TAU * i / 5.0
				ci.draw_circle(c + Vector2(cos(a), sin(a)) * s * 0.14 + Vector2(0, -s * 0.12), s * 0.18, col.darkened(0.1 * (i % 2)))
			ci.draw_circle(c + Vector2(0, -s * 0.12), s * 0.12, col.lightened(0.15))
		"tomato":
			ci.draw_circle(c + Vector2(0, s * 0.06), s * 0.4, col)
			for i in 5:
				var a := -PI / 2 + TAU * i / 5.0
				ci.draw_line(c + Vector2(0, -s * 0.3), c + Vector2(0, -s * 0.3) + Vector2(cos(a), sin(a) * 0.5) * s * 0.2, Color("4E9A45"), lw)
		"hat":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.25, -s * 0.45), Vector2(s * 0.5, s * 0.6)), col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.45, s * 0.12), Vector2(s * 0.9, s * 0.12)), col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.25, s * 0.0), Vector2(s * 0.5, s * 0.08)), Pal.VELVET_HI)
		"arrow_l", "arrow_r":
			var k := -1.0 if name == "arrow_l" else 1.0
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.15 * k, -s * 0.3), c + Vector2(s * 0.15 * k, 0), c + Vector2(-s * 0.15 * k, s * 0.3)]), col, lw * 1.3, true)
		"plus", "minus":
			ci.draw_line(c + Vector2(-s * 0.3, 0), c + Vector2(s * 0.3, 0), col, lw * 1.3)
			if name == "plus":
				ci.draw_line(c + Vector2(0, -s * 0.3), c + Vector2(0, s * 0.3), col, lw * 1.3)
		"mask":
			_ellipse(ci, c, Vector2(s * 0.42, s * 0.3), col)
			var e := Color(0, 0, 0, 0.75)
			_ellipse(ci, c + Vector2(-s * 0.17, -s * 0.03), Vector2(s * 0.11, s * 0.07), e)
			_ellipse(ci, c + Vector2(s * 0.17, -s * 0.03), Vector2(s * 0.11, s * 0.07), e)
		"masks":
			# komedi (önde, gülen) ve trajedi (arkada, eğik, ağlayan)
			var back := c + Vector2(s * 0.14, -s * 0.08)
			_mask(ci, back, s * 0.62, col.darkened(0.35), false, 0.3)
			_mask(ci, c + Vector2(-s * 0.1, s * 0.06), s * 0.62, col, true, -0.2)
		"swords":
			for k: float in [-1.0, 1.0]:
				var a := c + Vector2(-s * 0.36 * k, s * 0.36)
				var b := c + Vector2(s * 0.34 * k, -s * 0.34)
				ci.draw_line(a, b, col, lw * 1.1, true)
				# kabza ve siper
				var d := (b - a).normalized()
				var n := Vector2(-d.y, d.x)
				var g := a + d * s * 0.16
				ci.draw_line(g - n * s * 0.13, g + n * s * 0.13, col, lw * 1.3, true)
				ci.draw_circle(a - d * s * 0.03, s * 0.055, col)
		"hanger":
			ci.draw_arc(c + Vector2(0, -s * 0.3), s * 0.09, PI * 0.9, PI * 2.4, 12, col, lw, true)
			ci.draw_polyline(PackedVector2Array([c + Vector2(0, -s * 0.2), c + Vector2(-s * 0.44, s * 0.18), c + Vector2(s * 0.44, s * 0.18), c + Vector2(0, -s * 0.2)]), col, lw, true)
		"opera":
			for k: float in [-1.0, 1.0]:
				ci.draw_circle(c + Vector2(s * 0.2 * k, s * 0.08), s * 0.17, col)
				ci.draw_circle(c + Vector2(s * 0.2 * k, s * 0.08), s * 0.09, Color(0, 0, 0, 0.55))
			ci.draw_rect(Rect2(c + Vector2(-s * 0.08, -s * 0.02), Vector2(s * 0.16, s * 0.09)), col)
			ci.draw_line(c + Vector2(s * 0.3, -s * 0.02), c + Vector2(s * 0.46, -s * 0.42), col, lw, true)
		"scroll":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.28, -s * 0.32), Vector2(s * 0.56, s * 0.64)), col, false, lw)
			for k: float in [-1.0, 1.0]:
				_ellipse(ci, c + Vector2(0, s * 0.36 * k), Vector2(s * 0.36, s * 0.07), col)
			for i in 3:
				ci.draw_line(c + Vector2(-s * 0.16, -s * 0.14 + i * s * 0.13), c + Vector2(s * 0.16, -s * 0.14 + i * s * 0.13), col, maxf(1.0, lw * 0.6))
		"gear":
			var pts := PackedVector2Array()
			for i in 48:
				var a := TAU * i / 48.0
				var r := s * (0.44 if (i / 3) % 2 == 0 else 0.34)
				pts.append(c + Vector2(cos(a), sin(a)) * r)
			ci.draw_colored_polygon(pts, col)
			ci.draw_circle(c, s * 0.15, Color(0, 0, 0, 0.6))
		"castle":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.4, -s * 0.05), Vector2(s * 0.8, s * 0.45)), col)
			for i in 3:
				var x := -s * 0.4 + i * s * 0.3
				ci.draw_rect(Rect2(c + Vector2(x, -s * 0.38), Vector2(s * 0.2, s * 0.36)), col)
				ci.draw_rect(Rect2(c + Vector2(x, -s * 0.46), Vector2(s * 0.07, s * 0.1)), col)
				ci.draw_rect(Rect2(c + Vector2(x + s * 0.13, -s * 0.46), Vector2(s * 0.07, s * 0.1)), col)
			_ellipse(ci, c + Vector2(0, s * 0.3), Vector2(s * 0.09, s * 0.12), Color(0, 0, 0, 0.6))
		"door":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.26, -s * 0.42), Vector2(s * 0.52, s * 0.84)), col, false, lw)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.26, -s * 0.42), c + Vector2(s * 0.12, -s * 0.3), c + Vector2(s * 0.12, s * 0.5), c + Vector2(-s * 0.26, s * 0.42)]), col)
			ci.draw_circle(c + Vector2(s * 0.03, s * 0.05), s * 0.05, Color(0, 0, 0, 0.7))
		"flag":
			ci.draw_line(c + Vector2(-s * 0.3, s * 0.45), c + Vector2(-s * 0.3, -s * 0.45), col, lw, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.3, -s * 0.45), c + Vector2(s * 0.4, -s * 0.3), c + Vector2(-s * 0.3, -s * 0.05)]), col)
		_:
			ci.draw_circle(c, s * 0.3, col)

static func _mask(ci: CanvasItem, c: Vector2, s: float, col: Color, happy: bool, tilt: float) -> void:
	var pts := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		var r := Vector2(s * 0.42, s * 0.5)
		var p := Vector2(cos(a) * r.x * (1.0 - 0.18 * maxf(0.0, sin(a))), sin(a) * r.y)
		pts.append(c + p.rotated(tilt))
	ci.draw_colored_polygon(pts, col)
	var e := Color(0, 0, 0, 0.8)
	for k: float in [-1.0, 1.0]:
		var ec := c + Vector2(s * 0.16 * k, -s * 0.1).rotated(tilt)
		_ellipse(ci, ec, Vector2(s * 0.1, s * (0.05 if happy else 0.07)), e)
	var m := PackedVector2Array()
	for i in 9:
		var t := float(i) / 8.0
		var x := lerpf(-s * 0.18, s * 0.18, t)
		var y := s * 0.2 + (s * 0.1 if happy else -s * 0.08) * sin(t * PI)
		m.append(c + Vector2(x, y).rotated(tilt))
	ci.draw_polyline(m, e, maxf(1.5, s * 0.07), true)

static func _ellipse(ci: CanvasItem, c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	ci.draw_colored_polygon(pts, col)

## Sanat deko köşe kesikli dikdörtgen (paneller, kartlar)
static func notched(r: Rect2, cut: float) -> PackedVector2Array:
	var p := r.position
	var s := r.size
	return PackedVector2Array([p + Vector2(cut, 0), p + Vector2(s.x - cut, 0), p + Vector2(s.x, cut), p + Vector2(s.x, s.y - cut),
		p + Vector2(s.x - cut, s.y), p + Vector2(cut, s.y), p + Vector2(0, s.y - cut), p + Vector2(0, cut)])

static func outline(ci: CanvasItem, pts: PackedVector2Array, col: Color, w := 1.0) -> void:
	var loop := pts.duplicate()
	loop.append(pts[0])
	ci.draw_polyline(loop, col, w, true)
