# systems/shopkeeper.gd — stationary NPC that sells one food item for money.
#
# The diner clerk in map1. Stands behind the counter (idle=true, no patrol),
# and interact() trades cash for a food item in the player's inventory via
# GameState.add_food(). Money gate: if the player can't afford it, the clerk
# tells them how much they need.
extends NPC

@export var food_name := "APPLE"
@export var price := 5
@export var locked_message := "nothing for you right now."
@export var sell_dialogue: Array[String] = ["here. on the house.", "hungry? here."]
@export var poor_dialogue: Array[String] = ["$5. come back when you can afford it."]
@export var serve_once := false   # true = stops selling after one sale
## Ticked when the player first walks up to the clerk — the "find the diner"
## objective comes from proximity, not from the first purchase.
@export var found_flag := "found_diner"

var _sold := false


func _ready() -> void:
	idle = true
	super()


func interact() -> void:
	if food_name == "" or price < 0:
		_say(_pick([locked_message], locked_message), 2.0)
		return
	# ShopUI is a registered autoload, so it lives at /root/ShopUI. Resolve it
	# by path rather than by the global identifier: that keeps this script
	# compiling even if the autoload is mid-reload, and it can never be null in
	# a running game.
	var shop := get_node_or_null("/root/ShopUI")
	if shop != null and shop.has_method("open"):
		shop.call("open", self)
	else:
		_say(_pick(sell_dialogue, "here. on the house."), 2.5)


## Stock rows for the buy UI. Each row: {id, label, price, food, desc} where
## `food` is the hunger fraction restored and `desc` a one-liner. Cheap food
## heals a little, pricier food heals a lot.
func get_stock() -> Array:
	return [
		{"id": "apple",     "label": "Apple",     "price": 2,  "food": 0.15, "desc": "keeps you going"},
		{"id": "hamburger", "label": "Hamburger", "price": 10, "food": 0.50, "desc": "heavy on the gut"},
		{"id": "bread",     "label": "Bread",     "price": 4,  "food": 0.30, "desc": "stale but filling"},
		{"id": "water",     "label": "Water",     "price": 3,  "food": 0.05, "desc": "wet"},
		{"id": "chips",     "label": "Chips",     "price": 6,  "food": 0.25, "desc": "crinkle bag"},
	]


func _on_talk_entered(body: Node3D) -> void:
	super(body)
	# Walking up to the clerk counts as finding the diner, before any purchase.
	var gs := get_node_or_null("/root/GameState")
	if gs != null and found_flag != "" and not gs.has_flag(found_flag):
		gs.set_flag(found_flag)


func _say(text: String, dur: float) -> void:
	if _hud == null or not is_instance_valid(_hud):
		_hud = _find_hud()
	if _hud != null and _hud.has_method("show_message"):
		_hud.call("show_message", text, dur)


func _pick(arr: Array[String], fallback: String = "") -> String:
	if arr.is_empty():
		return fallback
	return arr[randi() % arr.size()]
