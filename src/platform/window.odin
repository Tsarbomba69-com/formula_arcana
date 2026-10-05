package platform

import "../core"
import "../shared"
import rl "vendor:raylib"

open_window :: proc(w, h: i32, title: cstring) {
	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.InitWindow(w, h, title)
	rl.SetTargetFPS(60)
}

close_window :: proc() { rl.CloseWindow() }
should_close :: proc() -> bool { return rl.WindowShouldClose() }

// Translates raylib state into the game's event stream.
poll_events :: proc(ch: ^core.Event_Channel) {
	core.publish(
		ch,
		shared.Mouse_Input {
			position = shared.Vec2(rl.GetMousePosition()),
			pressed = rl.IsMouseButtonPressed(.LEFT),
			released = rl.IsMouseButtonReleased(.LEFT),
		},
	)

	if rl.IsKeyPressed(.UP) || rl.IsKeyPressed(.W) { core.publish(ch, shared.Key_Input{.Up}) }
	if rl.IsKeyPressed(.DOWN) || rl.IsKeyPressed(.S) { core.publish(ch, shared.Key_Input{.Down}) }
	if rl.IsKeyPressed(.ENTER) ||
	   rl.IsKeyPressed(.SPACE) { core.publish(ch, shared.Key_Input{.Confirm}) }
	if rl.IsKeyPressed(.ESCAPE) { core.publish(ch, shared.Key_Input{.Back}) }

	if rl.IsWindowResized() {
		core.publish(
			ch,
			core.Window_Resized{width = rl.GetScreenWidth(), height = rl.GetScreenHeight()},
		)
	}
}
