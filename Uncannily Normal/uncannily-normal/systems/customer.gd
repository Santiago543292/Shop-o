extends Node3D

## Customer system — NPCs come into the shop and you serve them.
##
## Each customer has a shopping list. The player must give them the items.
## The last item is the same trap the player fell for — serve it and the
## customer is trapped too. The player is complicit.

@export var customer_interval := 15.0    # seconds between customers
@export var max_customers := 3
@export var next_scene := "res://scenes/map2.tscn"

var _hud: Node
var _customers: Array[Dictionary] = []
var _active_customer: Dictionary = {}
var _timer := 0.0
var _serving := false


func _ready() -> void:
	_hud = _hud_node()


func _process(delta: float) -> void:
	if _serving:
		return
	if _customers.is_empty():
		_spawn_customer()


func _spawn_customer() -> void:
	var root := _scene_root()
	if root == null:
		return
	# Find an NPC instance to use as the customer
	for c in root.get_children():
		if c.has_method("walk_to") and c.has_method("talk_to"):
			_active_customer = {
				"node": c,
				"items": ["MILK", "BREAD", "PICKLES"],
				"delivered": [],
			}
			_serving = true
			c.call("talk_to", _player())
			if _hud != null:
				_hud.call("show_message", "A customer comes in.\nServe them.", 3.0)
			# Walk to the counter
			c.call("walk_to", global_position + Vector3(0, 0, -2))
			break


func _player() -> Node3D:
	var root := _scene_root()
	if root == null:
		return null
	for c in root.get_children():
		if c is CharacterBody3D and c != self and c.has_method("move_and_slide"):
			return c
	return null


func deliver_item(item_id: String) -> void:
	if not _serving or _active_customer.is_empty():
		return
	var items: Array = _active_customer.get("items", [])
	var delivered: Array = _active_customer.get("delivered", [])
	if not items.has(item_id):
		if _hud != null:
			_hud.call("show_message", "They did not ask for that.", 1.5)
		return
	if delivered.has(item_id):
		if _hud != null:
			_hud.call("show_message", "Already gave them that.", 1.0)
		return
	delivered.append(item_id)
	_active_customer["delivered"] = delivered

	if _hud != null:
		_hud.call("show_message", "Gave them %s." % item_id, 1.5)

	# Check if all items delivered
	if delivered.size() >= items.size():
		_finish_serving()


func _finish_serving() -> void:
	if _active_customer.is_empty():
		return
	var node: Node3D = _active_customer.get("node", null)
	if node != null and node.has_method("react_scared"):
		node.call("react_scared")
	if _hud != null:
		_hud.call("show_message", "They bought it.\nThey won't be coming back.", 4.0)
	GameState.customers_served += 1
	_serving = false
	_active_customer = {}


func _hud_node() -> Node:
	var root := _scene_root()
	if root == null:
		return null
	for c in root.get_children():
		if c.has_method("set_prompt"):
			return c
	return null


func _scene_root() -> Node:
	var n: Node = self
	while n.get_parent() != null and n.get_parent() != get_tree().root:
		n = n.get_parent()
	return n
