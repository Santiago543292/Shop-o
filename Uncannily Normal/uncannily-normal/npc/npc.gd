extends CharacterBody3D

## NPC — a character the player can talk to, walk up to, and use in cutscenes.
##
## Built like the player scene so it is familiar: a CharacterBody3D with a
## capsule collider, a model, and an AnimationPlayer. The difference is the
## brain — this one idles, walks to points, faces the player, and talks.
##
## NPCs serve three roles in the game:
##   PEDESTRIAN  — walks the streets, talks if approached
##   CUSTOMER    — comes into the shop, asks for items, buys the trap
##   EMPLOYEE    — works the counter, warns the player about the last item
##
## Animations expected on the AnimationPlayer:
##   "idle"    — standing, subtle breathing
##   "walk"    — walking cycle
##   "talk"    — talking gesture
##   "scared"  — the reaction you want from a customer
##
## If an animation is missing the NPC just stands there, which is fine.

@export var npc_name := "NPC"
@export var dialogue: Array[String] = []
@export var walk_speed := 2.2
@export var turn_speed := 8.0
@export var npc_role := "pedestrian"   # pedestrian | customer | employee
@export var shopping_list: Array[String] = []

var _player: Node3D
var _hud: Node
var _state := "idle"   # idle | walk | talk
var _target: Vector3 = Vector3.ZERO
var _dialogue_index := 0

@onready var _anim: AnimationPlayer = get_node_or_null("AnimationPlayer")
@onready var _model: Node3D = get_node_or_null("Model")


func _ready() -> void:
	_player = _find_player()
	_hud = _hud_node()


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
		return null
	for c in root.get_children():
		if c.has_method("set_prompt"):
			return c
	return null


func _physics_process(delta: float) -> void:
	match _state:
		"idle":
			_play("idle")
		"walk":
			var to := _target - global_position
			to.y = 0.0
			if to.length() < 0.3:
				_state = "idle"
				_play("idle")
				velocity = Vector3.ZERO
			else:
				velocity = to.normalized() * walk_speed
				_look_along(to)
				_play("walk")
				move_and_slide()
		"talk":
			_play("talk")
			velocity = Vector3.ZERO
			if _player != null:
				var to := _player.global_position - global_position
				_look_along(to)


func _look_along(dir: Vector3) -> void:
	if dir.length_squared() < 0.001:
		return
	var flat := Vector3(dir.x, 0.0, dir.z).normalized()
	rotation.y = atan2(flat.x, flat.z)


func _play(anim: String) -> void:
	if _anim == null:
		return
	if _anim.has_animation(anim) and _anim.current_animation != anim:
		_anim.play(anim)


# --- public API -------------------------------------------------------------

## Walk to a position, then go idle.
func walk_to(pos: Vector3) -> void:
	_target = pos
	_state = "walk"


## Face the player and talk. Shows the next dialogue line.
func talk_to(player: Node3D) -> void:
	_player = player
	_state = "talk"
	if _hud == null:
		return
	if dialogue.is_empty():
		_hud.call("show_message", "...", 2.0)
		return
	var line: String = dialogue[_dialogue_index % dialogue.size()]
	_dialogue_index += 1
	_hud.call("show_message", "%s:\n\"%s\"" % [npc_name, line], 4.0)


## React — play the scared animation and back away.
func react_scared() -> void:
	_play("scared")
	_state = "idle"


## Set a dialogue line by index (for cutscenes).
func set_dialogue(lines: Array[String]) -> void:
	dialogue = lines
	_dialogue_index = 0


## Employee: trigger the warning run at the player.
func trigger_warning() -> void:
	_state = "warn"


## Customer: called when the player delivers an item.
func receive_item(item_id: String) -> void:
	if _hud == null:
		return
	if shopping_list.has(item_id):
		_hud.call("show_message", "%s:\n\"Thank you.\"" % npc_name, 1.5)
	else:
		_hud.call("show_message", "%s:\n\"That is not on my list.\"" % npc_name, 1.5)
