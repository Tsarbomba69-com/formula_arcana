package features

import "../core"
import "../shared"
import "core:testing"

// ============================================================================
// BDD scenarios for the Transformation screen.
// Reference design: 1440x900, "THE ART OF ISOLATION", round 07/10.
// Renderer is faked: no window, no raylib (same approach as puzzle_selection_test).
// ============================================================================

Gameplay_Test_Capture :: struct {
	text:  [512]string,
	count: int,
	// Owned copies of every captured string. The screen formats many labels
	// ("ROUND 07 / 10", "STEP 00", ...) into short-lived stack buffers and hands
	// the renderer a slice of that buffer. Keeping only the slice would leave it
	// pointing at memory that is overwritten or dead by the time the test reads it.
	bytes: [32768]u8,
	used:  int,
}

@(private = "file")
gp_capture_text :: proc(text: string, _: shared.Vec2, _: i32, _: shared.Color, _: shared.Font_Id) {
	capture := (^Gameplay_Test_Capture)(context.user_ptr)
	if capture == nil || capture.count >= len(capture.text) { return }
	if capture.used + len(text) > len(capture.bytes) { return }

	start := capture.used
	copy(capture.bytes[start:], text)
	capture.used += len(text)
	capture.text[capture.count] = string(capture.bytes[start:capture.used])
	capture.count += 1
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
	_ = gp_click(s, s.tile_nodes[0]) // select the grouped term to distribute
	_ = gp_key(s, .Confirm)
	_ = gp_click(s, s.tile_nodes[3]) // select a constant for combining
	_ = gp_key(s, .Confirm)
}

@(private = "file")
gp_draw :: proc(s: ^Gameplay_State, ctx: Context, capture: ^Gameplay_Test_Capture) {
	capture.count = 0
	capture.used = 0
	previous_user_ptr := context.user_ptr
	context.user_ptr = rawptr(capture)
	defer context.user_ptr = previous_user_ptr
	draw_gameplay(s, ctx)
}

@(private = "file")
gp_count :: proc(capture: ^Gameplay_Test_Capture, want: string) -> (n: int) {
	for text in capture.text[:capture.count] {
		if text == want { n += 1 }
	}
	return
}

@(private = "file")
gp_has :: proc(capture: ^Gameplay_Test_Capture, want: string) -> bool {
	return gp_count(capture, want) > 0
}

// `want` must appear in this order (other text may be interleaved).
@(private = "file")
gp_has_in_order :: proc(capture: ^Gameplay_Test_Capture, want: []string) -> bool {
	next := 0
	for text in capture.text[:capture.count] {
		if next < len(want) && text == want[next] { next += 1 }
	}
	return next == len(want)
}

@(private = "file")
gp_expect_all :: proc(
	t: ^testing.T,
	capture: ^Gameplay_Test_Capture,
	wants: []string,
	loc := #caller_location,
) {
	for want in wants {
		testing.expectf(t, gp_has(capture, want), "screen should draw %q", want, loc = loc)
	}
}

// ============================================================================
// Feature: opening the screen
// ============================================================================

@(test)
given_a_run_when_gameplay_opens_then_the_top_bar_shows_mode_round_score_streak_and_time :: proc(
	t: ^testing.T,
) {
	ctx := gp_context()
	state := gp_open(t, &ctx)
	capture: Gameplay_Test_Capture

	gp_draw(&state, ctx, &capture)

	gp_expect_all(
		t,
		&capture,
		{"ARCANE TRIALS / Easy", "ROUND 07 / 10", "70%", "04,280", "× 6", "00:00"},
	)
	gp_expect_all(t, &capture, {"SCORE", "STREAK", "TIME"})
}

@(test)
given_a_puzzle_when_gameplay_opens_then_title_brief_and_category_tabs_are_shown :: proc(
	t: ^testing.T,
) {
	ctx := gp_context()
	state := gp_open(t, &ctx)
	capture: Gameplay_Test_Capture

	gp_draw(&state, ctx, &capture)

	gp_expect_all(
		t,
		&capture,
		{
			"THE ART OF ISOLATION",
			"Preserve equivalence. Transform the formula into its final form.",
		},
	)
	testing.expect(
		t,
		gp_has_in_order(&capture, {"ALGEBRA", "ARITHMETIC", "LOGIC", "PHYSICS"}),
		"the four category tabs should appear in design order",
	)
}

