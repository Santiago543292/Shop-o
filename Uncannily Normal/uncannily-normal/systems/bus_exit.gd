extends "res://systems/interactable.gd"

## Bus exit — walk up to it, press E, go to the next map.
##
## The bus will NOT take you until this map's work is done. Set the
## requirement fields per instance (the pre-wired bus_exit_mapN.tscn scenes
## already do). Pressing E before then shows what is still missing, so the
## player is never stuck wondering why nothing happened.
##
## Walking into the box ticks the "find the bus stop" objective.

@export var next_map := ""
## Seconds to wait before changing scene. 0 (the default) means "wait for the
## bus sound to finish" — the file is the whole arrive-idle-drive-off sequence,
## so cutting it short at a fixed 2.5s left the player hearing half a bus.
@export var bus_wait_time := 0.0
@export var objective_flag := "at_bus_stop"
## True = this bus ends the demo: show "END OF DEMO" and quit instead of
## loading the next map.
@export var ends_demo := false

@export_group("Requirements — the bus refuses until these are met")
@export var require_money := 150
@export var require_hunger := 0.0
@export var require_flag := ""
@export var blocked_message := "Not yet. Finish what you came here for."

var _leaving := false


func _ready() -> void:
	super()
	prompt = "[E]  WAIT FOR THE BUS"


func _on_body_entered(body: Node3D) -> void:
	super(body)
	if not body.has_method("move_and_slide"):
		return
	if objective_flag != "":
		GameState.set_flag(objective_flag)
	if _hud != null:
		_hud.call("show_message", "You found the bus stop.\nPress E to wait.", 3.0)


## Why the player cannot leave, or "" when they can.
func blocked_reason() -> String:
	if require_money > 0 and GameState.money < require_money:
		return "You need $%d before you can leave.\nYou have $%d." % [require_money, GameState.money]
	if require_hunger > 0.0 and GameState.hunger < require_hunger:
		return "You are too hungry to travel.\nFind something to eat first."
	if require_flag != "" and not GameState.has_flag(require_flag):
		return "You cannot leave yet.\nFinish what you came here for."
	return ""


func interact() -> void:
	if _leaving:
		return

	var blocked := blocked_reason()
	if blocked != "":
		if _hud != null:
			_hud.call("show_message", blocked, 3.5)
		return

	_leaving = true
	# No cutscene: the player just waits at the stop while the bus arrives.
	_wait_for_bus()


func _wait_for_bus() -> void:
	# The bus is heard before it is seen — the arrival is the loudest thing on
	# the street, and the scene change waits for it to finish.
	GameAudio.play_bus_arrive()
	if ends_demo:
		# The demo ends here: say so, then close the game instead of moving on.
		if _hud != null:
			_hud.call("show_message", "END OF DEMO", 4.0)
		await get_tree().create_timer(4.0).timeout
		get_tree().quit()
		return
	var wait := _bus_duration()
	if _hud != null:
		_hud.call("show_message", "The bus is coming.\nPlease wait.", wait)

	await get_tree().create_timer(wait).timeout

	if next_map != "":
		GameState.set_map(_map_id_for(next_map))
		get_tree().change_scene_to_file(next_map)
	else:
		get_tree().change_scene_to_file("res://ui/main_menu.tscn")


## How long to let the arrival play before moving on. A fixed `bus_wait_time`
## wins if set; otherwise the sound's own length is used, so the bus is never
## cut off mid-arrival.
func _bus_duration() -> float:
	if bus_wait_time > 0.0:
		return bus_wait_time
	var s := GameAudio._load("bus") as AudioStream
	if s is AudioStream:
		return maxf(s.get_length(), 1.0)
	return 2.5


## Turn a scene path into the map id the registry knows, so the HUD's
## objective and task list follow the player across the change.
func _map_id_for(scene_path: String) -> String:
	for m in GameState.MAPS:
		if str(m.get("scene", "")) == scene_path:
			return str(m.get("id", ""))
	return GameState.current_map
