extends Area3D

## DinerZone — detects when the player steps inside the diner.
##
## A plain trigger (no physics): it watches for the player's body and ticks the
## "found the diner" objective the first time they walk in, so the task completes
## on arrival rather than on the first purchase.

@export var zone_flag := "found_diner"

var _entered := false


func _ready() -> void:
	# Detect the player (layer 1); this zone is not itself detected.
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	# Size the trigger here rather than in the scene: the editor keeps resizing
	# the collision shape into a huge flat plane, which makes the diner trip
	# from halfway across the map.
	var col := get_node_or_null("Col") as CollisionShape3D
	if col == null:
		col = CollisionShape3D.new()
		col.name = "Col"
		add_child(col)
	var box := BoxShape3D.new()
	box.size = Vector3(6.0, 3.0, 10.0)
	col.shape = box
	col.position = Vector3(0.0, -0.5, 0.0)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if _entered or not body.has_method("move_and_slide"):
		return
	# Belt and braces: the editor can resize the collision shape, so also require
	# the player to actually be standing inside the diner.
	if body.global_position.distance_to(global_position) > 8.0:
		return
	_entered = true
	var gs := get_node_or_null("/root/GameState")
	if gs != null and zone_flag != "" and not gs.has_flag(zone_flag):
		gs.set_flag(zone_flag)
