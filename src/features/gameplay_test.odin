package features

import "../core"
import "../shared"
import "core:testing"

// ============================================================================
// BDD scenarios for the Transformation screen.
// Reference design: 1440x900, "THE ART OF ISOLATION", round 07/10.
// Renderer is faked: no window, no raylib (same approach as puzzle_selection_test).
// ============================================================================

@(private = "file")
gp_text: [512]string
@(private = "file")
gp_text_count: int

@(private = "file")
gp_capture_text :: proc(text: string, _: shared.Vec2, _: i32, _: shared.Color, _: shared.Font_Id) {
	if gp_text_count < len(gp_text) {
		gp_text[gp_text_count] = text
		gp_text_count += 1
	}
}

// Fill/outline/texture are called by core.ui_draw for every node, so they must not be nil.
// (Signatures inferred from the call sites in ui_draw.odin.)
@(private = "file")
gp_context :: proc() -> Context {
	return {
		viewport = shared.viewport_of(1440, 900),
		renderer = {
			measure_text = puzzle_test_measure_text,
			draw_text = gp_capture_text,
			fill_rect = proc(_: shared.Rect, _: shared.Color) {  },
			outline_rect = proc(_: shared.Rect, _: f32, _: shared.Color) {  },
			draw_texture = proc(_: shared.Texture_Id, _: shared.Rect, _: shared.Color) {  },
		},
	}
}

@(private = "file")
gp_puzzle :: proc() -> Puzzle {
	return {
		title           = "THE ART OF ISOLATION",
		brief           = "Preserve equivalence. Transform the formula into its final form.",
		category        = "ALGEBRA",
		start           = "3(x − 4) + 8 = 2x + 17",
		goal            = "x = 21",
		objective       = "ISOLATE THE UNKNOWN",
		rule            = "One variable. One value. No extra terms.",
		// The reference screenshot cuts this copy off; placeholder until the design is confirmed.
		completion_rule = "x alone on the left, equal to a number.",
	}
}

@(private = "file")
gp_run :: proc() -> Run_Info {
	return {
		mode = "ARCANE TRIALS",
		tier = .Easy,
		round = 7,
		rounds_total = 10,
		score = 4280,
		streak = 6,
	}
}

@(private = "file")
gp_open :: proc(t: ^testing.T, ctx: ^Context) -> Gameplay_State {
	state := init_gameplay(ctx, gp_puzzle(), gp_run())
	testing.expect(t, state.tree.count > 0, "gameplay should build its UI tree")
	return state
}

@(private = "file")
gp_key :: proc(s: ^Gameplay_State, key: shared.Nav_Key) -> core.Navigation {
	return update_gameplay(s, {shared.Key_Input{key}})
}

@(private = "file")
gp_center :: proc(s: ^Gameplay_State, node: int) -> shared.Vec2 {
	rect := s.tree.nodes[node].rect
	return {(rect.x + rect.w / 2) * s.viewport.scale, (rect.y + rect.h / 2) * s.viewport.scale}
}

@(private = "file")
gp_click :: proc(s: ^Gameplay_State, node: int) -> core.Navigation {
	p := gp_center(s, node)
	_ = update_gameplay(s, {shared.Mouse_Input{position = p, pressed = true}})
	return update_gameplay(s, {shared.Mouse_Input{position = p, released = true}})
}

@(private = "file")
gp_tick :: proc(s: ^Gameplay_State, dt: f32) {
	_ = update_gameplay(s, {shared.Tick_Input{dt = dt}})
}

// Distribute 3 → Combine constants, using the keyboard (Confirm applies the selected move).
@(private = "file")
gp_reach_reference_state :: proc(s: ^Gameplay_State) {
	_ = gp_key(s, .Confirm)
	_ = gp_key(s, .Confirm)
}

@(private = "file")
gp_draw :: proc(s: ^Gameplay_State, ctx: Context) {
	gp_text_count = 0
	draw_gameplay(s, ctx)
}

@(private = "file")
gp_count :: proc(want: string) -> (n: int) {
	for text in gp_text[:gp_text_count] {
		if text == want { n += 1 }
	}
	return
}

@(private = "file")
gp_has :: proc(want: string) -> bool {
	return gp_count(want) > 0
}

