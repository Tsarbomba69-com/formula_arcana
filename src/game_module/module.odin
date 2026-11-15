package main

import "../core"
import "../features"
import "../hot_reload"
import "../shared"
import "base:runtime"
import "core:strings"

MODULE_STATE_VERSION :: 1

Game_State :: struct {
	ctx:    features.Context,
	screen: features.Screen_State,
}

@(private = "file")
g_host: ^hot_reload.Host_API
g_api: hot_reload.Game_Module_API

host_load_texture :: proc(path: cstring) -> (shared.Texture_Id, bool) {
	id := g_host.load_texture(g_host.user_data, path)
	return shared.Texture_Id(id), id != 0
}

host_load_font :: proc(path: cstring, size: i32) -> (shared.Font_Id, bool) {
	id := g_host.load_font(g_host.user_data, path, size)
	return shared.Font_Id(id), id != 0
}

module_measure_text :: proc(
	text: string,
	size: i32,
	font_id: shared.Font_Id = shared.INVALID_FONT_ID,
) -> f32 {
	cstr := strings.clone_to_cstring(text, context.temp_allocator)
	return g_host.measure_text(g_host.user_data, cstr, size, u32(font_id))
}

module_draw_text :: proc(
	text: string,
	pos: shared.Vec2,
	size: i32,
	color: shared.Color,
	font_id: shared.Font_Id = shared.INVALID_FONT_ID,
) {
	cstr := strings.clone_to_cstring(text, context.temp_allocator)
	g_host.draw_text(
		g_host.user_data,
		cstr,
		pos.x,
		pos.y,
		size,
		color[0],
		color[1],
		color[2],
		color[3],
		u32(font_id),
	)
}

module_fill_rect :: proc(rect: shared.Rect, color: shared.Color) {
	g_host.fill_rect(
		g_host.user_data,
		rect.x,
		rect.y,
		rect.w,
		rect.h,
		color[0],
		color[1],
		color[2],
		color[3],
	)
}

module_outline_rect :: proc(rect: shared.Rect, thickness: f32, color: shared.Color) {
	g_host.outline_rect(
		g_host.user_data,
		rect.x,
		rect.y,
		rect.w,
		rect.h,
		thickness,
		color[0],
		color[1],
		color[2],
		color[3],
	)
}

module_draw_texture :: proc(id: shared.Texture_Id, rect: shared.Rect, tint: shared.Color) {
	g_host.draw_texture(
		g_host.user_data,
		u32(id),
		rect.x,
		rect.y,
		rect.w,
		rect.h,
		tint[0],
		tint[1],
		tint[2],
		tint[3],
	)
}

noop_begin :: proc() {  }
noop_end :: proc() {  }
noop_clear :: proc(color: shared.Color) {  }

module_renderer :: proc() -> shared.Renderer {
	return {
		begin_frame = noop_begin,
		end_frame = noop_end,
		clear = noop_clear,
		measure_text = module_measure_text,
		draw_text = module_draw_text,
		fill_rect = module_fill_rect,
		outline_rect = module_outline_rect,
		draw_texture = module_draw_texture,
	}
}

@(private)
game_initialize :: proc "c" (
	host: ^hot_reload.Host_API,
	width, height: i32,
	snapshot: hot_reload.Byte_Buffer,
) -> rawptr {
	context = runtime.default_context()
	if host == nil ||
	   host.abi_version != hot_reload.ABI_VERSION ||
	   host.struct_size < size_of(hot_reload.Host_API) { return nil }
	g_host = host
	state := new(Game_State)
	state.ctx = {
		config       = core.default_config(),
		viewport     = shared.viewport_of(width, height),
		renderer     = module_renderer(),
		load_texture = host_load_texture,
		load_font    = host_load_font,
	}
	navigation: core.Navigation = core.Go_Main_Menu{}
	if snapshot.data != nil && snapshot.len >= 8 {
		words := ([^]u32)(snapshot.data)
		if words[0] == MODULE_STATE_VERSION {
			switch words[1] {
			case 1: navigation = core.Go_Level_Select {
						difficulty = .Standard,
					}
			case 2: navigation = core.Go_Archives{}
			case 3: navigation = core.Go_Settings {
						tab = .Audio,
					}
			}
		}
	}
	state.screen = features.enter(navigation, &state.ctx)
	return rawptr(state)
}

