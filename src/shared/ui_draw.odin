package shared

// Generic drawing: tree + interaction + renderer -> draw calls.
// No raylib here, so this is as testable as the layout.

ui_draw :: proc(t: ^UI_Tree, ix: Interaction, r: Renderer, scale: f32) {
	ui_draw_node(t, t.root, ix, r, scale)
}

@(private)
ui_draw_node :: proc(t: ^UI_Tree, i: int, ix: Interaction, r: Renderer, scale: f32) {
	n := &t.nodes[i]
	rect := Rect{n.rect.x * scale, n.rect.y * scale, n.rect.w * scale, n.rect.h * scale}

	switch &k in n.kind {
	case nil:
	case Container: for c in n.children[:n.child_count] {
				ui_draw_node(t, c, ix, r, scale)
			}
	case Text:
		size := i32(f32(k.font_size) * scale)
		line_h := f32(k.font_size) * LINE_HEIGHT * scale
		for ln, li in k.lines[:k.line_count] {
			s := k.content[ln[0]:ln[1]]
			x := rect.x
			switch k.align {
			case .Start:
			case .Center: x += (rect.w - r.measure_text(s, size)) / 2
			case .End: x += rect.w - r.measure_text(s, size)
			}
			r.draw_text(s, {x, rect.y + f32(li) * line_h}, size, k.color)
		}
	case Button:
		visual := button_visual(ix, i)
		bg: Color
		switch visual {
		case .Rest: bg = k.normal_color
		case .Hover, .Focused: bg = k.hover_color
		case .Pressed: bg = k.pressed_color
		}
		border := visual == .Rest ? Color{200, 200, 200, 255} : Color{255, 215, 0, 255}

		r.fill_rect(rect, bg)
		r.outline_rect(rect, 2 * scale, border)

		size := i32(f32(BUTTON_FONT_SIZE) * scale)
		tw := r.measure_text(k.label, size)
		r.draw_text(
			k.label,
			{rect.x + (rect.w - tw) / 2, rect.y + (rect.h - f32(size)) / 2},
			size,
			{255, 255, 255, 255},
		)
	}
}
