extends Node

## Map sync test — a save from map1 must NOT give map0 map1's tasks.
##
## Reproduces the reported bug: finish map0, travel to map1, quit, relaunch.
## START loads map0, but the save still says map1, so the HUD showed the
## wrong task list.

var _pass := 0
var _fail := 0


func _ready() -> void:
	await get_tree().process_frame

	# Simulate the stale save: the singleton believes we are in map1 ...
	GameState.current_map = "map1"
	GameState.money = 0
	print("  [INFO] GameState.current_map before load = ", GameState.current_map)

	# ... but the scene we actually load is map0
	var map_scene: PackedScene = load("res://scenes/map0.tscn")
	var map := map_scene.instantiate()
	get_tree().root.add_child(map)
	get_tree().current_scene = map
	await _wait(15)

	# The HUD lives on the player inside the map; give it a moment to sync
	await _wait(15)

	print("  [INFO] GameState.current_map after load = ", GameState.current_map)
	_check("map id synced to the loaded scene (map0)", GameState.current_map == "map0")

	# And the objective text should be map0's
	var objective := _find_objective(map)
	if objective != null:
		print("  [INFO] objective text = ", objective.text)
		_check("objective shows map0's, not map1's",
			not objective.text.contains("DINER"))
		_check("objective mentions the bus stop",
			objective.text.contains("BUS STOP"))
	else:
		_check("found an objective label", false)

	_finish()


func _find_objective(n: Node) -> Label:
	if n is Label:
		var l := n as Label
		if l.text.contains("BUS STOP") or l.text.contains("DINER") or l.text.contains("SHOP"):
			return l
	for c in n.get_children():
		var f := _find_objective(c)
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
