# Game board for My Card Game (STS-style Roguelike Deckbuilder)
extends Board

var combat_manager: Node
var _energy_label: Label
var _turn_label: Label
var _end_turn_button: Button


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super._ready()
	counters = $Counters
	cfc.map_node(self)
	# We use the below while to wait until all the nodes we need have been mapped
	# "hand" should be one of them.
	$FancyMovementToggle.button_pressed = cfc.game_settings.fancy_movement
	$OvalHandToggle.button_pressed = cfc.game_settings.hand_use_oval_shape
	$ScalingFocusOptions.selected = cfc.game_settings.focus_style
	$Debug.button_pressed = cfc._debug
	# Generate game seed
	if not cfc.ut:
		cfc.game_rng_seed = CFUtils.generate_random_seed()
		$SeedLabel.text = "Game Seed is: " + cfc.game_rng_seed
	if not cfc.are_all_nodes_mapped:
		await cfc.all_nodes_mapped
	if not cfc.ut and not get_tree().get_root().has_node('RunFromEditor'):
		_setup_combat()
	# warning-ignore:return_value_discarded
	$DeckBuilderPopup.connect('popup_hide', Callable(self, '_on_DeckBuilder_hide'))


# Set up the combat system and UI.
func _setup_combat() -> void:
	# Create CombatManager
	combat_manager = Node.new()
	combat_manager.set_script(load("res://src/custom/CombatManager.gd"))
	combat_manager.board = self
	add_child(combat_manager)

	# Connect combat signals
	combat_manager.connect("energy_changed", Callable(self, "_on_energy_changed"))
	combat_manager.connect("turn_started", Callable(self, "_on_turn_started"))
	combat_manager.connect("turn_ended", Callable(self, "_on_turn_ended"))
	# Auto-inject combat_manager into all newly instanced cards
	cfc.connect("new_card_instanced", Callable(self, "inject_combat_manager"))

	# Create combat UI elements
	_create_combat_ui()

	# Load starting deck, then start combat
	load_starting_deck()
	# Wait a frame for cards to settle
	await get_tree().process_frame
	combat_manager.start_combat()


func _create_combat_ui() -> void:
	var viewport_size: Vector2 = Vector2(get_viewport().size)

	# Energy label (top-center area)
	_energy_label = Label.new()
	_energy_label.name = "EnergyLabel"
	_energy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_energy_label.position = Vector2(viewport_size.x / 2 - 60, 10)
	_energy_label.size = Vector2(120, 40)
	_energy_label.add_theme_font_size_override("font_size", 28)
	# Use a distinctive color for energy
	_energy_label.add_theme_color_override("font_color", Color(1, 0.85, 0))
	_energy_label.text = "⚡ 0/3"
	add_child(_energy_label)

	# Turn label (top-center, below energy)
	_turn_label = Label.new()
	_turn_label.name = "TurnLabel"
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_label.position = Vector2(viewport_size.x / 2 - 60, 50)
	_turn_label.size = Vector2(120, 25)
	_turn_label.add_theme_font_size_override("font_size", 16)
	_turn_label.text = "Turn 0"
	add_child(_turn_label)

	# End Turn button (bottom-right, near discard pile)
	_end_turn_button = Button.new()
	_end_turn_button.name = "EndTurnButton"
	_end_turn_button.text = "End Turn"
	_end_turn_button.position = Vector2(viewport_size.x - 170, viewport_size.y - 280)
	_end_turn_button.size = Vector2(120, 50)
	_end_turn_button.add_theme_font_size_override("font_size", 18)
	_end_turn_button.connect("pressed", Callable(self, "_on_EndTurn_pressed"))
	# Disabled until first turn starts
	_end_turn_button.disabled = true
	add_child(_end_turn_button)

	# Hide demo buttons that aren't needed for combat
	_hide_demo_buttons()


func _hide_demo_buttons() -> void:
	# Hide CGF demo/debug UI — they still exist for development but aren't shown
	var demo_nodes := [
		"FancyMovementToggle",
		"EnableAttach",
		"ScalingFocusOptions",
		"ReshuffleAllDeck",
		"ReshuffleAllDiscard",
		"OvalHandToggle",
		"DeckBuilder",
		"Debug",
		"PlacementGridDemo",
		"ModifiedLabelGrid",
		"SeedLabel",
	]
	for node_name in demo_nodes:
		var node := get_node_or_null(node_name)
		if node:
			node.visible = false


