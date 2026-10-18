extends "res://systems/interactable.gd"
##
## When the player picks it up, the employee warns them not to buy it.
## If they do anyway, the contract appears and they're trapped.
##
## This is the core of the game's horror: the list itself is the trap.

# prompt "[E]  TAKE THE LAST ONE" is inherited from Interactable; set in _ready.

var _mesh: MeshInstance3D
var _glow: OmniLight3D
var _tween: Tween = null
var _taken := false


func _ready() -> void:
	super()
	prompt = "[E]  TAKE THE LAST ONE"
	_mesh = get_node_or_null("Mesh") as MeshInstance3D

	# A cold, wrong glow — this item feels different.
	_glow = OmniLight3D.new()
	_glow.light_color = Color(0.9, 0.2, 0.15)
	_glow.light_energy = 1.2
	_glow.omni_range = 2.5
	_glow.position = Vector3(0, 0.3, 0)
	add_child(_glow)
	_pulse()


func _pulse() -> void:
	if _glow == null:
		return
	if _tween != null:
		_tween.kill()
	var tw := create_tween().set_loops()
	tw.tween_property(_glow, "light_energy", 0.5, 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_glow, "light_energy", 1.2, 0.7).set_trans(Tween.TRANS_SINE)
	_tween = tw


func interact() -> void:
	if _taken:
		return
	_taken = true

	# Collect it — this triggers the employee warning
	var collected := GameState.collect("contract")
	if collected:
		GameState.set_flag("bought_the_last_one")

	# Find the employee and trigger the warning
	_find_and_trigger_employee()

	if _hud != null:
		_hud.call("show_message",
			"THE LAST ONE.\nIt is warm. The label is in a language you do not read.", 4.0)

	# Hide the item
	if _mesh != null:
		_mesh.visible = false
	if _glow != null:
		if _tween != null:
			_tween.kill()
			_tween = null
		_glow.queue_free()
		_glow = null

	# Reveal the trap in a full-screen cutscene, then spawn the contract.
	_reveal_trap()


func _reveal_trap() -> void:
	# The fine print was never invisible ink — it was a contract you can never
	# unread. Play it over black while the player's keys stop moving them.
	var slides: Array[Dictionary] = [
		{"text": "the label bleeds words you can read\nfor the first time.", "min": 1.8},
		{"text": "the fine print was not invisible ink.\nit was a contract\nwritten in a language you never agreed to.", "min": 2.2},
		{"text": "CONGRATULATIONS.\nyou are employed here now.\nyour shift begins at once.", "min": 2.4, "sound": "beep"},
	]
	var cut := get_node_or_null("/root/Cutscene")
	if cut != null and cut.has_method("play") and cut.is_playing() == false:
		cut.play(slides, Callable(self, "_on_trap_revealed"))
	else:
		_on_trap_revealed()


func _on_trap_revealed() -> void:
	GameState.set_flag("trapped_in_shop")
	GameState.set_flag("read_the_fine_print")
	# The contract appears on the counter — the shop script handles this.
	_spawn_contract()


func _find_and_trigger_employee() -> void:
	var root := _scene_root()
	if root == null:
		return
	for c in root.get_children():
		if c.has_method("trigger_warning"):
			c.call("trigger_warning")
			return


func _spawn_contract() -> void:
	# The contract spawns on the counter — the shop script handles this.
	var root := _scene_root()
	if root == null:
		return
	for c in root.get_children():
		if c.has_method("spawn_contract"):
			c.call("spawn_contract")
			return


func _scene_root() -> Node:
	var n: Node = self
	while n.get_parent() != null and n.get_parent() != get_tree().root:
		n = n.get_parent()
	return n
