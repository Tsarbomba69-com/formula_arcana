package algebra

@(private = "package")
Parser :: struct {
	source: string,
	tokens: Source_Token_List,
	pos:    int,
	eq:     ^Equation,
	err:    Parse_Error,
}

@(private = "package")
p_peek :: proc(p: ^Parser) -> Source_Token_Kind {
	if p.pos >= p.tokens.count { return .End }
	return p.tokens.items[p.pos].kind
}

@(private = "package")
p_fail :: proc(p: ^Parser, err: Parse_Error) -> Expr_Id {
	if p.err == .None { p.err = err }
	return NO_EXPR
}

@(private = "package")
p_add :: proc(p: ^Parser, n: Expr_Node) -> Expr_Id {
	id := alg_new(p.eq, n)
	if id == NO_EXPR { return p_fail(p, .Too_Many_Nodes) }
	return id
}

parse_equation :: proc(src: string) -> (eq: Equation, err: Parse_Error) {
	tokens, lex_err := lex_source(src)
	if lex_err != .None { return {}, lex_err }
	p := Parser {
		source = src,
		tokens = tokens,
		eq     = &eq,
	}
	eq.lhs = p_expr(&p)
	if p.err != .None { return {}, p.err }
	if p_peek(&p) != .Equals { return {}, .Missing_Equals }
	p.pos += 1
	eq.rhs = p_expr(&p)
	if p.err != .None { return {}, p.err }
	if p_peek(&p) != .End { return {}, .Unexpected_Character }
	return eq, .None
}

// expr := ['+'|'-'] term (('+'|'-') term)*
@(private = "package")
p_expr :: proc(p: ^Parser) -> Expr_Id {
	negate := false
	if p_peek(p) == .Minus {
		negate = true
		p.pos += 1
	} else if p_peek(p) == .Plus {
		p.pos += 1
	}
	acc := p_term(p)
	if p.err != .None { return NO_EXPR }
	if negate { acc = p_negate(p, acc) }
	for {
		kind := p_peek(p)
		op: Binary_Op
		if kind == .Plus {
			op = .Add
		} else if kind == .Minus {
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

// term := factor (['*'] factor)*; adjacent factors imply multiplication.
@(private = "package")
p_term :: proc(p: ^Parser) -> Expr_Id {
	left := p_factor(p)
	if p.err != .None { return NO_EXPR }
	for {
		kind := p_peek(p)
		if kind == .Star {
			p.pos += 1
		} else if !(kind == .Left_Paren || kind == .Number || kind == .Letter) {
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
@(private = "package")
p_factor :: proc(p: ^Parser) -> Expr_Id {
	token := p.tokens.items[p.pos]
	#partial switch token.kind {
	case .Left_Paren:
		p.pos += 1
		inner := p_expr(p)
		if p.err != .None { return NO_EXPR }
		if p_peek(p) != .Right_Paren { return p_fail(p, .Unbalanced_Parens) }
		p.pos += 1
		return inner
	case .Number:
		span := token.span
		if span.end - span.start > 9 { return p_fail(p, .Unexpected_Character) }
		value: i64
		for i in span.start ..< span.end {
			value = value * 10 + i64(p.source[i] - '0')
		}
		p.pos += 1
		return p_add(p, Num{value})
	case .Letter:
		name := u8(p.source[token.span.start])
		p.pos += 1
		return p_add(p, Var{name})
	}
	return p_fail(p, .Expected_Expression)
}

// Gives a term its own minus sign (used for a leading "−").
@(private = "package")
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
