package features

import "../core"
import "core:fmt"
import "core:math"

// ============================================================================
// PHASE 1 CONTRACT — text formatting for the top bar and panel captions.
// All results alias `buf`.
// ============================================================================

Run_Info :: struct {
	mode:         string, // "ARCANE TRIALS"
	tier:         core.Difficulty,
	round:        int, // 1-based
	rounds_total: int,
	score:        int,
	streak:       int,
}

format_mode_tag :: proc(run: Run_Info, buf: []u8) -> string {
	return fmt.bprintf(buf, "%s / %v", run.mode, run.tier)
}

format_round :: proc(run: Run_Info, buf: []u8) -> string {
	return fmt.bprintf(buf, "ROUND %02d / %d", run.round, run.rounds_total)
}

format_progress :: proc(run: Run_Info, buf: []u8) -> string {
	frac := progress_fraction(run)
	pct := int(math.round(f32(frac) * 100.0))
	return fmt.bprintf(buf, "%d%%", pct)
}

progress_fraction :: proc(run: Run_Info) -> f32 {
	if run.rounds_total <= 0 { return 0.0 }
	val := f32(run.round) / f32(run.rounds_total)
	if val < 0.0 { return 0.0 }
	if val > 1.0 { return 1.0 }
	return val
}

format_score :: proc(score: int, buf: []u8) -> string {
	// Formats as 5-digit zero-padded with thousands comma separator (e.g., "04,280")
	s := math.abs(score)
	thousands := s / 1000
	remainder := s % 1000
	sign := score < 0 ? "-" : ""
	return fmt.bprintf(buf, "%s%02d,%03d", sign, thousands, remainder)
}

format_streak :: proc(streak: int, buf: []u8) -> string {
	return fmt.bprintf(buf, "× %d", streak)
}

format_time :: proc(seconds: f32, buf: []u8) -> string {
	total_secs := int(math.max(0.0, seconds))
	// Cap the timer display at 99 minutes and 59 seconds (5,999 seconds)
	max_secs := 99 * 60 + 59
	if total_secs > max_secs {
		total_secs = max_secs
	}

	mins := total_secs / 60
	secs := total_secs % 60
	return fmt.bprintf(buf, "%02d:%02d", mins, secs)
}

format_step :: proc(step: int, buf: []u8) -> string {
	return fmt.bprintf(buf, "STEP %02d", step)
}

format_index :: proc(n: int, buf: []u8) -> string {
	return fmt.bprintf(buf, "%02d", n)
}

format_move_count :: proc(moves: int, buf: []u8) -> string {
	if moves == 1 {
		return fmt.bprintf(buf, "1 MOVE")
	}
	return fmt.bprintf(buf, "%d MOVES", moves)
}

format_valid_moves :: proc(count: int, term_selected: bool, buf: []u8) -> string {
	suffix := term_selected ? " · selected term" : " · whole equation"
	if count == 1 {
		return fmt.bprintf(buf, "1 valid move%s", suffix)
	}
	return fmt.bprintf(buf, "%d valid moves%s", count, suffix)
}
