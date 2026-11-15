package features

import "../core"
import "../shared"

// Everything a screen needs from the app, passed in (never reached for).
Context :: struct {
	config:       core.Config,
	progress:     core.Progress,
	viewport:     shared.Viewport,
	renderer:     shared.Renderer,
	load_texture: proc(_: cstring) -> (shared.Texture_Id, bool),
	load_font:    proc(_: cstring, _: i32) -> (shared.Font_Id, bool),
}

// ---- One state type per screen (stubs, to be grown) ------------------------

Level_Select_State :: struct {
	unlocked:   core.Level_Set, // from save data, not from the menu
	selected:   int,
	difficulty: core.Difficulty,
	viewport:   shared.Viewport,
	pressed:    Maybe(int),
}

Settings_State :: struct {
	active_tab:       core.Settings_Tab,
	pending_audio:    core.Audio_Settings, // copied from the REAL config on entry
	pending_graphics: core.Graphics_Settings,
	is_dirty:         bool,
}

Archives_State :: struct {}

// The active screen OWNS its state. Changing screen == replacing this value.
// No parallel status enum, no loose nav_payload.
Screen_State :: union {
	Menu_State,
	Level_Select_State,
	Settings_State,
	Archives_State,
	Gameplay_State,
}

// ---- Transitions -----------------------------------------------------------

enter :: proc(nav: core.Navigation, ctx: ^Context) -> Screen_State {
	switch n in nav {
	case core.Go_Main_Menu: return init_menu(ctx)
	case core.Go_Level_Select:
		return Level_Select_State {
				unlocked = ctx.progress.unlocked,
				difficulty = n.difficulty,
				viewport = ctx.viewport,
			}
	case core.Go_Gameplay:
		if n.puzzle_index >= 0 && n.puzzle_index < len(PUZZLES) {
			return init_gameplay(PUZZLES[n.puzzle_index])
		}
		return nil
	case core.Go_Archives: return Archives_State{}
	case core.Go_Settings:
		return Settings_State {
				active_tab = n.tab,
				pending_audio = ctx.config.audio,
				pending_graphics = ctx.config.graphics,
			}
	case nil: return nil
	}
	return nil
}

update_screen :: proc(s: ^Screen_State, events: []core.Event) -> core.Navigation {
	switch &v in s^ {
	case Menu_State: return update_menu(&v, events)
	case Level_Select_State: return update_puzzle_select(&v, events)
	case Gameplay_State: return update_gameplay(events)
	case Settings_State: return back_to_menu(events)
	case Archives_State: return back_to_menu(events)
	case nil: return nil
	}
	return nil
}

resize_screen :: proc(s: ^Screen_State, ctx: ^Context) {
	#partial switch &v in s^ {
	case Menu_State: layout_menu(&v, ctx)
	}
}

draw_screen :: proc(s: ^Screen_State, ctx: Context) {
	switch &v in s^ {
	case Menu_State: draw_menu(&v, ctx.renderer)
	case Level_Select_State: draw_puzzle_select(v, ctx)
	case Settings_State: draw_placeholder(ctx, "SETTINGS")
	case Archives_State: draw_placeholder(ctx, "ARCHIVES")
	case Gameplay_State: draw_gameplay(v, ctx)
	case nil:
	}
}
// TODO: Puzzle selection should be it's own file
PUZZLE_COLUMNS :: 4
PUZZLE_GRID_X :: f32(210)
PUZZLE_GRID_Y :: f32(300)
PUZZLE_CARD_W :: f32(246)
PUZZLE_CARD_H :: f32(72)
PUZZLE_CARD_GAP :: f32(12)

puzzle_card_rect :: proc(index: int) -> shared.Rect {
	column := index % PUZZLE_COLUMNS
	row := index / PUZZLE_COLUMNS
	return {
		PUZZLE_GRID_X + f32(column) * (PUZZLE_CARD_W + PUZZLE_CARD_GAP),
		PUZZLE_GRID_Y + f32(row) * (PUZZLE_CARD_H + PUZZLE_CARD_GAP),
		PUZZLE_CARD_W,
		PUZZLE_CARD_H,
	}
}

puzzle_card_at :: proc(position: shared.Vec2) -> int {
	for index in 0 ..< len(PUZZLES) {
		if shared.contains_point(puzzle_card_rect(index), position) {
			return index
		}
	}
	return -1
}