// `want` must appear in this order (other text may be interleaved).
@(private = "file")
gp_has_in_order :: proc(want: []string) -> bool {
	next := 0
	for text in gp_text[:gp_text_count] {
		if next < len(want) && text == want[next] { next += 1 }
	}
	return next == len(want)
}

@(private = "file")
gp_expect_all :: proc(t: ^testing.T, wants: []string, loc := #caller_location) {
	for want in wants {
		testing.expectf(t, gp_has(want), "screen should draw %q", want, loc = loc)
	}
}

// ============================================================================
// Feature: opening the screen
// ============================================================================

// @(test)
// given_a_run_when_gameplay_opens_then_the_top_bar_shows_mode_round_score_streak_and_time :: proc(
// 	t: ^testing.T,
// ) {
// 	ctx := gp_context()
// 	state := gp_open(t, &ctx)

// 	gp_draw(&state, ctx)

// 	gp_expect_all(t, {"ARCANE TRIALS / ADEPT", "ROUND 07 / 10", "70%", "04,280", "× 6", "00:00"})
// 	gp_expect_all(t, {"SCORE", "STREAK", "TIME"})
// }

// @(test)
// given_a_puzzle_when_gameplay_opens_then_title_brief_and_category_tabs_are_shown :: proc(
// 	t: ^testing.T,
// ) {
// 	ctx := gp_context()
// 	state := gp_open(t, &ctx)

// 	gp_draw(&state, ctx)

// 	gp_expect_all(
// 		t,
// 		{
// 			"THE ART OF ISOLATION",
// 			"Preserve equivalence. Transform the formula into its final form.",
// 		},
// 	)
// 	testing.expect(
// 		t,
// 		gp_has_in_order({"ALGEBRA", "ARITHMETIC", "LOGIC", "PHYSICS"}),
// 		"the four category tabs should appear in design order",
// 	)
// }

// @(test)
// given_the_start_formula_when_gameplay_opens_then_the_panels_show_the_initial_state :: proc(
// 	t: ^testing.T,
// ) {
// 	ctx := gp_context()
// 	state := gp_open(t, &ctx)

// 	gp_draw(&state, ctx)

// 	gp_expect_all(
// 		t,
// 		{
// 			"VALID TRANSFORMATIONS",
// 			"1 valid move · whole equation",
// 			"Distribute 3",
// 			"CURRENT FORMULA",
// 			"STEP 00",
// 			"SCOPE: EQUATION",
// 			"Select a term to inspect its valid transformations.",
// 			"TRANSFORMATION HISTORY",
// 			"Every step, preserved.",
// 			"0 MOVES",
// 			"Initial formula",
// 			"STARTING STATE",
// 			"Original equation from the codex.",
// 			"APPLY TRANSFORM",
// 			"UNDO LAST",
// 			"RESTART",
// 		},
// 	)
// 	testing.expect(
// 		t,
// 		gp_has_in_order({"3", "(", "x", "−", "4", ")", "+", "8", "=", "2", "x", "+", "17"}),
// 		"formula tiles should read 3 ( x − 4 ) + 8 = 2 x + 17",
// 	)
// }

// @(test)
// given_a_puzzle_when_gameplay_opens_then_the_end_goal_card_shows_the_target :: proc(t: ^testing.T) {
// 	ctx := gp_context()
// 	state := gp_open(t, &ctx)

// 	gp_draw(&state, ctx)

// 	gp_expect_all(
// 		t,
// 		{
// 			"END GOAL",
// 			"ISOLATE THE UNKNOWN",
// 			"One variable. One value. No extra terms.",
// 			"x = 21",
// 			"TARGET STATE",
// 			"COMPLETION RULE",
// 			"x alone on the left, equal to a number.",
// 		},
// 	)
// }

// @(test)
// given_gameplay_opens_when_laid_out_then_the_three_panels_sit_left_center_right :: proc(
// 	t: ^testing.T,
// ) {
// 	ctx := gp_context()
// 	state := gp_open(t, &ctx)
// 	nodes := state.tree.nodes

// 	moves_x := nodes[state.move_nodes[0]].rect.x
// 	apply := nodes[state.apply_node].rect
// 	undo_x := nodes[state.undo_node].rect.x

