# Generates the roguelike map for My Card Game.
#
# Creates a 15-floor map with branching paths. Uses templates per floor range
# with randomization to ensure good node type distribution while keeping variety.
extends RefCounted

# Node type visual config: icon emoji and color for rendering.
const NODE_CONFIG := {
	"combat": {"icon": "⚔️", "color": Color(0.2, 0.6, 0.2)},
	"elite":  {"icon": "💀", "color": Color(0.8, 0.3, 0.1)},
	"shop":   {"icon": "💰", "color": Color(0.8, 0.7, 0.1)},
	"rest":   {"icon": "❤️", "color": Color(0.6, 0.2, 0.3)},
	"boss":   {"icon": "👑", "color": Color(0.7, 0.1, 0.2)},
}

const TOTAL_FLOORS := 15


# Generate a complete map with 15 floors and connections.
# Returns: {"floors": [[node_dicts], ...], "start_floor": 0}
static func generate() -> Dictionary:
	var floors := []
	# Floor 0: all combat (starting floor)
	floors.append(_make_floor(["combat", "combat", "combat"]))
	# Floors 1–13: procedural with templates
	for i in range(1, 14):
		floors.append(_generate_floor(i))
	# Floor 14: boss
	floors.append(_make_floor(["boss"]))
	# Assign normalized x positions and generate connections
	_assign_positions(floors)
	_connect_all_floors(floors)
	return {"floors": floors, "start_floor": 0}


static func _make_floor(types: Array) -> Array:
	var floor_nodes := []
	for t in types:
		floor_nodes.append({"type": t, "connections": []})
	return floor_nodes


static func _generate_floor(floor_index: int) -> Array:
	var templates: Array = _get_templates(floor_index)
	var template: Array = templates[randi() % templates.size()]
	return _make_floor(template)


# Floor templates ensure balanced distribution of node types.
# Each entry is an array of node types for one floor.
static func _get_templates(floor_index: int) -> Array:
	match floor_index:
		1, 2:
			return [
				["combat", "combat", "shop"],
				["combat", "combat", "rest"],
				["combat", "shop", "combat"],
			]
		3, 4:
			return [
				["combat", "shop", "combat"],
				["combat", "combat", "shop"],
				["combat", "elite", "combat"],
			]
		5, 6:
			return [
				["combat", "elite", "rest"],
				["combat", "combat", "shop"],
				["combat", "shop", "elite"],
			]
		7, 8:
			return [
				["elite", "combat", "rest"],
				["combat", "elite", "shop"],
				["combat", "combat", "elite"],
			]
		9, 10:
			return [
				["combat", "elite", "rest"],
				["elite", "combat", "shop"],
				["combat", "elite", "combat"],
			]
		11, 12:
			return [
				["combat", "elite", "rest"],
				["elite", "combat", "shop"],
				["combat", "elite", "combat"],
			]
		13:
			return [
				["rest", "shop", "combat"],
				["rest", "combat", "shop"],
			]
		_:
			return [["combat", "combat", "combat"]]


# Assign normalized x positions to nodes in each floor (evenly spaced).
static func _assign_positions(floors: Array) -> void:
	for floor in floors:
		var count: int = floor.size()
		for i in range(count):
			floor[i]["x"] = (float(i) + 0.5) / float(count)


# Generate connections between all adjacent floor pairs.
static func _connect_all_floors(floors: Array) -> void:
	for i in range(floors.size() - 1):
		_connect_floors(floors[i], floors[i + 1])


# Connect nodes between two adjacent floors.
# Rules: each node connects to 1–2 nearest nodes above;
# every node above receives at least 1 connection.
static func _connect_floors(floor_below: Array, floor_above: Array) -> void:
	for node in floor_below:
		node["connections"] = []
	# Each node below connects to 1–2 nearest nodes above
	for i in range(floor_below.size()):
		var from_x: float = floor_below[i]["x"]
		var sorted_above: Array = _sort_by_distance(from_x, floor_above)
		# Always connect to nearest
		floor_below[i]["connections"].append(sorted_above[0])
		# 40% chance to also connect to second nearest
		if sorted_above.size() > 1 and randf() < 0.4:
			floor_below[i]["connections"].append(sorted_above[1])
	# Ensure every node above has at least one incoming connection
	var connected: Dictionary = {}
	for node in floor_below:
		for conn in node["connections"]:
			connected[conn] = true
	for j in range(floor_above.size()):
		if not connected.has(j):
			# Find nearest node below and add this connection
			var nearest_below: int = 0
			var nearest_dist: float = 999.0
			for i in range(floor_below.size()):
				var dist: float = absf(floor_below[i]["x"] - floor_above[j]["x"])
				if dist < nearest_dist:
					nearest_dist = dist
					nearest_below = i
			if not j in floor_below[nearest_below]["connections"]:
				floor_below[nearest_below]["connections"].append(j)


# Sort indices of floor_above by x distance from from_x (nearest first).
static func _sort_by_distance(from_x: float, floor_above: Array) -> Array:
	var pairs: Array = []
	for j in range(floor_above.size()):
		pairs.append({"index": j, "dist": absf(from_x - floor_above[j]["x"])})
	pairs.sort_custom(func(a, b): return a["dist"] < b["dist"])
	return pairs.map(func(p): return p["index"])
