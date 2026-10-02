package main

import "core"
import "platform"
import "features"
import "shared"
import rl "vendor:raylib"

Game :: struct {
	event_channel: core.Event_Channel,
	menu_state:    features.Menu_State,
	status:        core.Game_State,
	screen_w:      i32,
	screen_h:      i32,
	mouse_input:     shared.Mouse_Input,
}

init :: proc(app: ^Game, w, h: i32) {
	app.screen_w = w
	app.screen_h = h
	app.status = .Menu
	app.menu_state = features.init_menu(w, h)
}

update :: proc(app: ^Game) {
	// 1. Platform produces events
	platform.poll_input_and_events(&app.event_channel)

	// 2. Consume events across active feature modules
	for ev in core.poll(&app.event_channel) {
		#partial switch e in ev {
		case core.Window_Resized:
			app.screen_w = e.width
			app.screen_h = e.height
		case core.State_Changed:
			app.status = e.target_state
        case shared.Mouse_Input:
            app.mouse_input = e
		}
	}

	// 3. Feature updates driven by game status
	#partial switch app.status {
	case .Menu:
		features.update_menu(&app.menu_state, app.mouse_input)
	case .Playing, .Options:
		if rl.IsKeyPressed(.ESCAPE) {
			app.status = .Menu
		}
	}
}

draw :: proc(app: ^Game) {
	rl.BeginDrawing()
	rl.ClearBackground(rl.Color{24, 28, 36, 255})

	#partial switch app.status {
	case .Menu:
		features.draw_menu(&app.menu_state, app.screen_w)
	case .Playing:
		rl.DrawText("GAMEPLAY SCREEN", 270, 260, 30, rl.GREEN)
	case .Options:
		rl.DrawText("OPTIONS SCREEN", 280, 260, 30, rl.ORANGE)
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
		update(&app)
		draw(&app)
	}
}