// 	testing.expect(t, moves_x < apply.x, "move cards are left of the formula panel")
// 	testing.expect(t, apply.x < undo_x, "history controls are right of the formula panel")
// 	testing.expect(t, apply.x + apply.w <= 1440, "Apply stays inside the 1440 design width")
// }

// // ============================================================================
// // Feature: the reference screen (after Distribute 3 → Combine constants)
// // ============================================================================

// @(test)
// given_two_moves_were_applied_when_the_screen_draws_then_it_matches_the_reference_design :: proc(
// 	t: ^testing.T,
// ) {
// 	ctx := gp_context()
// 	state := gp_open(t, &ctx)
// 	gp_reach_reference_state(&state)

// 	gp_draw(&state, ctx)

// 	// Top of the center panel + header counters.
// 	gp_expect_all(t, {"STEP 02", "2 MOVES", "SCOPE: EQUATION"})
// 	testing.expect(
// 		t,
// 		gp_has_in_order({"3", "x", "−", "4", "=", "2", "x", "+", "17"}),
// 		"formula tiles should read 3 x − 4 = 2 x + 17",
// 	)

// 	// Left panel: three cards.
// 	gp_expect_all(
// 		t,
// 		{
// 			"3 valid moves · whole equation",
// 			"Subtract 2x",
// 			"3x − 4 − 2x = 2x + 17 − 2x",
// 			"Cancel the variable on the right.",
// 			"Add 4",
// 			"3x − 4 + 4 = 2x + 17 + 4",
// 			"Remove the constant on the left.",
// 			"Subtract 17",
// 			"3x − 4 − 17 = 2x + 17 − 17",
// 			"Move the right-hand constant.",
// 			"RECOMMENDED",
// 			"SELECTED",
// 			"02",
// 			"03",
// 		},
// 	)

// 	// Preview block for the selected (recommended) move.
// 	gp_expect_all(
// 		t,
// 		{
// 			"AFTER SUBTRACTING 2x",
// 			"x − 4 = 17",
// 			"Equivalent for every x ∈ ℝ",
// 			"Preview only · history updates after applying",
// 		},
// 	)

// 	// Right panel: three history cards.
// 	gp_expect_all(
// 		t,
// 		{
// 			"Initial formula",
// 			"STARTING STATE",
// 			"3(x − 4) + 8 = 2x + 17",
// 			"Distribute 3",
// 			"APPLIED",
// 			"3x − 12 + 8 = 2x + 17",
// 			"3(x − 4) becomes 3x − 12.",
// 			"Combine constants",
// 			"CURRENT",
// 			"−12 + 8 becomes −4.",
// 			"00",
// 			"01",
// 		},
// 	)
// }

// @(test)
// given_the_reference_screen_when_drawn_then_exactly_one_card_is_selected_and_one_is_current :: proc(
// 	t: ^testing.T,
// ) {
// 	ctx := gp_context()
// 	state := gp_open(t, &ctx)
// 	gp_reach_reference_state(&state)

// 	gp_draw(&state, ctx)

// 	testing.expect_value(t, gp_count("SELECTED"), 1)
// 	testing.expect_value(t, gp_count("RECOMMENDED"), 1)
// 	testing.expect_value(t, gp_count("CURRENT"), 1)
// 	testing.expect_value(t, gp_count("STARTING STATE"), 1)
// }

// // ============================================================================
// // Feature: choosing a move (preview, never commits)
// // ============================================================================

// @(test)
// given_the_reference_state_when_down_is_pressed_then_the_next_move_is_previewed_not_applied :: proc(
// 	t: ^testing.T,
// ) {
// 	ctx := gp_context()
// 	state := gp_open(t, &ctx)
// 	gp_reach_reference_state(&state)

// 	navigation := gp_key(&state, .Down)
// 	gp_draw(&state, ctx)

// 	testing.expect(t, navigation == nil, "choosing a move should not navigate")
// 	testing.expect_value(t, state.workspace.selected_move, 1)
// 	testing.expect_value(t, workspace_step(&state.workspace), 2)
// 	testing.expect(t, gp_has("AFTER ADDING 4"), "preview heading follows the selection")
// 	testing.expect(t, gp_has("3x = 2x + 21"), "preview shows the simplified result")
// 	testing.expect_value(t, gp_count("SELECTED"), 1)
// }

