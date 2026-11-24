package algebra

import "core:testing"

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
