package algebra

import "core:testing"

// ============================================================================
// Feature: completion rule ("One variable. One value. No extra terms.")
// ============================================================================

@(test)
given_the_start_formula_when_distribute_is_applied_then_brackets_expand_without_combining :: proc(
	t: ^testing.T,
) {
	expect_equation(t, apply_pick(t, START, 0), DISTRIBUTED)
}

@(test)
given_a_distributed_formula_when_combine_constants_is_applied_then_constants_merge :: proc(
	t: ^testing.T,
) {
	expect_equation(t, apply_pick(t, DISTRIBUTED, 0), REFERENCE)
}

@(test)
given_the_reference_formula_when_subtract_2x_is_applied_then_the_result_is_simplified :: proc(
	t: ^testing.T,
) {
	expect_equation(t, apply_pick(t, REFERENCE, 0), "x − 4 = 17")
}

@(test)
given_the_reference_formula_when_add_4_is_applied_then_the_left_constant_disappears :: proc(
	t: ^testing.T,
) {
	expect_equation(t, apply_pick(t, REFERENCE, 1), "3x = 2x + 21")
}

@(test)
given_the_reference_formula_when_subtract_17_is_applied_then_the_right_constant_disappears :: proc(
	t: ^testing.T,
) {
	expect_equation(t, apply_pick(t, REFERENCE, 2), "3x − 21 = 2x")
}

@(test)
given_x_minus_4_equals_17_when_add_4_is_applied_then_x_equals_21 :: proc(t: ^testing.T) {
	expect_equation(t, apply_pick(t, "x − 4 = 17", 0), "x = 21")
}

@(test)
given_a_move_from_another_formula_when_applied_then_it_is_rejected_and_nothing_changes :: proc(
	t: ^testing.T,
) {
	distribute := valid_moves(parse_ok(t, START)).items[0]
	other := parse_ok(t, "x − 4 = 17")

	result, ok := apply_move(other, distribute)

	testing.expect(t, !ok, "a stale move must not apply")
	expect_equation(t, result, "x − 4 = 17")
}

// ---- history notes -------------------------------------------------------------

@(test)
given_a_distribute_move_when_explained_then_it_says_what_it_became :: proc(t: ^testing.T) {
	eq := parse_ok(t, START)
	expect_label(t, explain_move(eq, valid_moves(eq).items[0]), "3(x − 4) becomes 3x − 12.")
}

@(test)
given_a_combine_move_when_explained_then_it_says_what_it_became :: proc(t: ^testing.T) {
	eq := parse_ok(t, DISTRIBUTED)
	expect_label(t, explain_move(eq, valid_moves(eq).items[0]), "−12 + 8 becomes −4.")
}

// ============================================================================
// Feature: performing player-chosen transformations
// ============================================================================

@(private = "file")
expect_transformed :: proc(
	t: ^testing.T,
	start: string,
	op: Transformation,
	want: string,
	want_equivalence: Equivalence,
	loc := #caller_location,
) {
	result := apply_transformation(parse_ok(t, start), op)
	testing.expect_value(t, result.error, Move_Error.None, loc)
	expect_equation(t, result.equation, want)
	testing.expect_value(t, result.equivalence, want_equivalence, loc)
}

// @(test)
// given_each_transformation_when_titled_then_the_title_names_the_operation :: proc(t: ^testing.T) {
// 	expect_label(t, transformation_title(add_to_both(5)), "Add 5 to both sides")
// 	expect_label(t, transformation_title(subtract_from_both(4)), "Subtract 4 from both sides")
// 	expect_label(t, transformation_title(multiply_both(0)), "Multiply both sides by 0")
// 	expect_label(t, transformation_title(divide_both(2)), "Divide both sides by 2")
// 	expect_label(t, transformation_title(apply_function(.Square)), "Square both sides")
// }

// @(test)
// given_x_equals_3_when_adding_5_to_both_sides_then_it_becomes_x_plus_5_equals_8 :: proc(
// 	t: ^testing.T,
// ) {
// 	expect_transformed(t, "x = 3", add_to_both(5), "x + 5 = 8", .Equivalent)
// }

// @(test)
// given_2x_plus_4_equals_10_when_subtracting_4_from_both_sides_then_it_becomes_2x_equals_6 :: proc(
// 	t: ^testing.T,
// ) {
// 	expect_transformed(t, "2x + 4 = 10", subtract_from_both(4), "2x = 6", .Equivalent)
// }

