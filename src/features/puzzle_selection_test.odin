package features

import "../core"
import "../shared"
import "core:testing"

// Layout only needs text measurement; these tests do not create a window or use raylib.
puzzle_test_measure_text :: proc(text: string, font_size: i32, font_id: shared.Font_Id) -> f32 {
	return f32(len(text)) * f32(font_size) * 0.5
}

puzzle_test_context :: proc() -> Context {
	return {
		viewport = shared.viewport_of(1440, 900),
		renderer = {measure_text = puzzle_test_measure_text},
	}
}

puzzle_test_state :: proc(t: ^testing.T) -> Level_Select_State {
	ctx := puzzle_test_context()
	state := init_puzzle_select(&ctx, .Normal)
	testing.expect(t, state.tree.count > 0, "puzzle selection should build its UI tree")
	return state
}

puzzle_test_card_position :: proc(state: ^Level_Select_State, index: int) -> shared.Vec2 {
	rect := state.tree.nodes[state.puzzle_nodes[index]].rect
	return {
		(rect.x + rect.w / 2) * state.viewport.scale,
		(rect.y + rect.h / 2) * state.viewport.scale,
	}
}

puzzle_test_back_position :: proc(state: ^Level_Select_State) -> shared.Vec2 {
	rect := state.tree.nodes[state.back_node].rect
	return {
		(rect.x + rect.w / 2) * state.viewport.scale,
		(rect.y + rect.h / 2) * state.viewport.scale,
	}
}

@(test)
given_puzzle_selection_opens_when_it_is_initialized_then_first_puzzle_is_focused :: proc(
	t: ^testing.T,
) {
	state := puzzle_test_state(t)

	testing.expect_value(t, state.selected, 0)
	testing.expect_value(t, state.ix.focus, state.puzzle_nodes[0])
}

@(test)
given_first_puzzle_is_focused_when_down_is_pressed_then_focus_moves_one_row :: proc(
	t: ^testing.T,
) {
	state := puzzle_test_state(t)

	navigation := update_puzzle_select(&state, {shared.Key_Input{.Down}})

	testing.expect(t, navigation == nil, "moving focus should not navigate")
	testing.expect_value(t, state.selected, PUZZLE_COLUMNS)
	testing.expect_value(t, state.ix.focus, state.puzzle_nodes[PUZZLE_COLUMNS])
}

@(test)
given_first_puzzle_is_focused_when_up_is_pressed_then_focus_wraps_to_previous_row :: proc(
	t: ^testing.T,
) {
	state := puzzle_test_state(t)

	navigation := update_puzzle_select(&state, {shared.Key_Input{.Up}})

	testing.expect(t, navigation == nil, "moving focus should not navigate")
	testing.expect_value(t, state.selected, len(PUZZLES) - PUZZLE_COLUMNS)
	testing.expect_value(t, state.ix.focus, state.puzzle_nodes[len(PUZZLES) - PUZZLE_COLUMNS])
}

@(test)
given_a_puzzle_is_focused_when_confirm_is_pressed_then_that_puzzle_opens :: proc(t: ^testing.T) {
	state := puzzle_test_state(t)
	_ = update_puzzle_select(&state, {shared.Key_Input{.Down}})

	navigation := update_puzzle_select(&state, {shared.Key_Input{.Confirm}})
	gameplay, ok := navigation.(core.Go_Gameplay)

	testing.expect(t, ok, "confirming a puzzle should request gameplay")
	if ok {
		testing.expect_value(t, gameplay.puzzle_index, PUZZLE_COLUMNS)
	}
}

@(test)
given_puzzle_selection_is_open_when_back_is_pressed_then_main_menu_is_requested :: proc(
	t: ^testing.T,
) {
	state := puzzle_test_state(t)

	navigation := update_puzzle_select(&state, {shared.Key_Input{.Back}})
	_, ok := navigation.(core.Go_Main_Menu)

	testing.expect(t, ok, "Back should request the main menu")
}

@(test)
given_back_button_is_focused_when_confirm_is_pressed_then_main_menu_is_requested :: proc(
	t: ^testing.T,
) {
	state := puzzle_test_state(t)

	// Move down until focus reaches the Back button.
	for state.ix.focus != state.back_node {
		_ = update_puzzle_select(&state, {shared.Key_Input{.Down}})
	}

	navigation := update_puzzle_select(&state, {shared.Key_Input{.Confirm}})
	_, ok := navigation.(core.Go_Main_Menu)

	testing.expect(t, ok, "confirming the Back button should request the main menu")
}

@(test)
given_a_puzzle_card_is_clicked_when_released_on_the_same_card_then_it_opens :: proc(
	t: ^testing.T,
) {
	state := puzzle_test_state(t)
	position := puzzle_test_card_position(&state, 0)

	_ = update_puzzle_select(&state, {shared.Mouse_Input{position = position, pressed = true}})
	navigation := update_puzzle_select(
		&state,
		{shared.Mouse_Input{position = position, released = true}},
	)
	gameplay, ok := navigation.(core.Go_Gameplay)

	testing.expect(t, ok, "clicking a puzzle card should request gameplay")
	if ok {
		testing.expect_value(t, gameplay.puzzle_index, 0)
	}
}

@(test)
given_a_card_is_pressed_when_released_over_another_card_then_no_puzzle_opens :: proc(
	t: ^testing.T,
) {
	state := puzzle_test_state(t)
	first := puzzle_test_card_position(&state, 0)
	second := puzzle_test_card_position(&state, 1)

	_ = update_puzzle_select(&state, {shared.Mouse_Input{position = first, pressed = true}})
	navigation := update_puzzle_select(
		&state,
		{shared.Mouse_Input{position = second, released = true}},
	)

	testing.expect(t, navigation == nil, "releasing on a different card should cancel the click")
}

@(test)
given_back_button_is_clicked_when_released_on_it_then_main_menu_is_requested :: proc(
	t: ^testing.T,
) {
	state := puzzle_test_state(t)
	position := puzzle_test_back_position(&state)

	_ = update_puzzle_select(&state, {shared.Mouse_Input{position = position, pressed = true}})
	navigation := update_puzzle_select(
		&state,
		{shared.Mouse_Input{position = position, released = true}},
	)
	_, ok := navigation.(core.Go_Main_Menu)

	testing.expect(t, ok, "clicking Back should request the main menu")
}
