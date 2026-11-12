package shared

// Texture_Id uniquely identifies a loaded GPU texture asset.
Texture_Id :: distinct u32

// INVALID_TEXTURE_ID represents an unassigned or missing texture reference.
INVALID_TEXTURE_ID :: Texture_Id(0)
