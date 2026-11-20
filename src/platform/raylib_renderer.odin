package platform

import "../shared"
import "core:log"
import "core:strings"
import rl "vendor:raylib"

@(private)
g_active_tex_mgr: ^Texture_Manager

@(private)
g_active_font_mgr: ^Font_Manager

@(private)
RAYLIB_CLIP_STACK_CAPACITY :: 40

@(private)
g_clip_stack: [RAYLIB_CLIP_STACK_CAPACITY]shared.Rect

@(private)
g_clip_depth: int

@(private)
raylib_begin_clip :: proc(rect: shared.Rect) {
	clipped := rect
	if g_clip_depth > 0 {
		parent := g_clip_stack[g_clip_depth - 1]
		left := max(rect.x, parent.x)
		top := max(rect.y, parent.y)
		right := min(rect.x + rect.w, parent.x + parent.w)
		bottom := min(rect.y + rect.h, parent.y + parent.h)
		clipped = {left, top, max(right - left, 0), max(bottom - top, 0)}
	}
	assert(g_clip_depth < RAYLIB_CLIP_STACK_CAPACITY, "UI clip stack exceeded")
	g_clip_stack[g_clip_depth] = clipped
	g_clip_depth += 1
	rl.BeginScissorMode(i32(clipped.x), i32(clipped.y), i32(clipped.w), i32(clipped.h))
}

@(private)
raylib_end_clip :: proc() {
	assert(g_clip_depth > 0, "UI clip stack underflow")
	g_clip_depth -= 1
	rl.EndScissorMode()
	if g_clip_depth > 0 {
		parent := g_clip_stack[g_clip_depth - 1]
		rl.BeginScissorMode(i32(parent.x), i32(parent.y), i32(parent.w), i32(parent.h))
	}
}

// The ONLY file (with window.odin) that talks to raylib for drawing.
raylib_renderer :: proc(tex_mgr: ^Texture_Manager, font_mgr: ^Font_Manager) -> shared.Renderer {
	g_active_tex_mgr = tex_mgr
	g_active_font_mgr = font_mgr
	return {
		begin_frame = proc() { rl.BeginDrawing() },
		end_frame = proc() { rl.EndDrawing() },
		clear = proc(c: shared.Color) { rl.ClearBackground(rl.Color(c)) },
		measure_text = proc(
			text: string,
			font_size: i32,
			font_id: shared.Font_Id = shared.INVALID_FONT_ID,
		) -> f32 {
			cstr := strings.clone_to_cstring(text, context.temp_allocator)
			if font, ok := get_font(g_active_font_mgr, font_id); ok {
				return rl.MeasureTextEx(font, cstr, f32(font_size), 1.0).x
			}
			return f32(rl.MeasureText(cstr, font_size))
		},
		draw_text = proc(
			text: string,
			pos: shared.Vec2,
			font_size: i32,
			color: shared.Color,
			font_id: shared.Font_Id,
		) {
			cstr := strings.clone_to_cstring(text, context.temp_allocator)
			rl_col := rl.Color{color[0], color[1], color[2], color[3]}
			if font, ok := get_font(g_active_font_mgr, font_id); ok {
				rl.DrawTextEx(font, cstr, {pos.x, pos.y}, f32(font_size), 1.0, rl_col)
				return
			}
			rl.DrawText(cstr, i32(pos.x), i32(pos.y), font_size, rl_col)
		},
		fill_rect = proc(r: shared.Rect, c: shared.Color) {
			rl.DrawRectangleRec({r.x, r.y, r.w, r.h}, rl.Color(c))
		},
		outline_rect = proc(r: shared.Rect, thickness: f32, c: shared.Color) {
			rl.DrawRectangleLinesEx({r.x, r.y, r.w, r.h}, thickness, rl.Color(c))
		},
		draw_texture = proc(id: shared.Texture_Id, dest: shared.Rect, tint: shared.Color) {
			raylib_tex, ok := get_texture(g_active_tex_mgr, id)
			if !ok {
				log.errorf("Failed to fetch texture from manager with % ID", id)
				return
			}
			source := rl.Rectangle{0, 0, f32(raylib_tex.width), f32(raylib_tex.height)}
			target := rl.Rectangle{dest.x, dest.y, dest.w, dest.h}
			rl.DrawTexturePro(raylib_tex, source, target, {0, 0}, 0.0, rl.Color(tint))
		},
		begin_clip = raylib_begin_clip,
		end_clip = raylib_end_clip,
	}
}
