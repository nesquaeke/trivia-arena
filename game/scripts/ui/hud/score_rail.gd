class_name ScoreRail
extends Control
## Soldaki skor sütunu. Sıralama değişince kartlar yaylanarak yer değiştirir.

const GAP := 10.0
var chips := {}          # isim -> ScoreChip

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func update_rows(rows: Array) -> void:
	var seen := {}
	for i in rows.size():
		var r: Dictionary = rows[i]
		var key := String(r.get("name", ""))
		seen[key] = true
		var chip: ScoreChip = chips.get(key)
		var ty := i * (ScoreChip.H + GAP)
		if chip == null:
			chip = ScoreChip.new()
			add_child(chip)
			chips[key] = chip
			chip.position = Vector2(0, ty)
			Fx.anchor(chip)
			Fx.rise(chip, 0.05 * i, Vector2(-60, 0), 0.5)
		chip.target_y = ty
		chip.apply(r, i + 1)
	for k in chips.keys():
		if not seen.has(k):
			chips[k].queue_free()
			chips.erase(k)

func clear() -> void:
	for c in chips.values():
		c.queue_free()
	chips.clear()