// @(test)
// given_x_equals_3_when_adding_5_then_both_the_left_and_the_right_side_change :: proc(
// 	t: ^testing.T,
// ) {
// 	result := apply_transformation(parse_ok(t, "x = 3"), add_to_both(5))
// 	buf: [LABEL_CAP * 2]u8

// 	testing.expect_value(t, format_side(result.equation, .Left, buf[:]), "x + 5")
// 	testing.expect_value(t, format_side(result.equation, .Right, buf[:]), "8")
// }

// @(test)
// given_2x_plus_4_equals_10_when_dividing_both_sides_by_2_then_every_term_is_divided :: proc(
// 	t: ^testing.T,
// ) {
// 	expect_transformed(t, "2x + 4 = 10", divide_both(2), "x + 2 = 5", .Equivalent)
// }

// @(test)
// given_2x_plus_4_equals_10_when_multiplying_both_sides_by_3_then_every_term_is_multiplied :: proc(
// 	t: ^testing.T,
// ) {
// 	expect_transformed(t, "2x + 4 = 10", multiply_both(3), "6x + 12 = 30", .Equivalent)
// }

// @(test)
// given_2x_plus_4_equals_10_when_dividing_by_zero_then_the_request_is_unavailable_and_the_equation_is_unchanged :: proc(
// 	t: ^testing.T,
// ) {
// 	eq := parse_ok(t, "2x + 4 = 10")

// 	testing.expect_value(t, check_transformation(eq, divide_both(0)), Move_Error.Division_By_Zero)

// 	result := apply_transformation(eq, divide_both(0))
// 	testing.expect_value(t, result.error, Move_Error.Division_By_Zero)
// 	expect_equation(t, result.equation, "2x + 4 = 10")
// }

// @(test)
// given_division_by_zero_when_the_player_is_told_then_the_message_says_it_is_undefined :: proc(
// 	t: ^testing.T,
// ) {
// 	testing.expect_value(
// 		t,
// 		move_error_message(.Division_By_Zero),
// 		"Division by zero is undefined.",
// 	)
// }

// @(test)
// given_x_equals_3_when_multiplying_both_sides_by_zero_then_it_is_allowed_but_not_equivalent :: proc(
// 	t: ^testing.T,
// ) {
// 	eq := parse_ok(t, "x = 3")

// 	testing.expect_value(t, check_transformation(eq, multiply_both(0)), Move_Error.None)
// 	expect_transformed(t, "x = 3", multiply_both(0), "0 = 0", .Not_Equivalent)
// }

// @(test)
// given_a_non_equivalent_transformation_when_marked_then_the_player_is_warned_information_was_lost :: proc(
// 	t: ^testing.T,
// ) {
// 	testing.expect_value(t, equivalence_name(.Not_Equivalent), "not equivalent")
// 	testing.expect_value(t, equivalence_warning(.Not_Equivalent), "Information was lost.")
// 	testing.expect_value(t, equivalence_name(.Equivalent), "equivalent")
// 	testing.expect_value(t, equivalence_warning(.Equivalent), "")
// }

// @(test)
// given_x_plus_1_equals_3_when_squaring_both_sides_then_each_complete_side_is_squared_and_extra_solutions_are_flagged :: proc(
// 	t: ^testing.T,
// ) {
// 	eq := parse_ok(t, "x + 1 = 3")
// 	result := apply_transformation(eq, apply_function(.Square))
// 	buf: [LABEL_CAP * 2]u8

// 	testing.expect_value(t, result.error, Move_Error.None)
// 	expect_equation(t, result.equation, "(x + 1)^2 = 3^2")
// 	testing.expect_value(t, format_side(result.equation, .Right, buf[:]), "3^2")
// 	testing.expect_value(t, result.equivalence, Equivalence.May_Introduce_Extra_Solutions)
// 	testing.expect_value(t, equivalence_name(result.equivalence), "may introduce extra solutions")
// }

// @(test)
// given_x_plus_1_equals_3_when_squaring_both_sides_then_the_function_is_not_distributed_over_the_sum :: proc(
// 	t: ^testing.T,
// ) {
// 	result := apply_transformation(parse_ok(t, "x + 1 = 3"), apply_function(.Square))
// 	buf: [LABEL_CAP * 2]u8

// 	left := format_side(result.equation, .Left, buf[:])

// 	testing.expect_value(t, left, "(x + 1)^2")
// 	testing.expect(t, left != "x^2 + 1", "squaring must not be distributed without a rule")
// }
