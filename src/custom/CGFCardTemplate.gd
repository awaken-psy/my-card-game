extends Card

# CombatManager reference, set by CGFBoard during setup
var combat_manager: Node = null

# --- Hover oscillation fix ---
# When the card is at the bottom of the hand and the mouse hovers near its
# bottom edge, the focus animation moves the card up past the cursor. This
# causes mouse_exited → unfocus → card drops back → mouse_entered → focus →
# repeating in an infinite oscillation loop.
# We fix this by tracking the card's original bounding rect when focus begins,
# and only unfocusing when the mouse leaves that original area (not the
# post-animation position).
var _focus_origin_rect: Rect2 = Rect2()
var _focus_tracking: bool = false


func _ready() -> void:
	super._ready()
	_apply_play_mode()
	# Speed up animations for snappier feel
	focus_tween_duration = 0.075
	dragged_tween_duration = 0.1
	reorganization_tween_duration = 0.2


# Configure drag/click interaction based on the board's play_mode setting.
func _apply_play_mode() -> void:
	if cfc.NMAP.has("board") and cfc.NMAP.board.play_mode == "drag":
		disable_dragging_from_hand = false
		board_placement = BoardPlacement.ANYWHERE
	else:
		disable_dragging_from_hand = true
		board_placement = BoardPlacement.NONE


# Catch mouse release at input level (before gui_input) to ensure
# drag drop is always detected, even when Controls obscure the card.
func _input(event: InputEvent) -> void:
	if state == CardState.DRAGGED and event is InputEventMouseButton:
		if event.get_button_index() == 1 and not event.is_pressed():
			_handle_drag_drop()
			get_viewport().set_input_as_handled()
			return

func _process(delta) -> void:
	super._process(delta)
	# Hover oscillation fix: check if mouse has truly left the card's
	# original (pre-focus) position before unfocusing.
	if _focus_tracking and state == CardState.FOCUSED_IN_HAND:
		var mouse_pos := get_global_mouse_position()
		if not _focus_origin_rect.has_point(mouse_pos):
			_focus_tracking = false
			# Mouse genuinely left the card's original area — unfocus
			if get_parent().is_in_group("hands"):
				for c in get_parent().get_all_cards():
					c.interruptTweening()
					c.reorganize_self()
	elif _focus_tracking:
		_focus_tracking = false


# Store the card's original rect before the focus animation moves it.
func _on_Card_mouse_entered() -> void:
	if cfc.game_paused:
		return
	_focus_tracking = false
	if state == CardState.IN_HAND:
		# Record original bounding rect before focus animation shifts the card
		_focus_origin_rect = Rect2(global_position, $Control.size).grow(4)
	super._on_Card_mouse_entered()


# Delay unfocus: the focus animation may have moved the card away from the
# cursor. Let _process decide when the mouse has truly left the original area.
func _on_Card_mouse_exited() -> void:
	if state == CardState.FOCUSED_IN_HAND:
		_focus_tracking = true
		return
	super._on_Card_mouse_exited()


# Route card interaction based on play_mode:
# - "click": click to play (STS alternative)
# - "drag": drag to target zone (STS classic, default)
func _on_Card_gui_input(event) -> void:
	if event is InputEventMouseButton and cfc.NMAP.has("board"):
		var board = cfc.NMAP.board
		# Z-index check: forward input to the actually focused card
		if board.mouse_pointer.current_focused_card \
				and self != board.mouse_pointer.current_focused_card:
			board.mouse_pointer.current_focused_card._on_Card_gui_input(event)
			return

		if event.get_button_index() == 1:
			if board.play_mode == "click":
				# --- Click mode: play on click release ---
				if not event.is_pressed() and state == CardState.FOCUSED_IN_HAND:
					_try_play_card()
				elif state not in [CardState.IN_HAND, CardState.FOCUSED_IN_HAND]:
					super._on_Card_gui_input(event)
				return
			else:
				# --- Drag mode ---
				if not event.is_pressed() and state == CardState.DRAGGED:
					_handle_drag_drop()
					return
				# Start drag immediately on press (skip framework 0.1s delay)
				# STS style: allow dragging even when energy is insufficient (snaps back on release)
				if event.is_pressed() \
						and state in [CardState.FOCUSED_IN_HAND, CardState.FOCUSED_ON_BOARD, CardState.FOCUSED_IN_POPUP] \
						and combat_manager:
					cfc.card_drag_ongoing = self
					_start_dragging(event.position)
					return
				super._on_Card_gui_input(event)
				return

		if event.get_button_index() == 2:
			if event.is_pressed():
				targeting_arrow.initiate_targeting()
			else:
				targeting_arrow.complete_targeting()
			return
	# For other event types, use framework default
	super._on_Card_gui_input(event)


