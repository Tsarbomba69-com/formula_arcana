package main

import "core"
import "features"
import "platform"
import "shared"

WINDOW_W :: 1280
WINDOW_H :: 720

Game :: struct {
	events: core.Event_Channel,
	screen: features.Screen_State, // the active screen owns its own state
	ctx:    features.Context, // config, progress, viewport, renderer
}

init :: proc(app: ^Game, w, h: i32) {
	app.ctx = {
		config   = core.default_config(),
		viewport = shared.viewport_of(w, h),
		renderer = platform.raylib_renderer(),
	}
	app.screen = features.enter(core.Go_Main_Menu{}, app.ctx)
}

update :: proc(app: ^Game) {
	// 1. Platform produces events
	platform.poll_events(&app.events)

	// 2. Drain into a frame-local slice
	events := make([dynamic]core.Event, context.temp_allocator)
	for ev in core.poll(&app.events) {
		append(&events, ev)
	}

	// 3. App-level events
	for ev in events {
		#partial switch e in ev {
		case core.Window_Resized:
			app.ctx.viewport = shared.viewport_of(e.width, e.height)
			features.resize_screen(&app.screen, app.ctx)
		}
	}

	// 4. The active screen decides; a Navigation replaces the screen.
	if nav := features.update_screen(&app.screen, events[:]); nav != nil {
		app.screen = features.enter(nav, app.ctx)
	}
}

draw :: proc(app: ^Game) {
	r := app.ctx.renderer
	r.begin_frame()
	r.clear({24, 28, 36, 255})
	features.draw_screen(&app.screen, app.ctx)
	r.end_frame()
}

main :: proc() {
	platform.open_window(WINDOW_W, WINDOW_H, "Formula Arcana")
	defer platform.close_window()

	app: Game
	init(&app, WINDOW_W, WINDOW_H)

	for !platform.should_close() {
		free_all(context.temp_allocator)
		update(&app)
		draw(&app)
	}
}
