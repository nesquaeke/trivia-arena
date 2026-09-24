extends Node
## Uçtan uca telefon testi için sahne tarafı:
##   godot --headless --path game res://tests/phone_host.tscn -- --relay=ws://localhost:3123/ws
## Kodu /tmp/ta_code.txt'ye yazar, telefon katılınca pelüşün hareketini ölçer.
func _ready() -> void:
	Profile.save_enabled = false
	var m = load("res://scenes/main.tscn").instantiate()
	add_child(m)
	await get_tree().create_timer(0.5).timeout
	m.start_house()
	var t := 0.0
	while m.bridge.state != "live" and t < 15.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	print("HOSTED ", m.bridge.code, " state=", m.bridge.state)
	var f := FileAccess.open("/tmp/ta_code.txt", FileAccess.WRITE)
	f.store_string(m.bridge.code)
	f.close()
	t = 0.0
	while m.phone_players.is_empty() and t < 60.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	if m.phone_players.is_empty():
		print("RESULT no_pad")
		get_tree().quit(2)
		return
	var p: Plush = m.phone_players.values()[0]
	print("PAD JOINED name=", p.player_name, " color=", p.look.color)
	var start := p.global_position
	var max_y := start.y
	var max_x := start.x
	for i in 240:
		await get_tree().physics_frame
		max_y = max(max_y, p.global_position.y)
		max_x = max(max_x, p.global_position.x)
	print("RESULT moved_x=%.2f jumped=%.2f" % [max_x - start.x, max_y - start.y])
	get_tree().quit(0)
