# Shop screen for My Card Game (M11).
#
# STS-style shop where the player can spend gold to:
#   - Buy cards (5 random cards from the pool)
#   - Remove a card from the deck (75 gold)
#   - Heal 30% max HP (50 gold)
#   - Buy a relic (150 gold)
extends Control

signal shop_closed

const _SetDefinition = preload("res://src/custom/cards/sets/SetDefinition_MyCardGame.gd")
const _RelicDatabase = preload("res://src/custom/RelicDatabase.gd")

var _viewport_size: Vector2 = Vector2(1280, 720)
var _run_state: RefCounted
var _board: Node
var _card_slots: Array = []  # [{card_name, price, sold}]
var _relic_id: String = ""
var _relic_price: int = 150
var _relic_sold: bool = false

const PRICE_REMOVE := 75
const PRICE_HEAL := 50


# Called by CGFBoard after adding this node to the tree.
func setup(viewport_size: Vector2, run_state: RefCounted, board: Node) -> void:
	_viewport_size = viewport_size
	_run_state = run_state
	_board = board
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_shop() -> void:
	cfc.game_paused = true
	_clear_ui()
	_build_shop()
	visible = true


# --- UI Building ---


func _clear_ui() -> void:
	_card_slots.clear()
	_relic_id = ""
	_relic_sold = false
	for child in get_children():
		remove_child(child)
		child.queue_free()


func _build_shop() -> void:
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
	title.name = "ShopTitle"
	title.text = "💰 商店"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(center_x - 200, 30)
	title.size = Vector2(400, 50)
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("outline_size", 2)
	add_child(title)

	# Gold display
	var gold_label := Label.new()
	gold_label.name = "GoldLabel"
	gold_label.text = "💰 金币: %d" % _run_state.gold
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gold_label.position = Vector2(_viewport_size.x - 220, 35)
	gold_label.size = Vector2(200, 40)
	gold_label.add_theme_font_size_override("font_size", 24)
	gold_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	add_child(gold_label)

	# --- Card for sale section ---
	_build_card_section(center_x, center_y - 80)

	# --- Services section (heal, remove) ---
	_build_services_section(center_x, center_y + 120)

	# --- Relic section ---
	_build_relic_section(center_x, center_y + 230)

	# Leave button
	var leave_btn := Button.new()
	leave_btn.name = "LeaveButton"
	leave_btn.text = "离开商店"
	leave_btn.position = Vector2(center_x - 80, _viewport_size.y - 80)
	leave_btn.size = Vector2(160, 45)
	leave_btn.add_theme_font_size_override("font_size", 18)
	_style_button_secondary(leave_btn)
	leave_btn.connect("pressed", Callable(self, "_on_leave_pressed"))
	add_child(leave_btn)


func _build_card_section(center_x: float, start_y: float) -> void:
	# Section title
	var section_title := Label.new()
	section_title.text = "🃏 购买卡牌"
	section_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	section_title.position = Vector2(center_x - 200, start_y - 30)
	section_title.size = Vector2(400, 25)
	section_title.add_theme_font_size_override("font_size", 20)
	section_title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	add_child(section_title)

	# Generate 5 random cards for sale
	var pool: Array = []
	for card_name in _SetDefinition.CARDS:
		var card_data: Dictionary = _SetDefinition.CARDS[card_name]
		if card_data.get("_rarity", "") != "Starter":
			pool.append(card_name)
	pool.shuffle()
	var sale_cards: Array = pool.slice(0, mini(5, pool.size()))

	var card_width: float = 130.0
	var gap: float = 15.0
	var total_width: int = sale_cards.size() * card_width + (sale_cards.size() - 1) * gap
	var start_x: float = center_x - total_width / 2.0

	for i in range(sale_cards.size()):
		var card_name: String = sale_cards[i]
		var rarity: String = _SetDefinition.CARDS[card_name].get("_rarity", "Common")
		var price: int = _card_price(rarity)
		_card_slots.append({"card_name": card_name, "price": price, "sold": false})

		var x: float = start_x + i * (card_width + gap)
		var btn := Button.new()
		btn.name = "CardSlot_%d" % i
		btn.text = "%s\n💰%d" % [card_name, price]
		btn.position = Vector2(x, start_y)
		btn.size = Vector2(card_width, 60)
		btn.add_theme_font_size_override("font_size", 14)
		_style_card_button(btn, rarity)
		btn.connect("pressed", Callable(self, "_on_buy_card").bind(i))
		add_child(btn)


