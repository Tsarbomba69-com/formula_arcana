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
	#partial switch m.kind {
	case .Distribute, .Add_To_Both, .Subtract_From_Both: return m.target == term
	case .Associate, .Commute: return m.target == term
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

@(private = "package")
alg_token_is_operand :: proc(token: Token) -> bool {
	if token.kind == .Constant || token.kind == .Variable { return true }
	t := token
	return token.kind == .Paren && label_str(&t.text) == ")"
}

@(private = "package")
alg_additive_operator_ordinal :: proc(
	tokens: ^Token_List,
	tok_idx: int,
) -> (
	ordinal: int,
	binary: bool,
) {
	if tok_idx < 0 || tok_idx >= tokens.count { return }
	tok := tokens.items[tok_idx]
	if tok.kind != .Operator { return }
	txt := label_str(&tok.text)
	if txt != "+" && txt != MINUS { return }
	for i in 0 ..< tokens.count {
		current := tokens.items[i]
		if current.side != tok.side || current.kind != .Operator { continue }
		current_text := label_str(&current.text)
		if current_text != "+" && current_text != MINUS { continue }
		prev_is_operand :=
			i > 0 &&
			tokens.items[i - 1].side == tok.side &&
			alg_token_is_operand(tokens.items[i - 1])
		if !prev_is_operand { continue } 	// Unary sign, not a commutable operator.
		if i == tok_idx { binary = true; return }
		if i < tok_idx { ordinal += 1 }
	}
	return
}

@(private = "package")
alg_additive_operator_at :: proc(eq: ^Equation, id: Expr_Id, ordinal: ^int) -> Expr_Id {
	b, ok := alg_node(eq, id).(Bin)
	if !ok { return NO_EXPR }
	if target := alg_additive_operator_at(eq, b.left, ordinal); target != NO_EXPR { return target }
	if b.op == .Add || b.op == .Sub {
		if ordinal^ == 0 { return id }
		ordinal^ -= 1
	}
	return alg_additive_operator_at(eq, b.right, ordinal)
}

@(private = "package")
alg_token_commute_target :: proc(eq: ^Equation, tokens: ^Token_List, tok_idx: int) -> Expr_Id {
	ordinal, binary := alg_additive_operator_ordinal(tokens, tok_idx)
	if !binary { return NO_EXPR }
	root := tokens.items[tok_idx].side == .Left ? eq.lhs : eq.rhs
	return alg_additive_operator_at(eq, root, &ordinal)
}

@(private = "package")
alg_tree_contains :: proc(eq: ^Equation, root, target: Expr_Id) -> bool {
	if root == target { return true }
	if b, ok := alg_node(eq, root).(Bin); ok {
		return alg_tree_contains(eq, b.left, target) || alg_tree_contains(eq, b.right, target)
	}
	return false
}

@(private = "package")
alg_is_contextual_commute_move :: proc(eq: ^Equation, m: Move) -> bool {
	if m.kind != .Commute || m.target == NO_EXPR { return false }
	b, ok := alg_node(eq, m.target).(Bin)
	if !ok || (b.op != .Add && b.op != .Sub) { return false }
	root := m.side == .Left ? eq.lhs : eq.rhs
	return alg_tree_contains(eq, root, m.target)
}

@(private = "package")
alg_commute_chain_root :: proc(
	eq: ^Equation,
	root, target: Expr_Id,
	current: Expr_Id = NO_EXPR,
) -> Expr_Id {
	b, ok := alg_node(eq, root).(Bin)
	if !ok { return NO_EXPR }
	if b.op == .Mul {
		if found := alg_commute_chain_root(eq, b.left, target); found != NO_EXPR { return found }
		return alg_commute_chain_root(eq, b.right, target)
	}
	chain := current == NO_EXPR ? root : current
	if root == target { return chain }
	if found := alg_commute_chain_root(eq, b.left, target, chain);
	   found != NO_EXPR { return found }
	return alg_commute_chain_root(eq, b.right, target, chain)
}

