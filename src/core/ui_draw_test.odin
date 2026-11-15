package core

import "../shared"
import "core:testing"

outline_calls: int
last_outline_rect: shared.Rect
last_outline_width: f32
last_outline_color: shared.Color

test_measure :: proc(text: string, font_size: i32, font_id: shared.Font_Id) -> f32 {
	return 0
}

record_outline :: proc(rect: shared.Rect, thickness: f32, color: shared.Color) {
	outline_calls += 1
	last_outline_rect = rect
	last_outline_width = thickness
	last_outline_color = color
}

@(test)
given_node_has_border_when_drawn_at_scaled_viewport_then_border_is_rendered_scaled :: proc(
	t: ^testing.T,
) {
	// Given: a node with a configured border.
	outline_calls = 0

	tree: UI_Tree
	node := ui_add(&tree, Container{width = 100, height = 50})
	border_color := shared.Color{30, 120, 240, 255}
	set_node_border(&tree, node, UI_Border{color = border_color, thickness = 3})

	// When: it is laid out and drawn at 2x scale.
	ui_layout(&tree, {100, 50}, test_measure)
	renderer := shared.Renderer {
		outline_rect = record_outline,
	}
	ui_draw(&tree, Interaction{}, renderer, 2)

	// Then: one correctly scaled border is drawn around the node.
	testing.expect_value(t, outline_calls, 1)
	testing.expect_value(t, last_outline_rect.x, 0)
	testing.expect_value(t, last_outline_rect.y, 0)
	testing.expect_value(t, last_outline_rect.w, 200)
	testing.expect_value(t, last_outline_rect.h, 100)
	testing.expect_value(t, last_outline_width, 6)
	testing.expect_value(t, last_outline_color[0], u8(30))
	testing.expect_value(t, last_outline_color[1], u8(120))
	testing.expect_value(t, last_outline_color[2], u8(240))
	testing.expect_value(t, last_outline_color[3], u8(255))
}

@(test)
given_node_has_no_border_when_drawn_then_no_border_is_rendered :: proc(t: ^testing.T) {
	// Given: a node with the default border settings.
	outline_calls = 0

	tree: UI_Tree
	_ = ui_add(&tree, Container{width = 100, height = 50})

	// When: it is laid out and drawn.
	ui_layout(&tree, {100, 50}, test_measure)
	renderer := shared.Renderer {
		outline_rect = record_outline,
	}
	ui_draw(&tree, Interaction{}, renderer, 1)

	// Then: no border outline is requested.
	testing.expect_value(t, outline_calls, 0)
}
