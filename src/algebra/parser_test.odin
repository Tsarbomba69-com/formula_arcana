package algebra

import "core:testing"

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
