package features

import "../core"
import "../shared"
import "core:fmt"
import "core:log"
import "core:math"

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
	selected_operator: int, // token index; independent of Token.term
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

// ============================================================================
// Painter primitives
// ============================================================================

@(private = "file")
Gp_View :: struct {
	s:     ^Gameplay_State,
	r:     shared.Renderer,
	scale: f32,
	size:  shared.Vec2, // real window pixels
}

// ---- Palette ----------------------------------------------------------------

GP_BG :: shared.Color{5, 12, 19, 255}
GP_BAR :: shared.Color{7, 18, 27, 245}
GP_PANEL :: shared.Color{8, 22, 32, 238}
GP_PANEL_BORDER :: shared.Color{24, 62, 72, 255}
GP_DIVIDER :: shared.Color{22, 52, 62, 255}
GP_CARD :: shared.Color{9, 30, 40, 255}
GP_CARD_BORDER :: shared.Color{22, 58, 68, 255}
GP_TEXT :: shared.Color{214, 228, 232, 255}
GP_MUTED :: shared.Color{122, 150, 158, 255}
GP_DISABLED :: shared.Color{70, 92, 98, 255}
GP_TEAL :: shared.Color{72, 214, 204, 255}
GP_TEAL_SOFT :: shared.Color{126, 226, 216, 255}
GP_TEAL_DIM :: shared.Color{34, 120, 124, 255}
GP_TEAL_FILL :: shared.Color{14, 62, 68, 255}
GP_GREEN :: shared.Color{62, 216, 140, 255}
GP_AMBER :: shared.Color{232, 152, 92, 255}
GP_AMBER_DIM :: shared.Color{190, 118, 64, 255}
GP_TILE_CONST :: shared.Color{58, 38, 30, 255}
GP_TILE_OP :: shared.Color{16, 56, 52, 255}
GP_OP_TEXT :: shared.Color{104, 226, 172, 255}
GP_VAR :: shared.Color{96, 206, 255, 255}
GP_VEIL :: shared.Color{2, 6, 10, 170}

// ---- Layout constants (design space, content-relative) -----------------------

GP_HEADER_H :: f32(76)
GP_STATS_BOTTOM :: f32(168)
GP_PANEL_TOP :: f32(261)
GP_PANEL_BOTTOM :: f32(852)

GP_MOVES_VISIBLE_MAX :: 4
GP_TILE_FONT_MAX :: f32(42)
GP_TILE_FONT_MIN :: f32(24)
GP_TILE_H :: f32(65)
GP_TILE_GAP :: f32(4)

GP_TABS := [4]string{"ALGEBRA", "ARITHMETIC", "LOGIC", "PHYSICS"}
GP_TAB_WIDTHS := [4]f32{96, 110, 78, 90}

GP_FOOTNOTE :: "Only equivalence-preserving moves are listed."

// ---- Fonts (all optional: a missing file falls back to the UI font) ---------

GP_FONT_UI_PATH: cstring = "assets/fonts/DejaVuSans.ttf"
GP_FONT_DISPLAY_PATH: cstring = "assets/fonts/Cinzel-SemiBold.ttf" // headings, caps only
GP_FONT_MONO_PATH: cstring = "assets/fonts/JetBrainsMono-Regular.ttf" // captions
GP_FONT_MATH_PATH: cstring = "assets/fonts/STIXTwoText-Regular.ttf" // equations
GP_FONT_MATH_ITALIC_PATH: cstring = "assets/fonts/STIXTwoText-Italic.ttf" // the variable x
GP_BACKGROUND_PATH: cstring = "assets/images/main_menu_bg.png" // drawn very dim; optional

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
	state.selected_operator = -1

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

