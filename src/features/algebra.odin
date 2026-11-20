package features

// ============================================================================
// Equation engine for the "Transformation" screen.
// Pure: no raylib, no UI, no allocator. Everything is value-typed and copy-safe.
//
// An Equation is a fixed pool of AST nodes (children by index, like core.UI_Tree).
// All moves are computed on the equation's ADDITIVE TERMS:
//   3(x − 4) + 8   →  terms: [ 3(x − 4) (group) , 8 (const) ]
//
// Offering rules (pinned by algebra_test.odin):
//  R1 Simplify first: Distribute / Combine_Constants / Combine_Like_Terms.
//     If any exists, ONLY those are offered.
//  R2 Otherwise balance moves (same operation on both sides):
//     a. Variable cancel — only when BOTH sides hold a variable term; cancels the
//        one on the side with the SMALLER coefficient (tie → right). Listed first.
//     b. Constant cancel — each constant whose side holds a variable (left, then right).
//     c. Divide_Both — "ax = c" with c divisible by a (a ≠ 0, 1).
//  R3 Nothing is offered when solved.
//  R4 A selected term narrows the list to moves acting on that term.
// Integers only.
// ============================================================================

MAX_NODES :: 32
MAX_TOKENS :: 24
MAX_MOVES :: 8
MAX_TERMS :: 16
LABEL_CAP :: 96

EQUIVALENCE_NOTE :: "Equivalent for every x ∈ ℝ"

@(private = "file")
MINUS :: "−" // U+2212

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

// ============================================================================
// Internal text writer
// ============================================================================

@(private = "file")
Writer :: struct {
	buf: []u8,
	n:   int,
}

@(private = "file")
w_str :: proc(w: ^Writer, s: string) {
	for i in 0 ..< len(s) {
		if w.n < len(w.buf) {
			w.buf[w.n] = s[i]
			w.n += 1
		}
	}
}

@(private = "file")
w_byte :: proc(w: ^Writer, b: u8) {
	if w.n < len(w.buf) {
		w.buf[w.n] = b
		w.n += 1
	}
}

@(private = "file")
w_int :: proc(w: ^Writer, v: i64) {
	tmp: [24]u8
	w_str(w, alg_int_str(v, &tmp))
}

// Signed, with U+2212 for negatives.
@(private = "file")
w_signed :: proc(w: ^Writer, v: i64) {
	if v < 0 { w_str(w, MINUS) }
	w_int(w, abs(v))
}

@(private = "file")
w_text :: proc(w: ^Writer) -> string {
	return string(w.buf[:w.n])
}

@(private = "file")
alg_int_str :: proc(v: i64, tmp: ^[24]u8) -> string {
	if v == 0 { return "0" }
	n := abs(v)
	i := len(tmp)
	for n > 0 {
		i -= 1
		tmp[i] = u8('0' + n % 10)
		n /= 10
	}
	if v < 0 {
		i -= 1
		tmp[i] = '-'
	}
	return string(tmp[i:])
}

// ============================================================================
// Node helpers
// ============================================================================

@(private = "file")
alg_node :: proc(eq: ^Equation, id: Expr_Id) -> Expr_Node {
	if id < 0 || int(id) >= eq.count { return nil }
	return eq.nodes[id]
}

@(private = "file")
alg_new :: proc(eq: ^Equation, n: Expr_Node) -> Expr_Id {
	if eq.count >= MAX_NODES {
		eq.overflow = true
		return NO_EXPR
	}
	eq.nodes[eq.count] = n
	eq.count += 1
	return Expr_Id(eq.count - 1)
}

@(private = "file")
alg_is_sum :: proc(n: Expr_Node) -> bool {
	b, ok := n.(Bin)
	return ok && b.op != .Mul
}

@(private = "file")
alg_eq_name :: proc(eq: ^Equation) -> u8 {
	for i in 0 ..< eq.count {
		if v, ok := eq.nodes[i].(Var); ok { return v.name }
	}
	return 'x'
}

// ---- Additive-term flattening -----------------------------------------------------

@(private = "file")
Sum_Term :: struct {
	node: Expr_Id,
	neg:  bool, // sign contributed by the surrounding − operators
}

@(private = "file")
Sum_List :: struct {
	items:    [MAX_TERMS]Sum_Term,
	count:    int,
	overflow: bool,
}

@(private = "file")
alg_collect :: proc(eq: ^Equation, id: Expr_Id, neg: bool, out: ^Sum_List) {
	if b, ok := alg_node(eq, id).(Bin); ok && b.op != .Mul {
		alg_collect(eq, b.left, neg, out)
		alg_collect(eq, b.right, b.op == .Sub ? !neg : neg, out)
		return
	}
	if out.count >= MAX_TERMS {
		out.overflow = true
		return
	}
	out.items[out.count] = {id, neg}
	out.count += 1
}

// A negative number / negative leading coefficient carries its own sign.
@(private = "file")
alg_intrinsic_neg :: proc(eq: ^Equation, id: Expr_Id) -> bool {
	#partial switch n in alg_node(eq, id) {
	case Num: return n.value < 0
	case Bin: if n.op == .Mul {
				if a, ok := alg_node(eq, n.left).(Num); ok { return a.value < 0 }
			}
	}
	return false
}

@(private = "file")
alg_term_negative :: proc(eq: ^Equation, t: Sum_Term) -> bool {
	return t.neg != alg_intrinsic_neg(eq, t.node)
}

