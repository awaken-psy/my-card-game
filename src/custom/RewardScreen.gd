# Post-combat reward screen for My Card Game.
#
# Two-phase STS-style reward flow:
#   Phase A: Reward list (card reward, gold placeholder, etc.)
#   Phase B: Card selection (3 real Card instances via cfc.instance_card)
#   Phase C: Result screen (victory/defeat/run complete)
extends Control

signal reward_selected(card_name: String)
signal reward_skipped
signal continue_run
signal return_to_menu

const _SetDefinition = preload("res://src/custom/cards/sets/SetDefinition_MyCardGame.gd")
const _CFConst = preload("res://src/custom/CFConst.gd")

var _viewport_size: Vector2 = Vector2(1280, 720)
var _selected_card_name: String = ""
var _reward_card_names: Array = []
var _gold_reward: int = 0


# Called by CGFBoard after adding this node to the tree.
func setup(viewport_size: Vector2) -> void:
	_viewport_size = viewport_size
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


# --- Public API (called by CGFBoard) ---


func show_victory_rewards(_is_final_encounter: bool = false, gold_amount: int = 0) -> void:
	_gold_reward = gold_amount
	cfc.game_paused = true
	_clear_ui()
	_build_overlay()
	_build_reward_list()
	visible = true


func show_run_complete(remaining_hp: int, max_hp: int) -> void:
	cfc.game_paused = true
	_clear_ui()
	_build_overlay()
	_build_run_complete_screen(remaining_hp, max_hp)
	visible = true


func show_game_over() -> void:
	cfc.game_paused = true
	_clear_ui()
	_build_overlay()
	_build_result_screen(false, "")
	visible = true


# --- UI Building ---


func _clear_ui() -> void:
	_selected_card_name = ""
	_reward_card_names = []
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


# --- Phase A: Reward List ---


func _build_reward_list() -> void:
	var center_x: float = _viewport_size.x / 2.0
	var center_y: float = _viewport_size.y / 2.0

	# Title
	var title := Label.new()
	title.name = "RewardTitle"
	title.text = "★ 战斗奖励 ★"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(center_x - 200, center_y - 170)
	title.size = Vector2(400, 50)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("outline_size", 2)
	add_child(title)

	# Reward entries container
	var entries_vbox := VBoxContainer.new()
	entries_vbox.name = "RewardEntries"
	entries_vbox.position = Vector2(center_x - 160, center_y - 90)
	entries_vbox.size = Vector2(320, 200)
	entries_vbox.add_theme_constant_override("separation", 14)

	# Card reward entry (clickable)
	var card_entry := _create_list_entry("🃏  卡牌奖励", "选择一张卡牌加入牌组", true)
	card_entry.name = "CardRewardEntry"
	card_entry.connect("pressed", Callable(self, "_on_card_reward_clicked"))
	entries_vbox.add_child(card_entry)

	# Gold entry (real gold reward)
	if _gold_reward > 0:
		var gold_entry := _create_list_entry("💰  金币 +%d" % _gold_reward, "已自动获得", false)
		gold_entry.name = "GoldEntry"
		entries_vbox.add_child(gold_entry)

	add_child(entries_vbox)

	# Skip button
	var skip_button := Button.new()
	skip_button.name = "SkipButton"
	skip_button.text = "跳过所有奖励"
	skip_button.position = Vector2(center_x - 100, center_y + 150)
	skip_button.size = Vector2(200, 45)
	skip_button.add_theme_font_size_override("font_size", 16)
	_style_button_secondary(skip_button)
	skip_button.connect("pressed", Callable(self, "_on_skip_pressed"))
	add_child(skip_button)

	# Stagger entry animation (#19)
	_animate_entries(entries_vbox, center_y)


