package shared

Vec2 :: [2]f32

Rect :: struct {
	x, y, w, h: f32,
}

contains_point :: proc(r: Rect, p: Vec2) -> bool {
	return p.x >= r.x && p.x <= r.x + r.w && p.y >= r.y && p.y <= r.y + r.h
}

// UI is laid out in a fixed 1440x900 "design space" and scaled when drawn.
DESIGN_W :: 1440.0
DESIGN_H :: 900.0

Viewport :: struct {
	size:  Vec2, // real window size in pixels
	scale: f32, // real px per design px
}

viewport_of :: proc(w, h: i32) -> Viewport {
	size := Vec2{f32(w), f32(h)}
	return {size, min(size.x / DESIGN_W, size.y / DESIGN_H)}
}

// ---- Input events (edges, not levels) --------------------------------------

Mouse_Input :: struct {
	position: Vec2, // real pixels
	pressed:  bool, // went down this frame
	released: bool, // went up this frame
}

Nav_Key :: enum {
	Up,
	Down,
	Confirm,
	Back,
}

Key_Input :: struct {
	key: Nav_Key,
}

// Texture_Id uniquely identifies a loaded GPU texture asset.
Texture_Id :: distinct u32

// INVALID_TEXTURE_ID represents an unassigned or missing texture reference.
INVALID_TEXTURE_ID :: Texture_Id(0)

Font_Id :: distinct u32

INVALID_FONT_ID :: Font_Id(0)

Color :: [4]u8