@(test)
given_the_start_formula_when_gameplay_opens_then_the_panels_show_the_initial_state :: proc(
	t: ^testing.T,
) {
	ctx := gp_context()
	state := gp_open(t, &ctx)
	capture: Gameplay_Test_Capture

	gp_draw(&state, ctx, &capture)

	gp_expect_all(
		t,
		&capture,
		{
			"VALID TRANSFORMATIONS",
			"1 valid move · whole equation",
			"Distributive property",
			"CURRENT FORMULA",
			"STEP 00",
			"SCOPE: EQUATION",
			"Select a term or operator to inspect it.",
			"TRANSFORMATION HISTORY",
			"Every step, preserved.",
			"0 MOVES",
			"Initial formula",
			"STARTING STATE",
			"Original equation from the codex.",
			"APPLY TRANSFORM",
			"UNDO LAST",
			"RESTART",
		},
	)
	testing.expect(
		t,
		gp_has_in_order(
			&capture,
			{"3", "(", "x", "−", "4", ")", "+", "8", "=", "2", "x", "+", "17"},
		),
		"formula tiles should read 3 ( x − 4 ) + 8 = 2 x + 17",
	)
}

@(test)
given_a_puzzle_when_gameplay_opens_then_the_end_goal_card_shows_the_target :: proc(t: ^testing.T) {
	ctx := gp_context()
	state := gp_open(t, &ctx)
	capture: Gameplay_Test_Capture

	gp_draw(&state, ctx, &capture)

	gp_expect_all(
		t,
		&capture,
		{
			"END GOAL",
			"ISOLATE THE UNKNOWN",
			"One variable. One value. No extra terms.",
			"x = 21",
			"TARGET STATE",
			"COMPLETION RULE",
			"x alone on the left, equal to a number.",
		},
	)
}

@(test)
given_gameplay_opens_when_laid_out_then_the_three_panels_sit_left_center_right :: proc(
	t: ^testing.T,
) {
	ctx := gp_context()
	state := gp_open(t, &ctx)
	nodes := state.tree.nodes

	moves_x := nodes[state.move_nodes[0]].rect.x
	apply := nodes[state.apply_node].rect
	undo_x := nodes[state.undo_node].rect.x

	testing.expect(t, moves_x < apply.x, "move cards are left of the formula panel")
	testing.expect(t, apply.x < undo_x, "history controls are right of the formula panel")
	testing.expect(t, apply.x + apply.w <= 1440, "Apply stays inside the 1440 design width")
}

@(test)
given_the_transformation_list_overflows_when_the_wheel_moves_over_it_then_its_cards_scroll :: proc(
	t: ^testing.T,
) {
	ctx := gp_context()
	state := gp_open(t, &ctx)
	state.workspace.moves.count = 8
	layout_gameplay(&state, &ctx)
	view := gp_moves_view_rect(state.origin_x)
	position := shared.Vec2{view.x + view.w / 2, view.y + view.h / 2} * state.viewport.scale

	_ = update_gameplay(&state, {shared.Mouse_Input{position = position, wheel = -1}})

	testing.expect(
		t,
		state.moves_scroll_y > 0,
		"wheel input should advance the transformation list",
	)
	testing.expect(
		t,
		state.tree.nodes[state.move_nodes[0]].rect.y < gp_move_card_rect(state.origin_x, 0, 8).y,
		"scrolled transformation card geometry should move upward",
	)
}

@(test)
given_the_history_overflows_when_the_wheel_moves_over_it_then_history_scrolls_independently :: proc(
	t: ^testing.T,
) {
	ctx := gp_context()
	state := gp_open(t, &ctx)
	state.workspace.entry_count = 8
	layout_gameplay(&state, &ctx)
	view := gp_history_view_rect(state.origin_x)
	position := shared.Vec2{view.x + view.w / 2, view.y + view.h / 2} * state.viewport.scale

	_ = update_gameplay(&state, {shared.Mouse_Input{position = position, wheel = -1}})

	testing.expect(t, state.history_scroll_y > 0, "wheel input should advance the history panel")
	testing.expect_value(t, state.moves_scroll_y, 0)
}

