class_name WardrobePanel
extends GlassPanel
## Kostüm odası: iki sekme.
##   Trivia karakteri  kumaş + şapka / bıyık / papyon
##   Fetih taşı        kumaş + kültür kostümü + kale üslubu
## Seçim değişince sahnedeki pelüş anında giyinir; Fetih sekmesinde yanında kalesi belirir.

signal look_changed(key: String, value: String)
signal tab_changed(conquest: bool)
signal done
signal preview(key: String, value: String)
signal bought

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
var _rank: Control
var _hint := ""
var _hint_t := 0.0
var _buy: CtaButton
var _pending := []          # [kategori, öğe]: denenen kilitli öğe

func _ready() -> void:
	size = Vector2(540, 960)
	add_theme_constant_override("margin_left", 36)
	add_theme_constant_override("margin_right", 36)
	add_theme_constant_override("margin_top", 30)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 9)
	add_child(v)
	_kick = KickerLabel.new()
	v.add_child(_kick)
	_title = KineticText.new()
	_title.font = Pal.display()
	_title.font_size = 62
	_title.custom_minimum_size = Vector2(460, 66)
	_title.color = Pal.CHAMPAGNE
	v.add_child(_title)
	_tabs = Segmented.new()
	_tabs.custom_minimum_size = Vector2(460, 48)
	_tabs.font_size = 22
	_tabs.selected = 0
	_tabs.changed.connect(func(i): _set_tab(i == 1))
	v.add_child(_tabs)
	_rank = Control.new()
	_rank.custom_minimum_size = Vector2(460, 30)
	_rank.draw.connect(_draw_rank)
	v.add_child(_rank)
	_labels["color"] = _small_label(v)
	_swatches = Control.new()
	_swatches.custom_minimum_size = Vector2(460, 112)
	_swatches.mouse_filter = Control.MOUSE_FILTER_STOP
	_swatches.draw.connect(_draw_swatches)
	_swatches.gui_input.connect(_swatch_input)
	v.add_child(_swatches)
	_trivia_box = VBoxContainer.new()
	_trivia_box.add_theme_constant_override("separation", 6)
	v.add_child(_trivia_box)
	_conquest_box = VBoxContainer.new()
	_conquest_box.add_theme_constant_override("separation", 6)
	_conquest_box.visible = false
	v.add_child(_conquest_box)
	for cat in [["hat", PlushVisual.HATS, "look.", _trivia_box], ["mustache", PlushVisual.MUSTACHES, "look.", _trivia_box],
			["bowtie", PlushVisual.BOWTIES, "look.", _trivia_box], ["glasses", PlushVisual.GLASSES, "look.", _trivia_box],
		["necklace", PlushVisual.NECKLACES, "look.", _trivia_box], ["outfit", PlushVisual.OUTFITS, "look.", _trivia_box],
			["culture", CultureCostume.CULTURES, "culture.", _conquest_box], ["castle", CastleModel.STYLES, "castle.", _conquest_box],
			["banner", CastleModel.BANNERS, "banner.", _conquest_box]]:
		var box: VBoxContainer = cat[3]
		var row := _Carousel.new()
		row.key = cat[0]
		row.opts = cat[1]
		row.prefix = cat[2]
		row.changed.connect(func(k, val):
			if Progress.is_unlocked(k, val):
				_pending = []
				look_changed.emit(k, val)
			else:
				_try_on(k, val))
		box.add_child(row)
		_rows[cat[0]] = row
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sp)
	_buy = CtaButton.new()
	_buy.custom_minimum_size = Vector2(460, 60)
	_buy.font_size = 26
	_buy.visible = false
	_buy.pressed.connect(_do_buy)
	v.add_child(_buy)
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
	_labels["color"].text = Pal.t("wardrobe.color")
	var lab := {"hat": "wardrobe.hat", "mustache": "wardrobe.mustache", "bowtie": "wardrobe.bowtie", "glasses": "wardrobe.glasses",
		"necklace": "wardrobe.necklace", "outfit": "wardrobe.outfit", "banner": "ward.banner", "culture": "ward.culture", "castle": "ward.castle"}
	for k in lab:
		_rows[k].label = Pal.t(lab[k])
	_done.label = Pal.t("common.done")
	refresh()

