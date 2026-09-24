extends SceneTree
## Bütün .gd dosyalarını derler, hata verenleri listeler.
##   godot --headless --path game -s res://tools/check_scripts.gd

func _init() -> void:
	var bad := 0
	for p in _walk("res://scripts") + _walk("res://tests"):
		var s = load(p)
		if s == null or (s is GDScript and not s.can_instantiate()):
			print("HATA: ", p)
			bad += 1
	print("derlendi, hatalı: ", bad)
	quit(bad)

func _walk(dir: String) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for sub in d.get_directories():
		out.append_array(_walk(dir + "/" + sub))
	return out
