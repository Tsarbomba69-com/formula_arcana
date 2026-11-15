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

@(test)
given_focus_is_on_first_button_when_pressing_up_then_focus_wraps_to_last :: proc(t: ^testing.T) {
	// Given: a new menu, with focus initially on its first button.
	ctx := test_ctx()
	m := init_menu(&ctx)

	// When: the user moves up, then confirms.
	_ = update_menu(&m, {shared.Key_Input{.Up}})
	nav := update_menu(&m, {shared.Key_Input{.Confirm}})

	// Then: focus has wrapped to Settings.
	settings, ok := nav.(core.Go_Settings)
	testing.expect(t, ok, "Up from the first button should wrap focus to Settings")
	if ok {
		testing.expect_value(t, settings.tab, core.Settings_Tab.Audio)
	}
}

@(test)
given_focus_is_on_first_button_when_moving_down_three_times_then_it_wraps_to_first :: proc(
	t: ^testing.T,
) {
	// Given: a new menu with three buttons and focus on the first.
	ctx := test_ctx()
	m := init_menu(&ctx)

	// When: the user moves down past every button.
	_ = update_menu(&m, {shared.Key_Input{.Down}})
	_ = update_menu(&m, {shared.Key_Input{.Down}})
	_ = update_menu(&m, {shared.Key_Input{.Down}})
	nav := update_menu(&m, {shared.Key_Input{.Confirm}})

	// Then: focus has wrapped back to Enter the Codex.
	_, ok := nav.(core.Go_Level_Select)
	testing.expect(t, ok, "moving down past the last button should wrap to the first")
}

@(test)
given_menu_is_open_when_back_is_pressed_then_menu_stays_open :: proc(t: ^testing.T) {
	// Given: a new menu.
	ctx := test_ctx()
	m := init_menu(&ctx)

	// When: the user presses Back and then confirms.
	_ = update_menu(&m, {shared.Key_Input{.Back}})
	nav := update_menu(&m, {shared.Key_Input{.Confirm}})

	// Then: Back has not navigated away or changed the initial focus.
	_, ok := nav.(core.Go_Level_Select)
	testing.expect(t, ok, "Back should leave the main menu unchanged")
}

@(test)
given_no_button_was_pressed_when_mouse_is_released_over_button_then_no_navigation_occurs :: proc(
	t: ^testing.T,
) {
	// Given: a new menu and a pointer over the Archives button.
	ctx := test_ctx()
	m := init_menu(&ctx)
	pos := button_center(&m, 1)

	// When: the pointer is released without a preceding button press.
	nav := update_menu(&m, {shared.Mouse_Input{position = pos, released = true}})

	// Then: a release by itself does not activate the button.
	testing.expect(t, nav == nil, "release without a matching press should not navigate")
}

@(test)
given_mouse_was_pressed_outside_when_released_over_button_then_no_navigation_occurs :: proc(
	t: ^testing.T,
) {
	// Given: a new menu and a pointer press outside every button.
	ctx := test_ctx()
	m := init_menu(&ctx)
	outside := shared.Vec2{-100, -100}
	target := button_center(&m, 1)
	_ = update_menu(&m, {shared.Mouse_Input{position = outside, pressed = true}})

	// When: the pointer is released over Archives.
	nav := update_menu(&m, {shared.Mouse_Input{position = target, released = true}})

	// Then: moving onto a button during release does not count as a click.
	testing.expect(
		t,
		nav == nil,
		"a press outside followed by release over a button should not navigate",
	)
}

@(test)
given_archives_button_when_clicked_then_archives_navigation_is_requested :: proc(t: ^testing.T) {
	// Given: a new menu and the Archives button's center.
	ctx := test_ctx()
	m := init_menu(&ctx)
	pos := button_center(&m, 1)

	// When: the user presses and releases on that button.
	_ = update_menu(&m, {shared.Mouse_Input{position = pos, pressed = true}})
	nav := update_menu(&m, {shared.Mouse_Input{position = pos, released = true}})

	// Then: navigation requests the Archives screen.
	_, ok := nav.(core.Go_Archives)
	testing.expect(t, ok, "clicking Archives should request Archives navigation")
}

@(test)
given_settings_button_when_clicked_then_audio_settings_are_requested :: proc(t: ^testing.T) {
	// Given: a new menu and the Settings button's center.
	ctx := test_ctx()
	m := init_menu(&ctx)
	pos := button_center(&m, 2)

	// When: the user presses and releases on that button.
	_ = update_menu(&m, {shared.Mouse_Input{position = pos, pressed = true}})
	nav := update_menu(&m, {shared.Mouse_Input{position = pos, released = true}})

	// Then: navigation requests the Audio settings tab.
	settings, ok := nav.(core.Go_Settings)
	testing.expect(t, ok, "clicking Settings should request settings navigation")
	if ok {
		testing.expect_value(t, settings.tab, core.Settings_Tab.Audio)
	}
}
