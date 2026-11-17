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
	unlocked:     core.Level_Set, // from save data, not from the menu
	selected:     int,
	difficulty:   core.Difficulty,
	viewport:     shared.Viewport,
	tree:         core.UI_Tree,
	ix:           core.Interaction,
	puzzle_nodes: [len(PUZZLES)]int,
	back_node:    int,
	font:         shared.Font_Id,
	pressed:      Maybe(int), // used only by direct, uninitialized state callers
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
	case core.Go_Level_Select: return init_puzzle_select(ctx, n.difficulty)
	case core.Go_Gameplay:
		if n.puzzle_index >= 0 && n.puzzle_index < len(PUZZLES) {
			return init_gameplay(ctx, PUZZLES[n.puzzle_index], run_info_for(ctx.progress))
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
	case Gameplay_State: return update_gameplay(&v, events)
	case Settings_State: return back_to_menu(events)
	case Archives_State: return back_to_menu(events)
	case nil: return nil
	}
	return nil
}

resize_screen :: proc(s: ^Screen_State, ctx: ^Context) {
	#partial switch &v in s^ {
	case Menu_State: layout_menu(&v, ctx)
	case Level_Select_State: layout_puzzle_select(&v, ctx)
	}
}

draw_screen :: proc(s: ^Screen_State, ctx: Context) {
	switch &v in s^ {
	case Menu_State: draw_menu(&v, ctx.renderer)
	case Level_Select_State: draw_puzzle_select(&v, ctx)
	case Settings_State: draw_placeholder(ctx, "SETTINGS")
	case Archives_State: draw_placeholder(ctx, "ARCHIVES")
	case Gameplay_State: draw_gameplay(&v, ctx)
	case nil:
	}
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