// Rebuilds tree + node indices from state. Called on init, resize and after every change.
layout_gameplay :: proc(s: ^Gameplay_State, ctx: ^Context) {
	// Gameplay uses the painter below for its visuals, but keeps a small UI tree
	// for hit testing and keyboard focus. Build that tree here because the
	// visible controls depend on the current workspace (move and token counts).
	s.viewport = ctx.viewport
	s.design = ctx.viewport.size / max(ctx.viewport.scale, 0.001)
	s.origin_x = max((s.design.x - shared.DESIGN_W) / 2, 0)
	s.measure = ctx.renderer.measure_text
	s.tree = {}
	s.move_node_count = 0
	s.tile_node_count = 0
	s.apply_node = 0
	s.undo_node = 0
	s.restart_node = 0
	s.pause_node = 0

	// Add interactive nodes in drawing order. Rectangles are in design units;
	// the painter reads these same rectangles and scales them for the renderer.
	for i in 0 ..< min(s.workspace.moves.count, MAX_MOVES) {
		node := core.ui_add(&s.tree, core.Button{action = int(Gameplay_Action.Move_Card)})
		s.move_nodes[i] = node
		s.move_node_count += 1
	}
	s.tokens = tokenize(workspace_current(&s.workspace))
	for i in 0 ..< min(s.tokens.count, MAX_TOKENS) {
		node := core.ui_add(&s.tree, core.Button{action = int(Gameplay_Action.Term_Tile)})
		s.tile_nodes[i] = node
		s.tile_node_count += 1
	}
	s.apply_node = core.ui_add(&s.tree, core.Button{action = int(Gameplay_Action.Apply)})
	s.undo_node = core.ui_add(&s.tree, core.Button{action = int(Gameplay_Action.Undo)})
	s.restart_node = core.ui_add(&s.tree, core.Button{action = int(Gameplay_Action.Restart)})
	s.pause_node = core.ui_add(&s.tree, core.Button{action = int(Gameplay_Action.Pause)})

	for index in 0 ..< s.move_node_count {
		s.tree.nodes[s.move_nodes[index]].rect = gp_move_card_rect(
			s.origin_x,
			index,
			s.move_node_count,
		)
	}
	moves_view := gp_moves_view_rect(s.origin_x)
	moves_content_h := gp_moves_content_height(s.move_node_count)
	s.moves_scroll_y = clamp(s.moves_scroll_y, 0, max(moves_content_h - moves_view.h, 0))
	core.ui_scroll_nodes_by(&s.tree, s.move_nodes[:s.move_node_count], s.moves_scroll_y)
	history_view := gp_history_view_rect(s.origin_x)
	history_content_h := gp_history_content_height(s.workspace.entry_count)
	s.history_scroll_y = clamp(s.history_scroll_y, 0, max(history_content_h - history_view.h, 0))
	box := gp_rect_formula_box(s.origin_x)
	if s.tile_node_count > 0 {
		gap := GP_TILE_GAP
		available := box.w - 32 - f32(s.tile_node_count - 1) * gap
		tile_w := available / f32(s.tile_node_count)
		s.tile_font_size = clamp(tile_w * 0.58, GP_TILE_FONT_MIN, GP_TILE_FONT_MAX)
		start_x := box.x + 16
		for i in 0 ..< s.tile_node_count {
			s.tree.nodes[s.tile_nodes[i]].rect = {
				start_x + f32(i) * (tile_w + gap),
				box.y + 25,
				tile_w,
				GP_TILE_H,
			}
		}
	}
	s.tree.nodes[s.apply_node].rect = gp_rect_apply(s.origin_x)
	s.tree.nodes[s.undo_node].rect = gp_rect_undo(s.origin_x)
	s.tree.nodes[s.restart_node].rect = gp_rect_restart(s.origin_x)
	s.tree.nodes[s.pause_node].rect = gp_rect_pause(s.origin_x)
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

@(private = "file")
gameplay_rebuild :: proc(s: ^Gameplay_State) {
	ctx := Context {
		viewport = s.viewport,
		renderer = {measure_text = s.measure},
	}
	layout_gameplay(s, &ctx)
	if s.tree.count > 0 { s.ix.focus = s.apply_node }
}

@(private = "file")
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
				s.selected_operator = -1
				workspace_toggle_term(&s.workspace, token.term)
				gameplay_rebuild(s)
			} else if token.kind == .Operator && label_str(&token.text) != "=" {
				if s.selected_operator == i {
					s.selected_operator = -1
				} else {
					s.selected_operator = i
				}
				// Operation and term scopes are mutually exclusive.
				s.workspace.selection = nil
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

// ============================================================================
// draw_gameplay
// ============================================================================
draw_gameplay :: proc(s: ^Gameplay_State, ctx: Context) {
	if s.tree.count == 0 { return } 	// never laid out
	v := Gp_View {
		s     = s,
		r     = ctx.renderer,
		scale = ctx.viewport.scale,
		size  = ctx.viewport.size,
	}

	gp_draw_background(&v)
	gp_draw_header(&v)
	gp_draw_stats(&v)
	gp_draw_title(&v)
	gp_draw_moves_panel(&v)
	gp_draw_formula_panel(&v)
	gp_draw_goal_panel(&v)
	gp_draw_history_panel(&v)
	if s.paused { gp_draw_pause_veil(&v) }
}

gp_text_width :: proc(
	measure: shared.Measure_Text,
	scale: f32,
	text: string,
	size: f32,
	font: shared.Font_Id,
) -> f32 {
	if measure == nil { return f32(len(text)) * size * 0.55 } 	// layout still works without a renderer
	return measure(text, i32(size * scale), font) / scale
}

gp_tab_rects :: proc(ox: f32) -> (rects: [4]shared.Rect) {
	total: f32 = 8 * 3
	for w in GP_TAB_WIDTHS { total += w }
	x := ox + 1408 - total
	for i in 0 ..< len(GP_TABS) {
		rects[i] = {x, 200, GP_TAB_WIDTHS[i], 30}
		x += GP_TAB_WIDTHS[i] + 8
	}
	return
}

// ============================================================================
// Panel geometry
// ============================================================================

gp_rect_moves :: proc(ox: f32) -> shared.Rect {
	return {ox + 32, GP_PANEL_TOP, 299, GP_PANEL_BOTTOM - GP_PANEL_TOP}
}

gp_rect_formula :: proc(ox: f32) -> shared.Rect {
	return {ox + 352, GP_PANEL_TOP, 699, 385}
}

gp_rect_goal :: proc(ox: f32) -> shared.Rect {
	return {ox + 352, 666, 699, GP_PANEL_BOTTOM - 666}
}

gp_rect_history :: proc(ox: f32) -> shared.Rect {
	return {ox + 1072, GP_PANEL_TOP, 336, GP_PANEL_BOTTOM - GP_PANEL_TOP}
}

@(private = "file")
GP_SCROLL_STEP :: f32(72)
GP_SCROLLBAR_MIN_THUMB :: f32(36)

// Returns the design-space viewport where transformation cards are clipped and hit-tested.
gp_moves_view_rect :: proc(ox: f32) -> shared.Rect {
	p := gp_rect_moves(ox)
	return {p.x + 12, p.y + 91, p.w - 24, p.h - 143}
}

// Returns the design-space viewport where history cards are clipped and hit-tested.
gp_history_view_rect :: proc(ox: f32) -> shared.Rect {
	p := gp_rect_history(ox)
	return {p.x + 12, p.y + 90, p.w - 24, p.h - 204}
}

@(private = "file")
gp_moves_content_height :: proc(count: int) -> f32 {
	if count <= 0 { return 0 }
	visible := min(count, GP_MOVES_VISIBLE_MAX)
	height := gp_card_height(visible)
	gap := gp_card_gap(visible)
	return 13 + f32(count) * (height + gap) - gap
}

@(private = "file")
gp_history_content_height :: proc(count: int) -> f32 {
	return max(f32(count) * 126 - 3, 0)
}

@(private = "file")
gp_moves_scroll_max :: proc(s: ^Gameplay_State) -> f32 {
	return max(gp_moves_content_height(s.move_node_count) - gp_moves_view_rect(s.origin_x).h, 0)
}

@(private = "file")
gp_history_scroll_max :: proc(s: ^Gameplay_State) -> f32 {
	return max(
		gp_history_content_height(s.workspace.entry_count) - gp_history_view_rect(s.origin_x).h,
		0,
	)
}

@(private = "file")
gp_moves_scrollbar_track :: proc(s: ^Gameplay_State) -> shared.Rect {
	view := gp_moves_view_rect(s.origin_x)
	return {view.x + view.w - 9, view.y, 9, view.h}
}

@(private = "file")
gp_history_scrollbar_track :: proc(s: ^Gameplay_State) -> shared.Rect {
	view := gp_history_view_rect(s.origin_x)
	return {view.x + view.w - 9, view.y, 9, view.h}
}

@(private = "file")
gp_scrollbar_thumb :: proc(
	track: shared.Rect,
	viewport_height, content_height, scroll, scroll_max: f32,
) -> shared.Rect {
	if scroll_max <= 0 || content_height <= 0 { return {} }
	thumb_h := clamp(track.h * viewport_height / content_height, GP_SCROLLBAR_MIN_THUMB, track.h)
	travel := track.h - thumb_h
	thumb_y := track.y + (scroll_max > 0 ? scroll / scroll_max : 0) * travel
	return {track.x - 1.5, thumb_y, track.w + 3, thumb_h}
}

@(private = "file")
gp_moves_scrollbar_thumb :: proc(s: ^Gameplay_State) -> shared.Rect {
	view := gp_moves_view_rect(s.origin_x)
	return gp_scrollbar_thumb(
		gp_moves_scrollbar_track(s),
		view.h,
		gp_moves_content_height(s.move_node_count),
		s.moves_scroll_y,
		gp_moves_scroll_max(s),
	)
}

@(private = "file")
gp_history_scrollbar_thumb :: proc(s: ^Gameplay_State) -> shared.Rect {
	view := gp_history_view_rect(s.origin_x)
	return gp_scrollbar_thumb(
		gp_history_scrollbar_track(s),
		view.h,
		gp_history_content_height(s.workspace.entry_count),
		s.history_scroll_y,
		gp_history_scroll_max(s),
	)
}

@(private = "file")
gp_begin_scrollbar_drag :: proc(s: ^Gameplay_State, position: shared.Vec2) -> bool {
	if gp_moves_scroll_max(s) > 0 {
		track := gp_moves_scrollbar_track(s)
		if shared.contains_point(track, position) {
			thumb := gp_moves_scrollbar_thumb(s)
			if !shared.contains_point(thumb, position) {
				travel := max(track.h - thumb.h, 1)
				ratio := clamp((position.y - track.y - thumb.h / 2) / travel, 0, 1)
				gp_set_moves_scroll(s, ratio * gp_moves_scroll_max(s))
			}
			s.scroll_drag = .Moves
			s.scroll_drag_y = position.y
			s.scroll_drag_start = s.moves_scroll_y
			return true
		}
	}
	if gp_history_scroll_max(s) > 0 {
		track := gp_history_scrollbar_track(s)
		if shared.contains_point(track, position) {
			thumb := gp_history_scrollbar_thumb(s)
			if !shared.contains_point(thumb, position) {
				travel := max(track.h - thumb.h, 1)
				ratio := clamp((position.y - track.y - thumb.h / 2) / travel, 0, 1)
				gp_set_history_scroll(s, ratio * gp_history_scroll_max(s))
			}
			s.scroll_drag = .History
			s.scroll_drag_y = position.y
			s.scroll_drag_start = s.history_scroll_y
			return true
		}
	}
	return false
}

@(private = "file")
gp_update_scrollbar_drag :: proc(s: ^Gameplay_State, pointer_y: f32) {
	if s.scroll_drag == .Moves {
		track := gp_moves_scrollbar_track(s)
		thumb := gp_moves_scrollbar_thumb(s)
		travel := max(track.h - thumb.h, 1)
		scroll_delta := (pointer_y - s.scroll_drag_y) * gp_moves_scroll_max(s) / travel
		gp_set_moves_scroll(s, s.scroll_drag_start + scroll_delta)
	} else if s.scroll_drag == .History {
		track := gp_history_scrollbar_track(s)
		thumb := gp_history_scrollbar_thumb(s)
		travel := max(track.h - thumb.h, 1)
		scroll_delta := (pointer_y - s.scroll_drag_y) * gp_history_scroll_max(s) / travel
		gp_set_history_scroll(s, s.scroll_drag_start + scroll_delta)
	}
}

@(private = "file")
gp_set_moves_scroll :: proc(s: ^Gameplay_State, offset: f32) {
	previous := s.moves_scroll_y
	s.moves_scroll_y = clamp(offset, 0, gp_moves_scroll_max(s))
	core.ui_scroll_nodes_by(&s.tree, s.move_nodes[:s.move_node_count], s.moves_scroll_y - previous)
}

@(private = "file")
gp_set_history_scroll :: proc(s: ^Gameplay_State, offset: f32) {
	s.history_scroll_y = clamp(offset, 0, gp_history_scroll_max(s))
}

@(private = "file")
gp_is_move_node :: proc(s: ^Gameplay_State, node: int) -> bool {
	for move_node in s.move_nodes[:s.move_node_count] {
		if move_node == node { return true }
	}
	return false
}

gp_rect_formula_box :: proc(ox: f32) -> shared.Rect {
	p := gp_rect_formula(ox)
	return {p.x + 24, p.y + 86, p.w - 48, 115}
}

gp_rect_apply :: proc(ox: f32) -> shared.Rect {
	p := gp_rect_formula(ox)
	return {p.x + 470, p.y + 294, 206, 51}
}

gp_rect_target :: proc(ox: f32) -> shared.Rect {
	p := gp_rect_goal(ox)
	return {p.x + 472, p.y + 26, 203, 100}
}

gp_rect_undo :: proc(ox: f32) -> shared.Rect {
	return {ox + 1094, 754, 142, 40}
}

gp_rect_restart :: proc(ox: f32) -> shared.Rect {
	return {ox + 1248, 754, 138, 40}
}

gp_rect_pause :: proc(ox: f32) -> shared.Rect {
	return {ox + 1337, 98, 47, 47}
}

gp_card_height :: proc(visible: int) -> f32 {
	return visible <= 3 ? 122 : 98
}

gp_card_gap :: proc(visible: int) -> f32 {
	return visible <= 3 ? 18 : 12
}

// slot == zero-based position in the full transformations list.
gp_move_card_rect :: proc(ox: f32, slot, count: int) -> shared.Rect {
	p := gp_rect_moves(ox)
	card_count := min(count, GP_MOVES_VISIBLE_MAX)
	h := gp_card_height(card_count)
	return {p.x + 22, 365 + f32(slot) * (h + gp_card_gap(card_count)), p.w - 44, h}
}

gp_history_card_rect :: proc(ox: f32, slot: int) -> shared.Rect {
	p := gp_rect_history(ox)
	return {p.x + 22, 366 + f32(slot) * 126, p.w - 44, 108}
}

@(private = "file")
gp_load_font :: proc(ctx: ^Context, path: cstring, fallback: shared.Font_Id) -> shared.Font_Id {
	if ctx.load_font == nil { return fallback }
	id, ok := ctx.load_font(path, 64)
	if ok && id != shared.INVALID_FONT_ID { return id }
	log.infof("Font %s unavailable, using fallback", path)
	return fallback
}

@(private = "file")
gp_draw_background :: proc(v: ^Gp_View) {
	full := shared.Rect{0, 0, v.size.x, v.size.y}
	v.r.fill_rect(full, GP_BG)
	if v.s.background != shared.INVALID_TEXTURE_ID {
		v.r.draw_texture(v.s.background, full, {255, 255, 255, 38})
	}
}

@(private = "file")
gp_draw_header :: proc(v: ^Gp_View) {
	s := v.s
	ox := s.origin_x
	design_w := s.design.x
	gp_fill(v, {0, 0, design_w, GP_HEADER_H}, GP_BAR)
	gp_hline(v, 0, GP_HEADER_H - 1, design_w, GP_DIVIDER)

	gp_ring(v, ox + 65, 38, 16, 2, GP_AMBER)
	gp_text(v, "FORMULA ARCANA", ox + 97, 37, 19, GP_TEXT, s.fonts.display)

	buf: [64]u8
	gp_text(v, format_mode_tag(s.run, buf[:]), ox + 1392, 38, 12, GP_TEAL, s.fonts.mono, .End)
}

@(private = "file")
gp_draw_stats :: proc(v: ^Gp_View) {
	s := v.s
	ox := s.origin_x
	gp_fill(v, {0, GP_HEADER_H, s.design.x, GP_STATS_BOTTOM - GP_HEADER_H}, GP_BAR)
	gp_hline(v, 0, GP_STATS_BOTTOM - 1, s.design.x, GP_DIVIDER)

	buf: [64]u8
	left, bar_w := ox + 56, f32(380)
	gp_text(v, format_round(s.run, buf[:]), left, 116, 11, GP_TEAL, s.fonts.mono)
	gp_text(v, format_progress(s.run, buf[:]), left + bar_w, 116, 11, GP_MUTED, s.fonts.mono, .End)
	gp_fill(v, {left, 132, bar_w, 5}, GP_DIVIDER)
	gp_fill(v, {left, 132, bar_w * progress_fraction(s.run), 5}, GP_GREEN)

	gp_text(v, "SCORE", ox + 652, 107, 10, GP_MUTED, s.fonts.mono)
	gp_text(v, format_score(s.run.score, buf[:]), ox + 652, 132, 21, GP_TEAL_SOFT, s.fonts.mono)
	gp_text(v, "STREAK", ox + 826, 107, 10, GP_MUTED, s.fonts.mono)
	gp_text(v, format_streak(s.run.streak, buf[:]), ox + 826, 132, 21, GP_OP_TEXT, s.fonts.mono)
	gp_text(v, "TIME", ox + 1001, 107, 10, GP_MUTED, s.fonts.mono)
	gp_text(v, format_time(s.elapsed, buf[:]), ox + 1001, 132, 21, GP_AMBER, s.fonts.mono)

	// Pause button: two bars; amber while paused.
	node := s.pause_node
	r := s.tree.nodes[node].rect
	border := s.paused ? GP_AMBER : GP_AMBER_DIM
	fill := shared.Color{10, 30, 40, 255}
	#partial switch core.button_visual(s.ix, node) {
	case .Hover, .Focused: fill = {16, 44, 56, 255}
	case .Pressed: fill = {6, 20, 28, 255}
	}
	gp_box(v, r, fill, border, 1.5)
	bar_h := r.h * 0.42
	gp_fill(v, {r.x + r.w * 0.34, r.y + (r.h - bar_h) / 2, 4, bar_h}, GP_TEXT)
	gp_fill(v, {r.x + r.w * 0.58, r.y + (r.h - bar_h) / 2, 4, bar_h}, GP_TEXT)
}

