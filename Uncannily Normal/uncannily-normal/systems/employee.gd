extends CharacterBody3D

## The employee AI — stands behind the counter, warns the player about the last item.
##
## The employee has three states:
##   IDLE      — stands behind the counter, does nothing
##   RUNNING   — runs at the player when all normal items are collected
##   WARNING   — faces the player, delivers the warning line, then returns
##
## The warning is the whole reason the last item is frightening: the employee
## runs at you, stops too close, and tells you not to buy it. Then they go
## back to the counter and do not speak again — which is worse.

@export var run_speed := 4.6
@export var stop_distance := 1.5
@export var stare_seconds := 1.1
@export var post_position := Vector3(0, 0, -4)

@export_group("Warning Lines")
@export var warning_lines: Array[String] = [
	"do not buy the last one.",
	"anything but the last one.",
	"please. not that one.",
	"you will not leave if you buy it.",
]

var _player: Node3D
var _hud: Node
var _state := "idle"   # idle | running | warning | done
var _stare := 0.0
var _said := false


func _ready() -> void:
	_player = _find_player()
	_hud = _hud_node()
	position = post_position


func _find_player() -> Node3D:
	var root := _scene_root()
	if root == null:
		return null
	for c in root.get_children():
		if c is CharacterBody3D and c != self and c.has_method("move_and_slide"):
			return c
	return null


func _scene_root() -> Node:
	var n: Node = self
	while n.get_parent() != null and n.get_parent() != get_tree().root:
		n = n.get_parent()
	return n


func _hud_node() -> Node:
	var root := _scene_root()
	if root == null:
		root = get_tree().root
	return _hud_find(root, "set_prompt")


func _hud_find(n: Node, method: String) -> Node:
	if n.has_method(method):
		return n
	for c in n.get_children():
		var f := _hud_find(c, method)
		if f != null:
			return f
	return null


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = _find_player()
		return

	match _state:
		"idle":
			# Watch for the moment the list is one short.
			if GameState.all_normal_collected() and not GameState.has_flag("warned"):
				_state = "running"
		"running":
			var to := _player.global_position - global_position
			to.y = 0.0
			if to.length() <= stop_distance:
				_state = "warning"
				_stare = stare_seconds
				velocity = Vector3.ZERO
			else:
				velocity = to.normalized() * run_speed
				_look_along(to)
				move_and_slide()
		"warning":
			_stare -= delta
			if _stare <= 0.0 and not _said:
				_said = true
				_say()
				_state = "done"
				GameState.set_flag("warned")
		"done":
			# Walk back to the counter and stay there.
			var back := post_position - position
			back.y = 0.0
			if back.length() > 0.4:
				velocity = back.normalized() * run_speed * 0.5
				_look_along(back)
				move_and_slide()
			else:
				velocity = Vector3.ZERO


func _look_along(dir: Vector3) -> void:
	if dir.length_squared() < 0.001:
		return
	var flat := Vector3(dir.x, 0.0, dir.z).normalized()
	rotation.y = atan2(flat.x, flat.z)


func _say() -> void:
	var line: String = warning_lines[randi() % warning_lines.size()]
	if _hud != null:
		_hud.call("show_message", "\" %s \"" % line, 4.5)
	# Nudge the list so the last entry is now called out in red.
	if _hud != null and _hud.has_method("show_message"):
		pass  # The HUD reads the flag on refresh.


## Called by the trap item when the player picks it up.
func trigger_warning() -> void:
	if GameState.has_flag("warned"):
		return
	_state = "running"