// ============================================================================
// Printing
// ============================================================================

@(private = "file")
alg_print_side :: proc(eq: ^Equation, id: Expr_Id, w: ^Writer) {
	list: Sum_List
	alg_collect(eq, id, false, &list)
	for t, i in list.items[:list.count] {
		neg := alg_term_negative(eq, t)
		if i == 0 {
			if neg { w_str(w, MINUS) }
		} else {
			w_str(w, neg ? " − " : " + ")
		}
		alg_print_mag(eq, t.node, w)
	}
}

// Prints a term WITHOUT its sign.
@(private = "file")
alg_print_mag :: proc(eq: ^Equation, id: Expr_Id, w: ^Writer) {
	switch n in alg_node(eq, id) {
	case nil:
	case Num: w_int(w, abs(n.value))
	case Var: w_byte(w, n.name)
	case Bin:
		if n.op != .Mul {
			w_str(w, "(")
			alg_print_side(eq, id, w)
			w_str(w, ")")
			return
		}
		l, r := alg_node(eq, n.left), alg_node(eq, n.right)
		if a, ok := l.(Num); ok {
			mag := abs(a.value)
			_, r_var := r.(Var)
			r_sum := alg_is_sum(r)
			if mag == 1 && (r_var || r_sum) {
				alg_print_factor(eq, n.right, w) // 1x → x, 1(x + 2) → (x + 2)
			} else if rn, ok2 := r.(Num); ok2 {
				w_int(w, mag)
				w_str(w, " × ")
				w_int(w, abs(rn.value))
			} else {
				w_int(w, mag)
				alg_print_factor(eq, n.right, w)
			}
		} else {
			alg_print_factor(eq, n.left, w)
			alg_print_factor(eq, n.right, w)
		}
	}
}

@(private = "file")
alg_print_factor :: proc(eq: ^Equation, id: Expr_Id, w: ^Writer) {
	alg_print_mag(eq, id, w) // sums get their parentheses inside alg_print_mag
}

// Canonical text: spaces around + − =, tight parentheses, coefficient 1 omitted, U+2212 minus.
// The result aliases `buf`.
format_equation :: proc(eq: Equation, buf: []u8) -> string {
	eq := eq
	if eq.count == 0 { return "" }
	w := Writer {
		buf = buf,
	}
	alg_print_side(&eq, eq.lhs, &w)
	w_str(&w, " = ")
	alg_print_side(&eq, eq.rhs, &w)
	return w_text(&w)
}

format_side :: proc(eq: Equation, side: Side, buf: []u8) -> string {
	eq := eq
	if eq.count == 0 { return "" }
	w := Writer {
		buf = buf,
	}
	alg_print_side(&eq, side == .Left ? eq.lhs : eq.rhs, &w)
	return w_text(&w)
}

// ============================================================================
// Parsing
// ============================================================================
// Accepted: digits, letters, + - − * ( ) = and spaces. Implicit multiplication ("3x", "3(x-4)").
// Unary minus at the start of an expression or parenthesis: "-x = 5", "3(-x + 1)".

Parse_Error :: enum {
	None,
	Empty,
	Missing_Equals,
	Unbalanced_Parens,
	Unexpected_Character,
	Expected_Expression,
	Too_Many_Nodes,
}

@(private = "file")
Parser :: struct {
	runes: [160]rune,
	n:     int,
	pos:   int,
	eq:    ^Equation,
	err:   Parse_Error,
}

@(private = "file")
p_peek :: proc(p: ^Parser) -> rune {
	if p.pos >= p.n { return 0 }
	return p.runes[p.pos]
}

@(private = "file")
p_is_minus :: proc(r: rune) -> bool {
	return r == '-' || r == '−'
}

@(private = "file")
p_is_digit :: proc(r: rune) -> bool {
	return r >= '0' && r <= '9'
}

