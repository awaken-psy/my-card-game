# Game board for My Card Game (STS-style Roguelike Deckbuilder)
extends Board

# Play mode: "drag" (STS classic, default) or "click"
var play_mode: String = "drag"

var combat_manager: Node
var audio_manager: Node
var _energy_orb: Panel
var _energy_label: Label
var _turn_label: Label
var _end_turn_button: Button
# Player stat UI
var _player_hp_bar: ProgressBar
var _player_hp_text: Label
var _player_name_label: Label
var _player_visual: Control

# Preload combat entity script (class_name removed due to load-order issues)
const _CombatEntity = preload("res://src/custom/CombatEntity.gd")
const _RunState = preload("res://src/custom/RunState.gd")
const _EnemyAI = preload("res://src/custom/EnemyAI.gd")
var _player_block_label: Label
var _player_status_label: Label
# Enemy stat UI
var _enemy_name_label: Label
var _enemy_hp_bar: ProgressBar
var _enemy_hp_text: Label
var _enemy_block_label: Label
var _enemy_status_label: Label
var _enemy_intent_label: Label
var _enemy_visual: Control
var _reward_screen: Control

# Run state persists across encounters within the same run.
var run_state: RefCounted

# Encounter progress label (e.g. "Battle 2/3")
var _encounter_label: Label

# References to dynamically created combat UI nodes (for cleanup)
var _combat_ui_nodes: Array = []

# Enemy highlight tween (for drag targeting visual feedback)
var _enemy_highlight_tween: Tween = null


# Full-screen red flash overlay for player damage feedback.
var _hit_overlay: ColorRect = null

# M11: Map and Shop screens
var _map_screen: Control
var _shop_screen: Control

# Called when the node enters the scene tree.
func _ready() -> void:
	super._ready()
	counters = $Counters
	cfc.map_node(self)
	if not cfc.ut:
		cfc.game_rng_seed = CFUtils.generate_random_seed()
	if not cfc.are_all_nodes_mapped:
		await cfc.all_nodes_mapped
	if not cfc.ut and not get_tree().get_root().has_node('RunFromEditor'):
		_start_run()
	# warning-ignore:return_value_discarded
	$DeckBuilderPopup.connect('popup_hide', Callable(self, '_on_DeckBuilder_hide'))


# --- Run lifecycle ---


# Start a new run (fresh RunState + first encounter).
func _start_run() -> void:
	run_state = _RunState.new()
	# STS-style: start with a random relic
	var _RelicDB = load("res://src/custom/RelicDatabase.gd")
	var starter_relic: String = _RelicDB.get_random_relic([])
	if starter_relic != "":
		run_state.add_relic(starter_relic)
		var rdata: Dictionary = _RelicDB.get_relic(starter_relic)
		push_warning("起始遗物: %s %s" % [rdata.get("icon", ""), rdata.get("name", "")])
	_show_map_screen()


# Set up the combat system and UI.
func _setup_combat() -> void:
	_set_piles_visible(true)
	cfc.set_setting("hand_use_oval_shape", true)
	cfc.set_setting("fancy_movement", true)

	# Create CombatManager
	combat_manager = Node.new()
	combat_manager.set_script(load("res://src/custom/CombatManager.gd"))
	combat_manager.board = self
	add_child(combat_manager)

	# Create AudioManager
	audio_manager = Node.new()
	audio_manager.set_script(load("res://src/custom/AudioManager.gd"))
	audio_manager.name = "AudioManager"
	add_child(audio_manager)

	# Get encounter config from RunState
	var encounter: Dictionary = run_state.get_current_encounter()

	# Initialize combat entities
	combat_manager.player = _CombatEntity.new("Player", run_state.player_max_hp, run_state.player_hp)
	combat_manager.player.strength = run_state.player_strength
	combat_manager.enemy = _CombatEntity.new(encounter["name"], encounter["hp"])


	# Create enemy AI from config
	combat_manager.enemy_ai = _EnemyAI.new(encounter)
	# Connect combat signals
	combat_manager.connect("energy_changed", Callable(self, "_on_energy_changed"))
	combat_manager.connect("turn_started", Callable(self, "_on_turn_started"))
	combat_manager.connect("turn_ended", Callable(self, "_on_turn_ended"))
	combat_manager.connect("combat_ended", Callable(self, "_on_combat_ended"))
	combat_manager.connect("enemy_intent_changed", Callable(self, "_on_enemy_intent_changed"))

	# Connect combat signals for animations
	combat_manager.connect("entity_damaged", Callable(self, "_on_entity_damaged"))
	combat_manager.connect("player_turn_started", Callable(self, "_on_player_turn_banner"))
	combat_manager.connect("enemy_turn_started", Callable(self, "_on_enemy_turn_banner"))

	# Connect entity signals for UI updates
	combat_manager.player.connect("hp_changed", Callable(self, "_on_player_hp_changed"))
	combat_manager.player.connect("block_changed", Callable(self, "_on_player_block_changed"))
	combat_manager.player.connect("stats_changed", Callable(self, "_on_player_stats_changed"))
	combat_manager.enemy.connect("hp_changed", Callable(self, "_on_enemy_hp_changed"))
	combat_manager.enemy.connect("block_changed", Callable(self, "_on_enemy_block_changed"))
	combat_manager.enemy.connect("stats_changed", Callable(self, "_on_enemy_stats_changed"))
	combat_manager.player.connect("poison_damaged", Callable(self, "_on_poison_tick"))
	combat_manager.enemy.connect("poison_damaged", Callable(self, "_on_poison_tick"))
	combat_manager.player.connect("healed", Callable(self, "_on_player_healed"))
	combat_manager.connect("thorns_triggered", Callable(self, "_on_thorns_triggered"))

	# Auto-inject combat_manager into all newly instanced cards
	if not cfc.is_connected("new_card_instanced", Callable(self, "inject_combat_manager")):
		cfc.connect("new_card_instanced", Callable(self, "inject_combat_manager"))

	# Create combat UI elements
	_create_combat_ui()

	# Load deck from run state, then start combat
	_load_deck_from_run_state()
	await get_tree().process_frame
	combat_manager.start_combat()


