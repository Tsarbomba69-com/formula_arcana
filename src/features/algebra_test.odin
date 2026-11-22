package features
// TODO: The algebra file will evolve to a full blown symbolic engine later
import "core:testing"

// The reference screen walks this exact path:
//   3(x − 4) + 8 = 2x + 17      initial
//   3x − 12 + 8 = 2x + 17       Distribute 3
//   3x − 4 = 2x + 17            Combine constants     <- screenshot state
//   x − 4 = 17                  Subtract 2x
//   x = 21                      Add 4                 <- target
START :: "3(x − 4) + 8 = 2x + 17"
DISTRIBUTED :: "3x − 12 + 8 = 2x + 17"
REFERENCE :: "3x − 4 = 2x + 17"

// ---- helpers ---------------------------------------------------------------

@(private = "file")
parse_ok :: proc(t: ^testing.T, src: string, loc := #caller_location) -> Equation {
	eq, err := parse_equation(src)
	testing.expectf(t, err == .None, "parsing %q failed with %v", src, err, loc = loc)
	return eq
}

@(private = "file")
expect_equation :: proc(t: ^testing.T, eq: Equation, want: string, loc := #caller_location) {
	buf: [LABEL_CAP * 2]u8
	testing.expect_value(t, format_equation(eq, buf[:]), want, loc)
}

@(private = "file")
expect_label :: proc(t: ^testing.T, label: Label, want: string, loc := #caller_location) {
	label := label
	testing.expect_value(t, label_str(&label), want, loc)
}

@(private = "file")
title_of :: proc(eq: Equation, m: Move) -> Label {
	return describe_move(eq, m).title
}

@(private = "file")
apply_pick :: proc(t: ^testing.T, src: string, pick: int, loc := #caller_location) -> Equation {
	eq := parse_ok(t, src, loc)
	moves := valid_moves(eq)
	testing.expectf(t, pick < moves.count, "%q should offer move #%d", src, pick, loc = loc)
	out, ok := apply_move(eq, moves.items[pick])
	testing.expectf(t, ok, "applying move #%d to %q should succeed", pick, src, loc = loc)
	return out
}

// ============================================================================
// Feature: parsing and canonical formatting
// ============================================================================

@(test)
given_an_ascii_equation_when_parsed_then_it_formats_with_canonical_spacing_and_minus :: proc(
	t: ^testing.T,
) {
	eq := parse_ok(t, "3(x-4)+8=2x+17")
	expect_equation(t, eq, START)
}

@(test)
given_unicode_minus_and_extra_spaces_when_parsed_then_it_formats_canonically :: proc(
	t: ^testing.T,
) {
	eq := parse_ok(t, "  3x  −  4 =   2x +17 ")
	expect_equation(t, eq, REFERENCE)
}

@(test)
given_a_coefficient_of_one_when_formatted_then_it_is_omitted :: proc(t: ^testing.T) {
	eq := parse_ok(t, "1x - 4 = 17")
	expect_equation(t, eq, "x − 4 = 17")
}

@(test)
given_no_equals_sign_when_parsed_then_missing_equals_is_reported :: proc(t: ^testing.T) {
	_, err := parse_equation("3x − 4")
	testing.expect_value(t, err, Parse_Error.Missing_Equals)
}

@(test)
given_unbalanced_parentheses_when_parsed_then_unbalanced_parens_is_reported :: proc(
	t: ^testing.T,
) {
	_, err := parse_equation("3(x − 4 = 17")
	testing.expect_value(t, err, Parse_Error.Unbalanced_Parens)
}

@(test)
given_an_unknown_character_when_parsed_then_unexpected_character_is_reported :: proc(
	t: ^testing.T,
) {
	_, err := parse_equation("3x # 4 = 17")
	testing.expect_value(t, err, Parse_Error.Unexpected_Character)
}

@(test)
given_empty_input_when_parsed_then_empty_is_reported :: proc(t: ^testing.T) {
	_, err := parse_equation("   ")
	testing.expect_value(t, err, Parse_Error.Empty)
}

// ============================================================================
// Feature: formula tiles (tokens)
// ============================================================================

@(test)
given_the_reference_formula_when_tokenized_then_nine_tiles_with_the_design_kinds_appear :: proc(
	t: ^testing.T,
) {
	tokens := tokenize(parse_ok(t, REFERENCE))

	want_text := [?]string{"3", "x", "−", "4", "=", "2", "x", "+", "17"}
	want_kind := [?]Token_Kind {
		.Constant,
		.Variable,
		.Operator,
		.Constant,
		.Operator,
		.Constant,
		.Variable,
		.Operator,
		.Constant,
	}
	testing.expect_value(t, tokens.count, len(want_text))
	for i in 0 ..< min(tokens.count, len(want_text)) {
		tok := tokens.items[i]
		expect_label(t, tok.text, want_text[i])
		testing.expect_value(t, tok.kind, want_kind[i])
	}
}

@(test)
given_the_start_formula_when_tokenized_then_parentheses_are_tiles_too :: proc(t: ^testing.T) {
	tokens := tokenize(parse_ok(t, START))

	want := [?]string{"3", "(", "x", "−", "4", ")", "+", "8", "=", "2", "x", "+", "17"}
	testing.expect_value(t, tokens.count, len(want))
	for i in 0 ..< min(tokens.count, len(want)) {
		expect_label(t, tokens.items[i].text, want[i])
	}
	testing.expect_value(t, tokens.items[1].kind, Token_Kind.Paren)
}

@(test)
given_tiles_of_one_term_when_tokenized_then_they_share_a_term_and_operators_have_none :: proc(
	t: ^testing.T,
) {
	tokens := tokenize(parse_ok(t, REFERENCE)) // 3 x − 4 = 2 x + 17

	testing.expect_value(t, tokens.items[0].term, tokens.items[1].term) // 3 and x are "3x"
	testing.expect(t, tokens.items[0].term != tokens.items[3].term, "3x and 4 are different terms")
	testing.expect_value(t, tokens.items[2].term, NO_EXPR) // −
	testing.expect_value(t, tokens.items[4].term, NO_EXPR) // =
	testing.expect_value(t, tokens.items[0].side, Side.Left)
	testing.expect_value(t, tokens.items[5].side, Side.Right)
}

// ============================================================================
// Feature: which moves are valid (left panel)
// ============================================================================

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
// Feature: completion rule ("One variable. One value. No extra terms.")
// ============================================================================

@(test)
given_the_target_x_equals_21_when_checking_formulas_then_only_the_isolated_value_is_solved :: proc(
	t: ^testing.T,
) {
	target := parse_ok(t, "x = 21")

	testing.expect(t, is_solved(parse_ok(t, "x = 21"), target), "x = 21 solves it")
	testing.expect(t, !is_solved(parse_ok(t, "x = 20"), target), "wrong value")
	testing.expect(t, !is_solved(parse_ok(t, "x − 4 = 17"), target), "extra term")
	testing.expect(t, !is_solved(parse_ok(t, "21 = x"), target), "variable must be on the left")
	testing.expect(t, !is_solved(parse_ok(t, START), target), "start is not solved")
}
