extends "res://systems/interactable.gd"

## shelf_item.gd — a shopping-list entry sitting on a shop shelf.
##
## Normal items collect their id into GameState (which ticks off the HUD's
## shopping list). Decoys (item_id == "") are just labelled — they look like
## products but are not on the list, so taking them does nothing but show the
## label, keeping the player guessing which shelf item is real.
##
## The Area3D is detection only (collision_layer = 0, set by Interactable);
## the shelf itself is the solid surface the item sits on, so this node has no
## physics body and the player simply walks past it to press E.

@export var item_id := ""        # matches an entry in GameState.LIST, or "" for a decoy
@export var item_label := ""     # shown in the prompt and the take message

var _taken := false
var _mesh: MeshInstance3D


func _ready() -> void:
	super()
	_mesh = get_node_or_null("Mesh") as MeshInstance3D
	if item_label != "":
		prompt = "[E]  TAKE %s" % item_label


func interact() -> void:
	if _taken:
		return
	if item_id == "":
		# A decoy — show what it is, but it is not on the list.
		if _hud != null:
			_hud.call("show_message", item_label + "\nNot on the list.", 2.0)
		return
	if GameState.has_collected(item_id):
		return
	_taken = true
	GameState.collect(item_id)
	if _hud != null:
		_hud.call("show_message", "TOOK %s." % item_label, 1.5)
	if _mesh != null:
		_mesh.visible = false
