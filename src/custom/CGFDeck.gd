# Deck pile for My Card Game.
# Card drawing is managed by CombatManager, not by clicking the deck.
extends Pile

signal draw_card(deck)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super._ready()
	# Shuffle animation disabled — CORGI/SPLASH animations cause the deck pile
	# to drift to wrong position and block combat startup. See Pile.shuffle_cards().
	# Framework return tween fix (a453a01) may resolve this; re-enable after testing.
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
