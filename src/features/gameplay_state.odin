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
		title           = "THE ART OF ISOLATION",
		brief           = "Preserve equivalence. Transform the formula into its final form.",
		category        = "ALGEBRA",
		start           = "3(x − 4) + 8 = 2x + 17",
		goal            = "x = 21",
		objective       = "ISOLATE THE UNKNOWN",
		rule            = "One variable. One value. No extra terms.",
		// The reference screenshot cuts this copy off; placeholder until the design is confirmed.
		completion_rule = "x alone on the left, equal to a number.",
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

Gameplay_Fonts :: struct {
	ui, display, mono, math, math_italic: shared.Font_Id,
}

Gameplay_Scroll_Drag :: enum {
	None,
	Moves,
	History,
}

Gameplay_Selection_Kind :: enum {
	None,
	Term,
	Operator,
}

Gameplay_Selection :: struct {
	kind:        Gameplay_Selection_Kind,
	token_index: int, // tile index for operator or term selection
	term:        Expr_Id,
}

Gameplay_State :: struct {
	puzzle:            Puzzle,
	run:               Run_Info,
	workspace:         Workspace,
	elapsed:           f32, // seconds; frozen while paused or solved
	paused:            bool,
	viewport:          shared.Viewport,
	tree:              core.UI_Tree,
	ix:                core.Interaction,
	font:              shared.Font_Id,

	// Interactive nodes (rebuilt together with the tree after every state change).
	move_nodes:        [MAX_MOVES]int,
	move_node_count:   int,
	moves_scroll_y:    f32,
	history_scroll_y:  f32,
	scroll_drag:       Gameplay_Scroll_Drag,
	scroll_drag_y:     f32,
	scroll_drag_start: f32,
	tile_nodes:        [MAX_TOKENS]int, // index == token index
	tile_node_count:   int,
	selection:         Gameplay_Selection,
	apply_node:        int,
	undo_node:         int,
	restart_node:      int,
	pause_node:        int,

	// Visuals (owned by gameplay_view.odin)
	fonts:             Gameplay_Fonts,
	background:        shared.Texture_Id,
	measure:           shared.Measure_Text, // kept so update_gameplay can call gameplay_rebuild
	design:            shared.Vec2, // window size in design units
	origin_x:          f32, // left margin that centres the 1440-wide content
	tokens:            Token_List, // tiles of the current formula (index == tile_nodes index)
	tile_font_size:    f32,
}

GP_FONT_UI_PATH: cstring = "assets/fonts/DejaVuSans.ttf"
GP_FONT_DISPLAY_PATH: cstring = "assets/fonts/Cinzel-SemiBold.ttf"
GP_FONT_MONO_PATH: cstring = "assets/fonts/JetBrainsMono-Regular.ttf"
GP_FONT_MATH_PATH: cstring = "assets/fonts/STIXTwoText-Regular.ttf"
GP_FONT_MATH_ITALIC_PATH: cstring = "assets/fonts/STIXTwoText-Italic.ttf"
GP_BACKGROUND_PATH: cstring = "assets/images/main_menu_bg.png"

