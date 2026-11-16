package features

import "core:log"
import "../core"
import "../shared"

PUZZLE_COLUMNS :: 4
PUZZLE_CARD_W :: f32(246)
PUZZLE_CARD_H :: f32(72)
PUZZLE_CARD_GAP :: f32(12)
PUZZLE_FONT_PATH: cstring = "assets/fonts/DejaVuSans.ttf"
PUZZLE_BACKGROUND_PATH: cstring = "assets/images/main_menu_bg.png"

Puzzle_Select_Action :: enum int {
	Back_To_Menu = -1,
}

init_puzzle_select :: proc(
	ctx: ^Context,
	difficulty: core.Difficulty,
) -> (
	state: Level_Select_State,
) {
	state.unlocked = ctx.progress.unlocked
	state.difficulty = difficulty
	state.viewport = ctx.viewport

	if ctx.load_font != nil {
		state.font, _ = ctx.load_font(PUZZLE_FONT_PATH, 64)
	}
	if state.font == shared.INVALID_FONT_ID {
		log.warnf("Failed to load UI font at %s, falling back to default", PUZZLE_FONT_PATH)
	}

	t := &state.tree
	white := shared.Color{230, 235, 240, 255}
	mint := shared.Color{100, 220, 190, 255}

	eyebrow := core.ui_add(
		t,
		core.Text {
			content = "THE LOGIC ALCHEMIST",
			font_size = 16,
			color = mint,
			font = state.font,
		},
	)
	title := core.ui_add(
		t,
		core.Text{content = "PUZZLE SELECT", font_size = 34, color = white, font = state.font},
	)
	description := core.ui_add(
		t,
		core.Text {
			content = "Select a formula to transmute from the codex archives.",
			font_size = 15,
			color = white,
			align = .Center,
			max_width = 1020,
			font = state.font,
		},
	)
	header := core.ui_add(
		t,
		core.Container{direction = .Vertical, alignment = .Center, spacing = 8},
		eyebrow,
		title,
		description,
	)

	rows: [5]int
	row_count := (len(PUZZLES) + PUZZLE_COLUMNS - 1) / PUZZLE_COLUMNS
	for row in 0 ..< row_count {
		cards: [PUZZLE_COLUMNS]int
		card_count := min(PUZZLE_COLUMNS, len(PUZZLES) - row * PUZZLE_COLUMNS)
		for column in 0 ..< card_count {
			index := row * PUZZLE_COLUMNS + column
			state.puzzle_nodes[index] = core.ui_add(
				t,
				core.Button {
					label = "",
					action = index,
					width = PUZZLE_CARD_W,
					height = PUZZLE_CARD_H,
					font = state.font,
					normal_color = {8, 20, 28, 255},
					hover_color = {18, 60, 68, 255},
					pressed_color = {14, 42, 48, 255},
					padding = {8, 8, 8, 8},
				},
			)
			cards[column] = state.puzzle_nodes[index]
		}
		rows[row] = core.ui_add(
			t,
			core.Container {
				direction = .Horizontal,
				alignment = .Center,
				spacing = PUZZLE_CARD_GAP,
			},
			..cards[:card_count],
		)
	}
	grid := core.ui_add(
		t,
		core.Container{direction = .Vertical, alignment = .Center, spacing = PUZZLE_CARD_GAP},
		..rows[:row_count],
	)
	back := core.ui_add(
		t,
		core.Button {
			label = "Back to Main Menu",
			action = int(Puzzle_Select_Action.Back_To_Menu),
			width = 260,
			font = state.font,
			normal_color = {28, 38, 44, 255},
			hover_color = {40, 54, 62, 255},
			pressed_color = {20, 28, 32, 255},
			padding = {12, 20, 12, 20},
		},
	)
	state.back_node = back
	panel := core.ui_add(
		t,
		core.Container {
			direction = .Vertical,
			alignment = .Center,
			spacing = 18,
			padding = {24, 30, 24, 30},
			width = 1080,
		},
		header,
		grid,
		back,
	)
	t.nodes[panel].background = core.UI_Background {
		type  = .Color,
		color = {8, 24, 34, 220},
	}
	core.set_node_border(t, panel, {color = {80, 190, 190, 255}, thickness = 2})
	design := ctx.viewport.size / ctx.viewport.scale
	root := core.ui_add(
		t,
		core.Container {
			direction = .Vertical,
			alignment = .Center,
			width = design.x,
			height = design.y,
		},
		panel,
	)
	if ctx.load_texture != nil {
		background, ok := ctx.load_texture(PUZZLE_BACKGROUND_PATH)
		if ok {
			core.set_node_background_image(t, root, background)
		} else {
			log.warnf("Failed to load puzzle selection background at %s", PUZZLE_BACKGROUND_PATH)
		}
	}
	state.ix.focus = state.puzzle_nodes[0]
	layout_puzzle_select(&state, ctx)
	return
}

layout_puzzle_select :: proc(state: ^Level_Select_State, ctx: ^Context) {
	state.viewport = ctx.viewport
	design := ctx.viewport.size / ctx.viewport.scale
	core.ui_layout(&state.tree, design, ctx.renderer.measure_text)
}

