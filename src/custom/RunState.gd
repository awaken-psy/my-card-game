# Cross-combat run state for My Card Game.
#
# Tracks persistent data across the 3-encounter run:
#   - Player HP (no recovery between fights)
#   - Deck card names (reward cards accumulate)
#   - Current encounter index
#
# Used by CGFBoard to initialize each combat from the correct state.
extends RefCounted

const PLAYER_MAX_HP := 80

const _EnemyDatabase = preload("res://src/custom/enemies/EnemyDatabase.gd")

# Encounter definitions: enemy_id determines which enemy config to use.
# Format: {"enemy_id": "..."} — full config fetched from EnemyDatabase.
const ENCOUNTERS := [
	# Battle 1: random normal enemy
	{"enemy_id": "_random_normal"},
	# Battle 2: elite
	{"enemy_id": "jaw_worm_elite"},
	# Battle 3: boss (fixed)
	{"enemy_id": "heart_mimic"},
]

# All normal enemy IDs for random selection in encounter 1.
const _NORMAL_ENEMIES := ["jaw_worm", "fungi_beast", "slaver"]

var current_encounter: int = 0
var player_hp: int = PLAYER_MAX_HP
var player_max_hp: int = PLAYER_MAX_HP
var deck_card_names: Array = []

# Cached random pick for the first encounter (decided at run start).
var _first_encounter_enemy: String = ""


func _init() -> void:
	deck_card_names = [
		"Strike", "Strike", "Strike", "Strike", "Strike",
		"Defend", "Defend", "Defend", "Defend",
		"Bash",
	]
	# Decide the random enemy for encounter 1 at run start
	_first_encounter_enemy = _NORMAL_ENEMIES[randi() % _NORMAL_ENEMIES.size()]


# Returns the full enemy config for the current encounter.
func get_current_encounter() -> Dictionary:
	var encounter: Dictionary = ENCOUNTERS[current_encounter]
	var enemy_id: String = encounter["enemy_id"]
	# Resolve random placeholder
	if enemy_id == "_random_normal":
		enemy_id = _first_encounter_enemy
	return _EnemyDatabase.get_enemy(enemy_id)


# 1-based encounter number for display ("Battle 1/3").
func get_encounter_number() -> int:
	return current_encounter + 1


# Total number of encounters in the run.
func get_total_encounters() -> int:
	return ENCOUNTERS.size()


# True when the current fight is the last one.
func is_final_encounter() -> bool:
	return current_encounter >= ENCOUNTERS.size() - 1


# Move to the next encounter. Call after reward selection.
func advance_encounter() -> void:
	current_encounter += 1


# True when all encounters have been completed.
func is_run_complete() -> bool:
	return current_encounter >= ENCOUNTERS.size()
