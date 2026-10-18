extends Node

## Player input helper — the inventory key.
##
## Keys:
##   Q (inventory) -> opens / closes the player's inventory panel.
##   E (interact)  -> when the inventory is open, eats the picked food; when it
##                    is closed, the key falls through to nearby Area3Ds (NPC
##                    dialogue / the shopkeeper) so each key still has one owner
##                    per context.

## The inventory is a CanvasLayer that lives ON the player, not beside it in
## the map, so it is found by searching the tree for the `toggle` capability
## rather than by walking a fixed parent path.

var _inventory: Node


func _ready() -> void:
	_inventory = _find_inventory()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):  # Q: open / close inventory
		if _inventory == null or not is_instance_valid(_inventory):
			_inventory = _find_inventory()
		if _inventory != null and _inventory.has_method("toggle"):
			_inventory.call("toggle")
		return
	# E: when the inventory is open, it owns the key — eat the picked food.
	# When closed, we drop through so nearby Area3Ds (NPCs / shop) see E.
	if event.is_action_pressed("interact"):
		if _inventory != null and _inventory.has_method("is_open") and bool(_inventory.call("is_open")):
			if _inventory.has_method("eat_selected"):
				_inventory.call("eat_selected")
			return


func _find_inventory() -> Node:
	var root := get_tree().current_scene
	if root == null:
		root = get_tree().root
	return _search(root)


func _search(n: Node) -> Node:
	if n.has_method("toggle") and n.has_method("is_open"):
		return n
	for c in n.get_children():
		var f := _search(c)
		if f != null:
			return f
	return null