# Clean up combat state to prepare for the next encounter.
func _cleanup_combat() -> void:
	# Clear any focused card before transitioning
	if cfc.NMAP and cfc.NMAP.get("main") and is_instance_valid(cfc.NMAP.main):
		cfc.NMAP.main.unfocus_all()
	if combat_manager and is_instance_valid(combat_manager):
		if combat_manager.is_connected("combat_ended", Callable(self, "_on_combat_ended")):
			combat_manager.disconnect("combat_ended", Callable(self, "_on_combat_ended"))

	var all_cards: Array = cfc.NMAP.hand.get_all_cards().duplicate()
	all_cards.append_array(cfc.NMAP.discard.get_all_cards().duplicate())
	all_cards.append_array(cfc.NMAP.deck.get_all_cards().duplicate())
	for card in all_cards:
		if is_instance_valid(card):
			var parent = card.get_parent()
			if parent == cfc.NMAP.hand:
				cfc.NMAP.hand.remove_child(card)
			elif parent == cfc.NMAP.discard:
				cfc.NMAP.discard.remove_child(card)
			elif parent == cfc.NMAP.deck:
				cfc.NMAP.deck.remove_child(card)
			card.queue_free()

	if _reward_screen and is_instance_valid(_reward_screen):
		_reward_screen.queue_free()
		_reward_screen = null

	for node in _combat_ui_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_combat_ui_nodes.clear()

	if combat_manager and is_instance_valid(combat_manager):
		combat_manager.queue_free()
		combat_manager = null

	if audio_manager and is_instance_valid(audio_manager):
		audio_manager.queue_free()
		audio_manager = null


# _advance_to_next_encounter removed — replaced by map-driven flow in M11.


# --- Combat UI ---


