# systems/npc.gd — generic NPC.
#
# A CharacterBody3D that patrols a set of waypoint Markers (ping-pong, or
# stands still if none / idle=true) and answers [E] with a cycling line of
# dialogue routed through whichever HUD is found anywhere in the tree.
#
# Scene layout (npc.tscn):
#   NPC(CharacterBody3D, npc.gd)
#     Collision  CollisionShape3D  (capsule — physics)
#     Mesh       MeshInstance3D     (low-poly capsule fallback visual)
#     Model       Node3D             (holds the Walking.fbx character mesh)
#     Talk       Area3D            (sphere trigger → prompt + E)
#     TalkCol    CollisionShape3D  (child of Talk)
#
# Subclass for clerks / shopkeepers / walkers and override interact().
extends CharacterBody3D
class_name NPC

const DEFAULT_LINES: Array[String] = [
	"such a busy night right?",
	"not many out at this hour.",
	"you look tired.",
	"I wasn't going to stop for anyone.",
	"Hello",
	"hmmm?",
	
]

const FBX_PATH := "res://Assets/animations/Walking.fbx"
## How close the player must be to talk. Enforced in code as well as by the
## Talk Area3D, so a resize in the editor can't make NPCs answer from across
## the map.
const TALK_RADIUS := 3.5

@export var walk_speed := 2.6
@export var waypoint: NodePath             # if set, patrol spawn<->this point
@export var dialogue: Array[String] = []   # empty -> DEFAULT_LINES
@export var idle := false                  # true = never moves
@export var prompt_text := "[E]  TALK"
@export var settle_time := 0.5
@export var tint: Color = Color(1, 1, 1, 1)   # white = keep the FBX's own albedo

var _player: Node3D
var _hud: Node
var _wp: Node3D
var _origin: Vector3
var _to_target := true
var _settle := 0.0
var _in_range := false
var _line := 0

# FBX character model + walk animation (the NPC animates instead of t-posing).
var _fbx_model: Node3D
var _fbx_anim: AnimationPlayer
var _walk_anim := ""


func _ready() -> void:
	_player = _find_player()
	_hud = _find_hud()
	_origin = global_position
	if waypoint != NodePath(""):
		var n = get_node_or_null(waypoint)
		if n is Node3D:
			_wp = n
	if _wp == null:
		idle = true
	var talk: Area3D = get_node_or_null("Talk")
	if talk is Area3D:
		talk.collision_layer = 0
		talk.collision_mask = 1
		talk.monitoring = true
		# Enforce the radius here: the editor keeps resizing the collision shape,
		# which made the prompt (and the E key) reach from across the map.
		var tcol := talk.get_node_or_null("TalkCol") as CollisionShape3D
		if tcol != null:
			var sphere := SphereShape3D.new()
			sphere.radius = 3.5
			tcol.shape = sphere
		if not talk.body_entered.is_connected(_on_talk_entered):
			talk.body_entered.connect(_on_talk_entered)
			talk.body_exited.connect(_on_talk_exited)
	_load_fbx()


func _physics_process(delta: float) -> void:
	if idle or _wp == null:
		# Hold position. Deliberately NO move_and_slide() while idle: the
		# engine's penetration recovery would shove the NPC out of any overlap
		# (the player walking into the clerk), and an idle NPC must never move.
		velocity = Vector3.ZERO
	else:
		_patrol(delta)
	_sync_anim()


func _patrol(delta: float) -> void:
	var target := _wp.global_position if _to_target else _origin
	var to := target - global_position
	to.y = 0.0
	if to.length() <= 0.45:
		_settle -= delta
		if _settle <= 0.0:
			_to_target = !_to_target
			_settle = settle_time
		velocity = Vector3.ZERO
	else:
		velocity = to.normalized() * walk_speed
		_look(to)
	move_and_slide()


func _look(dir: Vector3) -> void:
	if dir.length_squared() < 0.0001:
		return
	rotation.y = atan2(dir.x, dir.z)


# Plays the FBX walk cycle while the NPC is translating, stops it when idle.
func _sync_anim() -> void:
	if _fbx_anim == null or _walk_anim == "":
		return
	var moving := velocity.length() > 0.15
	if moving:
		if not _fbx_anim.is_playing():
			_fbx_anim.play(_walk_anim)
	elif _fbx_anim.is_playing():
		_fbx_anim.stop()


