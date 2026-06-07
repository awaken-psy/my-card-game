# Manages the STS-style combat flow: turns, energy, draw/discard cycle,
# card effect resolution (M4), and enemy turns with intent display (M5).
#
# Lifecycle: start_combat() -> [start_turn() <-> end_turn()] loop
# Cards are played via click (see CGFCardTemplate.gd override).
# Effects are resolved in order: Block -> Damage -> Special effects.
# Enemy AI executes at end of each player turn.
extends Node

signal turn_started(turn_number)
signal turn_ended
signal energy_changed(current_energy, max_energy)
signal combat_ended
signal entity_damaged(entity, amount)
signal enemy_intent_changed(intent_info)
signal player_turn_started
signal enemy_turn_started

const MAX_ENERGY := 3
const DRAW_PER_TURN := 5

const _EnemyAI = preload("res://src/custom/EnemyAI.gd")

var current_energy: int = 0
var turn_number: int = 0
var is_player_turn: bool = false
var enemy_ai: RefCounted

# "victory" or "defeat" — set when combat ends.
var combat_result: String = ""

# True while a card's effects are being resolved (prevents double-play).
var _is_resolving: bool = false

# Reference to the board node (set by CGFBoard)
var board: Node

# Combat entities (created by CGFBoard._setup_combat before start_combat)
var player
var enemy


func _ready() -> void:
	pass


# Begin a new combat encounter.
# Expects deck to already contain all starting cards,
# and player/enemy entities to be already created.
func start_combat() -> void:
	turn_number = 0
	current_energy = 0
	is_player_turn = false
	combat_result = ""
	# Create enemy AI
	enemy_ai = _EnemyAI.new()
	if not cfc.are_all_nodes_mapped:
		await cfc.all_nodes_mapped
	# Shuffle the deck (SNAP style avoids the framework's return tween bug)
	await cfc.NMAP.deck.shuffle_cards()
	await get_tree().create_timer(0.5).timeout
	start_turn()


# Begin a new player turn.
func start_turn() -> void:
	turn_number += 1
	is_player_turn = true
	# Reset block and tick status at start of turn
	player.reset_block()
	player.tick_status()
	# Refill energy
	current_energy = MAX_ENERGY
	emit_signal("energy_changed", current_energy, MAX_ENERGY)
	# Choose enemy intent for this round (displayed during player's turn)
	var intent: Dictionary = enemy_ai.choose_intent()
	emit_signal("enemy_intent_changed", intent)
	emit_signal("turn_started", turn_number)
	emit_signal("player_turn_started")
	# Draw cards one by one with animation delay
	await draw_cards(DRAW_PER_TURN)


# End the current player turn.
func end_turn() -> void:
	if not is_player_turn:
		return
	is_player_turn = false
	emit_signal("turn_ended")
	# Discard all cards currently in hand
	await discard_hand()
	# Enemy turn
	await _enemy_turn()
	# After enemy turn, check if combat should end
	# (M5 fix: player dying during enemy turn now emits combat_ended)
	if enemy.is_dead() or player.is_dead():
		combat_result = "victory" if enemy.is_dead() else "defeat"
		emit_signal("combat_ended")
		return
	start_turn()


# Execute the enemy's pre-chosen intent.
func _enemy_turn() -> void:
	emit_signal("enemy_turn_started")
	# Enemy resets block and ticks status at start of their turn
	enemy.reset_block()
	enemy.tick_status()
	# Brief pause to let player see the intent before execution
	await get_tree().create_timer(0.8).timeout
	# Execute the pre-chosen intent
	enemy_ai.execute_intent(enemy, player, self)
	# Clear intent display after execution
	emit_signal("enemy_intent_changed", {})
	# Brief pause after execution for visual feedback
	await get_tree().create_timer(0.5).timeout


# Check if a card can be played (enough energy + player turn + not resolving).
func can_play_card(card: Card) -> bool:
	if not is_player_turn:
		return false
	if _is_resolving:
		return false
	var cost: int = card.properties.get("Cost", 0)
	return current_energy >= cost


# Play a card from hand: spend energy, fly to target, execute effects, discard.
func play_card(card: Card) -> void:
	if not can_play_card(card):
		return
	_is_resolving = true
	var cost: int = card.properties.get("Cost", 0)
	spend_energy(cost)
	# Fly card toward its target
	await _animate_card_to_target(card)
	# Execute card effects
	await _resolve_card_effects(card)
	# Move card to discard pile
	card.move_to(cfc.NMAP.discard)
	_is_resolving = false
	# Re-evaluate hand card visuals after resolution lock is released
	board._notify_hand_cards_cost_update()


