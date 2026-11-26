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

Gameplay_No_Animation :: struct {}

Gameplay_Distribution_Animation :: struct {
	source_tokens:    Token_List,
	multiplier_index: int,
	target_indices:   [MAX_TERMS]int,
	target_count:     int,
}

Gameplay_Magnet_Animation :: struct {
	source_tokens:       Token_List,
	result_tokens:       Token_List,
	source_indices:      [MAX_TOKENS]int,
	destination_indices: [MAX_TOKENS]int,
	pair_count:          int,
}

Gameplay_Swap_Animation :: struct {
	source_tokens: Token_List,
	result_tokens: Token_List,
	swap_start:    int, // first token of the swapped region
	swap_a_len:    int, // tokens in term A (left of the operator)
	swap_b_len:    int, // tokens in term B (right of the operator)
}

Gameplay_Animation_Payload :: union {
	Gameplay_No_Animation,
	Gameplay_Distribution_Animation,
	Gameplay_Magnet_Animation,
	Gameplay_Swap_Animation, // Commute: term A and term B orbit into each other's slot
}

Gameplay_Animation :: struct {
	elapsed:  f32,
	duration: f32,
	source:   Equation,
	result:   Equation,
	payload:  Gameplay_Animation_Payload,
}

GP_DISTRIBUTION_PASS_DURATION :: f32(0.52)
GP_DISTRIBUTION_SETTLE_DURATION :: f32(0.24)
GP_SWAP_DURATION :: f32(0.9)

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
	formula_animation: Gameplay_Animation,
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
		case shared.Tick_Input: if !s.paused {
					dt := max(input.dt, 0)
					if !workspace_solved(&s.workspace) { s.elapsed += dt }
					if s.formula_animation.duration > 0 {
						s.formula_animation.elapsed += dt
						if s.formula_animation.elapsed >= s.formula_animation.duration {
							s.formula_animation = {}
						}
					}
				}
		case shared.Key_Input: switch input.key {
				case .Back: return core.Go_Level_Select{difficulty = .Normal}
				case .Pause: s.paused = !s.paused
				case .Undo: if !s.paused {
							s.formula_animation = {}
							if workspace_undo(&s.workspace) { gameplay_rebuild(s) }
						}
				case .Up:
					workspace_step_selection(&s.workspace, -1)
					gameplay_rebuild(s)
				case .Down:
					workspace_step_selection(&s.workspace, 1)
					gameplay_rebuild(s)
				case .Confirm: if !s.paused { _ = gameplay_apply_selected(s) }
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
	case s.apply_node: _ = gameplay_apply_selected(s)
	case s.undo_node:
		s.formula_animation = {}
		if workspace_undo(&s.workspace) { gameplay_rebuild(s) }
	case s.restart_node:
		s.formula_animation = {}
		workspace_restart(&s.workspace); s.elapsed = 0; gameplay_rebuild(s)
	case s.pause_node: s.paused = true
	}
}

gameplay_apply_selected :: proc(s: ^Gameplay_State) -> bool {
	if s.workspace.selected_move < 0 ||
	   s.workspace.selected_move >= s.workspace.moves.count { return false }
	before := workspace_current(&s.workspace)
	move := s.workspace.moves.items[s.workspace.selected_move]
	s.formula_animation = {}
	if !workspace_apply(&s.workspace) { return false }
	animation := Gameplay_Animation {
		source = before,
		result = workspace_current(&s.workspace),
	}
	if move.kind == .Distribute {
		distribution := Gameplay_Distribution_Animation {
			multiplier_index = -1,
		}
		gameplay_prepare_formula_animation(&distribution, before, move)
		if distribution.target_count > 0 {
			animation.duration =
				f32(distribution.target_count) * GP_DISTRIBUTION_PASS_DURATION +
				GP_DISTRIBUTION_SETTLE_DURATION
			animation.payload = distribution
			s.formula_animation = animation
		}
	} else if move.kind == .Combine_Constants ||
	   move.kind == .Combine_Like_Terms ||
	   move.kind == .Add_To_Both ||
	   move.kind == .Subtract_From_Both {
		magnet: Gameplay_Magnet_Animation
		gameplay_prepare_magnet_animation(&magnet, before, animation.result, move)
		if magnet.pair_count > 0 {
			animation.duration = 0.72
			animation.payload = magnet
			s.formula_animation = animation
		}
	} else if move.kind == .Commute {
		swap: Gameplay_Swap_Animation
		gameplay_prepare_swap_animation(&swap, before, animation.result)
		if swap.swap_a_len > 0 {
			animation.duration = GP_SWAP_DURATION
			animation.payload = swap
			s.formula_animation = animation
		}
	}
	s.history_scroll_y = gp_history_scroll_max(s)
	gameplay_rebuild(s)
	return true
}