func _create_list_entry(title_text: String, subtitle_text: String, clickable: bool) -> Control:
	if clickable:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(320, 70)
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(0.15, 0.15, 0.25)
		normal.border_color = Color(0.7, 0.6, 0.3)
		normal.set_border_width_all(2)
		normal.set_corner_radius_all(10)
		normal.content_margin_left = 20
		normal.content_margin_right = 20
		normal.content_margin_top = 12
		normal.content_margin_bottom = 12
		var hover := normal.duplicate()
		hover.bg_color = Color(0.22, 0.22, 0.38)
		hover.border_color = Color(1, 0.85, 0.3)
		hover.set_border_width_all(3)
		var pressed := normal.duplicate()
		pressed.bg_color = Color(0.1, 0.1, 0.18)
		pressed.border_color = Color(0.5, 0.4, 0.2)
		btn.add_theme_stylebox_override("normal", normal)
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_stylebox_override("pressed", pressed)
		btn.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
		btn.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.5))
		# Two-line text
		btn.text = "%s\n[color=gray]%s[/color]" % [title_text, subtitle_text]
		# Fallback: plain text (BBCode not supported on Button by default)
		btn.text = title_text
		btn.add_theme_font_size_override("font_size", 20)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		return btn
	else:
		var panel := Panel.new()
		panel.custom_minimum_size = Vector2(320, 70)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.15, 0.7)
		style.border_color = Color(0.35, 0.35, 0.35)
		style.set_border_width_all(1)
		style.set_corner_radius_all(10)
		style.content_margin_left = 20
		style.content_margin_right = 20
		style.content_margin_top = 12
		style.content_margin_bottom = 12
		panel.add_theme_stylebox_override("panel", style)
		var vbox := VBoxContainer.new()
		vbox.anchor_right = 1.0
		vbox.anchor_bottom = 1.0
		vbox.offset_left = 20
		vbox.offset_right = -20
		vbox.offset_top = 12
		vbox.offset_bottom = -12
		vbox.add_theme_constant_override("separation", 2)
		var t := Label.new()
		t.text = title_text
		t.add_theme_font_size_override("font_size", 18)
		t.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		vbox.add_child(t)
		var s := Label.new()
		s.text = subtitle_text
		s.add_theme_font_size_override("font_size", 12)
		s.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		vbox.add_child(s)
		panel.add_child(vbox)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return panel


func _on_card_reward_clicked() -> void:
	_clear_ui()
	_build_overlay()
	_build_card_selection()
	visible = true


# --- Phase B: Card Selection (real Card instances) ---


func _build_card_selection() -> void:
	var center_x: float = _viewport_size.x / 2.0

	# Title
	var title := Label.new()
	title.name = "CardSelectTitle"
	title.text = "★ 选择一张卡牌 ★"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(center_x - 200, 50)
	title.size = Vector2(400, 50)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("outline_size", 2)
	add_child(title)

	# Create 3 real card instances
	_reward_card_names = _pick_3_rewards()
	var card_scale := 1.5
	var card_width: float = _CFConst.CARD_SIZE.x * card_scale
	var card_height: float = _CFConst.CARD_SIZE.y * card_scale
	var gap: float = 30.0
	var total_width: float = _reward_card_names.size() * card_width + (_reward_card_names.size() - 1) * gap
	var start_x: float = center_x - total_width / 2.0
	var target_y: float = 130.0

	var card_nodes: Array = []
	var target_positions: Array = []

	for i in range(_reward_card_names.size()):
		var card_name: String = _reward_card_names[i]
		var card_x: float = start_x + i * (card_width + gap)

		# Create real Card instance
		var card = cfc.instance_card(card_name)
		card.z_index = 5
		add_child(card)
		# Disable framework processing to prevent state-based scale override
		card.set_process(false)
		card.set_is_faceup(true, true)
		card.scale = Vector2(card_scale, card_scale)
		card.position = Vector2(card_x, _viewport_size.y + 50) # start below screen
		# Hide manipulation buttons
		var mb = card.get_node_or_null("Control/ManipulationButtons")
		if mb:
			mb.visible = false
		card_nodes.append(card)
		target_positions.append(Vector2(card_x, target_y))

		# Selection highlight border (initially invisible)
		var highlight := Panel.new()
		highlight.name = "Highlight_" + card_name
		highlight.position = Vector2(card_x - 4, target_y - 4)
		highlight.size = Vector2(card_width + 8, card_height + 8)
		var h_style := StyleBoxFlat.new()
		h_style.bg_color = Color(0, 0, 0, 0)
		h_style.border_color = Color(1, 0.85, 0.2, 0)
		h_style.set_border_width_all(4)
		h_style.set_corner_radius_all(8)
		highlight.add_theme_stylebox_override("panel", h_style)
		highlight.z_index = 6
		highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(highlight)

		# Clickable overlay (captures all mouse events before card can)
		var click_area := Control.new()
		click_area.name = "ClickArea_" + card_name
		click_area.position = Vector2(card_x, target_y)
		click_area.size = Vector2(card_width, card_height)
		click_area.z_index = 10
		click_area.mouse_filter = Control.MOUSE_FILTER_STOP
		click_area.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		click_area.connect("gui_input", Callable(self, "_on_reward_card_gui_input").bind(card_name))
		click_area.connect("mouse_entered", Callable(self, "_on_reward_card_hover").bind(card_name, true))
		click_area.connect("mouse_exited", Callable(self, "_on_reward_card_hover").bind(card_name, false))
		add_child(click_area)

	# Stagger entry animation (#19): cards slide up from below
	for i in range(card_nodes.size()):
		var card = card_nodes[i]
		var target = target_positions[i]
		var tween := create_tween()
		# Force correct scale (framework may override during _ready)
		tween.tween_property(card, "scale", Vector2(card_scale, card_scale), 0.01)
		tween.tween_property(card, "position", target, 0.5)\
			.set_delay(0.15 * i)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Bottom buttons
	var btn_y: float = target_y + card_height + 30

	var confirm_btn := Button.new()
	confirm_btn.name = "ConfirmButton"
	confirm_btn.text = "确认选择"
	confirm_btn.position = Vector2(center_x - 70, btn_y)
	confirm_btn.size = Vector2(140, 45)
	confirm_btn.add_theme_font_size_override("font_size", 16)
	confirm_btn.disabled = true
	_style_button_primary(confirm_btn)
	confirm_btn.connect("pressed", Callable(self, "_on_confirm_card"))
	add_child(confirm_btn)

	var back_btn := Button.new()
	back_btn.name = "BackButton"
	back_btn.text = "返回"
	back_btn.position = Vector2(center_x - 50, btn_y + 55)
	back_btn.size = Vector2(100, 35)
	back_btn.add_theme_font_size_override("font_size", 14)
	_style_button_secondary(back_btn)
	back_btn.connect("pressed", Callable(self, "_on_card_selection_back"))
	add_child(back_btn)


