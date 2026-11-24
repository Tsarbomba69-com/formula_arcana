package features

import "../core"
import "../shared"

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
GP_TILE_SIDE_INSET :: f32(16)
GP_TILE_TOP_INSET :: f32(25)
GP_TILE_WIDTH_FACTOR :: f32(0.58)

GP_CONTENT_RIGHT :: f32(1408)
GP_MOVES_PANEL_X :: f32(32)
GP_MOVES_PANEL_W :: f32(299)
GP_CENTER_PANEL_X :: f32(352)
GP_CENTER_PANEL_W :: f32(699)
GP_HISTORY_PANEL_X :: f32(1072)
GP_HISTORY_PANEL_W :: f32(336)
GP_FORMULA_PANEL_H :: f32(385)
GP_FORMULA_GOAL_GAP :: f32(20)

GP_PANEL_CONTENT_INSET_X :: f32(12)
GP_MOVES_VIEW_TOP_INSET :: f32(91)
GP_MOVES_VIEW_BOTTOM_INSET :: f32(52)
GP_HISTORY_VIEW_TOP_INSET :: f32(90)
GP_HISTORY_VIEW_BOTTOM_INSET :: f32(113)
GP_SCROLLBAR_W :: f32(9)
GP_SCROLLBAR_THUMB_OVERHANG :: f32(1.5)

GP_FORMULA_BOX_X_INSET :: f32(24)
GP_FORMULA_BOX_TOP_INSET :: f32(86)
GP_FORMULA_BOX_H :: f32(115)
GP_APPLY_BUTTON_W :: f32(206)
GP_APPLY_BUTTON_H :: f32(51)
GP_APPLY_BUTTON_RIGHT_INSET :: f32(23)
GP_APPLY_BUTTON_TOP_INSET :: f32(294)
GP_GOAL_CARD_X_INSET :: f32(472)
GP_GOAL_CARD_TOP_INSET :: f32(26)
GP_GOAL_CARD_W :: f32(203)
GP_GOAL_CARD_H :: f32(100)
GP_FOOTER_BUTTON_TOP_INSET :: f32(98)
GP_FOOTER_BUTTON_H :: f32(40)
GP_FOOTER_BUTTON_GAP :: f32(12)
GP_UNDO_BUTTON_W :: f32(142)
GP_RESTART_BUTTON_W :: f32(138)
GP_FOOTER_EDGE_INSET :: f32(22)
GP_PAUSE_BUTTON_TOP :: f32(98)
GP_PAUSE_BUTTON_SIZE :: f32(47)
GP_PAUSE_BUTTON_RIGHT_INSET :: f32(24)

GP_MOVE_CARD_TOP :: f32(365)
GP_MOVE_CARD_SIDE_INSET :: f32(22)
GP_HISTORY_CARD_TOP :: f32(366)
GP_HISTORY_CARD_STEP :: f32(126)
GP_HISTORY_CARD_H :: f32(108)
GP_HISTORY_CONTENT_TAIL :: f32(3)

GP_TABS := [4]string{"ALGEBRA", "ARITHMETIC", "LOGIC", "PHYSICS"}
GP_TAB_WIDTHS := [4]f32{96, 110, 78, 90}

GP_FOOTNOTE :: "Only equivalence-preserving moves are listed."
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
	gp_assert_tile_mapping(s)
	gameplay_sync_selection(s)
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
		tile_w := gp_formula_tile_width(box, s.tile_node_count)
		s.tile_font_size = clamp(tile_w * GP_TILE_WIDTH_FACTOR, GP_TILE_FONT_MIN, GP_TILE_FONT_MAX)
		for i in 0 ..< s.tile_node_count {
			s.tree.nodes[s.tile_nodes[i]].rect = gp_formula_tile_rect(box, s.tile_node_count, i)
		}
	}
	s.tree.nodes[s.apply_node].rect = gp_rect_apply(s.origin_x)
	s.tree.nodes[s.undo_node].rect = gp_rect_undo(s.origin_x)
	s.tree.nodes[s.restart_node].rect = gp_rect_restart(s.origin_x)
	s.tree.nodes[s.pause_node].rect = gp_rect_pause(s.origin_x)
}

// Each tile node and token share the same array index. Nodes are added in the
// same order as tokens, so rebuilding either list must preserve their counts.
gp_assert_tile_mapping :: proc(s: ^Gameplay_State) {
	assert(
		s.tile_node_count == s.tokens.count,
		"gameplay tile nodes must map one-to-one to tokens",
	)
	for i in 0 ..< s.tile_node_count {
		assert(s.tile_nodes[i] == s.move_node_count + i, "tile node order must match token order")
	}
}

