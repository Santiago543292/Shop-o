extends Node

## Bus stop test — loads the REAL map0 and checks the bus exit works there.
## This is the test that matters: the prop works in isolation, but the map
## scene is where the user actually walks into it.

var _pass := 0
var _fail := 0


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	var map_scene: PackedScene = load("res://scenes/map0.tscn")
	if map_scene == null:
		_check("map0 loads", false)
		_finish()
		return
	var map := map_scene.instantiate()
	get_tree().root.add_child(map)
	get_tree().current_scene = map
	await _wait(10)

	# Find the bus exit
	var bus := _find_capability(map, "next_map")
	if bus == null:
		_check("a bus exit exists in map0", false)
		_finish()
		return
	_check("a bus exit exists in map0", true)
	print("  [INFO] bus exit node: ", bus.name, " at ", bus.global_position)
	print("  [INFO] next_map: ", bus.get("next_map"))

	# Check its collision setup
	if bus is Area3D:
		var area := bus as Area3D
		print("  [INFO] layer=", area.collision_layer,
			" mask=", area.collision_mask,
			" monitoring=", area.monitoring)
		_check("bus area masks layer 1", area.collision_mask == 1)
		_check("bus area is monitoring", area.monitoring)
		var shape := _find_shape(area)
		_check("bus area has a CollisionShape3D", shape != null)
		if shape != null:
			print("  [INFO] shape disabled=", shape.disabled,
				" global_pos=", shape.global_position)

	# Find the player
	var player := _find_body(map)
	_check("player exists in map0", player != null)
	if player == null:
		_finish()
		return
	print("  [INFO] player layer=", player.collision_layer,
		" mask=", player.collision_mask)
	print("  [INFO] player start=", player.global_position)

	# Move the player onto the bus exit
	var target: Vector3 = (bus as Node3D).global_position
	print("  [INFO] moving player to bus exit at ", target)
	player.global_position = target + Vector3(0, 0.2, 0)
	player.velocity = Vector3.ZERO
	await _wait(30)

	var in_range: bool = bus.get("_player_in_range")
	_check("bus exit detects the player standing on it", in_range == true)
	if bus is Area3D:
		var overlapping := (bus as Area3D).get_overlapping_bodies()
		print("  [INFO] overlapping bodies: ", overlapping.size())
		_check("area reports an overlapping body", overlapping.size() > 0)

	# Walking in should have ticked the objective
	await _wait(5)
	print("  [INFO] at_bus_stop flag = ", GameState.has_flag("at_bus_stop"))
	_check("walking into the bus stop ticks the objective", GameState.has_flag("at_bus_stop"))

	# --- the bus must REFUSE while the map's work is unfinished ---
	GameState.money = 0
	var reason: String = bus.call("blocked_reason")
	print("  [INFO] blocked_reason with $0: ", reason)
	_check("bus refuses before $150 is met", reason != "")
	var scene_before_block := get_tree().current_scene
	_press_interact()
	await _wait(60)
	_check("E while blocked does NOT change the scene",
		get_tree().current_scene == scene_before_block)

	# --- give the money, and it should let you through ---
	GameState.money = 150
	# Keep the test fast: the real wait is the full 23.8s bus file.
	bus.set("bus_wait_time", 2.0)
	await _wait(5)
	_check("bus allows travel once $150 is met", str(bus.call("blocked_reason")) == "")

	var before_scene := get_tree().current_scene
	_press_interact()
	# Wait long enough for the bus cutscene (auto-advances in ~1.6s) + the
	# 2.0s bus_wait_time the test set, then the scene change.
	await _wait(260)
	var after_scene := get_tree().current_scene
	print("  [INFO] scene before=", before_scene, " after=", after_scene)
	print("  [INFO] current_map = ", GameState.current_map)
	_check("E on the bus exit changed the scene", after_scene != before_scene)
	_check("the map id followed the scene change", GameState.current_map == "map1")

	_finish()


func _finish() -> void:
	print("\n=== %d passed, %d failed ===" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _find_shape(n: Node) -> CollisionShape3D:
	if n is CollisionShape3D:
		return n
	for c in n.get_children():
		var f := _find_shape(c)
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


func _find_capability(n: Node, prop: String) -> Node:
	for c in n.get_children():
		if prop in c:
			return c
	for c in n.get_children():
		var f := _find_capability(c, prop)
		if f != null:
			return f
	return null


func _press_interact() -> void:
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	var up := InputEventAction.new()
	up.action = "interact"
	up.pressed = false
	Input.parse_input_event(up)


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
