package features

import "../core"
import "../shared"
import "core:testing"

@(private = "file")
drawn_text: [16]string

@(private = "file")
drawn_text_count: int

capture_gameplay_text :: proc(
	text: string,
	_: shared.Vec2,
	_: i32,
	_: shared.Color,
	_: shared.Font_Id,
) {
	drawn_text[drawn_text_count] = text
	drawn_text_count += 1
}

has_drawn_text :: proc(want: string) -> bool {
	for text in drawn_text[:drawn_text_count] {
		if text == want { return true }
	}
	return false
}

@(test)
given_a_puzzle_is_selected_when_gameplay_opens_then_goal_transforms_and_empty_history_are_visible :: proc(
	t: ^testing.T,
) {
	// Given: the player confirms the available puzzle.
	selection := Level_Select_State {
		viewport = shared.viewport_of(1440, 900),
	}
	navigation := update_puzzle_select(&selection, {shared.Key_Input{.Confirm}})
	_, opens_gameplay := navigation.(core.Go_Gameplay)
	testing.expect(t, opens_gameplay, "confirming the puzzle should open gameplay")
	ctx := Context {
		viewport = shared.viewport_of(1440, 900),
		renderer = {draw_text = capture_gameplay_text},
	}
	drawn_text_count = 0
	screen := enter(navigation, &ctx)

	// When: the gameplay screen draws for the first time.
	draw_screen(&screen, ctx)

	// Then: the goal and permitted transformations appear, with no proof steps yet.
	testing.expect(t, has_drawn_text("GOAL"))
	testing.expect(t, has_drawn_text(FIRST_PUZZLE.goal))
	testing.expect(t, has_drawn_text("AVAILABLE TRANSFORMS"))
	puzzle := FIRST_PUZZLE
	for index in 0 ..< puzzle.transform_count {
		testing.expect(t, has_drawn_text(puzzle.available_transforms[index]))
	}
	testing.expect(t, has_drawn_text("PROOF HISTORY"))
	testing.expect(t, has_drawn_text("No steps yet"))
	gameplay, ok := screen.(Gameplay_State)
	testing.expect(t, ok)
	if ok { testing.expect_value(t, gameplay.history_count, 0) }
}
