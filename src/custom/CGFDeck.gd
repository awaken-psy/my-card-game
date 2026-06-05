# Deck pile for My Card Game.
# Card drawing is managed by CombatManager, not by clicking the deck.
extends Pile

signal draw_card(deck)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super._ready()
	# Disable shuffle animation entirely. The framework's shuffle animations
	# (CORGI/SPLASH/SNAP) all move the pile toward viewport center, but the
	# return tween is fire-and-forget and unreliable — the pile gets stuck at
	# the shuffle midpoint. NONE skips animation and just reorders the cards.
	shuffle_style = CFConst.ShuffleStyle.NONE
	if not cfc.are_all_nodes_mapped:
		await cfc.all_nodes_mapped
	# Keep the draw_card signal connected for compatibility
	# (CombatManager calls hand.draw_card() directly instead)
	# warning-ignore:return_value_discarded
	connect("draw_card", Callable(cfc.NMAP.hand, "draw_card"))
	# Connect click on deck to draw card (for development/testing only)
	$Control.connect("gui_input", Callable(self, "_on_Deck_input_event"))


func _on_Deck_input_event(event) -> void:
	# Allow clicking deck to draw in debug mode
	if cfc._debug and event.is_pressed() \
			and not cfc.game_paused \
			and event.get_button_index() == 1:
		emit_signal("draw_card", self)
