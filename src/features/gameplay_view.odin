package features

import "../core"
import "../shared"
import "core:fmt"
import "core:math"

// ============================================================================
// Painter primitives
// ============================================================================

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

draw_gameplay :: proc(s: ^Gameplay_State, ctx: Context) {
	if s.tree.count == 0 { return }
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

gp_draw_background :: proc(v: ^Gp_View) {
	full := shared.Rect{0, 0, v.size.x, v.size.y}
	v.r.fill_rect(full, GP_BG)
	if v.s.background != shared.INVALID_TEXTURE_ID {
		v.r.draw_texture(v.s.background, full, {255, 255, 255, 38})
	}
}

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
	if s.selection.kind == .Term { hint = "Click the term again to return to the whole equation." }
	if s.selection.kind == .Operator {
		token := s.tokens.items[s.selection.token_index]
		hint_buf: [64]u8
		hint = fmt.bprintf(
			hint_buf[:],
			"Selected operation: %s · click again to clear",
			label_str(&token.text),
		)
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
	scope :=
		s.selection.kind == .Term ? "SCOPE: TERM" : (s.selection.kind == .Operator ? "SCOPE: OPERATION" : "SCOPE: EQUATION")
	gp_text(v, scope, p.x + 634, ly, 10, GP_TEAL, s.fonts.mono, .End)
	gp_hline(v, x, p.y + 261, p.w - 48, GP_DIVIDER)

	gp_draw_preview(v, p, solved)
}

gp_draw_tiles :: proc(v: ^Gp_View) {
	s := v.s
	fs := s.tile_font_size
	for i in 0 ..< s.tile_node_count {
		token := &s.tokens.items[i]
		node := s.tile_nodes[i]
		r := s.tree.nodes[node].rect
		text := label_str(&token.text)
		cx, cy := r.x + r.w / 2, r.y + r.h / 2

		selectable :=
			token.term != NO_EXPR || (token.kind == .Operator && label_str(&token.text) != "=")
		selected :=
			(s.selection.kind == .Operator && s.selection.token_index == i) ||
			(s.selection.kind == .Term && token.term == s.selection.term && selectable)
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
	case w.moves.count > 0 && w.selected_move < w.moves.count:
		move := w.moves.items[w.selected_move]
		view = describe_move(workspace_current(w), move)
		heading = label_str(&view.heading)
		if preview, ok := workspace_preview(w); ok { result = format_equation(preview, rbuf[:]) }
		show_note = true
		enabled = !s.paused && workspace_has_scope(w)
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

gp_draw_stats_pause_only :: proc(v: ^Gp_View) {
	r := v.s.tree.nodes[v.s.pause_node].rect
	gp_box(v, r, {16, 44, 56, 255}, GP_AMBER, 1.5)
	bar_h := r.h * 0.42
	gp_fill(v, {r.x + r.w * 0.34, r.y + (r.h - bar_h) / 2, 4, bar_h}, GP_TEXT)
	gp_fill(v, {r.x + r.w * 0.58, r.y + (r.h - bar_h) / 2, 4, bar_h}, GP_TEXT)
}

gp_scaled :: proc(v: ^Gp_View, r: shared.Rect) -> shared.Rect {
	k := v.scale
	return {r.x * k, r.y * k, r.w * k, r.h * k}
}

gp_draw_scrollbar :: proc(v: ^Gp_View, track, thumb: shared.Rect) {
	gp_fill(v, track, {5, 14, 21, 255})
	gp_box(v, thumb, GP_TEAL_DIM, GP_TEAL)
}

gp_begin_panel_clip :: proc(v: ^Gp_View, r: shared.Rect) {
	if v.r.begin_clip != nil { v.r.begin_clip(gp_scaled(v, r)) }
}

gp_end_panel_clip :: proc(v: ^Gp_View) {
	if v.r.end_clip != nil { v.r.end_clip() }
}

gp_fill :: proc(v: ^Gp_View, r: shared.Rect, c: shared.Color) {
	v.r.fill_rect(gp_scaled(v, r), c)
}

gp_outline :: proc(v: ^Gp_View, r: shared.Rect, thickness: f32, c: shared.Color) {
	v.r.outline_rect(gp_scaled(v, r), thickness * v.scale, c)
}

gp_box :: proc(v: ^Gp_View, r: shared.Rect, fill, border: shared.Color, thickness: f32 = 1) {
	gp_fill(v, r, fill)
	gp_outline(v, r, thickness, border)
}

gp_hline :: proc(v: ^Gp_View, x, y, w: f32, c: shared.Color) {
	gp_fill(v, {x, y, w, 1}, c)
}

// No circle primitive exists, so a ring is a polyline of small squares.
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

gp_measure :: proc(v: ^Gp_View, text: string, size: f32, font: shared.Font_Id) -> f32 {
	return gp_text_width(v.r.measure_text, v.scale, text, size, font)
}

// (x, y) = anchor point; y is the vertical CENTRE of the line. `align` says what x means.
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

gp_panel :: proc(v: ^Gp_View, r: shared.Rect) {
	gp_box(v, r, GP_PANEL, GP_PANEL_BORDER)
}
