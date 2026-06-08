# Enemy database: data-driven enemy configurations for My Card Game.
#
# Each enemy config defines:
#   - name: display name
#   - hp: base HP (actual HP can be overridden per encounter)
#   - type: "normal", "elite", or "boss"
#   - visual: { color, border_color, size, corner_radius } for the combat UI
#   - moves: array of move dictionaries
#   - first_move: index of forced first move (-1 = none)
#   - no_repeat: true = cannot use same move twice in a row
#   - phases: boss-only, HP-threshold phase transitions
#
# Move dictionary:
#   { "name", "damage", "block", "strength", "poison", "weak", "type" }
extends RefCounted

const ENEMIES := {
	"jaw_worm": {
		"name": "Jaw Worm",
		"hp": 42,
		"type": "normal",
		"visual": {
			"color": Color(0.5, 0.1, 0.1, 0.9),
			"border_color": Color(0.85, 0.25, 0.25),
			"size": Vector2(150, 120),
			"corner_radius": 12,
		},
		"moves": [
			{"name": "Chomp", "damage": 11, "block": 0, "strength": 0, "poison": 0, "weak": 0, "type": "attack"},
			{"name": "Thrash", "damage": 7, "block": 5, "strength": 0, "poison": 0, "weak": 0, "type": "attack"},
			{"name": "Bellow", "damage": 0, "block": 6, "strength": 2, "poison": 0, "weak": 0, "type": "buff"},
		],
		"first_move": 0,
		"no_repeat": true,
		"phases": [],
	},

	"fungi_beast": {
		"name": "Fungi Beast",
		"hp": 28,
		"type": "normal",
		"visual": {
			"color": Color(0.15, 0.4, 0.1, 0.9),
			"border_color": Color(0.4, 0.75, 0.25),
			"size": Vector2(120, 100),
			"corner_radius": 50,
		},
		"moves": [
			{"name": "Bite", "damage": 6, "block": 0, "strength": 0, "poison": 0, "weak": 0, "type": "attack"},
			{"name": "Spore Cloud", "damage": 0, "block": 0, "strength": 0, "poison": 4, "weak": 0, "type": "attack"},
			{"name": "Grow", "damage": 0, "block": 4, "strength": 1, "poison": 0, "weak": 0, "type": "buff"},
		],
		"first_move": 0,
		"no_repeat": true,
		"phases": [],
	},

	"slaver": {
		"name": "Slaver",
		"hp": 46,
		"type": "normal",
		"visual": {
			"color": Color(0.35, 0.15, 0.45, 0.9),
			"border_color": Color(0.6, 0.4, 0.75),
			"size": Vector2(150, 120),
			"corner_radius": 12,
		},
		"moves": [
			{"name": "Stab", "damage": 12, "block": 0, "strength": 0, "poison": 0, "weak": 0, "type": "attack"},
			{"name": "Rake", "damage": 7, "block": 0, "strength": 0, "poison": 0, "weak": 1, "type": "attack"},
			{"name": "Defend", "damage": 0, "block": 11, "strength": 0, "poison": 0, "weak": 0, "type": "defend"},
		],
		"first_move": 0,
		"no_repeat": true,
		"phases": [],
	},

	"jaw_worm_elite": {
		"name": "Jaw Worm Elite",
		"hp": 58,
		"type": "elite",
		"visual": {
			"color": Color(0.6, 0.08, 0.08, 0.9),
			"border_color": Color(1.0, 0.8, 0.2),
			"size": Vector2(170, 130),
			"corner_radius": 14,
		},
		"moves": [
			{"name": "Chomp", "damage": 14, "block": 0, "strength": 0, "poison": 0, "weak": 0, "type": "attack"},
			{"name": "Thrash", "damage": 10, "block": 8, "strength": 0, "poison": 0, "weak": 0, "type": "attack"},
			{"name": "Bellow", "damage": 0, "block": 8, "strength": 3, "poison": 0, "weak": 0, "type": "buff"},
		],
		"first_move": 0,
		"no_repeat": true,
		"phases": [],
	},

	"heart_mimic": {
		"name": "Heart Mimic",
		"hp": 80,
		"type": "boss",
		"visual": {
			"color": Color(0.45, 0.05, 0.15, 0.9),
			"border_color": Color(0.9, 0.2, 0.4),
			"size": Vector2(200, 160),
			"corner_radius": 16,
		},
		"moves": [
			# Phase 1 (HP > 50%)
			{"name": "Slam", "damage": 15, "block": 0, "strength": 0, "poison": 0, "weak": 0, "type": "attack"},
			{"name": "Buffet", "damage": 10, "block": 10, "strength": 0, "poison": 0, "weak": 0, "type": "attack"},
			{"name": "Echo", "damage": 0, "block": 0, "strength": 2, "poison": 0, "weak": 0, "type": "buff"},
		],
		"first_move": 0,
		"no_repeat": true,
		"phases": [
			{
				"threshold": 0.5,
				"moves": [
					{"name": "Multi-Strike", "damage": 6, "block": 0, "strength": 0, "poison": 0, "weak": 0, "type": "attack", "hits": 2},
					{"name": "Blood Rage", "damage": 12, "block": 0, "strength": 3, "poison": 0, "weak": 0, "type": "attack"},
					{"name": "Harden", "damage": 0, "block": 20, "strength": 0, "poison": 0, "weak": 0, "type": "defend"},
				],
			},
		],
	},
}


static func get_enemy(enemy_id: String) -> Dictionary:
	if ENEMIES.has(enemy_id):
		return ENEMIES[enemy_id].duplicate(true)
	push_warning("EnemyDatabase: unknown enemy '%s'" % enemy_id)
	# Fallback to jaw_worm
	return ENEMIES["jaw_worm"].duplicate(true)
