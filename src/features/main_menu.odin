package main_menu

import "../core"
import "../shared"
import rl "vendor:raylib"

Menu_State :: struct {
	tree:      shared.UI_Tree, // whole tree is value-typed: lives wherever Menu_State lives
	mouse_pos: shared.Vec2,
}

measure_text :: proc(text: cstring, font_size: i32) -> i32 {
	return rl.MeasureText(text, font_size)
}

init_menu :: proc(screen_w, screen_h: i32) -> (state: Menu_State) {
	t := &state.tree
	button_padding := shared.Insets{10, 20, 10, 20}

	title := shared.ui_add(
		t,
		shared.Text {
			content = "Formula Arcana",
			font_size = 36,
			color = {255, 255, 255, 255},
			is_bold = true,
		},
	)

	play := shared.ui_add(
		t,
		shared.Button {
			label = "Enter Codex",
			normal_color = {50, 150, 50, 255},
			hover_color = {70, 180, 70, 255},
			pressed_color = {30, 100, 30, 255},
			padding = button_padding,
			on_click = shared.Navigate_To {
				target = .Level_Select,
				payload = shared.Level_Select_Payload{difficulty = .Standard},
			},
		},
	)

	settings := shared.ui_add(
		t,
		shared.Button {
			label = "Settings",
			normal_color = {100, 100, 100, 255},
			hover_color = {130, 130, 130, 255},
			pressed_color = {70, 70, 70, 255},
			padding = button_padding,
			on_click = shared.Navigate_To {
				target = .Settings,
				payload = shared.Settings_Payload {
					active_tab = .Audio,
					pending_audio = {
						master_volume = 0.8,
						music_volume = 0.5,
						sfx_volume = 1.0,
						is_muted = false,
					},
					pending_graphics = {
						fullscreen = true,
						resolution = {1920, 1080},
						vsync = true,
					},
					is_dirty = false,
				},
			},
		},
	)

	// Root (added last)
	shared.ui_add(
		t,
		shared.Container {
			direction = .Vertical,
			alignment = .Center,
			spacing = 16,
			padding = {20, 20, 20, 20},
		},
		title,
		play,
		settings,
	)

	layout_menu(&state, screen_w, screen_h)
	return
}

// Call again on window resize.
layout_menu :: proc(state: ^Menu_State, screen_w, screen_h: i32) {
	shared.ui_layout(&state.tree, {f32(screen_w), f32(screen_h)}, measure_text)
}

// Consumes the frame event stream; returns the clicked button's message (nil if none).
update_menu :: proc(state: ^Menu_State, events: []core.Event) -> shared.Msg {
	msg: shared.Msg

	for ev in events {
		#partial switch e in ev {
		case shared.Mouse_Input:
			state.mouse_pos = e.position

			for &n in state.tree.nodes[:state.tree.count] {
				#partial switch &k in n.kind {
				case shared.Button: if shared.contains_point(n.rect, e.position) {
							k.state = e.clicked ? .Pressed : .Hover
							if e.clicked {
								msg = k.on_click
							}
						} else {
							k.state = .Normal
						}
				}
			}
		}
	}

	return msg
}

draw_menu :: proc(state: ^Menu_State) {
	draw_node(&state.tree, state.tree.root)
}

draw_node :: proc(t: ^shared.UI_Tree, i: int) {
	n := &t.nodes[i]

	switch k in n.kind {
	case nil:
	case shared.Container: for c in n.children[:n.child_count] {
				draw_node(t, c)
			}
	case shared.Text:
		rl.DrawText(k.content, i32(n.rect.x), i32(n.rect.y), k.font_size, rl.Color(k.color))
	case shared.Button:
		bg: shared.Color
		switch k.state {
		case .Normal: bg = k.normal_color
		case .Hover: bg = k.hover_color
		case .Pressed: bg = k.pressed_color
		}

		r := rl.Rectangle{n.rect.x, n.rect.y, n.rect.w, n.rect.h}
		rl.DrawRectangleRec(r, rl.Color(bg))
		rl.DrawRectangleLinesEx(r, 2, k.state == .Normal ? rl.LIGHTGRAY : rl.GOLD)

		tw := rl.MeasureText(k.label, shared.BUTTON_FONT_SIZE)
		tx := i32(n.rect.x + n.rect.w / 2) - tw / 2
		ty := i32(n.rect.y + n.rect.h / 2) - shared.BUTTON_FONT_SIZE / 2
		rl.DrawText(k.label, tx, ty, shared.BUTTON_FONT_SIZE, rl.WHITE)
	}
}