@(private = "file")
gp_draw_title :: proc(v: ^Gp_View) {
	s := v.s
	ox := s.origin_x
	title_size := gp_fit(v, s.puzzle.title, 26, 640, 16, s.fonts.display)
	gp_text(v, s.puzzle.title, ox + 32, 210, title_size, GP_TEXT, s.fonts.display)
	gp_text(v, s.puzzle.brief, ox + 32, 237, 14, GP_MUTED, s.fonts.ui)

	tabs := gp_tab_rects(ox)
	for i in 0 ..< len(GP_TABS) {
		active := GP_TABS[i] == s.puzzle.category
		if active {
			gp_box(v, tabs[i], GP_TEAL_FILL, GP_TEAL)
		} else {
			gp_box(v, tabs[i], GP_PANEL, GP_PANEL_BORDER)
		}
		gp_text(
			v,
			GP_TABS[i],
			tabs[i].x + tabs[i].w / 2,
			tabs[i].y + tabs[i].h / 2,
			11,
			active ? GP_TEAL_SOFT : GP_MUTED,
			s.fonts.mono,
			.Center,
		)
	}
}

// ---- Left: valid transformations -----------------------------------------------

@(private = "file")
gp_draw_moves_panel :: proc(v: ^Gp_View) {
	s := v.s
	w := &s.workspace
	p := gp_rect_moves(s.origin_x)
	gp_panel(v, p)

	x := p.x + 22
	gp_text(v, "VALID TRANSFORMATIONS", x, p.y + 33, 17, GP_TEXT, s.fonts.display)
	buf: [64]u8
	gp_text(
		v,
		format_valid_moves(w.moves.count, w.selection != nil, buf[:]),
		x,
		p.y + 61,
		12,
		GP_MUTED,
		s.fonts.ui,
	)
	gp_hline(v, x, p.y + 83, p.w - 44, GP_DIVIDER)

	if w.entry_count > 0 {
		eq := workspace_current(w)
		gp_begin_panel_clip(v, gp_moves_view_rect(s.origin_x))
		for index in 0 ..< s.move_node_count {
			gp_draw_move_card(v, &eq, index)
		}
		gp_end_panel_clip(v)
		if gp_moves_scroll_max(s) > 0 {
			gp_draw_scrollbar(v, gp_moves_scrollbar_track(s), gp_moves_scrollbar_thumb(s))
		}
	}

	gp_text(v, GP_FOOTNOTE, x, p.y + p.h - 39, 11, GP_MUTED, s.fonts.ui)
}