@(private)
game_update :: proc "c" (raw_state: rawptr, events: ^hot_reload.Hot_Event, count: u64) {
	context = runtime.default_context()
	if raw_state == nil { return }
	state := (^Game_State)(raw_state)
	event_array := ([^]hot_reload.Hot_Event)(events)
	for i in 0 ..< int(count) {
		event := event_array[i]
		switch event.kind {
		case hot_reload.EVENT_WINDOW_RESIZED:
			state.ctx.viewport = shared.viewport_of(event.width, event.height)
			features.resize_screen(&state.screen, &state.ctx)
		case hot_reload.EVENT_MOUSE_INPUT:
			core_events := []core.Event {
				shared.Mouse_Input {
					position = {event.x, event.y},
					pressed = event.flags & hot_reload.EVENT_FLAG_PRESSED != 0,
					released = event.flags & hot_reload.EVENT_FLAG_RELEASED != 0,
				},
			}
			if navigation := features.update_screen(&state.screen, core_events);
			   navigation != nil {
				state.screen = features.enter(navigation, &state.ctx)
			}
		case hot_reload.EVENT_KEY_INPUT:
			key: shared.Nav_Key
			switch event.key {
			case hot_reload.KEY_UP: key = .Up
			case hot_reload.KEY_DOWN: key = .Down
			case hot_reload.KEY_CONFIRM: key = .Confirm
			case hot_reload.KEY_BACK: key = .Back
			}
			core_events := []core.Event{shared.Key_Input{key}}
			if navigation := features.update_screen(&state.screen, core_events);
			   navigation != nil {
				state.screen = features.enter(navigation, &state.ctx)
			}
		}
	}
}

@(private)
game_draw :: proc "c" (raw_state: rawptr) {
	context = runtime.default_context()
	if raw_state == nil { return }
	state := (^Game_State)(raw_state)
	features.draw_screen(&state.screen, state.ctx)
}

@(private)
game_snapshot :: proc "c" (
	raw_state: rawptr,
	destination: hot_reload.Byte_Buffer,
	bytes_written: ^u64,
) -> u32 {
	if raw_state == nil || bytes_written == nil { return 0 }
	bytes_written^ = 8
	if destination.data == nil && destination.len == 0 { return 1 }
	if destination.data == nil || destination.len < 8 { return 0 }
	state := (^Game_State)(raw_state)
	words := ([^]u32)(destination.data)
	words[0] = MODULE_STATE_VERSION
	switch screen in state.screen {
	case features.Menu_State: words[1] = 0
	case features.Level_Select_State: words[1] = 1
	case features.Archives_State: words[1] = 2
	case features.Settings_State: words[1] = 3
	case: words[1] = 0
	}
	return 1
}

@(private)
game_shutdown :: proc "c" (raw_state: rawptr) {
	context = runtime.default_context()
	if raw_state == nil { return }
	free((^Game_State)(raw_state))
}

@(export, link_name = "game_module_api_v1")
game_module_api_v1 :: proc "c" () -> ^hot_reload.Game_Module_API {
	g_api = hot_reload.Game_Module_API {
		abi_version = hot_reload.ABI_VERSION,
		struct_size = u32(size_of(hot_reload.Game_Module_API)),
		initialize  = game_initialize,
		update      = game_update,
		draw        = game_draw,
		snapshot    = game_snapshot,
		shutdown    = game_shutdown,
	}
	return &g_api
}
