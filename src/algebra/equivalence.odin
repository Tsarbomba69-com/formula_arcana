package algebra

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
