# Enemy AI for Jaw Worm: defines moves and manages intent selection.
#
# Move selection rules:
#   - Turn 1: always Chomp
#   - After: random from 3 moves, cannot pick the same move twice in a row
#
# The intent is chosen at the start of each player turn (displayed to the player)
# and executed at the end of the player turn during the enemy turn.
extends RefCounted


# Jaw Worm's three moves
var _moves: Array = [
	{"name": "Chomp", "damage": 11, "block": 0, "strength": 0, "type": "attack"},
	{"name": "Thrash", "damage": 7, "block": 5, "strength": 0, "type": "attack"},
	{"name": "Bellow", "damage": 0, "block": 6, "strength": 2, "type": "buff"},
]

var current_intent: Dictionary = {}
var _last_move_name: String = ""
var _turn_count: int = 0


# Choose the next intent. Called at the start of each player turn.
# Turn 1: always Chomp. After: random from 3, no consecutive same move.
func choose_intent() -> Dictionary:
	_turn_count += 1
	var move: Dictionary
	if _turn_count == 1:
		move = _moves[0]  # Turn 1: always Chomp
	else:
		var candidates := _moves.filter(func(m): return m["name"] != _last_move_name)
		move = candidates[randi() % candidates.size()]
	_last_move_name = move["name"]
	current_intent = move.duplicate()
	return current_intent


# Execute the current intent against the given targets.
# Order: damage (uses current stats) → block → strength (affects future turns).
func execute_intent(enemy, player, combat_manager) -> void:
	if current_intent.is_empty():
		return
	# 1. Apply damage first (uses current stats, before any buffs)
	var base_damage: int = current_intent.get("damage", 0)
	if base_damage > 0:
		var damage := _calculate_enemy_damage(base_damage, enemy, player)
		player.take_damage(damage)
		combat_manager.emit_signal("entity_damaged", player, damage)
	# 2. Apply block
	if current_intent.get("block", 0) > 0:
		enemy.gain_block(current_intent["block"])
	# 3. Apply strength last (affects future turns, not current damage)
	if current_intent.get("strength", 0) > 0:
		enemy.add_strength(current_intent["strength"])


# Calculate enemy damage with strength, weak, and vulnerable modifiers.
func _calculate_enemy_damage(base: int, attacker, defender) -> int:
	var damage := base + attacker.strength
	# Weak: outgoing damage × 0.75
	if attacker.weak > 0:
		damage = int(damage * 0.75)
	# Vulnerable: incoming damage × 1.5
	if defender.vulnerable > 0:
		damage = int(damage * 1.5)
	return maxi(damage, 0)


# Reset AI state for a new combat encounter.
func reset() -> void:
	current_intent = {}
	_last_move_name = ""
	_turn_count = 0
