package main

import "core"
import "features"
import "platform"
import "shared"
import rl "vendor:raylib"

Game :: struct {
	event_channel: core.Event_Channel,
	menu_state:    features.Menu_State,
	status:        core.Game_State,
	nav_payload:   shared.Nav_Payload, // data handed over by the last Navigate_To
	screen_w:      i32,
	screen_h:      i32,
}

init :: proc(app: ^Game, w, h: i32) {
	app.screen_w = w
	app.screen_h = h
	app.status = .Menu
	app.menu_state = features.init_menu(w, h)
}

update :: proc(app: ^Game) {
	// 1. Platform produces events into channel
	platform.poll_events(&app.event_channel)

	// 2. Drain channel into a frame-local event slice
	events := make([dynamic]core.Event, context.temp_allocator)

	for ev in core.poll(&app.event_channel) {
		append(&events, ev)
	}

	// 3. Process top-level system events
	for ev in events {
		#partial switch e in ev {
		case core.Window_Resized:
			app.screen_w = e.width
			app.screen_h = e.height
			features.layout_menu(&app.menu_state, e.width, e.height)
		case core.State_Changed: app.status = e.target_state
		}
	}

	// 4. Pass the frame event stream to active feature domain logic
	#partial switch app.status {
	case .Menu:
		msg := features.update_menu(&app.menu_state, events[:])
		#partial switch m in msg {
		case shared.Navigate_To:
			navigate(app, m)
		}
	case .Playing, .Options: if rl.IsKeyPressed(.ESCAPE) {
				app.status = .Menu
			}
	}
}

navigate :: proc(app: ^Game, nav: shared.Navigate_To) {
	app.nav_payload = nav.payload

	switch nav.target {
	case .Main_Menu:    app.status = .Menu
	case .Level_Select: app.status = .Playing // TODO: dedicated level-select state
	case .Settings:     app.status = .Options
	}
}

draw :: proc(app: ^Game) {
	rl.BeginDrawing()
	rl.ClearBackground(rl.Color{24, 28, 36, 255})

	#partial switch app.status {
	case .Menu: features.draw_menu(&app.menu_state)
	case .Playing: rl.DrawText("GAMEPLAY SCREEN", 270, 260, 30, rl.GREEN)
	case .Options: rl.DrawText("OPTIONS SCREEN", 280, 260, 30, rl.ORANGE)
	case .Quit:
	}

	rl.EndDrawing()
}

main :: proc() {
	screen_w: i32 = 800
	screen_h: i32 = 600
	rl.InitWindow(screen_w, screen_h, "Formula Arcana")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)
	app: Game
	init(&app, screen_w, screen_h)

	for !rl.WindowShouldClose() && app.status != .Quit {
		free_all(context.temp_allocator)
		update(&app)
		draw(&app)
	}
}