func refresh() -> void:
	var look := Profile.look()
	for k in _rows:
		_rows[k].set_value(String(look.get(k, "none")))
		_rows[k].queue_redraw_name()
	_swatches.queue_redraw()
	_refresh_buy()

## Kilitli öğeyi dene: pelüş giyer, "Satın al" düğmesi çıkar
func _try_on(cat: String, item: String) -> void:
	_pending = [cat, item]
	preview.emit(cat, item)
	_locked_hint(cat, item)
	_refresh_buy()

func _refresh_buy() -> void:
	if _buy == null:
		return
	_buy.visible = not _pending.is_empty()
	if _pending.is_empty():
		return
	var cost := Progress.price(_pending[0], _pending[1])
	var have := Progress.coins()
	_buy.label = Pal.t("shop.buy", {"n": cost}) if have >= cost else Pal.t("shop.need", {"n": cost - have})
	_buy.style = "gold" if have >= cost else "ghost"

func _do_buy() -> void:
	if _pending.is_empty():
		return
	var cat: String = _pending[0]
	var item: String = _pending[1]
	if Progress.buy(cat, item):
		Pal.sfx("coin", -2.0, 1.1)
		Pal.sfx("fanfare", -10.0, 1.3)
		_pending = []
		look_changed.emit(cat, item)
		bought.emit()
		_hint = Pal.t("shop.bought", {"x": Pal.t((("culture." if cat == "culture" else ("castle." if cat == "castle" else ("banner." if cat == "banner" else "look.")))) + item)})
		_hint_t = 2.5
		refresh()
	else:
		Pal.sfx("buzz", -8.0, 1.2)
		_hint = Pal.t("shop.poor")
		_hint_t = 2.0
		Fx.shake(_buy, 8.0, 0.3)
	_rank.queue_redraw()

func open() -> void:
	_pending = []
	retext()
	_tabs.selected = 0
	_set_tab(false)
	_title.play(0.25)

func _swatch_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var i := int(e.position.x / 57.5) + (8 if e.position.y > 56 else 0)
		if i >= 0 and i < PlushVisual.COLOR_KEYS.size():
			var key: String = PlushVisual.COLOR_KEYS[i]
			if not Progress.is_unlocked("color", key):
				_try_on("color", key)
				return
			_pending = []
			_refresh_buy()
			Pal.sfx("click", -4.0, 1.0 + i * 0.05)
			look_changed.emit("color", key)
			_swatches.queue_redraw()

## Kilitli öğeye dokunuldu: nasıl açılacağını söyle
func _locked_hint(cat: String, item: String) -> void:
	var req := Progress.requirement(cat, item)
	if req.has("shop"):
		_hint = Pal.t("shop.only", {"n": req.price})
	elif req.has("level"):
		_hint = Pal.t("rank.locked_level", {"n": req.level}) + " · " + Pal.t("shop.or_buy", {"n": req.get("price", 0)})
	else:
		_hint = Pal.t("rank.locked_ach", {"a": SteamService.ach_name(String(req.get("ach", "")))})
	_hint_t = 2.5
	Pal.sfx("buzz", -12.0, 1.4)
	_rank.queue_redraw()