// @(test)
// given_the_first_move_is_selected_when_up_is_pressed_then_selection_wraps_to_the_last :: proc(
// 	t: ^testing.T,
// ) {
// 	ctx := gp_context()
// 	state := gp_open(t, &ctx)
// 	gp_reach_reference_state(&state)

// 	_ = gp_key(&state, .Up)

// 	testing.expect_value(t, state.workspace.selected_move, 2)
// }

// @(test)
// given_a_move_card_is_clicked_when_released_on_the_same_card_then_it_is_selected_not_applied :: proc(
// 	t: ^testing.T,
// ) {
// 	ctx := gp_context()
// 	state := gp_open(t, &ctx)
// 	gp_reach_reference_state(&state)

// 	navigation := gp_click(&state, state.move_nodes[2])

// 	testing.expect(t, navigation == nil, "selecting a card should not navigate")
// 	testing.expect_value(t, state.workspace.selected_move, 2)
// 	testing.expect_value(t, workspace_step(&state.workspace), 2)
// }

// @(test)
// given_a_card_is_pressed_when_released_over_another_card_then_the_selection_is_unchanged :: proc(
// 	t: ^testing.T,
// ) {
// 	ctx := gp_context()
// 	state := gp_open(t, &ctx)
// 	gp_reach_reference_state(&state)
// 	first := gp_center(&state, state.move_nodes[0])
// 	third := gp_center(&state, state.move_nodes[2])

// 	_ = update_gameplay(&state, {shared.Mouse_Input{position = first, pressed = true}})
// 	_ = update_gameplay(&state, {shared.Mouse_Input{position = third, released = true}})

// 	testing.expect_value(t, state.workspace.selected_move, 0)
// }

// // ============================================================================
// // Feature: applying a transform
// // ============================================================================

// @(test)
// given_a_selected_move_when_confirm_is_pressed_then_it_is_applied_and_history_grows :: proc(
// 	t: ^testing.T,
// ) {
// 	ctx := gp_context()
// 	state := gp_open(t, &ctx)
// 	gp_reach_reference_state(&state)

// 	navigation := gp_key(&state, .Confirm) // Subtract 2x
// 	gp_draw(&state, ctx)

// 	testing.expect(t, navigation == nil, "applying should not navigate")
// 	testing.expect_value(t, workspace_step(&state.workspace), 3)
// 	gp_expect_all(t, {"STEP 03", "3 MOVES", "Subtract 2x", "x − 4 = 17"})
// }

// @(test)
// given_the_apply_button_is_clicked_when_released_on_it_then_the_selected_move_is_applied :: proc(
// 	t: ^testing.T,
// ) {
// 	ctx := gp_context()
// 	state := gp_open(t, &ctx)

// 	_ = gp_click(&state, state.apply_node) // Distribute 3

// 	testing.expect_value(t, workspace_step(&state.workspace), 1)
// 	gp_draw(&state, ctx)
// 	gp_expect_all(t, {"STEP 01", "1 MOVE", "3x − 12 + 8 = 2x + 17"})
// }

// @(test)
// given_the_apply_button_is_pressed_when_released_elsewhere_then_nothing_is_applied :: proc(
// 	t: ^testing.T,
// ) {
// 	ctx := gp_context()
// 	state := gp_open(t, &ctx)
// 	press := gp_center(&state, state.apply_node)
// 	elsewhere := gp_center(&state, state.undo_node)

// 	_ = update_gameplay(&state, {shared.Mouse_Input{position = press, pressed = true}})
// 	_ = update_gameplay(&state, {shared.Mouse_Input{position = elsewhere, released = true}})

// 	testing.expect_value(t, workspace_step(&state.workspace), 0)
// }

// // ============================================================================
// // Feature: inspecting a term (scope)
// // ============================================================================

// @(test)
// given_the_reference_state_when_a_tile_is_clicked_then_scope_becomes_the_term_and_moves_narrow :: proc(
// 	t: ^testing.T,
// ) {
// 	ctx := gp_context()
// 	state := gp_open(t, &ctx)
// 	gp_reach_reference_state(&state)

// 	_ = gp_click(&state, state.tile_nodes[3]) // the "4" of −4
// 	gp_draw(&state, ctx)

