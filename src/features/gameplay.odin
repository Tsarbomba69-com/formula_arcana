package features

import "../core"
import "../shared"

// Puzzle contains the goal and transformations permitted for one proof task.
Puzzle :: struct {
	title:                string,
	goal:                 string,
	available_transforms: [4]string,
	transform_count:      int,
}

// Gameplay_State owns the current proof history for the active puzzle.
Gameplay_State :: struct {
	puzzle:        Puzzle,
	history:       [16]string,
	history_count: int,
}

FIRST_PUZZLE :: Puzzle {
	title = "Additive Identity",
	goal = "x + 0 = x",
	available_transforms = {"Additive identity", "Reflexivity", "", ""},
	transform_count = 2,
}

init_gameplay :: proc(puzzle: Puzzle) -> Gameplay_State {
	return {puzzle = puzzle}
}

update_gameplay :: proc(events: []core.Event) -> core.Navigation {
	for event in events {
		if key, ok := event.(shared.Key_Input); ok && key.key == .Back {
			return core.Go_Level_Select{difficulty = .Standard}
		}
	}
	return nil
}

draw_gameplay :: proc(state: Gameplay_State, ctx: Context) {
	scale := ctx.viewport.scale
	color := shared.Color{230, 235, 240, 255}
	y := f32(72)
	draw := ctx.renderer.draw_text
	draw("PROOF WORKSPACE", {72 * scale, y * scale}, i32(32 * scale), color)
	y += 58
	draw(state.puzzle.title, {72 * scale, y * scale}, i32(24 * scale), {100, 220, 190, 255})
	y += 54
	draw("GOAL", {72 * scale, y * scale}, i32(18 * scale), {145, 165, 180, 255})
	y += 34
	draw(state.puzzle.goal, {72 * scale, y * scale}, i32(30 * scale), color)
	y += 78
	draw("AVAILABLE TRANSFORMS", {72 * scale, y * scale}, i32(18 * scale), {145, 165, 180, 255})
	y += 34
	for index in 0 ..< state.puzzle.transform_count {
		transform := state.puzzle.available_transforms[index]
		draw(transform, {92 * scale, y * scale}, i32(20 * scale), color)
		y += 32
	}
	y += 28
	draw("PROOF HISTORY", {72 * scale, y * scale}, i32(18 * scale), {145, 165, 180, 255})
	y += 34
	if state.history_count == 0 {
		draw("No steps yet", {92 * scale, y * scale}, i32(20 * scale), color)
	} else {
		for index in 0 ..< state.history_count {
			step := state.history[index]
			draw(step, {92 * scale, y * scale}, i32(20 * scale), color)
			y += 32
		}
	}
	draw("Esc: puzzle select", {72 * scale, 850 * scale}, i32(16 * scale), {145, 165, 180, 255})
}