@(test)
given_the_history_has_a_scrollbar_when_its_thumb_is_dragged_then_the_history_offset_changes :: proc(
	t: ^testing.T,
) {
	ctx := gp_context()
	state := gp_open(t, &ctx)
	state.workspace.entry_count = 8
	layout_gameplay(&state, &ctx)
	view := gp_history_view_rect(state.origin_x)
	track_x := view.x + view.w - 7
	start := shared.Vec2{track_x, view.y + 20} * state.viewport.scale
	finish := shared.Vec2{track_x, view.y + view.h - 20} * state.viewport.scale

	_ = update_gameplay(
		&state,
		{shared.Mouse_Input{position = start, pressed = true, down = true}},
	)
	_ = update_gameplay(&state, {shared.Mouse_Input{position = finish, down = true}})
	_ = update_gameplay(&state, {shared.Mouse_Input{position = finish, released = true}})

	testing.expect(
		t,
		state.history_scroll_y > 0,
		"dragging the history thumb should change its offset",
	)
}

// ============================================================================
// Feature: the reference screen (after Distribute 3 → Combine constants)
// ============================================================================

@(test)
given_two_moves_were_applied_when_the_screen_draws_then_it_matches_the_reference_design :: proc(
	t: ^testing.T,
) {
	ctx := gp_context()
	state := gp_open(t, &ctx)
	gp_reach_reference_state(&state)
	capture: Gameplay_Test_Capture
	gp_draw(&state, ctx, &capture)

	// Top of the center panel + header counters.
	gp_expect_all(t, &capture, {"STEP 02", "2 MOVES", "SCOPE: EQUATION"})
	testing.expect(
		t,
		gp_has_in_order(&capture, {"3", "x", "−", "4", "=", "2", "x", "+", "17"}),
		"formula tiles should read 3 x − 4 = 2 x + 17",
	)

	// Left panel: three cards.
	gp_expect_all(
		t,
		&capture,
		{
			"3 valid moves · whole equation",
			"Subtract 2x",
			"a = b  →  a − c = b − c",
			"Cancel the variable on the right.",
			"Add 4",
			"a = b  →  a + c = b + c",
			"Remove the constant on the left.",
			"Subtract 17",
			"a = b  →  a − c = b − c",
			"Move the right-hand constant.",
			"RECOMMENDED",
			"SELECTED",
			"02",
			"03",
		},
	)

	// Preview block for the selected (recommended) move.
	gp_expect_all(
		t,
		&capture,
		{
			"AFTER SUBTRACTING 2x",
			"x − 4 = 17",
			"Equivalent for every x ∈ ℝ",
			"Preview only · history updates after applying",
		},
	)

	// Right panel: three history cards.
	gp_expect_all(
		t,
		&capture,
		{
			"Initial formula",
			"STARTING STATE",
			"3(x − 4) + 8 = 2x + 17",
			"Distribute 3",
			"APPLIED",
			"3x − 12 + 8 = 2x + 17",
			"3(x − 4) becomes 3x − 12.",
			"Combine constants",
			"CURRENT",
			"−12 + 8 becomes −4.",
			"00",
			"01",
		},
	)
}

@(test)
given_the_reference_screen_when_drawn_then_exactly_one_card_is_selected_and_one_is_current :: proc(
	t: ^testing.T,
) {
	ctx := gp_context()
	state := gp_open(t, &ctx)
	gp_reach_reference_state(&state)
	capture: Gameplay_Test_Capture
	gp_draw(&state, ctx, &capture)

	testing.expect_value(t, gp_count(&capture, "SELECTED"), 1)
	testing.expect_value(t, gp_count(&capture, "RECOMMENDED"), 1)
	testing.expect_value(t, gp_count(&capture, "CURRENT"), 1)
	testing.expect_value(t, gp_count(&capture, "STARTING STATE"), 1)
}