func _draw_rank() -> void:
	var xp := Progress.xp()
	var lv := Progress.level_of(xp)
	var y := 20.0
	if _hint_t > 0.0:
		Icons.draw(_rank, "cross", Vector2(10, y - 6), 14, Pal.BAD)
		_rank.draw_string(Pal.italic(), Vector2(24, y), _hint, HORIZONTAL_ALIGNMENT_LEFT, 440, 18, Color(Pal.GOLD, clampf(_hint_t, 0.0, 1.0)))
		return
	var head := Pal.upper(Pal.t("rank.level", {"n": lv})) + " · " + Pal.upper(Pal.t(Progress.title_key(lv)))
	_rank.draw_string(Pal.display_bold(), Vector2(0, y), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Pal.GOLD)
	var hw := Pal.display_bold().get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
	var bx := hw + 14
	var bw := 460.0 - bx - 70
	_rank.draw_rect(Rect2(bx, y - 11, bw, 8), Color(0, 0, 0, 0.5))
	_rank.draw_rect(Rect2(bx, y - 11, bw * Progress.level_frac(xp), 8), Pal.GOLD)
	var got := Progress.unlocked_ids().size()
	_rank.draw_string(Pal.italic(), Vector2(bx + bw + 8, y), "%d/%d" % [got, Progress.total_unlockables()], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(Pal.CREAM, 0.7))
	# jeton bakiyesi (sağ üstte)
	var ctext := str(Progress.coins())
	var cw := Pal.display_bold().get_string_size(ctext, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	Icons.draw(_rank, "coins", Vector2(460 - cw - 16, y - 34), 20, Pal.GOLD)
	_rank.draw_string(Pal.display_bold(), Vector2(460 - cw, y - 26), ctext, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Pal.GOLD)

func _process(d: float) -> void:
	if is_visible_in_tree():
		_swatches.queue_redraw()
		if _hint_t > 0.0:
			_hint_t -= d
			_rank.queue_redraw()

func _draw_swatches() -> void:
	var cur := String(Profile.look().get("color", "mustard"))
	var m := _swatches.get_local_mouse_position()
	for i in PlushVisual.COLOR_KEYS.size():
		var key: String = PlushVisual.COLOR_KEYS[i]
		var c := Vector2(26 + (i % 8) * 57.5, 28 + (i / 8) * 54)
		var locked := not Progress.is_unlocked("color", key)
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
		if locked:
			_swatches.draw_circle(c, rad, Color(0.05, 0.02, 0.03, 0.6))
			_lock_icon(_swatches, c, 13)
		if key == cur:
			_swatches.draw_arc(c, rad + 6, 0, TAU, 40, Pal.GOLD, 2.5, true)
			Icons.draw(_swatches, "check", c, 18, Pal.INK if col.get_luminance() > 0.45 else Pal.CHAMPAGNE, 3.0)

## Asma kilit simgesi (kilitli öğeler)
static func _lock_icon(ci: CanvasItem, c: Vector2, s: float, col := Color("F6CF7B")) -> void:
	ci.draw_arc(c + Vector2(0, -s * 0.25), s * 0.3, PI, TAU, 12, col, maxf(1.5, s * 0.14), true)
	ci.draw_rect(Rect2(c + Vector2(-s * 0.42, -s * 0.2), Vector2(s * 0.84, s * 0.62)), col)
	ci.draw_circle(c + Vector2(0, s * 0.06), s * 0.09, Color(0, 0, 0, 0.7))

class _Carousel extends HBoxContainer:
	signal changed(key: String, value: String)
	var key := ""
	var label := ""
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
		_name.custom_minimum_size = Vector2(332, 60)
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
	func queue_redraw_name() -> void:
		if _name:
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
		var locked := not Progress.is_unlocked(key, String(opts[cur]))
		if label != "":
			var kf := Pal.kicker()
			var lw := kf.get_string_size(Pal.upper(label), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			_name.draw_string(kf, Vector2((_name.size.x - lw) * 0.5, 12), Pal.upper(label), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(Pal.CREAM, 0.55))
		var fs := 32
		var extra := 70.0 if locked else 10.0
		while fs > 18 and f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > _name.size.x - extra:
			fs -= 2
		var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var e := _slide * _slide
		var x := (_name.size.x - w - (extra - 10.0) * 0.5) * 0.5 + e * 60.0 * _dir
		_name.draw_string(f, Vector2(x, 45), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Pal.MUTED if locked else Pal.CHAMPAGNE, 1.0 - e))
		if locked:
			WardrobePanel._lock_icon(_name, Vector2(x - 16, 34), 16)
			var price := Progress.price(key, String(opts[cur]))
			if price > 0:
				var pt := str(price)
				Icons.draw(_name, "coins", Vector2(x + w + 16, 34), 14, Color(Pal.GOLD, 0.9))
				_name.draw_string(Pal.display_bold(), Vector2(x + w + 26, 42), pt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(Pal.GOLD, 0.9))
		var n := opts.size()
		var dx := 12.0
		var x0 := _name.size.x * 0.5 - (n - 1) * dx * 0.5
		if n * dx > _name.size.x - 20:
			dx = (_name.size.x - 20) / n
			x0 = _name.size.x * 0.5 - (n - 1) * dx * 0.5
		for i in n:
			var lk := not Progress.is_unlocked(key, String(opts[i]))
			var col: Color = Pal.GOLD if i == cur else (Color(Pal.BAD, 0.35) if lk else Color(Pal.CREAM, 0.3))
			_name.draw_circle(Vector2(x0 + i * dx, 56), 2.2 if i != cur else 3.2, col)
