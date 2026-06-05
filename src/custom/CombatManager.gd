# Manages the STS-style combat flow: turns, energy, draw/discard cycle.
#
# Lifecycle: start_combat() → [start_turn() ↔ end_turn()] loop
# Cards are played via click (see CGFCardTemplate.gd override).
extends Node

signal turn_started(turn_number)
signal turn_ended
signal energy_changed(current_energy, max_energy)
signal combat_ended

const MAX_ENERGY := 3
const DRAW_PER_TURN := 5

var current_energy: int = 0
var turn_number: int = 0
var is_player_turn: bool = false

# Reference to the board node (set by CGFBoard)
var board: Node


func _ready() -> void:
	pass


# Begin a new combat encounter.
# Expects deck to already contain all starting cards.
func start_combat() -> void:
	turn_number = 0
	current_energy = 0
	is_player_turn = false
	if not cfc.are_all_nodes_mapped:
		await cfc.all_nodes_mapped
	# Shuffle the deck (SNAP style avoids the framework's return tween bug)
	await cfc.NMAP.deck.shuffle_cards()
	start_turn()


# Begin a new player turn.
func start_turn() -> void:
	turn_number += 1
	is_player_turn = true
	current_energy = MAX_ENERGY
	emit_signal("energy_changed", current_energy, MAX_ENERGY)
	emit_signal("turn_started", turn_number)
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
	# TODO: M5 will insert enemy turn here
	# For now, immediately start next player turn
	await get_tree().create_timer(0.5).timeout
	start_turn()


# Check if a card can be played (enough energy + player turn).
func can_play_card(card: Card) -> bool:
	if not is_player_turn:
		return false
	var cost: int = card.properties.get("Cost", 0)
	return current_energy >= cost


# Play a card from hand: spend energy, then move to discard.
func play_card(card: Card) -> void:
	if not can_play_card(card):
		return
	var cost: int = card.properties.get("Cost", 0)
	spend_energy(cost)
	# TODO: M4 will execute card effects here before discard
	# Move card to discard pile
	card.move_to(cfc.NMAP.discard)


# Spend energy and emit signal.
func spend_energy(amount: int) -> void:
	current_energy = max(0, current_energy - amount)
	emit_signal("energy_changed", current_energy, MAX_ENERGY)


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
