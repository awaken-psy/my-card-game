# My Card Game — card scripts (placeholder for M1)
# M4 will implement actual card effects using the scripting engine
extends RefCounted

const scripts := {
	"Strike": {
		"manual": {
			"hand": [
				# M4: Deal _damage to target enemy
			]
		}
	},
	"Defend": {
		"manual": {
			"hand": [
				# M4: Gain _block
			]
		}
	},
	"Bash": {
		"manual": {
			"hand": [
				# M4: Deal _damage + apply vulnerable
			]
		}
	},
	"Cleave": {
		"manual": {
			"hand": [
				# M4: Deal _damage
			]
		}
	},
	"Iron Wave": {
		"manual": {
			"hand": [
				# M4: Deal _damage + gain _block
			]
		}
	},
	"Shrug It Off": {
		"manual": {
			"hand": [
				# M4: Gain _block + draw 1 card
			]
		}
	},
	"Pommel Strike": {
		"manual": {
			"hand": [
				# M4: Deal _damage + draw 1 card
			]
		}
	},
	"Inflame": {
		"manual": {
			"hand": [
				# M4: Gain 2 strength (permanent buff)
			]
		}
	},
	"Bloodletting": {
		"manual": {
			"hand": [
				# M4: Lose 3 HP + gain 2 energy
			]
		}
	},
	"Heavy Blow": {
		"manual": {
			"hand": [
				# M4: Deal _damage (strength scaling)
			]
		}
	},
}

func get_scripts(card_name: String) -> Dictionary:
	return(scripts.get(card_name, {}))
