package algebra

@(private = "package")
Term_Kind :: enum {
	Const,
	Var,
	Group, // k(…) with a simple sum inside — distributable
	Other, // anything the engine does not understand → no moves
}

@(private = "package")
Term_Info :: struct {
	node:  Expr_Id, // the additive term's node
	kind:  Term_Kind,
	value: i64, // signed constant / signed coefficient / signed multiplier
	name:  u8, // variable letter (0 for constants)
	inner: Expr_Id, // Group: the sum inside the brackets
	neg:   bool, // final sign in the sum
}

@(private = "package")
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
@(private = "package")
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

@(private = "package")
Side_Info :: struct {
	items: [MAX_TERMS]Term_Info,
	count: int,
	ok:    bool, // every term understood
}

@(private = "package")
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
