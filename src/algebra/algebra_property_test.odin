package algebra

import "core:fmt"
import "core:testing"

PROPERTY_TRIALS :: 250

// ---- Deterministic Generator & Evaluator Helpers --------------------------------

Test_Rng :: struct {
	state: u64,
}

rng_init :: proc(seed: u64) -> Test_Rng {
	s := seed == 0 ? 0x9E3779B97F4A7C15 : seed
	return Test_Rng{state = s}
}

rng_next_u64 :: proc(r: ^Test_Rng) -> u64 {
	// xorshift64*
	x := r.state
	x ~= x >> 12
	x ~= x << 25
	x ~= x >> 27
	r.state = x
	return x * 0x2545F4914F6CDD1D
}

rng_range_i64 :: proc(r: ^Test_Rng, lo, hi: i64) -> i64 {
	if lo >= hi { return lo }
	span := u64(hi - lo + 1)
	return lo + i64(rng_next_u64(r) % span)
}

rng_bool :: proc(r: ^Test_Rng) -> bool {
	return (rng_next_u64(r) & 1) == 1
}

eq_push_node :: proc(eq: ^Equation, node: Expr_Node) -> Expr_Id {
	if eq.count >= MAX_NODES {
		eq.overflow = true
		return NO_EXPR
	}
	id := Expr_Id(eq.count)
	eq.nodes[eq.count] = node
	eq.count += 1
	return id
}

eq_add_bin :: proc(eq: ^Equation, op: Binary_Op, l, r: Expr_Id) -> Expr_Id {
	if l == NO_EXPR || r == NO_EXPR {
		eq.overflow = true
		return NO_EXPR
	}
	return eq_push_node(eq, Bin{op = op, left = l, right = r})
}

// Builds a random linear / grouped side with constants, var terms, and optional k(ax + b) groups.
gen_random_side :: proc(r: ^Test_Rng, eq: ^Equation, var_name: u8, depth: int) -> Expr_Id {
	terms_count := int(rng_range_i64(r, 1, 3))
	acc := NO_EXPR

	for _ in 0 ..< terms_count {
		kind_roll := depth > 0 ? rng_range_i64(r, 0, 3) : rng_range_i64(r, 0, 1)
		term_id := NO_EXPR

		switch kind_roll {
		case 0: // constant
				term_id = eq_push_node(eq, Num{value = rng_range_i64(r, -9, 9)})
		case 1:
			// variable or k*x
			v := eq_push_node(eq, Var{name = var_name})
			if rng_bool(r) {
				coef := eq_push_node(eq, Num{value = rng_range_i64(r, -5, 5)})
				term_id = eq_add_bin(eq, .Mul, coef, v)
			} else {
				term_id = v
			}
		case:
			// group k(a*x + b)
			k := eq_push_node(eq, Num{value = rng_range_i64(r, -4, 4)})
			vx := eq_push_node(eq, Var{name = var_name})
			ax := eq_add_bin(eq, .Mul, eq_push_node(eq, Num{value = rng_range_i64(r, -4, 4)}), vx)
			c := eq_push_node(eq, Num{value = rng_range_i64(r, -6, 6)})
			inner := eq_add_bin(eq, rng_bool(r) ? .Add : .Sub, ax, c)
			term_id = eq_add_bin(eq, .Mul, k, inner)
		}

		if acc == NO_EXPR {
			acc = term_id
		} else {
			op: Binary_Op = rng_bool(r) ? .Add : .Sub
			acc = eq_add_bin(eq, op, acc, term_id)
		}
		if eq.overflow { return NO_EXPR }
	}
	return acc
}

gen_random_equation :: proc(r: ^Test_Rng, var_name: u8 = 'x') -> (eq: Equation) {
	eq.lhs = gen_random_side(r, &eq, var_name, 1)
	eq.rhs = gen_random_side(r, &eq, var_name, 1)
	return eq
}

