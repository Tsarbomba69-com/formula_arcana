package features

// ============================================================================
// PHASE 1 CONTRACT — pure equation domain for the "Transformation" screen.
// No raylib, no UI, no allocation. Everything is value-typed and copy-safe
// (history == array of Equation snapshots; undo == pop).
//
// Every proc below is a STUB that returns a zero value on purpose:
// the tests in algebra_test.odin must fail (RED) until Phase 2 implements them.
// ============================================================================

MAX_NODES :: 32
MAX_TOKENS :: 24
MAX_MOVES :: 8
LABEL_CAP :: 96

EQUIVALENCE_NOTE :: "Equivalent for every x ∈ ℝ"

// ---- Expression tree (children by index, like core.UI_Tree) ---------------

Expr_Id :: distinct int
NO_EXPR :: Expr_Id(-1)

Binary_Op :: enum {
	Add,
	Sub,
	Mul, // also produced by implicit multiplication: 3x, 3(x − 4)
}

Num :: struct {
	value: i64, // integers only in Phase 1
}

Var :: struct {
	name: u8, // single letter
}

Bin :: struct {
	op:          Binary_Op,
	left, right: Expr_Id,
}

Expr_Node :: union {
	Num,
	Var,
	Bin,
}

Equation :: struct {
	nodes:    [MAX_NODES]Expr_Node,
	count:    int,
	lhs, rhs: Expr_Id,
}

Side :: enum {
	Left,
	Right,
}

// ---- Fixed-capacity text (no allocator, copy-safe) --------------------------

Label :: struct {
	data: [LABEL_CAP]u8,
	len:  int,
}

label_set :: proc(l: ^Label, s: string) {
	l.len = min(len(s), LABEL_CAP)
	copy(l.data[:l.len], s[:l.len])
}

label_str :: proc(l: ^Label) -> string {
	return string(l.data[:l.len])
}

// ---- Parsing & formatting ----------------------------------------------------
// Accepted input: ASCII '-' or '−' (U+2212), optional spaces, implicit
// multiplication ("3x", "3(x-4)"). Canonical output (format_equation):
//   * spaces around + − =           "3x − 4 = 2x + 17"
//   * no space for coefficients     "3x", "2x"
//   * tight parentheses             "3(x − 4)"
//   * coefficient 1 is omitted      "x"
//   * the minus is U+2212           "−"

Parse_Error :: enum {
	None,
	Empty,
	Missing_Equals,
	Unbalanced_Parens,
	Unexpected_Character,
	Too_Many_Nodes,
}

parse_equation :: proc(src: string) -> (eq: Equation, err: Parse_Error) {
	return {}, .Empty // STUB
}

// Result aliases `buf`; the caller owns the buffer.
format_equation :: proc(eq: Equation, buf: []u8) -> string {
	return "" // STUB
}

// ---- Tokens: what the formula panel draws as tiles --------------------------
// "3x − 4 = 2x + 17" → 3 x − 4 = 2 x + 17  (9 tiles, exactly as in the design)

Token_Kind :: enum {
	Constant, // 3, 4, 17
	Variable, // x
	Operator, // + − =
	Paren, // ( )
}

Token :: struct {
	kind: Token_Kind,
	text: Label,
	term: Expr_Id, // additive term this tile belongs to; NO_EXPR for operators
	side: Side,
}

Token_List :: struct {
	items: [MAX_TOKENS]Token,
	count: int,
}

tokenize :: proc(eq: Equation) -> Token_List {
	return {} // STUB
}

// ---- Moves ----------------------------------------------------------------------
// Offering rules (the contract the tests pin down):
//  R1 Simplify first: if any Distribute / Combine_Constants is possible, ONLY
//     those are offered (Distribute before Combine).
//  R2 Otherwise offer balance moves (apply the same operation to both sides):
//     a. Variable cancel — only when BOTH sides hold a variable term; cancels the
//        variable term on the side with the SMALLER coefficient (tie → right).
//        Listed first and flagged "recommended".
//     b. Constant cancel — for each constant term whose side holds a variable.
//        Listed after (a), in source order (left side first).
//  R3 Nothing is offered when solved ("x = 21").
//  R4 A selected term narrows the list to moves that act on that term.

Move_Kind :: enum {
	Distribute,
	Combine_Constants,
	Add_To_Both,
	Subtract_From_Both,
}

// 2x == {2, true}; 4 == {4, false}. Always the magnitude that is added/subtracted.
Term :: struct {
	coef:    i64,
	has_var: bool,
}

Move :: struct {
	kind:    Move_Kind,
	side:    Side, // side the moved term lives on / the side being simplified
	target:  Expr_Id, // Distribute: the Mul node. Balance: the cancelled term. Combine: NO_EXPR
	operand: Term, // balance moves only
}

Move_List :: struct {
	items: [MAX_MOVES]Move,
	count: int,
}

valid_moves :: proc(eq: Equation, selected: Maybe(Expr_Id) = nil) -> Move_List {
	return {} // STUB
}

// What the UI shows for one move.
Move_View :: struct {
	title:   Label, // "Subtract 2x"
	preview: Label, // raw, unsimplified: "3x − 4 − 2x = 2x + 17 − 2x"
	hint:    Label, // "Cancel the variable on the right."
	heading: Label, // "AFTER SUBTRACTING 2x" (caps, variable stays lower-case)
}

describe_move :: proc(eq: Equation, m: Move) -> Move_View {
	return {} // STUB
}

// "3(x − 4) becomes 3x − 12." / "−12 + 8 becomes −4."  (history card notes)
explain_move :: proc(eq: Equation, m: Move) -> Label {
	return {} // STUB
}

// Balance moves return the fully simplified result ("x − 4 = 17");
// Distribute / Combine only perform their own step.
// Returns ok=false (and the input unchanged) if `m` does not apply to `eq`.
apply_move :: proc(eq: Equation, m: Move) -> (result: Equation, ok: bool) {
	return eq, false // STUB
}

// Completion rule: variable alone on the LEFT, a number equal to the target's on the right.
is_solved :: proc(eq: Equation, target: Equation) -> bool {
	return false // STUB
}