func _create_combat_ui() -> void:
	var viewport_size: Vector2 = Vector2(get_viewport().size)
	var encounter: Dictionary = run_state.get_current_encounter()

	# --- Combat background (gradient based on encounter type) ---
	var bg := TextureRect.new()
	bg.name = "CombatBackground"
	bg.size = viewport_size
	bg.z_index = -10
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var gradient := Gradient.new()
	var enc_type: String = encounter.get("type", "normal")
	match enc_type:
		"elite":
			gradient.colors = [Color(0.1, 0.03, 0.15), Color(0.15, 0.08, 0.25)]
		"boss":
			gradient.colors = [Color(0.15, 0.03, 0.05), Color(0.2, 0.05, 0.1)]
		_:
			gradient.colors = [Color(0.05, 0.05, 0.15), Color(0.1, 0.1, 0.25)]
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	bg.texture = tex
	add_child(bg)
	_combat_ui_nodes.append(bg)

	# --- Hit overlay (full-screen red flash when player takes damage) ---
	_hit_overlay = ColorRect.new()
	_hit_overlay.name = "HitOverlay"
	_hit_overlay.color = Color(1, 0, 0, 0)
	_hit_overlay.size = viewport_size
	_hit_overlay.z_index = 150
	_hit_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hit_overlay)
	_combat_ui_nodes.append(_hit_overlay)

	# --- Encounter progress label (top center) ---
	_encounter_label = Label.new()
	_encounter_label.name = "EncounterLabel"
	_encounter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_encounter_label.position = Vector2(viewport_size.x / 2 - 80, 10)
	_encounter_label.size = Vector2(160, 30)
	_encounter_label.add_theme_font_size_override("font_size", 20)
	_encounter_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	var map_node: Dictionary = run_state.get_current_node()
	var node_type: String = map_node.get("type", "combat")
	var type_names: Dictionary = {"combat": "战斗", "elite": "精英", "boss": "Boss"}
	_encounter_label.text = "层 %d/%d · %s" % [run_state.get_floor_number(), run_state.get_total_floors(), type_names.get(node_type, "战斗")]
	add_child(_encounter_label)
	_combat_ui_nodes.append(_encounter_label)

	# Relic icons display (top-right of encounter label) with hover tooltip
	var _RelicDB = load("res://src/custom/RelicDatabase.gd")
	var relic_x := viewport_size.x / 2.0 + 100
	for relic_id in run_state.relics:
		var rdata: Dictionary = _RelicDB.get_relic(relic_id)
		var relic_icon := Label.new()
		relic_icon.text = rdata.get("icon", "?")
		relic_icon.position = Vector2(relic_x, 12)
		relic_icon.size = Vector2(30, 30)
		relic_icon.add_theme_font_size_override("font_size", 18)
		relic_icon.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
		relic_icon.mouse_filter = Control.MOUSE_FILTER_STOP
		relic_icon.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var rid: String = relic_id
		var rdata_copy: Dictionary = rdata
		relic_icon.connect("mouse_entered", Callable(self, "_show_combat_relic_tooltip").bind(relic_icon, rid))
		relic_icon.connect("mouse_exited", Callable(self, "_hide_combat_relic_tooltip"))
		add_child(relic_icon)
		_combat_ui_nodes.append(relic_icon)
		relic_x += 35

	# --- Energy orb (bottom-left, near deck — STS style) ---
	_energy_orb = Panel.new()
	_energy_orb.name = "EnergyOrb"
	_energy_orb.position = Vector2(cfc.NMAP.deck.position.x + 25, cfc.NMAP.deck.position.y - 95)
	_energy_orb.size = Vector2(70, 70)
	var orb_style := StyleBoxFlat.new()
	orb_style.bg_color = Color(0.08, 0.18, 0.45, 0.95)
	orb_style.border_color = Color(0.3, 0.6, 1.0)
	orb_style.set_border_width_all(3)
	orb_style.set_corner_radius_all(35)
	_energy_orb.add_theme_stylebox_override("panel", orb_style)

	_energy_label = Label.new()
	_energy_label.name = "EnergyLabel"
	_energy_label.text = "0"
	_energy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_energy_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_energy_label.anchor_right = 1.0
	_energy_label.anchor_bottom = 1.0
	_energy_label.add_theme_font_size_override("font_size", 26)
	_energy_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	_energy_orb.add_child(_energy_label)
	add_child(_energy_orb)
	_combat_ui_nodes.append(_energy_orb)

	# Turn label (below energy orb)
	_turn_label = Label.new()
	_turn_label.name = "TurnLabel"
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_label.position = Vector2(cfc.NMAP.deck.position.x + 15, cfc.NMAP.deck.position.y - 22)
	_turn_label.size = Vector2(90, 25)
	_turn_label.add_theme_font_size_override("font_size", 18)
	_turn_label.text = "Turn 0"
	add_child(_turn_label)
	_combat_ui_nodes.append(_turn_label)

	# --- Enemy area (right side — STS style) ---
	# --- Enemy area (right side — STS style) ---
	var enemy_x := viewport_size.x / 2 + 120
	var enemy_cy := viewport_size.y / 2 - 50

	# Enemy visual — use config-driven colors/size
	var evis: Dictionary = encounter.get("visual", {})
	var ev_size: Vector2 = evis.get("size", Vector2(150, 120))
	var ev_color: Color = evis.get("color", Color(0.5, 0.1, 0.1, 0.9))
	var ev_border: Color = evis.get("border_color", Color(0.85, 0.25, 0.25))
	var ev_radius: int = evis.get("corner_radius", 12)
	var ev_border_w: int = 3 if encounter.get("type", "normal") == "boss" else 2

	_enemy_visual = Panel.new()
	_enemy_visual.name = "EnemyVisual"
	_enemy_visual.position = Vector2(enemy_x + 25, enemy_cy - ev_size.y / 2)
	_enemy_visual.size = ev_size
	var ev_style := StyleBoxFlat.new()
	ev_style.bg_color = ev_color
	ev_style.border_color = ev_border
	ev_style.set_border_width_all(ev_border_w)
	ev_style.set_corner_radius_all(ev_radius)
	_enemy_visual.add_theme_stylebox_override("panel", ev_style)
	add_child(_enemy_visual)
	_combat_ui_nodes.append(_enemy_visual)
	# Intent label (above enemy visual)
	# Intent label (above enemy visual)
	_enemy_intent_label = Label.new()
	_enemy_intent_label.name = "EnemyIntentLabel"
	_enemy_intent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enemy_intent_label.position = Vector2(enemy_x, enemy_cy - ev_size.y / 2 - 30)
	_enemy_intent_label.size = Vector2(200, 20)
	_enemy_intent_label.add_theme_font_size_override("font_size", 14)
	_enemy_intent_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	_enemy_intent_label.text = ""
	add_child(_enemy_intent_label)
	_combat_ui_nodes.append(_enemy_intent_label)

	_enemy_name_label = Label.new()
	_enemy_name_label.name = "EnemyNameLabel"
	_enemy_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enemy_name_label.position = Vector2(enemy_x, enemy_cy - ev_size.y / 2 - 10)
	_enemy_name_label.size = Vector2(200, 20)
	_enemy_name_label.add_theme_font_size_override("font_size", 16)
	_enemy_name_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	_enemy_name_label.text = combat_manager.enemy.display_name
	add_child(_enemy_name_label)
	_combat_ui_nodes.append(_enemy_name_label)

	# Enemy HP bar (below enemy visual)
	_enemy_hp_bar = ProgressBar.new()
	_enemy_hp_bar.name = "EnemyHpBar"
	_enemy_hp_bar.position = Vector2(enemy_x + 25, enemy_cy + ev_size.y / 2 + 8)
	_enemy_hp_bar.size = Vector2(ev_size.x, 16)
	_enemy_hp_bar.min_value = 0
	_enemy_hp_bar.max_value = combat_manager.enemy.max_hp
	_enemy_hp_bar.value = combat_manager.enemy.hp
	_enemy_hp_bar.show_percentage = false
	var ehp_bg := StyleBoxFlat.new()
	ehp_bg.bg_color = Color(0.15, 0.15, 0.15)
	ehp_bg.set_corner_radius_all(4)
	var ehp_fill := StyleBoxFlat.new()
	ehp_fill.bg_color = Color(0.2, 0.8, 0.2)
	ehp_fill.set_corner_radius_all(4)
	_enemy_hp_bar.add_theme_stylebox_override("background", ehp_bg)
	_enemy_hp_bar.add_theme_stylebox_override("fill", ehp_fill)
	add_child(_enemy_hp_bar)
	_combat_ui_nodes.append(_enemy_hp_bar)

	_enemy_hp_text = Label.new()
	_enemy_hp_text.name = "EnemyHpText"
	_enemy_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enemy_hp_text.position = Vector2(enemy_x, enemy_cy + ev_size.y / 2 + 28)
	_enemy_hp_text.size = Vector2(200, 22)
	_enemy_hp_text.add_theme_font_size_override("font_size", 16)
	_enemy_hp_text.add_theme_color_override("font_color", Color.WHITE)
	_enemy_hp_text.add_theme_color_override("font_outline_color", Color.BLACK)
	_enemy_hp_text.add_theme_constant_override("outline_size", 2)
	_enemy_hp_text.text = "%d/%d" % [combat_manager.enemy.hp, combat_manager.enemy.max_hp]
	add_child(_enemy_hp_text)
	_combat_ui_nodes.append(_enemy_hp_text)

	_enemy_block_label = Label.new()
	_enemy_block_label.name = "EnemyBlockLabel"
	_enemy_block_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enemy_block_label.position = Vector2(enemy_x + 60, enemy_cy + ev_size.y / 2 + 28)
	_enemy_block_label.size = Vector2(200, 22)
	_enemy_block_label.add_theme_font_size_override("font_size", 16)
	_enemy_block_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1))
	_enemy_block_label.text = ""
	add_child(_enemy_block_label)
	_combat_ui_nodes.append(_enemy_block_label)

	_enemy_status_label = Label.new()
	_enemy_status_label.name = "EnemyStatusLabel"
	_enemy_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enemy_status_label.position = Vector2(enemy_x, enemy_cy + ev_size.y / 2 + 52)
	_enemy_status_label.size = Vector2(200, 18)
	_enemy_status_label.add_theme_font_size_override("font_size", 12)
	_enemy_status_label.text = ""
	add_child(_enemy_status_label)
	_combat_ui_nodes.append(_enemy_status_label)
	# --- Player area (left side — STS style) ---
	var player_x := viewport_size.x / 2 - 320
	var player_cy := viewport_size.y / 2 - 50

	# Player visual (geometric placeholder: blue rounded rectangle)
	_player_visual = Panel.new()
	_player_visual.name = "PlayerVisual"
	_player_visual.position = Vector2(player_x + 25, player_cy - 60)
	_player_visual.size = Vector2(150, 120)
	var pv_style := StyleBoxFlat.new()
	pv_style.bg_color = Color(0.1, 0.12, 0.4, 0.9)
	pv_style.border_color = Color(0.3, 0.5, 0.9)
	pv_style.set_border_width_all(2)
	pv_style.set_corner_radius_all(12)
	_player_visual.add_theme_stylebox_override("panel", pv_style)
	add_child(_player_visual)
	_combat_ui_nodes.append(_player_visual)

	_player_name_label = Label.new()
	_player_name_label.name = "PlayerNameLabel"
	_player_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_player_name_label.position = Vector2(player_x, player_cy - 82)
	_player_name_label.size = Vector2(200, 20)
	_player_name_label.add_theme_font_size_override("font_size", 16)
	_player_name_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
	_player_name_label.text = "Player"
	add_child(_player_name_label)
	_combat_ui_nodes.append(_player_name_label)

	# Player HP bar (below player visual)
	_player_hp_bar = ProgressBar.new()
	_player_hp_bar.name = "PlayerHpBar"
	_player_hp_bar.position = Vector2(player_x + 25, player_cy + 68)
	_player_hp_bar.size = Vector2(150, 16)
	_player_hp_bar.min_value = 0
	_player_hp_bar.max_value = combat_manager.player.max_hp
	_player_hp_bar.value = combat_manager.player.hp
	_player_hp_bar.show_percentage = false
	var php_bg := StyleBoxFlat.new()
	php_bg.bg_color = Color(0.15, 0.15, 0.15)
	php_bg.set_corner_radius_all(4)
	var php_fill := StyleBoxFlat.new()
	php_fill.bg_color = Color(0.2, 0.8, 0.2)
	php_fill.set_corner_radius_all(4)
	_player_hp_bar.add_theme_stylebox_override("background", php_bg)
	_player_hp_bar.add_theme_stylebox_override("fill", php_fill)
	add_child(_player_hp_bar)
	_combat_ui_nodes.append(_player_hp_bar)

	_player_hp_text = Label.new()
	_player_hp_text.name = "PlayerHpText"
	_player_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_player_hp_text.position = Vector2(player_x, player_cy + 88)
	_player_hp_text.size = Vector2(200, 22)
	_player_hp_text.add_theme_font_size_override("font_size", 16)
	_player_hp_text.add_theme_color_override("font_color", Color.WHITE)
	_player_hp_text.add_theme_color_override("font_outline_color", Color.BLACK)
	_player_hp_text.add_theme_constant_override("outline_size", 2)
	_player_hp_text.text = "%d/%d" % [combat_manager.player.hp, combat_manager.player.max_hp]
	add_child(_player_hp_text)
	_combat_ui_nodes.append(_player_hp_text)

	_player_block_label = Label.new()
	_player_block_label.name = "PlayerBlockLabel"
	_player_block_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_player_block_label.position = Vector2(player_x + 60, player_cy + 88)
	_player_block_label.size = Vector2(200, 22)
	_player_block_label.add_theme_font_size_override("font_size", 16)
	_player_block_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1))
	_player_block_label.text = ""
	add_child(_player_block_label)
	_combat_ui_nodes.append(_player_block_label)

	_player_status_label = Label.new()
	_player_status_label.name = "PlayerStatusLabel"
	_player_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_player_status_label.position = Vector2(player_x, player_cy + 112)
	_player_status_label.size = Vector2(200, 18)
	_player_status_label.add_theme_font_size_override("font_size", 12)
	_player_status_label.text = ""
	add_child(_player_status_label)
	_combat_ui_nodes.append(_player_status_label)

	# End Turn button (center-right, above hand area)
	_end_turn_button = Button.new()
	_end_turn_button.name = "EndTurnButton"
	_end_turn_button.text = "End Turn"
	_end_turn_button.position = Vector2(viewport_size.x / 2 + 300, viewport_size.y - 260)
	_end_turn_button.size = Vector2(120, 50)
	_end_turn_button.add_theme_font_size_override("font_size", 18)
	_style_end_turn_button(_end_turn_button)
	_end_turn_button.connect("pressed", Callable(self, "_on_EndTurn_pressed"))
	_end_turn_button.disabled = true
	add_child(_end_turn_button)
	_combat_ui_nodes.append(_end_turn_button)

	# All non-interactive UI elements must pass through mouse events,
	# otherwise they consume gui_input and prevent card drag release detection.
	for node in _combat_ui_nodes:
		if node is Control and node != _end_turn_button:
			node.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Hide framework demo UI not needed during combat
	for node_name in ["Counters"]:
		var n := get_node_or_null(node_name)
		if n:
			n.visible = false
	for container_name in ["deck", "discard", "hand"]:
		var container = cfc.NMAP.get(container_name) if cfc.NMAP else null
		if container:
			var mb = container.get_node_or_null("Control/ManipulationButtons")
			if mb:
				mb.visible = false


