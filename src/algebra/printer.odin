package algebra

@(private = "package")
Writer :: struct {
	buf: []u8,
	n:   int,
}

@(private = "package")
w_str :: proc(w: ^Writer, s: string) {
	for i in 0 ..< len(s) {
		if w.n < len(w.buf) {
			w.buf[w.n] = s[i]
			w.n += 1
		}
	}
}

@(private = "package")
w_byte :: proc(w: ^Writer, b: u8) {
	if w.n < len(w.buf) {
		w.buf[w.n] = b
		w.n += 1
	}
}

@(private = "package")
w_int :: proc(w: ^Writer, v: i64) {
	tmp: [24]u8
	w_str(w, alg_int_str(v, &tmp))
}

// Signed, with U+2212 for negatives.
@(private = "package")
w_signed :: proc(w: ^Writer, v: i64) {
	if v < 0 { w_str(w, MINUS) }
	w_int(w, abs(v))
}

@(private = "package")
w_text :: proc(w: ^Writer) -> string {
	return string(w.buf[:w.n])
}

@(private = "package")
alg_int_str :: proc(v: i64, tmp: ^[24]u8) -> string {
	if v == 0 { return "0" }
	n := abs(v)
	i := len(tmp)
	for n > 0 {
		i -= 1
		tmp[i] = u8('0' + n % 10)
		n /= 10
	}
	if v < 0 {
		i -= 1
		tmp[i] = '-'
	}
	return string(tmp[i:])
}
// ============================================================================
// Printing
// ============================================================================

@(private = "package")
alg_print_side :: proc(eq: ^Equation, id: Expr_Id, w: ^Writer) {
	list: Sum_List
	alg_collect(eq, id, false, &list)
	for t, i in list.items[:list.count] {
		neg := alg_term_negative(eq, t)
		if i == 0 {
			if neg { w_str(w, MINUS) }
		} else {
			w_str(w, neg ? " − " : " + ")
		}
		alg_print_mag(eq, t.node, w)
	}
}

// Prints a term WITHOUT its sign.
@(private = "package")
alg_print_mag :: proc(eq: ^Equation, id: Expr_Id, w: ^Writer) {
	switch n in alg_node(eq, id) {
	case nil:
	case Num: w_int(w, abs(n.value))
	case Var: w_byte(w, n.name)
	case Bin:
		if n.op != .Mul {
			w_str(w, "(")
			alg_print_side(eq, id, w)
			w_str(w, ")")
			return
		}
		l, r := alg_node(eq, n.left), alg_node(eq, n.right)
		if a, ok := l.(Num); ok {
			mag := abs(a.value)
			_, r_var := r.(Var)
			r_sum := alg_is_sum(r)
			if mag == 1 && (r_var || r_sum) {
				alg_print_factor(eq, n.right, w) // 1x → x, 1(x + 2) → (x + 2)
			} else if rn, ok2 := r.(Num); ok2 {
				w_int(w, mag)
				w_str(w, " × ")
				w_int(w, abs(rn.value))
			} else {
				w_int(w, mag)
				alg_print_factor(eq, n.right, w)
			}
		} else {
			alg_print_factor(eq, n.left, w)
			alg_print_factor(eq, n.right, w)
		}
	}
}

@(private = "package")
alg_print_factor :: proc(eq: ^Equation, id: Expr_Id, w: ^Writer) {
	alg_print_mag(eq, id, w) // sums get their parentheses inside alg_print_mag
}

// Canonical text: spaces around + − =, tight parentheses, coefficient 1 omitted, U+2212 minus.
// The result aliases `buf`.
format_equation :: proc(eq: Equation, buf: []u8) -> string {
	eq := eq
	if eq.count == 0 { return "" }
	w := Writer {
		buf = buf,
	}
	alg_print_side(&eq, eq.lhs, &w)
	w_str(&w, " = ")
	alg_print_side(&eq, eq.rhs, &w)
	return w_text(&w)
}

format_side :: proc(eq: Equation, side: Side, buf: []u8) -> string {
	eq := eq
	if eq.count == 0 { return "" }
	w := Writer {
		buf = buf,
	}
	alg_print_side(&eq, side == .Left ? eq.lhs : eq.rhs, &w)
	return w_text(&w)
}
@(private = "package")
w_term :: proc(w: ^Writer, t: Term, name: u8) {
	if t.has_var {
		if t.coef != 1 { w_signed(w, t.coef) }
		if t.coef == -1 { w_str(w, MINUS) }
		w_byte(w, name)
	} else {
		w_signed(w, t.coef)
	}
}

