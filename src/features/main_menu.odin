package main_menu

import "../shared"
import rl "vendor:raylib"

Menu_Action :: enum {
	None,
	Play,
	Options,
	Quit,
}

Button :: struct {
	rect:   shared.Rect, // Uses engine math type instead of rl.Rectangle
	text:   string,
	action: Menu_Action,
}

Menu_State :: struct {
	buttons: [3]Button,
	mouse_pos: shared.Vec2, // Cached for hover rendering
}

init_menu :: proc(screen_w, screen_h: i32) -> Menu_State {
	btn_w: f32 = 250
	btn_h: f32 = 50
	start_x: f32 = f32(screen_w) / 2 - btn_w / 2

	return Menu_State {
		buttons = [3]Button {
			{rect = {start_x, 220, btn_w, btn_h}, text = "Play Game", action = .Play},
			{rect = {start_x, 290, btn_w, btn_h}, text = "Options", action = .Options},
			{rect = {start_x, 360, btn_w, btn_h}, text = "Exit to Desktop", action = .Quit},
		},
	}
}

// Pure domain logic: consumes input state passed down from frame update
update_menu :: proc(state: ^Menu_State, input: shared.Mouse_Input) -> Menu_Action {
	state.mouse_pos = input.position

	if input.clicked {
		for btn in state.buttons {
			if shared.contains_point(btn.rect, input.position) {
				state.mouse_pos = input.position
				return btn.action
			}
		}
	}

	return .None
}

draw_menu :: proc(state: ^Menu_State, screen_w: i32) {
	title_text :: "FORMULA ARCANA"
	title_w := rl.MeasureText(title_text, 40)
	rl.DrawText(title_text, screen_w / 2 - title_w / 2, 120, 40, rl.RAYWHITE)

	for btn in state.buttons {
		is_hovered := shared.contains_point(btn.rect, state.mouse_pos)

		bg_color := is_hovered ? rl.DARKBLUE : rl.BLUE
		text_color := is_hovered ? rl.YELLOW : rl.WHITE

		rl_rect := rl.Rectangle{btn.rect.x, btn.rect.y, btn.rect.w, btn.rect.h}

		rl.DrawRectangleRec(rl_rect, bg_color)
		rl.DrawRectangleLinesEx(rl_rect, 2, is_hovered ? rl.GOLD : rl.LIGHTGRAY)

		tw := rl.MeasureText(cstring(raw_data(btn.text)), 20)
		tx := i32(btn.rect.x + btn.rect.w / 2) - tw / 2
		ty := i32(btn.rect.y + btn.rect.h / 2) - 10

		rl.DrawText(cstring(raw_data(btn.text)), tx, ty, 20, text_color)
	}
}