func _build_services_section(center_x: float, start_y: float) -> void:
	var section_title := Label.new()
	section_title.text = "🔧 服务"
	section_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	section_title.position = Vector2(center_x - 200, start_y - 25)
	section_title.size = Vector2(400, 25)
	section_title.add_theme_font_size_override("font_size", 20)
	section_title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	add_child(section_title)

	# Heal button
	var heal_btn := Button.new()
	heal_btn.name = "HealButton"
	var heal_amount: int = int(_run_state.player_max_hp * 0.3)
	heal_btn.text = "❤️ 回复 %d HP  (💰%d)" % [heal_amount, PRICE_HEAL]
	heal_btn.position = Vector2(center_x - 170, start_y + 5)
	heal_btn.size = Vector2(160, 50)
	heal_btn.add_theme_font_size_override("font_size", 15)
	_style_button_primary(heal_btn)
	heal_btn.connect("pressed", Callable(self, "_on_heal_pressed"))
	add_child(heal_btn)

	# Remove card button
	var remove_btn := Button.new()
	remove_btn.name = "RemoveButton"
	remove_btn.text = "🗑️ 删除卡牌  (💰%d)" % PRICE_REMOVE
	remove_btn.position = Vector2(center_x + 10, start_y + 5)
	remove_btn.size = Vector2(160, 50)
	remove_btn.add_theme_font_size_override("font_size", 15)
	_style_button_primary(remove_btn)
	remove_btn.connect("pressed", Callable(self, "_on_remove_card_pressed"))
	add_child(remove_btn)


func _build_relic_section(center_x: float, start_y: float) -> void:
	# Pick a random relic the player doesn't already have
	_relic_id = _RelicDatabase.get_random_relic(_run_state.relics)

	var section_title := Label.new()
	section_title.text = "✨ 遗物"
	section_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	section_title.position = Vector2(center_x - 200, start_y - 25)
	section_title.size = Vector2(400, 25)
	section_title.add_theme_font_size_override("font_size", 20)
	section_title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	add_child(section_title)

	if _relic_id == "":
		var no_relic := Label.new()
		no_relic.text = "（已售罄）"
		no_relic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_relic.position = Vector2(center_x - 80, start_y + 5)
		no_relic.size = Vector2(160, 40)
		no_relic.add_theme_font_size_override("font_size", 16)
		no_relic.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		add_child(no_relic)
		return

	var relic_data: Dictionary = _RelicDatabase.get_relic(_relic_id)
	_relic_price = relic_data.get("price", 150)

	var relic_btn := Button.new()
	relic_btn.name = "RelicButton"
	relic_btn.text = "%s %s\n%s  (💰%d)" % [relic_data["icon"], relic_data["name"], relic_data["description"], _relic_price]
	relic_btn.position = Vector2(center_x - 170, start_y + 5)
	relic_btn.size = Vector2(340, 60)
	relic_btn.add_theme_font_size_override("font_size", 14)
	_style_button_primary(relic_btn)
	relic_btn.connect("pressed", Callable(self, "_on_buy_relic"))
	add_child(relic_btn)


# --- Card Pricing ---


func _card_price(rarity: String) -> int:
	match rarity:
		"Common":
			return 50
		"Uncommon":
			return 75
		"Rare":
			return 100
		_:
			return 50


# --- Button Handlers ---


func _on_buy_card(index: int) -> void:
	if index >= _card_slots.size():
		return
	var slot: Dictionary = _card_slots[index]
	if slot["sold"]:
		return
	if not _run_state.spend_gold(slot["price"]):
		_show_toast("金币不足！")
		return
	slot["sold"] = true
	_run_state.deck_card_names.append(slot["card_name"])
	_refresh_gold_display()
	# Mark button as sold
	var btn = get_node_or_null("CardSlot_%d" % index)
	if btn:
		btn.text = "%s\n(已购买)" % slot["card_name"]
		btn.disabled = true
	_show_toast("%s 已加入牌组！" % slot["card_name"])


func _on_heal_pressed() -> void:
	if not _run_state.spend_gold(PRICE_HEAL):
		_show_toast("金币不足！")
		return
	var heal_amount: int = int(_run_state.player_max_hp * 0.3)
	_run_state.player_hp = mini(_run_state.player_hp + heal_amount, _run_state.player_max_hp)
	_refresh_gold_display()
	_show_toast("回复了 %d HP！" % heal_amount)
	# Disable heal button after use (once per shop visit)
	var btn = get_node_or_null("HealButton")
	if btn:
		btn.disabled = true
		btn.text = "❤️ 已使用"


func _on_remove_card_pressed() -> void:
	if not _run_state.spend_gold(PRICE_REMOVE):
		_show_toast("金币不足！")
		return
	_refresh_gold_display()
	# Show card selection overlay for removal
	_show_remove_card_picker()


func _on_buy_relic() -> void:
	if _relic_sold or _relic_id == "":
		return
	if not _run_state.spend_gold(_relic_price):
		_show_toast("金币不足！")
		return
	_relic_sold = true
	_run_state.add_relic(_relic_id)
	_refresh_gold_display()
	var btn = get_node_or_null("RelicButton")
	if btn:
		btn.text = "(已购买)"
		btn.disabled = true
	var relic_data: Dictionary = _RelicDatabase.get_relic(_relic_id)
	_show_toast("获得遗物: %s %s！" % [relic_data["icon"], relic_data["name"]])


func _on_leave_pressed() -> void:
	cfc.game_paused = false
	emit_signal("shop_closed")


