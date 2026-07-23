LeopardRP = LeopardRP or {}
LeopardRP.Modules = LeopardRP.Modules or {}
LeopardRP.Config = LeopardRP.Config or {}
LeopardRP.CharacterCreation = LeopardRP.CharacterCreation or {}

local fontsCreated = LeopardRP.CharacterCreation.FontsCreated == true
if fontsCreated then return end

-- Use guaranteed built-in fonts so clients without custom font packs do not spam fallback warnings.
local OKUDA_REGULAR = "Tahoma"
local OKUDA_BOLD = "Trebuchet MS"
local OKUDA_ITALIC = "Tahoma"
local OKUDA_BOLD_ITALIC = "Trebuchet MS"

local function createFont(name, family, size, weight, italic)
    surface.CreateFont(name, {
        font = family,
        size = size,
        weight = weight,
        italic = italic == true,
        antialias = true,
        extended = true
    })
end

-- LeopardRP names.
createFont("LeopardRP.Menu.Title", OKUDA_BOLD, 42, 800)
createFont("LeopardRP.Menu.Subtitle", OKUDA_REGULAR, 20, 500)
createFont("LeopardRP.Menu.Button", OKUDA_BOLD, 24, 700)
createFont("LeopardRP.Menu.Small", OKUDA_REGULAR, 16, 450)
createFont("LeopardRP.Menu.Micro", OKUDA_REGULAR, 12, 450)
createFont("LeopardRP.Menu.Panel", OKUDA_REGULAR, 18, 550)
createFont("LeopardRP.Menu.PanelBold", OKUDA_BOLD, 20, 800)
createFont("LeopardRP.Character.Title", OKUDA_BOLD, 30, 800)
createFont("LeopardRP.Character.Small", OKUDA_REGULAR, 15, 450)
createFont("LeopardRP.Character.RecordHeader", "Segoe UI Semibold", 24, 650)
createFont("LeopardRP.Character.RecordLabel", "Segoe UI Semibold", 12, 650)
createFont("LeopardRP.Character.RecordValue", "Segoe UI", 16, 450)
createFont("LeopardRP.Character.RecordBody", "Segoe UI", 15, 450)
createFont("LeopardRP.Character.RecordTiny", "Segoe UI", 13, 450)

-- Alias common Helix/UI names used by this schema to keep one family everywhere.
createFont("ixSmallFont", OKUDA_REGULAR, 16, 450)
createFont("ixMediumFont", OKUDA_REGULAR, 18, 550)
createFont("ixMenuTinyFont", OKUDA_REGULAR, 14, 450)
createFont("ixMenuMiniFont", OKUDA_REGULAR, 16, 500)
createFont("ixTitleFont", OKUDA_BOLD, 36, 800)
createFont("ixMenuButtonHugeFont", OKUDA_BOLD, 28, 800)

-- Replace Trebuchet calls used in ported UI with Okuda equivalents.
createFont("Trebuchet18", OKUDA_REGULAR, 18, 500)
createFont("Trebuchet24", OKUDA_BOLD, 24, 700)
createFont("Trebuchet24Italic", OKUDA_BOLD_ITALIC, 24, 700, true)
createFont("Trebuchet18Italic", OKUDA_ITALIC, 18, 500, true)

LeopardRP.CharacterCreation.FontsCreated = true