@(private = "file")
gp_draw_move_card :: proc(v: ^Gp_View, eq: ^Equation, index: int) {
	s := v.s
	w := &s.workspace
	node := s.move_nodes[index]
	r := s.tree.nodes[node].rect
	selected := index == w.selected_move
	vis := core.button_visual(s.ix, node)

	box := r
	if selected {
		box.x -= 8 // the selected card pops out of the column
		box.w += 16
	}
	fill, border := GP_CARD, GP_CARD_BORDER
	thickness := f32(1)
	if selected {
		fill, border, thickness = GP_TEAL_FILL, GP_TEAL, 1.5
	} else if vis == .Hover || vis == .Pressed {
		border = GP_TEAL_DIM
	}
	gp_box(v, box, fill, border, thickness)

	view := describe_move(eq^, w.moves.items[index])
	compact := r.h < 110
	x := r.x + 16
	tag_y := r.y + (compact ? 14 : 18)
	title_y := r.y + (compact ? 36 : 43)
	rule_y := r.y + (compact ? 64 : 72)

	buf: [16]u8
	if workspace_is_recommended(w, index) {
		gp_text(v, "RECOMMENDED", x, tag_y, 10, GP_TEAL, s.fonts.mono)
	} else {
		gp_text(v, format_index(index + 1, buf[:]), x, tag_y, 10, GP_MUTED, s.fonts.mono)
	}
	if selected {
		gp_text(v, "SELECTED", r.x + r.w - 16, tag_y, 10, GP_TEAL, s.fonts.mono, .End)
	}

	title := label_str(&view.title)
	gp_text(v, title, x, title_y, 17, GP_TEXT, s.fonts.ui)
	gp_text(v, label_str(&view.rule), x, rule_y, 10, GP_AMBER, s.fonts.math)
	if view.rule_2.len > 0 {
		gp_text(v, label_str(&view.rule_2), x, rule_y + 16, 10, GP_AMBER, s.fonts.math)
	}
	if !compact {
		gp_text(v, label_str(&view.hint), x, r.y + 102, 11, GP_MUTED, s.fonts.ui)
	}
}