@(private = "file")
p_is_letter :: proc(r: rune) -> bool {
	return (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z')
}

@(private = "file")
p_fail :: proc(p: ^Parser, err: Parse_Error) -> Expr_Id {
	if p.err == .None { p.err = err }
	return NO_EXPR
}

@(private = "file")
p_add :: proc(p: ^Parser, n: Expr_Node) -> Expr_Id {
	id := alg_new(p.eq, n)
	if id == NO_EXPR { return p_fail(p, .Too_Many_Nodes) }
	return id
}

parse_equation :: proc(src: string) -> (eq: Equation, err: Parse_Error) {
	p := Parser {
		eq = &eq,
	}
	depth := 0
	for r in src {
		if r == ' ' || r == '\t' { continue }
		valid :=
			p_is_digit(r) ||
			p_is_letter(r) ||
			p_is_minus(r) ||
			r == '+' ||
			r == '*' ||
			r == '=' ||
			r == '(' ||
			r == ')'
		if !valid { return {}, .Unexpected_Character }
		if r == '(' { depth += 1 }
		if r == ')' {
			depth -= 1
			if depth < 0 { return {}, .Unbalanced_Parens }
		}
		if p.n >= len(p.runes) { return {}, .Too_Many_Nodes }
		p.runes[p.n] = r
		p.n += 1
	}
	if p.n == 0 { return {}, .Empty }
	if depth != 0 { return {}, .Unbalanced_Parens }

	eq.lhs = p_expr(&p)
	if p.err != .None { return {}, p.err }
	if p_peek(&p) != '=' { return {}, .Missing_Equals }
	p.pos += 1
	eq.rhs = p_expr(&p)
	if p.err != .None { return {}, p.err }
	if p.pos < p.n { return {}, .Unexpected_Character } 	// a second "=" or stray ")"
	return eq, .None
}

// expr := ['+'|'-'] term (('+'|'-') term)*
@(private = "file")
p_expr :: proc(p: ^Parser) -> Expr_Id {
	negate := false
	if p_is_minus(p_peek(p)) {
		negate = true
		p.pos += 1
	} else if p_peek(p) == '+' {
		p.pos += 1
	}
	acc := p_term(p)
	if p.err != .None { return NO_EXPR }
	if negate { acc = p_negate(p, acc) }
	for {
		r := p_peek(p)
		op: Binary_Op
		if r == '+' {
			op = .Add
		} else if p_is_minus(r) {
			op = .Sub
		} else {
			break
		}
		p.pos += 1
		rhs := p_term(p)
		if p.err != .None { return NO_EXPR }
		acc = p_add(p, Bin{op, acc, rhs})
		if p.err != .None { return NO_EXPR }
	}
	return acc
}

// term := factor ( ['*'] factor )*   — a factor may follow directly: implicit multiplication
@(private = "file")
p_term :: proc(p: ^Parser) -> Expr_Id {
	left := p_factor(p)
	if p.err != .None { return NO_EXPR }
	for {
		r := p_peek(p)
		if r == '*' {
			p.pos += 1
		} else if !(r == '(' || p_is_digit(r) || p_is_letter(r)) {
			break
		}
		right := p_factor(p)
		if p.err != .None { return NO_EXPR }
		left = p_add(p, Bin{.Mul, left, right})
		if p.err != .None { return NO_EXPR }
	}
	return left
}

// factor := NUMBER | LETTER | '(' expr ')'
@(private = "file")
p_factor :: proc(p: ^Parser) -> Expr_Id {
	r := p_peek(p)
	switch {
	case r == '(':
		p.pos += 1
		inner := p_expr(p)
		if p.err != .None { return NO_EXPR }
		if p_peek(p) != ')' { return p_fail(p, .Unbalanced_Parens) }
		p.pos += 1
		return inner
	case p_is_digit(r):
		value: i64
		digits := 0
		for p_is_digit(p_peek(p)) {
			value = value * 10 + i64(p_peek(p) - '0')
			digits += 1
			p.pos += 1
		}
		if digits > 9 { return p_fail(p, .Unexpected_Character) }
		return p_add(p, Num{value})
	case p_is_letter(r):
		p.pos += 1
		return p_add(p, Var{u8(r)})
	}
	return p_fail(p, .Expected_Expression)
}

// Gives a term its own minus sign (used for a leading "−").
@(private = "file")
p_negate :: proc(p: ^Parser, id: Expr_Id) -> Expr_Id {
	switch n in alg_node(p.eq, id) {
	case nil: return id
	case Num:
		p.eq.nodes[id] = Num{-n.value}
		return id
	case Var:
		minus_one := p_add(p, Num{-1})
		if p.err != .None { return NO_EXPR }
		return p_add(p, Bin{.Mul, minus_one, id})
	case Bin:
		if n.op == .Mul {
			if a, ok := alg_node(p.eq, n.left).(Num); ok {
				p.eq.nodes[n.left] = Num{-a.value}
				return id
			}
		}
		minus_one := p_add(p, Num{-1})
		if p.err != .None { return NO_EXPR }
		return p_add(p, Bin{.Mul, minus_one, id})
	}
	return id
}

// ============================================================================
// Tokens — what the formula panel draws as tiles
// ============================================================================

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

@(private = "file")
tok_push :: proc(out: ^Token_List, kind: Token_Kind, text: string, term: Expr_Id, side: Side) {
	if out.count >= MAX_TOKENS { return }
	t := &out.items[out.count]
	t^ = {
		kind = kind,
		term = term,
		side = side,
	}
	label_set(&t.text, text)
	out.count += 1
}

@(private = "file")
tok_push_int :: proc(out: ^Token_List, v: i64, term: Expr_Id, side: Side) {
	tmp: [24]u8
	tok_push(out, .Constant, alg_int_str(v, &tmp), term, side)
}

// "3x − 4 = 2x + 17" → 3 x − 4 = 2 x + 17  (9 tiles). Operators are not selectable.
tokenize :: proc(eq: Equation) -> (out: Token_List) {
	eq := eq
	if eq.count == 0 { return }
	alg_tokens_side(&eq, eq.lhs, .Left, NO_EXPR, &out)
	tok_push(&out, .Operator, "=", NO_EXPR, .Left)
	alg_tokens_side(&eq, eq.rhs, .Right, NO_EXPR, &out)
	return
}

@(private = "file")
alg_tokens_side :: proc(
	eq: ^Equation,
	id: Expr_Id,
	side: Side,
	forced_term: Expr_Id,
	out: ^Token_List,
) {
	list: Sum_List
	alg_collect(eq, id, false, &list)
	for t, i in list.items[:list.count] {
		neg := alg_term_negative(eq, t)
		if i == 0 {
			if neg { tok_push(out, .Operator, MINUS, NO_EXPR, side) }
		} else {
			tok_push(out, .Operator, neg ? MINUS : "+", NO_EXPR, side)
		}
		term := forced_term != NO_EXPR ? forced_term : t.node
		alg_tokens_mag(eq, t.node, side, term, out)
	}
}

@(private = "file")
alg_tokens_mag :: proc(eq: ^Equation, id: Expr_Id, side: Side, term: Expr_Id, out: ^Token_List) {
	switch n in alg_node(eq, id) {
	case nil:
	case Num: tok_push_int(out, abs(n.value), term, side)
	case Var: tok_push(out, .Variable, string([]u8{n.name}), term, side)
	case Bin:
		if n.op != .Mul {
			tok_push(out, .Paren, "(", term, side)
			alg_tokens_side(eq, id, side, term, out)
			tok_push(out, .Paren, ")", term, side)
			return
		}
		l, r := alg_node(eq, n.left), alg_node(eq, n.right)
		if a, ok := l.(Num); ok {
			mag := abs(a.value)
			_, r_var := r.(Var)
			if mag == 1 && (r_var || alg_is_sum(r)) {
				alg_tokens_mag(eq, n.right, side, term, out)
			} else if rn, ok2 := r.(Num); ok2 {
				tok_push_int(out, mag, term, side)
				tok_push(out, .Operator, "×", NO_EXPR, side)
				tok_push_int(out, abs(rn.value), term, side)
			} else {
				tok_push_int(out, mag, term, side)
				alg_tokens_mag(eq, n.right, side, term, out)
			}
		} else {
			alg_tokens_mag(eq, n.left, side, term, out)
			alg_tokens_mag(eq, n.right, side, term, out)
		}
	}
}

// ============================================================================
// Term analysis
// ============================================================================

@(private = "file")
Term_Kind :: enum {
	Const,
	Var,
	Group, // k(…) with a simple sum inside — distributable
	Other, // anything the engine does not understand → no moves
}

@(private = "file")
Term_Info :: struct {
	node:  Expr_Id, // the additive term's node
	kind:  Term_Kind,
	value: i64, // signed constant / signed coefficient / signed multiplier
	name:  u8, // variable letter (0 for constants)
	inner: Expr_Id, // Group: the sum inside the brackets
	neg:   bool, // final sign in the sum
}

@(private = "file")
alg_classify :: proc(eq: ^Equation, t: Sum_Term, allow_group: bool) -> Term_Info {
	info := Term_Info {
		node  = t.node,
		kind  = .Other,
		inner = NO_EXPR,
		neg   = alg_term_negative(eq, t),
	}
	sign := i64(t.neg ? -1 : 1)

	#partial switch n in alg_node(eq, t.node) {
	case Num:
		info.kind = .Const
		info.value = sign * n.value
	case Var:
		info.kind = .Var
		info.value = sign
		info.name = n.name
	case Bin:
		if n.op != .Mul { break }
		l, r := alg_node(eq, n.left), alg_node(eq, n.right)
		if a, ok := l.(Num); ok {
			#partial switch rv in r {
			case Num:
				info.kind = .Const
				info.value = sign * a.value * rv.value
			case Var:
				info.kind = .Var
				info.value = sign * a.value
				info.name = rv.name
			case Bin: if allow_group && rv.op != .Mul {
						if name, simple := alg_inner_simple(eq, n.right); simple {
							info.kind = .Group
							info.value = sign * a.value
							info.inner = n.right
							info.name = name
						}
					}
			}
		} else if lv, ok2 := l.(Var); ok2 {
			if rn, ok3 := r.(Num); ok3 {
				info.kind = .Var
				info.value = sign * rn.value
				info.name = lv.name
			}
		}
	}
	return info
}

