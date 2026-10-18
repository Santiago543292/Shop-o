extends Node

## Interaction test — proves the Area3D interactables detect the player and
## respond to E, without needing to run the game by hand.
##
## Prints PASS/FAIL per assertion and exits with a non-zero code on failure.

var _pass := 0
var _fail := 0


func _ready() -> void:
	await get_tree().process_frame

	var world := Node3D.new()
	world.name = "TestWorld"
	add_child(world)

	# Ground so the player does not fall forever
	var ground := StaticBody3D.new()
	var gcol := CollisionShape3D.new()
	var gshape := BoxShape3D.new()
	gshape.size = Vector3(40, 1, 40)
	gcol.shape = gshape
	gcol.position = Vector3(0, -0.5, 0)
	ground.add_child(gcol)
	world.add_child(ground)

	# HUD stand-in, so set_prompt has a target
	var hud := CanvasLayer.new()
	hud.set_script(preload("res://ui/hud.gd"))
	world.add_child(hud)
	await get_tree().process_frame

	# The player
	var player_scene: PackedScene = load("res://scenes/player.tscn")
	var player := player_scene.instantiate()
	player.position = Vector3(0, 0.2, 10)
	world.add_child(player)
	await get_tree().process_frame

	# A trash can at the origin
	var trash_scene: PackedScene = load("res://systems/trash_can.tscn")
	var trash := trash_scene.instantiate()
	trash.position = Vector3(0, 0, 0)
	world.add_child(trash)
	await get_tree().process_frame

	# --- TEST 1: the Area3D is configured to detect the player ---
	_check("trash is an Area3D", trash is Area3D)
	_check("trash collision_mask includes layer 1", (trash as Area3D).collision_mask == 1)
	_check("trash is monitoring", (trash as Area3D).monitoring)
	_check("trash has a CollisionShape3D child", _has_shape_child(trash))

	# --- TEST 2: player out of range -> no overlap ---
	await _wait(10)
	var in_range_before: bool = trash.get("_player_in_range")
	_check("player out of range reads false", in_range_before == false)

	# --- TEST 3: move the player into range -> overlap detected ---
	var body := _find_body(player)
	if body != null:
		body.global_position = Vector3(0, 0.2, 1.5)
	await _wait(20)
	var in_range_after: bool = trash.get("_player_in_range")
	_check("player in range reads true", in_range_after == true)

	# --- TEST 4: E press while in range fires the interaction ---
	GameState.money = 0
	var money_before := GameState.money
	# Direct call first — isolates the logic from the input path
	trash.call("interact")
	await _wait(5)
	var money_direct := GameState.money
	_check("interact() directly pays out money", money_direct > money_before)
	print("  [INFO] money after direct interact: $", money_direct)

	# --- TEST 4b: the HUD label follows GameState ---
	var money_label := _find_label_with(hud, "$")
	if money_label != null:
		await _wait(5)
		_check("HUD money label shows the new total",
			money_label.text == "$%d" % GameState.money)
	else:
		_check("HUD money label found", false)

	# Now the input path on a fresh can
	var trash3 := trash_scene.instantiate()
	trash3.position = Vector3(0, 0, 3)
	world.add_child(trash3)
	var body3 := _find_body(player)
	if body3 != null:
		body3.global_position = Vector3(0, 0.2, 3)
	await _wait(20)
	_check("second can sees player in range", trash3.get("_player_in_range") == true)
	var money_before3 := GameState.money
	_press_interact()
	await _wait(15)
	_check("E press fires interact()", GameState.money > money_before3)

	# --- TEST 5: E press out of range does nothing ---
	var trash2 := trash_scene.instantiate()
	trash2.position = Vector3(20, 0, 20)
	world.add_child(trash2)
	await _wait(5)
	_press_interact()
	await _wait(5)
	_check("out-of-range E did nothing", trash2.get("_searched") == false)

	# --- TEST 6: the bus exit is wired to the right scene ---
	var bus_scene: PackedScene = load("res://systems/bus_exit_map0.tscn")
	var bus := bus_scene.instantiate()
	_check("bus_exit_map0 targets map1",
		str(bus.get("next_map")) == "res://scenes/map1.tscn")
	# Add it to the tree so _ready() runs and sets the prompt
	bus.position = Vector3(50, 0, 50)
	world.add_child(bus)
	await _wait(5)
	_check("bus exit has a prompt", str(bus.get("prompt")).contains("BUS"))
	_check("bus exit found the HUD", bus.get("_hud") != null)

	print("\n=== %d passed, %d failed ===" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)


func _has_shape_child(n: Node) -> bool:
	for c in n.get_children():
		if c is CollisionShape3D:
			return true
	return false


func _find_body(n: Node) -> Node3D:
	if n is CharacterBody3D:
		return n
	for c in n.get_children():
		var f := _find_body(c)
		if f != null:
			return f
	return null


func _find_label_with(root: Node, needle: String) -> Label:
	if root is Label and (root as Label).text.begins_with(needle):
		return root
	for c in root.get_children():
		var f := _find_label_with(c, needle)
		if f != null:
			return f
	return null


func _find_capability(n: Node, method: String) -> Node:
	if n.has_method(method):
		return n
	for c in n.get_children():
		var f := _find_capability(c, method)
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
