# Game board for My Card Game (STS-style Roguelike Deckbuilder)
extends Board

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super._ready()
	counters = $Counters
	cfc.map_node(self)
	# We use the below while to wait until all the nodes we need have been mapped
	# "hand" should be one of them.
	# We're assigning our positions programmatically,
	# instead of defining them on the scene.
	# This way any they will work with any size of viewport in a game.
	# Discard pile goes bottom right
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
		load_starting_deck()
	# warning-ignore:return_value_discarded
	$DeckBuilderPopup.connect('popup_hide', Callable(self, '_on_DeckBuilder_hide'))



# This function is to avoid relating the logic in the card objects
# to a node which might not be there in another game
# You can remove this function and the FancyMovementToggle button
# without issues
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
