package features

import "../core"
import "../shared"

// Everything a screen needs from the app, passed in (never reached for).
Context :: struct {
	config:   core.Config,
	progress: core.Progress,
	viewport: shared.Viewport,
	renderer: shared.Renderer,
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
}

// ---- Transitions -----------------------------------------------------------

enter :: proc(nav: core.Navigation, ctx: Context) -> Screen_State {
	switch n in nav {
	case core.Go_Main_Menu: return init_menu(ctx)
	case core.Go_Level_Select:
		return Level_Select_State{unlocked = ctx.progress.unlocked, difficulty = n.difficulty}
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
	case Level_Select_State: return back_to_menu(events)
	case Settings_State: return back_to_menu(events)
	case Archives_State: return back_to_menu(events)
	case nil: return nil
	}
	return nil
}

resize_screen :: proc(s: ^Screen_State, ctx: Context) {
	#partial switch &v in s^ {
	case Menu_State: layout_menu(&v, ctx)
	}
}

draw_screen :: proc(s: ^Screen_State, ctx: Context) {
	switch &v in s^ {
	case Menu_State: draw_menu(&v, ctx.renderer)
	case Level_Select_State: draw_placeholder(ctx, "LEVEL SELECT")
	case Settings_State: draw_placeholder(ctx, "SETTINGS")
	case Archives_State: draw_placeholder(ctx, "ARCHIVES")
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