// Build the HUD snapshot from the persisted campaign progress. A run has one
// round per puzzle; unlocked levels mark how far the player has progressed.
// Score and streak are session data and start at zero for a new run.
run_info_for :: proc(progress: core.Progress) -> Run_Info {
	completed := 0
	for i in 0 ..< len(PUZZLES) {
		if i in progress.unlocked {
			completed += 1
		}
	}
	round := clamp(completed + 1, 1, len(PUZZLES))

	return {
		mode         = "ARCANE TRIALS",
		tier         = core.Difficulty.Normal,
		round        = round, // 1-based
		rounds_total = len(PUZZLES),
		score        = 0,
		streak       = 0,
	}
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

	state.fonts.ui = gp_load_font(ctx, GP_FONT_UI_PATH, shared.INVALID_FONT_ID)
	state.fonts.display = gp_load_font(ctx, GP_FONT_DISPLAY_PATH, state.fonts.ui)
	state.fonts.mono = gp_load_font(ctx, GP_FONT_MONO_PATH, state.fonts.ui)
	state.fonts.math = gp_load_font(ctx, GP_FONT_MATH_PATH, state.fonts.ui)
	state.fonts.math_italic = gp_load_font(ctx, GP_FONT_MATH_ITALIC_PATH, state.fonts.math)
	if ctx.load_texture != nil {
		if texture, ok := ctx.load_texture(GP_BACKGROUND_PATH); ok { state.background = texture }
	}

	layout_gameplay(&state, ctx)
	state.ix.focus = state.apply_node
	return
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
	for event in events {
		#partial switch input in event {
		case shared.Tick_Input: if !s.paused && !workspace_solved(&s.workspace) {
					s.elapsed += max(input.dt, 0)
				}
		case shared.Key_Input: switch input.key {
				case .Back: return core.Go_Level_Select{difficulty = .Normal}
				case .Pause: s.paused = !s.paused
				case .Undo: if !s.paused && workspace_undo(&s.workspace) { gameplay_rebuild(s) }
				case .Up:
					workspace_step_selection(&s.workspace, -1)
					gameplay_rebuild(s)
				case .Down:
					workspace_step_selection(&s.workspace, 1)
					gameplay_rebuild(s)
				case .Confirm: if !s.paused && workspace_apply(&s.workspace) {
							s.history_scroll_y = gp_history_scroll_max(s)
							gameplay_rebuild(s)
						}
				case .Left, .Right:
				}
		case shared.Mouse_Input:
			position := input.position / max(s.viewport.scale, 0.001)
			if input.wheel != 0 {
				if shared.contains_point(gp_moves_view_rect(s.origin_x), position) {
					previous_scroll := s.moves_scroll_y
					s.moves_scroll_y = clamp(
						s.moves_scroll_y - input.wheel * GP_SCROLL_STEP,
						0,
						gp_moves_scroll_max(s),
					)
					delta := s.moves_scroll_y - previous_scroll
					core.ui_scroll_nodes_by(&s.tree, s.move_nodes[:s.move_node_count], delta)
				} else if shared.contains_point(gp_history_view_rect(s.origin_x), position) {
					s.history_scroll_y = clamp(
						s.history_scroll_y - input.wheel * GP_SCROLL_STEP,
						0,
						gp_history_scroll_max(s),
					)
				}
			}
			scrollbar_active := false
			if input.pressed {
				scrollbar_active = gp_begin_scrollbar_drag(s, position)
			}
			if s.scroll_drag != .None && input.down {
				gp_update_scrollbar_drag(s, position.y)
				scrollbar_active = true
			}
			if input.released && s.scroll_drag != .None {
				s.scroll_drag = .None
				scrollbar_active = true
			}
			if scrollbar_active {
				s.ix.hover = nil
				s.ix.pressed = nil
				continue
			}
			hit, over := core.ui_button_at(&s.tree, position)
			if over &&
			   gp_is_move_node(s, hit) &&
			   !shared.contains_point(gp_moves_view_rect(s.origin_x), position) {
				over = false
			}
			if over { s.ix.hover = hit } else { s.ix.hover = nil }
			if input.pressed && over { s.ix.pressed = hit; s.ix.focus = hit }
			if input.released {
				if pressed, ok := s.ix.pressed.?; ok {
					s.ix.pressed = nil
					if over && hit == pressed { gameplay_activate(s, hit) }
				}
			}
		}
	}
	return nil
}

gameplay_rebuild :: proc(s: ^Gameplay_State) {
	ctx := Context {
		viewport = s.viewport,
		renderer = {measure_text = s.measure},
	}
	layout_gameplay(s, &ctx)
	if s.tree.count > 0 { s.ix.focus = s.apply_node }
}

gameplay_activate :: proc(s: ^Gameplay_State, node: int) {
	if s.paused {
		if node == s.pause_node { s.paused = false }
		return
	}
	for i in 0 ..< s.move_node_count {
		if node == s.move_nodes[i] {
			_ = workspace_select_move(&s.workspace, i)
			return
		}
	}
	for i in 0 ..< s.tile_node_count {
		if node == s.tile_nodes[i] {
			token := s.tokens.items[i]
			if token.term != NO_EXPR {
				workspace_toggle_term(&s.workspace, token.term)
				gameplay_rebuild(s)
			} else if token.kind == .Operator && label_str(&token.text) != "=" {
				workspace_toggle_op(&s.workspace, i)
				gameplay_rebuild(s)
			}
			return
		}
	}
	switch node {
	case s.apply_node: if workspace_apply(&s.workspace) {
				s.history_scroll_y = gp_history_scroll_max(s)
				gameplay_rebuild(s)
			}
	case s.undo_node: if workspace_undo(&s.workspace) { gameplay_rebuild(s) }
	case s.restart_node:
		workspace_restart(&s.workspace); s.elapsed = 0; gameplay_rebuild(s)
	case s.pause_node: s.paused = true
	}
}

gp_load_font :: proc(ctx: ^Context, path: cstring, fallback: shared.Font_Id) -> shared.Font_Id {
	if ctx.load_font == nil { return fallback }
	id, ok := ctx.load_font(path, 64)
	if ok && id != shared.INVALID_FONT_ID { return id }
	log.infof("Font %s unavailable, using fallback", path)
	return fallback
}