// 	testing.expect_value(t, state.workspace.moves.count, 1)
// 	gp_expect_all(t, {"SCOPE: TERM", "1 valid move · selected term", "Add 4"})
// 	testing.expect_value(t, gp_count("Subtract 2x"), 0)
// }

// @(test)
// given_a_term_is_selected_when_the_same_tile_is_clicked_again_then_scope_returns_to_the_equation :: proc(
// 	t: ^testing.T,
// ) {
// 	ctx := gp_context()
// 	state := gp_open(t, &ctx)
// 	gp_reach_reference_state(&state)
// 	_ = gp_click(&state, state.tile_nodes[3])

// 	_ = gp_click(&state, state.tile_nodes[3])
// 	gp_draw(&state, ctx)

// 	testing.expect_value(t, state.workspace.moves.count, 3)
// 	gp_expect_all(t, {"SCOPE: EQUATION", "3 valid moves · whole equation"})
// }

// @(test)
// given_an_operator_tile_when_clicked_then_scope_does_not_change :: proc(t: ^testing.T) {
// 	ctx := gp_context()
// 	state := gp_open(t, &ctx)
// 	gp_reach_reference_state(&state)

// 	_ = gp_click(&state, state.tile_nodes[2]) // the "−" operator
// 	_ = gp_click(&state, state.tile_nodes[4]) // the "="

// 	testing.expect(t, state.workspace.selection == nil, "operators are not selectable terms")
// 	testing.expect_value(t, state.workspace.moves.count, 3)
// }

// // ============================================================================
// // Feature: undo and restart
// // ============================================================================

// @(test)
// given_two_moves_applied_when_undo_last_is_clicked_then_only_the_last_move_is_removed :: proc(
// 	t: ^testing.T,
// ) {
// 	ctx := gp_context()
// 	state := gp_open(t, &ctx)
// 	gp_reach_reference_state(&state)

// 	_ = gp_click(&state, state.undo_node)
// 	gp_draw(&state, ctx)

// 	testing.expect_value(t, workspace_step(&state.workspace), 1)
// 	gp_expect_all(t, {"STEP 01", "1 MOVE", "3x − 12 + 8 = 2x + 17"})
// 	testing.expect_value(t, gp_count("Combine constants"), 1) // the move card; its history card is gone
// }

// @(test)
// given_two_moves_applied_when_the_undo_key_is_pressed_then_the_last_move_is_removed :: proc(
// 	t: ^testing.T,
// ) {
// 	ctx := gp_context()
// 	state := gp_open(t, &ctx)
// 	gp_reach_reference_state(&state)

// 	_ = gp_key(&state, .Undo)

// 	testing.expect_value(t, workspace_step(&state.workspace), 1)
// }

// @(test)
// given_no_moves_applied_when_undo_is_pressed_then_nothing_changes :: proc(t: ^testing.T) {
// 	ctx := gp_context()
// 	state := gp_open(t, &ctx)

// 	_ = gp_key(&state, .Undo)
// 	_ = gp_click(&state, state.undo_node)

// 	testing.expect_value(t, workspace_step(&state.workspace), 0)
// }

// @(test)
// given_two_moves_applied_when_restart_is_clicked_then_the_start_formula_returns :: proc(
// 	t: ^testing.T,
// ) {
// 	ctx := gp_context()
// 	state := gp_open(t, &ctx)
// 	gp_reach_reference_state(&state)

// 	_ = gp_click(&state, state.restart_node)
// 	gp_draw(&state, ctx)

// 	testing.expect_value(t, workspace_step(&state.workspace), 0)
// 	gp_expect_all(t, {"STEP 00", "0 MOVES", "1 valid move · whole equation"})
// }

// // ============================================================================
// // Feature: the clock and pause
// // ============================================================================

// @(test)
// given_the_clock_is_running_when_ticks_arrive_then_time_advances_in_whole_seconds :: proc(
// 	t: ^testing.T,
// ) {
// 	ctx := gp_context()
// 	state := gp_open(t, &ctx)

// 	gp_tick(&state, 12.4)
// 	gp_tick(&state, 12.4)
// 	gp_draw(&state, ctx)

// 	gp_expect_all(t, {"00:24"})
// }

