# Game board for My Card Game (STS-style Roguelike Deckbuilder)
extends Board

var combat_manager: Node
var _energy_label: Label
var _turn_label: Label
var _end_turn_button: Button
# Player stat labels
var _player_hp_label: Label

# Preload combat entity script (class_name removed due to load-order issues)
const _CombatEntity = preload("res://src/custom/CombatEntity.gd")
var _player_block_label: Label
var _player_status_label: Label
# Enemy stat labels
var _enemy_name_label: Label
var _enemy_hp_label: Label
var _enemy_block_label: Label
var _enemy_status_label: Label


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
	# Force game settings for STS-style gameplay
	cfc.set_setting("hand_use_oval_shape", true)
	cfc.set_setting("fancy_movement", true)
	$OvalHandToggle.button_pressed = true
	$FancyMovementToggle.button_pressed = true

	# Create CombatManager
	combat_manager = Node.new()
	combat_manager.set_script(load("res://src/custom/CombatManager.gd"))
	combat_manager.board = self
	add_child(combat_manager)

	# Initialize combat entities (before UI so signals can be connected)
	combat_manager.player = _CombatEntity.new("Player", 80)
	combat_manager.enemy = _CombatEntity.new("Jaw Worm", 42)

	# Connect combat signals
	combat_manager.connect("energy_changed", Callable(self, "_on_energy_changed"))
	combat_manager.connect("turn_started", Callable(self, "_on_turn_started"))
	combat_manager.connect("turn_ended", Callable(self, "_on_turn_ended"))
	combat_manager.connect("combat_ended", Callable(self, "_on_combat_ended"))

	# Connect entity signals for UI updates
	combat_manager.player.connect("hp_changed", Callable(self, "_on_player_hp_changed"))
	combat_manager.player.connect("block_changed", Callable(self, "_on_player_block_changed"))
	combat_manager.player.connect("stats_changed", Callable(self, "_on_player_stats_changed"))
	combat_manager.enemy.connect("hp_changed", Callable(self, "_on_enemy_hp_changed"))
	combat_manager.enemy.connect("block_changed", Callable(self, "_on_enemy_block_changed"))
	combat_manager.enemy.connect("stats_changed", Callable(self, "_on_enemy_stats_changed"))

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

	# --- Energy label (bottom-left, near player — STS style) ---
	_energy_label = Label.new()
	_energy_label.name = "EnergyLabel"
	_energy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_energy_label.position = Vector2(20, viewport_size.y - 200)
	_energy_label.size = Vector2(120, 40)
	_energy_label.add_theme_font_size_override("font_size", 28)
	_energy_label.add_theme_color_override("font_color", Color(1, 0.85, 0))
	_energy_label.text = "⚡ 0/3"
	add_child(_energy_label)

	# Turn label (below energy, bottom-left)
	_turn_label = Label.new()
	_turn_label.name = "TurnLabel"
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_label.position = Vector2(30, viewport_size.y - 160)
	_turn_label.size = Vector2(100, 25)
	_turn_label.add_theme_font_size_override("font_size", 16)
	_turn_label.text = "Turn 0"
	add_child(_turn_label)

	# --- Enemy stats (right side, vertically centered — STS style) ---
	var enemy_x := viewport_size.x / 2 + 120
	var enemy_cy := viewport_size.y / 2 - 60
	_enemy_name_label = Label.new()
	_enemy_name_label.name = "EnemyNameLabel"
	_enemy_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enemy_name_label.position = Vector2(enemy_x, enemy_cy)
	_enemy_name_label.size = Vector2(200, 20)
	_enemy_name_label.add_theme_font_size_override("font_size", 16)
	_enemy_name_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	_enemy_name_label.text = combat_manager.enemy.display_name
	add_child(_enemy_name_label)

	_enemy_hp_label = Label.new()
	_enemy_hp_label.name = "EnemyHpLabel"
	_enemy_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enemy_hp_label.position = Vector2(enemy_x, enemy_cy + 22)
	_enemy_hp_label.size = Vector2(200, 20)
	_enemy_hp_label.add_theme_font_size_override("font_size", 16)
	_enemy_hp_label.text = "❤️ %d/%d" % [combat_manager.enemy.hp, combat_manager.enemy.max_hp]
	add_child(_enemy_hp_label)

	_enemy_block_label = Label.new()
	_enemy_block_label.name = "EnemyBlockLabel"
	_enemy_block_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enemy_block_label.position = Vector2(enemy_x, enemy_cy + 44)
	_enemy_block_label.size = Vector2(200, 18)
	_enemy_block_label.add_theme_font_size_override("font_size", 13)
	_enemy_block_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1))
	_enemy_block_label.text = ""
	add_child(_enemy_block_label)

	_enemy_status_label = Label.new()
	_enemy_status_label.name = "EnemyStatusLabel"
	_enemy_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enemy_status_label.position = Vector2(enemy_x, enemy_cy + 64)
	_enemy_status_label.size = Vector2(200, 18)
	_enemy_status_label.add_theme_font_size_override("font_size", 12)
	_enemy_status_label.text = ""
	add_child(_enemy_status_label)

	# --- Player stats (left side, vertically centered — STS style) ---
	var player_x := 20
	var player_cy := viewport_size.y / 2 - 40

	_player_hp_label = Label.new()
	_player_hp_label.name = "PlayerHpLabel"
	_player_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_player_hp_label.position = Vector2(player_x, player_cy)
	_player_hp_label.size = Vector2(200, 22)
	_player_hp_label.add_theme_font_size_override("font_size", 16)
	_player_hp_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	_player_hp_label.text = "❤️ %d/%d" % [combat_manager.player.hp, combat_manager.player.max_hp]
	add_child(_player_hp_label)

	_player_block_label = Label.new()
	_player_block_label.name = "PlayerBlockLabel"
	_player_block_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_player_block_label.position = Vector2(player_x, player_cy + 24)
	_player_block_label.size = Vector2(200, 22)
	_player_block_label.add_theme_font_size_override("font_size", 16)
	_player_block_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1))
	_player_block_label.text = ""
	add_child(_player_block_label)

	_player_status_label = Label.new()
	_player_status_label.name = "PlayerStatusLabel"
	_player_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_player_status_label.position = Vector2(player_x, player_cy + 48)
	_player_status_label.size = Vector2(200, 18)
	_player_status_label.add_theme_font_size_override("font_size", 12)
	_player_status_label.text = ""
	add_child(_player_status_label)

	# End Turn button (center-right, above hand area)
	_end_turn_button = Button.new()
	_end_turn_button.name = "EndTurnButton"
	_end_turn_button.text = "End Turn"
	_end_turn_button.position = Vector2(viewport_size.x / 2 + 200, viewport_size.y - 230)
	_end_turn_button.size = Vector2(120, 50)
	_end_turn_button.add_theme_font_size_override("font_size", 18)
	_end_turn_button.connect("pressed", Callable(self, "_on_EndTurn_pressed"))
	_end_turn_button.disabled = true
	add_child(_end_turn_button)

	# Hide demo buttons that aren't needed for combat
	_hide_demo_buttons()