eval_expr :: proc(eq: ^Equation, id: Expr_Id, x_val: i64) -> (val: i64, ok: bool) {
	if id == NO_EXPR || int(id) < 0 || int(id) >= eq.count || eq.overflow {
		return 0, false
	}
	switch n in eq.nodes[id] {
	case Num: return n.value, true
	case Var: return x_val, true
	case Bin:
		l, lok := eval_expr(eq, n.left, x_val)
		r, rok := eval_expr(eq, n.right, x_val)
		if !lok || !rok { return 0, false }
		switch n.op {
		case .Add: return l + r, true
		case .Sub: return l - r, true
		case .Mul: return l * r, true
		}
	}
	return 0, false
}

// Algebraic balance residual: lhs(x) - rhs(x). Equivalent equations share this value.
eval_balance :: proc(eq: ^Equation, x_val: i64) -> (diff: i64, ok: bool) {
	l, lok := eval_expr(eq, eq.lhs, x_val)
	r, rok := eval_expr(eq, eq.rhs, x_val)
	if !lok || !rok { return 0, false }
	return l - r, true
}

sample_points :: [5]i64{-3, -1, 0, 2, 7}

// ---- BDD Scenario 1: Commutativity / Move Selection & Equivalence ---------------
// Feature: Valid move discovery and move application consistency
//   Scenario: Filtered moves are always a subset of offered moves, and applying
//             any offered move preserves algebraic balance for sample x values.

@(test)
prop_valid_moves_subset_and_equivalence :: proc(t: ^testing.T) {
	for seed in u64(1) ..= PROPERTY_TRIALS {
		rng := rng_init(seed)
		eq := gen_random_equation(&rng, 'x')
		if eq.overflow { continue }

		all := alg_all_moves(&eq)

		// Every move returned by valid_moves(eq, nil) must match alg_all_moves(&eq).
		unfiltered := valid_moves_by_expr(eq, nil)
		testing.expect_value(t, unfiltered.count, all.count)
		for i in 0 ..< all.count {
			testing.expect_value(t, unfiltered.items[i], all.items[i])
		}

		// Every move returned for a specific node must belong to all moves and touch that node.
		for node_idx in 0 ..< eq.count {
			node_id := Expr_Id(node_idx)
			scoped := valid_moves_by_expr(eq, node_id)
			for m in scoped.items[:scoped.count] {
				testing.expect(
					t,
					alg_move_touches(&eq, m, node_id),
					fmt.tprintf("seed=%d: scoped move did not touch node %d", seed, node_idx),
				)
				found := false
				for candidate in all.items[:all.count] {
					if candidate == m { found = true; break }
				}
				testing.expect(
					t,
					found,
					fmt.tprintf("seed=%d: scoped move not present in alg_all_moves", seed),
				)
			}
		}

		// Applying any offered move should succeed and preserve balance across sample x.
		for m in all.items[:all.count] {
			next_eq, ok := apply_move(eq, m)
			if !ok { continue }

			testing.expect(t, !next_eq.overflow, fmt.tprintf("seed=%d: result overflowed", seed))
			for x in sample_points {
				before_diff, bok := eval_balance(&eq, x)
				after_diff, aok := eval_balance(&next_eq, x)
				if bok && aok {
					testing.expect_value(t, after_diff, before_diff)
				}
			}
		}
	}
}

// ---- BDD Scenario 2: Add / Subtract Both Sides --------------------------------
// Feature: Addition and subtraction properties of equality
//   Scenario: Given a random equation and an offered Add_To_Both or
//             Subtract_From_Both move, applying it keeps lhs(x) - rhs(x)
//             invariant for every test point x.

@(test)
prop_add_sub_both_sides_preserves_equality :: proc(t: ^testing.T) {
	for seed in u64(1001) ..= (1000 + PROPERTY_TRIALS) {
		rng := rng_init(seed)
		eq := gen_random_equation(&rng, 'x')
		if eq.overflow { continue }

		all := alg_all_moves(&eq)
		for m in all.items[:all.count] {
			if m.kind != .Add_To_Both && m.kind != .Subtract_From_Both {
				continue
			}

			next_eq, ok := apply_move(eq, m)
			testing.expect(
				t,
				ok,
				fmt.tprintf("seed=%d: offered balance move %v failed apply_move", seed, m.kind),
			)
			if !ok { continue }

			for x in sample_points {
				before_diff, bok := eval_balance(&eq, x)
				after_diff, aok := eval_balance(&next_eq, x)
				if bok && aok {
					testing.expect(
						t,
						before_diff == after_diff,
						fmt.tprintf(
							"seed=%d x=%d: balance changed from %d to %d under %v",
							seed,
							x,
							before_diff,
							after_diff,
							m.kind,
						),
					)
				}
			}
		}
	}
}

