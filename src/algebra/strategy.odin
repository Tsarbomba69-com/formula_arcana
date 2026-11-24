package algebra

alg_push_move :: proc(list: ^Move_List, m: Move) {
	if list.count >= MAX_MOVES { return }
	list.items[list.count] = m
	list.count += 1
}

@(private = "package")
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
@(private = "package")
alg_move_touches :: proc(eq: ^Equation, m: Move, term: Expr_Id) -> bool {
	switch m.kind {
	case .Distribute, .Add_To_Both, .Subtract_From_Both: return m.target == term
	case .Multiply_Both, .Apply_Function: return false // player requests, never offered as steps
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

// True when token `idx` and `idx + 1` on the same side are adjacent factors of an
// implicit multiplication (e.g. `3` before `(` or `x`, or `)` before `(` or `x`).
@(private = "package")
alg_is_implicit_mul_at :: proc(tokens: ^Token_List, idx: int) -> bool {
	if idx < 0 || idx + 1 >= tokens.count { return false }
	a := tokens.items[idx]
	b := tokens.items[idx + 1]
	if a.side != b.side { return false }

	a_text := label_str(&a.text)
	b_text := label_str(&b.text)
	if a_text == "=" || b_text == "=" { return false }

	left_can_mul := a.kind == .Constant || a.kind == .Variable || a_text == ")"
	right_can_mul := b.kind == .Constant || b.kind == .Variable || b_text == "("
	return left_can_mul && right_can_mul
}

// Checks whether a selected token at `tok_idx` targets move `m`.
@(private = "package")
alg_token_touches_move :: proc(eq: ^Equation, tokens: ^Token_List, tok_idx: int, m: Move) -> bool {
	if tok_idx < 0 || tok_idx >= tokens.count { return false }
	tok := tokens.items[tok_idx]
	if tok.side != m.side { return false }

	op_text := label_str(&tok.text)
	if op_text == "=" { return false }

	// Explicit or implicit multiplication around a .Group term enables .Distribute.
	if m.kind == .Distribute {
		if op_text == "×" {
			return tok.term != NO_EXPR && tok.term == m.target
		}
		if tok.kind == .Operator {
			// `+` and `−` never trigger distribution.
			return false
		}
		// Token is a factor/paren on an implicit multiplication boundary (e.g. `3` or `(` in `3(x − 4)`).
		has_implicit_mul :=
			alg_is_implicit_mul_at(tokens, tok_idx) || alg_is_implicit_mul_at(tokens, tok_idx - 1)
		return has_implicit_mul && tok.term != NO_EXPR && tok.term == m.target
	}

	// Binary `+` or `−` between two combinable terms on the same side.
	if tok.kind == .Operator && (op_text == "+" || op_text == MINUS) {
		if m.kind != .Combine_Constants && m.kind != .Combine_Like_Terms {
			return false
		}
		prev_term := NO_EXPR
		for i := tok_idx - 1; i >= 0; i -= 1 {
			if tokens.items[i].side != tok.side { break }
			if tokens.items[i].term != NO_EXPR {
				prev_term = tokens.items[i].term
				break
			}
		}
		next_term := NO_EXPR
		for i := tok_idx + 1; i < tokens.count; i += 1 {
			if tokens.items[i].side != tok.side { break }
			if tokens.items[i].term != NO_EXPR {
				next_term = tokens.items[i].term
				break
			}
		}
		return(
			prev_term != NO_EXPR &&
			next_term != NO_EXPR &&
			alg_move_touches(eq, m, prev_term) &&
			alg_move_touches(eq, m, next_term) \
		)
	}

	if tok.term != NO_EXPR {
		return alg_move_touches(eq, m, tok.term)
	}
	return false
}

// Does the operator token at `tok_idx` act on move `m`?
@(private = "package")
alg_operator_token_touches :: proc(
	eq: ^Equation,
	tokens: ^Token_List,
	tok_idx: int,
	m: Move,
) -> bool {
	if tok_idx < 0 || tok_idx >= tokens.count { return false }
	tok := tokens.items[tok_idx]
	if tok.kind != .Operator || tok.side != m.side { return false }

	op_text := label_str(&tok.text)
	if op_text == "=" { return false }

	// Find the additive term immediately before and after this operator token on the same side.
	prev_term := NO_EXPR
	for i := tok_idx - 1; i >= 0; i -= 1 {
		if tokens.items[i].side != tok.side { break }
		if tokens.items[i].term != NO_EXPR {
			prev_term = tokens.items[i].term
			break
		}
	}
	next_term := NO_EXPR
	for i := tok_idx + 1; i < tokens.count; i += 1 {
		if tokens.items[i].side != tok.side { break }
		if tokens.items[i].term != NO_EXPR {
			next_term = tokens.items[i].term
			break
		}
	}

	switch m.kind {
	case .Combine_Constants, .Combine_Like_Terms:
		// Only binary + or − between two combinable terms on the same side.
		if op_text != "+" && op_text != MINUS { return false }
		return(
			prev_term != NO_EXPR &&
			next_term != NO_EXPR &&
			alg_move_touches(eq, m, prev_term) &&
			alg_move_touches(eq, m, next_term) \
		)
	case .Distribute:
		// Only explicit multiplication (×) can trigger distribution—never + or −.
		if op_text != "×" { return false }
		return prev_term != NO_EXPR && prev_term == next_term && m.target == prev_term
	case .Add_To_Both, .Subtract_From_Both, .Divide_Both, .Multiply_Both, .Apply_Function:
		return false
	}
	return false
}

valid_moves_by_expr :: proc(eq: Equation, selected: Maybe(Expr_Id) = nil) -> (out: Move_List) {
	eq := eq
	all := alg_all_moves(&eq)
	term, has_term := selected.?
	for m in all.items[:all.count] {
		if has_term && !alg_move_touches(&eq, m, term) { continue }
		alg_push_move(&out, m)
	}
	return
}

valid_moves_by_token :: proc(eq: Equation, tok_idx: int) -> (out: Move_List) {
	eq := eq
	tokens := tokenize(eq)
	if tok_idx < 0 || tok_idx >= tokens.count { return }

	all := alg_all_moves(&eq)
	for m in all.items[:all.count] {
		if alg_token_touches_move(&eq, &tokens, tok_idx, m) {
			alg_push_move(&out, m)
		}
	}
	return
}

valid_moves :: proc {
	valid_moves_by_expr,
	valid_moves_by_token,
}

// ============================================================================
// Player-chosen transformations: what is ALLOWED (as opposed to recommended).
//
// valid_moves / alg_all_moves answer "what do we suggest?". The procs below
// answer "what may the player do?" and must never consult the recommender.
// ============================================================================

// Every kind the player may pick for `eq`. Operands are free, so legality of a
// concrete request is decided by check_transformation. Empty for a zero-value
// or overflowed equation.
applicable_kinds :: proc(eq: Equation) -> Move_Kinds {
	unimplemented()
}

// .None == the request is available. Pure: never mutates, never consults recommendations.
check_transformation :: proc(eq: Equation, t: Transformation) -> Move_Error {
	unimplemented()
}
