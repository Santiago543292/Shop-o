extends Node

## _flow_shop.gd - end-to-end flow test for the map2 shop trap.
##
## Drives the real sequence the player goes through:
##   TriggerItem.interact()  ->  3-slide fine-print cutscene
##   -> GameState.trapped_in_shop + contract spawned on the counter
##   -> (escape timer) -> night cutscene -> back ExitDoor opens + monster spawns
##
## Cutscenes auto-advance after DEFAULT_AUTO=6s, but they also advance on any
## key/click once the slide's `min` has elapsed, so this test pumps a Space key
## every 2.5s (longer than the longest `min` = 2.4s) to step them through fast.
##
## Run: godot --headless --path <proj> --scene res://tools/_test_flow_shop.tscn

const SCENE := "res://scenes/map2.tscn"
const SPACE_KEYCODE := 32          # Key.SPACE
const PUMP_INTERVAL := 2.5         # must exceed every slide's `min` (max 2.4)
const DEADLINE := 40.0

enum State { IDLE, TRIGGER, WAIT_TRAP, WAIT_NIGHT, DONE, FAIL }
var _state := State.IDLE

var _t := 0.0
var _init_wait := 0.6
var _inst: Node3D
var _ok := true
var _last_pump := -999.0
var _trap_checked := false
var _night_cutscene_seen := false

@onready var GameState = get_node("/root/GameState")
@onready var Cutscene  = get_node("/root/Cutscene")


func _ready() -> void:
	GameState.reset()
	var ps := ResourceLoader.load(SCENE) as PackedScene
	if ps == null:
		_fail("map2 PackedScene null"); _end()
		return
	_inst = ps.instantiate()
	get_tree().root.call_deferred("add_child", _inst)


func _process(delta: float) -> void:
	_t += delta
	if _t > DEADLINE and _state != State.DONE:
		_fail("deadline hit in state " + str(_state)); _end()
		return

	# pump Space to advance any active cutscene
	if Cutscene != null and Cutscene.is_playing():
		if _t - _last_pump >= PUMP_INTERVAL:
			_last_pump = _t
			_send_space()

	match _state:
		State.IDLE:
			if _inst != null and _inst.is_inside_tree() and _t >= _init_wait:
				_set_fast_escape()
				_state = State.TRIGGER
		State.TRIGGER:
			var trap := _inst.find_child("TrapItem", true, false)
			if trap == null or not trap.has_method("interact"):
				_fail("TrapItem missing/interact"); _end()
				return
			trap.interact()
			_state = State.WAIT_TRAP
		State.WAIT_TRAP:
			if GameState.has_flag("trapped_in_shop"):
				_assert_trap_done()
				_state = State.WAIT_NIGHT
		State.WAIT_NIGHT:
			# night cutscene plays once escape timer fires; keep pumping until
			# the back exit opens and the monster spawns.
			if _exit_opened() and _monster_spawned():
				_assert_night_done()
				_state = State.DONE
		State.DONE:
			_end()


func _set_fast_escape() -> void:
	var esc := _inst.find_child("Escape", true, false)
	if esc == null:
		return
	# @export var -> direct assignment works at runtime (set() guarded by
	# has_method("set") is unreliable for built-in dispatch).
	esc.escape_delay = 0.4


func _send_space() -> void:
	var ev := InputEventKey.new()
	ev.keycode = SPACE_KEYCODE
	ev.pressed = true
	ev.echo = false
	get_tree().root.push_input(ev, true)


func _assert_trap_done() -> void:
	if not GameState.has_flag("bought_the_last_one"):
		_fail("bought_the_last_one not set")
	if not GameState.has_flag("read_the_fine_print"):
		_fail("read_the_fine_print not set")
	var sc := _inst.find_child("ShopController", true, false)
	var contract_spawned := false
	if sc != null:
		for c in sc.get_children():
			if c is MeshInstance3D:
				contract_spawned = true
				break
	if not contract_spawned:
		_fail("contract not spawned on ShopController")
	print("[trap] flags set + contract spawned OK")


func _exit_opened() -> bool:
	var col := _inst.find_child("ExitDoorCol", true, false)
	if col == null:
		return false
	return bool(col.get("disabled"))


func _monster_spawned() -> bool:
	return _inst.find_child("Monster", true, false) != null


func _assert_night_done() -> void:
	if not _exit_opened():
		_fail("ExitDoor did not open")
	if not _monster_spawned():
		_fail("monster did not spawn")
	print("[escape] back exit opened + monster spawned OK")


func _fail(msg: String) -> void:
	_ok = false
	print("FAIL: " + msg)


func _end() -> void:
	print("RESULT_FLOW: " + ("PASS" if _ok else "FAIL"))
	if _inst != null and is_instance_valid(_inst):
		_inst.queue_free()
	get_tree().quit()
