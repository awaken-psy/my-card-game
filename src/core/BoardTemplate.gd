# Mean to serve as the main play area for [Card] objects.
#
# It functions almost like a [CardContainer].
class_name Board
extends Control

# Simulated mouse position for Unit Testing
var _UT_mouse_position := Vector2(0,0)
# Simulated mouse position for Unit Testing
var _UT_current_mouse_position := Vector2(0,0)
# Simulated mouse position for Unit Testing
var _UT_target_mouse_position := Vector2(0,0)
# Simulated mouse movement speed for Unit Testing.
# The bigger the number, the faster the mouse moves
var _UT_mouse_speed := 3
# Set to true if there's an actual interpolation ongoing
var _UT_interpolation_requested := false
# Used for interpolating
var _t = 0
# Set true on the frame interpolation completes (before overlap check)
var _UT_interpolation_ended := false
# Used for finding the counters node and modifying them
# This variable has to exist if the [mod_counters](ScriptingEngine#mod_counters)
# task is to be used.
var counters : Counters

var mouse_pointer: MousePointer = MousePointer.new()
	

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("board")
	if not cfc.are_all_nodes_mapped:
		await cfc.all_nodes_mapped
	mouse_pointer = load(CFConst.PATH_MOUSE_POINTER).instantiate()
	add_child(mouse_pointer)
	for container in get_tree().get_nodes_in_group("piles"):
		container.re_place()
	for container in get_tree().get_nodes_in_group("hands"):
		container.re_place()


func _process(_delta: float) -> void:
	if _UT_interpolation_requested:
		_t += _delta * _UT_mouse_speed
		if _t >= 1:
			_t = 0
			_UT_mouse_position = _UT_target_mouse_position
			_UT_interpolation_requested = false
			_UT_interpolation_ended = true
		else:
			_UT_mouse_position = _UT_current_mouse_position.lerp(
					_UT_target_mouse_position, _t)
	# Update mouse pointer position in both UT and non-UT modes.
	# In non-UT mode, this relies on determine_global_mouse_pos()
	# returning SubViewport-local coordinates via get_global_mouse_position().
	mouse_pointer.position = \
				mouse_pointer.determine_global_mouse_pos()
	if cfc.ut:
		# Manually detect overlaps since physics Area2D detection is
		# unreliable in headless mode
		var mp_pos = mouse_pointer.position
		var changed = false
		for child in get_children():
			if child is Card or child is CardContainer:
				var col = child.get_node_or_null("CollisionShape2D")
				if col and col.shape is RectangleShape2D:
					var col_pos = child.position + col.position
					var half_ext = col.shape.size / 2.0
					if mp_pos.x >= col_pos.x - half_ext.x and mp_pos.x < col_pos.x + half_ext.x \
							and mp_pos.y >= col_pos.y - half_ext.y and mp_pos.y < col_pos.y + half_ext.y:
						if child not in mouse_pointer.overlaps:
							mouse_pointer.overlaps.append(child)
							changed = true
					else:
						if child in mouse_pointer.overlaps:
							child.highlight.set_highlight(false)
							mouse_pointer.overlaps.erase(child)
							changed = true
			# In headless/UT mode, container child cards are never direct children
			# of Board, so the overlap loop never finds them. Check every frame
			# so focus is detected early enough for the focus tween to complete.
			if cfc.ut and not cfc.card_drag_ongoing:
				var prev_cards = mouse_pointer._ut_container_cards.duplicate()
				mouse_pointer._ut_container_cards.clear()
				for cont in get_children():
					if cont is CardContainer:
						for subcard in cont.get_children():
							if subcard is Card:
								var subcol = subcard.get_node_or_null("CollisionShape2D")
								if subcol and subcol.shape is RectangleShape2D:
									var cc = cont.position + subcard.position + subcol.position
									var hs = subcol.shape.size / 2.0
									if mp_pos.x >= cc.x - hs.x and mp_pos.x < cc.x + hs.x and mp_pos.y >= cc.y - hs.y and mp_pos.y < cc.y + hs.y:
										mouse_pointer._ut_container_cards.append(subcard)
				if prev_cards != mouse_pointer._ut_container_cards:
					changed = true
			if _UT_interpolation_ended:
				_UT_interpolation_ended = false
		if changed:
			mouse_pointer._discover_focus()


# This function is called by unit testing to simulate mouse movement on the board
func _UT_interpolate_mouse_move(newpos: Vector2,
		startpos := Vector2(-1,-1), mouseSpeed := 3) -> void:
#	print_debug(newpos, _UT_mouse_position)
	if startpos == Vector2(-1,-1):
		_UT_current_mouse_position = _UT_mouse_position
	else:
		_UT_current_mouse_position = startpos
	_UT_mouse_speed = mouseSpeed
	_UT_target_mouse_position = newpos
	_UT_interpolation_requested = true


# Returns an array with all children nodes which are of Card class
func get_all_cards() -> Array:
	var cardsArray := []
	for obj in get_children():
		if obj as Card: cardsArray.append(obj)
	return(cardsArray)

# Overridable function which returns all objects on the table which can
# be used as subjects by the scripting engine.
func get_all_scriptables() -> Array:
	return(get_all_cards())


# Returns an int with the amount of children nodes which are of Card class
func get_card_count() -> int:
	return(get_all_cards().size())


# Returns a card object of the card in the specified index among all cards.
func get_card(idx: int) -> Card:
	return(get_all_cards()[idx])


# Returns an int of the index of the card object requested
func get_card_index(card: Card) -> int:
	return(get_all_cards().find(card))


# Returns the BoardPlacementGrid object with the specified name
func get_grid(grid_name: String) -> BoardPlacementGrid:
	var found_grid: BoardPlacementGrid
	for grid in get_tree().get_nodes_in_group("placement_grid"):
		if grid.name_label.text == grid_name:
			found_grid = grid
	return(found_grid)

# warning-ignore:unused_argument
func get_final_placement_node(card: Card) -> Node:
	return(self)
