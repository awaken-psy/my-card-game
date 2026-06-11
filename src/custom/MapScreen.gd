# Map screen for My Card Game (M11).
#
# Displays the 15-floor roguelike map with branching paths.
# The player clicks on a reachable node to proceed to the next encounter.
# Shows current HP, gold, and owned relics.
extends Control

signal node_selected(floor_index: int, node_index: int)

const _MapGenerator = preload("res://src/custom/MapGenerator.gd")
const _RelicDatabase = preload("res://src/custom/RelicDatabase.gd")

var _viewport_size: Vector2 = Vector2(1280, 720)
var _run_state: RefCounted

# Layout constants
const FLOOR_HEIGHT := 80
const NODE_RADIUS := 28
const MAP_PADDING_Y := 60
const MAP_WIDTH_RATIO := 0.6  # fraction of viewport width used for nodes

# Node buttons for interaction
var _node_buttons: Array = []  # [{button, floor_index, node_index}]

# Cached connection data for _draw()
var _connections: Array = []  # [{from_pos, to_pos, reachable}]

# Scroll container reference
var _scroll: ScrollContainer
var _relic_tooltip: Panel = null


func setup(viewport_size: Vector2, run_state: RefCounted) -> void:
	_viewport_size = viewport_size
	_run_state = run_state
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_map() -> void:
	cfc.game_paused = true
	_clear_ui()
	_build_map()
	visible = true
	# Auto-scroll to current floor
	_scroll_to_current()


# --- UI Building ---


func _clear_ui() -> void:
	_node_buttons.clear()
	_connections.clear()
	for child in get_children():
		remove_child(child)
		child.queue_free()


func _build_map() -> void:
	# Full-screen overlay
	var overlay := ColorRect.new()
	overlay.name = "MapOverlay"
	overlay.color = Color(0.05, 0.05, 0.12)
	overlay.size = _viewport_size
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# Top info bar
	_build_info_bar()

	# Title
	var title := Label.new()
	title.name = "MapTitle"
	title.text = "🗺️ 选择路线"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(_viewport_size.x / 2.0 - 150, 10)
	title.size = Vector2(300, 35)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	title.z_index = 10
	add_child(title)

	# Map content area with scrolling
	_scroll = ScrollContainer.new()
	_scroll.name = "MapScroll"
	_scroll.position = Vector2(0, 50)
	_scroll.size = Vector2(_viewport_size.x, _viewport_size.y - 50)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(_scroll)

	# Calculate map height
	var total_floors: int = _run_state.map_data["floors"].size()
	var map_height: int = total_floors * FLOOR_HEIGHT + MAP_PADDING_Y * 2

	# Drawing layer for connections (behind nodes)
	var draw_layer := Control.new()
	draw_layer.name = "ConnectionLayer"
	draw_layer.custom_minimum_size = Vector2(_viewport_size.x, map_height)
	draw_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(draw_layer)
	# Connect draw signal
	draw_layer.draw.connect(_on_draw_connections.bind(draw_layer))

	# Node layer
	var node_layer := Control.new()
	node_layer.name = "NodeLayer"
	node_layer.custom_minimum_size = Vector2(_viewport_size.x, map_height)
	node_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(node_layer)

	# Get reachable node identifiers
	var reachable: Array = _run_state.get_reachable_nodes()
	var reachable_keys: Dictionary = {}
	for r in reachable:
		reachable_keys["%d_%d" % [r["floor_index"], r["node_index"]]] = true

	# Build nodes for each floor (top to bottom: boss first, start last)
	var map_center_x: float = _viewport_size.x / 2.0
	var map_width: float = _viewport_size.x * MAP_WIDTH_RATIO

	for floor_index in range(total_floors):
		var floor_nodes: Array = _run_state.map_data["floors"][floor_index]
		# Y position: boss at top (floor 14 = low Y), start at bottom (floor 0 = high Y)
		var y: float = map_height - MAP_PADDING_Y - (floor_index * FLOOR_HEIGHT) - FLOOR_HEIGHT / 2.0

		for node_index in range(floor_nodes.size()):
			var node: Dictionary = floor_nodes[node_index]
			var x: float = map_center_x - map_width / 2.0 + node["x"] * map_width
			var node_type: String = node.get("type", "combat")
			var is_current: bool = (floor_index == _run_state.current_floor and node_index == _run_state.current_node_index)
			var key: String = "%d_%d" % [floor_index, node_index]
			var is_reachable: bool = reachable_keys.has(key)

			# Build connections data
			for conn_idx in node.get("connections", []):
				var next_floor: Array = _run_state.map_data["floors"][floor_index + 1] if floor_index + 1 < total_floors else []
				if conn_idx < next_floor.size():
					var next_node: Dictionary = next_floor[conn_idx]
					var next_y: float = map_height - MAP_PADDING_Y - ((floor_index + 1) * FLOOR_HEIGHT) - FLOOR_HEIGHT / 2.0
					var next_x: float = map_center_x - map_width / 2.0 + next_node["x"] * map_width
					_connections.append({
						"from_pos": Vector2(x, y),
						"to_pos": Vector2(next_x, next_y),
						"active": is_current,
					})

			# Create node button
			var node_config: Dictionary = _MapGenerator.NODE_CONFIG.get(node_type, {})
			var btn := Button.new()
			btn.name = "Node_%d_%d" % [floor_index, node_index]
			btn.position = Vector2(x - NODE_RADIUS, y - NODE_RADIUS)
			btn.size = Vector2(NODE_RADIUS * 2, NODE_RADIUS * 2)
			var icon: String = node_config.get("icon", "●")
			var color: Color = node_config.get("color", Color.GRAY)
			btn.text = icon
			btn.add_theme_font_size_override("font_size", 20)
			btn.mouse_filter = Control.MOUSE_FILTER_STOP
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

			# Style based on state
			_style_node_button(btn, color, is_current, is_reachable)

			if is_reachable:
				btn.connect("pressed", Callable(self, "_on_node_clicked").bind(floor_index, node_index))
			elif not is_current:
				btn.mouse_default_cursor_shape = Control.CURSOR_ARROW
				if not is_reachable:
					btn.mouse_filter = Control.MOUSE_FILTER_IGNORE

			node_layer.add_child(btn)
			_node_buttons.append({
				"button": btn,
				"floor_index": floor_index,
				"node_index": node_index,
				"is_current": is_current,
				"is_reachable": is_reachable,
			})

	# Trigger initial draw of connections
	draw_layer.queue_redraw()