@(private = "package")
alg_commute_chain_ordinal :: proc(
	eq: ^Equation,
	root, target: Expr_Id,
	ordinal: ^int,
) -> (
	found: bool,
) {
	b, ok := alg_node(eq, root).(Bin)
	if !ok || b.op == .Mul { return false }
	if alg_commute_chain_ordinal(eq, b.left, target, ordinal) { return true }
	if root == target { return true }
	ordinal^ += 1
	return alg_commute_chain_ordinal(eq, b.right, target, ordinal)
}

@(private = "package")
alg_collect_chain_operators :: proc(
	eq: ^Equation,
	root: Expr_Id,
	operators: ^[MAX_NODES]Expr_Id,
	count: ^int,
) {
	b, ok := alg_node(eq, root).(Bin)
	if !ok || b.op == .Mul { return }
	alg_collect_chain_operators(eq, b.left, operators, count)
	operators[count^] = root
	count^ += 1
	alg_collect_chain_operators(eq, b.right, operators, count)
}

@(private = "package")
alg_find_parent_link :: proc(
	eq: ^Equation,
	root, target: Expr_Id,
) -> (
	parent: Expr_Id,
	is_left: bool,
	found: bool,
) {
	b, ok := alg_node(eq, root).(Bin)
	if !ok { return }
	if b.left == target { return root, true, true }
	if b.right == target { return root, false, true }
	if nested_parent, nested_left, nested_found := alg_find_parent_link(eq, b.left, target);
	   nested_found {
		return nested_parent, nested_left, true
	}
	return alg_find_parent_link(eq, b.right, target)
}

@(private = "package")
alg_set_term_intrinsic_sign :: proc(eq: ^Equation, term: Expr_Id, negative: bool) -> Expr_Id {
	switch n in alg_node(eq, term) {
	case Num:
		eq.nodes[term] = Num{negative ? -abs(n.value) : abs(n.value)}
		return term
	case Var:
		if !negative { return term }
		minus_one := alg_new(eq, Num{-1})
		if minus_one == NO_EXPR { return NO_EXPR }
		return alg_new(eq, Bin{.Mul, minus_one, term})
	case Bin:
		if n.op == .Mul {
			if coefficient, ok := alg_node(eq, n.left).(Num); ok {
				eq.nodes[n.left] = Num{negative ? -abs(coefficient.value) : abs(coefficient.value)}
				return term
			}
			if coefficient, ok := alg_node(eq, n.right).(Num); ok {
				eq.nodes[n.right] = Num {
					negative ? -abs(coefficient.value) : abs(coefficient.value),
				}
				return term
			}
		}
		if !negative { return term }
		minus_one := alg_new(eq, Num{-1})
		if minus_one == NO_EXPR { return NO_EXPR }
		return alg_new(eq, Bin{.Mul, minus_one, term})
	}
	return NO_EXPR
}

@(private = "package")
alg_swap_commute_pair :: proc(eq: ^Equation, side: Side, root: Expr_Id, pair_index: int) -> bool {
	terms: Sum_List
	alg_collect(eq, root, false, &terms)
	if pair_index < 0 || pair_index + 1 >= terms.count { return false }
	side_root := side == .Left ? eq.lhs : eq.rhs
	parent, parent_left, has_parent := alg_find_parent_link(eq, side_root, root)
	negative: [MAX_TERMS]bool
	for i in 0 ..< terms.count {
		negative[i] = alg_term_negative(eq, terms.items[i])
	}
	terms.items[pair_index], terms.items[pair_index + 1] =
		terms.items[pair_index + 1], terms.items[pair_index]
	negative[pair_index], negative[pair_index + 1] = negative[pair_index + 1], negative[pair_index]
	for i in 0 ..< terms.count {
		node := alg_set_term_intrinsic_sign(eq, terms.items[i].node, negative[i] && i == 0)
		if node == NO_EXPR { return false }
		terms.items[i].node = node
	}

	operators: [MAX_NODES]Expr_Id
	operator_count := 0
	alg_collect_chain_operators(eq, root, &operators, &operator_count)
	if operator_count != terms.count - 1 { return false }
	acc := terms.items[0].node
	for i in 0 ..< operator_count {
		node := operators[i]
		next := terms.items[i + 1]
		op: Binary_Op = negative[i + 1] ? .Sub : .Add
		eq.nodes[node] = Bin{op, acc, next.node}
		acc = node
	}
	new_root := operators[operator_count - 1]
	if !has_parent {
		if side == .Left { eq.lhs = new_root } else { eq.rhs = new_root }
	} else if parent_bin, ok := alg_node(eq, parent).(Bin); ok {
		if parent_left { parent_bin.left = new_root } else { parent_bin.right = new_root }
		eq.nodes[parent] = parent_bin
	}
	return true
}