func _set_piles_visible(vis: bool) -> void:
	for pile_name in ["deck", "discard", "hand"]:
		var container = cfc.NMAP.get(pile_name) if cfc.NMAP else null
		if container:
			container.visible = vis


# --- Combat signal handlers ---


func _on_energy_changed(current: int, max_energy: int) -> void:
	if _energy_label:
		_energy_label.text = "%d" % current
	if _energy_orb:
		var style: StyleBoxFlat = _energy_orb.get_theme_stylebox("panel")
		if current < max_energy:
			style.bg_color = Color(0.04, 0.08, 0.2, 0.95)
			style.border_color = Color(0.2, 0.4, 0.7)
		else:
			style.bg_color = Color(0.08, 0.18, 0.45, 0.95)
			style.border_color = Color(0.3, 0.6, 1.0)
	_notify_hand_cards_cost_update()


func _on_turn_started(turn_num: int) -> void:
	if _turn_label:
		_turn_label.text = "Turn %d" % turn_num
	if _end_turn_button:
		_end_turn_button.disabled = false


func _on_turn_ended() -> void:
	if _end_turn_button:
		_end_turn_button.disabled = true


func _show_combat_relic_tooltip(anchor: Control, relic_id: String) -> void:
	_hide_combat_relic_tooltip()
	var _RelicDB = load("res://src/custom/RelicDatabase.gd")
	var data: Dictionary = _RelicDB.get_relic(relic_id)
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
	_combat_ui_nodes.append(tooltip)
	# Position below anchor
	await get_tree().process_frame
	var vp_size: Vector2 = get_viewport().size
	var tx: float = mini(anchor.global_position.x - 30, vp_size.x - tooltip.size.x - 10)
	var ty: float = anchor.global_position.y + anchor.size.y + 5
	if ty + tooltip.size.y > vp_size.y:
		ty = anchor.global_position.y - tooltip.size.y - 5
	tooltip.position = Vector2(tx, ty)


