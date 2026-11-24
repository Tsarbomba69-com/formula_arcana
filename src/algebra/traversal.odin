package algebra

@(private = "package")
alg_node :: proc(eq: ^Equation, id: Expr_Id) -> Expr_Node {
	if id < 0 || int(id) >= eq.count { return nil }
	return eq.nodes[id]
}

@(private = "package")
alg_new :: proc(eq: ^Equation, n: Expr_Node) -> Expr_Id {
	if eq.count >= MAX_NODES {
		eq.overflow = true
		return NO_EXPR
	}
	eq.nodes[eq.count] = n
	eq.count += 1
	return Expr_Id(eq.count - 1)
}

@(private = "package")
alg_is_sum :: proc(n: Expr_Node) -> bool {
	b, ok := n.(Bin)
	return ok && b.op != .Mul
}

@(private = "package")
alg_eq_name :: proc(eq: ^Equation) -> u8 {
	for i in 0 ..< eq.count {
		if v, ok := eq.nodes[i].(Var); ok { return v.name }
	}
	return 'x'
}

// ---- Additive-term flattening -----------------------------------------------------

@(private = "package")
Sum_Term :: struct {
	node: Expr_Id,
	neg:  bool, // sign contributed by the surrounding − operators
}

@(private = "package")
Sum_List :: struct {
	items:    [MAX_TERMS]Sum_Term,
	count:    int,
	overflow: bool,
}

@(private = "package")
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
@(private = "package")
alg_intrinsic_neg :: proc(eq: ^Equation, id: Expr_Id) -> bool {
	#partial switch n in alg_node(eq, id) {
	case Num: return n.value < 0
	case Bin: if n.op == .Mul {
				if a, ok := alg_node(eq, n.left).(Num); ok { return a.value < 0 }
			}
	}
	return false
}

@(private = "package")
alg_term_negative :: proc(eq: ^Equation, t: Sum_Term) -> bool {
	return t.neg != alg_intrinsic_neg(eq, t.node)
}
