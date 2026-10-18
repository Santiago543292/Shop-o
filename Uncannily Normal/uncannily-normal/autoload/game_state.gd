extends Node

## Uncannily Normal — game state
##
## The story follows the lore:
##   MAP 0  THE BUS STOP   — wake up at night, find the bus stop
##   MAP 1  THE STREETS    — explore, get hungry, find the diner, see weird things
##   MAP 2  THE SHOP       — buy the list, the last one traps you, you work here
##   ESCAPE THE OUT       — night falls, find a way out before the monster finds you
##
## Everything reads from here so no system disagrees about where the player is.

signal list_changed()
signal act_changed(id: String)
signal flag_changed(name: String, value: bool)
signal hunger_changed(value: float)
signal money_changed(value: int)
signal inventory_changed()

# --- MAPS -------------------------------------------------------------------

const MAPS: Array[Dictionary] = [
	{
		"id": "map0",
		"title": "THE BUS STOP",
		"objective": "FIND THE BUS STOP",
		"blurb": "you wake up at night. the street is empty. the bus is coming.",
		"scene": "res://scenes/map0.tscn",
	},
	{
		"id": "map1",
		"title": "THE STREETS",
		"objective": "FIND THE DINER — YOU ARE HUNGRY",
		"blurb": "you need food. the diner is open.",
		"scene": "res://scenes/map1.tscn",
	},
	{
		"id": "map2",
		"title": "THE SHOP",
		"objective": "BUY EVERYTHING ON THE LIST",
		"blurb": "the store is open.",
		"scene": "res://scenes/map2.tscn",
	},
	{
		"id": "escape",
		"title": "THE WAY OUT",
		"objective": "FIND A WAY OUT BEFORE THE MONSTER FINDS YOU",
		"blurb": "night falls. the shop is different. find the exit.",
		"scene": "res://scenes/map2.tscn",
	},
]

# --- THE LIST ---------------------------------------------------------------

const LIST: Array[Dictionary] = [
	{"id": "milk",     "label": "MILK",         "trap": false},
	{"id": "bread",    "label": "BREAD",        "trap": false},
	{"id": "pickles",  "label": "PICKLES",      "trap": false},
	{"id": "soap",     "label": "SOAP",         "trap": false},
	{"id": "eggs",     "label": "EGGS",         "trap": false},
	{"id": "candles",  "label": "CANDLES",      "trap": false},
	{"id": "contract", "label": "THE LAST ONE", "trap": true},
]

# Food table: what each food item heals (fraction of hunger, 0.0–1.0) plus its
# display label and a one-line description. Used by the inventory eat action.
const FOOD: Dictionary = {
	"apple":     {"label": "Apple",     "food": 0.15, "desc": "keeps you going"},
	"hamburger": {"label": "Hamburger", "food": 0.50, "desc": "heavy on the gut"},
	"bread":     {"label": "Bread",     "food": 0.30, "desc": "stale but filling"},
	"water":     {"label": "Water",     "food": 0.05, "desc": "wet"},
	"chips":     {"label": "Chips",     "food": 0.25, "desc": "crinkle bag"},
}


# --- STATE ------------------------------------------------------------------

var current_map := "map0"
var collected: Array[String] = []
var flags: Dictionary = {}
var hunger := 1.0          # 1.0 = full, 0.0 = starving
var is_night := true
var customers_served := 0
var escape_unlocked := false

# Money and carried things live here so the HUD and the inventory panel read
# the SAME number — two copies is how a counter stops adding up.
var money := 0
var food: Array[String] = []
var items: Array[String] = []


# --- money ------------------------------------------------------------------

func add_money(amount: int) -> void:
	money += amount
	money_changed.emit(money)


func spend_money(amount: int) -> bool:
	if money < amount:
		return false
	money -= amount
	money_changed.emit(money)
	return true


# --- carried things ---------------------------------------------------------

func add_food(food_name: String) -> void:
	food.append(food_name)
	inventory_changed.emit()


func remove_food(food_name: String) -> void:
	food.erase(food_name)
	inventory_changed.emit()


## Eat one carried food item: restores hunger by its FOOD value and removes it
## from the inventory. Returns false if the item isn't food or isn't carried.
func eat(food_name: String) -> bool:
	if food_name == "" or not food.has(food_name) or not FOOD.has(food_name):
		return false
	var amt := float(FOOD[food_name].get("food", 0.0))
	set_hunger(hunger + amt)   # set_hunger clamps to [0,1] and emits hunger_changed
	remove_food(food_name)
	return true


func add_item(item_name: String) -> void:
	items.append(item_name)
	inventory_changed.emit()


func remove_item(item_name: String) -> void:
	items.erase(item_name)
	inventory_changed.emit()


# --- the list ---------------------------------------------------------------

func list() -> Array[Dictionary]:
	return LIST


func trap_entry() -> Dictionary:
	for e in LIST:
		if bool(e.get("trap", false)):
			return e
	return {}


func has_collected(id: String) -> bool:
	return collected.has(id)


func collect(id: String) -> bool:
	if collected.has(id):
		return false
	collected.append(id)
	list_changed.emit()
	return true


func normal_progress() -> Vector2i:
	var need := 0
	var have := 0
	for e in LIST:
		if bool(e.get("trap", false)):
			continue
		need += 1
		if collected.has(str(e["id"])):
			have += 1
	return Vector2i(have, need)


func all_normal_collected() -> bool:
	var p := normal_progress()
	return p.x >= p.y and p.y > 0


func list_complete() -> bool:
	return collected.size() >= LIST.size()


# --- hunger -----------------------------------------------------------------

func set_hunger(value: float) -> void:
	hunger = clampf(value, 0.0, 1.0)
	hunger_changed.emit(hunger)


func is_hungry() -> bool:
	return hunger < 0.4


func is_starving() -> bool:
	return hunger <= 0.0


# --- flags ------------------------------------------------------------------

func has_flag(name: String) -> bool:
	return bool(flags.get(name, false))


func set_flag(name: String, value: bool = true) -> void:
	if bool(flags.get(name, false)) == value:
		return
	flags[name] = value
	flag_changed.emit(name, value)


# --- maps -------------------------------------------------------------------

func map_record(id: String) -> Dictionary:
	for a in MAPS:
		if str(a["id"]) == id:
			return a
	return {}


func map_scene(id: String) -> String:
	return str(map_record(id).get("scene", ""))


func set_map(id: String) -> void:
	if current_map == id:
		return
	current_map = id
	act_changed.emit(id)


func next_map_after(id: String) -> String:
	for i in MAPS.size():
		if str(MAPS[i]["id"]) == id and i + 1 < MAPS.size():
			return str(MAPS[i + 1]["id"])
	return ""


func next_scene(id: String) -> String:
	for i in MAPS.size():
		if str(MAPS[i]["id"]) == id and i + 1 < MAPS.size():
			return str(MAPS[i + 1]["scene"])
	return ""


# --- escape -----------------------------------------------------------------

func unlock_escape() -> void:
	escape_unlocked = true
	set_flag("escape_unlocked")


func is_escape_unlocked() -> bool:
	return escape_unlocked or has_flag("escape_unlocked")


# --- reset ------------------------------------------------------------------

func reset() -> void:
	collected.clear()
	flags.clear()
	current_map = "map0"
	hunger = 1.0
	is_night = true
	customers_served = 0
	escape_unlocked = false
	money = 0
	food.clear()
	items.clear()
	list_changed.emit()
	act_changed.emit(current_map)
	hunger_changed.emit(hunger)
	money_changed.emit(money)
	inventory_changed.emit()
