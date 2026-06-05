# Post-combat reward screen for My Card Game.
#
# Victory: shows 3 random reward cards from the pool (non-Starter),
#          player picks one or skips, then sees victory message.
# Defeat:  shows Game Over message.
#
# Both end with a "Return to Main Menu" button.
#
# TODO (M8): Replace text-based card panels with real card instances for
#            richer visuals.
extends Control

signal reward_selected(card_name: String)
signal reward_skipped
signal return_to_menu

const _SetDefinition = preload("res://src/custom/cards/sets/SetDefinition_MyCardGame.gd")

var _viewport_size: Vector2 = Vector2(1280, 720)


# Called by CGFBoard after adding this node to the tree.
func setup(viewport_size: Vector2) -> void:
	_viewport_size = viewport_size
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


# --- Public API (called by CGFBoard) ---


# Show the reward selection screen (victory path).
func show_victory_rewards() -> void:
	_clear_ui()
	_build_overlay()
	_build_reward_selection()
	visible = true


# Show the game over screen (defeat path).
func show_game_over() -> void:
	_clear_ui()
	_build_overlay()
	_build_result_screen(false, "")
	visible = true


# --- UI Building ---


func _clear_ui() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()


func _build_overlay() -> void:
	var overlay := ColorRect.new()
	overlay.name = "Overlay"
	overlay.color = Color(0, 0, 0, 0.75)
	overlay.position = Vector2.ZERO
	overlay.size = _viewport_size
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)


func _build_reward_selection() -> void:
	var center_x: float = _viewport_size.x / 2.0
	var start_y: float = 60.0

	# Title
	var title := Label.new()
	title.name = "RewardTitle"
	title.text = "★ Choose a Reward ★"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(center_x - 200, start_y)
	title.size = Vector2(400, 40)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	add_child(title)

	# Pick 3 random reward cards (non-duplicate)
	var reward_cards: Array = _pick_3_rewards()
	var panel_width: float = 170.0
	var panel_height: float = 240.0
	var gap: float = 40.0
	var total_width: float = 3 * panel_width + 2 * gap
	var start_x: float = center_x - total_width / 2.0
	var cards_y: float = start_y + 70.0

	for i in range(reward_cards.size()):
		var card_name: String = reward_cards[i]
		var card_data: Dictionary = _SetDefinition.CARDS[card_name]
		var panel: Control = _create_card_panel(card_name, card_data)
		panel.position = Vector2(start_x + i * (panel_width + gap), cards_y)
		panel.size = Vector2(panel_width, panel_height)
		add_child(panel)

	# Skip button
	var skip_button := Button.new()
	skip_button.name = "SkipButton"
	skip_button.text = "Skip Reward"
	skip_button.position = Vector2(center_x - 80, cards_y + panel_height + 30)
	skip_button.size = Vector2(160, 45)
	skip_button.add_theme_font_size_override("font_size", 16)
	skip_button.connect("pressed", Callable(self, "_on_skip_pressed"))
	add_child(skip_button)


func _build_result_screen(is_victory: bool, selected_card: String) -> void:
	var center_x: float = _viewport_size.x / 2.0
	var center_y: float = _viewport_size.y / 2.0

	# Title
	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(center_x - 200, center_y - 100)
	title.size = Vector2(400, 50)
	title.add_theme_font_size_override("font_size", 36)
	add_child(title)

	# Subtitle
	var subtitle := Label.new()
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.position = Vector2(center_x - 250, center_y - 40)
	subtitle.size = Vector2(500, 30)
	subtitle.add_theme_font_size_override("font_size", 18)
	add_child(subtitle)

	if is_victory:
		title.text = "Victory!"
		title.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
		if selected_card != "":
			subtitle.text = "%s added to your deck!" % selected_card
		else:
			subtitle.text = "Reward skipped."
	else:
		title.text = "Game Over"
		title.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		subtitle.text = "You have been defeated."
		subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

	# Return to Main Menu button
	var return_button := Button.new()
	return_button.text = "Return to Main Menu"
	return_button.position = Vector2(center_x - 120, center_y + 20)
	return_button.size = Vector2(240, 50)
	return_button.add_theme_font_size_override("font_size", 18)
	return_button.connect("pressed", Callable(self, "_on_return_pressed"))
	add_child(return_button)