# --- Drag mode handlers ---


# Called when a card is released while in DRAGGED state.
# Validates the drop target and either plays the card or snaps it back.
func _handle_drag_drop() -> void:
	z_index = 0
	cfc.card_drag_ongoing = null
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	$Control.set_default_cursor_shape(Input.CURSOR_ARROW)
	# Disable enemy highlight
	if cfc.NMAP.board:
		cfc.NMAP.board._set_enemy_highlight(false)
	# Validate drop target
	if _is_valid_drag_drop():
		_try_play_card()
	else:
		# Snap back to hand position
		set_state(CardState.IN_HAND)
		if get_parent().is_in_group("hands"):
			for c in get_parent().get_all_cards():
				c.interruptTweening()
				c.reorganize_self()


# Check if the current drop position is valid for this card type.
# - Attack: must land on enemy area
# - Defense/Power: can be dropped outside hand area
# Always checks energy and turn state.
func _is_valid_drag_drop() -> bool:
	if not combat_manager or not combat_manager.can_play_card(self):
		return false
	var mouse_pos: Vector2 = get_global_mouse_position()
	# If dropped back over the hand area, snap back (cancel play)
	if _is_over_hand(mouse_pos):
		return false
	var card_type: String = properties.get("Type", "")
	if card_type == "Attack":
		# Attack cards auto-target nearest enemy when dragged outside hand
		return true
	else:
		# Defense/Power cards can be dropped anywhere outside hand
		return true


# Check if the given position is within the hand container area.
func _is_over_hand(pos: Vector2) -> bool:
	if not cfc.NMAP.has("hand"):
		return false
	var hand = cfc.NMAP.hand
	var hand_control: Control = hand.get_node("Control")
	if not hand_control:
		return false
	var hand_rect := Rect2(hand.global_position, hand_control.size)
	return hand_rect.has_point(pos)


# Override to force rotation reset and show enemy highlight for attack cards.
func _start_dragging(drag_offset: Vector2) -> void:
	# Force rotation to 0 immediately (prevent tilted drag from incomplete focus tween)
	$Control.rotation_degrees = 0
	super._start_dragging(drag_offset)
	if properties.get("Type", "") == "Attack" and cfc.NMAP.board:
		cfc.NMAP.board._set_enemy_highlight(true)


# --- Card play ---


# Attempt to play this card via the combat manager.
func _try_play_card() -> void:
	if not combat_manager:
		return
	if combat_manager.can_play_card(self):
		combat_manager.play_card(self)


# Override cost check to use energy system instead of framework's credits.
func check_play_costs() -> Color:
	if not combat_manager:
		return CFConst.CostsState.IMPOSSIBLE
	if combat_manager.can_play_card(self):
		return CFConst.CostsState.OK
	else:
		return CFConst.CostsState.IMPOSSIBLE


# --- Compatibility stubs (framework template expects these) ---


func common_move_scripts(new_container: Node, old_container: Node) -> void:
	pass


func get_modified_credits_cost() -> int:
	return properties.get("Cost", 0)


func pay_play_costs() -> void:
	pass
