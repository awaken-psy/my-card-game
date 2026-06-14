# Forge screen for My Card Game (M13).
#
# STS-style forge where the player can upgrade one card from their deck.
# Shows all upgradeable cards, player selects one to upgrade.
extends Control

signal forge_completed
signal forge_cancelled

const _SetDefinition = preload("res://src/custom/cards/sets/SetDefinition_MyCardGame.gd")
const _CFConst = preload("res://src/custom/CFConst.gd")

var _viewport_size: Vector2 = Vector2(1280, 720)
var _run_state: RefCounted
var _board: Node
var _upgradeable_cards: Array = []  # [{card_name, upgrade_name}]
var _selected_card_index: int = -1


# Called by CGFBoard after adding this node to the tree.
func setup(viewport_size: Vector2, run_state: RefCounted, board: Node) -> void:
	_viewport_size = viewport_size
	_run_state = run_state
	_board = board
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_forge() -> void:
	cfc.game_paused = true
	_clear_ui()
	_find_upgradeable_cards()
	_build_forge()
	visible = true


# --- Card Upgrade Definitions ---

# Maps base card names to their upgraded versions.
# Upgraded cards have "+" suffix and improved stats.
const UPGRADE_PATHS := {
	# === Starting Deck ===
	"Strike": {
		"name": "Strike+",
		"Damage": 9,  # +3 damage
		"Abilities": "造成 9 点伤害",
	},
	"Defend": {
		"name": "Defend+",
		"Block": 8,  # +3 block
		"Abilities": "获得 8 点格挡",
	},
	"Bash": {
		"name": "Bash+",
		"Damage": 10,  # +2 damage
		"Abilities": "造成 10 点伤害\n施加 3 层易伤",  # +1 vulnerable
		"_effects": ["vulnerable:3"],
	},
	# === Reward Pool ===
	"Cleave": {
		"name": "Cleave+",
		"Damage": 11,  # +3 damage
		"Abilities": "造成 11 点伤害",
	},
	"Iron Wave": {
		"name": "Iron Wave+",
		"Damage": 7,  # +2 damage
		"Block": 7,   # +2 block
		"Abilities": "造成 7 点伤害\n获得 7 点格挡",
	},
	"Shrug It Off": {
		"name": "Shrug It Off+",
		"Block": 11,  # +3 block
		"Abilities": "获得 11 点格挡\n抽 1 张牌",
	},
	"Pommel Strike": {
		"name": "Pommel Strike+",
		"Damage": 12,  # +3 damage
		"Abilities": "造成 12 点伤害\n抽 1 张牌",
	},
	"Inflame": {
		"name": "Inflame+",
		"Abilities": "获得 3 点力量（永久）",  # +1 strength
		"_effects": ["strength:3"],
	},
	"Bloodletting": {
		"name": "Bloodletting+",
		"Abilities": "失去 3 HP\n获得 3 点能量",  # +1 energy
		"_effects": ["lose_hp:3", "gain_energy:3"],
	},
	"Heavy Blow": {
		"name": "Heavy Blow+",
		"Damage": 20,  # +6 damage
		"Abilities": "造成 20 点伤害\n（受力量加成）",
	},
	"Poison Stab": {
		"name": "Poison Stab+",
		"Damage": 6,  # +2 damage
		"Abilities": "造成 6 点伤害\n施加 4 层中毒",  # +1 poison
		"_effects": ["poison:4"],
	},
	"Crippling Blow": {
		"name": "Crippling Blow+",
		"Damage": 12,  # +3 damage
		"Abilities": "造成 12 点伤害\n施加 3 层虚弱",  # +1 weak
		"_effects": ["weak:3"],
	},
	"Bandage": {
		"name": "Bandage+",
		"Abilities": "回复 10 HP",  # +4 heal
		"_effects": ["heal:10"],
	},
	"Thorns": {
		"name": "Thorns+",
		"Block": 12,  # +4 block
		"Abilities": "获得 12 点格挡\n获得 4 点荆棘",  # +1 thorns
		"_effects": ["thorns:4"],
	},
	"Shield Bash": {
		"name": "Shield Bash+",
		"Abilities": "造成等同于格挡值的伤害\n（伤害+50%）",
		"_effects": ["shield_bash_boosted"],
	},
	"Fiend Fire": {
		"name": "Fiend Fire+",
		"Damage": 20,  # +5 damage
		"Abilities": "造成 20 点伤害\n施加 3 层中毒",  # +1 poison
		"_effects": ["poison:3"],
	},
}


