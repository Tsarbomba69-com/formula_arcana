package platform

import "../shared"
import "base:runtime"
import rl "vendor:raylib"

// Font_Manager handles loading, storing, and unloading font assets safely.
Font_Manager :: struct {
	fonts:     map[shared.Font_Id]rl.Font,
	next_id:   u32,
	allocator: runtime.Allocator,
}

// init_font_manager allocates and initializes an empty font manager.
init_font_manager :: proc(allocator := context.allocator) -> Font_Manager {
	return Font_Manager {
		fonts = make(map[shared.Font_Id]rl.Font, 8, allocator),
		next_id = 1,
		allocator = allocator,
	}
}

destroy_font_manager :: proc(manager: ^Font_Manager) {
	for _, font in manager.fonts {
		rl.UnloadFont(font)
	}
	delete(manager.fonts)
}

load_font_from_file :: proc(
	manager: ^Font_Manager,
	filepath: cstring,
	base_size: i32 = 64, // Rasterize at a crisp high resolution (e.g., 64px) so scaling down looks sharp
) -> (
	shared.Font_Id,
	bool,
) {
	ray_font := rl.LoadFontEx(filepath, base_size, nil, 0)
	if ray_font.texture.id == 0 {
		return shared.INVALID_FONT_ID, false
	}

	rl.SetTextureFilter(ray_font.texture, .BILINEAR)
	id := shared.Font_Id(manager.next_id)
	manager.next_id += 1
	manager.fonts[id] = ray_font

	return id, true
}

// get_font retrieves the underlying raylib font for text measurement and rendering.
get_font :: proc(manager: ^Font_Manager, id: shared.Font_Id) -> (rl.Font, bool) {
	return manager.fonts[id]
}