// ============================================================================
// Feature: choosing a move (preview, never commits)
// ============================================================================

@(test)
given_the_reference_state_when_down_is_pressed_then_the_next_move_is_previewed_not_applied :: proc(
	t: ^testing.T,
) {
	ctx := gp_context()
	state := gp_open(t, &ctx)
	gp_reach_reference_state(&state)
	capture: Gameplay_Test_Capture
	navigation := gp_key(&state, .Down)
	gp_draw(&state, ctx, &capture)

	testing.expect(t, navigation == nil, "choosing a move should not navigate")
	testing.expect_value(t, state.workspace.selected_move, 1)
	testing.expect_value(t, workspace_step(&state.workspace), 2)
	testing.expect(t, gp_has(&capture, "AFTER ADDING 4"), "preview heading follows the selection")
	testing.expect(t, gp_has(&capture, "3x = 2x + 21"), "preview shows the simplified result")
	testing.expect_value(t, gp_count(&capture, "SELECTED"), 1)
}

@(test)
given_the_first_move_is_selected_when_up_is_pressed_then_selection_wraps_to_the_last :: proc(
	t: ^testing.T,
) {
	ctx := gp_context()
	state := gp_open(t, &ctx)
	gp_reach_reference_state(&state)

	_ = gp_key(&state, .Up)

	testing.expect_value(t, state.workspace.selected_move, 2)
}

@(test)
given_a_move_card_is_clicked_when_released_on_the_same_card_then_it_is_selected_not_applied :: proc(
	t: ^testing.T,
) {
	ctx := gp_context()
	state := gp_open(t, &ctx)
	gp_reach_reference_state(&state)

	navigation := gp_click(&state, state.move_nodes[2])

	testing.expect(t, navigation == nil, "selecting a card should not navigate")
	testing.expect_value(t, state.workspace.selected_move, 2)
	testing.expect_value(t, workspace_step(&state.workspace), 2)
}

@(test)
given_a_card_is_pressed_when_released_over_another_card_then_the_selection_is_unchanged :: proc(
	t: ^testing.T,
) {
	ctx := gp_context()
	state := gp_open(t, &ctx)
	gp_reach_reference_state(&state)
	first := gp_center(&state, state.move_nodes[0])
	third := gp_center(&state, state.move_nodes[2])

	_ = update_gameplay(&state, {shared.Mouse_Input{position = first, pressed = true}})
	_ = update_gameplay(&state, {shared.Mouse_Input{position = third, released = true}})

	testing.expect_value(t, state.workspace.selected_move, 0)
}

// ============================================================================
// Feature: applying a transform
// ============================================================================

@(test)
given_a_selected_move_when_confirm_is_pressed_then_it_is_applied_and_history_grows :: proc(
	t: ^testing.T,
) {
	ctx := gp_context()
	state := gp_open(t, &ctx)
	gp_reach_reference_state(&state)
	capture: Gameplay_Test_Capture
	_ = gp_click(&state, state.tile_nodes[5]) // select 2x before applying
	navigation := gp_key(&state, .Confirm) // Subtract 2x
	gp_draw(&state, ctx, &capture)

	testing.expect(t, navigation == nil, "applying should not navigate")
	testing.expect_value(t, workspace_step(&state.workspace), 3)
	gp_expect_all(t, &capture, {"STEP 03", "3 MOVES", "Subtract 2x", "x − 4 = 17"})
}

@(test)
given_the_apply_button_is_clicked_when_released_on_it_then_the_selected_move_is_applied :: proc(
	t: ^testing.T,
) {
	ctx := gp_context()
	state := gp_open(t, &ctx)
	capture: Gameplay_Test_Capture
	_ = gp_click(&state, state.tile_nodes[0]) // select the grouped term to distribute
	_ = gp_click(&state, state.apply_node) // Distribute 3

	testing.expect_value(t, workspace_step(&state.workspace), 1)
	gp_draw(&state, ctx, &capture)
	gp_expect_all(t, &capture, {"STEP 01", "1 MOVE", "3x − 12 + 8 = 2x + 17"})
}

