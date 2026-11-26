package algebra

@(private = "package")
Spec_Kind :: enum {
	Const,
	Var,
	Node, // copy a term subtree from the source equation (a group we do not expand)
}

@(private = "package")
Spec :: struct {
	kind:  Spec_Kind,
	value: i64, // Const / Var: signed constant or coefficient
	name:  u8,
	src:   Expr_Id, // Node: term in the source equation
	neg:   bool, // Node: final sign in the sum
}

@(private = "package")
Spec_List :: struct {
	items: [MAX_TERMS * 2]Spec,
	count: int,
}

@(private = "package")
spec_push :: proc(l: ^Spec_List, s: Spec) {
	if l.count >= len(l.items) { return }
	l.items[l.count] = s
	l.count += 1
}

@(private = "package")
spec_negative :: proc(s: Spec) -> bool {
	return s.kind == .Node ? s.neg : s.value < 0
}

@(private = "package")
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
@(private = "package")
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
@(private = "package")
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

@(private = "package")
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
@(private = "package")
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

@(private = "package")
alg_assemble :: proc(src: ^Equation, l, r: []Spec) -> (out: Equation, ok: bool) {
	out.lhs = alg_build_side(&out, src, l)
	out.rhs = alg_build_side(&out, src, r)
	return out, !out.overflow
}

// Text of a standalone sum of specs ("−12 + 8").
@(private = "package")
alg_specs_text :: proc(src: ^Equation, specs: []Spec, w: ^Writer) {
	tmp: Equation
	root := alg_build_side(&tmp, src, specs)
	alg_print_side(&tmp, root, w)
}

// var terms first, then the constant; zero terms vanish; an empty side becomes 0.
@(private = "package")
alg_normalize :: proc(specs: []Spec, name: u8) -> (out: Spec_List) {
	var_total, const_total: i64
	for s in specs {
		if s.kind == .Var { var_total += s.value }
		if s.kind == .Const { const_total += s.value }
	}
	if var_total != 0 { spec_push(&out, Spec{kind = .Var, value = var_total, name = name}) }
	if const_total != 0 { spec_push(&out, Spec{kind = .Const, value = const_total}) }
	for s in specs {
		if s.kind == .Node { spec_push(&out, s) }
	}
	if out.count == 0 { spec_push(&out, Spec{kind = .Const, value = 0}) }
	return
}

// Replaces all specs of `kind` with their sum, placed where the first one was.
@(private = "package")
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

@(private = "package")
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
@(private = "package")
alg_perform :: proc(eq: ^Equation, m: Move) -> (out: Equation, ok: bool) {
	name := alg_eq_name(eq)
	left, right := alg_side_specs(eq, .Left), alg_side_specs(eq, .Right)

	#partial switch m.kind {
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

	case .Commute:
		root := m.side == .Left ? eq.lhs : eq.rhs
		chain_root := alg_commute_chain_root(eq, root, m.target)
		if chain_root == NO_EXPR { return eq^, false }
		pair_index := 0
		if !alg_commute_chain_ordinal(eq, chain_root, m.target, &pair_index) { return eq^, false }
		return eq^, alg_swap_commute_pair(eq, m.side, chain_root, pair_index)

	case .Multiply_Both, .Apply_Function: return eq^, false // player requests go through apply_transformation

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
	if !offered { offered = alg_is_contextual_balance_move(&eq, m) }
	if !offered { offered = alg_is_contextual_commute_move(&eq, m) }
	if !offered { return eq, false }
	out, built := alg_perform(&eq, m)
	if !built { return eq, false }
	return out, true
}

@(private = "package")
alg_is_contextual_balance_move :: proc(eq: ^Equation, m: Move) -> bool {
	if m.kind != .Add_To_Both && m.kind != .Subtract_From_Both { return false }
	if m.target == NO_EXPR || m.operand.coef < 0 { return false }
	info := alg_analyze(eq, m.side)
	for t in info.items[:info.count] {
		if t.node != m.target || (t.kind != .Var && t.kind != .Const) { continue }
		if m.operand.has_var != (t.kind == .Var) || m.operand.coef != abs(t.value) { return false }
		if t.value < 0 && m.kind != .Add_To_Both { return false }
		if t.value > 0 && m.kind != .Subtract_From_Both { return false }
		return true
	}
	return false
}

// ============================================================================
// Player-chosen transformations: performing them.
// Unlike apply_move, nothing here checks the recommender (alg_all_moves).
// Replaces apply_scalar_to_both / apply_add_to_both / apply_subtract_from_both.
// ============================================================================

// Applies `t` to BOTH complete sides. On error the result carries `eq` unchanged.
apply_transformation :: proc(eq: Equation, t: Transformation) -> Transform_Result {
	unimplemented()
}

// "Add 5 to both sides", "Subtract 4 from both sides", "Multiply both sides by 0",
// "Divide both sides by 2", "Square both sides".
transformation_title :: proc(t: Transformation) -> Label {
	unimplemented()
}

// "equivalent", "not equivalent", "may introduce extra solutions".
equivalence_name :: proc(e: Equivalence) -> string {
	unimplemented()
}

// "" for Equivalent; otherwise a short player-facing warning, e.g. "Information was lost."
equivalence_warning :: proc(e: Equivalence) -> string {
	unimplemented()
}

// "" for .None; .Division_By_Zero -> "Division by zero is undefined."
move_error_message :: proc(err: Move_Error) -> string {
	unimplemented()
}
