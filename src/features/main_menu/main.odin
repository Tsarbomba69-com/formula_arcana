package main_menu

import rl "vendor:raylib"

init_menu :: proc(screen_w, screen_h: i32) -> Menu_State {
	btn_w: f32 = 250
	btn_h: f32 = 50
	start_x: f32 = f32(screen_w) / 2 - btn_w / 2

	return Menu_State {
		buttons = [3]Button {
			{rect = {start_x, 220, btn_w, btn_h}, text = "Play Game", action = .Playing},
			{rect = {start_x, 290, btn_w, btn_h}, text = "Options", action = .Options},
			{rect = {start_x, 360, btn_w, btn_h}, text = "Exit to Desktop", action = .Quit},
		},
	}
}

update_menu :: proc(state: ^Menu_State, current_game_state: ^Game_State) {
	mouse_pos := rl.GetMousePosition()

	if rl.IsMouseButtonPressed(.LEFT) {
		for btn in state.buttons {
			if rl.CheckCollisionPointRec(mouse_pos, btn.rect) {
				current_game_state^ = btn.action
			}
		}
	}
}

draw_menu :: proc(state: ^Menu_State, screen_w: i32) {
	mouse_pos := rl.GetMousePosition()

	title_text :: "FORMULA ARCANA"
	title_w := rl.MeasureText(title_text, 40)
	rl.DrawText(title_text, screen_w / 2 - title_w / 2, 120, 40, rl.RAYWHITE)

	for btn in state.buttons {
		is_hovered := rl.CheckCollisionPointRec(mouse_pos, btn.rect)

		bg_color := is_hovered ? rl.DARKBLUE : rl.BLUE
		text_color := is_hovered ? rl.YELLOW : rl.WHITE

		rl.DrawRectangleRec(btn.rect, bg_color)
		rl.DrawRectangleLinesEx(btn.rect, 2, is_hovered ? rl.GOLD : rl.LIGHTGRAY)

		tw := rl.MeasureText(cstring(raw_data(btn.text)), 20)
		tx := i32(btn.rect.x + btn.rect.width / 2) - tw / 2
		ty := i32(btn.rect.y + btn.rect.height / 2) - 10

		rl.DrawText(cstring(raw_data(btn.text)), tx, ty, 20, text_color)
	}
}
