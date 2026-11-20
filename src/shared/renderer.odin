package shared

// The only door to the graphics backend. Features and widgets draw through
// this; `platform` fills it with raylib; tests fill only what they need.

Measure_Text :: #type proc(text: string, font_size: i32, font_id: Font_Id = INVALID_FONT_ID) -> f32

Renderer :: struct {
	begin_frame:  proc(),
	end_frame:    proc(),
	clear:        proc(color: Color),
	measure_text: Measure_Text,
	draw_text:    proc(
		text: string,
		pos: Vec2,
		font_size: i32,
		color: Color,
		font_id: Font_Id = INVALID_FONT_ID,
	),
	fill_rect:    proc(r: Rect, color: Color),
	outline_rect: proc(r: Rect, thickness: f32, color: Color),
	draw_texture: proc(id: Texture_Id, dest: Rect, tint: Color),
	begin_clip:   proc(r: Rect),
	end_clip:     proc(),
}
