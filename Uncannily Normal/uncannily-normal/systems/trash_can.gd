extends "res://systems/interactable.gd"


@export var money_min := 17
@export var money_max := 25

var _searched := false


func _ready() -> void:
	super()
	prompt = "[E]  SEARCH"


func interact() -> void:
	if _searched:
		_push_prompt("")
		if _hud != null:
			_hud.call("show_message", "Nothing left in here.", 1.5)
		return
	_searched = true

	# Rummaging is the loudest thing about searching a bin — the money reveal
	# comes after, so the sound lands first and the payoff follows it.
	GameAudio.play_search()

	var amount := randi_range(money_min, money_max)
	GameState.add_money(amount)

	if _hud != null:
		_hud.call("show_message", "Found $%d in the trash.\nTotal: $%d" % [amount, GameState.money], 2.5)

	# Dim the can so it reads as searched
	var mesh := get_node_or_null("Mesh") as MeshInstance3D
	if mesh != null:
		mesh.modulate = Color(0.4, 0.4, 0.4, 1)