gameplay_sync_selection :: proc(s: ^Gameplay_State) {
	s.selection = {}
	if s.workspace.selected_op >= 0 && s.workspace.selected_op < s.tokens.count {
		s.selection = {
			kind        = .Operator,
			token_index = s.workspace.selected_op,
		}
		return
	}
	if term, ok := s.workspace.selection.?; ok {
		s.selection = {
			kind        = .Term,
			token_index = -1,
			term        = term,
		}
		for i in 0 ..< s.tokens.count {
			if s.tokens.items[i].term == term {
				s.selection.token_index = i
				break
			}
		}
	}
}

gp_formula_tile_width :: proc(box: shared.Rect, count: int) -> f32 {
	if count <= 0 { return 0 }
	available := box.w - 2 * GP_TILE_SIDE_INSET - f32(count - 1) * GP_TILE_GAP
	return available / f32(count)
}

gp_formula_tile_rect :: proc(box: shared.Rect, count, index: int) -> shared.Rect {
	tile_w := gp_formula_tile_width(box, count)
	x := box.x + GP_TILE_SIDE_INSET + f32(index) * (tile_w + GP_TILE_GAP)
	return {x, box.y + GP_TILE_TOP_INSET, tile_w, GP_TILE_H}
}

// ============================================================================
// Panel geometry
// ============================================================================

gp_rect_moves :: proc(ox: f32) -> shared.Rect {
	return {ox + GP_MOVES_PANEL_X, GP_PANEL_TOP, GP_MOVES_PANEL_W, GP_PANEL_BOTTOM - GP_PANEL_TOP}
}

gp_rect_formula :: proc(ox: f32) -> shared.Rect {
	return {ox + GP_CENTER_PANEL_X, GP_PANEL_TOP, GP_CENTER_PANEL_W, GP_FORMULA_PANEL_H}
}

gp_rect_goal :: proc(ox: f32) -> shared.Rect {
	goal_top := GP_PANEL_TOP + GP_FORMULA_PANEL_H + GP_FORMULA_GOAL_GAP
	return {ox + GP_CENTER_PANEL_X, goal_top, GP_CENTER_PANEL_W, GP_PANEL_BOTTOM - goal_top}
}

gp_rect_history :: proc(ox: f32) -> shared.Rect {
	return {
		ox + GP_HISTORY_PANEL_X,
		GP_PANEL_TOP,
		GP_HISTORY_PANEL_W,
		GP_PANEL_BOTTOM - GP_PANEL_TOP,
	}
}

GP_SCROLL_STEP :: f32(72)
GP_SCROLLBAR_MIN_THUMB :: f32(36)

// Returns the design-space viewport where transformation cards are clipped and hit-tested.
gp_moves_view_rect :: proc(ox: f32) -> shared.Rect {
	p := gp_rect_moves(ox)
	return {
		p.x + GP_PANEL_CONTENT_INSET_X,
		p.y + GP_MOVES_VIEW_TOP_INSET,
		p.w - 2 * GP_PANEL_CONTENT_INSET_X,
		p.h - GP_MOVES_VIEW_TOP_INSET - GP_MOVES_VIEW_BOTTOM_INSET,
	}
}

// Returns the design-space viewport where history cards are clipped and hit-tested.
gp_history_view_rect :: proc(ox: f32) -> shared.Rect {
	p := gp_rect_history(ox)
	return {
		p.x + GP_PANEL_CONTENT_INSET_X,
		p.y + GP_HISTORY_VIEW_TOP_INSET,
		p.w - 2 * GP_PANEL_CONTENT_INSET_X,
		p.h - GP_HISTORY_VIEW_TOP_INSET - GP_HISTORY_VIEW_BOTTOM_INSET,
	}
}

gp_moves_content_height :: proc(count: int) -> f32 {
	if count <= 0 { return 0 }
	visible := min(count, GP_MOVES_VISIBLE_MAX)
	height := gp_card_height(visible)
	gap := gp_card_gap(visible)
	return 13 + f32(count) * (height + gap) - gap
}

gp_history_content_height :: proc(count: int) -> f32 {
	return max(f32(count) * GP_HISTORY_CARD_STEP - GP_HISTORY_CONTENT_TAIL, 0)
}

gp_moves_scroll_max :: proc(s: ^Gameplay_State) -> f32 {
	return max(gp_moves_content_height(s.move_node_count) - gp_moves_view_rect(s.origin_x).h, 0)
}

gp_history_scroll_max :: proc(s: ^Gameplay_State) -> f32 {
	return max(
		gp_history_content_height(s.workspace.entry_count) - gp_history_view_rect(s.origin_x).h,
		0,
	)
}

gp_moves_scrollbar_track :: proc(s: ^Gameplay_State) -> shared.Rect {
	view := gp_moves_view_rect(s.origin_x)
	return {view.x + view.w - GP_SCROLLBAR_W, view.y, GP_SCROLLBAR_W, view.h}
}

