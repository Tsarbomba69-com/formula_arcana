package platform

import "../shared"
import "base:runtime"
import "core:strings"
import rl "vendor:raylib"

Font_Key :: struct {
	filepath:  string,
	base_size: i32,
}

// Font_Manager handles loading, storing, and unloading font assets safely.
Font_Manager :: struct {
	fonts:     map[shared.Font_Id]rl.Font,
	font_keys: map[Font_Key]shared.Font_Id,
	next_id:   u32,
	allocator: runtime.Allocator,
}

STAR_GLYPHS :: [?]i32 {
	0x2605, // ★
	0x2606, // ☆
}

// init_font_manager allocates and initializes an empty font manager.
init_font_manager :: proc(allocator := context.allocator) -> Font_Manager {
	return Font_Manager {
		fonts = make(map[shared.Font_Id]rl.Font, 8, allocator),
		font_keys = make(map[Font_Key]shared.Font_Id, 8, allocator),
		next_id = 1,
		allocator = allocator,
	}
}

destroy_font_manager :: proc(manager: ^Font_Manager) {
	for _, font in manager.fonts {
		rl.UnloadFont(font)
	}
	for key, _ in manager.font_keys {
		delete(key.filepath, manager.allocator)
	}
	delete(manager.fonts)
	delete(manager.font_keys)
}

load_font_from_file :: proc(
	manager: ^Font_Manager,
	filepath: cstring,
	base_size: i32 = 64, // Rasterize at a crisp high resolution (e.g., 64px) so scaling down looks sharp
) -> (
	shared.Font_Id,
	bool,
) {
	key := Font_Key {
		filepath  = string(filepath),
		base_size = base_size,
	}
	if id, ok := manager.font_keys[key]; ok {
		return id, true
	}

	codepoints := make([dynamic]rune, context.temp_allocator)
	// Standard printable ASCII
	for r in 32 ..= 126 {
		append(&codepoints, rune(r))
	}
	// Star rating glyphs (supported by latinmodern-math.ttf)
	append(&codepoints, '−') // U+2212 MINUS SIGN
	append(&codepoints, '★') // U+2605
	append(&codepoints, '☆') // U+2606

	ray_font := rl.LoadFontEx(filepath, base_size, raw_data(codepoints), i32(len(codepoints)))
	if ray_font.texture.id == 0 {
		return shared.INVALID_FONT_ID, false
	}

	rl.SetTextureFilter(ray_font.texture, .BILINEAR)
	id := shared.Font_Id(manager.next_id)
	manager.next_id += 1
	manager.fonts[id] = ray_font
	stored_path, err := strings.clone(key.filepath, manager.allocator)
	if err != nil {
		rl.UnloadFont(ray_font)
		delete_key(&manager.fonts, id)
		return shared.INVALID_FONT_ID, false
	}
	key.filepath = stored_path
	manager.font_keys[key] = id

	return id, true
}

// get_font retrieves the underlying raylib font for text measurement and rendering.
get_font :: proc(manager: ^Font_Manager, id: shared.Font_Id) -> (rl.Font, bool) {
	return manager.fonts[id]
}
