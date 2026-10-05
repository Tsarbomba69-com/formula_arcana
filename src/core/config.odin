package core

// Single source of truth for persisted data. Lives on the app, not in menu code.

// Value type (no slice, no allocation): bit N set == level N unlocked.
Level_Set :: bit_set[0 ..< 64;u64]

Progress :: struct {
	unlocked: Level_Set,
}

Audio_Settings :: struct {
	master_volume, music_volume, sfx_volume: f32,
	is_muted:                                bool,
}

Graphics_Settings :: struct {
	fullscreen: bool,
	resolution: [2]i32,
	vsync:      bool,
}

Config :: struct {
	audio:    Audio_Settings,
	graphics: Graphics_Settings,
}

default_config :: proc() -> Config {
	return {
		audio = {master_volume = 0.8, music_volume = 0.5, sfx_volume = 1.0},
		graphics = {fullscreen = false, resolution = {1280, 720}, vsync = true},
	}
}