describe_move :: proc(eq: Equation, m: Move) -> (view: Move_View) {
	eq := eq
	name := alg_eq_name(&eq)
	buf: [LABEL_CAP * 2]u8
	w := Writer {
		buf = buf[:],
	}

	// ---- title ----
	switch m.kind {
	case .Distribute:
		w_str(&w, "Distribute ")
		w_signed(&w, m.operand.coef)
	case .Combine_Constants: w_str(&w, "Combine constants")
	case .Combine_Like_Terms: w_str(&w, "Combine like terms")
	case .Add_To_Both:
		w_str(&w, "Add ")
		w_term(&w, m.operand, name)
	case .Subtract_From_Both:
		w_str(&w, "Subtract ")
		w_term(&w, m.operand, name)
	case .Divide_Both:
		w_str(&w, "Divide by ")
		w_signed(&w, m.operand.coef)
	case .Multiply_Both:
		w_str(&w, "Multiply by ")
		w_signed(&w, m.operand.coef)
	case .Apply_Function: switch m.operand.coef {
			case 2: w_str(&w, "Square both sides")
			case: w_str(&w, "Apply function to both sides")
			}
	}
	label_set(&view.action, w_text(&w))
	w.n = 0
	if m.kind == .Distribute {
		w_str(&w, "Distributive property")
		label_set(&view.title, w_text(&w))
	} else {
		label_set(&view.title, label_str(&view.action))
	}
	w.n = 0
	switch m.kind {
	case .Distribute:
		w_str(&w, DISTRIBUTIVE_ADDITION_RULE)
		label_set(&view.rule, w_text(&w))
		w.n = 0
		w_str(&w, DISTRIBUTIVE_SUBTRACTION_RULE)
		label_set(&view.rule_2, w_text(&w))
	case .Combine_Constants: w_str(&w, "a + b = c")
	case .Combine_Like_Terms: w_str(&w, "ax + bx = (a + b)x")
	case .Add_To_Both: w_str(&w, "a = b  →  a + c = b + c")
	case .Subtract_From_Both: w_str(&w, "a = b  →  a − c = b − c")
	case .Divide_Both: w_str(&w, "a = b  →  a ÷ c = b ÷ c")
	case .Multiply_Both: w_str(&w, "a = b  →  a × c = b × c")
	case .Apply_Function: w_str(&w, "a = b  →  f(a) = f(b)")
	}
	if m.kind != .Distribute { label_set(&view.rule, w_text(&w)) }

	// ---- heading ----
	w.n = 0
	switch m.kind {
	case .Distribute:
		w_str(&w, "AFTER DISTRIBUTING ")
		w_signed(&w, m.operand.coef)
	case .Combine_Constants: w_str(&w, "AFTER COMBINING CONSTANTS")
	case .Combine_Like_Terms: w_str(&w, "AFTER COMBINING LIKE TERMS")
	case .Add_To_Both:
		w_str(&w, "AFTER ADDING ")
		w_term(&w, m.operand, name)
	case .Subtract_From_Both:
		w_str(&w, "AFTER SUBTRACTING ")
		w_term(&w, m.operand, name)
	case .Divide_Both:
		w_str(&w, "AFTER DIVIDING BY ")
		w_signed(&w, m.operand.coef)
	case .Multiply_Both:
		w_str(&w, "AFTER MULTIPLYING BY ")
		w_signed(&w, m.operand.coef)
	case .Apply_Function: w_str(&w, "AFTER APPLYING FUNCTION")
	}
	label_set(&view.heading, w_text(&w))

	// ---- hint ----
	side_word := m.side == .Left ? "left" : "right"
	w.n = 0
	switch m.kind {
	case .Distribute:
		w_str(&w, "Multiply ")
		w_signed(&w, m.operand.coef)
		w_str(&w, " into each term in the brackets.")
	case .Combine_Constants:
		w_str(&w, "Merge the constants on the ")
		w_str(&w, side_word)
		w_str(&w, ".")
	case .Combine_Like_Terms:
		w_str(&w, "Merge the like terms on the ")
		w_str(&w, side_word)
		w_str(&w, ".")
	case .Add_To_Both, .Subtract_From_Both: if m.operand.has_var {
				w_str(&w, "Cancel the variable on the ")
				w_str(&w, side_word)
				w_str(&w, ".")
			} else if m.side == .Left {
				w_str(&w, "Remove the constant on the left.")
			} else {
				w_str(&w, "Move the right-hand constant.")
			}
	case .Divide_Both: w_str(&w, "Divide both sides by the coefficient.")
	case .Multiply_Both: w_str(&w, "Multiply both sides by the factor.")
	case .Apply_Function: w_str(&w, "Apply the transformation to both sides.")
	}
	label_set(&view.hint, w_text(&w))

	// ---- preview (raw, unsimplified) ----
	w.n = 0
	switch m.kind {
	case .Distribute, .Combine_Constants, .Combine_Like_Terms:
		if result, ok := alg_perform(&eq, m); ok {
				out: [LABEL_CAP * 2]u8
				w_str(&w, format_equation(result, out[:]))
			}
	case .Add_To_Both, .Subtract_From_Both, .Divide_Both, .Multiply_Both:
		op: string
		switch m.kind {
		case .Add_To_Both: op = " + "
		case .Subtract_From_Both: op = " − "
		case .Divide_Both: op = " ÷ "
		case .Multiply_Both: op = " × "
		case .Distribute, .Combine_Constants, .Combine_Like_Terms, .Apply_Function:
		}
		for side in Side {
			out: [LABEL_CAP]u8
			w_str(&w, format_side(eq, side, out[:]))
			w_str(&w, op)
			if m.kind == .Divide_Both || m.kind == .Multiply_Both {
				w_signed(&w, m.operand.coef)
			} else {
				w_term(&w, m.operand, name)
			}
			if side == .Left { w_str(&w, " = ") }
		}
	case .Apply_Function: if result, ok := alg_perform(&eq, m); ok {
				out: [LABEL_CAP * 2]u8
				w_str(&w, format_equation(result, out[:]))
			}
	}
	label_set(&view.preview, w_text(&w))
	return
}