// Checks whether a selected token at `tok_idx` targets move `m`.
@(private = "package")
alg_token_touches_move :: proc(eq: ^Equation, tokens: ^Token_List, tok_idx: int, m: Move) -> bool {
	if tok_idx < 0 || tok_idx >= tokens.count { return false }
	tok := tokens.items[tok_idx]
	if tok.side != m.side { return false }

	op_text := label_str(&tok.text)
	if op_text == "=" { return false }
	if m.kind == .Commute {
		return tok.kind == .Operator && alg_token_commute_target(eq, tokens, tok_idx) == m.target
	}

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

	#partial switch m.kind {
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
	case .Commute: return alg_token_commute_target(eq, tokens, tok_idx) == m.target
	case .Add_To_Both, .Subtract_From_Both, .Divide_Both, .Multiply_Both, .Apply_Function:
		return false
	}
	return false
}

@(private = "package")
alg_append_contextual_balance :: proc(eq: ^Equation, term: Expr_Id, moves: ^Move_List) {
	if term == NO_EXPR { return }
	for side in Side {
		info := alg_analyze(eq, side)
		for t in info.items[:info.count] {
			if t.node != term { continue }
			if t.kind == .Group {
				candidate := Move{.Distribute, side, t.node, {t.value, false}}
				already_listed := false
				for existing in moves.items[:moves.count] {
					if existing == candidate { already_listed = true; break }
				}
				if !already_listed { alg_push_move(moves, candidate) }
				continue
			}
			if t.kind != .Var && t.kind != .Const { continue }
			kind := t.value < 0 ? Move_Kind.Add_To_Both : Move_Kind.Subtract_From_Both
			candidate := Move{kind, side, t.node, {abs(t.value), t.kind == .Var}}
			already_listed := false
			for existing in moves.items[:moves.count] {
				if existing == candidate { already_listed = true; break }
			}
			if !already_listed { alg_push_move(moves, candidate) }
		}
	}
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
	if label_str(&tokens.items[tok_idx].text) == "=" { return }

	all := alg_all_moves(&eq)
	for m in all.items[:all.count] {
		if alg_token_touches_move(&eq, &tokens, tok_idx, m) {
			alg_push_move(&out, m)
		}
	}

	// A token can also anchor a direct balance move, even when the global
	// recommender currently prefers simplifying another part of the equation.
	tok := tokens.items[tok_idx]
	if tok.kind != .Operator && tok.term != NO_EXPR {
		alg_append_contextual_balance(&eq, tok.term, &out)
	}
	if tok.kind == .Operator && out.count == 0 {
		directions := [2]int{-1, 1}
		for direction in directions {
			adjacent := tok_idx + direction
			for adjacent >= 0 &&
			    adjacent < tokens.count &&
			    tokens.items[adjacent].side == tok.side {
				if tokens.items[adjacent].term != NO_EXPR {
					alg_append_contextual_balance(&eq, tokens.items[adjacent].term, &out)
					break
				}
				adjacent += direction
			}
		}
	}
	if tok.kind == .Operator {
		if target := alg_token_commute_target(&eq, &tokens, tok_idx); target != NO_EXPR {
			alg_push_move(&out, Move{.Commute, tok.side, target, {}})
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
