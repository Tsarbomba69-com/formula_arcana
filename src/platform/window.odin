package platform

import "../core"
import "../shared"
import rl "vendor:raylib"

Window :: struct {
	// ... window properties
}

poll_events :: proc(ch: ^core.Event_Channel) {
	if rl.IsWindowResized() {
		w := rl.GetScreenWidth()
		h := rl.GetScreenHeight()

		// Publish to the channel
		core.publish(ch, core.Window_Resized{width = w, height = h})
	}

	m_pos := rl.GetMousePosition()
	core.publish(
		ch,
		shared.Mouse_Input {
			position = {m_pos.x, m_pos.y},
			clicked = rl.IsMouseButtonPressed(.LEFT),
		},
	)
}