# Loads Walking.fbx into the Model node and grabs its walk animation. No-op
# when there is no Model node (stand-alone Shopkeeper) or the FBX can't load —
# the low-poly capsule Mesh then stays visible.
func _load_fbx() -> void:
	var model := get_node_or_null("Model") as Node3D
	if model == null:
		return
	var ps := load(FBX_PATH) as PackedScene
	if ps == null:
		return
	var inst := ps.instantiate() as Node3D
	if inst == null:
		return
	model.add_child(inst)
	_fbx_model = inst
	# Keep the capsule fallback visible unless the FBX actually carries a
	# mesh, so the NPC is never invisible to the player.
	if _has_mesh(inst):
		var capsule := get_node_or_null("Mesh") as MeshInstance3D
		if capsule != null:
			capsule.visible = false
		_apply_fbx_tint(inst)
	_fbx_anim = _find_animation_player(inst)
	if _fbx_anim != null and _walk_anim == "" and _fbx_anim.get_animation_list().size() > 0:
		_walk_anim = _fbx_anim.get_animation_list()[0]


func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for c in root.get_children():
		var r := _find_animation_player(c)
		if r != null:
			return r
	return null


# True when the instanced FBX scene contains a renderable mesh (static or
# skinned), so the low-poly capsule fallback is only hidden for real models.
func _has_mesh(root: Node) -> bool:
	if root is MeshInstance3D:
		return true
	for c in root.get_children():
		if _has_mesh(c):
			return true
	return false


# Tints the FBX's visible mesh by this NPC's `tint`. A white tint (the default)
# leaves the model's materials untouched, so a plain walker keeps its albedo
# while a shopkeeper can be tinted distinctively (dark blue) instead of looking
# identical to every other character.
func _apply_fbx_tint(inst: Node3D) -> void:
	if inst == null or tint.a <= 0.0:
		return
	if tint.r == 1.0 and tint.g == 1.0 and tint.b == 1.0:
		return
	for c in inst.get_children():
		if c is MeshInstance3D:
			var gi := c as GeometryInstance3D
			if gi.material_override == null:
				var m := StandardMaterial3D.new()
				m.albedo_color = tint
				gi.material_override = m
			elif gi.material_override is StandardMaterial3D:
				(gi.material_override as StandardMaterial3D).albedo_color = tint
			break


func _on_talk_entered(body: Node3D) -> void:
	if not body.has_method("move_and_slide"):
		return
	_in_range = true
	_push_prompt(prompt_text)


func _on_talk_exited(body: Node3D) -> void:
	if not body.has_method("move_and_slide"):
		return
	_in_range = false
	_push_prompt("")


func _unhandled_input(event: InputEvent) -> void:
	# While the player's inventory is open, E belongs to eating — NPCs must not
	# also answer it.
	if not _in_range or not event.is_action_pressed("interact") or _inventory_open():
		return
	# Belt and braces: the Talk Area3D can be resized by the editor, so also
	# require the player to actually be within talking distance.
	if _player != null and _player.global_position.distance_to(global_position) > TALK_RADIUS + 0.5:
		return
	interact()


func _inventory_open() -> bool:
	var p := _find_player()
	if p == null:
		return false
	var inv := p.get_node_or_null("Inventory")
	return inv != null and inv.has_method("is_open") and bool(inv.call("is_open"))


func _push_prompt(text: String) -> void:
	_hud = _find_hud()
	if _hud != null and _hud.has_method("set_prompt"):
		_hud.call("set_prompt", text)


func interact() -> void:
	var lines: Array[String] = dialogue
	if lines.is_empty():
		lines = DEFAULT_LINES
	var line := lines[_line % lines.size()]
	_line += 1
	if _hud == null or not is_instance_valid(_hud):
		_hud = _find_hud()
	if _hud != null and _hud.has_method("show_message"):
		_hud.call("show_message", line, 2.5)


func _find_player() -> Node3D:
	# The player is a Node3D wrapper whose controller is a CHILD of it, so a
	# shallow scan of the scene root finds nothing — search by class instead.
	var root := _scene_root()
	if root == null:
		root = get_tree().root
	var found := root.find_children("*", "PlayerController3D", true, false)
	if found.size() > 0:
		return found[0]
	return null


func _scene_root() -> Node:
	var n: Node = self
	while n.get_parent() != null and n.get_parent() != get_tree().root:
		n = n.get_parent()
	return n


func _find_hud() -> Node:
	var root := _scene_root()
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
