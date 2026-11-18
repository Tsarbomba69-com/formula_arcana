package features

// ============================================================================
// Workspace — the session logic behind the three panels:
// valid moves (left), current formula + preview (center), history (right).
//
// Pure: no timers, no score, no UI. Value-typed and copy-safe; history is an
// array of Equation snapshots, so undo is just "forget the last entry".
//
// Depends only on the equation domain:
//   parse_equation, valid_moves, apply_move, describe_move, explain_move, is_solved
// ============================================================================

MAX_HISTORY :: 16 // entry 0 is the initial formula, so at most 15 moves

History_Entry :: struct {
	equation: Equation,
	title:    Label, // "Initial formula", "Distribute 3", "Combine constants"
	note:     Label, // "Original equation from the codex.", "3(x − 4) becomes 3x − 12."
}

Workspace :: struct {
	start, target: Equation,
	entries:       [MAX_HISTORY]History_Entry,
	entry_count:   int,
	selection:     Maybe(Expr_Id), // selected term; nil == scope "whole equation"
	moves:         Move_List, // valid moves for the current scope
	selected_move: int, // index into `moves`
}

Workspace_Error :: enum {
	None,
	Invalid_Start,
	Invalid_Target,
}

INITIAL_TITLE :: "Initial formula"
INITIAL_NOTE :: "Original equation from the codex."

// ---- Construction ----------------------------------------------------------------

workspace_init :: proc(start, target: string) -> (w: Workspace, err: Workspace_Error) {
	start_eq, start_err := parse_equation(start)
	if start_err != .None { return {}, .Invalid_Start }
	target_eq, target_err := parse_equation(target)
	if target_err != .None { return {}, .Invalid_Target }

	w.start = start_eq
	w.target = target_eq
	workspace_restart(&w)
	return w, .None
}

// ---- Queries ------------------------------------------------------------------------

workspace_current :: proc(w: ^Workspace) -> Equation {
	if w.entry_count <= 0 { return {} }
	return w.entries[w.entry_count - 1].equation
}

// Number of moves applied == entry_count - 1 ("STEP 02", "2 MOVES"). Never negative.
workspace_step :: proc(w: ^Workspace) -> int {
	return max(w.entry_count - 1, 0)
}

workspace_solved :: proc(w: ^Workspace) -> bool {
	return w.entry_count > 0 && is_solved(workspace_current(w), w.target)
}

// Result of the selected move without committing it. Never touches history.
workspace_preview :: proc(w: ^Workspace) -> (result: Equation, ok: bool) {
	if !workspace_has_selected_move(w) { return {}, false }
	return apply_move(workspace_current(w), w.moves.items[w.selected_move])
}

// A move is "recommended" when it is the first move of the UNFILTERED list,
// so the badge survives narrowing the scope to a single term.
workspace_is_recommended :: proc(w: ^Workspace, index: int) -> bool {
	if index < 0 || index >= w.moves.count { return false }
	unfiltered := valid_moves(workspace_current(w))
	if unfiltered.count == 0 { return false }
	return w.moves.items[index] == unfiltered.items[0]
}

// ---- Selection (preview only) ----------------------------------------------------

// Selecting the already-selected term deselects it. Resets selected_move to 0.
// Tiles that belong to no term (operators, "=") are ignored.
workspace_toggle_term :: proc(w: ^Workspace, term: Expr_Id) {
	if term == NO_EXPR { return }
	if current, ok := w.selection.?; ok && current == term {
		w.selection = nil
	} else {
		w.selection = term
	}
	w.selected_move = 0
	workspace_refresh(w)
}

// false (and no change) when out of range.
workspace_select_move :: proc(w: ^Workspace, index: int) -> bool {
	if index < 0 || index >= w.moves.count { return false }
	w.selected_move = index
	return true
}

// Wraps around (Up / Down).
workspace_step_selection :: proc(w: ^Workspace, delta: int) {
	count := w.moves.count
	if count == 0 { return }
	w.selected_move = ((w.selected_move + delta) % count + count) % count
}

// ---- Mutation --------------------------------------------------------------------------

// Commits the selected move. Clears the term selection and resets selected_move to 0
// (node ids change after a move, so a stale selection would point at the wrong term).
// false when: no move is selected, the puzzle is solved, or the history is full.
workspace_apply :: proc(w: ^Workspace) -> bool {
	if w.entry_count <= 0 || w.entry_count >= MAX_HISTORY { return false }
	if workspace_solved(w) { return false }
	if !workspace_has_selected_move(w) { return false }

	before := workspace_current(w)
	move := w.moves.items[w.selected_move]
	after, ok := apply_move(before, move)
	if !ok { return false }

	view := describe_move(before, move)
	w.entries[w.entry_count] = {
		equation = after,
		title    = view.title,
		note     = explain_move(before, move),
	}
	w.entry_count += 1

	w.selection = nil
	w.selected_move = 0
	workspace_refresh(w)
	return true
}

// Forgets the last move. Works from a solved state too (the puzzle becomes playable again).
workspace_undo :: proc(w: ^Workspace) -> bool {
	if w.entry_count <= 1 { return false } 	// the initial formula cannot be undone

	w.entry_count -= 1
	w.entries[w.entry_count] = {}
	w.selection = nil
	w.selected_move = 0
	workspace_refresh(w)
	return true
}

// Back to the initial formula; the start and target are kept.
workspace_restart :: proc(w: ^Workspace) {
	for i in 0 ..< MAX_HISTORY { w.entries[i] = {} }
	w.entries[0].equation = w.start
	label_set(&w.entries[0].title, INITIAL_TITLE)
	label_set(&w.entries[0].note, INITIAL_NOTE)
	w.entry_count = 1
	w.selection = nil
	w.selected_move = 0
	workspace_refresh(w)
}

// ---- Internals ----------------------------------------------------------------------------

@(private = "file")
workspace_has_selected_move :: proc(w: ^Workspace) -> bool {
	return w.selected_move >= 0 && w.selected_move < w.moves.count
}

// Recomputes the move list for the current formula and scope.
// A solved puzzle never offers moves, whatever the equation domain says.
@(private = "file")
workspace_refresh :: proc(w: ^Workspace) {
	w.moves = {}
	if w.entry_count <= 0 || workspace_solved(w) { return }
	w.moves = valid_moves(workspace_current(w), w.selection)
	if w.selected_move >= w.moves.count { w.selected_move = 0 }
}
