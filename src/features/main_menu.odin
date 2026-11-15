package features

import "../core"
import "../shared"
import "core:log"

// The menu owns what its buttons MEAN. The generic Button only carries an int.
Menu_Action :: enum int {
	Enter_Codex,
	Archives,
	Settings,
}

Menu_State :: struct {
	tree:     core.UI_Tree,
	viewport: shared.Viewport,
	ix:       core.Interaction, // focus / hover / pressed, one place
}

BUTTON_WIDTH :: 360
// TODO: I think colors should be in shared
WHITE :: shared.Color{255, 255, 255, 255}
CYAN :: shared.Color{77, 216, 232, 255}
MINT :: shared.Color{74, 222, 154, 255}
MIST :: shared.Color{140, 160, 170, 255}
RED :: shared.Color{255, 0, 0, 255}

add_button :: proc(
	t: ^core.UI_Tree,
	label: string,
	action: Menu_Action,
	font: shared.Font_Id,
	normal, hover, pressed: shared.Color,
) -> int {
	return core.ui_add(
		t,
		core.Button {
			label = label,
			action = int(action),
			width = BUTTON_WIDTH,
			font = font,
			normal_color = normal,
			hover_color = hover,
			pressed_color = pressed,
			padding = {14, 20, 14, 20},
		},
	)
}

init_menu :: proc(ctx: ^Context) -> (state: Menu_State) {
	state.viewport = ctx.viewport
	t := &state.tree
	background_path: cstring = "assets/images/main_menu_bg.png"
	background: shared.Texture_Id
	ok := false
	has_texture_loader := ctx.load_texture != nil
	if has_texture_loader {
		background, ok = ctx.load_texture(background_path)
	}
	// Load at 64px base size so the 64px title and smaller UI elements both render cleanly
	ui_font_path: cstring = "assets/fonts/ChakraPetch-SemiBold.ttf"
	ui_font: shared.Font_Id
	ok_font := false
	has_font_loader := ctx.load_font != nil
	if has_font_loader {
		ui_font, ok_font = ctx.load_font(ui_font_path, 64)
	}
	if has_font_loader && !ok_font {
		log.warnf("Failed to load UI font at %s, falling back to default", ui_font_path)
	}

	eyebrow := core.ui_add(
		t,
		core.Text{content = "THE LOGIC ALCHEMIST", font_size = 24, color = MINT, font = ui_font},
	)
	top := core.ui_add(
		t,
		core.Text {
			content = "FORMULA",
			font_size = 64,
			color = WHITE,
			is_bold = true,
			font = ui_font,
		},
	)
	bottom := core.ui_add(
		t,
		core.Text {
			content = "ARCANA",
			font_size = 48,
			color = CYAN,
			is_bold = true,
			font = ui_font,
		},
	)
	wordmark := core.ui_add(
		t,
		core.Container{direction = .Vertical, alignment = .Center, spacing = 4},
		top,
		bottom,
	)
	tagline := core.ui_add(
		t,
		core.Text {
			content = "Transmute logic into power. Restore the celestial codex one equation at a time.",
			font_size = 16,
			color = WHITE,
			align = .Center,
			max_width = BUTTON_WIDTH,
			font = ui_font,
		},
	)

	enter := add_button(
		t,
		"Enter the Codex",
		.Enter_Codex,
		ui_font,
		{22, 70, 78, 255},
		{30, 95, 105, 255},
		{14, 50, 56, 255},
	)
	archives := add_button(
		t,
		"Archives",
		.Archives,
		ui_font,
		{28, 38, 44, 255},
		{40, 54, 62, 255},
		{20, 28, 32, 255},
	)
	settings := add_button(
		t,
		"Settings",
		.Settings,
		ui_font,
		{28, 38, 44, 255},
		{40, 54, 62, 255},
		{20, 28, 32, 255},
	)
	buttons := core.ui_add(
		t,
		core.Container{direction = .Vertical, alignment = .Center, spacing = 16},
		enter,
		archives,
		settings,
	)

	// Root (added last)
	design := ctx.viewport.size / ctx.viewport.scale
	core.ui_add(
		t,
		core.Container {
			direction = .Vertical,
			alignment = .Center,
			spacing   = 24,
			padding   = {20, 20, 20, 20},
			width     = design.x, // Fill screen width
			height    = design.y, // Fill screen height
		},
		eyebrow,
		wordmark,
		tagline,
		buttons,
	)
	state.ix.focus = core.ui_first_button(t)

	if has_texture_loader {
		if !ok {
			log.warnf("Failed to load button background texture at %s", background_path)
		} else {
			core.set_node_background_image(t, t.root, background)
		}
	}

	layout_menu(&state, ctx)
	return
}

// Call again on window resize.
layout_menu :: proc(state: ^Menu_State, ctx: ^Context) {
	state.viewport = ctx.viewport
	design := ctx.viewport.size / ctx.viewport.scale
	core.ui_layout(&state.tree, design, ctx.renderer.measure_text)
}

// Consumes the frame's events; returns where to go next (nil == stay).
update_menu :: proc(state: ^Menu_State, events: []core.Event) -> core.Navigation {
	nav: core.Navigation
	t := &state.tree

	for ev in events {
		#partial switch e in ev {
		case shared.Mouse_Input:
			p := e.position / state.viewport.scale // real px -> design space
			hit, over := core.ui_button_at(t, p)

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
				case .Up: core.ui_focus_step(t, &state.ix, -1)
				case .Down: core.ui_focus_step(t, &state.ix, +1)
				case .Confirm: nav = menu_navigate(t, state.ix.focus)
				case .Back:
				}
		}
	}

	return nav
}

// The ONLY place that knows what each button means.
menu_navigate :: proc(t: ^core.UI_Tree, node: int) -> core.Navigation {
	button, ok := t.nodes[node].kind.(core.Button)
	if !ok { return nil }

	switch Menu_Action(button.action) {
	case .Enter_Codex: return core.Go_Level_Select{difficulty = .Standard}
	case .Archives: return core.Go_Archives{}
	case .Settings: return core.Go_Settings{tab = .Audio}
	}
	return nil
}

draw_menu :: proc(state: ^Menu_State, r: shared.Renderer) {
	core.ui_draw(&state.tree, state.ix, r, state.viewport.scale)
}

load_font :: proc(text: ^core.Text, font_path: string) {

}
