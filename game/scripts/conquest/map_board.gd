class_name MapBoard
extends Node3D
## Conquest haritası: sahneye serilen, keçeden kesilip dikilmiş bir Türkiye.
##
## Her bölge ayrı bir keçe parçası: kalınlığı var, kenarı bir ton koyu,
## üst yüzünde iplik dikişi. Sahibi olunca parça o oyuncunun rengine boyanır.
## Çevresi mavi saten deniz; önünde ve arkasında eski tiyatroların "dalga
## makinesi" gibi sallanan boyalı dalga kesikleri.
##
## Veri: res://data/maps/turkiye.json (web sürümündeki 15 bölge, gerçek il sınırları).

signal region_clicked(id: String)
signal region_hovered(id: String)

const WIDTH := 13.4          ## haritanın sahnedeki genişliği (m)
const CENTER_Z := -1.55      ## haritanın merkezinin sahnedeki z'si
const H := 0.16              ## keçe parçasının kalınlığı
const GAP := 0.028           ## bölgeler arası dikiş boşluğu
const RIM := 0.075           ## kenardaki koyu şerit genişliği
const NEUTRAL := [Color("E9DCC0"), Color("E3D2B0"), Color("EEE3CA"), Color("DDCDA9")]

var data := {}
var S := 0.01
var regions := {}            # id -> Dictionary (aşağıya bak)
var order: Array[String] = []
var sea_mat: ShaderMaterial
var _t := 0.0
var _waves: Array[Node3D] = []
var hover_id := ""

## Bölge sözlüğü:
##   id, name_tr, name_en, adj, seat (Vector3), polys (Array[PackedVector2Array], dünya x/z),
##   node (Node3D, yükselen parça), top_mat, rim_mat, base_col, label (Label3D),
##   owner_col (Color / null), rich (bool), lift, lift_target, glow, glow_target, piece (Node3D)

func load_map(path := "res://data/maps/turkiye.json") -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	data = JSON.parse_string(f.get_as_text())
	S = WIDTH / float(data.cols)

func to_world(mx: float, my: float) -> Vector3:
	return Vector3((mx - data.cols * 0.5) * S, 0.0, CENTER_Z + (my - data.rows * 0.5) * S)

