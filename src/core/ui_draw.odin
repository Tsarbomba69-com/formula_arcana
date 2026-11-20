package core

import "../shared"
import "core:fmt"
// Generic drawing: tree + interaction + renderer -> draw calls.
// No raylib here, so this is as testable as the layout.

ui_draw :: proc(t: ^UI_Tree, ix: Interaction, r: shared.Renderer, scale: f32) {
	ui_draw_node(t, t.root, ix, r, scale)
}

@(private)
ui_draw_node :: proc(t: ^UI_Tree, i: int, ix: Interaction, r: shared.Renderer, scale: f32) {
	n := &t.nodes[i]
	rect := shared.Rect{n.rect.x * scale, n.rect.y * scale, n.rect.w * scale, n.rect.h * scale}
	#partial switch n.background.type {
	case .Color: r.fill_rect(rect, n.background.color)
	case .Image: // Draw background texture scaled to the node's rect
			r.draw_texture(n.background.texture_id, rect, {255, 255, 255, 255})
	}

	switch &k in n.kind {
	case nil:
	case Container: for c in n.children[:n.child_count] {
				ui_draw_node(t, c, ix, r, scale)
			}
	case Scroll_View:
		if r.begin_clip != nil { r.begin_clip(rect) }
		for c in n.children[:n.child_count] {
			ui_draw_node(t, c, ix, r, scale)
		}
		if r.end_clip != nil { r.end_clip() }
	case Text:
		size := i32(f32(k.font_size) * scale)
		line_h := f32(k.font_size) * DEFAULT_LINE_HEIGHT_SCALE * scale
		for ln, li in k.lines[:k.line_count] {
			s := k.content[ln[0]:ln[1]]
			x := rect.x
			switch k.align {
			case .Start:
			case .Center: x += (rect.w - r.measure_text(s, size)) / 2
			case .End: x += rect.w - r.measure_text(s, size)
			}
			r.draw_text(s, {x, rect.y + f32(li) * line_h}, size, k.color, k.font)
		}
	case Button:
		visual := button_visual(ix, i)
		bg: shared.Color
		switch visual {
		case .Rest: bg = k.normal_color
		case .Hover, .Focused: bg = k.hover_color
		case .Pressed: bg = k.pressed_color
		}
		border :=
			visual == .Rest ? shared.Color{200, 200, 200, 255} : shared.Color{255, 215, 0, 255}

		r.fill_rect(rect, bg)
		r.outline_rect(rect, 2 * scale, border)

		size := i32(f32(BUTTON_FONT_SIZE) * scale)
		tw := r.measure_text(k.label, size)
		r.draw_text(
			k.label,
			{rect.x + (rect.w - tw) / 2, rect.y + (rect.h - f32(size)) / 2},
			size,
			{255, 255, 255, 255},
			k.font,
		)
	}

	if n.border.thickness > 0 && r.outline_rect != nil {
		r.outline_rect(rect, n.border.thickness * scale, n.border.color)
	}
}

// Dumps the entire UI tree hierarchy to the console for debugging
ui_dump :: proc(t: ^UI_Tree) {
	if t.count == 0 {
		fmt.println("--- UI Tree: Empty ---")
		return
	}
	fmt.println("--- UI Tree Dump ---")
	ui_dump_node(t, t.root, 0)
}
// TODO: Remove this
@(private)
ui_dump_node :: proc(t: ^UI_Tree, i: int, depth: int) {
	if i < 0 || i >= t.count { return }
	n := &t.nodes[i]

	// Build visual indentation
	indent := ""
	for _ in 0 ..< depth {
		indent = fmt.tprint(indent, "  ")
	}

	// Extract kind-specific details
	kind_str := "Unknown"
	details := ""
	switch &k in n.kind {
	case nil: kind_str = "Nil"
	case Container:
		kind_str = "Container"
		details = fmt.tprint("dir=", k.direction, ", spacing=", k.spacing)
	case Text:
		kind_str = "Text"
		details = fmt.tprint("content=\"", k.content, "\"")
	case Button:
		kind_str = "Button"
		details = fmt.tprint("label=\"", k.label, "\", action=", k.action)
	case Scroll_View:
		kind_str = "Scroll_View"
		details = fmt.tprint("viewport=", k.width, "x", k.height)
	}

	// Format background info
	bg_str := ""
	switch n.background.type {
	case .None: bg_str = "bg:none"
	case .Color: bg_str = fmt.tprint("bg:color=", n.background.color)
	case .Image: bg_str = fmt.tprint("bg:image(id=", n.background.texture_id, ")")
	}

	// Print node summary line
	fmt.printf(
		"%s[%d] %s | rect: {x=%.1f, y=%.1f, w=%.1f, h=%.1f} | %s | %s\n",
		indent,
		i,
		kind_str,
		n.rect.x,
		n.rect.y,
		n.rect.w,
		n.rect.h,
		details,
		bg_str,
	)

	// Recurse into children
	for child_idx in n.children[:n.child_count] {
		ui_dump_node(t, child_idx, depth + 1)
	}
}
