# Relic definitions for My Card Game.
#
# Each relic provides a passive bonus that triggers at specific combat events.
# Relics are acquired from: elite kills, boss kills, shop purchases.
extends RefCounted

# Relic data:
#   name: display name
#   description: effect description
#   icon: emoji for UI display
#   rarity: "common", "uncommon", "rare"
#   price: shop price in gold
const RELICS := {
	"orichalcum": {
		"name": "橄榄石",
		"description": "每回合开始获得 4 格挡",
		"icon": "💎",
		"rarity": "common",
		"price": 100,
	},
	"burning_blade": {
		"name": "燃烧之刃",
		"description": "每回合首次攻击 +3 伤害",
		"icon": "🔥",
		"rarity": "uncommon",
		"price": 150,
	},
	"red_skull": {
		"name": "赤红之颅",
		"description": "击杀精英/Boss后永久 +2 力量",
		"icon": "💀",
		"rarity": "uncommon",
		"price": 150,
	},
	"vampire_eye": {
		"name": "吸血之眼",
		"description": "攻击造成伤害时回复 2 HP",
		"icon": "👁️",
		"rarity": "rare",
		"price": 200,
	},
	"lucky_cat": {
		"name": "招财猫",
		"description": "每场战斗额外 +15 金币",
		"icon": "🐱",
		"rarity": "common",
		"price": 100,
	},
}


static func get_relic(relic_id: String) -> Dictionary:
	if RELICS.has(relic_id):
		return RELICS[relic_id].duplicate()
	push_error("RelicDatabase: Unknown relic '%s'" % relic_id)
	return {}


static func get_all_ids() -> Array:
	return RELICS.keys()


static func get_random_relic(exclude: Array = []) -> String:
	var pool := []
	for id in RELICS:
		if not id in exclude:
			pool.append(id)
	if pool.is_empty():
		return ""
	return pool[randi() % pool.size()]
