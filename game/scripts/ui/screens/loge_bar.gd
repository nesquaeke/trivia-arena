class_name LogeBar
extends GlassPanel
## Loca: sahneye gül, domates, şapka fırlat.

signal throw(kind: String)
signal leave

var _kick: KickerLabel
var _btns := {}
var _leave: CtaButton

func _ready() -> void:
	size = Vector2(1000, 150)
	add_theme_constant_override("margin_top", 18)
	add_theme_constant_override("margin_bottom", 18)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	_kick = KickerLabel.new()
	v.add_child(_kick)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	for k in ["rose", "tomato", "hat"]:
		var b := CtaButton.new()
		b.style = "ghost"
		b.icon_name = k
		b.custom_minimum_size = Vector2(210, 64)
		b.font_size = 28
		var kind: String = k
		b.pressed.connect(func(): throw.emit(kind))
		row.add_child(b)
		_btns[k] = b
	_leave = CtaButton.new()
	_leave.style = "velvet"
	_leave.custom_minimum_size = Vector2(250, 64)
	_leave.font_size = 26
	_leave.pressed.connect(func(): leave.emit())
	row.add_child(_leave)

func retext() -> void:
	_kick.text = Pal.t("spectate.kicker") + "  ·  " + Pal.t("spectate.hint")
	for k in _btns:
		_btns[k].label = Pal.t("spectate." + k)
	_leave.label = Pal.t("spectate.leave")
