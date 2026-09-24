class_name ConquestPiece
extends Node3D
## Haritada bir bölgeyi tutan küçük pelüş figür: sahibinin kumaşı ve kültür
## kostümü. Hafifçe nefes alır, göz kırpar; bölge alınınca devrilip gider.

var look := {}
var culture := "viking"
var visual: PlushVisual
var _t := 0.0

## look: yalnız "color" (kostümün rengi, oyuncunun rengi). Gövde klasik oyuncak ayı keçesi.
func _init(p_look := {}, p_culture := "viking") -> void:
	look = p_look
	culture = p_culture
	set_meta("base_scale", Vector3.ONE * 0.62)

func _ready() -> void:
	visual = PlushVisual.new({"color": "teddy"})
	visual.culture = culture
	visual.costume_color = PlushVisual.COLORS.get(String(look.get("color", "mustard")), Color.WHITE)
	add_child(visual)
	rotation.y = randf_range(-0.25, 0.25)
	_t = randf() * 5.0

func cheer() -> void:
	var tw := create_tween()
	tw.tween_property(self, "position:y", position.y + 0.35, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:y", position.y, 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	_t += delta
	if visual and visual.body_root:
		visual.animate(minf(delta, 1.0 / 30.0), Vector3.ZERO, true, 0)
