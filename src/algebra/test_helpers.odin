package algebra

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

@(private = "package")
parse_ok :: proc(t: ^testing.T, src: string, loc := #caller_location) -> Equation {
	eq, err := parse_equation(src)
	testing.expectf(t, err == .None, "parsing %q failed with %v", src, err, loc = loc)
	return eq
}

@(private = "package")
expect_equation :: proc(t: ^testing.T, eq: Equation, want: string, loc := #caller_location) {
	buf: [LABEL_CAP * 2]u8
	testing.expect_value(t, format_equation(eq, buf[:]), want, loc)
}

@(private = "package")
expect_label :: proc(t: ^testing.T, label: Label, want: string, loc := #caller_location) {
	label := label
	testing.expect_value(t, label_str(&label), want, loc)
}

@(private = "package")
title_of :: proc(eq: Equation, m: Move) -> Label {
	return describe_move(eq, m).title
}

@(private = "package")
apply_pick :: proc(t: ^testing.T, src: string, pick: int, loc := #caller_location) -> Equation {
	eq := parse_ok(t, src, loc)
	moves := valid_moves(eq)
	testing.expectf(t, pick < moves.count, "%q should offer move #%d", src, pick, loc = loc)
	out, ok := apply_move(eq, moves.items[pick])
	testing.expectf(t, ok, "applying move #%d to %q should succeed", pick, src, loc = loc)
	return out
}

expect_equation_result :: proc(t: ^testing.T, result: Equation, want: string) {
	buf: [LABEL_CAP * 2]u8
	testing.expect_value(t, format_equation(result, buf[:]), want)
}

expect_move_error :: proc(t: ^testing.T, err: Move_Error, want: Move_Error) {
	testing.expect_value(t, err, want)
}


// Encodes a positive integer literal in a value outside the Expr_Id node range.
// These add/subtract tests need only scalar operands, not a separate expression tree.
expression_from_text :: proc(t: ^testing.T, src: string) -> Expr_Id {
	buf: [128]u8
	copy(buf[:len(src)], src)
	suffix := " = 0"
	copy(buf[len(src):len(src) + len(suffix)], suffix)
	eq, err := parse_equation(string(buf[:len(src) + len(suffix)]))
	if err != .None {
		testing.expect_value(t, err, Parse_Error.None)
		return Expr_Id(-1)
	}
	if value, ok := eq.nodes[eq.lhs].(Num); ok && value.value > 0 {
		return Expr_Id(-value.value - 2)
	}
	testing.expect(t, false, "expected a positive integer literal")
	return Expr_Id(-1)
}
