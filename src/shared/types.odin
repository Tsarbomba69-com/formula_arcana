package shared

Vec2 :: [2]f32

Rect :: struct {
	x, y, w, h: f32,
}

contains_point :: proc(r: Rect, p: Vec2) -> bool {
	return p.x >= r.x && p.x <= r.x + r.w && p.y >= r.y && p.y <= r.y + r.h
}

Mouse_Input :: struct {
	position: Vec2,
	clicked:  bool,
}