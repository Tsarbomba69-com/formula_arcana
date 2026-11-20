package platform

import "../shared"
import "base:runtime"
import "core:strings"
import rl "vendor:raylib"

// Texture_Manager handles loading, storing, and unloading GPU texture assets safely.
Texture_Manager :: struct {
	textures:     map[shared.Texture_Id]rl.Texture2D,
	texture_keys: map[string]shared.Texture_Id,
	next_id:      u32,
	allocator:    runtime.Allocator,
}

// init_texture_manager allocates and initializes an empty texture manager.
// Caller assumes ownership and must call destroy_texture_manager to avoid leaks.
init_texture_manager :: proc(allocator := context.allocator) -> Texture_Manager {
	return Texture_Manager {
		textures = make(map[shared.Texture_Id]rl.Texture2D, 16, allocator),
		texture_keys = make(map[string]shared.Texture_Id, 16, allocator),
		next_id = 1,
		allocator = allocator,
	}
}

// destroy_texture_manager unloads all active GPU textures and frees container memory.
destroy_texture_manager :: proc(manager: ^Texture_Manager) {
	for _, tex in manager.textures {
		rl.UnloadTexture(tex)
	}
	for key, _ in manager.texture_keys {
		delete(key, manager.allocator)
	}

	delete(manager.textures)
	delete(manager.texture_keys)
}

// load_texture_from_file loads an image file from disk via Raylib, registers it, and returns a Texture_Id.
load_texture_from_file :: proc(
	manager: ^Texture_Manager,
	filepath: cstring,
) -> (
	shared.Texture_Id,
	bool,
) {
	key := string(filepath)
	if id, ok := manager.texture_keys[key]; ok {
		return id, true
	}

	ray_tex := rl.LoadTexture(filepath)
	if ray_tex.id == 0 {
		return shared.INVALID_TEXTURE_ID, false
	}

	id := shared.Texture_Id(manager.next_id)
	manager.next_id += 1
	manager.textures[id] = ray_tex
	stored_path, err := strings.clone(key, manager.allocator)
	if err != nil {
		rl.UnloadTexture(ray_tex)
		delete_key(&manager.textures, id)
		return shared.INVALID_TEXTURE_ID, false
	}
	manager.texture_keys[stored_path] = id

	return id, true
}

// get_texture retrieves the underlying raylib texture for rendering use.
get_texture :: proc(manager: ^Texture_Manager, id: shared.Texture_Id) -> (rl.Texture2D, bool) {
	tex, ok := manager.textures[id]
	return tex, ok
}