@(test)
given_the_apply_button_is_pressed_when_released_elsewhere_then_nothing_is_applied :: proc(
	t: ^testing.T,
) {
	ctx := gp_context()
	state := gp_open(t, &ctx)
	press := gp_center(&state, state.apply_node)
	elsewhere := gp_center(&state, state.undo_node)

	_ = update_gameplay(&state, {shared.Mouse_Input{position = press, pressed = true}})
	_ = update_gameplay(&state, {shared.Mouse_Input{position = elsewhere, released = true}})

	testing.expect_value(t, workspace_step(&state.workspace), 0)
}

// ============================================================================
// Feature: inspecting a term (scope)
// ============================================================================

@(test)
given_any_expression_term_when_selected_then_every_valid_transformation_for_that_term_is_shown :: proc(
	t: ^testing.T,
) {
	ctx := gp_context()
	state := gp_open(t, &ctx)
	capture: Gameplay_Test_Capture
	checked_terms: [MAX_TOKENS]Expr_Id
	checked_count := 0

	for i in 0 ..< state.tile_node_count {
		term := state.tokens.items[i].term
		if term == NO_EXPR { continue }

		already_checked := false
		for checked in checked_terms[:checked_count] {
			if checked == term { already_checked = true; break }
		}
		if already_checked { continue }
		checked_terms[checked_count] = term
		checked_count += 1

		_ = gp_click(&state, state.tile_nodes[i])
		expected := valid_moves(workspace_current(&state.workspace), term)
		testing.expect_value(t, state.workspace.moves.count, expected.count)
		gp_draw(&state, ctx, &capture)
		for move in expected.items[:expected.count] {
			view := describe_move(workspace_current(&state.workspace), move)
			testing.expect(
				t,
				gp_has(&capture, label_str(&view.title)),
				"every valid transformation for a selected expression term should be rendered",
			)
		}
	}
}

@(test)
given_the_distributive_property_is_available_when_the_moves_panel_draws_then_general_addition_and_subtraction_rules_are_shown :: proc(
	t: ^testing.T,
) {
	ctx := gp_context()
	state := gp_open(t, &ctx)
	capture: Gameplay_Test_Capture
	gp_draw(&state, ctx, &capture)

	gp_expect_all(
		t,
		&capture,
		{
			"Distributive property",
			"Addition: a(b + c) = ab + ac",
			"Subtraction: a(b - c) = ab - ac",
		},
	)
}

@(test)
given_no_expression_token_is_selected_when_apply_is_clicked_then_the_formula_and_history_stay_unchanged :: proc(
	t: ^testing.T,
) {
	ctx := gp_context()
	state := gp_open(t, &ctx)

	testing.expect(t, state.workspace.selection == nil, "no token is selected on entry")
	_ = gp_click(&state, state.apply_node)

	testing.expect_value(t, workspace_step(&state.workspace), 0)
	testing.expect_value(t, state.workspace.entry_count, 1)
	buf: [LABEL_CAP * 2]u8
	testing.expect_value(t, format_equation(workspace_current(&state.workspace), buf[:]), START)
}

@(test)
given_the_reference_state_when_a_tile_is_clicked_then_scope_becomes_the_term_and_moves_narrow :: proc(
	t: ^testing.T,
) {
	ctx := gp_context()
	state := gp_open(t, &ctx)
	capture: Gameplay_Test_Capture
	gp_reach_reference_state(&state)

	_ = gp_click(&state, state.tile_nodes[3]) // the "4" of −4
	gp_draw(&state, ctx, &capture)

	testing.expect_value(t, state.workspace.moves.count, 1)
	gp_expect_all(t, &capture, {"SCOPE: TERM", "1 valid move · selected term", "Add 4"})
	testing.expect_value(t, gp_count(&capture, "Subtract 2x"), 0)
}

@(test)
given_a_term_is_selected_when_the_same_tile_is_clicked_again_then_scope_returns_to_the_equation :: proc(
	t: ^testing.T,
) {
	ctx := gp_context()
	state := gp_open(t, &ctx)
	capture: Gameplay_Test_Capture
	gp_reach_reference_state(&state)
	_ = gp_click(&state, state.tile_nodes[3])

	_ = gp_click(&state, state.tile_nodes[3])
	gp_draw(&state, ctx, &capture)

	testing.expect_value(t, state.workspace.moves.count, 3)
	gp_expect_all(t, &capture, {"SCOPE: EQUATION", "3 valid moves · whole equation"})
}

