extends Node

## Eat test — verifies the food cutscene + hunger restore on map1 (the diner).
##
## Loads the real map1 (so the BurgerPiz2 diner + HungerNode + Player are
## present), drops hunger low, calls Food1.interact(), and checks the eating
## cutscene plays to completion and hunger is restored.

var _pass := 0
var _fail := 0

@onready var GameState = get_node("/root/GameState")
@onready var Cutscene  = get_node("/root/Cutscene")


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	GameState.reset()
	GameState.set_hunger(0.1)

	var map_scene := load("res://scenes/map1.tscn") as PackedScene
	if map_scene == null:
		_check("map1 loads", false)
		_finish()
		return
	var map := map_scene.instantiate()
	get_tree().root.add_child(map)
	get_tree().current_scene = map
	await _wait(20)

	var food := _find_named(map, "Food1")
	_check("Food1 placed at the diner in map1", food != null)
	if food == null:
		_finish()
		return

	var before = GameState.hunger
	_check("hunger is low before eating", before <= 0.2)

	food.interact()

	# Eating cutscene is 2 slides (auto 1.2 + 1.0 = ~2.2s); let it finish.
	await _wait(220)  # ~3.6s at 60fps
	_check("eating cutscene finished", not Cutscene.is_playing())

	var after = GameState.hunger
	_check("hunger restored by eating (0.1 -> >=0.6)", after >= 0.55 and after > before)

	# The prop should vanish in time with the "you feel stronger" slide.
	var mesh := food.get_node_or_null("Mesh") as MeshInstance3D
	if mesh != null:
		_check("food mesh hidden after eating", not mesh.is_visible_in_tree())
	else:
		_check("food mesh hidden after eating", false)

	_finish()


func _find_named(n: Node, name: String) -> Node:
	if n.name == name:
		return n
	for c in n.get_children():
		var f := _find_named(c, name)
		if f != null:
			return f
	return null


func _wait(frames: int) -> void:
	for i in range(frames):
		await get_tree().physics_frame


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("  PASS  ", label)
	else:
		_fail += 1
		var cut := get_node_or_null("/root/Cutscene")
		print("  FAIL  ", label, "  (hunger=", GameState.hunger,
			  " playing=", cut.is_playing() if cut else "?")


func _finish() -> void:
	get_tree().current_scene.queue_free() if get_tree().current_scene else null
	print("\n=== EAT: %d passed, %d failed ===" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
