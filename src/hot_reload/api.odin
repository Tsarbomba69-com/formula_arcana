package hot_reload

// This file defines the v1 boundary between the stable application host and
// the reloadable game module.
//
// Keep this API independent of core, features, platform, and shared packages.
// Values crossing the boundary must use simple fixed-width fields, pointers,
// and C strings. Do not pass Odin-managed strings, slices, unions, maps,
// allocators, or game structs across this boundary.
//
// Both sides must be built for the same target and agree on this layout and
// calling convention. Increment ABI_VERSION when making an incompatible change.

ABI_VERSION :: 1

// Event tags.
EVENT_WINDOW_RESIZED :: 1
EVENT_MOUSE_INPUT :: 2
EVENT_KEY_INPUT :: 3

// Event flags.
EVENT_FLAG_PRESSED :: 1 << 0
EVENT_FLAG_RELEASED :: 1 << 1

// Navigation key values. These are ABI values, not core.Nav_Key values.
KEY_UP :: 1
KEY_DOWN :: 2
KEY_LEFT :: 3
KEY_RIGHT :: 4
KEY_CONFIRM :: 5
KEY_BACK :: 6

// A flat, ABI-safe representation of the current application's events.
//
// Fields not used by an event's kind are zero. For mouse events, x/y are
// window pixel coordinates. For resize events, width/height are pixel sizes.
Hot_Event :: struct {
	kind:   u32,
	flags:  u32,
	x, y:   f32,
	width:  i32,
	height: i32,
	key:    u32,
}

// A byte range used for opaque, versioned state snapshots.
// The module defines and versions the contents; the host only stores bytes.
Byte_Buffer :: struct {
	data: rawptr,
	len:  u64,
}

// Host-owned services available to the game module.
//
// The module may retain a copy of this table while it is active. The callbacks
// and user_data remain valid until the module is shut down.
Host_Log_Proc :: proc "c" (user_data: rawptr, message: cstring)

Host_Load_Texture_Proc :: proc "c" (user_data: rawptr, path: cstring) -> u32

Host_Load_Font_Proc :: proc "c" (user_data: rawptr, path: cstring, base_size: i32) -> u32

Host_Draw_Text_Proc :: proc "c" (
	user_data: rawptr,
	text: cstring,
	x, y: f32,
	font_size: i32,
	r, g, b, a: u8,
	font_id: u32,
)

Host_Measure_Text_Proc :: proc "c" (
	user_data: rawptr,
	text: cstring,
	font_size: i32,
	font_id: u32,
) -> f32

Host_Fill_Rect_Proc :: proc "c" (user_data: rawptr, x, y, width, height: f32, r, g, b, a: u8)

Host_Outline_Rect_Proc :: proc "c" (
	user_data: rawptr,
	x, y, width, height: f32,
	thickness: f32,
	r, g, b, a: u8,
)

Host_Draw_Texture_Proc :: proc "c" (
	user_data: rawptr,
	texture_id: u32,
	x, y, width, height: f32,
	r, g, b, a: u8,
)

Host_API :: struct {
	abi_version:  u32,
	struct_size:  u32,
	user_data:    rawptr,
	log:          Host_Log_Proc,
	load_texture: Host_Load_Texture_Proc,
	load_font:    Host_Load_Font_Proc,
	measure_text: Host_Measure_Text_Proc,
	draw_text:    Host_Draw_Text_Proc,
	fill_rect:    Host_Fill_Rect_Proc,
	outline_rect: Host_Outline_Rect_Proc,
	draw_texture: Host_Draw_Texture_Proc,
}

// Module entry points. The host resolves the exported
// `game_module_api_v1` procedure and validates this table before using it.
Module_Initialize_Proc :: proc "c" (
	host: ^Host_API,
	window_width: i32,
	window_height: i32,
	snapshot: Byte_Buffer,
) -> rawptr

Module_Update_Proc :: proc "c" (state: rawptr, events: ^Hot_Event, event_count: u64)

Module_Draw_Proc :: proc "c" (state: rawptr)

// Snapshot protocol:
// - First call with destination.data == nil and destination.len == 0 to query
//   the required byte count.
// - Call again with a host-owned buffer of that size to write the snapshot.
// - Return 1 on success, 0 on failure.
// - Set bytes_written on both calls.
// The host copies the completed snapshot before shutting down/unloading the
// old module.
Module_Snapshot_Proc :: proc "c" (
	state: rawptr,
	destination: Byte_Buffer,
	bytes_written: ^u64,
) -> u32

Module_Shutdown_Proc :: proc "c" (state: rawptr)

Game_Module_API :: struct {
	abi_version: u32,
	struct_size: u32,
	initialize:  Module_Initialize_Proc,
	update:      Module_Update_Proc,
	draw:        Module_Draw_Proc,
	snapshot:    Module_Snapshot_Proc,
	shutdown:    Module_Shutdown_Proc,
}

// Exported by the reloadable module in the next implementation unit.
Game_Module_API_Proc :: proc "c" () -> ^Game_Module_API