// "3(x − 4) becomes 3x − 12." / "−12 + 8 becomes −4."  (history card notes)
explain_move :: proc(eq: Equation, m: Move) -> (note: Label) {
	eq := eq
	name := alg_eq_name(&eq)
	buf: [LABEL_CAP * 2]u8
	w := Writer {
		buf = buf[:],
	}

	switch m.kind {
	case .Distribute:
		info := alg_analyze(&eq, m.side)
		for t in info.items[:info.count] {
			if t.node != m.target || t.kind != .Group { continue }
			original := Spec {
				kind = .Node,
				src  = t.node,
				neg  = t.neg,
			}
			alg_specs_text(&eq, {original}, &w)
			w_str(&w, " becomes ")
			expanded := alg_expand_group(&eq, t)
			alg_specs_text(&eq, expanded.items[:expanded.count], &w)
			w_str(&w, ".")
		}

	case .Combine_Constants, .Combine_Like_Terms:
		kind: Spec_Kind = m.kind == .Combine_Constants ? .Const : .Var
		specs := alg_side_specs(&eq, m.side)
		picked: Spec_List
		for s in specs.items[:specs.count] {
			if s.kind == kind { spec_push(&picked, s) }
		}
		alg_specs_text(&eq, picked.items[:picked.count], &w)
		w_str(&w, " becomes ")
		combined := alg_combine(picked, kind, name)
		alg_specs_text(&eq, combined.items[:combined.count], &w)
		w_str(&w, ".")

	case .Add_To_Both:
		w_str(&w, "Added ")
		w_term(&w, m.operand, name)
		w_str(&w, " to both sides.")
	case .Subtract_From_Both:
		w_str(&w, "Subtracted ")
		w_term(&w, m.operand, name)
		w_str(&w, " from both sides.")
	case .Divide_Both:
		w_str(&w, "Divided both sides by ")
		w_signed(&w, m.operand.coef)
		w_str(&w, ".")
	case .Multiply_Both:
		w_str(&w, "Multiplied both sides by ")
		w_signed(&w, m.operand.coef)
		w_str(&w, ".")
	case .Apply_Function: w_str(&w, "Applied function to both sides.")
	}
	label_set(&note, w_text(&w))
	return
}