@(test)
given_an_addition_operator_when_clicked_then_it_is_selected_independently_of_its_term :: proc(
	t: ^testing.T,
) {
	ctx := gp_context()
	state := gp_open(t, &ctx)
	capture: Gameplay_Test_Capture
	plus_node := -1
	for i in 0 ..< state.tile_node_count {
		token := state.tokens.items[i]
		if token.kind == .Operator && label_str(&token.text) == "+" {
			plus_node = state.tile_nodes[i]
			break
		}
	}
	testing.expect(t, plus_node >= 0, "the formula should expose its addition operator as a tile")
	if plus_node < 0 { return }

	_ = gp_click(&state, plus_node)
	gp_draw(&state, ctx, &capture)

	testing.expect(t, state.selected_operator >= 0, "the clicked operation should be selected")
	testing.expect(t, state.workspace.selection == nil, "operation selection should not need an expression term id")
	gp_expect_all(t, &capture, {"SCOPE: OPERATION", "Selected operation: + · click again to clear"})

	_ = gp_click(&state, plus_node)
	testing.expect_value(t, state.selected_operator, -1)
}

// ============================================================================
// Feature: undo and restart
// ============================================================================

@(test)
given_two_moves_applied_when_undo_last_is_clicked_then_only_the_last_move_is_removed :: proc(
	t: ^testing.T,
) {
	ctx := gp_context()
	state := gp_open(t, &ctx)
	gp_reach_reference_state(&state)
	capture: Gameplay_Test_Capture
	_ = gp_click(&state, state.undo_node)
	gp_draw(&state, ctx, &capture)

	testing.expect_value(t, workspace_step(&state.workspace), 1)
	gp_expect_all(t, &capture, {"STEP 01", "1 MOVE", "3x − 12 + 8 = 2x + 17"})
	testing.expect_value(t, gp_count(&capture, "Combine constants"), 1) // the move card; its history card is gone
}

@(test)
given_two_moves_applied_when_the_undo_key_is_pressed_then_the_last_move_is_removed :: proc(
	t: ^testing.T,
) {
	ctx := gp_context()
	state := gp_open(t, &ctx)
	gp_reach_reference_state(&state)

	_ = gp_key(&state, .Undo)

	testing.expect_value(t, workspace_step(&state.workspace), 1)
}

@(test)
given_no_moves_applied_when_undo_is_pressed_then_nothing_changes :: proc(t: ^testing.T) {
	ctx := gp_context()
	state := gp_open(t, &ctx)

	_ = gp_key(&state, .Undo)
	_ = gp_click(&state, state.undo_node)

	testing.expect_value(t, workspace_step(&state.workspace), 0)
}

@(test)
given_two_moves_applied_when_restart_is_clicked_then_the_start_formula_returns :: proc(
	t: ^testing.T,
) {
	ctx := gp_context()
	state := gp_open(t, &ctx)
	gp_reach_reference_state(&state)
	capture: Gameplay_Test_Capture
	_ = gp_click(&state, state.restart_node)
	gp_draw(&state, ctx, &capture)

	testing.expect_value(t, workspace_step(&state.workspace), 0)
	gp_expect_all(t, &capture, {"STEP 00", "0 MOVES", "1 valid move · whole equation"})
}

// ============================================================================
// Feature: the clock and pause
// ============================================================================

@(test)
given_the_clock_is_running_when_ticks_arrive_then_time_advances_in_whole_seconds :: proc(
	t: ^testing.T,
) {
	ctx := gp_context()
	state := gp_open(t, &ctx)
	capture: Gameplay_Test_Capture
	gp_tick(&state, 12.4)
	gp_tick(&state, 12.4)
	gp_draw(&state, ctx, &capture)

	gp_expect_all(t, &capture, {"00:24"})
}