# --- Remove Card Picker ---


func _show_remove_card_picker() -> void:
	# Overlay on top of shop
	var picker_overlay := ColorRect.new()
	picker_overlay.name = "PickerOverlay"
	picker_overlay.color = Color(0, 0, 0, 0.85)
	picker_overlay.size = _viewport_size
	picker_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	picker_overlay.z_index = 50
	add_child(picker_overlay)

	var center_x: float = _viewport_size.x / 2.0

	var title := Label.new()
	title.text = "🗑️ 选择要删除的卡牌"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(center_x - 200, 80)
	title.size = Vector2(400, 40)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	title.z_index = 51
	add_child(title)

	# List all deck cards
	var scroll := ScrollContainer.new()
	scroll.name = "CardPickerScroll"
	scroll.position = Vector2(center_x - 200, 140)
	scroll.size = Vector2(400, 400)
	scroll.z_index = 51
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.name = "CardPickerVBox"
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)

	# Group cards by name for cleaner display
	var card_counts: Dictionary = {}
	for card_name in _run_state.deck_card_names:
		card_counts[card_name] = card_counts.get(card_name, 0) + 1

	for card_name in card_counts:
		var count: int = card_counts[card_name]
		var btn := Button.new()
		btn.text = "%s ×%d" % [card_name, count]
		btn.custom_minimum_size = Vector2(380, 40)
		btn.add_theme_font_size_override("font_size", 16)
		_style_button_primary(btn)
		btn.connect("pressed", Callable(self, "_on_remove_card_selected").bind(card_name))
		vbox.add_child(btn)

	# Cancel button
	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.position = Vector2(center_x - 60, 560)
	cancel_btn.size = Vector2(120, 40)
	cancel_btn.add_theme_font_size_override("font_size", 16)
	cancel_btn.z_index = 51
	_style_button_secondary(cancel_btn)
	cancel_btn.connect("pressed", Callable(self, "_on_picker_cancel"))
	add_child(cancel_btn)


func _on_remove_card_selected(card_name: String) -> void:
	_run_state.remove_card_from_deck(card_name)
	# Also remove a physical card from the deck pile if possible
	if _board and _board.combat_manager:
		# The card will be removed on next combat setup via deck_card_names
		pass
	_close_picker()
	_show_toast("%s 已从牌组移除！" % card_name)


func _on_picker_cancel() -> void:
	# Refund the gold since we cancelled
	_run_state.gold += PRICE_REMOVE
	_refresh_gold_display()
	_close_picker()


func _close_picker() -> void:
	var picker = get_node_or_null("PickerOverlay")
	if picker:
		picker.queue_free()
	var scroll = get_node_or_null("CardPickerScroll")
	if scroll:
		scroll.queue_free()
	# Remove all picker children (title, cancel, scroll)


# --- UI Helpers ---


func _refresh_gold_display() -> void:
	var label = get_node_or_null("GoldLabel")
	if label:
		label.text = "💰 金币: %d" % _run_state.gold


func _show_toast(text: String) -> void:
	var toast := Label.new()
	toast.name = "Toast"
	toast.text = text
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.position = Vector2(_viewport_size.x / 2.0 - 150, _viewport_size.y - 130)
	toast.size = Vector2(300, 35)
	toast.add_theme_font_size_override("font_size", 18)
	toast.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	toast.add_theme_constant_override("outline_size", 2)
	toast.z_index = 100
	add_child(toast)
	var tween: Tween = create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(toast, "modulate:a", 0.0, 0.5)
	tween.tween_callback(toast.queue_free)


# --- Button Styling ---


func _style_button_primary(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.15, 0.25)
	normal.border_color = Color(0.7, 0.6, 0.3)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(8)
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(0.22, 0.22, 0.38)
	hover.border_color = Color(1, 0.85, 0.3)

	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color(0.1, 0.1, 0.18)

	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color(0.08, 0.08, 0.12, 0.5)
	disabled.border_color = Color(0.3, 0.3, 0.3)

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

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(0.18, 0.18, 0.28)
	hover.border_color = Color(0.8, 0.8, 0.8)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)


func _style_card_button(btn: Button, rarity: String) -> void:
	var border_color := Color(0.5, 0.5, 0.5)
	match rarity:
		"Common":
			border_color = Color(0.6, 0.6, 0.6)
		"Uncommon":
			border_color = Color(0.2, 0.8, 0.3)
		"Rare":
			border_color = Color(0.6, 0.3, 0.9)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.1, 0.1, 0.18)
	normal.border_color = border_color
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(8)

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(0.18, 0.18, 0.3)
	hover.border_color = Color(1, 0.85, 0.3)
	hover.set_border_width_all(3)

	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color(0.08, 0.08, 0.08, 0.5)
	disabled.border_color = Color(0.3, 0.3, 0.3)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color(1, 0.85, 0.3))
	btn.add_theme_color_override("font_disabled_color", Color(0.4, 0.4, 0.4))
