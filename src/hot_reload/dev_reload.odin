package hot_reload

import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"

// Polling file watcher for the development build. It watches source trees and
// build.sh, debounces editor writes, and runs the configured build command.
// A successful build is reported to the caller so the host can activate the
// staged module at its next frame boundary.
Dev_Reload_Config :: struct {
	build_command:    []string,
	source_roots:     []string,
	poll_interval:    time.Duration,
	debounce:         time.Duration,
	last_scan:        time.Tick,
	last_change:      time.Tick,
	last_fingerprint: u64,
	initialized:      bool,
	pending:          bool,
}

Dev_Reloader :: struct {
	config: Dev_Reload_Config,
}

make_dev_reloader :: proc(
	build_command: []string = {"bash", "build.sh", "module"},
	allocator := context.allocator,
) -> Dev_Reloader {
	r: Dev_Reloader
	r.config.build_command = make([]string, len(build_command), allocator)
	for part, i in build_command {
		copy, err := strings.clone(part, allocator)
		if err != nil { return {} }
		r.config.build_command[i] = copy
	}
	r.config.source_roots = make([]string, 2, allocator)
	r.config.source_roots[0], _ = strings.clone("src", allocator)
	r.config.source_roots[1], _ = strings.clone("build.sh", allocator)
	r.config.poll_interval = 250 * time.Millisecond
	r.config.debounce = 400 * time.Millisecond
	return r
}

destroy_dev_reloader :: proc(r: ^Dev_Reloader, allocator := context.allocator) {
	if r == nil { return }
	delete(r.config.build_command, allocator)
	for root in r.config.source_roots { delete(root, allocator) }
	delete(r.config.source_roots, allocator)
	r^ = {}
}

// Returns true when any watched file is added, removed, or modified. The
// fingerprint combines relative paths, sizes, and nanosecond modification
// times, so creating and deleting files also triggers a rebuild.
scan_sources :: proc(roots: []string) -> u64 {
	fingerprint: u64 = 14695981039346656037
	for root in roots {
		if info, err := os.stat(root, context.temp_allocator); err == nil {
			if info.type == .Directory {
				fingerprint = scan_directory(root, fingerprint)
			} else {
				fingerprint = hash_file_info(info, fingerprint)
			}
			os.file_info_delete(info, context.temp_allocator)
		}
	}
	return fingerprint
}

scan_directory :: proc(path: string, hash: u64) -> u64 {
	result, err := os.read_all_directory_by_path(path, context.temp_allocator)
	if err != nil { return hash }
	defer os.file_info_slice_delete(result, context.temp_allocator)
	mut_hash := hash
	for info in result {
		if info.name == ".git" || info.name == "bin" { continue }
		if info.type == .Directory {
			mut_hash = scan_directory(info.fullpath, mut_hash)
		} else if watched_extension(info.name) {
			mut_hash = hash_file_info(info, mut_hash)
		}
	}
	return mut_hash
}

hash_file_info :: proc(info: os.File_Info, hash: u64) -> u64 {
	result := hash
	for b in info.fullpath { result = (result ~ u64(b)) * 1099511628211 }
	result = (result ~ u64(info.size)) * 1099511628211
	result = (result ~ u64(info.modification_time._nsec)) * 1099511628211
	return result
}

watched_extension :: proc(name: string) -> bool {
	return(
		strings.has_suffix(name, ".odin") ||
		strings.has_suffix(name, ".sh") ||
		strings.has_suffix(name, ".json") \
	)
}

// Returns true only when the build command succeeds. Output is forwarded to
// the console for diagnostics; no active runtime state is changed here.
run_build_command :: proc(command: []string) -> bool {
	if len(command) == 0 { return false }
	state, stdout, stderr, err := os.process_exec(
		os.Process_Desc{command = command},
		context.temp_allocator,
	)
	defer delete(stdout, context.temp_allocator)
	defer delete(stderr, context.temp_allocator)
	if len(stdout) > 0 { fmt.print(string(stdout)) }
	if len(stderr) > 0 { fmt.eprint(string(stderr)) }
	if err != nil {
		fmt.eprintln("hot_reload: could not start build command:", err)
		return false
	}
	if !state.exited || !state.success || state.exit_code != 0 {
		fmt.println("hot_reload: build failed; active code remains in use")
		return false
	}
	return true
}

// Call once per frame on the host thread. The initial call records a baseline
// and does not build. Changes are coalesced until the debounce interval has
// elapsed. Returns true after a successful build, for frame-boundary module
// activation by the host.
dev_reload_tick :: proc(r: ^Dev_Reloader) -> bool {
	if r == nil { return false }
	now := time.tick_now()
	if !r.config.initialized {
		r.config.last_fingerprint = scan_sources(r.config.source_roots)
		r.config.last_scan = now
		r.config.initialized = true
		return false
	}
	if time.tick_diff(r.config.last_scan, now) >= r.config.poll_interval {
		r.config.last_scan = now
		fingerprint := scan_sources(r.config.source_roots)
		if fingerprint != r.config.last_fingerprint {
			r.config.last_fingerprint = fingerprint
			r.config.last_change = now
			r.config.pending = true
		}
	}
	if !r.config.pending || time.tick_diff(r.config.last_change, now) < r.config.debounce {
		return false
	}
	r.config.pending = false
	fmt.println("hot_reload: source change detected; building candidate")
	return run_build_command(r.config.build_command)
}
