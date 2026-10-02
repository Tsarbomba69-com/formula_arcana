package shared

// The whole UI tree lives in a fixed-size array (no heap, no pointers).
// Children are referenced by index, so a UI_Tree can be copied/returned by value safely.
UI_MAX_NODES :: 16
UI_MAX_CHILDREN :: 8
BUTTON_FONT_SIZE :: 20

Color :: [4]u8

Insets :: struct {
	top, right, bottom, left: f32,
}

Direction :: enum {
	Vertical,
	Horizontal,
}

Alignment :: enum {
	Start,
	Center,
	End,
}

Button_State :: enum {
	Normal,
	Hover,
	Pressed,
}

// ---- Messages (what a click produces) --------------------------------------

Screen :: enum {
	Main_Menu,
	Level_Select,
	Settings,
}

Difficulty :: enum {
	Easy,
	Standard,
	Hard,
}

Settings_Tab :: enum {
	Audio,
	Graphics,
}

Audio_Settings :: struct {
	master_volume, music_volume, sfx_volume: f32,
	is_muted:                                bool,
}

Graphics_Settings :: struct {
	fullscreen: bool,
	resolution: [2]i32,
	vsync:      bool,
}

Level_Select_Payload :: struct {
	unlocked_levels: []i32, // nil == none unlocked, no allocation
	selected_level:  Maybe(i32),
	difficulty:      Difficulty,
}

Settings_Payload :: struct {
	active_tab:       Settings_Tab,
	pending_audio:    Audio_Settings,
	pending_graphics: Graphics_Settings,
	is_dirty:         bool,
}

Nav_Payload :: union {
	Level_Select_Payload,
	Settings_Payload,
}

Navigate_To :: struct {
	target:  Screen,
	payload: Nav_Payload,
}

Msg :: union {
	Navigate_To,
}

// ---- Node kinds ------------------------------------------------------------

Container :: struct {
	direction: Direction,
	alignment: Alignment, // cross-axis alignment of children
	spacing:   f32,
	padding:   Insets,
}

Text :: struct {
	content:   cstring,
	font_size: i32,
	color:     Color,
	is_bold:   bool,
}

Button :: struct {
	label:         cstring,
	state:         Button_State,
	normal_color:  Color,
	hover_color:   Color,
	pressed_color: Color,
	padding:       Insets,
	on_click:      Msg,
}

Node_Kind :: union {
	Container,
	Text,
	Button,
}

Node :: struct {
	kind:        Node_Kind,
	rect:        Rect, // filled by ui_layout
	children:    [UI_MAX_CHILDREN]int,
	child_count: int,
}

UI_Tree :: struct {
	nodes: [UI_MAX_NODES]Node,
	count: int,
	root:  int,
}

// ---- Building --------------------------------------------------------------

// Bottom-up: add leaves first, then the parent with its children's indices.
// The last node added becomes the root.
ui_add :: proc(t: ^UI_Tree, kind: Node_Kind, children: ..int) -> int {
	assert(t.count < UI_MAX_NODES, "UI_MAX_NODES exceeded")
	assert(len(children) <= UI_MAX_CHILDREN, "UI_MAX_CHILDREN exceeded")

	idx := t.count
	t.count += 1

	n := &t.nodes[idx]
	n^ = {
		kind        = kind,
		child_count = len(children),
	}
	for c, i in children {
		n.children[i] = c
	}

	t.root = idx
	return idx
}

// ---- Layout ----------------------------------------------------------------

Measure_Text :: #type proc(text: cstring, font_size: i32) -> i32

// Centers the root on the screen.
ui_layout :: proc(t: ^UI_Tree, screen: Vec2, measure: Measure_Text) {
	size := ui_measure(t, t.root, measure)
	ui_place(t, t.root, {(screen.x - size.x) / 2, (screen.y - size.y) / 2})
}

// Pass 1 (bottom-up): compute each node's size.
ui_measure :: proc(t: ^UI_Tree, i: int, measure: Measure_Text) -> Vec2 {
	n := &t.nodes[i]
	size: Vec2

	switch k in n.kind {
	case nil:
	case Text: size = {f32(measure(k.content, k.font_size)), f32(k.font_size)}
	case Button:
		size = {
				f32(measure(k.label, BUTTON_FONT_SIZE)) + k.padding.left + k.padding.right,
				f32(BUTTON_FONT_SIZE) + k.padding.top + k.padding.bottom,
			}
	case Container:
		main_axis, cross_axis: f32
		for c in n.children[:n.child_count] {
			cs := ui_measure(t, c, measure)
			if k.direction == .Vertical {
				main_axis += cs.y
				cross_axis = max(cross_axis, cs.x)
			} else {
				main_axis += cs.x
				cross_axis = max(cross_axis, cs.y)
			}
		}
		if n.child_count > 1 {
			main_axis += k.spacing * f32(n.child_count - 1)
		}
		size = k.direction == .Vertical ? Vec2{cross_axis, main_axis} : Vec2{main_axis, cross_axis}
		size.x += k.padding.left + k.padding.right
		size.y += k.padding.top + k.padding.bottom
	}

	n.rect.w, n.rect.h = size.x, size.y
	return size
}

// Pass 2 (top-down): assign absolute positions.
ui_place :: proc(t: ^UI_Tree, i: int, origin: Vec2) {
	n := &t.nodes[i]
	n.rect.x, n.rect.y = origin.x, origin.y

	c, is_container := n.kind.(Container)
	if !is_container { return }

	inner_w := n.rect.w - c.padding.left - c.padding.right
	inner_h := n.rect.h - c.padding.top - c.padding.bottom
	cursor := Vec2{origin.x + c.padding.left, origin.y + c.padding.top}
	vertical := c.direction == .Vertical

	for ci in n.children[:n.child_count] {
		child := &t.nodes[ci]

		avail := vertical ? inner_w : inner_h
		used := vertical ? child.rect.w : child.rect.h
		offset: f32
		switch c.alignment {
		case .Start:
		case .Center: offset = (avail - used) / 2
		case .End: offset = avail - used
		}

		if vertical {
			ui_place(t, ci, {cursor.x + offset, cursor.y})
			cursor.y += child.rect.h + c.spacing
		} else {
			ui_place(t, ci, {cursor.x, cursor.y + offset})
			cursor.x += child.rect.w + c.spacing
		}
	}
}