func _hide_combat_relic_tooltip() -> void:
	var tooltip = get_node_or_null("RelicTooltip")
	if tooltip:
		_combat_ui_nodes.erase(tooltip)
		tooltip.queue_free()


func _style_end_turn_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.15, 0.2)
	normal.border_color = Color(0.7, 0.6, 0.3)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(8)
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var hover := normal.duplicate()
	hover.bg_color = Color(0.2, 0.2, 0.28)
	hover.border_color = Color(1, 0.85, 0.3)
	hover.set_border_width_all(3)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.1, 0.1, 0.15)
	pressed.border_color = Color(0.5, 0.4, 0.2)
	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.08, 0.08, 0.08, 0.5)
	disabled.border_color = Color(0.3, 0.3, 0.3)
	disabled.set_border_width_all(1)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color(1, 0.85, 0.3))
	btn.add_theme_color_override("font_disabled_color", Color(0.4, 0.4, 0.4))


func _on_EndTurn_pressed() -> void:
	if combat_manager and combat_manager.is_player_turn:
		if audio_manager:
			audio_manager.play_sfx("button_click", -3.0)  # VOL_UI
		combat_manager.end_turn()


func _on_combat_ended() -> void:
	if _end_turn_button:
		_end_turn_button.disabled = true
	if _enemy_intent_label:
		_enemy_intent_label.text = ""
	if combat_manager.combat_result == "victory":
		run_state.player_hp = combat_manager.player.hp
		# Gold reward
		var gold_reward: int = run_state.get_gold_reward()
		run_state.add_gold(gold_reward)
		# Red Skull relic: +2 strength after elite/boss
		if run_state.is_elite_or_boss_encounter() and run_state.has_relic("red_skull"):
			run_state.player_strength += 2
		# Elite/boss relic drop
		var dropped_relic: String = ""
		if run_state.is_elite_or_boss_encounter():
			var _RelicDB = load("res://src/custom/RelicDatabase.gd")
			dropped_relic = _RelicDB.get_random_relic(run_state.relics)
			if dropped_relic != "":
				run_state.add_relic(dropped_relic)
		if audio_manager:
			audio_manager.play_sfx("victory")
		await _animate_victory()
		_show_reward_screen(gold_reward, dropped_relic)
	else:
		await _animate_defeat()
		if audio_manager:
			audio_manager.play_sfx("defeat")
		_show_game_over_screen()


# --- Turn transition banner ---


