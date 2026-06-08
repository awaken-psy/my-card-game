# Generic enemy AI driven by configuration dictionaries.
#
# Supports:
#   - Arbitrary moves with damage/block/strength/poison/weak
#   - First-turn forced move
#   - No-repeat-same-move constraint
#   - Boss multi-phase (HP threshold switches moves table)
#
# Usage:
#   var ai = EnemyAI.new(enemy_config)
#   ai.choose_intent()            # pick next move
#   ai.execute_intent(enemy, player, combat_manager)  # execute it
extends RefCounted

var current_intent: Dictionary = {}
var _moves: Array = []
var _first_move_index: int = -1  # forced first move (-1 = none)
var _no_repeat: bool = false
var _last_move_name: String = ""
var _turn_count: int = 0

# Boss phase support
var _phases: Array = []             # [{"threshold": 0.5, "moves": [...]}]
var _current_phase: int = 0
var _phase_switched: bool = false   # true after phase change this turn


func _init(config: Dictionary = {}) -> void:
	if config.is_empty():
		return
	_moves = config.get("moves", [])
	_first_move_index = config.get("first_move", -1)
	_no_repeat = config.get("no_repeat", false)
	_phases = config.get("phases", [])


# Choose the next intent. Called at the start of each player turn.
func choose_intent() -> Dictionary:
	_turn_count += 1
	_phase_switched = false

	# Check boss phase transition
	_update_phase()

	# Get active moves (current phase or base)
	var active_moves := _get_active_moves()

	var move: Dictionary
	if _turn_count == 1 and _first_move_index >= 0 and _first_move_index < active_moves.size():
		move = active_moves[_first_move_index]
	elif _no_repeat and active_moves.size() > 1:
		var candidates := active_moves.filter(func(m): return m["name"] != _last_move_name)
		move = candidates[randi() % candidates.size()]
	else:
		move = active_moves[randi() % active_moves.size()]

	_last_move_name = move["name"]
	current_intent = move.duplicate()
	return current_intent


# Execute the current intent against the given targets.
# Order: damage → block → strength → poison → weak.
# Supports "hits" field for multi-hit attacks (each hit calculated separately).
func execute_intent(enemy, player, combat_manager) -> void:
	if current_intent.is_empty():
		return
	# 1. Apply damage (uses current stats, before any buffs)
	var base_damage: int = current_intent.get("damage", 0)
	var hits: int = current_intent.get("hits", 1)
	if base_damage > 0:
		for _i in range(hits):
			var damage := _calculate_enemy_damage(base_damage, enemy, player)
			player.take_damage(damage)
			combat_manager.emit_signal("entity_damaged", player, damage)
			# Thorns: player reflects damage back to enemy
			if player.thorns > 0:
				enemy.take_damage(player.thorns)
				combat_manager.emit_signal("entity_damaged", enemy, player.thorns)
				combat_manager.emit_signal("thorns_triggered", player, player.thorns)
	# 2. Apply block
	if current_intent.get("block", 0) > 0:
		enemy.gain_block(current_intent["block"])
	# 3. Apply strength (affects future turns, not current damage)
	if current_intent.get("strength", 0) > 0:
		enemy.add_strength(current_intent["strength"])
	# 4. Apply poison
	if current_intent.get("poison", 0) > 0:
		player.add_poison(current_intent["poison"])
	# 5. Apply weak
	if current_intent.get("weak", 0) > 0:
		player.add_weak(current_intent["weak"])


# Calculate enemy damage with strength, weak, and vulnerable modifiers.
func _calculate_enemy_damage(base: int, attacker, defender) -> int:
	var damage: int = base + attacker.strength
	# Weak: outgoing damage × 0.75
	if attacker.weak > 0:
		damage = int(damage * 0.75)
	# Vulnerable: incoming damage × 1.5
	if defender.vulnerable > 0:
		damage = int(damage * 1.5)
	return maxi(damage, 0)


# Check if boss should transition to a new phase.
func _update_phase() -> void:
	if _phases.is_empty():
		return
	# Note: enemy HP is checked via combat_manager reference stored in
	# CombatManager which calls choose_intent(). The enemy reference is
	# passed during execute_intent, but for phase checks we need it earlier.
	# CombatManager sets phase_enemy_ref before calling choose_intent().
	pass


# Check if boss should transition based on enemy's HP ratio.
# Called by CombatManager after setting phase_enemy_ref.
func check_phase_transition(enemy) -> void:
	if _phases.is_empty():
		return
	var hp_ratio: float = float(enemy.hp) / float(enemy.max_hp)
	for i in range(_phases.size()):
		var phase: Dictionary = _phases[i]
		if hp_ratio <= phase.get("threshold", 0.0) and _current_phase <= i:
			if _current_phase != i + 1:
				_current_phase = i + 1
				_phase_switched = true
			return


# Get the moves array for the current phase.
func _get_active_moves() -> Array:
	if _phases.is_empty() or _current_phase == 0:
		return _moves
	# Phase 1 = _phases[0], phase 2 = _phases[1], etc.
	var phase_index: int = _current_phase - 1
	if phase_index < _phases.size():
		return _phases[phase_index].get("moves", _moves)
	return _moves


# Reset AI state for a new combat encounter.
func reset() -> void:
	current_intent = {}
	_last_move_name = ""
	_turn_count = 0
	_current_phase = 0
	_phase_switched = false
