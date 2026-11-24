package algebra

import "core:testing"

@(test)
given_subtracting_a_variable_when_same_text_tokens_survive_then_rewritten_terms_still_map :: proc(
	t: ^testing.T,
) {
	source := parse_ok(t, "3x = 2x + 21")
	moves := valid_moves(source)
	testing.expect(t, moves.count > 0, "the equation should offer a balancing move")
	if moves.count == 0 { return }

	result, ok := apply_move(source, moves.items[0])
	testing.expect(t, ok, "the first balancing move should apply")
	if !ok { return }
	mapping := move_animation_map(source, result, moves.items[0])
	source_tokens, result_tokens := tokenize(source), tokenize(result)

	left_source_maps := false
	right_source_maps := false
	for pair in mapping.pairs[:mapping.count] {
		from := source_tokens.items[pair.source_token]
		to := result_tokens.items[pair.destination_token]
		if label_str(&from.text) == "x" && label_str(&to.text) == "x" && to.side == .Left {
			if from.side == .Left { left_source_maps = true }
			if from.side == .Right { right_source_maps = true }
		}
	}
	testing.expect(
		t,
		left_source_maps,
		"the changed left variable term should map to the result x",
	)
	testing.expect(
		t,
		right_source_maps,
		"the cancelled right variable term should map to the result x",
	)
}