func _show_turn_banner(text: String, color: Color) -> void:
	var viewport_size := Vector2(get_viewport().size)
	# Semi-transparent overlay to block input during banner
	var overlay := ColorRect.new()
	overlay.name = "TurnBannerOverlay"
	overlay.color = Color(0, 0, 0, 0.4)
	overlay.size = viewport_size
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 200
	overlay.modulate.a = 0.0
	add_child(overlay)
	# Banner text label
	var label := Label.new()
	label.name = "TurnBannerLabel"
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(0, viewport_size.y / 2 - 40)
	label.size = Vector2(viewport_size.x, 80)
	label.add_theme_font_size_override("font_size", 42)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 3)
	label.z_index = 201
	label.scale = Vector2(1.5, 1.5)
	label.modulate.a = 0.0
	add_child(label)
	# Animation: appear → hold → fade out
	var tween := create_tween()
	# Phase 1: scale in + fade in (0.3s)
	tween.tween_property(overlay, "modulate:a", 1.0, 0.3)
	tween.parallel().tween_property(label, "modulate:a", 1.0, 0.3)
	tween.parallel().tween_property(label, "scale", Vector2(1.0, 1.0), 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Phase 2: hold (0.4s)
	tween.tween_interval(0.4)
	# Phase 3: fade out (0.3s)
	tween.tween_property(overlay, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.3)
	# Cleanup
	tween.tween_callback(overlay.queue_free)
	tween.tween_callback(label.queue_free)


func _on_player_turn_banner() -> void:
	if audio_manager:
		audio_manager.play_sfx("turn_start")
	_show_turn_banner("你的回合", Color(1, 0.85, 0.2))


func _on_enemy_turn_banner() -> void:
	if audio_manager:
		audio_manager.play_sfx("enemy_attack", -3.0)  # lighter than actual attack
	_show_turn_banner("敌方回合", Color(1, 0.3, 0.3))


# --- Combat end animations ---


func _animate_victory() -> void:
	if _enemy_visual:
		_enemy_visual.pivot_offset = _enemy_visual.size / 2
		var tween := create_tween()
		tween.tween_property(_enemy_visual, "modulate:a", 0.0, 0.6)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(_enemy_visual, "scale", Vector2(0.3, 0.3), 0.6)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		# Fade enemy stat labels
		for node in [_enemy_name_label, _enemy_hp_bar, _enemy_hp_text, _enemy_block_label, _enemy_status_label]:
			if node and is_instance_valid(node):
				tween.parallel().tween_property(node, "modulate:a", 0.0, 0.5)
		await tween.finished
		# Brief pause before reward screen
		await get_tree().create_timer(0.3).timeout


func _animate_defeat() -> void:
	var viewport_size := Vector2(get_viewport().size)
	# Dark overlay
	var overlay := ColorRect.new()
	overlay.name = "DefeatOverlay"
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.size = viewport_size
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 200
	overlay.modulate.a = 0.0
	add_child(overlay)
	var tween := create_tween()
	# Darken screen
	tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
	# Screen shake
	var orig_pos := position
	for i in range(8):
		var offset := Vector2(randf_range(-8, 8), randf_range(-5, 5))
		tween.tween_property(self, "position", orig_pos + offset, 0.04)
	tween.tween_property(self, "position", orig_pos, 0.06)
	await tween.finished
	# Remove defeat overlay immediately (queue_free defers to frame end)
	overlay.visible = false
	overlay.queue_free()


# Show the reward selection screen (non-final victory).
func _show_reward_screen(gold_reward: int = 0, dropped_relic: String = "") -> void:
	_reward_screen = Control.new()
	_reward_screen.set_script(load("res://src/custom/RewardScreen.gd"))
	_reward_screen.setup(Vector2(get_viewport().size))
	_reward_screen.connect("reward_selected", Callable(self, "_on_reward_card_selected"))
	_reward_screen.connect("reward_skipped", Callable(self, "_on_reward_skipped"))
	_reward_screen.connect("continue_run", Callable(self, "_on_continue_run"))
	add_child(_reward_screen)
	_reward_screen.show_victory_rewards(false, gold_reward)
	# Show relic drop notification
	if dropped_relic != "":
		var _RelicDB = load("res://src/custom/RelicDatabase.gd")
		var rdata: Dictionary = _RelicDB.get_relic(dropped_relic)
		_show_relic_toast(rdata.get("icon", ""), rdata.get("name", ""))


# Show the run complete screen (final victory).
func _show_run_complete_screen() -> void:
	_reward_screen = Control.new()
	_reward_screen.set_script(load("res://src/custom/RewardScreen.gd"))
	_reward_screen.setup(Vector2(get_viewport().size))
	_reward_screen.connect("return_to_menu", Callable(self, "_on_return_to_menu"))
	add_child(_reward_screen)
	_reward_screen.show_run_complete(run_state.player_hp, run_state.player_max_hp)


# Show the game over screen (defeat).
func _show_game_over_screen() -> void:
	_reward_screen = Control.new()
	_reward_screen.set_script(load("res://src/custom/RewardScreen.gd"))
	_reward_screen.setup(Vector2(get_viewport().size))
	_reward_screen.connect("return_to_menu", Callable(self, "_on_return_to_menu"))
	add_child(_reward_screen)
	_reward_screen.show_game_over()


# --- M11: Map, Shop, Rest flows ---


func _show_map_screen() -> void:
	if _map_screen and is_instance_valid(_map_screen):
		_map_screen.queue_free()
	_set_piles_visible(false)
	_map_screen = Control.new()
	_map_screen.set_script(load("res://src/custom/MapScreen.gd"))
	_map_screen.setup(Vector2(get_viewport().size), run_state)
	_map_screen.connect("node_selected", Callable(self, "_on_map_node_selected"))
	add_child(_map_screen)
	_map_screen.show_map()


func _close_map_screen() -> void:
	cfc.game_paused = false
	if _map_screen and is_instance_valid(_map_screen):
		_map_screen.queue_free()
		_map_screen = null


func _on_map_node_selected(floor_index: int, node_index: int) -> void:
	_close_map_screen()
	var node: Dictionary = run_state.get_current_node()
	var node_type: String = node.get("type", "combat")
	match node_type:
		"combat", "elite", "boss":
			_setup_combat()
		"shop":
			_show_shop_screen()
		"rest":
			_do_rest()


func _show_shop_screen() -> void:
	if _shop_screen and is_instance_valid(_shop_screen):
		_shop_screen.queue_free()
	_set_piles_visible(false)
	_shop_screen = Control.new()
	_shop_screen.set_script(load("res://src/custom/ShopScreen.gd"))
	_shop_screen.setup(Vector2(get_viewport().size), run_state, self)
	_shop_screen.connect("shop_closed", Callable(self, "_on_shop_closed"))
	add_child(_shop_screen)
	_shop_screen.show_shop()


func _on_shop_closed() -> void:
	if _shop_screen and is_instance_valid(_shop_screen):
		_shop_screen.queue_free()
		_shop_screen = null
	_show_map_screen()


func _do_rest() -> void:
	_set_piles_visible(false)
	var heal_amount: int = int(run_state.player_max_hp * 0.3)
	run_state.player_hp = mini(run_state.player_hp + heal_amount, run_state.player_max_hp)
	# Brief rest notification then return to map
	var toast := Label.new()
	toast.text = "❤️ 休息恢复 %d HP!" % heal_amount
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.position = Vector2(get_viewport().size.x / 2.0 - 150, get_viewport().size.y / 2.0 - 20)
	toast.size = Vector2(300, 40)
	toast.add_theme_font_size_override("font_size", 24)
	toast.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
	toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	toast.add_theme_constant_override("outline_size", 2)
	toast.z_index = 200
	add_child(toast)
	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(toast, "modulate:a", 0.0, 0.5)
	tween.tween_callback(toast.queue_free)
	await tween.finished
	_show_map_screen()


func _show_relic_toast(icon: String, relic_name: String) -> void:
	var toast := Label.new()
	toast.text = "%s 获得遗物: %s!" % [icon, relic_name]
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.position = Vector2(get_viewport().size.x / 2.0 - 180, get_viewport().size.y / 2.0 + 30)
	toast.size = Vector2(360, 40)
	toast.add_theme_font_size_override("font_size", 20)
	toast.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	toast.add_theme_constant_override("outline_size", 2)
	toast.z_index = 200
	add_child(toast)
	var tween := create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(toast, "modulate:a", 0.0, 0.5)
	tween.tween_callback(toast.queue_free)


# Add the selected reward card to the deck and run state.
func _on_reward_card_selected(card_name: String) -> void:
	if audio_manager:
		audio_manager.play_sfx("reward_select")
	var card = cfc.instance_card(card_name)
	inject_combat_manager(card)
	cfc.NMAP.deck.add_child(card)
	card._determine_idle_state()
	run_state.deck_card_names.append(card_name)
	push_warning("Reward: %s added to deck" % card_name)
	_on_continue_run()


# Player skipped the reward.
func _on_reward_skipped() -> void:
	push_warning("Reward skipped")
	_on_continue_run()


# Player clicked "Continue" after reward — save strength, go to map or run complete.
func _on_continue_run() -> void:
	# Save persistent strength from combat
	if combat_manager and combat_manager.player:
		run_state.player_strength = combat_manager.player.strength
	_cleanup_combat()
	if run_state.is_current_node_final():
		_show_run_complete_screen()
	else:
		_show_map_screen()


# Return to the main menu scene.
func _on_return_to_menu() -> void:
	cfc.quit_game()
	get_tree().change_scene_to_file("res://src/custom/MainMenu.tscn")


# After energy changes, re-check costs for all cards in hand
func _notify_hand_cards_cost_update() -> void:
	if not cfc.NMAP.has("hand"):
		return
	for card in cfc.NMAP.hand.get_all_cards():
		if is_instance_valid(card):
			_update_card_playable_visual(card)
			if card.state == Card.CardState.FOCUSED_IN_HAND:
					card.set_focus(true, card.check_play_costs())


# Update a card's visual to reflect whether it can be played.
func _update_card_playable_visual(card: Card) -> void:
	if not is_instance_valid(card):
		return
	if not combat_manager or not combat_manager.is_player_turn:
		card.modulate = Color.WHITE
		return
	if combat_manager.can_play_card(card):
		card.modulate = Color.WHITE
	else:
		card.modulate = Color(0.5, 0.5, 0.5, 1.0)


# Inject combat_manager reference into newly instanced cards.
func inject_combat_manager(card: Card) -> void:
	if combat_manager and is_instance_valid(card):
		card.combat_manager = combat_manager


# --- Entity UI update handlers ---


func _on_player_hp_changed(current, maximum) -> void:
	var clamped := maxi(current, 0)
	if _player_hp_bar:
		var ratio: float = float(clamped) / float(maximum)
		_update_hp_bar_color(_player_hp_bar, ratio)
		var tween := create_tween()
		tween.tween_property(_player_hp_bar, "value", clamped, 0.3)
	if _player_hp_text:
		_player_hp_text.text = "%d/%d" % [clamped, maximum]


func _on_player_block_changed(new_block) -> void:
	if _player_block_label:
		_player_block_label.text = "🛡️ %d" % new_block if new_block > 0 else ""
	if new_block > 0 and audio_manager:
		audio_manager.play_sfx("block_gain")


func _on_player_stats_changed() -> void:
	if _player_status_label and combat_manager:
		var e = combat_manager.player
		_player_status_label.text = _format_status_text(e)


func _on_enemy_hp_changed(current, maximum) -> void:
	var clamped := maxi(current, 0)
	if _enemy_hp_bar:
		var ratio: float = float(clamped) / float(maximum)
		_update_hp_bar_color(_enemy_hp_bar, ratio)
		var tween := create_tween()
		tween.tween_property(_enemy_hp_bar, "value", clamped, 0.3)
	if _enemy_hp_text:
		_enemy_hp_text.text = "%d/%d" % [clamped, maximum]


func _on_enemy_block_changed(new_block) -> void:
	if _enemy_block_label:
		_enemy_block_label.text = "🛡️ %d" % new_block if new_block > 0 else ""
	if new_block > 0 and audio_manager:
		audio_manager.play_sfx("block_gain")


func _on_enemy_stats_changed() -> void:
	if _enemy_status_label and combat_manager:
		var e = combat_manager.enemy
		_enemy_status_label.text = _format_status_text(e)


func _on_enemy_intent_changed(intent_info: Dictionary) -> void:
	if _enemy_intent_label:
		if intent_info.is_empty():
			_enemy_intent_label.text = ""
		else:
			_enemy_intent_label.text = _format_intent_text(intent_info)


# Spawn a floating number at the target position, rising and fading out.
func _spawn_floating_text(text: String, pos: Vector2, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.global_position = pos - Vector2(30, 20)
	label.z_index = 100
	add_child(label)
	# Float up and fade out
	var tween := create_tween()
	tween.tween_property(label, "global_position:y", pos.y - 70, 0.8)\
		.set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(label.queue_free)


# Handle entity_damaged signal: spawn floating damage/heal text.
func _on_entity_damaged(entity, amount: int) -> void:
	var pos: Vector2
	var color: Color
	if entity == combat_manager.enemy and _enemy_visual:
		pos = _enemy_visual.global_position + _enemy_visual.size / 2.0
		color = Color(1, 0.3, 0.3)  # Red for enemy damage
		_spawn_floating_text("-%d" % amount, pos, color)
		if amount > 0 and audio_manager:
			audio_manager.play_sfx("hit_enemy", 2.0)
			# Enemy hit feedback: flash white + shake
			var ev_tween := create_tween()
			ev_tween.tween_property(_enemy_visual, "modulate", Color.WHITE * 3, 0.05)
			ev_tween.tween_property(_enemy_visual, "modulate", Color.WHITE, 0.15)
			var ev_orig := _enemy_visual.position
			for _j in range(4):
				ev_tween.tween_property(_enemy_visual, "position", ev_orig + Vector2(randf_range(-4, 4), randf_range(-3, 3)), 0.03)
			ev_tween.tween_property(_enemy_visual, "position", ev_orig, 0.05)
	elif entity == combat_manager.player and _player_visual:
		pos = _player_visual.global_position + _player_visual.size / 2.0
		color = Color(1, 0.3, 0.3)  # Red for player damage
		_spawn_floating_text("-%d" % amount, pos, color)
		if amount > 0 and audio_manager:
			audio_manager.play_sfx("hit_player", 2.0)
			# Player hit feedback: screen edge flash red
			if _hit_overlay:
				var hit_tween := create_tween()
				hit_tween.tween_property(_hit_overlay, "color:a", 0.3, 0.05)
				hit_tween.tween_property(_hit_overlay, "color:a", 0.0, 0.3)


# Handle poison_damaged signal: spawn green floating poison text.
func _on_poison_tick(entity, amount: int) -> void:
	var pos: Vector2
	if entity == combat_manager.enemy and _enemy_visual:
		pos = _enemy_visual.global_position + _enemy_visual.size / 2.0
		_spawn_floating_text("☠️-%d" % amount, pos, Color(0.3, 0.9, 0.3))
	elif entity == combat_manager.player and _player_visual:
		pos = _player_visual.global_position + _player_visual.size / 2.0
		_spawn_floating_text("☠️-%d" % amount, pos, Color(0.3, 0.9, 0.3))


# Handle healed signal: spawn green floating heal text.
func _on_player_healed(entity, amount: int) -> void:
	if _player_visual:
		var pos: Vector2 = _player_visual.global_position + _player_visual.size / 2.0
		_spawn_floating_text("+%d" % amount, pos, Color(0.2, 0.9, 0.3))



# Handle thorns_triggered signal: spawn orange floating thorns text at the source.
func _on_thorns_triggered(source, damage: int) -> void:
	if source == combat_manager.enemy and _enemy_visual:
		var pos: Vector2 = _enemy_visual.global_position + _enemy_visual.size / 2.0
		_spawn_floating_text("🌵%d" % damage, pos, Color(1.0, 0.7, 0.1))

# Update HP bar fill color based on ratio (green → yellow → red).
func _update_hp_bar_color(bar: ProgressBar, ratio: float) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	var fill: StyleBoxFlat = bar.get_theme_stylebox("fill")
	var green := Color(0.2, 0.8, 0.2)
	var yellow := Color(0.9, 0.7, 0.1)
	var red := Color(0.9, 0.2, 0.2)
	if ratio > 0.5:
		fill.bg_color = green.lerp(yellow, (1.0 - ratio) * 2.0)
	else:
		fill.bg_color = yellow.lerp(red, (0.5 - ratio) * 2.0)


# --- Drag targeting ---


# Toggle the enemy area highlight (pulsing glow when dragging attack cards).
func _set_enemy_highlight(enabled: bool) -> void:
	if not _enemy_visual:
		return
	var style: StyleBoxFlat = _enemy_visual.get_theme_stylebox("panel")
	if enabled:
		style.set_border_width_all(4)
		if _enemy_highlight_tween:
			_enemy_highlight_tween.kill()
		_enemy_highlight_tween = create_tween()
		_enemy_highlight_tween.set_loops()
		_enemy_highlight_tween.tween_property(style, "border_color", Color(1.0, 0.9, 0.2), 0.35)
		_enemy_highlight_tween.tween_property(style, "border_color", Color(1.0, 0.5, 0.2), 0.35)
	else:
		if _enemy_highlight_tween:
			_enemy_highlight_tween.kill()
			_enemy_highlight_tween = null
		style.set_border_width_all(2)
		style.border_color = Color(0.85, 0.25, 0.25)


# Get the enemy drop target rect (expanded for easier targeting).
func get_enemy_drop_rect() -> Rect2:
	if not _enemy_visual:
		return Rect2()
	return Rect2(_enemy_visual.global_position, _enemy_visual.size).grow(30)


# Format status effects as a compact string.
static func _format_status_text(entity) -> String:
	var parts: Array = []
	if entity.strength != 0:
		parts.append("⚔️%d" % entity.strength)
	if entity.vulnerable > 0:
		parts.append("🔻%d" % entity.vulnerable)
	if entity.weak > 0:
		parts.append("❄️%d" % entity.weak)
	if entity.poison > 0:
		parts.append("☠️%d" % entity.poison)
	if entity.thorns > 0:
		parts.append("🌵%d" % entity.thorns)
	return "  ".join(parts)

static func _format_intent_text(intent: Dictionary) -> String:
	var parts: Array = []
	if intent.get("damage", 0) > 0:
		var hits: int = intent.get("hits", 1)
		if hits > 1:
			parts.append("⚔️%d×%d" % [intent["damage"], hits])
		else:
			parts.append("⚔️%d" % intent["damage"])
	if intent.get("block", 0) > 0:
		parts.append("🛡️%d" % intent["block"])
	if intent.get("strength", 0) > 0:
		parts.append("⬆️+%d⚔️" % intent["strength"])
	if intent.get("poison", 0) > 0:
		parts.append("☠️%d" % intent["poison"])
	if intent.get("weak", 0) > 0:
		parts.append("❄️%d" % intent["weak"])
	var text := " ".join(parts)
	if text != "":
		text = intent.get("name", "") + " " + text
	return text



# --- Deck builder and navigation ---

# Load the deck from run_state's card name list.
func _load_deck_from_run_state() -> void:
	for card_name in run_state.deck_card_names:
		var card = cfc.instance_card(card_name)
		inject_combat_manager(card)
		cfc.NMAP.deck.add_child(card)
		card._determine_idle_state()


func _on_DeckBuilder_pressed() -> void:
	cfc.game_paused = true
	$DeckBuilderPopup.popup_centered_clamped()

func _on_DeckBuilder_hide() -> void:
	cfc.game_paused = false


func _on_BackToMain_pressed() -> void:
	cfc.quit_game()
	get_tree().change_scene_to_file("res://src/custom/MainMenu.tscn")
