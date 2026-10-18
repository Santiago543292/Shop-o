extends Node

## Save/load — persists real progress, never clobbers a fresh run.
##
## START always begins a fresh run (see main_menu._on_start), so nothing here
## loads automatically. Loading on every map load is what put the previous
## session's money and flags into a new game; loading is now explicit.
##
## A save is only written once the player has actually done something.

const SAVE_PATH := "user://progress.cfg"

var _config := ConfigFile.new()


func _ready() -> void:
	# Deliberately does NOT load. START resets the state, and loading the save
	# here would immediately put the old session's money and flags back.
	pass


func has_progress() -> bool:
	return (not GameState.collected.is_empty()
		or GameState.customers_served > 0
		or GameState.current_map != "map0"
		or GameState.money > 0
		or GameState.has_flag("bought_the_last_one"))


func save_game() -> void:
	# Do not write a save for a run where nothing has happened yet.
	if not has_progress():
		return
	_config.set_value("save", "current_map", GameState.current_map)
	_config.set_value("save", "collected", GameState.collected)
	_config.set_value("save", "flags", GameState.flags)
	_config.set_value("save", "hunger", GameState.hunger)
	_config.set_value("save", "customers_served", GameState.customers_served)
	_config.set_value("save", "escape_unlocked", GameState.escape_unlocked)
	_config.set_value("save", "is_night", GameState.is_night)
	_config.set_value("save", "money", GameState.money)
	_config.save(SAVE_PATH)


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	_config.load(SAVE_PATH)

	# Ignore a save that holds no actual progress.
	var saved_collected: Array = _config.get_value("save", "collected", [])
	var saved_customers: int = int(_config.get_value("save", "customers_served", 0))
	var saved_map: String = str(_config.get_value("save", "current_map", "map0"))
	if saved_collected.is_empty() and saved_customers == 0 and saved_map == "map0":
		return

	for c in saved_collected:
		if not GameState.collected.has(str(c)):
			GameState.collected.append(str(c))

	var flags: Dictionary = _config.get_value("save", "flags", {})
	for k in flags:
		GameState.flags[str(k)] = flags[k]

	var hunger: float = float(_config.get_value("save", "hunger", 1.0))
	GameState.hunger = clampf(hunger, 0.0, 1.0)

	if saved_customers > 0:
		GameState.customers_served = saved_customers
	if bool(_config.get_value("save", "escape_unlocked", false)):
		GameState.escape_unlocked = true
	GameState.money = int(_config.get_value("save", "money", 0))

	GameState.set_map(saved_map)


func clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		get_tree().quit()