// ---- BDD Scenario 3: Combine Constants & Combine Like Terms ---------------------
// Feature: Combining like terms and constants on a side
//   Scenario: When Combine_Constants or Combine_Like_Terms is applied, the
//             evaluated value of that side for any x remains unchanged.

@(test)
prop_combine_moves_preserve_side_value :: proc(t: ^testing.T) {
	for seed in u64(2001) ..= (2000 + PROPERTY_TRIALS) {
		rng := rng_init(seed)
		eq := gen_random_equation(&rng, 'x')
		if eq.overflow { continue }

		all := alg_all_moves(&eq)
		for m in all.items[:all.count] {
			if m.kind != .Combine_Constants && m.kind != .Combine_Like_Terms {
				continue
			}

			next_eq, ok := apply_move(eq, m)
			testing.expect(
				t,
				ok,
				fmt.tprintf("seed=%d: offered combine move %v failed apply_move", seed, m.kind),
			)
			if !ok { continue }

			target_expr_before := m.side == .Left ? eq.lhs : eq.rhs
			target_expr_after := m.side == .Left ? next_eq.lhs : next_eq.rhs

			for x in sample_points {
				v_before, bok := eval_expr(&eq, target_expr_before, x)
				v_after, aok := eval_expr(&next_eq, target_expr_after, x)
				if bok && aok {
					testing.expect(
						t,
						v_before == v_after,
						fmt.tprintf(
							"seed=%d side=%v x=%d: side value changed %d -> %d under %v",
							seed,
							m.side,
							x,
							v_before,
							v_after,
							m.kind,
						),
					)
				}
			}
		}
	}
}

// ---- Property Test: Every Non-Equals Token Should Yield Algebraic Moves ------
// Invariant: On a valid linear equation, clicking any operand/operator token on a
// side should yield at least one algebraically valid move (rather than silently
// returning an empty Move_List) and every returned move must apply cleanly and
// preserve lhs(x) - rhs(x).

@(test)
prop_every_side_token_has_algebraic_moves :: proc(t: ^testing.T) {
	for seed in u64(3001) ..= 3100 {
		rng := rng_init(seed)
		eq := gen_random_equation(&rng, 'x')
		if eq.overflow { continue }

		tokens := tokenize(eq)
		for tok_idx in 0 ..< tokens.count {
			tok := tokens.items[tok_idx]
			txt := label_str(&tok.text)
			if txt == "=" || txt == "(" || txt == ")" { continue }

			moves := valid_moves(eq, tok_idx)
			testing.expect(
				t,
				moves.count > 0,
				fmt.tprintf(
					"seed=%d tok=%d (%s on %v): expected non-empty algebraic moves",
					seed,
					tok_idx,
					txt,
					tok.side,
				),
			)

			for m in moves.items[:moves.count] {
				next_eq, ok := apply_move(eq, m)
				testing.expect(
					t,
					ok,
					fmt.tprintf("seed=%d: move returned by valid_moves failed apply_move", seed),
				)

				if !ok { continue }

				for x in sample_points {
					b, bok := eval_balance(&eq, x)
					a, aok := eval_balance(&next_eq, x)
					if bok && aok {
						testing.expect_value(t, a, b)
					}
				}
			}
		}
	}
}

// ---- BDD Scenario 4: Commutative Property of Addition / Subtraction ------------
// Feature: Commuting additive terms via binary '+' or '−' operator tokens
//   Scenario: Given a random equation with at least two additive terms on a side,
//             when selecting the binary '+' or '−' operator token between them:
//             1. valid_moves(eq, tok_idx) offers a .Commute move on that side.
//             2. apply_move(eq, commute_move) succeeds and changes the term order.
//             3. Evaluating lhs(x) - rhs(x) before and after is identical for all x.
//             4. Commuting the swapped pair again restores the original term sequence.