# Animate the card being played: pulse scale + flash, then shrink away.
# Does NOT modify global_position (conflicts with framework hand management).
func _animate_card_to_target(card: Card) -> void:
	# Simple flash effect: white pulse on the card (does not touch position/scale).
	# Uses board tween to avoid framework card._tween conflicts.
	var tween := board.create_tween()
	tween.tween_property(card, "modulate", Color(2.0, 2.0, 2.0), 0.06)
	tween.tween_property(card, "modulate", Color.WHITE, 0.14)
	await tween.finished


# --- Effect Resolution ---


# Resolve all effects of a card in order: Block -> Damage -> Special effects.
func _resolve_card_effects(card: Card) -> void:
	# 1. Block
	var block_amount: int = card.properties.get("Block", 0)
	if block_amount > 0:
		player.gain_block(block_amount)

	# 2. Damage
	var base_damage: int = card.properties.get("Damage", 0)
	if base_damage > 0:
		var effects: Array = card.properties.get("_effects", [])
		var damage := _calculate_damage(base_damage, player, enemy, effects)
		enemy.take_damage(damage)
		emit_signal("entity_damaged", enemy, damage)

	# 3. Special effects from _effects array
	var effects: Array = card.properties.get("_effects", [])
	for effect_str in effects:
		await _resolve_effect(effect_str)

	# Check if combat should end
	_check_combat_end()


# Calculate final damage considering strength, weak, and vulnerable.
func _calculate_damage(base: int, attacker, defender, effects: Array) -> int:
	# Apply strength bonus
	var strength_bonus: int = attacker.strength
	# Heavy Blow (strength_scaling) gets double strength bonus
	if "strength_scaling" in effects:
		strength_bonus *= 2
	var damage := base + strength_bonus

	# Weak: outgoing damage * 0.75
	if attacker.weak > 0:
		damage = int(damage * 0.75)

	# Vulnerable: incoming damage * 1.5
	if defender.vulnerable > 0:
		damage = int(damage * 1.5)

	return maxi(damage, 0)


# Parse and execute a single effect string from _effects array.
func _resolve_effect(effect_str: String) -> void:
	var parts := effect_str.split(":")
	var effect_name: String = parts[0]
	var value: int = int(parts[1]) if parts.size() > 1 and parts[1].is_valid_int() else 0

	match effect_name:
		"draw":
			await draw_cards(value)
		"strength":
			player.add_strength(value)
		"vulnerable":
			enemy.add_vulnerable(value)
		"gain_energy":
			current_energy += value
			emit_signal("energy_changed", current_energy, MAX_ENERGY)
		"lose_hp":
			player.lose_hp(value)
			emit_signal("entity_damaged", player, value)
		"strength_scaling":
			pass  # Already handled in _calculate_damage
		_:
			push_warning("CombatManager: Unknown effect '%s'" % effect_name)


# Check if combat should end (enemy or player dead).
func _check_combat_end() -> void:
	if enemy.is_dead():
		is_player_turn = false
		combat_result = "victory"
		emit_signal("combat_ended")
	elif player.is_dead():
		is_player_turn = false
		combat_result = "defeat"
		emit_signal("combat_ended")


# --- Energy ---


# Spend energy and emit signal.
func spend_energy(amount: int) -> void:
	current_energy = max(0, current_energy - amount)
	emit_signal("energy_changed", current_energy, MAX_ENERGY)


# --- Drawing & Discarding ---


# Draw N cards from deck to hand, reshuffling discard if deck is empty.
func draw_cards(count: int) -> void:
	for i in count:
		# If deck is empty, reshuffle discard into deck
		if cfc.NMAP.deck.get_card_count() == 0:
			if cfc.NMAP.discard.get_card_count() == 0:
				break  # No cards left anywhere
			await _reshuffle_discard_into_deck()
		var card: Card = cfc.NMAP.hand.draw_card()
		if card:
			# Small delay between draws for animation
			await get_tree().create_timer(0.15).timeout
	# Ensure all cards finished their move animation and are properly positioned
	await get_tree().create_timer(0.3).timeout
	for c in cfc.NMAP.hand.get_all_cards():
		c.interruptTweening()
		c.reorganize_self()
	# Refresh card visuals (energy gray-out) after draw completes
	board._notify_hand_cards_cost_update()


# Discard all cards currently in hand.
func discard_hand() -> void:
	var hand_cards: Array = cfc.NMAP.hand.get_all_cards().duplicate()
	for card in hand_cards:
		if is_instance_valid(card):
			card.move_to(cfc.NMAP.discard)
			await get_tree().create_timer(0.08).timeout
	# Wait for the last card's move animation
	await get_tree().create_timer(0.3).timeout


# Move all discard pile cards back to deck, then shuffle.
func _reshuffle_discard_into_deck() -> void:
	var discard_cards: Array = cfc.NMAP.discard.get_all_cards().duplicate()
	for card in discard_cards:
		if is_instance_valid(card):
			card.move_to(cfc.NMAP.deck)
	# Wait for move animations to complete
	await get_tree().create_timer(0.3).timeout
	await cfc.NMAP.deck.shuffle_cards()