func _build_info_bar() -> void:
	# Semi-transparent bar at top
	var bar := ColorRect.new()
	bar.name = "InfoBar"
	bar.color = Color(0, 0, 0, 0.6)
	bar.position = Vector2(0, 0)
	bar.size = Vector2(_viewport_size.x, 50)
	bar.z_index = 10
	add_child(bar)

	# HP
	var hp_label := Label.new()
	hp_label.text = "❤️ %d/%d" % [_run_state.player_hp, _run_state.player_max_hp]
	hp_label.position = Vector2(20, 12)
	hp_label.size = Vector2(120, 30)
	hp_label.add_theme_font_size_override("font_size", 18)
	hp_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	hp_label.z_index = 11
	add_child(hp_label)

	# Gold
	var gold_label := Label.new()
	gold_label.text = "💰 %d" % _run_state.gold
	gold_label.position = Vector2(150, 12)
	gold_label.size = Vector2(100, 30)
	gold_label.add_theme_font_size_override("font_size", 18)
	gold_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	gold_label.z_index = 11
	add_child(gold_label)

	# Floor progress (left of relics)
	var total: int = _run_state.get_total_floors()
	var floor_label := Label.new()
	floor_label.text = "层 %d/%d" % [_run_state.get_floor_number(), total]
	floor_label.position = Vector2(260, 12)
	floor_label.size = Vector2(100, 30)
	floor_label.add_theme_font_size_override("font_size", 16)
	floor_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	floor_label.z_index = 11
	add_child(floor_label)

	# Relics (with hover tooltip)
	_relic_tooltip = null
	var relic_x: int = 370
	for relic_id in _run_state.relics:
		var relic_data: Dictionary = _RelicDatabase.get_relic(relic_id)
		var relic_label := Label.new()
		relic_label.text = relic_data.get("icon", "?")
		relic_label.position = Vector2(relic_x, 12)
		relic_label.size = Vector2(30, 30)
		relic_label.add_theme_font_size_override("font_size", 18)
		relic_label.z_index = 11
		relic_label.mouse_filter = Control.MOUSE_FILTER_STOP
		relic_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var rid: String = relic_id
		relic_label.connect("mouse_entered", Callable(self, "_show_relic_tooltip").bind(relic_label, rid))
		relic_label.connect("mouse_exited", Callable(self, "_hide_relic_tooltip"))
		add_child(relic_label)
		relic_x += 35

	# Settings gear button (top-right)
	var settings_btn := Button.new()
	settings_btn.name = "SettingsButton"
	settings_btn.text = "⚙"
	settings_btn.position = Vector2(_viewport_size.x - 55, 8)
	settings_btn.size = Vector2(40, 34)
	settings_btn.add_theme_font_size_override("font_size", 22)
	settings_btn.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	settings_btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	settings_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	settings_btn.z_index = 11
	settings_btn.flat = true
	settings_btn.connect("pressed", Callable(self, "_on_settings_pressed"))
	add_child(settings_btn)


# --- Connection Drawing ---


func _on_draw_lines(draw_layer: Control) -> void:
	_on_draw_connections(draw_layer)


func _on_draw_connections(draw_layer: Control) -> void:
	for conn in _connections:
		var color := Color(0.3, 0.3, 0.3, 0.5)
		var width: float = 2.0
		if conn["active"]:
			color = Color(1, 0.85, 0.2, 0.8)
			width = 3.0
		draw_layer.draw_line(conn["from_pos"], conn["to_pos"], color, width, true)


