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
	var deck: Array = _run_state.deck
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
	var card_scale := 1.3
	var card_width: float = _CFConst.CARD_SIZE.x * card_scale
	var card_height: float = _CFConst.CARD_SIZE.y * card_scale
	var gap: float = 30.0

	# Limit displayed cards to fit screen (max 5)
	var display_cards: Array = _upgradeable_cards.slice(0, 5)
	var total_width: float = display_cards.size() * card_width + (display_cards.size() - 1) * gap
	var start_x: float = center_x - total_width / 2.0
	var target_y: float = center_y - card_height / 2.0

	for i in range(display_cards.size()):
		var card_info: Dictionary = display_cards[i]
		var card_x: float = start_x + i * (card_width + gap)

		# Create card container (base + arrow + upgrade)
		var container := Control.new()
		container.name = "CardContainer_%d" % i
		container.position = Vector2(card_x, target_y)
		container.size = Vector2(card_width, card_height + 80)
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# Base card (dimmed)
		var base_card = cfc.instance_card(card_info["base_name"])
		if base_card and is_instance_valid(base_card):
			base_card.scale = Vector2(card_scale, card_scale)
			base_card.position = Vector2.ZERO
			base_card.modulate = Color(0.6, 0.6, 0.6, 1.0)  # Dimmed
			base_card.z_index = 0
			container.add_child(base_card)

		# Arrow pointing right
		var arrow := Label.new()
		arrow.text = "→"
		arrow.position = Vector2(card_width / 2.0 - 15, card_height / 2.0 - 20)
		arrow.size = Vector2(30, 40)
		arrow.add_theme_font_size_override("font_size", 36)
		arrow.add_theme_color_override("font_color", Color(1, 0.7, 0.2))
		arrow.z_index = 10
		container.add_child(arrow)

		# Upgrade card (highlighted, offset to right)
		var upgrade_card = cfc.instance_card(card_info["upgrade_name"])
		if upgrade_card and is_instance_valid(upgrade_card):
			upgrade_card.scale = Vector2(card_scale, card_scale)
			upgrade_card.position = Vector2(card_width / 2.0 + 10, 0)
			upgrade_card.z_index = 5
			# Make clickable
			upgrade_card.mouse_filter = Control.MOUSE_FILTER_STOP
			container.add_child(upgrade_card)

		# Click area over the whole container
		var click_area := Button.new()
		click_area.name = "ClickArea_%d" % i
		click_area.position = Vector2.ZERO
		click_area.size = Vector2(card_width + 80, card_height)
		click_area.flat = true
		click_area.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_style_click_area(click_area, i)
		click_area.connect("pressed", Callable(self, "_on_card_selected").bind(i))
		container.add_child(click_area)

		add_child(container)

		# Card name label below
		var name_label := Label.new()
		name_label.text = "%s → %s" % [card_info["base_name"], card_info["upgrade_name"]]
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.position = Vector2(card_x, target_y + card_height + 10)
		name_label.size = Vector2(card_width + 80, 30)
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		add_child(name_label)


func _style_click_area(btn: Button, index: int) -> void:
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
		var deck: Array = _run_state.deck
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