// ---- Center: current formula, preview, apply -----------------------------------

@(private = "file")
gp_draw_formula_panel :: proc(v: ^Gp_View) {
	s := v.s
	w := &s.workspace
	ox := s.origin_x
	p := gp_rect_formula(ox)
	gp_panel(v, p)

	x := p.x + 24
	buf: [64]u8
	solved := w.entry_count > 0 && workspace_solved(w)

	gp_text(v, "CURRENT FORMULA", x, p.y + 30, 11, GP_TEAL, s.fonts.mono)
	gp_text(
		v,
		format_step(workspace_step(w), buf[:]),
		p.x + p.w - 55,
		p.y + 30,
		11,
		GP_MUTED,
		s.fonts.mono,
		.End,
	)
	hint := "Select a term or operator to inspect it."
	if w.selection != nil { hint = "Click the term again to return to the whole equation." }
	if s.selected_operator >= 0 {
		token := s.tokens.items[s.selected_operator]
		hint_buf: [64]u8
		hint = fmt.bprintf(hint_buf[:], "Selected operation: %s · click again to clear", label_str(&token.text))
	}
	gp_text(v, hint, x, p.y + 56, 13, GP_TEXT, s.fonts.ui)

	// Formula box + tiles
	box := gp_rect_formula_box(ox)
	gp_box(v, box, {5, 16, 24, 255}, solved ? GP_GREEN : GP_TEAL, 1.5)
	gp_draw_tiles(v)

	// Legend
	ly := p.y + 231
	gp_text(v, "x", p.x + 38, ly, 18, GP_VAR, s.fonts.math_italic, .Center)
	gp_fill(v, {p.x + 30, ly + 10, 16, 1.5}, GP_VAR)
	gp_text(v, "Variable", p.x + 56, ly, 12, GP_MUTED, s.fonts.ui)
	gp_box(v, {p.x + 149, ly - 12, 24, 24}, GP_TILE_CONST, GP_TILE_CONST)
	gp_text(v, "7", p.x + 161, ly, 15, GP_AMBER, s.fonts.math, .Center)
	gp_text(v, "Constant", p.x + 180, ly, 12, GP_MUTED, s.fonts.ui)
	gp_box(v, {p.x + 272, ly - 12, 24, 24}, GP_TILE_OP, GP_TILE_OP)
	gp_text(v, "+", p.x + 284, ly, 15, GP_OP_TEXT, s.fonts.math, .Center)
	gp_text(v, "Operator", p.x + 304, ly, 12, GP_MUTED, s.fonts.ui)
	scope := w.selection != nil ? "SCOPE: TERM" : (s.selected_operator >= 0 ? "SCOPE: OPERATION" : "SCOPE: EQUATION")
	gp_text(v, scope, p.x + 634, ly, 10, GP_TEAL, s.fonts.mono, .End)
	gp_hline(v, x, p.y + 261, p.w - 48, GP_DIVIDER)

	gp_draw_preview(v, p, solved)
}

