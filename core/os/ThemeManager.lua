-- ThemeManager: loads JSON theme files, remaps the CC palette to exact hex
-- colors, and applies role mappings to PixelUI.
--
-- Palette slots are remapped globally via term.setPaletteColor so every draw
-- call using e.g. colors.green actually renders the theme's exact shade.
-- Call resetPalette() before handing control to games or the shell, and
-- restorePalette() when returning to the OS chrome.

local PixelUI = require("pixelui")

local ThemeManager = {}

local THEME_DIR     = "/core/data/themes/"
local SETTINGS_FILE = "/core/data/settings.json"

-- ── CC color name → constant ──────────────────────────────────────────────────

local COLOR_MAP = {
    white     = colors.white,
    orange    = colors.orange,
    magenta   = colors.magenta,
    lightBlue = colors.lightBlue,
    yellow    = colors.yellow,
    lime      = colors.lime,
    pink      = colors.pink,
    gray      = colors.gray,
    lightGray = colors.lightGray,
    cyan      = colors.cyan,
    purple    = colors.purple,
    blue      = colors.blue,
    brown     = colors.brown,
    green     = colors.green,
    red       = colors.red,
    black     = colors.black,
}

-- ── CC default palette (0-1 float RGB) ───────────────────────────────────────
-- Used by resetPalette() to restore remapped slots.

local CC_DEFAULTS = {
    [colors.white]     = {0xF0/255, 0xF0/255, 0xF0/255},
    [colors.orange]    = {0xF2/255, 0xB2/255, 0x33/255},
    [colors.magenta]   = {0xE5/255, 0x7F/255, 0xD8/255},
    [colors.lightBlue] = {0x99/255, 0xB2/255, 0xF2/255},
    [colors.yellow]    = {0xDE/255, 0xDE/255, 0x6C/255},
    [colors.lime]      = {0x7F/255, 0xCC/255, 0x19/255},
    [colors.pink]      = {0xF2/255, 0xB2/255, 0xCC/255},
    [colors.gray]      = {0x4C/255, 0x4C/255, 0x4C/255},
    [colors.lightGray] = {0x99/255, 0x99/255, 0x99/255},
    [colors.cyan]      = {0x4C/255, 0x99/255, 0xB2/255},
    [colors.purple]    = {0xB2/255, 0x66/255, 0xE5/255},
    [colors.blue]      = {0x33/255, 0x66/255, 0xCC/255},
    [colors.brown]     = {0x7F/255, 0x66/255, 0x4C/255},
    [colors.green]     = {0x57/255, 0xA6/255, 0x4E/255},
    [colors.red]       = {0xCC/255, 0x4C/255, 0x4C/255},
    [colors.black]     = {0x11/255, 0x11/255, 0x11/255},
}

-- ── Internal state ────────────────────────────────────────────────────────────

local activeThemeName = "pipboy"
local currentRawTheme = nil      -- raw JSON table of the active theme
local remappedSlots   = {}       -- color constants remapped by current theme

-- ── Utilities ─────────────────────────────────────────────────────────────────

local function hexToRGB(hex)
    hex = hex:gsub("^#", "")
    local r = tonumber(hex:sub(1, 2), 16) or 0
    local g = tonumber(hex:sub(3, 4), 16) or 0
    local b = tonumber(hex:sub(5, 6), 16) or 0
    return r / 255, g / 255, b / 255
end

local function readJSON(path)
    if not fs.exists(path) then return nil end
    local f = fs.open(path, "r")
    local raw = f.readAll()
    f.close()
    return textutils.unserialiseJSON(raw)
end

local function writeJSON(path, data)
    local f = fs.open(path, "w")
    f.write(textutils.serialiseJSON(data))
    f.close()
end

-- Recursively converts color name strings to CC color constants.
-- Hex strings are left alone (they don't map to a CC constant).
local function convertColors(tbl)
    local out = {}
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            out[k] = convertColors(v)
        elseif type(v) == "string" and COLOR_MAP[v] then
            out[k] = COLOR_MAP[v]
        else
            out[k] = v
        end
    end
    return out
end

-- ── Palette application ───────────────────────────────────────────────────────

local function applyPalette(rawTheme)
    remappedSlots = {}
    if not rawTheme.palette then return end
    if not term.setPaletteColor then return end

    for colorName, hex in pairs(rawTheme.palette) do
        local slot = COLOR_MAP[colorName]
        if slot and type(hex) == "string" then
            local r, g, b = hexToRGB(hex)
            term.setPaletteColor(slot, r, g, b)
            remappedSlots[#remappedSlots + 1] = slot
        end
    end
end

-- ── Public API ────────────────────────────────────────────────────────────────

--- Initialise: load the saved theme preference (or fall back to "pipboy").
function ThemeManager.init()
    local settings = readJSON(SETTINGS_FILE)
    local name = (settings and settings.theme) or "pipboy"
    ThemeManager.loadTheme(name)
end

--- Load and apply a theme by name. Returns true on success.
function ThemeManager.loadTheme(name)
    local path = THEME_DIR .. name .. ".json"
    local raw  = readJSON(path)
    if not raw then
        if name ~= "pipboy" then ThemeManager.loadTheme("pipboy") end
        return false
    end

    currentRawTheme = raw
    activeThemeName = name

    -- 1. Remap palette slots to the theme's exact hex colors
    applyPalette(raw)

    -- 2. Convert role strings to CC color constants and push to PixelUI
    local converted = convertColors(raw)
    PixelUI.setTheme(converted)

    return true
end

--- Returns the list of available theme names (sorted).
function ThemeManager.listThemes()
    if not fs.exists(THEME_DIR) then return {} end
    local names = {}
    for _, f in ipairs(fs.list(THEME_DIR)) do
        local name = f:match("^(.+)%.json$")
        if name then names[#names + 1] = name end
    end
    table.sort(names)
    return names
end

--- Returns the active theme name string.
function ThemeManager.getActive()
    return activeThemeName
end

--- Returns the converted CC-color theme table (for chrome drawing).
function ThemeManager.getColors()
    return PixelUI.getTheme()
end

--- Persist the theme preference to disk.
function ThemeManager.savePreference(name)
    writeJSON(SETTINGS_FILE, { theme = name })
end

--- Reset all palette slots remapped by the current theme back to CC defaults.
--- Call this before launching a game or returning to the MBS shell.
function ThemeManager.resetPalette()
    if not term.setPaletteColor then return end
    for _, slot in ipairs(remappedSlots) do
        local def = CC_DEFAULTS[slot]
        if def then
            term.setPaletteColor(slot, def[1], def[2], def[3])
        end
    end
end

--- Re-apply the current theme's palette after a reset.
--- Call this when returning to ChronosOS from a game or external program.
function ThemeManager.restorePalette()
    if currentRawTheme then
        applyPalette(currentRawTheme)
    end
end

return ThemeManager
