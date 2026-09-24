class_name WardrobePanel
extends GlassPanel
## Kostüm odası: iki sekme.
##   Trivia karakteri  kumaş + şapka / bıyık / papyon
##   Fetih taşı        kumaş + kültür kostümü + kale üslubu
## Seçim değişince sahnedeki pelüş anında giyinir; Fetih sekmesinde yanında kalesi belirir.

signal look_changed(key: String, value: String)
signal tab_changed(conquest: bool)
signal done

var _swatches: Control
var _rows := {}
var _title: KineticText
var _kick: KickerLabel
var _done: CtaButton
var _labels := {}
var _tabs: Segmented
var _trivia_box: VBoxContainer
var _conquest_box: VBoxContainer
var conquest_tab := false

func _ready() -> void:
	size = Vector2(540, 720)
	add_theme_constant_override("margin_left", 36)
	add_theme_constant_override("margin_right", 36)
	add_theme_constant_override("margin_top", 30)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	add_child(v)
	_kick = KickerLabel.new()
	v.add_child(_kick)
	_title = KineticText.new()
	_title.font = Pal.display()
	_title.font_size = 76
	_title.custom_minimum_size = Vector2(460, 82)
	_title.color = Pal.CHAMPAGNE
	v.add_child(_title)
	_tabs = Segmented.new()
	_tabs.custom_minimum_size = Vector2(460, 48)
	_tabs.font_size = 22
	_tabs.selected = 0
	_tabs.changed.connect(func(i): _set_tab(i == 1))
	v.add_child(_tabs)
	_labels["color"] = _small_label(v)
	_swatches = Control.new()
	_swatches.custom_minimum_size = Vector2(460, 64)
	_swatches.mouse_filter = Control.MOUSE_FILTER_STOP
	_swatches.draw.connect(_draw_swatches)
	_swatches.gui_input.connect(_swatch_input)
	v.add_child(_swatches)
	_trivia_box = VBoxContainer.new()
	_trivia_box.add_theme_constant_override("separation", 12)
	v.add_child(_trivia_box)
	_conquest_box = VBoxContainer.new()
	_conquest_box.add_theme_constant_override("separation", 12)
	_conquest_box.visible = false
	v.add_child(_conquest_box)
	for cat in [["hat", PlushVisual.HATS, "look.", _trivia_box], ["mustache", PlushVisual.MUSTACHES, "look.", _trivia_box],
			["bowtie", PlushVisual.BOWTIES, "look.", _trivia_box],
			["culture", CultureCostume.CULTURES, "culture.", _conquest_box], ["castle", CastleModel.STYLES, "castle.", _conquest_box]]:
		var box: VBoxContainer = cat[3]
		_labels[cat[0]] = _small_label(box)
		var row := _Carousel.new()
		row.key = cat[0]
		row.opts = cat[1]
		row.prefix = cat[2]
		row.changed.connect(func(k, val): look_changed.emit(k, val))
		box.add_child(row)
		_rows[cat[0]] = row
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sp)
	_done = CtaButton.new()
	_done.custom_minimum_size = Vector2(460, 70)
	_done.pressed.connect(func(): done.emit())
	v.add_child(_done)
	set_process(true)

func _small_label(v: VBoxContainer) -> KickerLabel:
	var k := KickerLabel.new()
	k.rules = false
	k.font_size = 17
	k.color = Color(Pal.CREAM, 0.7)
	v.add_child(k)
	return k

func _set_tab(conquest: bool) -> void:
	conquest_tab = conquest
	_trivia_box.visible = not conquest
	_conquest_box.visible = conquest
	var box := _conquest_box if conquest else _trivia_box
	box.modulate.a = 0.0
	create_tween().tween_property(box, "modulate:a", 1.0, 0.3)
	tab_changed.emit(conquest)

func retext() -> void:
	_kick.text = Pal.t("wardrobe.kicker")
	_title.text = Pal.upper(Pal.t("wardrobe.title"))
	_tabs.options = [Pal.t("ward.tab_trivia"), Pal.t("ward.tab_conquest")]
	for k in ["color", "hat", "mustache", "bowtie"]:
		_labels[k].text = Pal.t("wardrobe." + k)
	_labels["culture"].text = Pal.t("ward.culture")
	_labels["castle"].text = Pal.t("ward.castle")
	_done.label = Pal.t("common.done")
	refresh()

