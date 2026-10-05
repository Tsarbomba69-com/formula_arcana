package features

import "../core"
import "../shared"

// The menu owns what its buttons MEAN. The generic Button only carries an int.
Menu_Action :: enum int {
	Enter_Codex,
	Archives,
	Settings,
}

Menu_State :: struct {
	tree:     shared.UI_Tree,
	viewport: shared.Viewport,
	ix:       shared.Interaction, // focus / hover / pressed, one place
}

BUTTON_WIDTH :: 360

WHITE :: shared.Color{255, 255, 255, 255}
CYAN :: shared.Color{77, 216, 232, 255}
MINT :: shared.Color{74, 222, 154, 255}
MIST :: shared.Color{140, 160, 170, 255}

add_button :: proc(
	t: ^shared.UI_Tree,
	label: string,
	action: Menu_Action,
	normal, hover, pressed: shared.Color,
) -> int {
	return shared.ui_add(
		t,
		shared.Button {
			label = label,
			action = int(action),
			width = BUTTON_WIDTH,
			normal_color = normal,
			hover_color = hover,
			pressed_color = pressed,
			padding = {14, 20, 14, 20},
		},
	)
}

init_menu :: proc(ctx: Context) -> (state: Menu_State) {
	state.viewport = ctx.viewport
	t := &state.tree

	eyebrow := shared.ui_add(
		t,
		shared.Text{content = "THE LOGIC ALCHEMIST", font_size = 12, color = MINT},
	)
	top := shared.ui_add(
		t,
		shared.Text{content = "FORMULA", font_size = 64, color = WHITE, is_bold = true},
	)
	bottom := shared.ui_add(
		t,
		shared.Text{content = "ARCANA", font_size = 48, color = CYAN, is_bold = true},
	)
	wordmark := shared.ui_add(
		t,
		shared.Container{direction = .Vertical, alignment = .Center, spacing = 4},
		top,
		bottom,
	)

	tagline := shared.ui_add(
		t,
		shared.Text {
			content = "Transmute logic into power. Restore the celestial codex one equation at a time.",
			font_size = 16,
			color = MIST,
			align = .Center,
			max_width = BUTTON_WIDTH,
		},
	)

	enter := add_button(
		t,
		"Enter the Codex",
		.Enter_Codex,
		{22, 70, 78, 255},
		{30, 95, 105, 255},
		{14, 50, 56, 255},
	)
	archives := add_button(
		t,
		"Archives",
		.Archives,
		{28, 38, 44, 255},
		{40, 54, 62, 255},
		{20, 28, 32, 255},
	)
	settings := add_button(
		t,
		"Settings",
		.Settings,
		{28, 38, 44, 255},
		{40, 54, 62, 255},
		{20, 28, 32, 255},
	)
	buttons := shared.ui_add(
		t,
		shared.Container{direction = .Vertical, alignment = .Center, spacing = 16},
		enter,
		archives,
		settings,
	)

	// Root (added last)
	shared.ui_add(
		t,
		shared.Container {
			direction = .Vertical,
			alignment = .Center,
			spacing = 24,
			padding = {20, 20, 20, 20},
		},
		eyebrow,
		wordmark,
		tagline,
		buttons,
	)

	state.ix.focus = shared.ui_first_button(t)
	layout_menu(&state, ctx)
	return
}

// Call again on window resize.
layout_menu :: proc(state: ^Menu_State, ctx: Context) {
	state.viewport = ctx.viewport
	design := ctx.viewport.size / ctx.viewport.scale
	shared.ui_layout(&state.tree, design, ctx.renderer.measure_text)
}

// Consumes the frame's events; returns where to go next (nil == stay).
update_menu :: proc(state: ^Menu_State, events: []core.Event) -> core.Navigation {
	nav: core.Navigation
	t := &state.tree

	for ev in events {
		#partial switch e in ev {
		case shared.Mouse_Input:
			p := e.position / state.viewport.scale // real px -> design space
			hit, over := shared.ui_button_at(t, p)

			if over {
				state.ix.hover = hit
			} else {
				state.ix.hover = nil
			}

			if e.pressed && over {
				state.ix.pressed = hit
				state.ix.focus = hit
			}

			// Click == press AND release on the same button.
			if e.released {
				if pr, ok := state.ix.pressed.?; ok {
					if over && hit == pr {
						nav = menu_navigate(t, pr)
					}
					state.ix.pressed = nil
				}
			}

		case shared.Key_Input: switch e.key {
				case .Up: shared.ui_focus_step(t, &state.ix, -1)
				case .Down: shared.ui_focus_step(t, &state.ix, +1)
				case .Confirm: nav = menu_navigate(t, state.ix.focus)
				case .Back:
				}
		}
	}

	return nav
}

// The ONLY place that knows what each button means.
menu_navigate :: proc(t: ^shared.UI_Tree, node: int) -> core.Navigation {
	button, ok := t.nodes[node].kind.(shared.Button)
	if !ok { return nil }

	switch Menu_Action(button.action) {
	case .Enter_Codex: return core.Go_Level_Select{difficulty = .Standard}
	case .Archives: return core.Go_Archives{}
	case .Settings: return core.Go_Settings{tab = .Audio}
	}
	return nil
}

draw_menu :: proc(state: ^Menu_State, r: shared.Renderer) {
	shared.ui_draw(&state.tree, state.ix, r, state.viewport.scale)
}