// @(test)
// given_the_pause_button_is_clicked_when_ticks_arrive_then_time_does_not_advance :: proc(
// 	t: ^testing.T,
// ) {
// 	ctx := gp_context()
// 	state := gp_open(t, &ctx)
// 	gp_tick(&state, 5)

// 	_ = gp_click(&state, state.pause_node)
// 	gp_tick(&state, 10)

// 	testing.expect(t, state.paused, "the pause button pauses")
// 	testing.expect_value(t, state.elapsed, f32(5))
// }

// @(test)
// given_the_game_is_paused_when_pause_is_pressed_again_then_the_clock_resumes :: proc(
// 	t: ^testing.T,
// ) {
// 	ctx := gp_context()
// 	state := gp_open(t, &ctx)
// 	_ = gp_key(&state, .Pause)

// 	_ = gp_key(&state, .Pause)
// 	gp_tick(&state, 3)

// 	testing.expect(t, !state.paused, "second press resumes")
// 	testing.expect_value(t, state.elapsed, f32(3))
// }

// @(test)
// given_the_game_is_paused_when_confirm_is_pressed_then_no_move_is_applied :: proc(t: ^testing.T) {
// 	ctx := gp_context()
// 	state := gp_open(t, &ctx)
// 	_ = gp_key(&state, .Pause)

// 	_ = gp_key(&state, .Confirm)
// 	_ = gp_click(&state, state.apply_node)

// 	testing.expect_value(t, workspace_step(&state.workspace), 0)
// }

// // ============================================================================
// // Feature: solving the puzzle
// // ============================================================================

// @(test)
// given_the_reference_state_when_subtract_2x_and_add_4_are_applied_then_the_puzzle_is_solved_and_the_clock_stops :: proc(
// 	t: ^testing.T,
// ) {
// 	ctx := gp_context()
// 	state := gp_open(t, &ctx)
// 	gp_reach_reference_state(&state)
// 	gp_tick(&state, 24)

// 	_ = gp_key(&state, .Confirm) // Subtract 2x
// 	_ = gp_key(&state, .Confirm) // Add 4
// 	gp_tick(&state, 10)
// 	gp_draw(&state, ctx)

// 	testing.expect(t, workspace_solved(&state.workspace), "x = 21 solves the puzzle")
// 	testing.expect_value(t, state.elapsed, f32(24))
// 	gp_expect_all(t, {"STEP 04", "4 MOVES", "00:24", "0 valid moves · whole equation"})
// }

// @(test)
// given_a_solved_puzzle_when_confirm_is_pressed_then_nothing_more_is_applied :: proc(t: ^testing.T) {
// 	ctx := gp_context()
// 	state := gp_open(t, &ctx)
// 	gp_reach_reference_state(&state)
// 	_ = gp_key(&state, .Confirm)
// 	_ = gp_key(&state, .Confirm)

// 	navigation := gp_key(&state, .Confirm)

// 	testing.expect(t, navigation == nil, "no auto-navigation on solve yet (open question)")
// 	testing.expect_value(t, workspace_step(&state.workspace), 4)
// }

// // ============================================================================
// // Feature: leaving the screen
// // ============================================================================

// @(test)
// given_gameplay_is_open_when_back_is_pressed_then_level_select_is_requested :: proc(t: ^testing.T) {
// 	ctx := gp_context()
// 	state := gp_open(t, &ctx)

// 	navigation := gp_key(&state, .Back)
// 	_, ok := navigation.(core.Go_Level_Select)

// 	testing.expect(t, ok, "Back should request level select")
// }

// // ============================================================================
// // Feature: resizing keeps the screen interactive
// // ============================================================================

// @(test)
// given_the_window_is_resized_when_a_card_is_clicked_at_the_new_scale_then_it_is_selected :: proc(
// 	t: ^testing.T,
// ) {
// 	ctx := gp_context()
// 	state := gp_open(t, &ctx)
// 	gp_reach_reference_state(&state)
// 	ctx.viewport = shared.viewport_of(1920, 1080)
// 	state.viewport = ctx.viewport
// 	layout_gameplay(&state, &ctx)

// 	_ = gp_click(&state, state.move_nodes[1])

// 	testing.expect_value(t, state.workspace.selected_move, 1)
// }