# --- Combat signal handlers ---

func _on_energy_changed(current: int, max_energy: int) -> void:
	if _energy_label:
		_energy_label.text = "⚡ %d/%d" % [current, max_energy]
	# Update all hand cards' cost display
	_notify_hand_cards_cost_update()


func _on_turn_started(turn_num: int) -> void:
	if _turn_label:
		_turn_label.text = "Turn %d" % turn_num
	if _end_turn_button:
		_end_turn_button.disabled = false


func _on_turn_ended() -> void:
	if _end_turn_button:
		_end_turn_button.disabled = true


func _on_EndTurn_pressed() -> void:
	if combat_manager and combat_manager.is_player_turn:
		combat_manager.end_turn()


# After energy changes, re-check costs for all cards in hand
# so the card border color reflects affordability.
func _notify_hand_cards_cost_update() -> void:
	if not cfc.NMAP.has("hand"):
		return
	for card in cfc.NMAP.hand.get_all_cards():
		if is_instance_valid(card):
			# Trigger a re-check by toggling focus (framework refreshes glow)
			if card.state == Card.CardState.FOCUSED_IN_HAND:
				card.set_focus(true, card.check_play_costs())


# Inject combat_manager reference into newly instanced cards.
# Connected to cfc.new_card_instanced signal for automatic injection.
func inject_combat_manager(card: Card) -> void:
	if combat_manager and is_instance_valid(card):
		card.combat_manager = combat_manager


# --- Original CGFBoard methods (kept for compatibility) ---

# This function is to avoid relating the logic in the card objects
# to a node which might not be there in another game
func _on_FancyMovementToggle_toggled(_button_pressed) -> void:
	cfc.set_setting('fancy_movement', $FancyMovementToggle.button_pressed)


func _on_OvalHandToggle_toggled(_button_pressed: bool) -> void:
	cfc.set_setting("hand_use_oval_shape", $OvalHandToggle.button_pressed)
	for c in cfc.NMAP.hand.get_all_cards():
		c.reorganize_self()


# Reshuffles all Card objects created back into the deck
func _on_ReshuffleAllDeck_pressed() -> void:
	reshuffle_all_in_pile(cfc.NMAP.deck)


func _on_ReshuffleAllDiscard_pressed() -> void:
	reshuffle_all_in_pile(cfc.NMAP.discard)

func reshuffle_all_in_pile(pile: Pile = cfc.NMAP.deck):
	for c in get_tree().get_nodes_in_group("cards"):
		if c.get_parent() != pile and c.state != Card.CardState.DECKBUILDER_GRID:
			c.move_to(pile)
			await get_tree().create_timer(0.1).timeout
	# Last card in, is the top card of the pile
	var last_card : Card = pile.get_top_card()
	if last_card._tween and last_card._tween.is_running():
		await last_card._tween.finished
	await get_tree().create_timer(0.2).timeout
	pile.shuffle_cards()


# Button to change focus mode
func _on_ScalingFocusOptions_item_selected(index) -> void:
	cfc.set_setting('focus_style', index)


# Button to make all cards act as attachments
func _on_EnableAttach_toggled(button_pressed: bool) -> void:
	for c in get_tree().get_nodes_in_group("cards"):
		if button_pressed:
			c.attachment_mode = Card.AttachmentMode.ATTACH_BEHIND
		else:
			c.attachment_mode = Card.AttachmentMode.DO_NOT_ATTACH


func _on_Debug_toggled(button_pressed: bool) -> void:
	cfc._debug = button_pressed

# Loads the starting deck: 5 Strike + 4 Defend + 1 Bash
func load_starting_deck() -> void:
	var starting_deck := [
		"Strike", "Strike", "Strike", "Strike", "Strike",
		"Defend", "Defend", "Defend", "Defend",
		"Bash",
	]
	for card_name in starting_deck:
		var card = cfc.instance_card(card_name)
		# Inject combat_manager into each card for click-to-play
		inject_combat_manager(card)
		cfc.NMAP.deck.add_child(card)
		card._determine_idle_state()

func _on_DeckBuilder_pressed() -> void:
	cfc.game_paused = true
	$DeckBuilderPopup.popup_centered_clamped()

func _on_DeckBuilder_hide() -> void:
	cfc.game_paused = false


func _on_BackToMain_pressed() -> void:
	cfc.quit_game()
	get_tree().change_scene_to_file("res://src/custom/MainMenu.tscn")
