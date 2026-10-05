package shared

// Generic widget tree + layout. Knows NOTHING about screens or game messages:
// a button just carries an `action` id, and the owning feature decides what it means.
// The whole tree is value-typed: fixed array, children by index, copy-safe.

UI_MAX_NODES :: 16
UI_MAX_CHILDREN :: 8
UI_MAX_LINES :: 4
LINE_HEIGHT :: 1.3
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

// ---- Node kinds ------------------------------------------------------------

Container :: struct {
	direction: Direction,
	alignment: Alignment, // cross-axis alignment of children
	spacing:   f32,
	padding:   Insets,
}

Text :: struct {
	content:    string,
	font_size:  i32,
	color:      Color,
	is_bold:    bool,
	align:      Alignment, // line alignment inside the node's own box
	max_width:  f32, // 0 == never wrap
	// -- layout output (filled by ui_layout; byte ranges into `content`) --
	line_count: int,
	lines:      [UI_MAX_LINES][2]int,
}

Button :: struct {
	label:         string,
	action:        int, // opaque id; the owning feature maps it to behaviour
	width:         f32, // 0 == fit content
	normal_color:  Color,
	hover_color:   Color,
	pressed_color: Color,
	padding:       Insets,
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

// ---- Interaction state lives OUTSIDE the nodes ------------------------------
// Exactly one focus; at most one hover; at most one pressed.

Interaction :: struct {
	focus:   int, // node index
	hover:   Maybe(int),
	pressed: Maybe(int),
}

Button_Visual :: enum {
	Rest,
	Hover,
	Pressed,
	Focused,
}

button_visual :: proc(ix: Interaction, i: int) -> Button_Visual {
	if p, ok := ix.pressed.?; ok && p == i { return .Pressed }
	if h, ok := ix.hover.?; ok && h == i { return .Hover }
	if ix.focus == i { return .Focused }
	return .Rest
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

// ---- Queries ---------------------------------------------------------------

// Button node indices in creation order (== visual order when built top to bottom).
ui_buttons :: proc(t: ^UI_Tree) -> (list: [UI_MAX_NODES]int, count: int) {
	for i in 0 ..< t.count {
		if _, ok := t.nodes[i].kind.(Button); ok {
			list[count] = i
			count += 1
		}
	}
	return
}

ui_first_button :: proc(t: ^UI_Tree) -> int {
	list, count := ui_buttons(t)
	return count > 0 ? list[0] : 0
}

// `p` is in design space.
ui_button_at :: proc(t: ^UI_Tree, p: Vec2) -> (idx: int, ok: bool) {
	for i in 0 ..< t.count {
		if _, is_button := t.nodes[i].kind.(Button);
		   is_button && contains_point(t.nodes[i].rect, p) {
			return i, true
		}
	}
	return 0, false
}

// dir: +1 next, -1 previous. Wraps around.
ui_focus_step :: proc(t: ^UI_Tree, ix: ^Interaction, dir: int) {
	list, count := ui_buttons(t)
	if count == 0 { return }
	cur := 0
	for i in 0 ..< count {
		if list[i] == ix.focus { cur = i }
	}
	ix.focus = list[(cur + dir + count) % count]
}

// ---- Text wrapping ---------------------------------------------------------

@(private)
text_push_line :: proc(k: ^Text, start, end: int) {
	assert(k.line_count < UI_MAX_LINES, "UI_MAX_LINES exceeded")
	k.lines[k.line_count] = {start, end}
	k.line_count += 1
}

// Greedy word wrap on spaces. Fills k.lines, returns the widest line.
text_wrap :: proc(k: ^Text, measure: Measure_Text) -> (width: f32) {
	k.line_count = 0
	s := k.content

	if k.max_width <= 0 {
		text_push_line(k, 0, len(s))
	} else {
		start, last_space, i := 0, -1, 0
		for i <= len(s) {
			if i == len(s) || s[i] == ' ' {
				if last_space >= 0 && measure(s[start:i], k.font_size) > k.max_width {
					text_push_line(k, start, last_space)
					start = last_space + 1
					last_space = -1
					continue // re-test this same space against the new line
				}
				last_space = i
			}
			i += 1
		}
		text_push_line(k, start, len(s))
	}

	for ln in k.lines[:k.line_count] {
		width = max(width, measure(k.content[ln[0]:ln[1]], k.font_size))
	}
	return
}

// ---- Layout ----------------------------------------------------------------

// `design` is the available area in design units. Centers the root in it.
ui_layout :: proc(t: ^UI_Tree, design: Vec2, measure: Measure_Text) {
	size := ui_measure(t, t.root, measure)
	ui_place(t, t.root, {(design.x - size.x) / 2, (design.y - size.y) / 2})
}

// Pass 1 (bottom-up): compute each node's size.
ui_measure :: proc(t: ^UI_Tree, i: int, measure: Measure_Text) -> Vec2 {
	n := &t.nodes[i]
	size: Vec2

	switch &k in n.kind {
	case nil:
	case Text:
		w := text_wrap(&k, measure)
		size = {w, f32(k.line_count) * f32(k.font_size) * LINE_HEIGHT}
	case Button:
		w := measure(k.label, BUTTON_FONT_SIZE) + k.padding.left + k.padding.right
		if k.width > 0 { w = k.width }
		size = {w, f32(BUTTON_FONT_SIZE) + k.padding.top + k.padding.bottom}
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
