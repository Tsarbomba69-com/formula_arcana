package algebra

Solver_Status :: enum {
	Solved,
	Search_Not_Implemented,
}

Solver_Result :: struct {
	status: Solver_Status,
	moves:  Move_List,
}

// solve reports an equation that already meets its target. Planning rewrite
// sequences is intentionally left for a later implementation.
solve :: proc(start, target: Equation) -> Solver_Result {
	if is_solved(start, target) {
		return {status = .Solved}
	}
	return {status = .Search_Not_Implemented}
}
