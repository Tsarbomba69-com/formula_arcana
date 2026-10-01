package main_menu

import rl "vendor:raylib"

Game_State :: enum {
	Menu,
	Playing,
	Options,
	Quit,
}

Button :: struct {
	rect:   rl.Rectangle,
	text:   string,
	action: Game_State,
	// TODO: Add more button properties if needed (e.g., hover state, icon, font, etc.)
}

Menu_State :: struct {
	buttons: [3]Button,
	// TODO: Add more menu state variables if needed (e.g., selected button index, etc.)
}