func _hide_demo_buttons() -> void:
	# Hide CGF demo/debug UI — they still exist for development but aren't shown
	var demo_nodes := [
		"Counters",
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
	# Hide manipulation buttons on Pile/Hand containers
	for container_name in ["deck", "discard", "hand"]:
		var container = cfc.NMAP.get(container_name) if cfc.NMAP else null
		if container:
			var mb = container.get_node_or_null("Control/ManipulationButtons")
			if mb:
				mb.visible = false


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


func _on_combat_ended() -> void:
	if _end_turn_button:
		_end_turn_button.disabled = true
	# TODO: M7 will show victory/game-over screen
	if combat_manager.enemy.is_dead():
		push_warning("Combat ended: enemy defeated!")
	elif combat_manager.player.is_dead():
		push_warning("Combat ended: player defeated!")


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


# --- Entity UI update handlers ---

func _on_player_hp_changed(current, maximum) -> void:
	if _player_hp_label:
		_player_hp_label.text = "❤️ %d/%d" % [maxi(current, 0), maximum]


func _on_player_block_changed(new_block) -> void:
	if _player_block_label:
		_player_block_label.text = "🛡️ %d" % new_block if new_block > 0 else ""


func _on_player_stats_changed() -> void:
	if _player_status_label and combat_manager:
		var e = combat_manager.player
		_player_status_label.text = _format_status_text(e)


func _on_enemy_hp_changed(current, maximum) -> void:
	if _enemy_hp_label:
		_enemy_hp_label.text = "❤️ %d/%d" % [maxi(current, 0), maximum]


func _on_enemy_block_changed(new_block) -> void:
	if _enemy_block_label:
		_enemy_block_label.text = "🛡️ %d" % new_block if new_block > 0 else ""


func _on_enemy_stats_changed() -> void:
	if _enemy_status_label and combat_manager:
		var e = combat_manager.enemy
		_enemy_status_label.text = _format_status_text(e)


# Format status effects as a compact string.
# Shows only non-zero values: "⚔️2 🔻3 ❄️1"
static func _format_status_text(entity) -> String:
	var parts: Array = []
	if entity.strength != 0:
		parts.append("⚔️%d" % entity.strength)
	if entity.vulnerable > 0:
		parts.append("🔻%d" % entity.vulnerable)
	if entity.weak > 0:
		parts.append("❄️%d" % entity.weak)
	return "  ".join(parts)


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