func _on_reward_card_gui_input(event: InputEvent, card_name: String) -> void:
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and not event.is_pressed():
		_select_card(card_name)


func _on_reward_card_hover(card_name: String, entering: bool) -> void:
	var card = get_node_or_null(card_name)
	if not card:
		return
	if entering and _selected_card_name != card_name:
		card.modulate = Color(1.15, 1.15, 1.15)
	elif _selected_card_name != card_name:
		card.modulate = Color.WHITE


func _select_card(card_name: String) -> void:
	_selected_card_name = card_name
	# Update highlights and dimming
	for cn in _reward_card_names:
		var highlight = get_node_or_null("Highlight_" + cn)
		var card = get_node_or_null(cn)
		if not highlight or not card:
			continue
		var style: StyleBoxFlat = highlight.get_theme_stylebox("panel")
		if cn == card_name:
			style.border_color = Color(1, 0.85, 0.2)
			card.modulate = Color.WHITE
		else:
			style.border_color = Color(0.5, 0.5, 0.5, 0.5)
			card.modulate = Color(0.5, 0.5, 0.5)
	# Enable confirm button
	var confirm = get_node_or_null("ConfirmButton")
	if confirm:
		confirm.disabled = false


func _on_confirm_card() -> void:
	if _selected_card_name == "":
		return
	var chosen := _selected_card_name
	emit_signal("reward_selected", chosen)
	_clear_ui()
	_build_overlay()
	_build_result_screen(true, chosen)
	visible = true


func _on_card_selection_back() -> void:
	_clear_ui()
	_build_overlay()
	_build_reward_list()
	visible = true


# --- Phase C: Result Screen ---


func _build_result_screen(is_victory: bool, selected_card: String) -> void:
	var center_x: float = _viewport_size.x / 2.0
	var center_y: float = _viewport_size.y / 2.0

	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(center_x - 200, center_y - 100)
	title.size = Vector2(400, 50)
	title.add_theme_font_size_override("font_size", 36)
	add_child(title)

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
			subtitle.text = "%s 已加入牌组!" % selected_card
		else:
			subtitle.text = "奖励已跳过。"

		var continue_button := Button.new()
		continue_button.text = "Continue"
		continue_button.position = Vector2(center_x - 120, center_y + 20)
		continue_button.size = Vector2(240, 50)
		continue_button.add_theme_font_size_override("font_size", 18)
		_style_button_primary(continue_button)
		continue_button.connect("pressed", Callable(self, "_on_continue_pressed"))
		add_child(continue_button)
	else:
		title.text = "Game Over"
		title.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		subtitle.text = "你已被击败。"
		subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

		var return_button := Button.new()
		return_button.text = "返回主菜单"
		return_button.position = Vector2(center_x - 120, center_y + 20)
		return_button.size = Vector2(240, 50)
		return_button.add_theme_font_size_override("font_size", 18)
		_style_button_secondary(return_button)
		return_button.connect("pressed", Callable(self, "_on_return_pressed"))
		add_child(return_button)