gp_history_scrollbar_track :: proc(s: ^Gameplay_State) -> shared.Rect {
	view := gp_history_view_rect(s.origin_x)
	return {view.x + view.w - GP_SCROLLBAR_W, view.y, GP_SCROLLBAR_W, view.h}
}

gp_scrollbar_thumb :: proc(
	track: shared.Rect,
	viewport_height, content_height, scroll, scroll_max: f32,
) -> shared.Rect {
	if scroll_max <= 0 || content_height <= 0 { return {} }
	thumb_h := clamp(track.h * viewport_height / content_height, GP_SCROLLBAR_MIN_THUMB, track.h)
	travel := track.h - thumb_h
	thumb_y := track.y + (scroll_max > 0 ? scroll / scroll_max : 0) * travel
	return {
		track.x - GP_SCROLLBAR_THUMB_OVERHANG,
		thumb_y,
		track.w + 2 * GP_SCROLLBAR_THUMB_OVERHANG,
		thumb_h,
	}
}

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

gp_set_moves_scroll :: proc(s: ^Gameplay_State, offset: f32) {
	previous := s.moves_scroll_y
	s.moves_scroll_y = clamp(offset, 0, gp_moves_scroll_max(s))
	core.ui_scroll_nodes_by(&s.tree, s.move_nodes[:s.move_node_count], s.moves_scroll_y - previous)
}

gp_set_history_scroll :: proc(s: ^Gameplay_State, offset: f32) {
	s.history_scroll_y = clamp(offset, 0, gp_history_scroll_max(s))
}

gp_is_move_node :: proc(s: ^Gameplay_State, node: int) -> bool {
	for move_node in s.move_nodes[:s.move_node_count] {
		if move_node == node { return true }
	}
	return false
}

gp_rect_formula_box :: proc(ox: f32) -> shared.Rect {
	p := gp_rect_formula(ox)
	return {
		p.x + GP_FORMULA_BOX_X_INSET,
		p.y + GP_FORMULA_BOX_TOP_INSET,
		p.w - 2 * GP_FORMULA_BOX_X_INSET,
		GP_FORMULA_BOX_H,
	}
}

gp_rect_apply :: proc(ox: f32) -> shared.Rect {
	p := gp_rect_formula(ox)
	return {
		p.x + p.w - GP_APPLY_BUTTON_RIGHT_INSET - GP_APPLY_BUTTON_W,
		p.y + GP_APPLY_BUTTON_TOP_INSET,
		GP_APPLY_BUTTON_W,
		GP_APPLY_BUTTON_H,
	}
}

gp_rect_target :: proc(ox: f32) -> shared.Rect {
	p := gp_rect_goal(ox)
	return {
		p.x + GP_GOAL_CARD_X_INSET,
		p.y + GP_GOAL_CARD_TOP_INSET,
		GP_GOAL_CARD_W,
		GP_GOAL_CARD_H,
	}
}

gp_rect_undo :: proc(ox: f32) -> shared.Rect {
	p := gp_rect_history(ox)
	return {
		p.x + GP_FOOTER_EDGE_INSET,
		p.y + p.h - GP_FOOTER_BUTTON_TOP_INSET,
		GP_UNDO_BUTTON_W,
		GP_FOOTER_BUTTON_H,
	}
}

gp_rect_restart :: proc(ox: f32) -> shared.Rect {
	p := gp_rect_history(ox)
	x := p.x + GP_FOOTER_EDGE_INSET + GP_UNDO_BUTTON_W + GP_FOOTER_BUTTON_GAP
	return {x, p.y + p.h - GP_FOOTER_BUTTON_TOP_INSET, GP_RESTART_BUTTON_W, GP_FOOTER_BUTTON_H}
}

gp_rect_pause :: proc(ox: f32) -> shared.Rect {
	return {
		ox + GP_CONTENT_RIGHT - GP_PAUSE_BUTTON_RIGHT_INSET - GP_PAUSE_BUTTON_SIZE,
		GP_PAUSE_BUTTON_TOP,
		GP_PAUSE_BUTTON_SIZE,
		GP_PAUSE_BUTTON_SIZE,
	}
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
	return {
		p.x + GP_MOVE_CARD_SIDE_INSET,
		GP_MOVE_CARD_TOP + f32(slot) * (h + gp_card_gap(card_count)),
		p.w - 2 * GP_MOVE_CARD_SIDE_INSET,
		h,
	}
}

gp_history_card_rect :: proc(ox: f32, slot: int) -> shared.Rect {
	p := gp_rect_history(ox)
	return {
		p.x + GP_MOVE_CARD_SIDE_INSET,
		GP_HISTORY_CARD_TOP + f32(slot) * GP_HISTORY_CARD_STEP,
		p.w - 2 * GP_MOVE_CARD_SIDE_INSET,
		GP_HISTORY_CARD_H,
	}
}
