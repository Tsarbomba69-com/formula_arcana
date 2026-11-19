package features

import "core:testing"

TARGET :: "x = 21"

@(private = "file")
open :: proc(t: ^testing.T, loc := #caller_location) -> Workspace {
	w, err := workspace_init(START, TARGET)
	testing.expect_value(t, err, Workspace_Error.None, loc)
	return w
}

@(private = "file")
current_is :: proc(t: ^testing.T, w: ^Workspace, want: string, loc := #caller_location) {
	buf: [LABEL_CAP * 2]u8
	testing.expect_value(t, format_equation(workspace_current(w), buf[:]), want, loc)
}

@(private = "file")
entry_label :: proc(w: ^Workspace, index: int, note: bool) -> string {
	if note { return label_str(&w.entries[index].note) }
	return label_str(&w.entries[index].title)
}

// Plays the reference path: Distribute 3 → Combine constants (the screenshot state).
@(private = "file")
reach_reference_state :: proc(t: ^testing.T, w: ^Workspace) {
	testing.expect(t, workspace_apply(w), "Distribute 3 should apply")
	testing.expect(t, workspace_apply(w), "Combine constants should apply")
}

// ============================================================================
// Feature: opening a workspace
// ============================================================================

@(test)
given_a_start_and_target_when_the_workspace_opens_then_history_holds_only_the_initial_formula :: proc(
	t: ^testing.T,
) {
	w := open(t)

	testing.expect_value(t, workspace_step(&w), 0)
	testing.expect_value(t, w.entry_count, 1)
	testing.expect_value(t, entry_label(&w, 0, false), "Initial formula")
	testing.expect_value(t, entry_label(&w, 0, true), "Original equation from the codex.")
	current_is(t, &w, START)
	testing.expect(t, !workspace_solved(&w), "the start is not solved")
}

@(test)
given_a_fresh_workspace_when_inspected_then_the_first_move_is_selected_and_recommended :: proc(
	t: ^testing.T,
) {
	w := open(t)

	testing.expect_value(t, w.moves.count, 1)
	testing.expect_value(t, w.selected_move, 0)
	testing.expect(t, w.selection == nil, "scope starts as the whole equation")
	testing.expect(t, workspace_is_recommended(&w, 0), "the first move is recommended")
}

@(test)
given_an_unparsable_start_when_the_workspace_opens_then_invalid_start_is_reported :: proc(
	t: ^testing.T,
) {
	_, err := workspace_init("3(x", TARGET)
	testing.expect_value(t, err, Workspace_Error.Invalid_Start)
}

@(test)
given_an_unparsable_target_when_the_workspace_opens_then_invalid_target_is_reported :: proc(
	t: ^testing.T,
) {
	_, err := workspace_init(START, "x =")
	testing.expect_value(t, err, Workspace_Error.Invalid_Target)
}

// ============================================================================
// Feature: applying moves builds the history (right panel)
// ============================================================================

@(test)
given_the_start_when_distribute_is_applied_then_history_gains_a_distribute_entry :: proc(
	t: ^testing.T,
) {
	w := open(t)

	testing.expect(t, workspace_apply(&w), "apply should succeed")

	testing.expect_value(t, workspace_step(&w), 1)
	testing.expect_value(t, entry_label(&w, 1, false), "Distribute 3")
	testing.expect_value(t, entry_label(&w, 1, true), "3(x − 4) becomes 3x − 12.")
	current_is(t, &w, DISTRIBUTED)
	testing.expect_value(t, w.moves.count, 1) // Combine constants is now the only move
}

@(test)
given_the_reference_path_when_two_moves_are_applied_then_the_screen_state_is_reached :: proc(
	t: ^testing.T,
) {
	w := open(t)

	reach_reference_state(t, &w)

	testing.expect_value(t, workspace_step(&w), 2) // "STEP 02" / "2 MOVES"
	testing.expect_value(t, w.entry_count, 3)
	testing.expect_value(t, entry_label(&w, 0, false), "Initial formula")
	testing.expect_value(t, entry_label(&w, 1, false), "Distribute 3")
	testing.expect_value(t, entry_label(&w, 2, false), "Combine constants")
	testing.expect_value(t, entry_label(&w, 2, true), "−12 + 8 becomes −4.")
	current_is(t, &w, REFERENCE)
	testing.expect_value(t, w.moves.count, 3)
	testing.expect_value(t, w.selected_move, 0)
	testing.expect(t, workspace_is_recommended(&w, 0), "Subtract 2x is recommended")
	testing.expect(t, !workspace_is_recommended(&w, 1), "Add 4 is not recommended")
}

// ============================================================================
// Feature: previewing without committing
// ============================================================================

@(test)
given_the_reference_state_when_a_move_is_selected_then_the_preview_changes_but_history_does_not :: proc(
	t: ^testing.T,
) {
	w := open(t)
	reach_reference_state(t, &w)
	buf: [LABEL_CAP * 2]u8

	preview, ok := workspace_preview(&w)
	testing.expect(t, ok, "a move is selected")
	testing.expect_value(t, format_equation(preview, buf[:]), "x − 4 = 17")

	testing.expect(t, workspace_select_move(&w, 1), "Add 4 exists")
	preview, ok = workspace_preview(&w)
	testing.expect(t, ok, "a move is selected")
	testing.expect_value(t, format_equation(preview, buf[:]), "3x = 2x + 21")

	testing.expect_value(t, workspace_step(&w), 2)
	testing.expect_value(t, w.entry_count, 3)
	current_is(t, &w, REFERENCE)
}

