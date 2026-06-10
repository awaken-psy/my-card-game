# Cross-combat run state for My Card Game (M11 Roguelike version).
#
# Tracks persistent data across a 15-floor roguelike run:
#   - Map data (floor layout, connections)
#   - Player position on the map
#   - HP, gold, deck, relics
#   - Persistent strength from relics
extends RefCounted

const PLAYER_MAX_HP := 80
const STARTING_GOLD := 99

const _EnemyDatabase = preload("res://src/custom/enemies/EnemyDatabase.gd")
const _MapGenerator = preload("res://src/custom/MapGenerator.gd")

# Enemy pools
const _NORMAL_ENEMIES := ["jaw_worm", "fungi_beast", "slaver"]
const _ELITE_ENEMIES := ["jaw_worm_elite"]
const _BOSS_ENEMIES := ["heart_mimic"]

# --- Map data ---
var map_data: Dictionary = {}
var current_floor: int = -1
var current_node_index: int = -1

# --- Player state ---
var player_hp: int = PLAYER_MAX_HP
var player_max_hp: int = PLAYER_MAX_HP
var player_strength: int = 0  # Persistent across combats (from relics)
var deck_card_names: Array = []
var gold: int = STARTING_GOLD
var relics: Array = []  # Array of relic_id strings


func _init() -> void:
	deck_card_names = [
		"Strike", "Strike", "Strike", "Strike", "Strike",
		"Defend", "Defend", "Defend", "Defend",
		"Bash",
	]
	map_data = _MapGenerator.generate()


# --- Map Navigation ---


# Get the current node data (type, x, connections).
func get_current_node() -> Dictionary:
	if current_floor < 0 or current_floor >= map_data["floors"].size():
		return {}
	var floor_nodes: Array = map_data["floors"][current_floor]
	if current_node_index < 0 or current_node_index >= floor_nodes.size():
		return {}
	return floor_nodes[current_node_index]


# Get all nodes on the starting floor (for initial selection).
func get_starting_nodes() -> Array:
	return map_data["floors"][0]


# Get reachable nodes from current position (connected nodes on the next floor).
# Returns array of {node_data, floor_index, node_index} for each reachable node.
func get_reachable_nodes() -> Array:
	if current_floor < 0:
		# Haven't entered map yet; all floor 0 nodes are reachable
		var result := []
		var floor_nodes: Array = map_data["floors"][0]
		for i in range(floor_nodes.size()):
			result.append({
				"node": floor_nodes[i],
				"floor_index": 0,
				"node_index": i,
			})
		return result
	var current_node := get_current_node()
	var next_floor_index := current_floor + 1
	if next_floor_index >= map_data["floors"].size():
		return []
	var next_floor: Array = map_data["floors"][next_floor_index]
	var connected_indices: Array = current_node.get("connections", [])
	var result := []
	for idx in connected_indices:
		if idx < next_floor.size():
			result.append({
				"node": next_floor[idx],
				"floor_index": next_floor_index,
				"node_index": idx,
			})
	return result


# Move to a specific node on the map.
func move_to_node(floor_index: int, node_index: int) -> void:
	current_floor = floor_index
	current_node_index = node_index


# True if the current node is the last floor (boss).
func is_current_node_final() -> bool:
	return current_floor >= map_data["floors"].size() - 1


# True if the run is complete (after boss defeated and advanced past last floor).
func is_run_complete() -> bool:
	return current_floor >= map_data["floors"].size()


# Get the total number of floors.
func get_total_floors() -> int:
	return map_data["floors"].size()


# 1-based floor number for display.
func get_floor_number() -> int:
	return maxi(current_floor + 1, 1)


# --- Encounter Generation ---


# Returns the full enemy config for the current node.
# Interface unchanged from M10 — CombatManager doesn't need modification for this.
func get_current_encounter() -> Dictionary:
	var node := get_current_node()
	if node.is_empty():
		return {}
	var node_type: String = node.get("type", "combat")
	match node_type:
		"combat":
			return _get_combat_encounter()
		"elite":
			return _get_elite_encounter()
		"boss":
			return _get_boss_encounter()
		_:
			return {}


func _get_combat_encounter() -> Dictionary:
	var enemy_id: String = _NORMAL_ENEMIES[randi() % _NORMAL_ENEMIES.size()]
	var config: Dictionary = _EnemyDatabase.get_enemy(enemy_id)
	return _scale_enemy(config)


func _get_elite_encounter() -> Dictionary:
	var enemy_id: String = _ELITE_ENEMIES[randi() % _ELITE_ENEMIES.size()]
	var config: Dictionary = _EnemyDatabase.get_enemy(enemy_id)
	return _scale_enemy(config, 1.3)


func _get_boss_encounter() -> Dictionary:
	var enemy_id: String = _BOSS_ENEMIES[randi() % _BOSS_ENEMIES.size()]
	var config: Dictionary = _EnemyDatabase.get_enemy(enemy_id)
	return _scale_enemy(config, 1.5)


# Scale enemy stats based on floor progression.
func _scale_enemy(config: Dictionary, extra_mult: float = 1.0) -> Dictionary:
	var scaled := config.duplicate(true)
	# Floor-based scaling: +8% HP per floor, +5% damage per floor
	var hp_mult := 1.0 + current_floor * 0.08
	var dmg_mult := 1.0 + current_floor * 0.05
	scaled["hp"] = int(scaled["hp"] * hp_mult * extra_mult)
	# Scale damage in moves
	if scaled.has("moves"):
		var scaled_moves := []
		for move in scaled["moves"]:
			var sm := move.duplicate()
			if sm.has("damage"):
				sm["damage"] = int(sm["damage"] * dmg_mult * extra_mult)
			scaled_moves.append(sm)
		scaled["moves"] = scaled_moves
	return scaled


# --- Gold ---


func add_gold(amount: int) -> void:
	gold += amount


func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		return true
	return false


# --- Relics ---


func add_relic(relic_id: String) -> void:
	if not relics.has(relic_id):
		relics.append(relic_id)


func has_relic(relic_id: String) -> bool:
	return relic_id in relics


# --- Rewards ---


# Calculate gold reward for current combat based on node type.
func get_gold_reward() -> int:
	var node := get_current_node()
	var node_type: String = node.get("type", "combat")
	var base_gold := 20 + current_floor * 3
	match node_type:
		"elite":
			base_gold = 40 + current_floor * 5
		"boss":
			base_gold = 100
	# Lucky Cat relic: +15 gold
	if has_relic("lucky_cat"):
		base_gold += 15
	return base_gold


# Check if current encounter is an elite or boss (for relic effects).
func is_elite_or_boss_encounter() -> bool:
	var node := get_current_node()
	var node_type: String = node.get("type", "combat")
	return node_type in ["elite", "boss"]


# --- Deck manipulation ---


# Remove a card by name from the deck. Returns true if removed.
func remove_card_from_deck(card_name: String) -> bool:
	var idx := deck_card_names.find(card_name)
	if idx >= 0:
		deck_card_names.remove_at(idx)
		return true
	return false
