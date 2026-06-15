extends Control

# The time it takes to switch from one menu tab to another
const menu_switch_time = 0.35
# Design resolution (matches project.godot viewport_width/height).
# canvas_items stretch mode scales the canvas, so all positions/sizes
# must use this constant, NOT get_viewport().size (which returns window size).
const DESIGN_SIZE := CFConst.DESIGN_RESOLUTION

@onready var v_buttons := $MainMenu/VBox/Center/VButtons
@onready var main_menu := $MainMenu
@onready var deck_builder := $DeckBuilder
@onready var card_library := $CardLibrary

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_setup_background()
	for option_button in v_buttons.get_children():
		if option_button.has_signal('pressed'):
			option_button.connect('pressed', Callable(self, 'on_button_pressed').bind(option_button.name))
	deck_builder.position.x = -DESIGN_SIZE.x
	card_library.position.x = -DESIGN_SIZE.x
	deck_builder.back_button.connect("pressed", Callable(self, "_on_DeckBuilder_Back_pressed"))
	card_library.back_button.connect("pressed", Callable(self, "_on_CardLibrary_Back_pressed"))


func _setup_background() -> void:
	var bg := $MainMenu/Background
	var gradient := Gradient.new()
	gradient.colors = [Color(0.05, 0.05, 0.12), Color(0.12, 0.06, 0.18)]
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.4)
	tex.fill_to = Vector2(1.0, 0.4)
	bg.texture = tex


func on_button_pressed(_button_name : String) -> void:
	match _button_name:
		"StartRun":
			# warning-ignore:return_value_discarded
			get_tree().change_scene_to_file(CFConst.PATH_CUSTOM + 'CGFMain.tscn')
		"GUT":
			# warning-ignore:return_value_discarded
			get_tree().change_scene_to_file("res://tests/tests.tscn")
		"Deckbuilder":
			switch_to_tab(deck_builder)
		"CardLibrary":
			switch_to_tab(card_library)
		"Exit":
			get_tree().quit()

func switch_to_tab(tab: Control) -> void:
	var main_position_x : float
	match tab:
		deck_builder, card_library:
			main_position_x = DESIGN_SIZE.x
	var tween: Tween
	if tween:
		tween.kill()
	tween = get_tree().create_tween().set_parallel(true)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(main_menu,'position:x', main_position_x, menu_switch_time)
	tween.tween_property(tab,'position:x', 0, menu_switch_time)
	tween.play()


func switch_to_main_menu(tab: Control) -> void:
	var tab_position_x : float
	match tab:
		deck_builder, card_library:
			tab_position_x = -DESIGN_SIZE.x
	var tween: Tween
	if tween:
		tween.kill()
	tween = get_tree().create_tween().set_parallel(true)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(tab,'position:x', tab_position_x, menu_switch_time)
	tween.tween_property(main_menu,'position:x', 0, menu_switch_time)
	tween.play()

func _on_DeckBuilder_Back_pressed() -> void:
	switch_to_main_menu(deck_builder)

func _on_CardLibrary_Back_pressed() -> void:
	switch_to_main_menu(card_library)
