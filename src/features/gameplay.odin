package features

import "../core"
import "../shared"

// Gameplay_State owns the current proof history for the active puzzle.
Gameplay_State :: struct {
	puzzle:        Puzzle,
	history:       [16]string,
	history_count: int,
}

// Puzzle contains the goal and transformations permitted for one proof task.
Puzzle :: struct {
	title:                string,
	goal:                 string,
	rating:               int, // 1..3 stars
	available_transforms: [2]string,
	transform_count:      int,
}

PUZZLES: [20]Puzzle = {
	{
		title = "ADDITIVE IDENTITY",
		goal = "x + 0 = x",
		rating = 3,
		available_transforms = {"Additive identity", "Reflexivity"},
		transform_count = 2,
	},
	{
		title = "MULTIPLICATIVE IDENTITY",
		goal = "x * 1 = x",
		rating = 1,
		available_transforms = {"Multiplicative identity", ""},
		transform_count = 1,
	},
	{
		title = "DISTRIBUTIVE PROPERTY",
		goal = "A(B + C) = AB + AC",
		rating = 1,
		available_transforms = {"Distributivity", ""},
		transform_count = 1,
	},
	{
		title = "COMMUTATIVE (ADD)",
		goal = "A + B = B + A",
		rating = 3,
		available_transforms = {"Commutativity", ""},
		transform_count = 1,
	},
	{
		title = "POWER OF IDENTITY",
		goal = "1^x = 1",
		rating = 2,
		available_transforms = {"Exponent identity", ""},
		transform_count = 1,
	},
	{
		title = "ZERO POWER",
		goal = "x^0 = 1",
		rating = 1,
		available_transforms = {"Zero exponent", ""},
		transform_count = 1,
	},
	{
		title = "LOG OF BASE",
		goal = "log_a(a) = 1",
		rating = 3,
		available_transforms = {"Logarithm identity", ""},
		transform_count = 1,
	},
	{
		title = "NEGATIVE POWER",
		goal = "x^-1 = 1/x",
		rating = 1,
		available_transforms = {"Negative exponent", ""},
		transform_count = 1,
	},
	{
		title = "DOUBLE NEGATION",
		goal = "-(-x) = x",
		rating = 1,
		available_transforms = {"Double negation", ""},
		transform_count = 1,
	},
	{
		title = "IMPLICATION RULE",
		goal = "A -> B = !A or B",
		rating = 1,
		available_transforms = {"Implication", ""},
		transform_count = 1,
	},
	{
		title = "DE MORGAN'S LAW",
		goal = "!(A and B) = !A or !B",
		rating = 1,
		available_transforms = {"De Morgan", ""},
		transform_count = 1,
	},
	{
		title = "NEGATIVE NEGATION",
		goal = "-x - (-x) = 0",
		rating = 1,
		available_transforms = {"Additive inverse", ""},
		transform_count = 1,
	},
	{
		title = "IMPLICATION RULE",
		goal = "A(B + C) = AB + AC",
		rating = 1,
		available_transforms = {"Distributivity", ""},
		transform_count = 1,
	},
	{
		title = "IMPLICATION RULE",
		goal = "A(B + C) = AB + AC",
		rating = 1,
		available_transforms = {"Distributivity", ""},
		transform_count = 1,
	},
	{
		title = "DE MORGAN'S LAW",
		goal = "A + B = B + A",
		rating = 1,
		available_transforms = {"Commutativity", ""},
		transform_count = 1,
	},
	{
		title = "DE MORGAN'S LAW",
		goal = "A + B = B + A",
		rating = 1,
		available_transforms = {"Commutativity", ""},
		transform_count = 1,
	},
	{
		title = "DE MORGAN'S LAW",
		goal = "2^0 = 1",
		rating = 1,
		available_transforms = {"Zero exponent", ""},
		transform_count = 1,
	},
	{
		title = "DE MORGAN'S LAW",
		goal = "x^2 = 1",
		rating = 1,
		available_transforms = {"Exponent rules", ""},
		transform_count = 1,
	},
	{
		title = "LOG OF BASE",
		goal = "log_a(a) = 1",
		rating = 3,
		available_transforms = {"Logarithm identity", ""},
		transform_count = 1,
	},
	{
		title = "NEGATIVE POWER",
		goal = "x^-1 = 1/x",
		rating = 1,
		available_transforms = {"Negative exponent", ""},
		transform_count = 1,
	},
}

FIRST_PUZZLE: Puzzle = PUZZLES[0]

init_gameplay :: proc(puzzle: Puzzle) -> Gameplay_State {
	return {puzzle = puzzle}
}

update_gameplay :: proc(events: []core.Event) -> core.Navigation {
	for event in events {
		if key, ok := event.(shared.Key_Input); ok && key.key == .Back {
			return core.Go_Level_Select{difficulty = .Normal}
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