@(test)
given_the_pause_button_is_clicked_when_ticks_arrive_then_time_does_not_advance :: proc(
	t: ^testing.T,
) {
	ctx := gp_context()
	state := gp_open(t, &ctx)
	gp_tick(&state, 5)

	_ = gp_click(&state, state.pause_node)
	gp_tick(&state, 10)

	testing.expect(t, state.paused, "the pause button pauses")
	testing.expect_value(t, state.elapsed, f32(5))
}

@(test)
given_the_game_is_paused_when_pause_is_pressed_again_then_the_clock_resumes :: proc(
	t: ^testing.T,
) {
	ctx := gp_context()
	state := gp_open(t, &ctx)
	_ = gp_key(&state, .Pause)

	_ = gp_key(&state, .Pause)
	gp_tick(&state, 3)

	testing.expect(t, !state.paused, "second press resumes")
	testing.expect_value(t, state.elapsed, f32(3))
}

@(test)
given_the_game_is_paused_when_confirm_is_pressed_then_no_move_is_applied :: proc(t: ^testing.T) {
	ctx := gp_context()
	state := gp_open(t, &ctx)
	_ = gp_key(&state, .Pause)

	_ = gp_key(&state, .Confirm)
	_ = gp_click(&state, state.apply_node)

	testing.expect_value(t, workspace_step(&state.workspace), 0)
}

// ============================================================================
// Feature: solving the puzzle
// ============================================================================

@(test)
given_the_reference_state_when_subtract_2x_and_add_4_are_applied_then_the_puzzle_is_solved_and_the_clock_stops :: proc(
	t: ^testing.T,
) {
	ctx := gp_context()
	state := gp_open(t, &ctx)
	capture: Gameplay_Test_Capture
	gp_reach_reference_state(&state)
	gp_tick(&state, 24)

	_ = gp_click(&state, state.tile_nodes[5]) // select 2x
	_ = gp_key(&state, .Confirm) // Subtract 2x
	_ = gp_click(&state, state.tile_nodes[2]) // select 4
	_ = gp_key(&state, .Confirm) // Add 4
	gp_tick(&state, 10)
	gp_draw(&state, ctx, &capture)

	testing.expect(t, workspace_solved(&state.workspace), "x = 21 solves the puzzle")
	testing.expect_value(t, state.elapsed, f32(24))
	gp_expect_all(t, &capture, {"STEP 04", "4 MOVES", "00:24", "0 valid moves · whole equation"})
}

@(test)
given_a_solved_puzzle_when_confirm_is_pressed_then_nothing_more_is_applied :: proc(t: ^testing.T) {
	ctx := gp_context()
	state := gp_open(t, &ctx)
	gp_reach_reference_state(&state)
	_ = gp_click(&state, state.tile_nodes[5]) // select 2x
	_ = gp_key(&state, .Confirm)
	_ = gp_click(&state, state.tile_nodes[2]) // select 4
	_ = gp_key(&state, .Confirm)

	navigation := gp_key(&state, .Confirm)

	testing.expect(t, navigation == nil, "no auto-navigation on solve yet (open question)")
	testing.expect_value(t, workspace_step(&state.workspace), 4)
}

// ============================================================================
// Feature: leaving the screen
// ============================================================================

@(test)
given_gameplay_is_open_when_back_is_pressed_then_level_select_is_requested :: proc(t: ^testing.T) {
	ctx := gp_context()
	state := gp_open(t, &ctx)

	navigation := gp_key(&state, .Back)
	_, ok := navigation.(core.Go_Level_Select)

	testing.expect(t, ok, "Back should request level select")
}

// ============================================================================
// Feature: resizing keeps the screen interactive
// ============================================================================

@(test)
given_the_window_is_resized_when_a_card_is_clicked_at_the_new_scale_then_it_is_selected :: proc(
	t: ^testing.T,
) {
	ctx := gp_context()
	state := gp_open(t, &ctx)
	gp_reach_reference_state(&state)
	ctx.viewport = shared.viewport_of(1920, 1080)
	state.viewport = ctx.viewport
	layout_gameplay(&state, &ctx)

	_ = gp_click(&state, state.move_nodes[1])

	testing.expect_value(t, state.workspace.selected_move, 1)
}
