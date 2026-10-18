extends Node

## Fresh-start test — reproduces "I start at $132 and the bus stop is already
## found".
##
## A previous session leaves a save on disk. Pressing START must give a clean
## run: $0, no flags, map0's objective unticked.
##
## NOTE: _on_start() changes the scene, which frees this test node. Every
## assertion therefore runs SYNCHRONOUSLY right after the call, before the
## deferred scene change can free us.

var _pass := 0
var _fail := 0
const SAVE_PATH := "user://progress.cfg"


func _ready() -> void:
	await get_tree().process_frame

	# --- 1. Lay down a stale save exactly like a previous session would ---
	var cfg := ConfigFile.new()
	cfg.set_value("save", "current_map", "map1")
	cfg.set_value("save", "collected", ["banana"])
	cfg.set_value("save", "flags", {"at_bus_stop": true})
	cfg.set_value("save", "hunger", 0.75)
	cfg.set_value("save", "customers_served", 0)
	cfg.set_value("save", "escape_unlocked", false)
	cfg.set_value("save", "is_night", true)
	cfg.set_value("save", "money", 132)
	cfg.save(SAVE_PATH)
	print("  [INFO] wrote stale save: money=132, at_bus_stop=true, map=map1")
	_check("stale save file exists", FileAccess.file_exists(SAVE_PATH))

	# --- 2. Build the menu and press START ---
	var menu_scene: PackedScene = load("res://ui/main_menu.tscn")
	var menu := menu_scene.instantiate()
	get_tree().root.add_child(menu)
	await _wait(10)

	# _on_start() resets the singleton synchronously, then defers the scene
	# change. Read the state NOW, before the change frees this node.
	menu.call("_on_start")

	# --- 3. The new run must be clean ---
	print("  [INFO] money after START = ", GameState.money)
	print("  [INFO] at_bus_stop after START = ", GameState.has_flag("at_bus_stop"))
	print("  [INFO] current_map after START = ", GameState.current_map)
	print("  [INFO] collected after START = ", GameState.collected)

	_check("money starts at 0, not 132", GameState.money == 0)
	_check("the bus stop is NOT already found", not GameState.has_flag("at_bus_stop"))
	_check("no items carried over", GameState.collected.is_empty())
	_check("the run begins in map0", GameState.current_map == "map0")
	_check("hunger starts full", GameState.hunger > 0.99)

	# --- 4. The stale save must be gone, so a reload stays clean ---
	_check("stale save was deleted", not FileAccess.file_exists(SAVE_PATH))

	_finish()


func _finish() -> void:
	print("\n=== %d passed, %d failed ===" % [_pass, _fail])
	# Quit on the root: this node may already be freed by the scene change.
	if is_inside_tree():
		get_tree().quit(0 if _fail == 0 else 1)
	else:
		print("  [INFO] test node was freed by the scene change (expected)")


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
