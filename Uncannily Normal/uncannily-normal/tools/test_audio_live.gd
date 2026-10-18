extends Node

## Audio diagnostic — loads the real map0 and reports what is actually
## playing, at what volume, and whether the hum follows the player.

var _pass := 0
var _fail := 0


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	print("=== audio server ===")
	print("  driver: ", AudioServer.get_driver_name())

	var map_scene: PackedScene = load("res://scenes/map0.tscn")
	var map := map_scene.instantiate()
	get_tree().root.add_child(map)
	get_tree().current_scene = map
	await _wait(40)

	print("\n=== beds after loading map0 ===")
	print("  ambience playing=", GameAudio._ambience.playing,
		" vol=", GameAudio._ambience.volume_db,
		" stream=", GameAudio._ambience.stream)
	print("  hum playing=", GameAudio._hum.playing,
		" vol=", GameAudio._hum.volume_db,
		" stream=", GameAudio._hum.stream)

	_check("ambience is playing", GameAudio._ambience.playing)
	_check("ambience has a stream", GameAudio._ambience.stream != null)
	_check("ambience is audible (> -20 dB)", GameAudio._ambience.volume_db > -20.0)
	_check("hum is playing", GameAudio._hum.playing)
	_check("hum has a stream", GameAudio._hum.stream != null)

	# --- the light hum node must be running ---
	var hum_node := _find_by_script(map, "res://systems/light_hum.gd")
	_check("the light hum node exists in map0", hum_node != null)
	if hum_node != null:
		print("  hum node: ", hum_node.name, " lights=", hum_node.get("_lights").size())
		_check("the hum node found the map's lights", hum_node.get("_lights").size() > 0)

	# --- move the player right next to a light and see if the hum rises ---
	var player := _find_body(map)
	var lights: Array = hum_node.get("_lights") if hum_node != null else []
	if player != null and lights.size() > 0:
		var nearest: OmniLight3D = lights[0]
		var best := INF
		for l in lights:
			var d: float = l.global_position.distance_to(player.global_position)
			if d < best:
				best = d
				nearest = l
		print("\n  nearest light ", nearest.name, " at ", best, " units")
		player.global_position = nearest.global_position + Vector3(0, -1.0, 0)
		await _wait(30)
		print("  hum volume AT the light = ", GameAudio._hum.volume_db)
		_check("the hum is loud at a light", GameAudio._hum.volume_db > -15.0)

		# and far away
		player.global_position = nearest.global_position + Vector3(60, 0, 60)
		await _wait(30)
		print("  hum volume far away = ", GameAudio._hum.volume_db)
		_check("the hum goes quiet away from lights", GameAudio._hum.volume_db < -25.0)

	# --- the trash can search sound ---
	GameAudio.last_oneshot = ""
	GameAudio.play_search()
	await _wait(5)
	print("\n  search playing=", GameAudio._oneshot.playing,
		" vol=", GameAudio._oneshot.volume_db,
		" last=", GameAudio.last_oneshot)
	_check("the search sound plays", GameAudio.last_oneshot == "search")
	_check("the search sound is audible", GameAudio._oneshot.volume_db > -20.0)

	_finish()


func _find_by_script(n: Node, path: String) -> Node:
	var s := n.get_script() as Script
	if s != null and s.resource_path == path:
		return n
	for c in n.get_children():
		var f := _find_by_script(c, path)
		if f != null:
			return f
	return null


func _find_body(n: Node) -> CharacterBody3D:
	if n is CharacterBody3D:
		return n
	for c in n.get_children():
		var f := _find_body(c)
		if f != null:
			return f
	return null


func _finish() -> void:
	print("\n=== %d passed, %d failed ===" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _wait(frames: int) -> void:
	for i in range(frames):
		await get_tree().physics_frame


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		print("  FAIL  ", label)