// Every term inside the brackets is a plain constant or a single-variable term.
@(private = "file")
alg_inner_simple :: proc(eq: ^Equation, group: Expr_Id) -> (name: u8, simple: bool) {
	list: Sum_List
	alg_collect(eq, group, false, &list)
	if list.overflow { return 0, false }
	for t in list.items[:list.count] {
		ti := alg_classify(eq, t, false)
		switch ti.kind {
		case .Const:
		case .Var:
			if name != 0 && name != ti.name { return 0, false }
			name = ti.name
		case .Group, .Other: return 0, false
		}
	}
	return name, true
}

@(private = "file")
Side_Info :: struct {
	items: [MAX_TERMS]Term_Info,
	count: int,
	ok:    bool, // every term understood
}

@(private = "file")
alg_analyze :: proc(eq: ^Equation, side: Side) -> (info: Side_Info) {
	list: Sum_List
	alg_collect(eq, side == .Left ? eq.lhs : eq.rhs, false, &list)
	info.ok = !list.overflow && list.count > 0
	for t in list.items[:list.count] {
		ti := alg_classify(eq, t, true)
		if ti.kind == .Other { info.ok = false }
		info.items[info.count] = ti
		info.count += 1
	}
	return
}

// ============================================================================
// Moves
// ============================================================================

Move_Kind :: enum {
	Distribute,
	Combine_Constants,
	Combine_Like_Terms,
	Add_To_Both,
	Subtract_From_Both,
	Divide_Both,
}

// 2x == {2, true}; 4 == {4, false}. Balance moves: always the magnitude added / subtracted.
// Divide_Both: the (signed) coefficient divided by. Distribute: the signed multiplier.
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