update_puzzle_select :: proc(state: ^Level_Select_State, events: []core.Event) -> core.Navigation {
	for event in events {
		#partial switch input in event {
		case shared.Key_Input: switch input.key {
				case .Up:
					state.selected =
							(state.selected + len(PUZZLES) - PUZZLE_COLUMNS) % len(PUZZLES)
				case .Down: state.selected = (state.selected + PUZZLE_COLUMNS) % len(PUZZLES)
				case .Confirm: return core.Go_Gameplay{puzzle_index = state.selected}
				case .Back: return core.Go_Main_Menu{}
				}

		case shared.Mouse_Input:
			position := input.position / state.viewport.scale
			hit := puzzle_card_at(position)

			if hit >= 0 {
				state.selected = hit
			}

			if input.pressed && hit >= 0 {
				state.pressed = hit
			}

			if input.released {
				if pressed, ok := state.pressed.?; ok {
					state.pressed = nil
					if hit == pressed {
						return core.Go_Gameplay{puzzle_index = pressed}
					}
				}
			}
		}
	}
	return nil
}

puzzle_stars :: proc(rating: int) -> string {
	switch rating {
	case 1: return "★☆☆"
	case 2: return "★★☆"
	case 3: return "★★★"
	}
	return "☆☆☆"
}

draw_puzzle_select :: proc(state: Level_Select_State, ctx: Context) {
	scale := ctx.viewport.scale
	renderer := ctx.renderer
	muted := shared.Color{145, 165, 180, 255}
	white := shared.Color{230, 235, 240, 255}
	mint := shared.Color{100, 220, 190, 255}

	// Centered selection panel.
	renderer.fill_rect({180 * scale, 100 * scale, 1080 * scale, 680 * scale}, {8, 24, 34, 220})
	renderer.outline_rect(
		{180 * scale, 100 * scale, 1080 * scale, 680 * scale},
		2 * scale,
		{80, 190, 190, 255},
	)

	renderer.draw_text("THE LOGIC ALCHEMIST", {640 * scale, 135 * scale}, i32(16 * scale), mint)
	renderer.draw_text("PUZZLE SELECT", {560 * scale, 165 * scale}, i32(34 * scale), white)
	renderer.draw_text(
		"Select a formula to transmute from the codex archives.",
		{420 * scale, 215 * scale},
		i32(15 * scale),
		white,
	)

	for index in 0 ..< len(PUZZLES) {
		rect := puzzle_card_rect(index)
		card := shared.Rect{rect.x * scale, rect.y * scale, rect.w * scale, rect.h * scale}
		selected := index == state.selected

		background := shared.Color{8, 20, 28, 255}
		border := shared.Color{110, 130, 140, 255}
		if selected {
			background = shared.Color{18, 60, 68, 255}
			border = mint
		}

		renderer.fill_rect(card, background)
		renderer.outline_rect(card, 2 * scale, border)
		renderer.draw_text(
			PUZZLES[index].title,
			{(rect.x + 8) * scale, (rect.y + 8) * scale},
			i32(15 * scale),
			mint,
		)
		renderer.draw_text(
			"GOAL:",
			{(rect.x + 8) * scale, (rect.y + 34) * scale},
			i32(13 * scale),
			white,
		)
		renderer.draw_text(
			PUZZLES[index].goal,
			{(rect.x + 54) * scale, (rect.y + 34) * scale},
			i32(13 * scale),
			white,
		)
		renderer.draw_text(
			puzzle_stars(PUZZLES[index].rating),
			{(rect.x + rect.w - 48) * scale, (rect.y + 52) * scale},
			i32(13 * scale),
			mint,
		)
	}

	renderer.draw_text(
		"Up/Down: select    Enter: open puzzle    Esc: back",
		{430 * scale, 835 * scale},
		i32(16 * scale),
		muted,
	)
}

// ---- Placeholders ----------------------------------------------------------

// Esc comes through the event stream like everything else (no rl.IsKeyPressed).
back_to_menu :: proc(events: []core.Event) -> core.Navigation {
	for ev in events {
		if k, ok := ev.(shared.Key_Input); ok && k.key == .Back {
			return core.Go_Main_Menu{}
		}
	}
	return nil
}

draw_placeholder :: proc(ctx: Context, title: string) {
	s := ctx.viewport.scale
	ctx.renderer.draw_text(title, {270 * s, 260 * s}, i32(30 * s), {120, 220, 120, 255})
}
