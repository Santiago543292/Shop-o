extends Node

## Hunger system — the player gets hungry over time, must eat to survive.
##
## Hunger decays over time. At 0.4 the player is hungry (objective updates).
## At 0.0 they starve — health drains, screen pulses, they must eat or die.
##
## Food items (at the diner, in the shop) restore hunger. The diner is the
## intended place to eat; the shop has expensive food that costs progress.

@export var decay_per_second := 0.005    # ~200 seconds from full to starving
@export var starve_damage_per_second := 2.0
@export var health := 100.0
var _hud: Node
var _dead := false


func _ready() -> void:
	_hud = _hud_node()


func _process(delta: float) -> void:
	if _dead:
		return
	if GameState.is_starving() or GameState.hunger <= 0.0:
		health -= starve_damage_per_second * delta
		if _hud != null and int(health) % 10 == 0:
			_hud.call("show_message", "YOU ARE STARVING.\nFIND FOOD.", 1.0)
		if health <= 0.0:
			_die()
	else:
		# Decay hunger
		var current := GameState.hunger
		current -= decay_per_second * delta
		GameState.set_hunger(current)


func eat(amount: float) -> void:
	if _dead:
		return
	var new_hunger := clampf(GameState.hunger + amount, 0.0, 1.0)
	GameState.set_hunger(new_hunger)
	if _hud != null:
		_hud.call("show_message", "You feel less hungry.", 2.0)


func heal(amount: float) -> void:
	if _dead:
		return
	health = minf(health + amount, 100.0)


func damage(amount: float) -> void:
	if _dead:
		return
	health -= amount
	if health <= 0.0:
		_die()


func _die() -> void:
	if _dead:
		return
	_dead = true
	if _hud != null:
		_hud.call("show_message", "YOU DIED.", 5.0)
	await get_tree().create_timer(5.0).timeout
	get_tree().reload_current_scene()


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
