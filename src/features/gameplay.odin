package features

import "../core"
import "../shared"
import "core:log"

// ============================================================================
// PHASE 1 CONTRACT — the "Transformation" gameplay screen.
// Replaces the old Gameplay_State / init_gameplay / update_gameplay /
// draw_gameplay in gameplay.odin (see PATCH.md). Stubs on purpose (RED).
//
// Shape follows Level_Select_State: the state OWNS a value-typed UI tree and
// the node indices that tests/handlers need. The domain lives in
// algebra.Workspace; this layer only maps events → workspace calls → tree.
// ============================================================================

// Button `action` ids used by the gameplay tree.
Gameplay_Action :: enum int {
	None,
	Move_Card, // + card index in the node lookup
	Term_Tile,
	Apply,
	Undo,
	Restart,
	Pause,
}

// Puzzle contains the goal and transformations permitted for one proof task.
Puzzle :: struct {
	title, goal:          string,
	rating:               int,
	available_transforms: [2]string,
	transform_count:      int,
	// Transformation screen
	brief:                string, // "Preserve equivalence. …"
	category:             string, // "ALGEBRA"
	start:                string, // "3(x − 4) + 8 = 2x + 17"   (goal = "x = 21")
	objective:            string, // "ISOLATE THE UNKNOWN"
	rule:                 string, // "One variable. One value. No extra terms."
	completion_rule:      string, // text under "COMPLETION RULE" (cut off in the screenshot)
}

PUZZLES: [20]Puzzle = {
	{
		title = "ADDITIVE IDENTITY",
		goal = "x + 0 = x",
		rating = 3,
		available_transforms = {"Additive identity", "Reflexivity"},
		transform_count = 2,
	},
	{
		title = "MULTIPLICATIVE IDENTITY",
		goal = "x * 1 = x",
		rating = 1,
		available_transforms = {"Multiplicative identity", ""},
		transform_count = 1,
	},
	{
		title = "DISTRIBUTIVE PROPERTY",
		goal = "A(B + C) = AB + AC",
		rating = 1,
		available_transforms = {"Distributivity", ""},
		transform_count = 1,
	},
	{
		title = "COMMUTATIVE (ADD)",
		goal = "A + B = B + A",
		rating = 3,
		available_transforms = {"Commutativity", ""},
		transform_count = 1,
	},
	{
		title = "POWER OF IDENTITY",
		goal = "1^x = 1",
		rating = 2,
		available_transforms = {"Exponent identity", ""},
		transform_count = 1,
	},
	{
		title = "ZERO POWER",
		goal = "x^0 = 1",
		rating = 1,
		available_transforms = {"Zero exponent", ""},
		transform_count = 1,
	},
	{
		title = "LOG OF BASE",
		goal = "log_a(a) = 1",
		rating = 3,
		available_transforms = {"Logarithm identity", ""},
		transform_count = 1,
	},
	{
		title = "NEGATIVE POWER",
		goal = "x^-1 = 1/x",
		rating = 1,
		available_transforms = {"Negative exponent", ""},
		transform_count = 1,
	},
	{
		title = "DOUBLE NEGATION",
		goal = "-(-x) = x",
		rating = 1,
		available_transforms = {"Double negation", ""},
		transform_count = 1,
	},
	{
		title = "IMPLICATION RULE",
		goal = "A -> B = !A or B",
		rating = 1,
		available_transforms = {"Implication", ""},
		transform_count = 1,
	},
	{
		title = "DE MORGAN'S LAW",
		goal = "!(A and B) = !A or !B",
		rating = 1,
		available_transforms = {"De Morgan", ""},
		transform_count = 1,
	},
	{
		title = "NEGATIVE NEGATION",
		goal = "-x - (-x) = 0",
		rating = 1,
		available_transforms = {"Additive inverse", ""},
		transform_count = 1,
	},
	{
		title = "IMPLICATION RULE",
		goal = "A(B + C) = AB + AC",
		rating = 1,
		available_transforms = {"Distributivity", ""},
		transform_count = 1,
	},
	{
		title = "IMPLICATION RULE",
		goal = "A(B + C) = AB + AC",
		rating = 1,
		available_transforms = {"Distributivity", ""},
		transform_count = 1,
	},
	{
		title = "DE MORGAN'S LAW",
		goal = "A + B = B + A",
		rating = 1,
		available_transforms = {"Commutativity", ""},
		transform_count = 1,
	},
	{
		title = "DE MORGAN'S LAW",
		goal = "A + B = B + A",
		rating = 1,
		available_transforms = {"Commutativity", ""},
		transform_count = 1,
	},
	{
		title = "DE MORGAN'S LAW",
		goal = "2^0 = 1",
		rating = 1,
		available_transforms = {"Zero exponent", ""},
		transform_count = 1,
	},
	{
		title = "DE MORGAN'S LAW",
		goal = "x^2 = 1",
		rating = 1,
		available_transforms = {"Exponent rules", ""},
		transform_count = 1,
	},
	{
		title = "LOG OF BASE",
		goal = "log_a(a) = 1",
		rating = 3,
		available_transforms = {"Logarithm identity", ""},
		transform_count = 1,
	},
	{
		title = "NEGATIVE POWER",
		goal = "x^-1 = 1/x",
		rating = 1,
		available_transforms = {"Negative exponent", ""},
		transform_count = 1,
	},
}

