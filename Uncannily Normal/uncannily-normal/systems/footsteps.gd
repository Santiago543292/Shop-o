extends Node

## Footsteps — a step for every stride, in a varying order.
##
## Sits beside the controller and watches its velocity: while the player is
## moving on the floor, a step fires on a timer. The timer shortens when
## sprinting so the rhythm reads as faster movement.
##
## The three sounds are cycled through a shuffled queue by GameAudio, so they
## come out in a different order every lap and never repeat back to back.

@export var walk_interval := 0.42
@export var sprint_interval := 0.30
@export var min_speed := 0.6

var _controller: CharacterBody3D
var _timer := 0.0
var _sprinting := false


func _ready() -> void:
	_controller = _find_controller()
	# Start ambience as soon as the player exists — the night bed should be
	# running before the first step lands.
	GameAudio.start_ambience()


func _physics_process(delta: float) -> void:
	if _controller == null or not is_instance_valid(_controller):
		_controller = _find_controller()
		if _controller == null:
			return

	var planar := Vector2(_controller.velocity.x, _controller.velocity.z).length()
	_sprinting = Input.is_action_pressed("_sprint")

	if not _controller.is_on_floor() or planar < min_speed:
		# Standing still, or in the air: arm the timer so the first step of a
		# new movement lands a beat later rather than instantly.
		_timer = 0.06
		return

	_timer -= delta
	if _timer <= 0.0:
		GameAudio.play_footstep()
		_timer = sprint_interval if _sprinting else walk_interval


func _find_controller() -> CharacterBody3D:
	var n: Node = self
	for i in range(6):
		n = n.get_parent()
		if n == null:
			return null
		var c := _search(n)
		if c != null:
			return c
	return null


func _search(n: Node) -> CharacterBody3D:
	if n is CharacterBody3D:
		return n
	for c in n.get_children():
		var f := _search(c)
		if f != null:
			return f
	return null