@(private = "file")
alg_push_move :: proc(list: ^Move_List, m: Move) {
	if list.count >= MAX_MOVES { return }
	list.items[list.count] = m
	list.count += 1
}

@(private = "file")
alg_all_moves :: proc(eq: ^Equation) -> (moves: Move_List) {
	if eq.count == 0 || eq.overflow { return }
	sides := [2]Side_Info{alg_analyze(eq, .Left), alg_analyze(eq, .Right)}
	if !sides[0].ok || !sides[1].ok { return }

	// One variable letter per puzzle.
	name: u8
	for s in sides {
		for i in 0 ..< s.count {
			t := s.items[i]
			if t.name == 0 { continue }
			if name != 0 && name != t.name { return }
			name = t.name
		}
	}

	// ---- R1: simplify first ----
	for side in Side {
		s := sides[side]
		for t in s.items[:s.count] {
			if t.kind == .Group {
				alg_push_move(&moves, Move{.Distribute, side, t.node, {t.value, false}})
			}
		}
	}
	for side in Side {
		s := sides[side]
		consts := 0
		for t in s.items[:s.count] {
			if t.kind == .Const { consts += 1 }
		}
		if consts >= 2 { alg_push_move(&moves, Move{.Combine_Constants, side, NO_EXPR, {}}) }
	}
	for side in Side {
		s := sides[side]
		vars := 0
		for t in s.items[:s.count] {
			if t.kind == .Var { vars += 1 }
		}
		if vars >= 2 { alg_push_move(&moves, Move{.Combine_Like_Terms, side, NO_EXPR, {}}) }
	}
	if moves.count > 0 { return }

	// ---- R2: balance moves (each side now has at most one variable term and one constant) ----
	var_term, const_term: [2]Maybe(Term_Info)
	for side in Side {
		for t in sides[side].items[:sides[side].count] {
			if t.kind == .Var { var_term[side] = t }
			if t.kind == .Const { const_term[side] = t }
		}
	}

	left_var, has_left_var := var_term[Side.Left].?
	right_var, has_right_var := var_term[Side.Right].?

	if has_left_var && has_right_var {
		cancel_side := Side.Right
		cancel := right_var
		if left_var.value < right_var.value {
			cancel_side = .Left
			cancel = left_var
		}
		kind := cancel.value > 0 ? Move_Kind.Subtract_From_Both : Move_Kind.Add_To_Both
		alg_push_move(&moves, Move{kind, cancel_side, cancel.node, {abs(cancel.value), true}})
	}

	for side in Side {
		c, has_const := const_term[side].?
		_, side_has_var := var_term[side].?
		if has_const && side_has_var && c.value != 0 {
			kind := c.value > 0 ? Move_Kind.Subtract_From_Both : Move_Kind.Add_To_Both
			alg_push_move(&moves, Move{kind, side, c.node, {abs(c.value), false}})
		}
	}

	// ---- c: "ax = c" ----
	if moves.count == 0 && sides[0].count == 1 && sides[1].count == 1 && has_left_var {
		rc, rc_ok := const_term[Side.Right].?
		a := left_var.value
		if rc_ok && a != 0 && a != 1 && rc.value % a == 0 {
			alg_push_move(&moves, Move{.Divide_Both, .Left, left_var.node, {a, true}})
		}
	}
	return
}

// Does `term` (an additive-term node id) belong to what the move acts on?
@(private = "file")
alg_move_touches :: proc(eq: ^Equation, m: Move, term: Expr_Id) -> bool {
	switch m.kind {
	case .Distribute, .Add_To_Both, .Subtract_From_Both: return m.target == term
	case .Combine_Constants, .Combine_Like_Terms:
		info := alg_analyze(eq, m.side)
		want: Term_Kind = m.kind == .Combine_Constants ? .Const : .Var
		for t in info.items[:info.count] {
			if t.node == term && t.kind == want { return true }
		}
	case .Divide_Both: for side in Side {
				info := alg_analyze(eq, side)
				for t in info.items[:info.count] {
					if t.node == term { return true }
				}
			}
	}
	return false
}

valid_moves :: proc(eq: Equation, selected: Maybe(Expr_Id) = nil) -> (out: Move_List) {
	eq := eq
	all := alg_all_moves(&eq)
	term, has_term := selected.?
	for m in all.items[:all.count] {
		if has_term && !alg_move_touches(&eq, m, term) { continue }
		alg_push_move(&out, m)
	}
	return
}

// ============================================================================
// Building new equations from term specs
// ============================================================================

@(private = "file")
Spec_Kind :: enum {
	Const,
	Var,
	Node, // copy a term subtree from the source equation (a group we do not expand)
}

@(private = "file")
Spec :: struct {
	kind:  Spec_Kind,
	value: i64, // Const / Var: signed constant or coefficient
	name:  u8,
	src:   Expr_Id, // Node: term in the source equation
	neg:   bool, // Node: final sign in the sum
}

@(private = "file")
Spec_List :: struct {
	items: [MAX_TERMS * 2]Spec,
	count: int,
}

@(private = "file")
spec_push :: proc(l: ^Spec_List, s: Spec) {
	if l.count >= len(l.items) { return }
	l.items[l.count] = s
	l.count += 1
}

@(private = "file")
spec_negative :: proc(s: Spec) -> bool {
	return s.kind == .Node ? s.neg : s.value < 0
}