gameplay_prepare_formula_animation :: proc(
	animation: ^Gameplay_Distribution_Animation,
	source: Equation,
	move: Move,
) {
	animation.source_tokens = tokenize(source)
	open_index := -1
	for i in 0 ..< animation.source_tokens.count {
		token := animation.source_tokens.items[i]
		if token.term == move.target && token.kind == .Paren && label_str(&token.text) == "(" {
			open_index = i
			break
		}
	}
	if open_index < 0 { return }

	for i := open_index - 1; i >= 0; i -= 1 {
		token := animation.source_tokens.items[i]
		if token.kind == .Operator { continue }
		if token.term == move.target { animation.multiplier_index = i }
		break
	}
	if animation.multiplier_index < 0 { return }

	first := open_index + 1
	for first < animation.source_tokens.count &&
	    animation.source_tokens.items[first].kind == .Operator {
		first += 1
	}
	if first >= animation.source_tokens.count { return }
	animation.target_indices[animation.target_count] = first
	animation.target_count += 1

	depth := 1
	for i := open_index + 1; i < animation.source_tokens.count; i += 1 {
		token := animation.source_tokens.items[i]
		if token.kind == .Paren {
			text := label_str(&token.text)
			if text == "(" { depth += 1 }
			if text == ")" { depth -= 1 }
			if depth == 0 { break }
		}
		if depth == 1 && token.kind == .Operator {
			text := label_str(&token.text)
			if text != "+" && text != "−" { continue }
			next := i + 1
			for next < animation.source_tokens.count &&
			    animation.source_tokens.items[next].kind == .Operator {
				next += 1
			}
			if next < animation.source_tokens.count && animation.target_count < MAX_TERMS {
				animation.target_indices[animation.target_count] = next
				animation.target_count += 1
			}
		}
	}
}

gameplay_prepare_magnet_animation :: proc(
	animation: ^Gameplay_Magnet_Animation,
	source, result: Equation,
	move: Move,
) {
	animation.source_tokens = tokenize(source)
	animation.result_tokens = tokenize(result)
	mapping := move_animation_map(source, result, move)
	for pair in mapping.pairs[:mapping.count] {
		animation.source_indices[animation.pair_count] = pair.source_token
		animation.destination_indices[animation.pair_count] = pair.destination_token
		animation.pair_count += 1
	}
}

gp_token_same :: proc(a, b: Token) -> bool {
	x, y := a, b
	return a.kind == b.kind && label_str(&x.text) == label_str(&y.text)
}

// A constant/variable token glued to its neighbour (the "2" in "2x") belongs to the same term.
gp_token_is_atom :: proc(t: Token) -> bool {
	return t.kind == .Constant || t.kind == .Variable
}

// A Commute turns `A op B` into `B op A`. Rather than trust token->term ids, find the
// two blocks by diffing the token streams (same token count, only the region moves):
//
//   source: [ A: start .. start+a_len )  OP  [ B: .. start+a_len+1+b_len )
//   result: [ B ]                        OP  [ A ]
//
// Leaves swap_a_len == 0 (no animation, the result just appears) if nothing matches.
gameplay_prepare_swap_animation :: proc(
	animation: ^Gameplay_Swap_Animation,
	source, result: Equation,
) {
	animation.source_tokens = tokenize(source)
	animation.result_tokens = tokenize(result)
	src, res := &animation.source_tokens, &animation.result_tokens
	if src.count != res.count || src.count < 3 { return }

	lo, hi := -1, -1
	for i in 0 ..< src.count {
		if !gp_token_same(src.items[i], res.items[i]) {
			if lo < 0 { lo = i }
			hi = i
		}
	}
	if lo < 0 { return } 	// A and B look identical: nothing to show
	for lo > 0 && gp_token_is_atom(src.items[lo - 1]) { lo -= 1 }
	for hi + 1 < src.count && gp_token_is_atom(src.items[hi + 1]) { hi += 1 }

	n := hi - lo + 1
	for a_len in 1 ..< n - 1 {
		b_len := n - a_len - 1
		op := lo + a_len
		if src.items[op].kind != .Operator { continue }
		if !gp_token_same(src.items[op], res.items[lo + b_len]) { continue }

		ok := true
		for k in 0 ..< b_len {
			if !gp_token_same(src.items[op + 1 + k], res.items[lo + k]) { ok = false; break }
		}
		if ok {
			for k in 0 ..< a_len {
				if !gp_token_same(src.items[lo + k], res.items[lo + b_len + 1 + k]) {
					ok = false
					break
				}
			}
		}
		if ok {
			animation.swap_start = lo
			animation.swap_a_len = a_len
			animation.swap_b_len = b_len
			return
		}
	}
}

gp_load_font :: proc(ctx: ^Context, path: cstring, fallback: shared.Font_Id) -> shared.Font_Id {
	if ctx.load_font == nil { return fallback }
	id, ok := ctx.load_font(path, 64)
	if ok && id != shared.INVALID_FONT_ID { return id }
	log.infof("Font %s unavailable, using fallback", path)
	return fallback
}
