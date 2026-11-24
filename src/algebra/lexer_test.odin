package algebra

import "core:testing"

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