update_puzzle_select :: proc(state: ^Level_Select_State, events: []core.Event) -> core.Navigation {
	t := &state.tree
	if t.count == 0 {
		return update_puzzle_select_uninitialized(state, events)
	}
	for event in events {
		#partial switch input in event {
		case shared.Key_Input: switch input.key {
				case .Up: if state.ix.focus == state.back_node {
							state.selected = len(PUZZLES) - 1
							state.ix.focus = state.puzzle_nodes[state.selected]
						} else {
							state.selected =
								(state.selected + len(PUZZLES) - PUZZLE_COLUMNS) % len(PUZZLES)
							state.ix.focus = state.puzzle_nodes[state.selected]
						}
				case .Down: if state.selected >= len(PUZZLES) - PUZZLE_COLUMNS {
							state.ix.focus = state.back_node
						} else {
							state.selected = (state.selected + PUZZLE_COLUMNS) % len(PUZZLES)
							state.ix.focus = state.puzzle_nodes[state.selected]
						}
				case .Confirm: if button, ok := t.nodes[state.ix.focus].kind.(core.Button); ok {
							return puzzle_select_navigate(button.action)
						}
				case .Back: return core.Go_Main_Menu{}
				}

		case shared.Mouse_Input:
			position := input.position / state.viewport.scale
			hit, over := core.ui_button_at(t, position)
			if over {
				state.ix.hover = hit
				if button, ok := t.nodes[hit].kind.(core.Button); ok && button.action >= 0 {
					state.selected = button.action
					state.ix.focus = hit
				}
			} else {
				state.ix.hover = nil
			}
			if input.pressed && over {
				state.ix.pressed = hit
				state.ix.focus = hit
			}
			if input.released {
				if pressed, ok := state.ix.pressed.?; ok {
					state.ix.pressed = nil
					if over && hit == pressed {
						if button, is_button := t.nodes[hit].kind.(core.Button); is_button {
							return puzzle_select_navigate(button.action)
						}
					}
				}
			}
		}
	}
	return nil
}

update_puzzle_select_uninitialized :: proc(
	state: ^Level_Select_State,
	events: []core.Event,
) -> core.Navigation {
	for event in events {
		#partial switch input in event {
		case shared.Key_Input: switch input.key {
				case .Up:
					state.selected =
							(state.selected + len(PUZZLES) - PUZZLE_COLUMNS) % len(PUZZLES)
				case .Down: state.selected = (state.selected + PUZZLE_COLUMNS) % len(PUZZLES)
				case .Confirm: return core.Go_Gameplay{puzzle_index = state.selected}
				case .Back: return core.Go_Main_Menu{}
				}
		case shared.Mouse_Input:
			position := input.position / state.viewport.scale
			hit := puzzle_card_at(position)
			if hit >= 0 && input.pressed { state.pressed = hit }
			if input.released {
				if pressed, ok := state.pressed.?; ok {
					state.pressed = nil
					if hit == pressed { return core.Go_Gameplay{puzzle_index = pressed} }
				}
			}
		}
	}
	return nil
}

puzzle_card_rect :: proc(index: int) -> shared.Rect {
	return {
		210 + f32(index % PUZZLE_COLUMNS) * (PUZZLE_CARD_W + PUZZLE_CARD_GAP),
		300 + f32(index / PUZZLE_COLUMNS) * (PUZZLE_CARD_H + PUZZLE_CARD_GAP),
		PUZZLE_CARD_W,
		PUZZLE_CARD_H,
	}
}

puzzle_card_at :: proc(position: shared.Vec2) -> int {
	for index in 0 ..< len(PUZZLES) {
		if shared.contains_point(puzzle_card_rect(index), position) { return index }
	}
	return -1
}

puzzle_select_navigate :: proc(action: int) -> core.Navigation {
	if action == int(Puzzle_Select_Action.Back_To_Menu) {
		return core.Go_Main_Menu{}
	}
	if action >= 0 && action < len(PUZZLES) {
		return core.Go_Gameplay{puzzle_index = action}
	}
	return nil
}

puzzle_stars :: proc(rating: int) -> string {
	switch rating {
	case 1: return "★☆☆"
	case 2: return "★★☆"
	case 3: return "★★★"
	}
	return "☆☆☆"
}

draw_puzzle_select :: proc(state: ^Level_Select_State, ctx: Context) {
	scale := ctx.viewport.scale
	core.ui_draw(&state.tree, state.ix, ctx.renderer, scale)
	for index in 0 ..< len(PUZZLES) {
		rect := state.tree.nodes[state.puzzle_nodes[index]].rect
		ctx.renderer.draw_text(
			PUZZLES[index].title,
			{(rect.x + 8) * scale, (rect.y + 8) * scale},
			i32(15 * scale),
			{100, 220, 190, 255},
			state.font,
		)
		ctx.renderer.draw_text(
			"GOAL:",
			{(rect.x + 8) * scale, (rect.y + 34) * scale},
			i32(13 * scale),
			{230, 235, 240, 255},
			state.font,
		)
		ctx.renderer.draw_text(
			PUZZLES[index].goal,
			{(rect.x + 54) * scale, (rect.y + 34) * scale},
			i32(13 * scale),
			{230, 235, 240, 255},
			state.font,
		)
		ctx.renderer.draw_text(
			puzzle_stars(PUZZLES[index].rating),
			{(rect.x + rect.w - 48) * scale, (rect.y + 52) * scale},
			i32(13 * scale),
			{100, 220, 190, 255},
			state.font,
		)
	}
}
