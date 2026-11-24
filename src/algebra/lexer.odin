package algebra

@(private = "package")
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

@(private = "package")
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

@(private = "package")
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

@(private = "package")
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


// Source tokens retain byte spans into the original equation text.
Source_Token_Kind :: enum {
	Number,
	Letter,
	Plus,
	Minus,
	Star,
	Equals,
	Left_Paren,
	Right_Paren,
	End,
}

Source_Span :: struct {
	start, end: int,
}

Source_Token :: struct {
	kind: Source_Token_Kind,
	span: Source_Span,
}

Source_Token_List :: struct {
	items: [160]Source_Token,
	count: int,
}

// Splits source text into parser tokens. Spans are byte offsets and include no
// leading or trailing whitespace. Only the language's supported ASCII spaces
// and tabs are skipped.
lex_source :: proc(src: string) -> (out: Source_Token_List, err: Parse_Error) {
	depth := 0
	i := 0
	for i < len(src) {
		b := src[i]
		if b == ' ' || b == '\t' {
			i += 1
			continue
		}
		start := i
		kind: Source_Token_Kind
		switch {
		case b >= '0' && b <= '9':
			kind = .Number
			for i < len(src) && src[i] >= '0' && src[i] <= '9' { i += 1 }
		case (b >= 'a' && b <= 'z') || (b >= 'A' && b <= 'Z'):
			kind = .Letter
			i += 1
		case b == '+':
			kind = .Plus
			i += 1
		case b == '-':
			kind = .Minus
			i += 1
		case i + len("−") <= len(src) && src[i:i + len("−")] == "−":
			kind = .Minus
			i += len("−")
		case b == '*':
			kind = .Star
			i += 1
		case b == '=':
			kind = .Equals
			i += 1
		case b == '(':
			kind = .Left_Paren
			depth += 1
			i += 1
		case b == ')':
			kind = .Right_Paren
			depth -= 1
			if depth < 0 { return {}, .Unbalanced_Parens }
			i += 1
		case: return {}, .Unexpected_Character
		}
		if out.count >= len(out.items) { return {}, .Too_Many_Nodes }
		out.items[out.count] = {
			kind = kind,
			span = {start, i},
		}
		out.count += 1
	}
	if out.count == 0 { return {}, .Empty }
	if depth != 0 { return {}, .Unbalanced_Parens }
	if out.count >= len(out.items) { return {}, .Too_Many_Nodes }
	out.items[out.count] = {
		kind = .End,
		span = {len(src), len(src)},
	}
	out.count += 1
	return out, .None
}