@(private = "file")
gp_draw_tiles :: proc(v: ^Gp_View) {
	s := v.s
	w := &s.workspace
	fs := s.tile_font_size
	for i in 0 ..< s.tile_node_count {
		token := &s.tokens.items[i]
		node := s.tile_nodes[i]
		r := s.tree.nodes[node].rect
		text := label_str(&token.text)
		cx, cy := r.x + r.w / 2, r.y + r.h / 2

	selectable := token.term != NO_EXPR || (token.kind == .Operator && label_str(&token.text) != "=")
		selected := s.selected_operator == i
		if sel, ok := w.selection.?; ok && selectable { selected = token.term == sel }
		vis := core.button_visual(s.ix, node)
		hovered := selectable && (vis == .Hover || vis == .Pressed)

		switch token.kind {
		case .Constant:
			gp_fill(v, r, GP_TILE_CONST)
			gp_text(v, text, cx, cy, fs, GP_AMBER, s.fonts.math, .Center)
		case .Operator:
			gp_fill(v, r, GP_TILE_OP)
			gp_text(v, text, cx, cy, fs, GP_OP_TEXT, s.fonts.math, .Center)
		case .Variable:
			gp_text(v, text, cx, cy, fs, GP_VAR, s.fonts.math_italic, .Center)
			underline := r.w * 0.55
			gp_fill(v, {cx - underline / 2, r.y + r.h - 8, underline, 1.5}, GP_VAR)
		case .Paren: gp_text(v, text, cx, cy, fs, GP_TEAL_SOFT, s.fonts.math, .Center)
		}
		if selected {
			gp_outline(v, r, 2, GP_TEAL)
		} else if hovered {
			gp_outline(v, r, 1, GP_TEAL_DIM)
		}
	}
}

@(private = "file")
gp_draw_preview :: proc(v: ^Gp_View, p: shared.Rect, solved: bool) {
	s := v.s
	w := &s.workspace
	x := p.x + 24

	heading, result: string
	show_note := false
	view: Move_View
	rbuf: [LABEL_CAP * 2]u8
	enabled := false
	switch {
	case w.entry_count == 0: heading = "NO FORMULA"
	case solved:
		heading = "TARGET REACHED"
		result = format_equation(workspace_current(w), rbuf[:])
	case w.moves.count >  0 && w.selected_move < w.moves.count:
		move := w.moves.items[w.selected_move]
		view = describe_move(workspace_current(w), move)
		heading = label_str(&view.heading)
		if preview, ok := workspace_preview(w); ok { result = format_equation(preview, rbuf[:]) }
		show_note = true
		enabled = !s.paused && w.selection != nil
	case: heading = "NO VALID MOVE"
	}

	gp_text(v, heading, x, p.y + 287, 11, GP_TEAL, s.fonts.mono)
	result_size := gp_fit(v, result, 32, 220, 18, s.fonts.math)
	gp_text(v, result, x, p.y + 326, result_size, GP_TEAL_SOFT, s.fonts.math)
	if show_note {
		gp_text(v, EQUIVALENCE_NOTE, p.x + 232, p.y + 330, 11, GP_MUTED, s.fonts.ui)
	}

	// Apply button
	node := s.apply_node
	r := s.tree.nodes[node].rect
	fill, border, label := shared.Color{14, 70, 78, 255}, GP_TEAL, GP_TEXT
	if !enabled {
		fill, border, label = {10, 28, 36, 255}, GP_DISABLED, GP_DISABLED
	} else {
		switch core.button_visual(s.ix, node) {
		case .Hover, .Focused: fill = {20, 90, 98, 255}
		case .Pressed: fill = {10, 52, 58, 255}
		case .Rest:
		}
	}
	gp_box(v, r, fill, border, 1.5)
	gp_text(
		v,
		"APPLY TRANSFORM",
		r.x + r.w / 2,
		r.y + r.h / 2,
		13,
		label,
		s.fonts.display,
		.Center,
	)

	gp_text(
		v,
		"Preview only · history updates after applying",
		x,
		p.y + 366,
		11,
		GP_MUTED,
		s.fonts.ui,
	)
}