# --- UI Building ---


func _clear_ui() -> void:
	_upgradeable_cards.clear()
	_selected_card_index = -1
	for child in get_children():
		remove_child(child)
		child.queue_free()


func _find_upgradeable_cards() -> void:
	# Find all cards in deck that can be upgraded
	_upgradeable_cards.clear()
	var deck: Array = _run_state.deck_card_names
	var seen: Dictionary = {}  # Avoid duplicates

	for card_name in deck:
		if seen.has(card_name):
			continue
		if UPGRADE_PATHS.has(card_name):
			var upgrade_info: Dictionary = UPGRADE_PATHS[card_name]
			_upgradeable_cards.append({
				"base_name": card_name,
				"upgrade_name": upgrade_info.get("name", card_name + "+"),
				"upgrade_info": upgrade_info,
			})
		seen[card_name] = true


func _build_forge() -> void:
	var center_x: float = _viewport_size.x / 2.0
	var center_y: float = _viewport_size.y / 2.0

	# Dark overlay
	var overlay := ColorRect.new()
	overlay.name = "Overlay"
	overlay.color = Color(0, 0, 0, 0.8)
	overlay.size = _viewport_size
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# Title
	var title := Label.new()
	title.name = "ForgeTitle"
	title.text = "⚒️ 锻造 — 升级卡牌"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(center_x - 200, 30)
	title.size = Vector2(400, 50)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1, 0.7, 0.2))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("outline_size", 2)
	add_child(title)

	if _upgradeable_cards.is_empty():
		# No upgradeable cards
		var msg := Label.new()
		msg.text = "没有可升级的卡牌"
		msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		msg.position = Vector2(center_x - 200, center_y - 25)
		msg.size = Vector2(400, 50)
		msg.add_theme_font_size_override("font_size", 24)
		msg.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		add_child(msg)
	else:
		# Build card grid
		_build_card_grid(center_x, center_y)

	# Close button
	var close_btn := Button.new()
	close_btn.name = "CloseButton"
	close_btn.text = "取消"
	close_btn.position = Vector2(center_x - 80, _viewport_size.y - 70)
	close_btn.size = Vector2(160, 45)
	close_btn.add_theme_font_size_override("font_size", 18)
	_style_button_secondary(close_btn)
	close_btn.connect("pressed", Callable(self, "_on_cancel_pressed"))
	add_child(close_btn)