# --- Relic Tooltip ---


func _show_relic_tooltip(anchor: Control, relic_id: String) -> void:
	_hide_relic_tooltip()
	var data: Dictionary = _RelicDatabase.get_relic(relic_id)
	if data.is_empty():
		return
	var tooltip := Panel.new()
	tooltip.name = "RelicTooltip"
	tooltip.z_index = 200
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.15, 0.95)
	style.border_color = Color(0.7, 0.6, 0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	tooltip.add_theme_stylebox_override("panel", style)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	var title := Label.new()
	title.text = "%s %s" % [data.get("icon", ""), data.get("name", "")]
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	vbox.add_child(title)
	var desc := Label.new()
	desc.text = data.get("description", "")
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(200, 0)
	vbox.add_child(desc)
	tooltip.add_child(vbox)
	add_child(tooltip)
	_relic_tooltip = tooltip
	# Position below the anchor, clamped to viewport
	await get_tree().process_frame
	var tx: float = mini(anchor.global_position.x - 30, _viewport_size.x - tooltip.size.x - 10)
	var ty: float = anchor.global_position.y + anchor.size.y + 5
	if ty + tooltip.size.y > _viewport_size.y:
		ty = anchor.global_position.y - tooltip.size.y - 5
	tooltip.position = Vector2(tx, ty)


func _hide_relic_tooltip() -> void:
	if _relic_tooltip and is_instance_valid(_relic_tooltip):
		_relic_tooltip.queue_free()
	_relic_tooltip = null


# --- Scrolling ---


func _scroll_to_current() -> void:
	if not _scroll:
		return
	# Wait one frame so ScrollContainer has updated its scrollbar range
	await get_tree().process_frame
	var target_y: float = _get_target_scroll_y()
	var max_scroll: float = _scroll.get_v_scroll_bar().max_value if _scroll.get_v_scroll_bar() else 0
	var scroll_pos: float = clampf(target_y - _scroll.size.y / 2.0, 0.0, max_scroll)
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(_scroll, "scroll_vertical", scroll_pos, 0.5)


# Calculate the Y position of the target floor in the map content area.
func _get_target_scroll_y() -> float:
	var total_floors: int = _run_state.map_data["floors"].size()
	var map_height: int = total_floors * FLOOR_HEIGHT + MAP_PADDING_Y * 2
	# When returning from combat, scroll to the next floor's reachable nodes
	var target_floor: int
	if _run_state.current_floor < 0:
		# Haven't entered map yet — target the starting floor (bottom)
		target_floor = 0
	else:
		# After combat on floor N, show floor N+1 reachable nodes
		target_floor = mini(_run_state.current_floor + 1, total_floors - 1)
	# Y position formula matches _build_map:
	# y = map_height - PADDING - floor * HEIGHT - HEIGHT/2
	return map_height - MAP_PADDING_Y - (target_floor * FLOOR_HEIGHT) - FLOOR_HEIGHT / 2.0


# --- Node Click Handler ---


func _on_node_clicked(floor_index: int, node_index: int) -> void:
	_run_state.move_to_node(floor_index, node_index)
	emit_signal("node_selected", floor_index, node_index)


# --- Node Button Styling ---


func _style_node_button(btn: Button, base_color: Color, is_current: bool, is_reachable: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.set_corner_radius_all(NODE_RADIUS)
	normal.content_margin_left = 0
	normal.content_margin_right = 0
	normal.content_margin_top = 0
	normal.content_margin_bottom = 0

	if is_current:
		normal.bg_color = base_color
		normal.border_color = Color(1, 1, 1)
		normal.set_border_width_all(3)
		btn.add_theme_color_override("font_color", Color.WHITE)
	elif is_reachable:
		normal.bg_color = Color(base_color.r * 0.3, base_color.g * 0.3, base_color.b * 0.3)
		normal.border_color = Color(1, 0.85, 0.2)
		normal.set_border_width_all(3)
		btn.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
		# Pulsing animation for reachable nodes
		var tween: Tween = create_tween()
		tween.set_loops()
		tween.tween_property(normal, "border_color", Color(1, 1, 0.5), 0.5)
		tween.tween_property(normal, "border_color", Color(1, 0.85, 0.2), 0.5)
	else:
		normal.bg_color = Color(0.1, 0.1, 0.15, 0.5)
		normal.border_color = Color(0.25, 0.25, 0.25)
		normal.set_border_width_all(1)
		btn.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		btn.disabled = true

	var hover: StyleBoxFlat = normal.duplicate()
	if is_reachable:
		hover.bg_color = Color(base_color.r * 0.5, base_color.g * 0.5, base_color.b * 0.5)
		hover.border_color = Color.WHITE
		hover.set_border_width_all(4)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("disabled", normal)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color(0.4, 0.4, 0.4))



func _on_settings_pressed() -> void:
	var board = get_parent()
	if board and board.has_method("open_settings"):
		board.open_settings()
