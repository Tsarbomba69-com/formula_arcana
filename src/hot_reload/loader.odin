package hot_reload

import "core:dynlib"
import "core:fmt"
import "core:os"

Hot_Module :: struct {
	library: dynlib.Library,
	api:     ^Game_Module_API,
	state:   rawptr,
	path:    string,
}

@(private = "file")
g_module_serial: u64

snapshot_state :: proc(module: ^Hot_Module, allocator := context.temp_allocator) -> ([]u8, bool) {
	if module == nil || module.api == nil || module.state == nil do return nil, true
	length: u64
	if module.api.snapshot(module.state, {}, &length) == 0 || length > 16 * 1024 * 1024 {
		fmt.eprintln("hot_reload: active module could not snapshot its state")
		return nil, false
	}
	bytes := make([]u8, int(length), allocator)
	written: u64
	buffer := Byte_Buffer{data = raw_data(bytes), len = length}
	if module.api.snapshot(module.state, buffer, &written) == 0 || written != length {
		delete(bytes, allocator)
		fmt.eprintln("hot_reload: active module returned an invalid snapshot")
		return nil, false
	}
	return bytes, true
}

load_candidate :: proc(
	host: ^Host_API,
	active: ^Hot_Module,
	candidate_path: string,
	width, height: i32,
) -> bool {
	if host == nil || candidate_path == "" do return false
	snapshot, snapshot_ok := snapshot_state(active)
	if !snapshot_ok do return false
	defer delete(snapshot)

	g_module_serial += 1
	active_path := fmt.aprintf("bin/debug/game_module_active_%d.%s", g_module_serial, dynlib.LIBRARY_FILE_EXTENSION)
	if err := os.copy_file(active_path, candidate_path); err != nil {
		fmt.eprintln("hot_reload: could not stage candidate:", err)
		delete(active_path, context.allocator)
		return false
	}
	lib, ok := dynlib.load_library(active_path)
	if !ok {
		fmt.eprintln("hot_reload: candidate library failed to load:", dynlib.last_error())
		_ = os.remove(active_path)
		delete(active_path, context.allocator)
		return false
	}
	symbol, found := dynlib.symbol_address(lib, "game_module_api_v1")
	if !found {
		fmt.eprintln("hot_reload: candidate is missing game_module_api_v1")
		dynlib.unload_library(lib)
		_ = os.remove(active_path)
		delete(active_path, context.allocator)
		return false
	}
	entry := cast(Game_Module_API_Proc)symbol
	api := entry()
	if api == nil || api.abi_version != ABI_VERSION || api.struct_size < size_of(Game_Module_API) ||
	   api.initialize == nil || api.update == nil || api.draw == nil || api.snapshot == nil || api.shutdown == nil {
		fmt.eprintln("hot_reload: candidate module API is invalid")
		dynlib.unload_library(lib)
		_ = os.remove(active_path)
		delete(active_path, context.allocator)
		return false
	}
	state := api.initialize(host, width, height, Byte_Buffer{data = raw_data(snapshot), len = u64(len(snapshot))})
	if state == nil {
		fmt.eprintln("hot_reload: candidate failed to restore state")
		dynlib.unload_library(lib)
		_ = os.remove(active_path)
		delete(active_path, context.allocator)
		return false
	}

	previous := active^
	active^ = Hot_Module{library = lib, api = api, state = state, path = active_path}
	if previous.api != nil {
		previous.api.shutdown(previous.state)
		dynlib.unload_library(previous.library)
		_ = os.remove(previous.path)
		delete(previous.path, context.allocator)
	}
	fmt.println("hot_reload: game module activated")
	return true
}

unload_game_module :: proc(module: ^Hot_Module) {
	if module == nil do return
	if module.api != nil && module.state != nil do module.api.shutdown(module.state)
	if module.library != dynlib.Library(nil) do dynlib.unload_library(module.library)
	if module.path != "" {
		_ = os.remove(module.path)
		delete(module.path, context.allocator)
	}
	module^ = {}
}