FIRST_PUZZLE: Puzzle = PUZZLES[0]

Gameplay_State :: struct {
	puzzle:          Puzzle,
	run:             Run_Info,
	workspace:       Workspace,
	elapsed:         f32, // seconds; frozen while paused or solved
	paused:          bool,
	viewport:        shared.Viewport,
	tree:            core.UI_Tree,
	ix:              core.Interaction,
	font:            shared.Font_Id,

	// Interactive nodes (rebuilt together with the tree after every state change).
	move_nodes:      [MAX_MOVES]int,
	move_node_count: int,
	tile_nodes:      [MAX_TOKENS]int, // index == token index
	tile_node_count: int,
	apply_node:      int,
	undo_node:       int,
	restart_node:    int,
	pause_node:      int,
}

// Seam for Phase 2: where Run_Info comes from (campaign/progress).
run_info_for :: proc(progress: core.Progress) -> Run_Info {
	return {} // STUB
}

init_gameplay :: proc(ctx: ^Context, puzzle: Puzzle, run: Run_Info) -> (state: Gameplay_State) {
	state.puzzle = puzzle
	state.run = run

	workspace, err := workspace_init(puzzle.start, puzzle.goal)
	if err == .None {
		state.workspace = workspace
	} else {
		log.errorf("Puzzle %q cannot start: %v", puzzle.title, err)
	}
	// TODO: Make init gameplay work
	// state.fonts.ui = gp_load_font(ctx, GP_FONT_UI_PATH, shared.INVALID_FONT_ID)
	// state.fonts.display = gp_load_font(ctx, GP_FONT_DISPLAY_PATH, state.fonts.ui)
	// state.fonts.mono = gp_load_font(ctx, GP_FONT_MONO_PATH, state.fonts.ui)
	// state.fonts.math = gp_load_font(ctx, GP_FONT_MATH_PATH, state.fonts.ui)
	// state.fonts.math_italic = gp_load_font(ctx, GP_FONT_MATH_ITALIC_PATH, state.fonts.math)
	// if ctx.load_texture != nil {
	// 	if texture, ok := ctx.load_texture(GP_BACKGROUND_PATH); ok { state.background = texture }
	// }

	layout_gameplay(&state, ctx)
	state.ix.focus = state.apply_node
	return
}

// Rebuilds tree + node indices from state. Called on init, resize and after every change.
layout_gameplay :: proc(s: ^Gameplay_State, ctx: ^Context) {
	// STUB
}

// Events handled (all through the event stream, like the other screens):
//   Key_Input .Up/.Down   → step selected move (wraps)         [preview only]
//   Key_Input .Confirm    → apply selected move
//   Key_Input .Undo       → undo last move
//   Key_Input .Pause      → toggle pause
//   Key_Input .Back       → Go_Level_Select{difficulty = .Normal}
//   Mouse_Input press+release on the SAME button → that button's action
//   Tick_Input{dt}        → advance the clock (unless paused / solved)
update_gameplay :: proc(s: ^Gameplay_State, events: []core.Event) -> core.Navigation {
	return nil // STUB
}

draw_gameplay :: proc(s: ^Gameplay_State, ctx: Context) {
	// STUB
}

@(private = "file")
gp_load_font :: proc(ctx: ^Context, path: cstring, fallback: shared.Font_Id) -> shared.Font_Id {
	if ctx.load_font == nil { return fallback }
	id, ok := ctx.load_font(path, 64)
	if ok && id != shared.INVALID_FONT_ID { return id }
	log.infof("Font %s unavailable, using fallback", path)
	return fallback
}
