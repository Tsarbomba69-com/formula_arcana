package features

// ============================================================================
// PHASE 1 CONTRACT — the session logic behind the three panels:
// valid moves (left), current formula + preview (center), history (right).
// Pure: no timers, no score, no UI. Stubs on purpose (RED).
// ============================================================================

MAX_HISTORY :: 16 // entry 0 is the initial formula

History_Entry :: struct {
	equation: Equation,
	title:    Label, // "Initial formula", "Distribute 3", "Combine constants"
	note:     Label, // "Original equation from the codex.", "3(x − 4) becomes 3x − 12."
}

Workspace :: struct {
	start, target: Equation,
	entries:       [MAX_HISTORY]History_Entry,
	entry_count:   int,
	selection:     Maybe(Expr_Id), // selected term; nil == scope "equation"
	moves:         Move_List, // valid moves for the current scope
	selected_move: int, // index into `moves`
}

Workspace_Error :: enum {
	None,
	Invalid_Start,
	Invalid_Target,
}

workspace_init :: proc(start, target: string) -> (w: Workspace, err: Workspace_Error) {
	return {}, .Invalid_Start // STUB
}

workspace_current :: proc(w: ^Workspace) -> Equation {
	return {} // STUB
}

// Number of moves applied == entry_count - 1 ("STEP 02", "2 MOVES").
workspace_step :: proc(w: ^Workspace) -> int {
	return -1 // STUB
}

// Selecting the already-selected term deselects it. Resets selected_move to 0.
workspace_toggle_term :: proc(w: ^Workspace, term: Expr_Id) {
	// STUB
}

// Preview only: never touches history. false when out of range.
workspace_select_move :: proc(w: ^Workspace, index: int) -> bool {
	return false // STUB
}

// Wraps around (used by Up / Down).
workspace_step_selection :: proc(w: ^Workspace, delta: int) {
	// STUB
}

// Result of the selected move without committing it.
workspace_preview :: proc(w: ^Workspace) -> (result: Equation, ok: bool) {
	return {}, false // STUB
}

// A move is "recommended" when it is the first of the UNFILTERED list.
workspace_is_recommended :: proc(w: ^Workspace, index: int) -> bool {
	return false // STUB
}

// Commits the selected move. Clears selection, resets selected_move to 0.
// false when: no move, already solved, or history is full.
workspace_apply :: proc(w: ^Workspace) -> bool {
	return false // STUB
}

workspace_undo :: proc(w: ^Workspace) -> bool {
	return false // STUB
}

workspace_restart :: proc(w: ^Workspace) {
	// STUB
}

workspace_solved :: proc(w: ^Workspace) -> bool {
	return false // STUB
}
