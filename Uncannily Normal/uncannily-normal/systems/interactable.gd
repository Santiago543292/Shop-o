extends Area3D

## Interactable — walk up to it, press E.
##
## The pattern that worked in the old game: an Area3D detects the player
## entering its radius, shows a prompt, and handles E while the player is
## inside. No raycast, no aiming.
##
## Subclasses override `interact()`.
##
## Collaborators (the HUD, the inventory) are found by CAPABILITY anywhere in
## the tree, not by a fixed parent path — they live on the player, not beside
## the prop, so a scene-root lookup finds nothing and the prompt never shows.

@export var prompt := "[E]  INTERACT"

var _player_in_range := false
var _hud: Node


func _ready() -> void:
	# Detect bodies on layer 1 (the player); do not be detected ourselves.
	collision_layer = 0
	collision_mask = 1
	monitoring = true

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_hud = _find_capability("set_prompt")


func _on_body_entered(body: Node3D) -> void:
	if body.has_method("move_and_slide"):
		_player_in_range = true
		_push_prompt(prompt)


func _on_body_exited(body: Node3D) -> void:
	if body.has_method("move_and_slide"):
		_player_in_range = false
		_push_prompt("")


func _push_prompt(text: String) -> void:
	if _hud == null or not is_instance_valid(_hud):
		_hud = _find_capability("set_prompt")
	if _hud != null:
		_hud.call("set_prompt", text)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	if not _player_in_range:
		return
	interact()


## Override in a subclass.
func interact() -> void:
	pass


# --- helpers for subclasses ------------------------------------------------

## Find any node in the tree that has `method`. Searches recursively, so it
## finds collaborators on the player as well as in the scene.
func _find_capability(method: String) -> Node:
	var root := get_tree().current_scene
	if root == null:
		root = get_tree().root
	return _search(root, method)


func _search(n: Node, method: String) -> Node:
	if n.has_method(method):
		return n
	for c in n.get_children():
		var f := _search(c, method)
		if f != null:
			return f
	return null