// ---- Bottom center: end goal -----------------------------------------------------

@(private = "file")
gp_draw_goal_panel :: proc(v: ^Gp_View) {
	s := v.s
	p := gp_rect_goal(s.origin_x)
	gp_panel(v, p)
	x := p.x + 24
	solved := s.workspace.entry_count > 0 && workspace_solved(&s.workspace)

	gp_text(v, "END GOAL", x, p.y + 30, 11, GP_TEAL, s.fonts.mono)
	gp_text(v, s.puzzle.objective, x, p.y + 60, 19, GP_TEXT, s.fonts.display)
	gp_text(v, s.puzzle.rule, x, p.y + 89, 13, GP_MUTED, s.fonts.ui)

	t := gp_rect_target(s.origin_x)
	gp_box(v, t, {8, 44, 40, 255}, solved ? GP_GREEN : GP_TEAL, 1.5)
	cx := t.x + t.w / 2
	goal_size := gp_fit(v, s.puzzle.goal, 42, t.w - 24, 20, s.fonts.math)
	gp_text(v, s.puzzle.goal, cx, t.y + 47, goal_size, GP_TEAL_SOFT, s.fonts.math, .Center)
	gp_text(v, "TARGET STATE", cx, t.y + 85, 10, GP_TEAL, s.fonts.mono, .Center)

	gp_text(v, "COMPLETION RULE", x, p.y + 135, 11, GP_TEAL, s.fonts.mono)
	gp_text(v, s.puzzle.completion_rule, x, p.y + 159, 12, GP_TEXT, s.fonts.ui)
}

// ---- Right: history -----------------------------------------------------------------

@(private = "file")
gp_draw_history_panel :: proc(v: ^Gp_View) {
	s := v.s
	w := &s.workspace
	ox := s.origin_x
	p := gp_rect_history(ox)
	gp_panel(v, p)

	x := p.x + 22
	buf: [64]u8
	gp_text(v, "TRANSFORMATION HISTORY", x, p.y + 33, 17, GP_TEXT, s.fonts.display)
	gp_text(v, "Every step, preserved.", x, p.y + 61, 12, GP_MUTED, s.fonts.ui)
	badge := shared.Rect{p.x + 252, p.y + 49, 62, 25}
	gp_box(v, badge, {10, 50, 56, 255}, GP_TEAL_DIM)
	gp_text(
		v,
		format_move_count(max(workspace_step(w), 0), buf[:]),
		badge.x + badge.w / 2,
		badge.y + badge.h / 2,
		10,
		GP_TEAL,
		s.fonts.mono,
		.Center,
	)
	gp_hline(v, x, p.y + 83, p.w - 44, GP_DIVIDER)

	gp_begin_panel_clip(v, gp_history_view_rect(ox))
	for i in 0 ..< w.entry_count {
		gp_draw_history_card(v, i, i)
	}
	gp_end_panel_clip(v)
	if gp_history_scroll_max(s) > 0 {
		gp_draw_scrollbar(v, gp_history_scrollbar_track(s), gp_history_scrollbar_thumb(s))
	}

	gp_draw_footer_button(v, s.undo_node, "UNDO LAST", w.entry_count > 1 && !s.paused)
	gp_draw_footer_button(v, s.restart_node, "RESTART", w.entry_count > 1 && !s.paused)
}

@(private = "file")
gp_draw_history_card :: proc(v: ^Gp_View, index, slot: int) {
	s := v.s
	w := &s.workspace
	r := gp_history_card_rect(s.origin_x, slot)
	r.y -= s.history_scroll_y
	current := index == w.entry_count - 1
	if current {
		gp_box(v, r, GP_TEAL_FILL, GP_TEAL, 1.5)
	} else {
		gp_box(v, r, GP_CARD, GP_CARD_BORDER)
	}

	entry := &w.entries[index]
	buf: [16]u8
	badge := shared.Rect{r.x + 14, r.y + 16, 22, 17}
	gp_box(v, badge, {6, 18, 26, 255}, current ? GP_TEAL_DIM : GP_CARD_BORDER)
	gp_text(
		v,
		format_index(index, buf[:]),
		badge.x + badge.w / 2,
		badge.y + badge.h / 2,
		10,
		GP_MUTED,
		s.fonts.mono,
		.Center,
	)

	tx := r.x + 50
	gp_text(v, label_str(&entry.title), tx, r.y + 21, 14, GP_TEXT, s.fonts.ui)
	tag := "APPLIED"
	if index == 0 {
		tag = "STARTING STATE"
	} else if current {
		tag = "CURRENT"
	}
	gp_text(v, tag, tx, r.y + 40, 10, current ? GP_TEAL : GP_MUTED, s.fonts.mono)

	ebuf: [LABEL_CAP * 2]u8
	text := format_equation(entry.equation, ebuf[:])
	size := gp_fit(v, text, 22, r.w - 28, 12, s.fonts.math)
	gp_text(v, text, r.x + 14, r.y + 62, size, GP_AMBER, s.fonts.math)
	gp_text(v, label_str(&entry.note), r.x + 14, r.y + 94, 11, GP_MUTED, s.fonts.ui)
}