func _pts(flat: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(0, flat.size() - 1, 2):
		var w := to_world(float(flat[i]), float(flat[i + 1]))
		out.append(Vector2(w.x, w.z))
	return out

# ── kurulum ─────────────────────────────────────────────────────────
func build() -> void:
	if data.is_empty():
		load_map()
	for c in get_children():
		c.queue_free()
	regions.clear()
	order.clear()
	_build_sea()
	_build_waves()
	var i := 0
	for r in data.regions:
		_build_region(r, NEUTRAL[i % NEUTRAL.size()])
		i += 1
	for link in data.get("links", []):
		var a: Dictionary = regions.get(link[0], {})
		var b: Dictionary = regions.get(link[1], {})
		if not a.is_empty() and not b.is_empty():
			if not a.adj.has(link[1]):
				a.adj.append(link[1])
			if not b.adj.has(link[0]):
				b.adj.append(link[0])
	_build_compass()

func _felt(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	m.normal_enabled = true
	m.normal_texture = PlushVisual.felt_normal()
	m.normal_scale = 0.55
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(2.2, 2.2, 2.2)
	m.emission_enabled = true
	m.emission = Color("FFD86B")
	m.emission_energy_multiplier = 0.0
	return m

func _build_region(r: Dictionary, col: Color) -> void:
	var id: String = r.id
	var node := Node3D.new()
	node.name = "R_" + id
	add_child(node)
	var top_mat := _felt(col)
	var rim_mat := _felt(col.darkened(0.22))
	var polys: Array[PackedVector2Array] = []
	var st_rim := SurfaceTool.new()
	st_rim.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_top := SurfaceTool.new()
	st_top.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stitches: Array[PackedVector2Array] = []
	for loop in r.loops:
		var raw := _pts(loop)
		if raw.size() < 3:
			continue
		for outer in Geometry2D.offset_polygon(raw, -GAP, Geometry2D.JOIN_ROUND):
			if outer.size() < 3:
				continue
			polys.append(outer)
			_add_walls(st_rim, outer)
			_add_cap(st_rim, outer, H)
			var inner_list := Geometry2D.offset_polygon(outer, -RIM, Geometry2D.JOIN_ROUND)
			for inner in inner_list:
				if inner.size() >= 3:
					_add_cap(st_top, inner, H + 0.004)
					stitches.append(inner)
	st_rim.generate_tangents()
	var rim_mi := MeshInstance3D.new()
	rim_mi.mesh = st_rim.commit()
	rim_mi.material_override = rim_mat
	node.add_child(rim_mi)
	var top_mi := MeshInstance3D.new()
	top_mi.mesh = st_top.commit()
	top_mi.material_override = top_mat
	node.add_child(top_mi)
	# iplik dikişi: iç kenarın biraz içinden kesikli çizgi
	var stitch_mi := MeshInstance3D.new()
	stitch_mi.mesh = _stitch_mesh(stitches)
	stitch_mi.material_override = PlushVisual.mat("map_thread", Color("FFF4DC"), 0.9)
	node.add_child(stitch_mi)
	# il sınırları: bölge içindeki ince, koyu iplik
	var lines_mi := MeshInstance3D.new()
	lines_mi.mesh = _lines_mesh(r.get("lines", []))
	lines_mi.material_override = PlushVisual.mat("map_lines", Color(0.25, 0.14, 0.08), 1.0)
	node.add_child(lines_mi)
	var seat := to_world(float(r.cx), float(r.cy))
	var lab := Label3D.new()
	lab.font = Pal.italic_black()
	lab.font_size = 64
	lab.pixel_size = 0.0034
	lab.text = String(r.tr)
	lab.modulate = Color("3A1C10")
	lab.outline_size = 10
	lab.outline_modulate = Color(1, 0.96, 0.86, 0.85)
	lab.rotation = Vector3(-PI / 2, 0, 0)
	lab.position = Vector3(seat.x, H + 0.012, seat.z + 0.42)
	lab.double_sided = false
	node.add_child(lab)
	regions[id] = {
		"id": id, "name_tr": r.tr, "name_en": r.en, "adj": (r.adj as Array).duplicate(),
		"seat": Vector3(seat.x, H, seat.z), "polys": polys, "node": node, "top_mat": top_mat, "rim_mat": rim_mat,
		"base_col": col, "label": lab, "owner_col": null, "rich": false,
		"lift": 0.0, "lift_target": 0.0, "glow": 0.0, "glow_target": 0.0, "piece": null, "badge": null,
	}
	order.append(id)

## Üçgeni istenen normale bakacak sırayla ekler (Godot'da ön yüz saat yönünde).
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b
		b = c
		c = t
	for v in [a, b, c]:
		st.set_normal(n)
		st.add_vertex(v)

## Çokgenin dış duvarları; normal, çokgenin merkezinden dışarı bakacak şekilde seçilir
func _add_walls(st: SurfaceTool, poly: PackedVector2Array) -> void:
	var n := poly.size()
	var cw := Geometry2D.is_polygon_clockwise(poly)
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		var d := (b - a).normalized()
		var out2 := Vector2(d.y, -d.x) if not cw else Vector2(-d.y, d.x)
		var nrm := Vector3(out2.x, 0, out2.y)
		var v0 := Vector3(a.x, 0, a.y)
		var v1 := Vector3(b.x, 0, b.y)
		var v2 := Vector3(b.x, H, b.y)
		var v3 := Vector3(a.x, H, a.y)
		_tri(st, v0, v1, v2, nrm)
		_tri(st, v0, v2, v3, nrm)

func _add_cap(st: SurfaceTool, poly: PackedVector2Array, y: float) -> void:
	var tri := Geometry2D.triangulate_polygon(poly)
	if tri.is_empty():
		return
	for i in range(0, tri.size(), 3):
		var p0 := poly[tri[i]]
		var p1 := poly[tri[i + 1]]
		var p2 := poly[tri[i + 2]]
		_tri(st, Vector3(p0.x, y, p0.y), Vector3(p1.x, y, p1.y), Vector3(p2.x, y, p2.y), Vector3.UP)

func _stitch_mesh(loops: Array[PackedVector2Array]) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dash := 0.07
	var gapl := 0.05
	var w := 0.011
	for loop in loops:
		for inset in Geometry2D.offset_polygon(loop, -0.05, Geometry2D.JOIN_ROUND):
			var n := inset.size()
			var carry := 0.0
			for i in n:
				var a := inset[i]
				var b := inset[(i + 1) % n]
				var L := a.distance_to(b)
				var dir := (b - a) / maxf(L, 0.0001)
				var s := -carry
				while s < L:
					var s0 := maxf(s, 0.0)
					var s1 := minf(s + dash, L)
					if s1 > s0:
						_quad_line(st, a + dir * s0, a + dir * s1, w, H + 0.008)
					s += dash + gapl
				carry = s - L
	return st.commit()

func _lines_mesh(lines: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for l in lines:
		var p := _pts(l)
		for i in range(p.size() - 1):
			_quad_line(st, p[i], p[i + 1], 0.009, H + 0.007)
	return st.commit()

func _quad_line(st: SurfaceTool, a: Vector2, b: Vector2, w: float, y: float) -> void:
	var d := (b - a)
	if d.length() < 0.0001:
		return
	var nrm := Vector2(-d.y, d.x).normalized() * w * 0.5
	var v0 := Vector3(a.x + nrm.x, y, a.y + nrm.y)
	var v1 := Vector3(b.x + nrm.x, y, b.y + nrm.y)
	var v2 := Vector3(b.x - nrm.x, y, b.y - nrm.y)
	var v3 := Vector3(a.x - nrm.x, y, a.y - nrm.y)
	_tri(st, v0, v1, v2, Vector3.UP)
	_tri(st, v0, v2, v3, Vector3.UP)

# ── deniz ve dalga makinesi ─────────────────────────────────────────
func _build_sea() -> void:
	var sea := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(15.6, 7.9)
	pm.subdivide_width = 1
	pm.subdivide_depth = 1
	sea.mesh = pm
	sea.position = Vector3(0, 0.012, CENTER_Z - 0.1)
	sea_mat = ShaderMaterial.new()
	sea_mat.shader = preload("res://ui/shaders/satin_sea.gdshader")
	sea.material_override = sea_mat
	sea.name = "Sea"
	add_child(sea)
	# sığ su halesi: kıyının biraz dışında daha açık mavi bir şerit
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for c in data.coast:
		var raw := _pts(c)
		if raw.size() < 3:
			continue
		for halo in Geometry2D.offset_polygon(raw, 0.16, Geometry2D.JOIN_ROUND):
			_add_cap(st, halo, 0.018)
	var shallow := MeshInstance3D.new()
	shallow.mesh = st.commit()
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color("5FA6BF")
	sm.roughness = 0.35
	sm.metallic_specular = 0.8
	shallow.material_override = sm
	add_child(shallow)

func _build_waves() -> void:
	_waves.clear()
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color("2F6E93")
	paint.roughness = 0.55
	var crest := StandardMaterial3D.new()
	crest.albedo_color = Color("EAF4F7")
	crest.roughness = 0.6
	for row in [[2.35, 0.0, 1.0], [2.6, 0.9, 0.85], [-5.05, 0.4, 1.1]]:
		var z: float = row[0]
		var node := Node3D.new()
		node.position = Vector3(float(row[1]) * 0.3, 0, z)
		node.set_meta("phase", float(row[1]) * 2.0)
		node.set_meta("z", z)
		add_child(node)
		var mi := MeshInstance3D.new()
		mi.mesh = _wave_mesh(16.4, 0.34 * float(row[2]), 0.05, 10)
		mi.material_override = paint
		node.add_child(mi)
		var cm := MeshInstance3D.new()
		cm.mesh = _wave_mesh(16.4, 0.34 * float(row[2]), 0.055, 10, true)
		cm.material_override = crest
		node.add_child(cm)
		_waves.append(node)

## Boyalı tahta dalga kesiği: sinüs sırtları olan ince levha (x ekseni boyunca)
func _wave_mesh(length: float, height: float, depth: float, crests: int, crest_only := false) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := crests * 12
	var pts := PackedVector2Array()
	for i in n + 1:
		var x := -length * 0.5 + length * i / float(n)
		var ph := float(i) / 12.0 * TAU
		var y := height * (0.55 + 0.45 * pow(absf(sin(ph * 0.5)), 1.6))
		pts.append(Vector2(x, y))
	for i in n:
		var a := pts[i]
		var b := pts[i + 1]
		var y0a := 0.0 if not crest_only else a.y - 0.035
		var y0b := 0.0 if not crest_only else b.y - 0.035
		for zz: float in [depth * 0.5, -depth * 0.5]:
			var nz := 1.0 if zz > 0 else -1.0
			var nn := Vector3(0, 0, nz)
			_tri(st, Vector3(a.x, y0a, zz), Vector3(b.x, y0b, zz), Vector3(b.x, b.y, zz), nn)
			_tri(st, Vector3(a.x, y0a, zz), Vector3(b.x, b.y, zz), Vector3(a.x, a.y, zz), nn)
	return st.commit()

func _build_compass() -> void:
	var gold := PlushVisual.mat("gold", Color("D6A93F"), 0.28, 1.0)
	var root := Node3D.new()
	root.position = Vector3(-6.4, 0.03, 1.55)
	add_child(root)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.34
	tm.outer_radius = 0.38
	ring.mesh = tm
	ring.material_override = gold
	root.add_child(ring)
	for i in 4:
		var p := MeshInstance3D.new()
		var pr := PrismMesh.new()
		pr.size = Vector3(0.14, 0.52 if i % 2 == 0 else 0.36, 0.02)
		p.mesh = pr
		p.material_override = gold if i != 0 else PlushVisual.mat("ruby", Color("C2183A"), 0.1)
		p.rotation = Vector3(-PI / 2, 0, -i * PI / 2)
		p.position = Vector3(0, 0.01, 0)
		var off := Vector3(0, 0, -0.2).rotated(Vector3.UP, -i * PI / 2)
		p.position += off
		root.add_child(p)
	var n := Label3D.new()
	n.text = "K" if Pal.tr_lang() else "N"
	n.font = Pal.display()
	n.font_size = 64
	n.pixel_size = 0.004
	n.modulate = Pal.GOLD
	n.rotation = Vector3(-PI / 2, 0, 0)
	n.position = Vector3(0, 0.02, -0.56)
	root.add_child(n)

# ── durum ───────────────────────────────────────────────────────────
func region(id: String) -> Dictionary:
	return regions.get(id, {})

func region_name(id: String) -> String:
	var r := region(id)
	if r.is_empty():
		return id
	return String(r.name_en if not Pal.tr_lang() else r.name_tr)

func seat(id: String) -> Vector3:
	var r := region(id)
	return (r.seat as Vector3) + Vector3(0, r.lift, 0) if not r.is_empty() else Vector3.ZERO

## Bölgeyi bir oyuncunun rengine boya (null: sahipsiz keçe)
func set_owner_color(id: String, col) -> void:
	var r := region(id)
	if r.is_empty():
		return
	r.owner_col = col
	var target: Color = r.base_col if col == null else (col as Color).lerp(Color.WHITE, 0.08)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(r.top_mat, "albedo_color", target, 0.5)
	tw.tween_property(r.rim_mat, "albedo_color", target.darkened(0.3), 0.5)
	r.label.modulate = Color("3A1C10") if target.get_luminance() > 0.45 else Color("FFF4DC")
	r.label.outline_modulate = Color(1, 0.96, 0.86, 0.85) if target.get_luminance() > 0.45 else Color(0.1, 0.04, 0.03, 0.85)
	flash(id)

func set_rich(id: String, on: bool) -> void:
	var r := region(id)
	if r.is_empty():
		return
	r.rich = on
	if on and r.badge == null:
		var b := Node3D.new()
		b.position = r.seat + Vector3(0.62, 0.3, -0.2)
		var coin := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.17
		cm.bottom_radius = 0.17
		cm.height = 0.04
		coin.mesh = cm
		coin.rotation.x = PI / 2
		coin.material_override = PlushVisual.mat("coin", Color("E8B93C"), 0.25, 1.0)
		b.add_child(coin)
		for side: float in [1.0, -1.0]:
			var l := Label3D.new()
			l.text = "2×"
			l.font = Pal.display()
			l.font_size = 72
			l.pixel_size = 0.003
			l.modulate = Color("5A3A08")
			l.outline_size = 0
			l.position = Vector3(0, 0.0, 0.025 * side)
			l.rotation.y = 0.0 if side > 0 else PI
			b.add_child(l)
		r.node.add_child(b)
		r.badge = b

func flash(id: String) -> void:
	var r := region(id)
	if not r.is_empty():
		r.glow = 1.4

## Seçilebilirlik: "none" | "pickable" | "cursor"
func set_mark(id: String, mark: String) -> void:
	var r := region(id)
	if r.is_empty():
		return
	match mark:
		"cursor":
			r.lift_target = 0.16
			r.glow_target = 0.9
		"pickable":
			r.lift_target = 0.05
			r.glow_target = 0.35
		_:
			r.lift_target = 0.0
			r.glow_target = 0.0

func clear_marks() -> void:
	for id in regions:
		set_mark(id, "none")

func region_at(p: Vector3) -> String:
	var q := Vector2(p.x, p.z)
	for id in order:
		for poly in regions[id].polys:
			if Geometry2D.is_point_in_polygon(q, poly):
				return id
	return ""

## Fare: kameradan ışın, harita düzlemiyle kesişim
func region_under_mouse(cam: Camera3D, screen_pos: Vector2) -> String:
	if cam == null:
		return ""
	var from := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return ""
	var t := (H - from.y) / dir.y
	if t < 0:
		return ""
	return region_at(from + dir * t)

## Yönle gezinme: şimdiki bölgeden verilen yöne en uygun aday
func step_towards(current: String, dir2: Vector2, candidates: Array) -> String:
	if candidates.is_empty():
		return current
	if current == "" or not candidates.has(current):
		return candidates[0]
	var from: Vector3 = regions[current].seat
	var want := Vector3(dir2.x, 0, dir2.y).normalized()
	var best := current
	var best_score := INF
	for id in candidates:
		if id == current:
			continue
		var d: Vector3 = regions[id].seat - from
		var dist := d.length()
		var cosang := d.normalized().dot(want)
		if cosang < 0.35:
			continue
		var score := dist * (2.0 - cosang)
		if score < best_score:
			best_score = score
			best = id
	return best

# ── taşlar ──────────────────────────────────────────────────────────
func set_piece(id: String, piece: Node3D) -> void:
	var r := region(id)
	if r.is_empty():
		return
	if r.piece and is_instance_valid(r.piece):
		var old: Node3D = r.piece
		var tw := old.create_tween()
		tw.tween_property(old, "scale", Vector3(0.01, 0.01, 0.01), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_callback(old.queue_free)
	r.piece = piece
	if piece:
		r.node.add_child(piece)
		piece.position = r.seat + Vector3(0, 0.0, -0.05)
		piece.scale = Vector3(0.01, 0.01, 0.01)
		var s: Vector3 = piece.get_meta("base_scale", Vector3.ONE)
		var tw2 := piece.create_tween()
		tw2.tween_property(piece, "scale", s, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func piece(id: String) -> Node3D:
	var r := region(id)
	return r.piece if not r.is_empty() else null

# ── canlılık ────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	_t += delta
	var pulse := 0.6 + 0.4 * sin(_t * 4.0)
	for id in order:
		var r: Dictionary = regions[id]
		r.lift = Fx.damp(r.lift, r.lift_target, 10.0, delta)
		r.glow = Fx.damp(r.glow, r.glow_target, 6.0, delta)
		r.node.position.y = r.lift
		var e: float = r.glow * (pulse if r.glow_target > 0.0 and r.glow_target < 0.8 else 1.0)
		(r.top_mat as StandardMaterial3D).emission_energy_multiplier = e * 0.55
		if r.badge:
			r.badge.rotation.y += delta * 1.6
			r.badge.position.y = r.seat.y + 0.32 + sin(_t * 2.0) * 0.03
	for w in _waves:
		var ph: float = w.get_meta("phase")
		w.position.x = sin(_t * 0.6 + ph) * 0.35
		w.position.y = sin(_t * 1.3 + ph) * 0.03
		w.position.z = float(w.get_meta("z")) + sin(_t * 0.9 + ph) * 0.03
