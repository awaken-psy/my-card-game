extends Card

# CombatManager reference, set by CGFBoard during setup
var combat_manager: Node = null


func _ready() -> void:
	super._ready()
	# Disable framework's drag-from-hand behavior (we use click-to-play)
	disable_dragging_from_hand = true
	# Prevent cards from being placed on the board
	board_placement = BoardPlacement.NONE


# STS-style click-to-play override.
# Instead of the framework's drag-and-drop, a single left-click on a
# focused card in hand will attempt to play it (if enough energy).
func _on_Card_gui_input(event) -> void:
	if event is InputEventMouseButton and cfc.NMAP.has("board"):
		# Z-index check: forward input to the actually focused card
		if cfc.NMAP.board.mouse_pointer.current_focused_card \
				and self != cfc.NMAP.board.mouse_pointer.current_focused_card:
			cfc.NMAP.board.mouse_pointer.current_focused_card._on_Card_gui_input(event)
			return

		if event.get_button_index() == 1:
			# Left click: play card on release while focused in hand
			if not event.is_pressed() and state == CardState.FOCUSED_IN_HAND:
				_try_play_card()
			# For other states (on board, in pile), let framework handle it
			elif state not in [CardState.IN_HAND, CardState.FOCUSED_IN_HAND]:
				super._on_Card_gui_input(event)
			return

		# Right-click: targeting arrow (for future M4/M5)
		if event.get_button_index() == 2:
			if event.is_pressed():
				targeting_arrow.initiate_targeting()
			else:
				targeting_arrow.complete_targeting()
			return
	# For other event types, use framework default
	super._on_Card_gui_input(event)


# Attempt to play this card via the combat manager.
func _try_play_card() -> void:
	if not combat_manager:
		return
	if combat_manager.can_play_card(self):
		combat_manager.play_card(self)


# Override cost check to use energy system instead of framework's credits.
func check_play_costs() -> Color:
	if not combat_manager:
		return CFConst.CostsState.IMPOSSIBLE
	if combat_manager.can_play_card(self):
		return CFConst.CostsState.OK
	else:
		return CFConst.CostsState.IMPOSSIBLE


# Sample code on how to ensure costs are paid when a card
# is dragged from hand to the table (kept for compatibility)
func common_move_scripts(new_container: Node, old_container: Node) -> void:
	if new_container == cfc.NMAP.board and old_container == cfc.NMAP.hand:
		pay_play_costs()


# Sample code on how to figure out costs of a card
func get_modified_credits_cost() -> int:
	var modified_cost : int = properties.get("Cost", 0)
	return(modified_cost)


# This sample function ensures all costs defined by a card are paid.
func pay_play_costs() -> void:
	cfc.NMAP.board.counters.mod_counter("credits", -get_modified_credits_cost())