func refresh() -> void:
	var look := Profile.look()
	for k in _rows:
		_rows[k].set_value(String(look.get(k, "none")))
	_swatches.queue_redraw()

func open() -> void:
	retext()
	_tabs.selected = 0
	_set_tab(false)
	_title.play(0.25)

func _swatch_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var i := int(e.position.x / 57.5)
		if i >= 0 and i < PlushVisual.COLOR_KEYS.size():
			Pal.sfx("click", -4.0, 1.0 + i * 0.05)
			look_changed.emit("color", PlushVisual.COLOR_KEYS[i])
			_swatches.queue_redraw()

func _process(_d: float) -> void:
	if is_visible_in_tree():
		_swatches.queue_redraw()

func _draw_swatches() -> void:
	var cur := String(Profile.look().get("color", "mustard"))
	var m := _swatches.get_local_mouse_position()
	for i in PlushVisual.COLOR_KEYS.size():
		var key: String = PlushVisual.COLOR_KEYS[i]
		var c := Vector2(26 + i * 57.5, 32)
		var col: Color = PlushVisual.COLORS[key]
		var hov := m.distance_to(c) < 26
		var rad := 21.0 + (3.0 if hov else 0.0)
		_swatches.draw_circle(c + Vector2(0, 3), rad, Color(0, 0, 0, 0.45))
		_swatches.draw_circle(c, rad, col)
		# keçe dokusu: ince noktalar
		for k in 7:
			var a := k * 2.1 + i
			_swatches.draw_circle(c + Vector2(cos(a), sin(a)) * rad * 0.55, 1.6, col.darkened(0.12))
		_swatches.draw_circle(c + Vector2(-rad * 0.3, -rad * 0.35), rad * 0.3, Color(1, 1, 1, 0.18))
		if key == cur:
			_swatches.draw_arc(c, rad + 6, 0, TAU, 40, Pal.GOLD, 2.5, true)
			Icons.draw(_swatches, "check", c, 18, Pal.INK if col.get_luminance() > 0.45 else Pal.CHAMPAGNE, 3.0)

class _Carousel extends HBoxContainer:
	signal changed(key: String, value: String)
	var key := ""
	var prefix := "look."
	var opts: Array = []
	var cur := 0
	var _name: Control
	var _slide := 0.0
	var _dir := 1
	func _ready() -> void:
		add_theme_constant_override("separation", 10)
		var l := IconButton.new()
		l.icon_name = "arrow_l"
		l.pressed.connect(func(): _step(-1))
		add_child(l)
		_name = Control.new()
		_name.custom_minimum_size = Vector2(332, 54)
		_name.clip_contents = true
		_name.draw.connect(_draw_name)
		add_child(_name)
		var r := IconButton.new()
		r.icon_name = "arrow_r"
		r.pressed.connect(func(): _step(1))
		add_child(r)
	func set_value(v: String) -> void:
		cur = maxi(0, opts.find(v))
		_name.queue_redraw()
	func _step(d: int) -> void:
		cur = (cur + d + opts.size()) % opts.size()
		_dir = d
		_slide = 1.0
		changed.emit(key, opts[cur])
		set_process(true)
	func _process(delta: float) -> void:
		_slide = maxf(0.0, _slide - delta * 5.0)
		_name.queue_redraw()
		if _slide <= 0.0:
			set_process(false)
	func _draw_name() -> void:
		var f := Pal.display()
		var s := Pal.upper(Pal.t(prefix + String(opts[cur])))
		var fs := 38
		while fs > 22 and f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > _name.size.x - 10:
			fs -= 2
		var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var e := _slide * _slide
		var x := (_name.size.x - w) * 0.5 + e * 60.0 * _dir
		_name.draw_string(f, Vector2(x, 40), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Pal.CHAMPAGNE, 1.0 - e))
		var n := opts.size()
		var dx := 12.0
		var x0 := _name.size.x * 0.5 - (n - 1) * dx * 0.5
		for i in n:
			_name.draw_circle(Vector2(x0 + i * dx, 50), 2.5 if i != cur else 3.5, Pal.GOLD if i == cur else Color(Pal.CREAM, 0.3))