@(private = "file")
alg_side_specs :: proc(eq: ^Equation, side: Side) -> (out: Spec_List) {
	info := alg_analyze(eq, side)
	for t in info.items[:info.count] {
		switch t.kind {
		case .Const: spec_push(&out, Spec{kind = .Const, value = t.value})
		case .Var: spec_push(&out, Spec{kind = .Var, value = t.value, name = t.name})
		case .Group, .Other: spec_push(&out, Spec{kind = .Node, src = t.node, neg = t.neg})
		}
	}
	return
}

// Copies a subtree as-is.
@(private = "file")
alg_copy :: proc(dst, src: ^Equation, id: Expr_Id) -> Expr_Id {
	switch n in alg_node(src, id) {
	case nil: return NO_EXPR
	case Num: return alg_new(dst, n)
	case Var: return alg_new(dst, n)
	case Bin:
		l := alg_copy(dst, src, n.left)
		r := alg_copy(dst, src, n.right)
		return alg_new(dst, Bin{n.op, l, r})
	}
	return NO_EXPR
}

// Copies a term so its OWN sign (leading coefficient) is `negative`.
@(private = "file")
alg_copy_signed :: proc(dst, src: ^Equation, id: Expr_Id, negative: bool) -> Expr_Id {
	switch n in alg_node(src, id) {
	case nil: return NO_EXPR
	case Num: return alg_new(dst, Num{negative ? -abs(n.value) : abs(n.value)})
	case Var:
		v := alg_new(dst, n)
		if !negative { return v }
		return alg_new(dst, Bin{.Mul, alg_new(dst, Num{-1}), v})
	case Bin:
		if n.op == .Mul {
			if a, ok := alg_node(src, n.left).(Num); ok {
				coef := alg_new(dst, Num{negative ? -abs(a.value) : abs(a.value)})
				return alg_new(dst, Bin{.Mul, coef, alg_copy(dst, src, n.right)})
			}
		}
		whole := alg_copy(dst, src, id)
		if !negative { return whole }
		return alg_new(dst, Bin{.Mul, alg_new(dst, Num{-1}), whole})
	}
	return NO_EXPR
}

@(private = "file")
alg_make_term :: proc(dst, src: ^Equation, s: Spec, intrinsic_neg: bool) -> Expr_Id {
	switch s.kind {
	case .Const: return alg_new(dst, Num{intrinsic_neg ? -abs(s.value) : abs(s.value)})
	case .Var:
		mag := abs(s.value)
		v := alg_new(dst, Var{s.name != 0 ? s.name : 'x'})
		if mag == 1 && !intrinsic_neg { return v }
		coef := alg_new(dst, Num{intrinsic_neg ? -mag : mag})
		return alg_new(dst, Bin{.Mul, coef, v})
	case .Node: return alg_copy_signed(dst, src, s.src, intrinsic_neg)
	}
	return NO_EXPR
}

// Left-associative sum. The first term carries its own sign; later terms use Add / Sub.
@(private = "file")
alg_build_side :: proc(dst, src: ^Equation, specs: []Spec) -> Expr_Id {
	if len(specs) == 0 { return alg_new(dst, Num{0}) }
	acc: Expr_Id
	for s, i in specs {
		neg := spec_negative(s)
		if i == 0 {
			acc = alg_make_term(dst, src, s, neg)
		} else {
			t := alg_make_term(dst, src, s, false)
			acc = alg_new(dst, Bin{neg ? .Sub : .Add, acc, t})
		}
	}
	return acc
}

@(private = "file")
alg_assemble :: proc(src: ^Equation, l, r: []Spec) -> (out: Equation, ok: bool) {
	out.lhs = alg_build_side(&out, src, l)
	out.rhs = alg_build_side(&out, src, r)
	return out, !out.overflow
}

// Text of a standalone sum of specs ("−12 + 8").
@(private = "file")
alg_specs_text :: proc(src: ^Equation, specs: []Spec, w: ^Writer) {
	tmp: Equation
	root := alg_build_side(&tmp, src, specs)
	alg_print_side(&tmp, root, w)
}

// var terms first, then the constant; zero terms vanish; an empty side becomes 0.
@(private = "file")
alg_normalize :: proc(specs: []Spec, name: u8) -> (out: Spec_List) {
	var_total, const_total: i64
	for s in specs {
		if s.kind == .Var { var_total += s.value }
		if s.kind == .Const { const_total += s.value }
	}
	if var_total != 0 { spec_push(&out, Spec{kind = .Var, value = var_total, name = name}) }
	if const_total != 0 { spec_push(&out, Spec{kind = .Const, value = const_total}) }
	if out.count == 0 { spec_push(&out, Spec{kind = .Const, value = 0}) }
	return
}

// Replaces all specs of `kind` with their sum, placed where the first one was.
@(private = "file")
alg_combine :: proc(specs: Spec_List, kind: Spec_Kind, name: u8) -> (out: Spec_List) {
	first := -1
	total: i64
	for i in 0 ..< specs.count {
		s := specs.items[i]
		if s.kind == kind {
			total += s.value
			if first < 0 {
				first = out.count
				spec_push(&out, Spec{kind = kind, name = name}) // placeholder
			}
		} else {
			spec_push(&out, s)
		}
	}
	if first >= 0 {
		out.items[first].value = total
		if total == 0 {
			for i in first ..< out.count - 1 { out.items[i] = out.items[i + 1] }
			out.count -= 1
		}
	}
	if out.count == 0 { spec_push(&out, Spec{kind = .Const, value = 0}) }
	return
}

