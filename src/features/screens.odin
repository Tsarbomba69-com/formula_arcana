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
	selected:   Maybe(int),
	difficulty: core.Difficulty,
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
		return Level_Select_State{unlocked = ctx.progress.unlocked, difficulty = n.difficulty}
	case core.Go_Gameplay: return init_gameplay(FIRST_PUZZLE)
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
	case Level_Select_State: return update_puzzle_select(events)
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
	case Level_Select_State: draw_puzzle_select(ctx)
	case Settings_State: draw_placeholder(ctx, "SETTINGS")
	case Archives_State: draw_placeholder(ctx, "ARCHIVES")
	case Gameplay_State: draw_gameplay(v, ctx)
	case nil:
	}
}

update_puzzle_select :: proc(events: []core.Event) -> core.Navigation {
	for event in events {
		if key, ok := event.(shared.Key_Input); ok {
			switch key.key {
			case .Up, .Down:
			case .Confirm: return core.Go_Gameplay{}
			case .Back: return core.Go_Main_Menu{}
			}
		}
	}
	return nil
}

draw_puzzle_select :: proc(ctx: Context) {
	s := ctx.viewport.scale
	ctx.renderer.draw_text("PUZZLE SELECT", {72 * s, 72 * s}, i32(30 * s), {230, 235, 240, 255})
	ctx.renderer.draw_text(FIRST_PUZZLE.title, {72 * s, 150 * s}, i32(24 * s), {100, 220, 190, 255})
	ctx.renderer.draw_text("Goal: x + 0 = x", {72 * s, 194 * s}, i32(20 * s), {230, 235, 240, 255})
	ctx.renderer.draw_text("Enter: open puzzle", {72 * s, 850 * s}, i32(16 * s), {145, 165, 180, 255})
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
