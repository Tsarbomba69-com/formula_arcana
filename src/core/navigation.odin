package core

// What a screen can ask the app to do. One union case per destination:
// the payload lives INSIDE the case, so target and payload can't disagree.
// Payloads carry only what the *caller* knows. Data that already has an
// owner (config, save data) is read by the destination, not copied through.

Difficulty :: enum {
	Easy,
	Standard,
	Hard,
}

Settings_Tab :: enum {
	Audio,
	Graphics,
}

Go_Main_Menu :: struct {}
Go_Level_Select :: struct {
	difficulty: Difficulty,
}
Go_Archives :: struct {}
Go_Settings :: struct {
	tab: Settings_Tab,
}

Navigation :: union {
	Go_Main_Menu,
	Go_Level_Select,
	Go_Archives,
	Go_Settings,
}
