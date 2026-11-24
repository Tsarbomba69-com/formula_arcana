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

// Builds animation provenance from the terms a move actually rewrites. Unlike
// text matching, this keeps a same-looking token when its owning term changed.
move_animation_map :: proc(source, result: Equation, move: Move) -> (mapping: Move_Animation_Map) {
	wanted: Term_Kind
	#partial switch move.kind {
	case .Combine_Constants: wanted = .Const
	case .Combine_Like_Terms: wanted = .Var
	case .Add_To_Both, .Subtract_From_Both: wanted = move.operand.has_var ? .Var : .Const
	case: return
	}

	source_eq, result_eq := source, result
	source_sides, result_sides: [2]Side_Info
	for side in Side {
		source_sides[side] = alg_analyze(&source_eq, side)
		result_sides[side] = alg_analyze(&result_eq, side)
	}

	for side in Side {
		if (move.kind == .Combine_Constants || move.kind == .Combine_Like_Terms) &&
		   side != move.side {
			continue
		}
		destination_term := NO_EXPR
		for term in result_sides[side].items[:result_sides[side].count] {
			if term.kind == wanted {
				destination_term = term.node
				break
			}
		}
		if destination_term == NO_EXPR &&
		   (move.kind == .Add_To_Both || move.kind == .Subtract_From_Both) {
			other_side := side == .Left ? Side.Right : Side.Left
			for term in result_sides[other_side].items[:result_sides[other_side].count] {
				if term.kind == wanted {
					destination_term = term.node
					break
				}
			}
		}
		if destination_term == NO_EXPR { continue }
		destination_token := alg_animation_term_token(&result_eq, destination_term, side, wanted)
		if destination_token < 0 {
			other_side := side == .Left ? Side.Right : Side.Left
			destination_token = alg_animation_term_token(
				&result_eq,
				destination_term,
				other_side,
				wanted,
			)
		}
		if destination_token < 0 { continue }

		for term in source_sides[side].items[:source_sides[side].count] {
			if term.kind != wanted { continue }
			source_token := alg_animation_term_token(&source_eq, term.node, side, wanted)
			if source_token < 0 { continue }
			if mapping.count < len(mapping.pairs) {
				mapping.pairs[mapping.count] = {source_token, destination_token}
				mapping.count += 1
			}
		}
	}
	return
}

@(private = "package")
alg_animation_term_token :: proc(
	eq: ^Equation,
	term: Expr_Id,
	side: Side,
	kind: Term_Kind,
) -> int {
	tokens := tokenize(eq^)
	for i in 0 ..< tokens.count {
		token := tokens.items[i]
		if token.term != term || token.side != side { continue }
		if kind == .Const && token.kind == .Constant { return i }
		if kind == .Var && token.kind == .Variable { return i }
	}
	return -1
}
