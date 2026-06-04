extends "res://tests/UTcommon.gd"

class TestManipulationButtons:
	extends "res://tests/Basic_common.gd"


	func test_manipulation_buttons_not_messing_hand_focus():
		var card = cards[0]
		await move_mouse(card.global_position)
		await move_mouse(card.global_position - Vector2(0,100))
		await yield_for(0.2)
		await move_mouse(card.global_position)
		await move_mouse(card.global_position - Vector2(0,100))
		await yield_for(0.2)
		await move_mouse(card.global_position)
		# Godot 4: focus tween (0.3s) triggers at end of mouse interpolation,
		# needs extra time to complete position/scale animation.
		await yield_for(0.5)
		assert_almost_eq(Vector2(103, -240.5),cards[0].position,Vector2(2,2),
				"Card focused and in correct global position")
		assert_almost_eq(Vector2(1.5, 1.5),cards[0].scale,Vector2(0.1,0.1),
				"Card has correct scale")
