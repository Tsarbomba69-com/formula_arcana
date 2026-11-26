package algebra

MAX_NODES :: 64
MAX_TOKENS :: 24
MAX_MOVES :: 8
MAX_TERMS :: 16
LABEL_CAP :: 96

EQUIVALENCE_NOTE :: "Equivalent for every x ∈ ℝ"
DISTRIBUTIVE_ADDITION_RULE :: "Addition: a(b + c) = ab + ac"
DISTRIBUTIVE_SUBTRACTION_RULE :: "Subtraction: a(b - c) = ab - ac"

@(private = "package")
MINUS :: "−" // U+2212
PLUS :: "+"

// ---- Expression tree ------------------------------------------------------------

Expr_Id :: distinct int
NO_EXPR :: Expr_Id(-1)

Binary_Op :: enum {
	Add,
	Sub,
	Mul, // also produced by implicit multiplication: 3x, 3(x − 4)
}

Num :: struct {
	value: i64,
}

Var :: struct {
	name: u8,
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
	overflow: bool, // the pool was too small while building
}

Side :: enum {
	Left,
	Right,
}

// ---- Fixed-capacity text -----------------------------------------------------------

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

Parse_Error :: enum {
	None,
	Empty,
	Missing_Equals,
	Unbalanced_Parens,
	Unexpected_Character,
	Expected_Expression,
	Too_Many_Nodes,
}
Token_Kind :: enum {
	Constant, // 3, 4, 17
	Variable, // x
	Operator, // + − = ×
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
Move_Kind :: enum {
	Distribute,
	Combine_Constants,
	Combine_Like_Terms,
	Add_To_Both,
	Subtract_From_Both,
	Divide_Both,
	Multiply_Both, // player-chosen: every term of both sides
	Apply_Function, // player-chosen: the function wraps each complete side
	Associate,
	Commute,
}

Move_Kinds :: bit_set[Move_Kind]

// 2x == {2, true}; 4 == {4, false}. Balance moves: always the magnitude added / subtracted.
// Divide_Both / Multiply_Both: the (signed) coefficient divided / multiplied by. Distribute: the signed multiplier.
Term :: struct {
	coef:    i64,
	has_var: bool,
}

Move :: struct {
	kind:    Move_Kind,
	side:    Side, // side the term lives on / the side being simplified
	target:  Expr_Id, // Distribute: the term. Balance: the cancelled term. Combine: NO_EXPR
	operand: Term,
}

Move_List :: struct {
	items: [MAX_MOVES]Move,
	count: int,
}

// What the UI shows for one move.
Move_View :: struct {
	title:   Label, // "Distributive property" or "Subtract 2x"
	action:  Label, // concrete operation recorded in history, e.g. "Distribute 3"
	rule:    Label, // general mathematical rule represented by the move
	rule_2:  Label, // second form when a property has multiple cases
	preview: Label, // raw, unsimplified: "3x − 4 − 2x = 2x + 17 − 2x"
	hint:    Label, // "Cancel the variable on the right."
	heading: Label, // "AFTER SUBTRACTING 2x" (caps, variable stays lower-case)
}

// How safe a move is. Zero value is Equivalent, so an untouched History_Entry reads as "equivalent".
Equivalence :: enum {
	Equivalent,
	Not_Equivalent, // information lost (e.g. multiply by 0)
	May_Introduce_Extra_Solutions, // e.g. squaring both sides
}

Move_Error :: enum {
	None,
	Not_Applicable, // zero-value / overflowed equation, or unsupported request
	Division_By_Zero,
	Unproven_Substitution, // the value is not backed by a known equality
}

// ---- Player-chosen transformations ---------------------------------------------

Function_Kind :: enum {
	Square,
}

// A request chosen by the player. Value-typed and comparable with ==.
// Accepted kinds: Add_To_Both, Subtract_From_Both, Multiply_Both, Divide_Both,
// Apply_Function. Other Move_Kinds are step moves and yield .Not_Applicable.
Transformation :: struct {
	kind:     Move_Kind,
	operand:  Term, // Add / Subtract / Multiply / Divide (constants: has_var == false)
	function: Function_Kind, // Apply_Function
}

Transform_Result :: struct {
	equation:    Equation, // identical to the input whenever error != .None
	equivalence: Equivalence, // meaningful only when error == .None
	error:       Move_Error,
}

// An expression with no "=". ASSUMPTION: reuses the Equation node arena; the root
// lives in `eq.lhs` and `eq.rhs` stays NO_EXPR.
Expression :: struct {
	eq: Equation,
}

// "Replace `variable` with `value`."
Substitution :: struct {
	variable: u8,
	value:    i64,
}

Substitution_Result :: struct {
	expression: Expression, // identical to the input whenever error != .None
	equality:   Equation, // the known equality that justified it ("x = 3"); zero-value on error
	error:      Move_Error,
}

// Token-to-token provenance for visualizing a rewrite in the presentation layer.
Move_Animation_Pair :: struct {
	source_token:      int,
	destination_token: int,
}

Move_Animation_Map :: struct {
	pairs: [MAX_TOKENS]Move_Animation_Pair,
	count: int,
}
