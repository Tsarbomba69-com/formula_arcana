package core

import "core:testing"

// ============================================================================
// Feature: scrolling a bounded UI viewport
// ============================================================================

@(test)
given_content_exceeds_the_viewport_when_scrolled_past_its_end_then_offset_stops_at_the_content_bound :: proc(
	t: ^testing.T,
) {
	tree: UI_Tree
	content := ui_add(&tree, Container{direction = .Vertical, width = 100, height = 300})
	viewport := ui_add(&tree, Scroll_View{width = 100, height = 120}, content)
	state: Scroll_State

	ui_layout(&tree, {100, 120}, test_measure)
	result := ui_scroll_by(&tree, &state, viewport, {0, 500})

	testing.expect_value(t, result.y, 180)
	testing.expect_value(t, state.offsets[viewport].y, 180)
}

@(test)
given_content_fits_when_a_scroll_delta_is_applied_then_offset_remains_zero :: proc(t: ^testing.T) {
	tree: UI_Tree
	content := ui_add(&tree, Container{direction = .Vertical, width = 80, height = 60})
	viewport := ui_add(&tree, Scroll_View{width = 100, height = 120}, content)
	state: Scroll_State

	ui_layout(&tree, {100, 120}, test_measure)
	result := ui_scroll_by(&tree, &state, viewport, {30, 50})

	testing.expect_value(t, result.x, 0)
	testing.expect_value(t, result.y, 0)
}

@(test)
given_content_is_scrolled_when_layout_is_applied_then_child_geometry_moves_by_the_offset :: proc(
	t: ^testing.T,
) {
	tree: UI_Tree
	button := ui_add(&tree, Button{label = "Continue", width = 80, height = 30})
	content := ui_add(&tree, Container{direction = .Vertical, width = 100, height = 240}, button)
	viewport := ui_add(&tree, Scroll_View{width = 100, height = 100}, content)
	state: Scroll_State

	ui_layout(&tree, {100, 100}, test_measure)
	initial_y := tree.nodes[button].rect.y
	_ = ui_scroll_to(&tree, &state, viewport, {0, 40})
	ui_layout_scroll(&tree, {100, 100}, test_measure, state)

	testing.expect_value(t, tree.nodes[button].rect.y, initial_y - 40)
}

@(test)
given_a_button_lies_outside_the_viewport_when_pointer_hit_testing_runs_then_it_is_not_targeted :: proc(
	t: ^testing.T,
) {
	tree: UI_Tree
	button := ui_add(&tree, Button{label = "Hidden", width = 80, height = 30})
	content := ui_add(&tree, Container{direction = .Vertical, width = 100, height = 240}, button)
	viewport := ui_add(&tree, Scroll_View{width = 100, height = 100}, content)
	state: Scroll_State

	ui_layout(&tree, {100, 100}, test_measure)
	_ = ui_scroll_to(&tree, &state, viewport, {0, 150})
	ui_layout_scroll(&tree, {100, 100}, test_measure, state)

	_, found := ui_button_at_scroll(&tree, state, {50, 20})
	testing.expect(
		t,
		!found,
		"a button clipped outside the viewport must not receive pointer input",
	)
}