@(private = "file")
alg_expand_group :: proc(eq: ^Equation, g: Term_Info) -> (out: Spec_List) {
	list: Sum_List
	alg_collect(eq, g.inner, false, &list)
	for t in list.items[:list.count] {
		ti := alg_classify(eq, t, false)
		v := g.value * ti.value
		if v == 0 { continue }
		if ti.kind == .Var {
			spec_push(&out, Spec{kind = .Var, value = v, name = ti.name})
		} else {
			spec_push(&out, Spec{kind = .Const, value = v})
		}
	}
	return
}

// Applies `m` WITHOUT checking that it is offered (callers check).
@(private = "file")
alg_perform :: proc(eq: ^Equation, m: Move) -> (out: Equation, ok: bool) {
	name := alg_eq_name(eq)
	left, right := alg_side_specs(eq, .Left), alg_side_specs(eq, .Right)

	switch m.kind {
	case .Distribute:
		specs := m.side == .Left ? &left : &right
		info := alg_analyze(eq, m.side)
		rebuilt: Spec_List
		for t, i in info.items[:info.count] {
			if t.node == m.target && t.kind == .Group {
				expanded := alg_expand_group(eq, t)
				for e in expanded.items[:expanded.count] { spec_push(&rebuilt, e) }
			} else {
				spec_push(&rebuilt, specs.items[i])
			}
		}
		if rebuilt.count == 0 { spec_push(&rebuilt, Spec{kind = .Const, value = 0}) }
		specs^ = rebuilt

	case .Combine_Constants, .Combine_Like_Terms:
		specs := m.side == .Left ? &left : &right
		kind: Spec_Kind = m.kind == .Combine_Constants ? .Const : .Var
		specs^ = alg_combine(specs^, kind, name)

	case .Add_To_Both, .Subtract_From_Both:
		sign := i64(m.kind == .Add_To_Both ? 1 : -1)
		extra: Spec
		if m.operand.has_var {
			extra = Spec {
				kind  = .Var,
				value = sign * m.operand.coef,
				name  = name,
			}
		} else {
			extra = Spec {
				kind  = .Const,
				value = sign * m.operand.coef,
			}
		}
		spec_push(&left, extra)
		spec_push(&right, extra)
		left = alg_normalize(left.items[:left.count], name)
		right = alg_normalize(right.items[:right.count], name)

	case .Divide_Both:
		a := m.operand.coef
		if a == 0 { return eq^, false }
		c: i64
		for s in right.items[:right.count] { if s.kind == .Const { c += s.value } }
		left = {}
		spec_push(&left, Spec{kind = .Var, value = 1, name = name})
		right = {}
		spec_push(&right, Spec{kind = .Const, value = c / a})
	}
	return alg_assemble(eq, left.items[:left.count], right.items[:right.count])
}

// Distribute / Combine only perform their own step. Balance moves return the fully simplified result.
// ok == false (and the input unchanged) if `m` is not offered for `eq`.
apply_move :: proc(eq: Equation, m: Move) -> (result: Equation, ok: bool) {
	eq := eq
	all := alg_all_moves(&eq)
	offered := false
	for c in all.items[:all.count] {
		if c == m { offered = true }
	}
	if !offered { return eq, false }
	out, built := alg_perform(&eq, m)
	if !built { return eq, false }
	return out, true
}

// ============================================================================
// Describing moves
// ============================================================================

// What the UI shows for one move.
Move_View :: struct {
	title:   Label, // "Subtract 2x"
	preview: Label, // raw, unsimplified: "3x − 4 − 2x = 2x + 17 − 2x"
	hint:    Label, // "Cancel the variable on the right."
	heading: Label, // "AFTER SUBTRACTING 2x" (caps, variable stays lower-case)
}

@(private = "file")
w_term :: proc(w: ^Writer, t: Term, name: u8) {
	if t.has_var {
		if t.coef != 1 { w_signed(w, t.coef) }
		if t.coef == -1 { w_str(w, MINUS) }
		w_byte(w, name)
	} else {
		w_signed(w, t.coef)
	}
}