func _build_run_complete_screen(remaining_hp: int, max_hp: int) -> void:
	var center_x: float = _viewport_size.x / 2.0
	var center_y: float = _viewport_size.y / 2.0

	var title := Label.new()
	title.text = "🎉 Run Complete! 🎉"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(center_x - 200, center_y - 80)
	title.size = Vector2(400, 50)
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = "你击败了全部 %d 个敌人!" % _SetDefinition.CARDS.size() # placeholder
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.position = Vector2(center_x - 200, center_y - 25)
	subtitle.size = Vector2(400, 30)
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	add_child(subtitle)

	var hp_label := Label.new()
	hp_label.text = "剩余 HP: %d/%d" % [remaining_hp, max_hp]
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.position = Vector2(center_x - 150, center_y + 20)
	hp_label.size = Vector2(300, 30)
	hp_label.add_theme_font_size_override("font_size", 18)
	hp_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	add_child(hp_label)

	var return_button := Button.new()
	return_button.text = "返回主菜单"
	return_button.position = Vector2(center_x - 120, center_y + 70)
	return_button.size = Vector2(240, 50)
	return_button.add_theme_font_size_override("font_size", 18)
	_style_button_secondary(return_button)
	return_button.connect("pressed", Callable(self, "_on_return_pressed"))
	add_child(return_button)


# --- Card Selection Logic ---


func _pick_3_rewards() -> Array:
	var reward_pool: Array = []
	for card_name in _SetDefinition.CARDS:
		var card_data: Dictionary = _SetDefinition.CARDS[card_name]
		if card_data.get("_rarity", "") != "Starter":
			reward_pool.append(card_name)
	reward_pool.shuffle()
	var count: int = mini(3, reward_pool.size())
	return reward_pool.slice(0, count)


func _on_skip_pressed() -> void:
	emit_signal("reward_skipped")
	_clear_ui()
	_build_overlay()
	_build_result_screen(true, "")


func _on_continue_pressed() -> void:
	cfc.game_paused = false
	emit_signal("continue_run")


func _on_return_pressed() -> void:
	cfc.game_paused = false
	emit_signal("return_to_menu")


# --- Entry Animation Helper ---


func _animate_entries(container: VBoxContainer, center_y: float) -> void:
	var target_y: float = container.position.y
	# Start below screen
	container.position.y = _viewport_size.y + 50
	# Tween to target
	var tween := create_tween()
	tween.tween_property(container, "position:y", target_y, 0.5)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Also animate skip button
	var skip = get_node_or_null("SkipButton")
	if skip:
		var skip_target_y: float = skip.position.y
		skip.position.y = _viewport_size.y + 50
		tween.parallel().tween_property(skip, "position:y", skip_target_y, 0.5)\
			.set_delay(0.15)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- Button Styling ---


func _style_button_primary(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.15, 0.25)
	normal.border_color = Color(0.7, 0.6, 0.3)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(8)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8

	var hover := normal.duplicate()
	hover.bg_color = Color(0.22, 0.22, 0.38)
	hover.border_color = Color(1, 0.85, 0.3)
	hover.set_border_width_all(3)

	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.1, 0.1, 0.18)
	pressed.border_color = Color(0.5, 0.4, 0.2)

	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.08, 0.08, 0.12, 0.5)
	disabled.border_color = Color(0.3, 0.3, 0.3)
	disabled.set_border_width_all(1)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color(1, 0.85, 0.3))
	btn.add_theme_color_override("font_disabled_color", Color(0.4, 0.4, 0.4))


func _style_button_secondary(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.12, 0.18)
	normal.border_color = Color(0.5, 0.5, 0.5)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6

	var hover := normal.duplicate()
	hover.bg_color = Color(0.18, 0.18, 0.28)
	hover.border_color = Color(0.8, 0.8, 0.8)

	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.08, 0.08, 0.12)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
