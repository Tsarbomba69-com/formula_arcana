package features

import "../core"
import "../shared"
import "core:testing"

// No window, no raylib: a fake measure is all layout needs.
fake_measure :: proc(text: string, font_size: i32, font_id: shared.Font_Id) -> f32 {
	return f32(len(text)) * f32(font_size) * 0.5
}

test_ctx :: proc() -> Context {
	return {viewport = shared.viewport_of(1440, 900), renderer = {measure_text = fake_measure}}
}

button_center :: proc(m: ^Menu_State, which: int) -> shared.Vec2 {
	list, _ := core.ui_buttons(&m.tree)
	r := m.tree.nodes[list[which]].rect
	return {r.x + r.w / 2, r.y + r.h / 2}
}

@(test)
buttons_share_width_and_center :: proc(t: ^testing.T) {
	ctx := test_ctx()
	m := init_menu(&ctx)
	list, count := core.ui_buttons(&m.tree)
	testing.expect_value(t, count, 3)

	first := m.tree.nodes[list[0]].rect
	for i in 0 ..< count {
		r := m.tree.nodes[list[i]].rect
		testing.expect_value(t, r.w, f32(BUTTON_WIDTH))
		testing.expect_value(t, r.x + r.w / 2, first.x + first.w / 2)
	}
}

@(test)
tagline_wraps_to_two_lines :: proc(t: ^testing.T) {
	ctx := test_ctx()
	m := init_menu(&ctx)
	for i in 0 ..< m.tree.count {
		if txt, ok := m.tree.nodes[i].kind.(core.Text); ok && txt.max_width > 0 {
			testing.expect_value(t, txt.line_count, 2)
		}
	}
}

@(test)
click_fires_on_release_not_press :: proc(t: ^testing.T) {
	ctx := test_ctx()
	m := init_menu(&ctx)
	pos := button_center(&m, 0) // scale == 1 at 1440x900

	nav := update_menu(&m, {shared.Mouse_Input{position = pos, pressed = true}})
	testing.expect(t, nav == nil, "press alone must not navigate")

	nav = update_menu(&m, {shared.Mouse_Input{position = pos, released = true}})
	_, is_level_select := nav.(core.Go_Level_Select)
	testing.expect(t, is_level_select, "release on same button navigates")
}

@(test)
release_elsewhere_cancels :: proc(t: ^testing.T) {
	ctx := test_ctx()
	m := init_menu(&ctx)
	update_menu(&m, {shared.Mouse_Input{position = button_center(&m, 0), pressed = true}})
	nav := update_menu(&m, {shared.Mouse_Input{position = button_center(&m, 1), released = true}})
	testing.expect(t, nav == nil)
	testing.expect(t, m.ix.pressed == nil)
}

@(test)
keyboard_focus_and_confirm :: proc(t: ^testing.T) {
	ctx := test_ctx()
	m := init_menu(&ctx)
	update_menu(&m, {shared.Key_Input{.Down}})
	nav := update_menu(&m, {shared.Key_Input{.Confirm}})
	_, is_archives := nav.(core.Go_Archives)
	testing.expect(t, is_archives)
}

@(test)
mouse_uses_scale :: proc(t: ^testing.T) {
	// Arrange
	ctx := test_ctx()
	ctx.viewport = shared.viewport_of(720, 450) // scale 0.5
	m := init_menu(&ctx)
	real_pos := button_center(&m, 2) * ctx.viewport.scale
	// Act
	update_menu(&m, {shared.Mouse_Input{position = real_pos, pressed = true}})
	nav := update_menu(&m, {shared.Mouse_Input{position = real_pos, released = true}})
	_, is_settings := nav.(core.Go_Settings)
	// Assert
	testing.expect(t, is_settings)
}

@(test)
background_defaults_to_none :: proc(t: ^testing.T) {
	// Arrange
	ctx := test_ctx()
	m := init_menu(&ctx)

	// Act & Assert
	for i in 0 ..< m.tree.count {
		node := m.tree.nodes[i]
		testing.expect_value(t, node.background.type, core.UI_Background_Type.None)
	}
}

@(test)
widget_accepts_background_image :: proc(t: ^testing.T) {
	// Arrange
	ctx := test_ctx()
	m := init_menu(&ctx)
	list, count := core.ui_buttons(&m.tree)
	testing.expect(t, count > 0, "expected at least one button")

	btn_idx := list[0]
	test_texture := shared.Texture_Id(101)

	// Act
	core.set_node_background_image(&m.tree, btn_idx, test_texture)

	// Assert
	node := m.tree.nodes[btn_idx]
	testing.expect_value(t, node.background.type, core.UI_Background_Type.Image)
	testing.expect_value(t, node.background.texture_id, test_texture)
}

// @(test)
// loads_font_into_text_object :: proc(t: ^testing.T) {
// 	Arrange
// 	font_path := "assets/fonts/default.ttf"
// 	txt := core.Text{}

// 	Act
// 	load_font(&txt, font_path)

// 	Assert
// 	testing.expect(
// 		t,
// 		txt.font.is_loaded,
// 		"font should be successfully loaded into the text object",
// 	)
// 	testing.expect_value(t, txt.font.path, font_path)
// }
