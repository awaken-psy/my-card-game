extends "res://tests/UTcommon.gd"
# Tests for the turn-transition banner strict-ordering fix (issue #3).
# Verifies that showing a new banner forcibly cleans up the previous one so
# the two banners can never overlap on screen.

func before_each():
	cfc.game_settings.fancy_movement = false

func after_each():
	cfc.game_settings.fancy_movement = true


# A new banner must kill + free the previous banner's nodes, so at most one
# banner pair (overlay + label) is ever present at a time.
func test_show_banner_cleans_up_previous():
	await setup_board()
	# First banner.
	board._show_turn_banner("敌方回合", Color(1, 0.3, 0.3))
	await get_tree().create_timer(0.05).timeout  # let nodes enter tree
	var first_overlay := board.get_node_or_null("TurnBannerOverlay")
	var first_label := board.get_node_or_null("TurnBannerLabel")
	assert_not_null(first_overlay, "First banner overlay exists")
	assert_not_null(first_label, "First banner label exists")
	# Capture references before the second banner is shown.
	var first_overlay_id := first_overlay.get_instance_id()
	# Show the second banner before the first one finished its lifetime.
	board._show_turn_banner("你的回合", Color(1, 0.85, 0.2))
	await get_tree().create_timer(0.05).timeout
	# The old overlay must already be freed (or queued for free).
	assert_false(is_instance_id_valid(first_overlay_id),
			"Previous banner overlay was freed before showing the new one")
	# Exactly one banner pair should exist now.
	var overlays := 0
	var labels := 0
	for child in board.get_children():
		if child is ColorRect and child.name == "TurnBannerOverlay":
			overlays += 1
		if child is Label and child.name == "TurnBannerLabel":
			labels += 1
	assert_eq(1, overlays, "Exactly one banner overlay after replacement")
	assert_eq(1, labels, "Exactly one banner label after replacement")
	await teardown_board()


# The banner total time must equal fade_in + hold + fade_out so the enemy turn
# wait can be sized to fully cover it (preventing overlap).
func test_banner_total_time_constant():
	await setup_board()
	var expected: float = board.BANNER_FADE_IN + board.BANNER_HOLD + board.BANNER_FADE_OUT
	assert_eq(expected, board.BANNER_TOTAL_TIME,
			"BANNER_TOTAL_TIME equals the sum of its phases")
	assert_eq(expected, board.get_banner_total_time(),
			"get_banner_total_time() returns the constant")
	# Guard against accidentally shrinking the banner below the enemy-turn wait
	# used by CombatManager._enemy_turn (0.5 + 0.6 = 1.1s).
	assert_gt(board.get_banner_total_time(), 0.9,
			"Banner lifetime stays long enough to be readable")
	await teardown_board()


# The banner should free itself and clear references once its tween completes
# naturally (no replacement), so we don't leak nodes or stale tween refs.
func test_banner_self_cleans_after_completion():
	await setup_board()
	board._show_turn_banner("敌方回合", Color(1, 0.3, 0.3))
	await get_tree().create_timer(0.05).timeout
	assert_eq(2, board._current_banner_nodes.size(),
			"Banner nodes tracked while playing")
	# Wait past the full lifetime plus margin.
	await get_tree().create_timer(board.get_banner_total_time() + 0.3).timeout
	assert_eq(0, board._current_banner_nodes.size(),
			"Banner node refs cleared after tween completes")
	assert_null(board._current_banner_tween,
			"Banner tween ref cleared after tween completes")
	await teardown_board()
