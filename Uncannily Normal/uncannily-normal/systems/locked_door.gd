
extends "res://systems/door.gd"

@export var requires_flag := ""            
@export var locked_prompt := "[E]  LOCKED"
@export var open_prompt := "[E]  DOOR"
@export var locked_message := "it won't budge."
@export var auto_relock := false          

var _trigger: Area3D
var _in_range := false
var _unlocked := false
var _hud: Node


func _ready() -> void:
	super()
	_trigger = get_node_or_null("Trigger")
	if _trigger is Area3D:
		_trigger.collision_layer = 0
		_trigger.collision_mask = 1
		if not _trigger.body_entered.is_connected(_on_body_entered):
			_trigger.body_entered.connect(_on_body_entered)
			_trigger.body_exited.connect(_on_body_exited)
	_check_lock()
	prompt = open_prompt if _unlocked else locked_prompt


func _check_lock() -> void:
	_unlocked = (requires_flag == "" or GameState.has_flag(requires_flag))


func _on_body_entered(body: Node3D) -> void:
	if not body.has_method("move_and_slide"):
		return
	_in_range = true
	_push_prompt(prompt if _unlocked else locked_prompt)


func _on_body_exited(body: Node3D) -> void:
	if not body.has_method("move_and_slide"):
		return
	_in_range = false
	_push_prompt("")


func _unhandled_input(event: InputEvent) -> void:
	if not _in_range or not event.is_action_pressed("interact"):
		return
	if not _unlocked:
		_check_lock()
		if not _unlocked:
			_say(locked_message, 2.0)
			return
	open()
	_say("the door opens.", 1.5)
	if auto_relock:
		await get_tree().create_timer(1.5).timeout
		close()


func open() -> void:
	if _col != null and is_instance_valid(_col):
		_col.set_deferred("disabled", true)
	if _mesh != null and is_instance_valid(_mesh):
		_mesh.visible = false


func close() -> void:
	if _col != null and is_instance_valid(_col):
		_col.set_deferred("disabled", false)
	if _mesh != null and is_instance_valid(_mesh):
		_mesh.visible = true


func _push_prompt(text: String) -> void:
	if _hud == null or not is_instance_valid(_hud):
		_hud = _find_hud()
	if _hud != null and _hud.has_method("set_prompt"):
		_hud.call("set_prompt", text)


func _say(text: String, dur: float) -> void:
	if _hud == null or not is_instance_valid(_hud):
		_hud = _find_hud()
	if _hud != null and _hud.has_method("show_message"):
		_hud.call("show_message", text, dur)


func _find_hud() -> Node:
	var root := get_tree().current_scene
	if root == null:
		root = get_tree().root
	return _search(root, "set_prompt")


func _search(n: Node, method: String) -> Node:
	if n.has_method(method):
		return n
	for c in n.get_children():
		var f := _search(c, method)
		if f != null:
			return f
	return null
