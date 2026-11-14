package main

import "core"
import "core:dynlib"
import "core:log"
import "base:runtime"
import "hot_reload"
import "platform"
import "shared"

WINDOW_W :: 1280
WINDOW_H :: 720
MODULE_CANDIDATE :: "bin/debug/game_module_candidate." + dynlib.LIBRARY_FILE_EXTENSION

Host_State :: struct {
	tex_mgr:  platform.Texture_Manager,
	font_mgr: platform.Font_Manager,
	renderer: shared.Renderer,
}

Game :: struct {
	events:     core.Event_Channel,
	host_state: Host_State,
	host_api:   hot_reload.Host_API,
	module:     hot_reload.Hot_Module,
	reloader:   hot_reload.Dev_Reloader,
}

host_log :: proc "c" (user_data: rawptr, message: cstring) {
	context = runtime.default_context()
	log.info(string(message))
}

host_load_texture :: proc "c" (user_data: rawptr, path: cstring) -> u32 {
	context = runtime.default_context()
	state := (^Host_State)(user_data)
	id, ok := platform.load_texture_from_file(&state.tex_mgr, path)
	return ok ? u32(id) : 0
}

host_load_font :: proc "c" (user_data: rawptr, path: cstring, size: i32) -> u32 {
	context = runtime.default_context()
	state := (^Host_State)(user_data)
	id, ok := platform.load_font_from_file(&state.font_mgr, path, size)
	return ok ? u32(id) : 0
}

host_measure_text :: proc "c" (user_data: rawptr, text: cstring, size: i32, font_id: u32) -> f32 {
	context = runtime.default_context()
	state := (^Host_State)(user_data)
	return state.renderer.measure_text(string(text), size, shared.Font_Id(font_id))
}

host_draw_text :: proc "c" (
	user_data: rawptr,
	text: cstring,
	x, y: f32,
	size: i32,
	r, g, b, a: u8,
	font_id: u32,
) {
	context = runtime.default_context()
	state := (^Host_State)(user_data)
	state.renderer.draw_text(string(text), {x, y}, size, {r, g, b, a}, shared.Font_Id(font_id))
}

host_fill_rect :: proc "c" (
	user_data: rawptr,
	x, y, width, height: f32,
	r, g, b, a: u8,
) {
	context = runtime.default_context()
	state := (^Host_State)(user_data)
	state.renderer.fill_rect({x, y, width, height}, {r, g, b, a})
}

host_outline_rect :: proc "c" (
	user_data: rawptr,
	x, y, width, height, thickness: f32,
	r, g, b, a: u8,
) {
	context = runtime.default_context()
	state := (^Host_State)(user_data)
	state.renderer.outline_rect({x, y, width, height}, thickness, {r, g, b, a})
}

host_draw_texture :: proc "c" (
	user_data: rawptr,
	texture_id: u32,
	x, y, width, height: f32,
	r, g, b, a: u8,
) {
	context = runtime.default_context()
	state := (^Host_State)(user_data)
	state.renderer.draw_texture(shared.Texture_Id(texture_id), {x, y, width, height}, {r, g, b, a})
}

init_host :: proc(app: ^Game) {
	app.host_state.tex_mgr = platform.init_texture_manager()
	app.host_state.font_mgr = platform.init_font_manager()
	app.host_state.renderer = platform.raylib_renderer(&app.host_state.tex_mgr, &app.host_state.font_mgr)
	app.host_api = {
		abi_version = hot_reload.ABI_VERSION,
		struct_size = u32(size_of(hot_reload.Host_API)),
		user_data = rawptr(&app.host_state),
		log = host_log,
		load_texture = host_load_texture,
		load_font = host_load_font,
		measure_text = host_measure_text,
		draw_text = host_draw_text,
		fill_rect = host_fill_rect,
		outline_rect = host_outline_rect,
		draw_texture = host_draw_texture,
	}
	app.reloader = hot_reload.make_dev_reloader()
}

shutdown_host :: proc(app: ^Game) {
	hot_reload.unload_game_module(&app.module)
	hot_reload.destroy_dev_reloader(&app.reloader)
	platform.destroy_texture_manager(&app.host_state.tex_mgr)
	platform.destroy_font_manager(&app.host_state.font_mgr)
}

collect_events :: proc(app: ^Game) -> []hot_reload.Hot_Event {
	platform.poll_events(&app.events)
	result := make([dynamic]hot_reload.Hot_Event, 0, context.temp_allocator)
	for event in core.poll(&app.events) {
		#partial switch e in event {
		case core.Window_Resized:
			append(&result, hot_reload.Hot_Event{kind = hot_reload.EVENT_WINDOW_RESIZED, width = e.width, height = e.height})
		case shared.Mouse_Input:
			flags: u32
			if e.pressed do flags |= hot_reload.EVENT_FLAG_PRESSED
			if e.released do flags |= hot_reload.EVENT_FLAG_RELEASED
			append(&result, hot_reload.Hot_Event{kind = hot_reload.EVENT_MOUSE_INPUT, flags = flags, x = e.position.x, y = e.position.y})
		case shared.Key_Input:
			key: u32
			switch e.key {
			case .Up: key = hot_reload.KEY_UP
			case .Down: key = hot_reload.KEY_DOWN
			case .Confirm: key = hot_reload.KEY_CONFIRM
			case .Back: key = hot_reload.KEY_BACK
			}
			append(&result, hot_reload.Hot_Event{kind = hot_reload.EVENT_KEY_INPUT, key = key})
		}
	}
	return result[:]
}

main :: proc() {
	context.logger = log.create_console_logger()
	defer log.destroy_console_logger(context.logger)
	platform.open_window(WINDOW_W, WINDOW_H, "Formula Arcana")
	defer platform.close_window()

	app: Game
	init_host(&app)
	defer shutdown_host(&app)
	if !hot_reload.load_candidate(&app.host_api, &app.module, MODULE_CANDIDATE, WINDOW_W, WINDOW_H) {
		log.error("Could not load initial game module")
		return
	}

	width, height: i32 = WINDOW_W, WINDOW_H
	for !platform.should_close() {
		free_all(context.temp_allocator)
		events := collect_events(&app)
		for event in events {
			if event.kind == hot_reload.EVENT_WINDOW_RESIZED {
				width, height = event.width, event.height
			}
		}
		app.module.api.update(app.module.state, raw_data(events), u64(len(events)))
		app.host_state.renderer.begin_frame()
		app.host_state.renderer.clear({24, 28, 36, 255})
		app.module.api.draw(app.module.state)
		app.host_state.renderer.end_frame()

		if hot_reload.dev_reload_tick(&app.reloader) {
			_ = hot_reload.load_candidate(&app.host_api, &app.module, MODULE_CANDIDATE, width, height)
		}
	}
}
