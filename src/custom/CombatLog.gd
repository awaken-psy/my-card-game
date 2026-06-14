# Combat log panel for tracking battle events.
# Appears as a scrollable panel in the bottom-right corner during combat.
# Records: turns, card plays, damage, block, status changes, relics, etc.
extends Control

# Log entry structure: {turn: int, text: String, color: Color}
var _entries: Array = []

# UI references
var _panel: Panel
var _scroll_container: ScrollContainer
var _log_container: VBoxContainer
var _toggle_button: Button
var _is_expanded: bool = false

# Colors for different event types
const COLOR_TURN := Color(1, 0.85, 0.2)      # Yellow
const COLOR_CARD := Color(0.7, 0.9, 1)        # Light blue
const COLOR_DAMAGE := Color(1, 0.35, 0.35)   # Red
const COLOR_BLOCK := Color(0.6, 0.8, 1)      # Blue
const COLOR_STATUS := Color(0.8, 0.6, 1)     # Purple
const COLOR_RELIC := Color(1, 0.85, 0.3)     # Gold
const COLOR_HEAL := Color(0.3, 0.9, 0.3)     # Green
const COLOR_INFO := Color(0.75, 0.75, 0.75)  # Gray


func _ready() -> void:
	# Wait for setup to be called externally, then apply initial state
	pass


func setup(viewport_size: Vector2) -> void:
	# Main panel (expandable) - create FIRST so it's behind the button
	_panel = Panel.new()
	_panel.name = "LogPanel"
	_panel.position = Vector2(viewport_size.x - 350, viewport_size.y - 280)
	_panel.size = Vector2(330, 250)
	_panel.z_index = 99
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let clicks pass through to cards below
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	panel_style.border_color = Color(0.4, 0.4, 0.5)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_left = 8
	panel_style.content_margin_right = 8
	panel_style.content_margin_top = 8
	panel_style.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	# Title
	var title := Label.new()
	title.text = "战斗日志"
	title.position = Vector2(10, 8)
	title.size = Vector2(100, 25)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", COLOR_TURN)
	_panel.add_child(title)

	# Scroll container
	_scroll_container = ScrollContainer.new()
	_scroll_container.name = "LogScroll"
	_scroll_container.position = Vector2(10, 35)
	_scroll_container.size = Vector2(310, 200)
	_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(_scroll_container)

	# Log container (VBox for entries)
	_log_container = VBoxContainer.new()
	_log_container.name = "LogContainer"
	_log_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_container.add_theme_constant_override("separation", 3)
	_scroll_container.add_child(_log_container)

	# Toggle button (small, always visible) - create LAST so it's on top
	_toggle_button = Button.new()
	_toggle_button.name = "LogToggle"
	_toggle_button.text = "📜"
	_toggle_button.position = Vector2(viewport_size.x - 50, viewport_size.y - 45)
	_toggle_button.size = Vector2(40, 35)
	_toggle_button.add_theme_font_size_override("font_size", 20)
	_toggle_button.z_index = 100
	_toggle_button.mouse_filter = Control.MOUSE_FILTER_STOP  # MUST receive clicks
	_toggle_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var toggle_normal := StyleBoxFlat.new()
	toggle_normal.bg_color = Color(0.1, 0.1, 0.15, 0.9)
	toggle_normal.border_color = Color(0.5, 0.5, 0.6)
	toggle_normal.set_border_width_all(2)
	toggle_normal.set_corner_radius_all(6)
	_toggle_button.add_theme_stylebox_override("normal", toggle_normal)
	var toggle_hover := toggle_normal.duplicate()
	toggle_hover.bg_color = Color(0.15, 0.15, 0.2, 0.95)
	_toggle_button.add_theme_stylebox_override("hover", toggle_hover)
	_toggle_button.pressed.connect(_toggle_log)
	add_child(_toggle_button)

	# Start collapsed
	_is_expanded = false
	_update_visibility()


func _toggle_log() -> void:
	_is_expanded = not _is_expanded
	_update_visibility()


func _update_visibility() -> void:
	_panel.visible = _is_expanded
	if _is_expanded:
		_toggle_button.text = "✕"
	else:
		_toggle_button.text = "📜"


# Add a new log entry.
func add_entry(turn: int, text: String, color: Color = COLOR_INFO) -> void:
	var entry := {"turn": turn, "text": text, "color": color}
	_entries.append(entry)

	# Create label for this entry
	var label := Label.new()
	label.text = "[T%d] %s" % [turn, text]
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(280, 0)
	_log_container.add_child(label)

	# Scroll to bottom
	await get_tree().process_frame
	var v_scroll := _scroll_container.get_v_scroll_bar()
	if v_scroll:
		_scroll_container.scroll_vertical = int(v_scroll.max_value)


# Clear all log entries.
func clear_log() -> void:
	_entries.clear()
	for child in _log_container.get_children():
		child.queue_free()


# Convenience methods for common event types

func log_turn_start(turn: int) -> void:
	add_entry(turn, "回合开始", COLOR_TURN)


func log_turn_end(turn: int) -> void:
	add_entry(turn, "回合结束", COLOR_TURN)


func log_card_played(turn: int, card_name: String, cost: int) -> void:
	add_entry(turn, "打出 %s (费用 %d)" % [card_name, cost], COLOR_CARD)


func log_damage(turn: int, target: String, amount: int) -> void:
	add_entry(turn, "%s 受到 %d 伤害" % [target, amount], COLOR_DAMAGE)


func log_block_gain(turn: int, target: String, amount: int) -> void:
	add_entry(turn, "%s 获得 %d 格挡" % [target, amount], COLOR_BLOCK)


func log_heal(turn: int, target: String, amount: int) -> void:
	add_entry(turn, "%s 恢复 %d HP" % [target, amount], COLOR_HEAL)


func log_status_change(turn: int, target: String, status: String, amount: int) -> void:
	var sign := "+" if amount >= 0 else ""
	add_entry(turn, "%s %s%s %s" % [target, sign, amount, status], COLOR_STATUS)


func log_relic_trigger(turn: int, relic_name: String, effect: String) -> void:
	add_entry(turn, "遗物 %s: %s" % [relic_name, effect], COLOR_RELIC)


func log_enemy_intent(turn: int, intent_name: String) -> void:
	add_entry(turn, "敌人意图: %s" % intent_name, COLOR_INFO)


func log_draw(turn: int, count: int) -> void:
	add_entry(turn, "抽牌 %d 张" % count, COLOR_CARD)


func log_discard(turn: int, count: int) -> void:
	add_entry(turn, "弃牌 %d 张" % count, COLOR_CARD)


func log_energy_change(turn: int, current: int, max_energy: int) -> void:
	add_entry(turn, "能量 %d/%d" % [current, max_energy], COLOR_INFO)


func log_poison_tick(turn: int, target: String, damage: int) -> void:
	add_entry(turn, "%s 中毒伤害 %d" % [target, damage], COLOR_STATUS)


func log_thorns(trigger: int, target: String, damage: int) -> void:
	add_entry(trigger, "%s 荆棘反弹 %d 伤害" % [target, damage], COLOR_STATUS)


func log_combat_end(turn: int, result: String) -> void:
	var color := COLOR_HEAL if result == "胜利" else COLOR_DAMAGE
	add_entry(turn, "战斗结束: %s" % result, color)
