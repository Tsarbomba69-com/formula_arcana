package algebra

import "core:testing"

@(test)
given_the_start_formula_when_listing_moves_then_only_distribute_3_is_offered :: proc(
	t: ^testing.T,
) {
	eq := parse_ok(t, START)
	moves := valid_moves(eq)

	testing.expect_value(t, moves.count, 1)
	testing.expect_value(t, moves.items[0].kind, Move_Kind.Distribute)
	expect_label(t, title_of(eq, moves.items[0]), "Distributive property")
}

@(test)
given_a_distributive_move_when_described_then_its_title_names_the_general_transformation :: proc(
	t: ^testing.T,
) {
	eq := parse_ok(t, START)
	moves := valid_moves(eq)
	expect_label(t, describe_move(eq, moves.items[0]).title, "Distributive property")
}

@(test)
given_expression_tokens_when_each_term_is_selected_then_all_valid_moves_for_that_term_are_listed :: proc(
	t: ^testing.T,
) {
	eq := parse_ok(t, START)
	tokens := tokenize(eq)
	distributable_term := tokens.items[0].term

	for i in 0 ..< tokens.count {
		term := tokens.items[i].term
		if term == NO_EXPR { continue }

		already_checked := false
		for previous in 0 ..< i {
			if tokens.items[previous].term == term {
				already_checked = true
				break
			}
		}
		if already_checked { continue }

		moves := valid_moves(eq, term)
		if term == distributable_term {
			testing.expect_value(t, moves.count, 1)
			testing.expect_value(t, moves.items[0].kind, Move_Kind.Distribute)
		} else {
			testing.expect_value(t, moves.count, 0)
		}
	}
}

@(test)
given_a_distributed_formula_when_listing_moves_then_only_combine_constants_is_offered :: proc(
	t: ^testing.T,
) {
	eq := parse_ok(t, DISTRIBUTED)
	moves := valid_moves(eq)

	testing.expect_value(t, moves.count, 1)
	testing.expect_value(t, moves.items[0].kind, Move_Kind.Combine_Constants)
	expect_label(t, title_of(eq, moves.items[0]), "Combine constants")
}

@(test)
given_the_reference_formula_when_listing_moves_then_three_balance_moves_appear_in_design_order :: proc(
	t: ^testing.T,
) {
	eq := parse_ok(t, REFERENCE)
	moves := valid_moves(eq)

	testing.expect_value(t, moves.count, 3)
	titles := [?]string{"Subtract 2x", "Add 4", "Subtract 17"}
	for i in 0 ..< min(moves.count, len(titles)) {
		expect_label(t, title_of(eq, moves.items[i]), titles[i])
	}
	// "Subtract 3x" is NOT offered: it would leave a negative variable coefficient.
}

@(test)
given_the_reference_formula_when_describing_moves_then_cards_show_preview_and_hint :: proc(
	t: ^testing.T,
) {
	eq := parse_ok(t, REFERENCE)
	moves := valid_moves(eq)

	previews := [?]string {
		"3x − 4 − 2x = 2x + 17 − 2x",
		"3x − 4 + 4 = 2x + 17 + 4",
		"3x − 4 − 17 = 2x + 17 − 17",
	}
	hints := [?]string {
		"Cancel the variable on the right.",
		"Remove the constant on the left.",
		"Move the right-hand constant.",
	}
	for i in 0 ..< min(moves.count, len(previews)) {
		view := describe_move(eq, moves.items[i])
		expect_label(t, view.preview, previews[i])
		expect_label(t, view.hint, hints[i])
	}
}

@(test)
given_a_move_when_described_then_heading_is_uppercase_but_the_variable_stays_lowercase :: proc(
	t: ^testing.T,
) {
	eq := parse_ok(t, REFERENCE)
	moves := valid_moves(eq)

	expect_label(t, describe_move(eq, moves.items[0]).heading, "AFTER SUBTRACTING 2x")
	expect_label(t, describe_move(eq, moves.items[1]).heading, "AFTER ADDING 4")

	start := parse_ok(t, START)
	expect_label(
		t,
		describe_move(start, valid_moves(start).items[0]).heading,
		"AFTER DISTRIBUTING 3",
	)
}

@(test)
given_variables_on_both_sides_when_the_left_coefficient_is_smaller_then_the_left_variable_is_cancelled :: proc(
	t: ^testing.T,
) {
	eq := parse_ok(t, "2x + 1 = 5x − 3")
	moves := valid_moves(eq)

	testing.expect_value(t, moves.count, 3)
	titles := [?]string{"Subtract 2x", "Subtract 1", "Add 3"}
	for i in 0 ..< min(moves.count, len(titles)) {
		expect_label(t, title_of(eq, moves.items[i]), titles[i])
	}
	expect_label(t, describe_move(eq, moves.items[0]).hint, "Cancel the variable on the left.")
}

@(test)
given_the_variable_is_only_on_the_left_when_listing_moves_then_only_left_constants_are_offered :: proc(
	t: ^testing.T,
) {
	eq := parse_ok(t, "x − 4 = 17")
	moves := valid_moves(eq)

	testing.expect_value(t, moves.count, 1)
	expect_label(t, title_of(eq, moves.items[0]), "Add 4")
}

@(test)
given_a_solved_formula_when_listing_moves_then_nothing_is_offered :: proc(t: ^testing.T) {
	moves := valid_moves(parse_ok(t, "x = 21"))
	testing.expect_value(t, moves.count, 0)
}

