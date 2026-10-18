extends Node

## _shop_check.gd - structural load test for scenes/map2.tscn.
## Run: godot --headless --path <proj> --scene res://tools/_test_shop.tscn

const SCENE := "res://scenes/map2.tscn"

var _ok := true
var _root := Node3D.new()


func _ready() -> void:
	get_tree().root.add_child(_root)
	_root.name = "_shop_test_root"

	var ps = ResourceLoader.load(SCENE)
	if ps == null:
		_fail("map2.tscn did not load as PackedScene")
		_done()
		return
	var inst = ps.instantiate()
	print("map2 root:", inst.name, inst.get_class())
	if inst == null:
		_fail("map2 did not instance")
		_done()
		return
	_root.add_child(inst)

	var names := []
	for c in inst.get_children():
		names.append(c.name)
	print("top-level children:", names)

	for w in ["ExitDoor", "ShopController", "Escape", "Employee", "Lights",
	          "NightEnvironment", "Moon", "HungerNode", "SaveSystem", "Player",
	          "TrapItem", "Floor", "Ceiling", "WallN_L", "WallN_R", "WallE",
	          "WallW", "WallS_L", "WallS_R", "WallS_Top", "CounterBody",
	          "CounterTop", "Item_Milk", "Item_Bread", "Item_Pickles",
	          "Item_Soap", "Item_Eggs", "Item_Candles"]:
		if not names.has(w):
			_fail("missing node: " + w)

	var trap = inst.find_child("TrapItem", true, false)
	if trap == null or not trap.has_method("_reveal_trap"):
		_fail("TrapItem wiring (_reveal_trap)")
	if trap != null and trap.get_class() != "Area3D":
		_fail("TrapItem not Area3D")

	var shop = inst.find_child("ShopController", true, false)
	if shop == null or not shop.has_method("spawn_contract"):
		_fail("ShopController wiring (spawn_contract)")

	var door = inst.find_child("ExitDoor", true, false)
	if door == null or not door.has_method("open"):
		_fail("ExitDoor wiring (open)")

	var esc = inst.find_child("Escape", true, false)
	if esc == null or not esc.has_method("_start_night"):
		_fail("Escape wiring (_start_night)")

	var lights = inst.find_child("Lights", true, false)
	if lights == null or lights.get_script() == null:
		_fail("Lights has no light_hum script")

	var player = inst.find_child("Player", true, false)
	if not _has_capability(player, "set_prompt"):
		_fail("Player has no HUD (set_prompt)")

	_done()


func _fail(msg: String) -> void:
	_ok = false
	print("FAIL: " + msg)


func _has_capability(n: Node, method: String) -> bool:
	if n == null:
		return false
	if n.has_method(method):
		return true
	for c in n.get_children():
		if _has_capability(c, method):
			return true
	return false


func _done() -> void:
	print("RESULT: " + ("PASS" if _ok else "FAIL"))
	_root.queue_free()
	get_tree().quit()
