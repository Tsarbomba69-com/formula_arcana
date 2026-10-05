package features

import "../core"
import "../shared"
import "core:testing"

// No window, no raylib: a fake measure is all layout needs.
fake_measure :: proc(text: string, font_size: i32) -> f32 {
	return f32(len(text)) * f32(font_size) * 0.5
}

test_ctx :: proc() -> Context {
	return {viewport = shared.viewport_of(1440, 900), renderer = {measure_text = fake_measure}}
}

button_center :: proc(m: ^Menu_State, which: int) -> shared.Vec2 {
	list, _ := shared.ui_buttons(&m.tree)
	r := m.tree.nodes[list[which]].rect
	return {r.x + r.w / 2, r.y + r.h / 2}
}

@(test)
buttons_share_width_and_center :: proc(t: ^testing.T) {
	m := init_menu(test_ctx())
	list, count := shared.ui_buttons(&m.tree)
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
	m := init_menu(test_ctx())
	for i in 0 ..< m.tree.count {
		if txt, ok := m.tree.nodes[i].kind.(shared.Text); ok && txt.max_width > 0 {
			testing.expect_value(t, txt.line_count, 2)
		}
	}
}

@(test)
click_fires_on_release_not_press :: proc(t: ^testing.T) {
	m := init_menu(test_ctx())
	pos := button_center(&m, 0) // scale == 1 at 1440x900

	nav := update_menu(&m, {shared.Mouse_Input{position = pos, pressed = true}})
	testing.expect(t, nav == nil, "press alone must not navigate")

	nav = update_menu(&m, {shared.Mouse_Input{position = pos, released = true}})
	_, is_level_select := nav.(core.Go_Level_Select)
	testing.expect(t, is_level_select, "release on same button navigates")
}

@(test)
release_elsewhere_cancels :: proc(t: ^testing.T) {
	m := init_menu(test_ctx())
	update_menu(&m, {shared.Mouse_Input{position = button_center(&m, 0), pressed = true}})
	nav := update_menu(&m, {shared.Mouse_Input{position = button_center(&m, 1), released = true}})
	testing.expect(t, nav == nil)
	testing.expect(t, m.ix.pressed == nil)
}

@(test)
keyboard_focus_and_confirm :: proc(t: ^testing.T) {
	m := init_menu(test_ctx())
	update_menu(&m, {shared.Key_Input{.Down}})
	nav := update_menu(&m, {shared.Key_Input{.Confirm}})
	_, is_archives := nav.(core.Go_Archives)
	testing.expect(t, is_archives)
}

@(test)
mouse_uses_scale :: proc(t: ^testing.T) {
	ctx := test_ctx()
	ctx.viewport = shared.viewport_of(720, 450) // scale 0.5
	m := init_menu(ctx)
	real_pos := button_center(&m, 2) * ctx.viewport.scale
	update_menu(&m, {shared.Mouse_Input{position = real_pos, pressed = true}})
	nav := update_menu(&m, {shared.Mouse_Input{position = real_pos, released = true}})
	_, is_settings := nav.(core.Go_Settings)
	testing.expect(t, is_settings)
}