// ---- term selection narrows the list ---------------------------------------

@(test)
given_a_constant_term_is_selected_when_listing_moves_then_only_moves_on_that_term_remain :: proc(
	t: ^testing.T,
) {
	eq := parse_ok(t, REFERENCE)
	tokens := tokenize(eq)

	moves := valid_moves(eq, tokens.items[3].term) // the "4" of −4

	testing.expect_value(t, moves.count, 1)
	expect_label(t, title_of(eq, moves.items[0]), "Add 4")
}

@(test)
given_the_right_variable_term_is_selected_when_listing_moves_then_subtract_2x_remains :: proc(
	t: ^testing.T,
) {
	eq := parse_ok(t, REFERENCE)
	tokens := tokenize(eq)

	moves := valid_moves(eq, tokens.items[5].term) // the "2x"

	testing.expect_value(t, moves.count, 1)
	expect_label(t, title_of(eq, moves.items[0]), "Subtract 2x")
}

@(test)
given_a_term_with_no_valid_move_is_selected_when_listing_moves_then_the_list_is_empty :: proc(
	t: ^testing.T,
) {
	eq := parse_ok(t, REFERENCE)
	tokens := tokenize(eq)

	moves := valid_moves(eq, tokens.items[0].term) // the "3x"

	testing.expect_value(t, moves.count, 0)
}

// ============================================================================
// Feature: applying a move
// ============================================================================

@(test)
given_the_start_formula_when_the_implicit_multiply_or_paren_is_selected_then_distribute_is_offered :: proc(
	t: ^testing.T,
) {
	eq := parse_ok(t, START) // 3(x − 4) + 8 = 2x + 17

	// Selecting "(" at index 1 targets the grouped product 3(x − 4)
	moves := valid_moves(eq, 1)

	testing.expect_value(t, moves.count, 1)
	testing.expect_value(t, moves.items[0].kind, Move_Kind.Distribute)
}

@(test)
given_a_distributed_formula_when_the_plus_between_constants_is_selected_then_combine_constants_is_offered :: proc(
	t: ^testing.T,
) {
	eq := parse_ok(t, DISTRIBUTED) // 3x − 12 + 8 = 2x + 17
	tokens := tokenize(eq)

	// Tokens: 0:"3", 1:"x", 2:"−", 3:"12", 4:"+", 5:"8", ...
	plus_idx := 4
	expect_label(t, tokens.items[plus_idx].text, "+")

	moves := valid_moves(eq, plus_idx)

	testing.expect_value(t, moves.count, 2)
	testing.expect_value(t, moves.items[0].kind, Move_Kind.Combine_Constants)
	testing.expect_value(t, moves.items[1].kind, Move_Kind.Commute)
}

@(test)
given_an_equation_when_the_equals_sign_is_selected_then_no_local_operation_move_is_offered :: proc(
	t: ^testing.T,
) {
	eq := parse_ok(t, REFERENCE) // 3x − 4 = 2x + 17
	tokens := tokenize(eq)

	// Token 4 is "="
	expect_label(t, tokens.items[4].text, "=")
	moves := valid_moves(eq, 4)

	testing.expect_value(t, moves.count, 0)
}

// ============================================================================
// Feature: player-chosen transformations are allowed independently of recommendations
// ============================================================================

// ALL_KINDS :: Move_Kinds{.Add_To_Both, .Subtract_From_Both, .Multiply_Both, .Divide_Both, .Apply_Function}

// @(test)
// given_a_valid_equation_when_inspecting_then_every_transformation_kind_is_applicable :: proc(
// 	t: ^testing.T,
// ) {
// 	eq := parse_ok(t, "x = 3")
// 	testing.expect_value(t, applicable_kinds(eq), ALL_KINDS)
// }

// @(test)
// given_no_equation_when_inspecting_then_no_transformation_kind_is_applicable :: proc(
// 	t: ^testing.T,
// ) {
// 	testing.expect_value(t, applicable_kinds(Equation{}), Move_Kinds{})
// }

// @(test)
// given_a_solved_looking_equation_when_the_recommender_offers_nothing_then_transformations_are_still_applicable :: proc(
// 	t: ^testing.T,
// ) {
// 	eq := parse_ok(t, "x = 3")

// 	// The recommender has no advice here, yet the player's request is still legal.
// 	testing.expect_value(t, valid_moves(eq).count, 0)
// 	testing.expect_value(t, check_transformation(eq, add_to_both(5)), Move_Error.None)
// 	expect_transformed(t, "x = 3", add_to_both(5), "x + 5 = 8", .Equivalent)
// }

// @(test)
// given_a_zero_divisor_when_checked_then_division_by_zero_is_reported :: proc(t: ^testing.T) {
// 	eq := parse_ok(t, "2x + 4 = 10")
// 	testing.expect_value(t, check_transformation(eq, divide_both(0)), Move_Error.Division_By_Zero)
// 	testing.expect_value(t, check_transformation(eq, divide_both(2)), Move_Error.None)
// }

// @(test)
// given_a_zero_multiplier_when_checked_then_it_is_still_available :: proc(t: ^testing.T) {
// 	eq := parse_ok(t, "x = 3")
// 	testing.expect_value(t, check_transformation(eq, multiply_both(0)), Move_Error.None)
// }
