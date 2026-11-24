package algebra

import "core:testing"

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

// ============================================================================
// Feature: operation selection narrows or triggers structural moves
// ============================================================================