# Create a text-based card panel for the reward selection.
# TODO (M8): Replace with real card instance rendering.
func _create_card_panel(card_name: String, card_data: Dictionary) -> Control:
	var panel := Panel.new()
	panel.name = "RewardCard_" + card_name

	# Styling: dark background with gold border
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18)
	style.border_color = Color(0.7, 0.6, 0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	# Content layout
	var vbox := VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 10
	vbox.offset_right = -10
	vbox.offset_top = 10
	vbox.offset_bottom = -10
	vbox.add_theme_constant_override("separation", 6)

	# Card name (colored by type)
	var name_label := Label.new()
	name_label.text = card_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", _get_type_color(card_data.get("Type", "")))
	vbox.add_child(name_label)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_stylebox_override("separator", StyleBoxEmpty.new())
	vbox.add_child(sep)

	# Cost
	var cost_label := Label.new()
	cost_label.text = "Cost: %d ⚡" % card_data.get("Cost", 0)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(cost_label)

	# Type badge
	var type_label := Label.new()
	type_label.text = "[%s]" % card_data.get("Type", "")
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.add_theme_font_size_override("font_size", 12)
	type_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(type_label)

	# Abilities description
	var desc_label := Label.new()
	desc_label.text = card_data.get("Abilities", "")
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_label)

	# Rarity badge
	var rarity: String = card_data.get("_rarity", "")
	var rarity_label := Label.new()
	rarity_label.text = "[%s]" % rarity
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.add_theme_font_size_override("font_size", 11)
	rarity_label.add_theme_color_override("font_color", _get_rarity_color(rarity))
	vbox.add_child(rarity_label)

	panel.add_child(vbox)

	# Make clickable
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.connect("gui_input", Callable(self, "_on_card_panel_gui_input").bind(card_name))
	panel.connect("mouse_entered", Callable(self, "_on_card_panel_hover").bind(panel, true))
	panel.connect("mouse_exited", Callable(self, "_on_card_panel_hover").bind(panel, false))

	return panel


# --- Card Selection Logic ---


# Pick 3 random non-duplicate cards from the reward pool (non-Starter).
func _pick_3_rewards() -> Array:
	var reward_pool: Array = []
	for card_name in _SetDefinition.CARDS:
		var card_data: Dictionary = _SetDefinition.CARDS[card_name]
		if card_data.get("_rarity", "") != "Starter":
			reward_pool.append(card_name)
	reward_pool.shuffle()
	var count: int = mini(3, reward_pool.size())
	return reward_pool.slice(0, count)


func _on_card_panel_gui_input(event: InputEvent, card_name: String) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.is_pressed():
			_on_card_selected(card_name)


func _on_card_panel_hover(panel: Control, entering: bool) -> void:
	var style: StyleBoxFlat = panel.get_theme_stylebox("panel")
	if entering:
		style.border_color = Color(1, 0.85, 0.3)
		style.set_border_width_all(3)
	else:
		style.border_color = Color(0.7, 0.6, 0.3)
		style.set_border_width_all(2)


func _on_card_selected(card_name: String) -> void:
	emit_signal("reward_selected", card_name)
	_clear_ui()
	_build_overlay()
	_build_result_screen(true, card_name)


func _on_skip_pressed() -> void:
	emit_signal("reward_skipped")
	_clear_ui()
	_build_overlay()
	_build_result_screen(true, "")


func _on_return_pressed() -> void:
	emit_signal("return_to_menu")


# --- Helpers ---


static func _get_type_color(card_type: String) -> Color:
	match card_type:
		"Attack":
			return Color(1, 0.4, 0.4)
		"Skill":
			return Color(0.4, 0.6, 1.0)
		"Power":
			return Color(0.8, 0.5, 1.0)
		_:
			return Color.WHITE


static func _get_rarity_color(rarity: String) -> Color:
	match rarity:
		"Common":
			return Color(0.7, 0.7, 0.7)
		"Uncommon":
			return Color(0.3, 0.8, 0.3)
		"Rare":
			return Color(1.0, 0.7, 0.2)
		_:
			return Color(0.5, 0.5, 0.5)
