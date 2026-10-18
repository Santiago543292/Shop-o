# ui/shop_ui.gd — the shopkeeper's buy screen.
#
# A right-side panel (same dock as the inventory, but exclusive) that lists the
# stock of whatever Shopkeeper is being talked to and lets the player buy food.
# Purchases debit GameState money and add the food item to GameState.food, so the
# existing inventory panel and the food->eat hook pick them up automatically.
#
# Open:  call ShopUI.open(keeper) with any node exposing
#        `get_stock() -> Array` (entries {id, label, price}). The Shopkeeper
#        returns its single food item this way.
# Close: Escape, Back button, or when the player walks out of range.

extends CanvasLayer
const UIStyle := preload("res://ui/ui_style.gd")

var _panel: PanelContainer
var _list: VBoxContainer
var _keeper: Node
var _open := false

func _ready() -> void:
	layer = 12
	_build()
	GameState.inventory_changed.connect(_on_inventory_changed)

func _build() -> void:
	# Full-rect root so the panel's CENTER_RIGHT anchors resolve against the
	# viewport. Clicks outside the panel pass through to the game.
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_panel = UIStyle.make_panel()
	# Centred rather than docked right: the old right-edge dock ran into the
	# HUD's money panel (top-right) and sat exactly on top of the inventory
	# panel, so the two read as one overlapping mess.
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -220
	_panel.offset_right = 220
	_panel.offset_top = -230
	_panel.offset_bottom = 230
	_panel.modulate.a = 0.0
	_panel.visible = false
	root.add_child(_panel)

	# One column so the title, the stock rows and CLOSE can never overlap.
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_panel.add_child(col)

	col.add_child(UIStyle.make_label("SHOP", UIStyle.SIZE_SUB, UIStyle.COL_REC))
	col.add_child(UIStyle.make_rule())

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	col.add_child(_list)

	var close_btn = UIStyle.make_button("CLOSE")
	close_btn.pressed.connect(close)
	col.add_child(close_btn)

func _process(delta: float) -> void:
	var target := 1.0 if _open else 0.0
	var t := lerpf(_panel.modulate.a, target, clampf(delta * 12.0, 0.0, 1.0))
	_panel.modulate.a = t
	_panel.visible = t > 0.01
	# Safety net: keep the cursor free for as long as the panel is up, even if
	# the controller was never found and keeps re-capturing it.
	if _open and Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func open(keeper: Node) -> void:
	_keeper = keeper
	_refresh_list()
	_open = true
	_show()
	_set_cursor(true)
	# Keep the prompt bar clear while shopping.
	if _hud():
		_hud().call("set_prompt", "")

func _refresh_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	var stock: Array = []
	if _keeper != null and _keeper.has_method("get_stock"):
		stock = _keeper.call("get_stock")
	if stock.is_empty():
		_list.add_child(UIStyle.make_label("nothing to sell.", UIStyle.SIZE_SMALL, UIStyle.COL_TEXT_DIM))
		return
	for entry in stock:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var label := str(entry.get("label", entry.get("id", "?")))
		var heal := ""
		if entry.has("food"):
			heal = "  (+%d%%)" % int(float(entry.get("food", 0.0)) * 100.0)
		row.add_child(UIStyle.make_label(label + heal + "  $" + str(entry.get("price", 0)), UIStyle.SIZE_SMALL, UIStyle.COL_TEXT))
		var buy = UIStyle.make_button("BUY")
		buy.disabled = not _can_afford(entry)
		buy.pressed.connect(_on_buy.bind(entry))
		row.add_child(buy)
		_list.add_child(row)

func _can_afford(entry: Dictionary) -> bool:
	return GameState.money >= int(entry.get("price", 0))

func _on_buy(entry: Dictionary) -> void:
	var price := int(entry.get("price", 0))
	if GameState.money < price:
		return
	if not GameState.spend_money(price):
		return
	var id := str(entry.get("id", ""))
	if id != "":
		GameState.add_food(id)
	_open = false
	close()

func close() -> void:
	_open = false
	_set_cursor(false)
	if _keeper == null or not is_instance_valid(_keeper):
		return
	# Restore the prompt if the player is still near the keeper.
	var talk = _keeper.get_node_or_null("Talk")
	var player := _player_ref()
	if talk != null and player != null and talk.overlaps_body(player):
		if _keeper.has_method("prompt_text"):
			if _hud():
				_hud().call("set_prompt", _keeper.get("prompt_text"))

func _input(event: InputEvent) -> void:
	if _open and event.is_action_pressed("ui_cancel"):
		close()

func _show() -> void:
	# The panel fades itself in (see _process); the layer just has to keep
	# receiving input while the game is paused or a cutscene is playing.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _set_cursor(free: bool) -> void:
	# The first-person controller re-captures the mouse every physics frame, so
	# showing the cursor is not enough — it has to be told to stop. Find it by
	# property (not by name) and set the flag; also set the mode directly so the
	# cursor is free even if the controller is never found.
	var pc := _player_controller()
	if pc != null:
		pc.set("disable_mouse_control", free)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if free else Input.MOUSE_MODE_CAPTURED


func _player_controller() -> Node:
	# The first-person controller is the only node of this class in the scene.
	# Look it up by class (not by name) so it is found no matter how the player
	# scene is arranged.
	var root := get_tree().current_scene
	if root == null:
		root = get_tree().root
	var found := root.find_children("*", "PlayerController3D", true, false)
	if found.size() > 0:
		return found[0]
	return _search_prop(root, "disable_mouse_control")


func _search_prop(n: Node, prop: String) -> Node:
	if n.get(prop) != null:
		return n
	for c in n.get_children():
		var f := _search_prop(c, prop)
		if f != null:
			return f
	return null

func _on_inventory_changed() -> void:
	if _open:
		_refresh_list()

func _hud() -> Node:
	var r = get_tree().current_scene
	if r == null:
		r = get_tree().root
	return _search(r)

func _search(n: Node) -> Node:
	if n.has_method("set_prompt"):
		return n
	for c in n.get_children():
		var f = _search(c)
		if f != null:
			return f
	return null

func _player_ref() -> Node:
	# The player is a Node3D wrapper whose controller is a CHILD of it, so a
	# shallow scan of the scene root finds nothing — search recursively by class.
	var r := get_tree().current_scene
	if r == null:
		r = get_tree().root
	var found := r.find_children("*", "PlayerController3D", true, false)
	if found.size() > 0:
		return found[0]
	return null
