package platform

import "../shared"
import "core:strings"
import rl "vendor:raylib"

// The ONLY file (with window.odin) that talks to raylib for drawing.
raylib_renderer :: proc() -> shared.Renderer {
	return {
		begin_frame = proc() { rl.BeginDrawing() },
		end_frame = proc() { rl.EndDrawing() },
		clear = proc(c: shared.Color) { rl.ClearBackground(rl.Color(c)) },
		measure_text = proc(text: string, font_size: i32) -> f32 {
			cs := strings.clone_to_cstring(text, context.temp_allocator)
			return f32(rl.MeasureText(cs, font_size))
		},
		draw_text = proc(text: string, pos: shared.Vec2, font_size: i32, c: shared.Color) {
			cs := strings.clone_to_cstring(text, context.temp_allocator)
			rl.DrawText(cs, i32(pos.x), i32(pos.y), font_size, rl.Color(c))
		},
		fill_rect = proc(r: shared.Rect, c: shared.Color) {
			rl.DrawRectangleRec({r.x, r.y, r.w, r.h}, rl.Color(c))
		},
		outline_rect = proc(r: shared.Rect, thickness: f32, c: shared.Color) {
			rl.DrawRectangleLinesEx({r.x, r.y, r.w, r.h}, thickness, rl.Color(c))
		},
	}
}
