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

const ENCOUNTERS := [
	{"name": "Jaw Worm", "hp": 42},
	{"name": "Jaw Worm", "hp": 55},
	{"name": "Jaw Worm Elite", "hp": 70},
]

var current_encounter: int = 0
var player_hp: int = PLAYER_MAX_HP
var player_max_hp: int = PLAYER_MAX_HP
var deck_card_names: Array = []


func _init() -> void:
	deck_card_names = [
		"Strike", "Strike", "Strike", "Strike", "Strike",
		"Defend", "Defend", "Defend", "Defend",
		"Bash",
	]


# Returns the encounter config for the current fight.
func get_current_encounter() -> Dictionary:
	return ENCOUNTERS[current_encounter]


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
