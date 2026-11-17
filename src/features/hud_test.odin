package features

import "core:testing"

@(private = "file")
reference_run :: proc() -> Run_Info {
	return {
		mode = "ARCANE TRIALS",
		tier = .Easy,
		round = 7,
		rounds_total = 10,
		score = 4280,
		streak = 6,
	}
}

@(test)
given_the_reference_run_when_formatted_then_the_top_bar_texts_match_the_design :: proc(
	t: ^testing.T,
) {
	run := reference_run()
	buf: [64]u8

	testing.expect_value(t, format_mode_tag(run, buf[:]), "ARCANE TRIALS / Easy")
	testing.expect_value(t, format_round(run, buf[:]), "ROUND 07 / 10")
	testing.expect_value(t, format_progress(run, buf[:]), "70%")
	testing.expect_value(t, format_score(run.score, buf[:]), "04,280")
	testing.expect_value(t, format_streak(run.streak, buf[:]), "× 6")
}

@(test)
given_a_round_count_when_asked_for_progress_then_it_is_a_clamped_fraction :: proc(t: ^testing.T) {
	testing.expect_value(t, progress_fraction({round = 7, rounds_total = 10}), f32(0.7))
	testing.expect_value(t, progress_fraction({round = 12, rounds_total = 10}), f32(1))
	testing.expect_value(t, progress_fraction({round = 3, rounds_total = 0}), f32(0))
}

@(test)
given_scores_when_formatted_then_they_are_zero_padded_to_five_digits_with_a_separator :: proc(
	t: ^testing.T,
) {
	buf: [32]u8
	testing.expect_value(t, format_score(0, buf[:]), "00,000")
	testing.expect_value(t, format_score(4280, buf[:]), "04,280")
	testing.expect_value(t, format_score(123456, buf[:]), "123,456")
}

@(test)
given_elapsed_seconds_when_formatted_then_they_show_minutes_and_whole_seconds :: proc(
	t: ^testing.T,
) {
	buf: [16]u8
	testing.expect_value(t, format_time(0, buf[:]), "00:00")
	testing.expect_value(t, format_time(24.9, buf[:]), "00:24")
	testing.expect_value(t, format_time(61, buf[:]), "01:01")
	testing.expect_value(t, format_time(99 * 60 + 59 + 0.9, buf[:]), "99:59")
	testing.expect_value(t, format_time(10_000, buf[:]), "99:59") // clamped
}

@(test)
given_a_step_number_when_formatted_then_it_is_zero_padded :: proc(t: ^testing.T) {
	buf: [16]u8
	testing.expect_value(t, format_step(2, buf[:]), "STEP 02")
	testing.expect_value(t, format_step(0, buf[:]), "STEP 00")
	testing.expect_value(t, format_index(1, buf[:]), "01")
}

@(test)
given_move_counts_when_formatted_then_singular_and_plural_are_correct :: proc(t: ^testing.T) {
	buf: [64]u8
	testing.expect_value(t, format_move_count(2, buf[:]), "2 MOVES")
	testing.expect_value(t, format_move_count(1, buf[:]), "1 MOVE")
	testing.expect_value(t, format_move_count(0, buf[:]), "0 MOVES")
	testing.expect_value(
		t,
		format_valid_moves(3, false, buf[:]),
		"3 valid moves · whole equation",
	)
	testing.expect_value(t, format_valid_moves(1, true, buf[:]), "1 valid move · selected term")
	testing.expect_value(t, format_valid_moves(0, true, buf[:]), "0 valid moves · selected term")
}