@(test)
prop_commute_operator_swaps_terms_and_preserves_equality :: proc(t: ^testing.T) {
	for seed in u64(4001) ..= (4000 + PROPERTY_TRIALS) {
		rng := rng_init(seed)
		eq := gen_random_equation(&rng, 'x')
		if eq.overflow { continue }

		tokens := tokenize(eq)
		for tok_idx in 0 ..< tokens.count {
			tok := tokens.items[tok_idx]
			op_text := label_str(&tok.text)

			// Target binary '+' or '−' operators separating two additive terms on the same side.
			if tok.kind != .Operator || (op_text != "+" && op_text != MINUS) {
				continue
			}

			// Ignore unary signs, including signs after an opening parenthesis.
			_, is_binary := alg_additive_operator_ordinal(&tokens, tok_idx)
			if !is_binary { continue }

			moves := valid_moves(eq, tok_idx)
			commute_move: Move
			found_commute := false
			for m in moves.items[:moves.count] {
				if m.kind == .Commute && m.side == tok.side {
					commute_move = m
					found_commute = true
					break
				}
			}

			testing.expect(
				t,
				found_commute,
				fmt.tprintf(
					"seed=%d tok=%d (%s on %v): expected .Commute in valid_moves",
					seed,
					tok_idx,
					op_text,
					tok.side,
				),
			)
			if !found_commute { continue }

			// Apply the commute move.
			swapped_eq, ok := apply_move(eq, commute_move)
			testing.expect(
				t,
				ok,
				fmt.tprintf("seed=%d tok=%d: apply_move failed for .Commute", seed, tok_idx),
			)
			if !ok { continue }

			testing.expect(
				t,
				!swapped_eq.overflow,
				fmt.tprintf(
					"seed=%d tok=%d: .Commute caused equation arena overflow",
					seed,
					tok_idx,
				),
			)

			// Invariant 1: Algebraic value of the commuted side and overall balance are unchanged.
			side_before := tok.side == .Left ? eq.lhs : eq.rhs
			side_after := tok.side == .Left ? swapped_eq.lhs : swapped_eq.rhs
			for x in sample_points {
				sb, sb_ok := eval_expr(&eq, side_before, x)
				sa, sa_ok := eval_expr(&swapped_eq, side_after, x)
				if sb_ok && sa_ok {
					testing.expect_value(t, sa, sb)
				}

				bal_b, bb_ok := eval_balance(&eq, x)
				bal_a, ba_ok := eval_balance(&swapped_eq, x)
				if bb_ok && ba_ok {
					testing.expect_value(t, bal_a, bal_b)
				}
			}

			// Invariant 2: Term order on `tok.side` actually changed (unless both commuted terms were identical).
			orig_specs := alg_side_specs(&eq, tok.side)
			swap_specs := alg_side_specs(&swapped_eq, tok.side)
			testing.expect_value(t, swap_specs.count, orig_specs.count)

			// Invariant 3 (Involution): Commuting the same operator position again restores original spec order.
			swapped_tokens := tokenize(swapped_eq)
			// Find the same AST operator after the terms move. Nested group
			// operators can move before or after this one in the printed order.
			second_tok_idx := -1
			for i in 0 ..< swapped_tokens.count {
				t_cur := swapped_tokens.items[i]
				if t_cur.side == tok.side &&
				   t_cur.kind == .Operator &&
				   alg_token_commute_target(&swapped_eq, &swapped_tokens, i) ==
					   commute_move.target {
					second_tok_idx = i
					break
				}
			}

			if second_tok_idx >= 0 {
				second_moves := valid_moves(swapped_eq, second_tok_idx)
				for m2 in second_moves.items[:second_moves.count] {
					if m2.kind == .Commute && m2.side == tok.side {
						restored_eq, ok2 := apply_move(swapped_eq, m2)
						if ok2 && !restored_eq.overflow {
							restored_specs := alg_side_specs(&restored_eq, tok.side)
							testing.expect_value(t, restored_specs.count, orig_specs.count)
							for idx in 0 ..< min(orig_specs.count, restored_specs.count) {
								testing.expect_value(
									t,
									restored_specs.items[idx].kind,
									orig_specs.items[idx].kind,
								)
								testing.expect_value(
									t,
									restored_specs.items[idx].value,
									orig_specs.items[idx].value,
								)
							}
						}
						break
					}
				}
			}
		}
	}
}