func _build_card_grid(center_x: float, center_y: float) -> void:
	# Card panel dimensions (Control-based, not Area2D)
	var card_width: float = 160.0
	var card_height: float = 250.0
	var arrow_width: float = 30.0  # Space for arrow between cards
	var pair_gap: float = 50.0  # Gap between card pairs

	var display_cards: Array = _upgradeable_cards.slice(0, 5)
	var pair_width: float = card_width * 2 + arrow_width  # base + arrow + upgrade
	var total_width: float = display_cards.size() * pair_width + (display_cards.size() - 1) * pair_gap
	var start_x: float = center_x - total_width / 2.0
	var target_y: float = center_y - card_height / 2.0

	for i in range(display_cards.size()):
		var card_info: Dictionary = display_cards[i]
		var pair_x: float = start_x + i * (pair_width + pair_gap)

		# Container for this card pair
		var container := Control.new()
		container.name = "CardContainer_%d" % i
		container.position = Vector2(pair_x, target_y)
		container.size = Vector2(pair_width, card_height)
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# Base card panel (left side, dimmed)
		var base_abilities: String = _get_base_card_abilities(card_info["base_name"])
		var base_panel := _create_card_panel(
			card_info["base_name"], base_abilities,
			false, card_width, card_height
		)
		base_panel.position = Vector2(0, 0)
		container.add_child(base_panel)

		# Arrow between cards
		var arrow := Label.new()
		arrow.text = "→"
		arrow.position = Vector2(card_width + 5, card_height / 2.0 - 20)
		arrow.size = Vector2(20, 40)
		arrow.add_theme_font_size_override("font_size", 30)
		arrow.add_theme_color_override("font_color", Color(1, 0.7, 0.2))
		arrow.z_index = 10
		container.add_child(arrow)

		# Upgrade card panel (right side, highlighted)
		var upgrade_abilities: String = card_info["upgrade_info"].get("Abilities", "")
		var upgrade_panel := _create_card_panel(
			card_info["upgrade_name"], upgrade_abilities,
			true, card_width, card_height
		)
		upgrade_panel.position = Vector2(card_width + arrow_width, 0)
		container.add_child(upgrade_panel)

		# Click area button (transparent overlay)
		var click_area := Button.new()
		click_area.name = "ClickArea_%d" % i
		click_area.position = Vector2.ZERO
		click_area.size = Vector2(pair_width, card_height)
		click_area.flat = true
		click_area.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_style_click_area(click_area, i)
		click_area.connect("pressed", Callable(self, "_on_card_selected").bind(i))
		container.add_child(click_area)

		add_child(container)

		# Card name label below the pair
		var name_label := Label.new()
		name_label.text = "%s → %s" % [card_info["base_name"], card_info["upgrade_name"]]
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.position = Vector2(pair_x, target_y + card_height + 10)
		name_label.size = Vector2(pair_width, 30)
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		add_child(name_label)


# Create a Control-based card panel (replaces Area2D card instances).
func _create_card_panel(card_name: String, abilities: String, is_upgrade: bool,
		width: float, height: float) -> Panel:
	var panel := Panel.new()
	panel.name = card_name
	panel.size = Vector2(width, height)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 0 if not is_upgrade else 5

	var card_type: String = _get_card_type(card_name)
	var style := _make_card_style(card_type, is_upgrade)
	panel.add_theme_stylebox_override("panel", style)

	# --- Content layout ---
	var margin := 10.0
	var content_w := width - margin * 2
	var content_h := height - margin * 2

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(margin, margin)
	vbox.size = Vector2(content_w, content_h)
	vbox.add_theme_constant_override("separation", 6)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Card name (top, centered)
	var name_label := Label.new()
	name_label.text = card_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.size = Vector2(content_w, 0)
	if is_upgrade:
		name_label.add_theme_font_size_override("font_size", 18)
		name_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	else:
		name_label.add_theme_font_size_override("font_size", 16)
		name_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(name_label)

	# Card type badge
	var type_label := Label.new()
	type_label.text = card_type
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.size = Vector2(content_w, 0)
	type_label.add_theme_font_size_override("font_size", 12)
	type_label.add_theme_color_override("font_color", _get_card_type_color(card_type, is_upgrade))
	vbox.add_child(type_label)

	# Separator line
	var sep := HSeparator.new()
	sep.size = Vector2(content_w, 0)
	vbox.add_child(sep)

	# Description text
	if abilities != "":
		var desc := Label.new()
		desc.text = abilities
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.size = Vector2(content_w, 0)
		desc.add_theme_font_size_override("font_size", 11)
		desc.add_theme_color_override("font_color",
			Color(0.7, 0.7, 0.7) if not is_upgrade else Color(0.95, 0.95, 0.95))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(desc)

	panel.add_child(vbox)
	return panel