describe_move :: proc(eq: Equation, m: Move) -> (view: Move_View) {
	eq := eq
	name := alg_eq_name(&eq)
	buf: [LABEL_CAP * 2]u8
	w := Writer {
		buf = buf[:],
	}

	// ---- title ----
	switch m.kind {
	case .Distribute:
		w_str(&w, "Distribute ")
		w_signed(&w, m.operand.coef)
	case .Combine_Constants: w_str(&w, "Combine constants")
	case .Combine_Like_Terms: w_str(&w, "Combine like terms")
	case .Add_To_Both:
		w_str(&w, "Add ")
		w_term(&w, m.operand, name)
	case .Subtract_From_Both:
		w_str(&w, "Subtract ")
		w_term(&w, m.operand, name)
	case .Divide_Both:
		w_str(&w, "Divide by ")
		w_signed(&w, m.operand.coef)
	}
	label_set(&view.title, w_text(&w))

	// ---- heading ----
	w.n = 0
	switch m.kind {
	case .Distribute:
		w_str(&w, "AFTER DISTRIBUTING ")
		w_signed(&w, m.operand.coef)
	case .Combine_Constants: w_str(&w, "AFTER COMBINING CONSTANTS")
	case .Combine_Like_Terms: w_str(&w, "AFTER COMBINING LIKE TERMS")
	case .Add_To_Both:
		w_str(&w, "AFTER ADDING ")
		w_term(&w, m.operand, name)
	case .Subtract_From_Both:
		w_str(&w, "AFTER SUBTRACTING ")
		w_term(&w, m.operand, name)
	case .Divide_Both:
		w_str(&w, "AFTER DIVIDING BY ")
		w_signed(&w, m.operand.coef)
	}
	label_set(&view.heading, w_text(&w))

	// ---- hint ----
	side_word := m.side == .Left ? "left" : "right"
	w.n = 0
	switch m.kind {
	case .Distribute:
		w_str(&w, "Multiply ")
		w_signed(&w, m.operand.coef)
		w_str(&w, " into each term in the brackets.")
	case .Combine_Constants:
		w_str(&w, "Merge the constants on the ")
		w_str(&w, side_word)
		w_str(&w, ".")
	case .Combine_Like_Terms:
		w_str(&w, "Merge the like terms on the ")
		w_str(&w, side_word)
		w_str(&w, ".")
	case .Add_To_Both, .Subtract_From_Both: if m.operand.has_var {
				w_str(&w, "Cancel the variable on the ")
				w_str(&w, side_word)
				w_str(&w, ".")
			} else if m.side == .Left {
				w_str(&w, "Remove the constant on the left.")
			} else {
				w_str(&w, "Move the right-hand constant.")
			}
	case .Divide_Both: w_str(&w, "Divide both sides by the coefficient.")
	}
	label_set(&view.hint, w_text(&w))

	// ---- preview (raw, unsimplified) ----
	w.n = 0
	switch m.kind {
	case .Distribute, .Combine_Constants, .Combine_Like_Terms:
		if result, ok := alg_perform(&eq, m); ok {
				out: [LABEL_CAP * 2]u8
				w_str(&w, format_equation(result, out[:]))
			}
	case .Add_To_Both, .Subtract_From_Both, .Divide_Both:
		op: string
		switch m.kind {
		case .Add_To_Both: op = " + "
		case .Subtract_From_Both: op = " − "
		case .Divide_Both: op = " ÷ "
		case .Distribute, .Combine_Constants, .Combine_Like_Terms:
		}
		for side in Side {
			out: [LABEL_CAP]u8
			w_str(&w, format_side(eq, side, out[:]))
			w_str(&w, op)
			if m.kind == .Divide_Both {
				w_signed(&w, m.operand.coef)
			} else {
				w_term(&w, m.operand, name)
			}
			if side == .Left { w_str(&w, " = ") }
		}
	}
	label_set(&view.preview, w_text(&w))
	return
}

// "3(x − 4) becomes 3x − 12." / "−12 + 8 becomes −4."  (history card notes)
explain_move :: proc(eq: Equation, m: Move) -> (note: Label) {
	eq := eq
	name := alg_eq_name(&eq)
	buf: [LABEL_CAP * 2]u8
	w := Writer {
		buf = buf[:],
	}

	switch m.kind {
	case .Distribute:
		info := alg_analyze(&eq, m.side)
		for t in info.items[:info.count] {
			if t.node != m.target || t.kind != .Group { continue }
			original := Spec {
				kind = .Node,
				src  = t.node,
				neg  = t.neg,
			}
			alg_specs_text(&eq, {original}, &w)
			w_str(&w, " becomes ")
			expanded := alg_expand_group(&eq, t)
			alg_specs_text(&eq, expanded.items[:expanded.count], &w)
			w_str(&w, ".")
		}

	case .Combine_Constants, .Combine_Like_Terms:
		kind: Spec_Kind = m.kind == .Combine_Constants ? .Const : .Var
		specs := alg_side_specs(&eq, m.side)
		picked: Spec_List
		for s in specs.items[:specs.count] {
			if s.kind == kind { spec_push(&picked, s) }
		}
		alg_specs_text(&eq, picked.items[:picked.count], &w)
		w_str(&w, " becomes ")
		combined := alg_combine(picked, kind, name)
		alg_specs_text(&eq, combined.items[:combined.count], &w)
		w_str(&w, ".")

	case .Add_To_Both:
		w_str(&w, "Added ")
		w_term(&w, m.operand, name)
		w_str(&w, " to both sides.")
	case .Subtract_From_Both:
		w_str(&w, "Subtracted ")
		w_term(&w, m.operand, name)
		w_str(&w, " from both sides.")
	case .Divide_Both:
		w_str(&w, "Divided both sides by ")
		w_signed(&w, m.operand.coef)
		w_str(&w, ".")
	}
	label_set(&note, w_text(&w))
	return
}

// ============================================================================
// Completion rule
// ============================================================================

// Variable alone on the LEFT, a number equal to the target's on the right.
is_solved :: proc(eq: Equation, target: Equation) -> bool {
	eq, target := eq, target
	if eq.count == 0 || target.count == 0 { return false }

	lv, l_ok := alg_node(&eq, eq.lhs).(Var)
	rv, r_ok := alg_node(&eq, eq.rhs).(Num)
	tl, tl_ok := alg_node(&target, target.lhs).(Var)
	tr, tr_ok := alg_node(&target, target.rhs).(Num)
	if !(l_ok && r_ok && tl_ok && tr_ok) { return false }
	return lv.name == tl.name && rv.value == tr.value
}