@(test)
given_three_moves_when_selecting_out_of_range_then_it_is_rejected_and_selection_is_kept :: proc(
	t: ^testing.T,
) {
	w := open(t)
	reach_reference_state(t, &w)
	testing.expect(t, workspace_select_move(&w, 2), "Subtract 17 exists")

	testing.expect(t, !workspace_select_move(&w, 3), "index 3 does not exist")
	testing.expect(t, !workspace_select_move(&w, -1), "negative index does not exist")

	testing.expect_value(t, w.selected_move, 2)
}

@(test)
given_the_last_move_is_selected_when_stepping_down_then_selection_wraps_to_the_first :: proc(
	t: ^testing.T,
) {
	w := open(t)
	reach_reference_state(t, &w)
	_ = workspace_select_move(&w, 2)

	workspace_step_selection(&w, +1)
	testing.expect_value(t, w.selected_move, 0)

	workspace_step_selection(&w, -1)
	testing.expect_value(t, w.selected_move, 2)
}

// ============================================================================
// Feature: scope — whole equation vs selected term
// ============================================================================

@(test)
given_the_reference_state_when_a_term_is_toggled_then_moves_narrow_and_toggling_again_restores_them :: proc(
	t: ^testing.T,
) {
	w := open(t)
	reach_reference_state(t, &w)
	four := tokenize(workspace_current(&w)).items[3].term

	workspace_toggle_term(&w, four)
	testing.expect_value(t, w.moves.count, 1)
	testing.expect(t, w.selection != nil, "scope is now a term")

	workspace_toggle_term(&w, four)
	testing.expect_value(t, w.moves.count, 3)
	testing.expect(t, w.selection == nil, "scope is the whole equation again")
}

@(test)
given_a_term_is_selected_when_a_move_is_applied_then_scope_returns_to_the_whole_equation :: proc(
	t: ^testing.T,
) {
	w := open(t)
	reach_reference_state(t, &w)
	workspace_toggle_term(&w, tokenize(workspace_current(&w)).items[3].term)

	testing.expect(t, workspace_apply(&w), "Add 4 applies")

	testing.expect(t, w.selection == nil, "node ids change after a move, so scope resets")
	testing.expect_value(t, w.selected_move, 0)
	current_is(t, &w, "3x = 2x + 21")
}

// ============================================================================
// Feature: undo / restart
// ============================================================================

@(test)
given_two_moves_applied_when_undo_is_requested_then_the_last_move_is_removed :: proc(
	t: ^testing.T,
) {
	w := open(t)
	reach_reference_state(t, &w)

	testing.expect(t, workspace_undo(&w), "undo should succeed")

	testing.expect_value(t, workspace_step(&w), 1)
	testing.expect_value(t, w.entry_count, 2)
	current_is(t, &w, DISTRIBUTED)
	testing.expect_value(t, w.moves.count, 1)
}

@(test)
given_no_moves_applied_when_undo_is_requested_then_nothing_happens :: proc(t: ^testing.T) {
	w := open(t)

	testing.expect(t, !workspace_undo(&w), "the initial formula cannot be undone")

	testing.expect_value(t, w.entry_count, 1)
	current_is(t, &w, START)
}

@(test)
given_moves_applied_when_restart_is_requested_then_the_start_formula_is_back :: proc(
	t: ^testing.T,
) {
	w := open(t)
	reach_reference_state(t, &w)

	workspace_restart(&w)

	testing.expect_value(t, workspace_step(&w), 0)
	testing.expect_value(t, w.entry_count, 1)
	current_is(t, &w, START)
	testing.expect_value(t, w.moves.count, 1)
	testing.expect_value(t, w.selected_move, 0)
}

// ============================================================================
// Feature: solving
// ============================================================================

@(test)
given_the_reference_state_when_subtract_2x_then_add_4_are_applied_then_x_equals_21_is_solved :: proc(
	t: ^testing.T,
) {
	w := open(t)
	reach_reference_state(t, &w)

	testing.expect(t, workspace_apply(&w), "Subtract 2x (recommended, selected by default)")
	current_is(t, &w, "x − 4 = 17")
	testing.expect(t, !workspace_solved(&w), "not solved yet")
	testing.expect(t, workspace_apply(&w), "Add 4")

	current_is(t, &w, "x = 21")
	testing.expect(t, workspace_solved(&w), "x = 21 is the target")
	testing.expect_value(t, workspace_step(&w), 4)
	testing.expect_value(t, w.moves.count, 0)
}

@(test)
given_a_solved_workspace_when_apply_is_requested_then_it_is_rejected :: proc(t: ^testing.T) {
	w := open(t)
	reach_reference_state(t, &w)
	_ = workspace_apply(&w)
	_ = workspace_apply(&w)

	testing.expect(t, !workspace_apply(&w), "nothing left to apply")
	testing.expect_value(t, workspace_step(&w), 4)
}

@(test)
given_a_solved_workspace_when_undo_is_requested_then_it_is_playable_again :: proc(t: ^testing.T) {
	w := open(t)
	reach_reference_state(t, &w)
	_ = workspace_apply(&w)
	_ = workspace_apply(&w)

	testing.expect(t, workspace_undo(&w), "undo from a solved state")

	testing.expect(t, !workspace_solved(&w), "no longer solved")
	current_is(t, &w, "x − 4 = 17")
}