@(private = "file")
gp_draw_footer_button :: proc(v: ^Gp_View, node: int, label: string, enabled: bool) {
	r := v.s.tree.nodes[node].rect
	fill, border, text := GP_CARD, GP_PANEL_BORDER, GP_TEXT
	if !enabled {
		text = GP_DISABLED
	} else {
		#partial switch core.button_visual(v.s.ix, node) {
		case .Hover, .Focused: border = GP_TEAL_DIM
		case .Pressed: fill = {6, 20, 28, 255}
		}
	}
	gp_box(v, r, fill, border)
	gp_text(v, label, r.x + r.w / 2, r.y + r.h / 2, 11, text, v.s.fonts.mono, .Center)
}

// ---- Pause --------------------------------------------------------------------------

@(private = "file")
gp_draw_pause_veil :: proc(v: ^Gp_View) {
	s := v.s
	v.r.fill_rect({0, GP_STATS_BOTTOM * v.scale, v.size.x, v.size.y}, GP_VEIL)
	p := gp_rect_formula(s.origin_x)
	cx, cy := p.x + p.w / 2, p.y + p.h / 2
	gp_text(v, "PAUSED", cx, cy - 8, 40, GP_TEXT, s.fonts.display, .Center)
	gp_text(v, "Click the pause button to resume", cx, cy + 30, 13, GP_MUTED, s.fonts.ui, .Center)
	// Keep the pause button itself readable and obviously clickable.
	gp_draw_stats_pause_only(v)
}

@(private = "file")
gp_draw_stats_pause_only :: proc(v: ^Gp_View) {
	r := v.s.tree.nodes[v.s.pause_node].rect
	gp_box(v, r, {16, 44, 56, 255}, GP_AMBER, 1.5)
	bar_h := r.h * 0.42
	gp_fill(v, {r.x + r.w * 0.34, r.y + (r.h - bar_h) / 2, 4, bar_h}, GP_TEXT)
	gp_fill(v, {r.x + r.w * 0.58, r.y + (r.h - bar_h) / 2, 4, bar_h}, GP_TEXT)
}

@(private = "file")
gp_scaled :: proc(v: ^Gp_View, r: shared.Rect) -> shared.Rect {
	k := v.scale
	return {r.x * k, r.y * k, r.w * k, r.h * k}
}

@(private = "file")
gp_draw_scrollbar :: proc(v: ^Gp_View, track, thumb: shared.Rect) {
	gp_fill(v, track, {5, 14, 21, 255})
	gp_box(v, thumb, GP_TEAL_DIM, GP_TEAL)
}

@(private = "file")
gp_begin_panel_clip :: proc(v: ^Gp_View, r: shared.Rect) {
	if v.r.begin_clip != nil { v.r.begin_clip(gp_scaled(v, r)) }
}

@(private = "file")
gp_end_panel_clip :: proc(v: ^Gp_View) {
	if v.r.end_clip != nil { v.r.end_clip() }
}

@(private = "file")
gp_fill :: proc(v: ^Gp_View, r: shared.Rect, c: shared.Color) {
	v.r.fill_rect(gp_scaled(v, r), c)
}

@(private = "file")
gp_outline :: proc(v: ^Gp_View, r: shared.Rect, thickness: f32, c: shared.Color) {
	v.r.outline_rect(gp_scaled(v, r), thickness * v.scale, c)
}

@(private = "file")
gp_box :: proc(v: ^Gp_View, r: shared.Rect, fill, border: shared.Color, thickness: f32 = 1) {
	gp_fill(v, r, fill)
	gp_outline(v, r, thickness, border)
}

@(private = "file")
gp_hline :: proc(v: ^Gp_View, x, y, w: f32, c: shared.Color) {
	gp_fill(v, {x, y, w, 1}, c)
}

// No circle primitive exists, so a ring is a polyline of small squares.
@(private = "file")
gp_ring :: proc(v: ^Gp_View, cx, cy, radius, thick: f32, c: shared.Color) {
	STEPS :: 72
	for i in 0 ..< STEPS {
		a := f32(i) / STEPS * 2 * math.PI
		gp_fill(
			v,
			{
				cx + math.cos(a) * radius - thick / 2,
				cy + math.sin(a) * radius - thick / 2,
				thick,
				thick,
			},
			c,
		)
	}
}

@(private = "file")
gp_measure :: proc(v: ^Gp_View, text: string, size: f32, font: shared.Font_Id) -> f32 {
	return gp_text_width(v.r.measure_text, v.scale, text, size, font)
}

// (x, y) = anchor point; y is the vertical CENTRE of the line. `align` says what x means.
@(private = "file")
gp_text :: proc(
	v: ^Gp_View,
	text: string,
	x, y, size: f32,
	color: shared.Color,
	font: shared.Font_Id,
	align: core.Alignment = .Start,
) {
	if len(text) == 0 { return }
	px := x
	switch align {
	case .Start:
	case .Center: px = x - gp_measure(v, text, size, font) / 2
	case .End: px = x - gp_measure(v, text, size, font)
	}
	v.r.draw_text(text, {px * v.scale, (y - size / 2) * v.scale}, i32(size * v.scale), color, font)
}

// Largest size <= `size` (never below `min_size`) at which `text` fits in `max_w`.
@(private = "file")
gp_fit :: proc(
	v: ^Gp_View,
	text: string,
	size, max_w, min_size: f32,
	font: shared.Font_Id,
) -> f32 {
	fs := size
	for fs > min_size && gp_measure(v, text, fs, font) > max_w { fs -= 1 }
	return fs
}

@(private = "file")
gp_panel :: proc(v: ^Gp_View, r: shared.Rect) {
	gp_box(v, r, GP_PANEL, GP_PANEL_BORDER)
}