# Get the card type (Attack / Skill / Power) from SetDefinition.
func _get_card_type(card_name: String) -> String:
	var cards: Dictionary = _SetDefinition.CARDS
	if cards.has(card_name):
		return cards[card_name].get("Type", "")
	return ""


# Get the base card's description from SetDefinition.
func _get_base_card_abilities(card_name: String) -> String:
	var cards: Dictionary = _SetDefinition.CARDS
	if cards.has(card_name):
		return cards[card_name].get("Abilities", "")
	return ""


# Build StyleBoxFlat for a card panel.
func _make_card_style(card_type: String, is_upgrade: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = _get_card_bg_color(card_type, is_upgrade)
	if is_upgrade:
		style.border_color = Color(1, 0.7, 0.2)
		style.set_border_width_all(3)
	else:
		style.border_color = Color(0.35, 0.35, 0.4)
		style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


# Background color based on card type.
func _get_card_bg_color(card_type: String, is_upgrade: bool) -> Color:
	if not is_upgrade:
		return Color(0.1, 0.1, 0.12)  # Dimmed dark
	match card_type:
		"Attack":
			return Color(0.25, 0.1, 0.1)  # Dark red
		"Skill":
			return Color(0.1, 0.15, 0.25)  # Dark blue
		"Power":
			return Color(0.2, 0.08, 0.2)  # Dark purple
		_:
			return Color(0.12, 0.12, 0.18)  # Neutral dark


# Text color for card type badge.
func _get_card_type_color(card_type: String, is_upgrade: bool) -> Color:
	if not is_upgrade:
		return Color(0.5, 0.5, 0.5)
	match card_type:
		"Attack":
			return Color(1, 0.4, 0.3)  # Red
		"Skill":
			return Color(0.4, 0.6, 1)  # Blue
		"Power":
			return Color(0.7, 0.4, 1)  # Purple
		_:
			return Color(0.7, 0.7, 0.7)


func _style_click_area(btn: Button, _index: int) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0.0)
	normal.border_color = Color(1, 0.7, 0.2)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(8)

	var hover := normal.duplicate()
	hover.bg_color = Color(1, 0.7, 0.2, 0.15)
	hover.border_color = Color(1, 0.85, 0.3)
	hover.set_border_width_all(3)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)


func _style_button_secondary(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.15, 0.2)
	normal.border_color = Color(0.4, 0.4, 0.5)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(8)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.25, 0.25, 0.35)
	hover.border_color = Color(0.6, 0.6, 0.7)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))


# --- Signal Handlers ---


func _on_card_selected(index: int) -> void:
	_selected_card_index = index
	if index >= 0 and index < _upgradeable_cards.size():
		var card_info: Dictionary = _upgradeable_cards[index]
		var base_name: String = card_info["base_name"]
		var upgrade_name: String = card_info["upgrade_name"]

		# Remove base card from deck, add upgrade
		var deck: Array = _run_state.deck_card_names
		var remove_idx: int = deck.find(base_name)
		if remove_idx >= 0:
			deck.remove_at(remove_idx)
			deck.append(upgrade_name)

		# Show success toast
		_show_forge_success(upgrade_name)

		# Emit signal after delay
		await get_tree().create_timer(1.5).timeout
		emit_signal("forge_completed")


func _on_cancel_pressed() -> void:
	emit_signal("forge_cancelled")


func _show_forge_success(card_name: String) -> void:
	var center_x: float = _viewport_size.x / 2.0
	var center_y: float = _viewport_size.y / 2.0

	var toast := Label.new()
	toast.text = "⚔️ 卡牌已升级: %s" % card_name
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.position = Vector2(center_x - 200, center_y + 200)
	toast.size = Vector2(400, 50)
	toast.add_theme_font_size_override("font_size", 24)
	toast.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
	toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	toast.add_theme_constant_override("outline_size", 2)
	toast.z_index = 100
	add_child(toast)

	var tween := create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(toast, "modulate:a", 0.0, 0.5)
	tween.tween_callback(toast.queue_free)
