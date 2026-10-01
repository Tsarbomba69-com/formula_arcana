package main

import rl "vendor:raylib"
import menu "features/main_menu"

main :: proc() {
    screen_w : i32 = 800
    screen_h : i32 = 600

    rl.InitWindow(screen_w, screen_h, "Formula Arcana")
    defer rl.CloseWindow()

    rl.SetTargetFPS(60)

    game_state := menu.Game_State.Menu
    menu_state := menu.init_menu(screen_w, screen_h)

    for !rl.WindowShouldClose() && game_state != .Quit {
        // --- UPDATE ---
        #partial switch game_state {
        case .Menu:
            menu.update_menu(&menu_state, &game_state)
        case .Playing, .Options:
            if rl.IsKeyPressed(.ESCAPE) {
                game_state = .Menu
            }
        }

        // --- DRAW ---
        rl.BeginDrawing()
        rl.ClearBackground(rl.Color{24, 28, 36, 255})

        #partial switch game_state {
        case .Menu:
            menu.draw_menu(&menu_state, screen_w)
        case .Playing:
            rl.DrawText("GAMEPLAY SCREEN", 270, 260, 30, rl.GREEN)
        case .Options:
            rl.DrawText("OPTIONS SCREEN", 280, 260, 30, rl.ORANGE)
        }

        rl.EndDrawing()
    }
}