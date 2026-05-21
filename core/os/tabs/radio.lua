-- RADIO tab: speaker control via Peripherals

local ThemeManager = require("ThemeManager")
local Peripherals  = require("Peripherals")

local radio = {}

local function th() return ThemeManager.getColors() end

-- ── State ─────────────────────────────────────────────────────────────────────

local volume    = 1.0    -- 0.0 – 3.0
local pitch     = 1.0
local nowPlaying = nil   -- sound ID string or nil
local message   = nil

-- Pre-set sound presets (one-shot sound events — streaming music disc sounds
-- cannot play through the CC speaker API, which only handles sound effects)
local PRESETS = {
    { label = "Note: Harp",        sound = "minecraft:block.note_block.harp" },
    { label = "Note: Bass",        sound = "minecraft:block.note_block.bass" },
    { label = "Note: Bell",        sound = "minecraft:block.note_block.bell" },
    { label = "Note: Flute",       sound = "minecraft:block.note_block.flute" },
    { label = "Note: Chime",       sound = "minecraft:block.note_block.chime" },
    { label = "Note: Xylophone",   sound = "minecraft:block.note_block.xylophone" },
    { label = "Note: Banjo",       sound = "minecraft:block.note_block.banjo" },
    { label = "Note: Pling",       sound = "minecraft:block.note_block.pling" },
    { label = "Note: Guitar",      sound = "minecraft:block.note_block.guitar" },
    { label = "Note: Cow Bell",    sound = "minecraft:block.note_block.cow_bell" },
    { label = "Ambient: Cave",     sound = "minecraft:ambient.cave" },
    { label = "Level Up",          sound = "minecraft:entity.player.levelup" },
    { label = "Thunder",           sound = "minecraft:entity.lightning_bolt.thunder" },
    { label = "Toast!",            sound = "minecraft:ui.toast.challenge_complete" },
    { label = "Ender Dragon",      sound = "minecraft:entity.ender_dragon.ambient" },
}

local selectedPreset = 1
local listScroll     = 0
local LIST_H         = 12

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function getSpeaker()
    return Peripherals.getSpeaker()
end

local function playSound(soundId)
    local spk = getSpeaker()
    if not spk then
        message = "No speaker connected."
        return
    end
    local ok, err = pcall(spk.playSound, soundId, volume, pitch)
    if ok then
        nowPlaying = soundId
        message    = nil
    else
        message = "Error: " .. tostring(err)
    end
end

local function stopSound()
    local spk = getSpeaker()
    if spk then
        pcall(spk.stop)
    end
    nowPlaying = nil
    message    = nil
end

-- ── Drawing ───────────────────────────────────────────────────────────────────

local function drawVolumeBar(x, y, w, vol)
    local t  = th()
    local fg = t.primary or colors.green
    local bg = t.background or colors.black
    local hi = t.secondary or colors.lime

    term.setTextColor(fg)
    term.setBackgroundColor(bg)
    term.setCursorPos(x, y)
    term.write("VOL ")

    local barW  = w - 10
    local filled = math.floor((vol / 3.0) * barW)
    term.setCursorPos(x + 4, y)
    term.setTextColor(hi)
    term.write(string.rep("\x83", filled))
    term.setTextColor(fg)
    term.write(string.rep("-", barW - filled))
    term.write(string.format(" %3d%%", math.floor(vol / 3.0 * 100)))
end

local function drawPresetList(x, y, w, h)
    local t   = th()
    local fg  = t.primary or colors.green
    local bg  = t.background or colors.black
    local dim = t.textSecondary or colors.lime
    local hl  = t.primary or colors.green

    for row = 0, h - 1 do
        local idx = row + listScroll + 1
        local preset = PRESETS[idx]
        term.setCursorPos(x, y + row)
        if not preset then
            term.setBackgroundColor(bg)
            term.write(string.rep(" ", w))
        elseif idx == selectedPreset then
            term.setBackgroundColor(hl)
            term.setTextColor(bg)
            local label = "  \xbb " .. preset.label
            label = label:sub(1, w)
            term.write(label .. string.rep(" ", w - #label))
            term.setBackgroundColor(bg)
        else
            term.setBackgroundColor(bg)
            term.setTextColor(fg)
            local label = "    " .. preset.label
            label = label:sub(1, w)
            term.write(label .. string.rep(" ", w - #label))
        end
    end
end

-- ── Public interface ──────────────────────────────────────────────────────────

function radio.render(x, y, w, h)
    local t   = th()
    local fg  = t.primary or colors.green
    local bg  = t.background or colors.black
    local dim = t.textSecondary or colors.lime
    local ok  = t.success or colors.lime
    local err = t.error or colors.red

    term.setBackgroundColor(bg)
    term.clear()

    -- Title
    term.setTextColor(fg)
    term.setCursorPos(math.floor((w - 5) / 2) + 1, 1)
    term.write("RADIO")
    term.setTextColor(dim)
    term.setCursorPos(1, 2)
    term.write(string.rep("\x83", w))

    -- Speaker status
    local spk = getSpeaker()
    term.setCursorPos(2, 3)
    if spk then
        term.setTextColor(ok)
        term.write("Speaker: ONLINE")
    else
        term.setTextColor(err)
        term.write("Speaker: OFFLINE \x14 Connect a Speaker upgrade")
    end

    -- Now playing
    term.setCursorPos(2, 4)
    term.setTextColor(dim)
    local npText = nowPlaying and (">> " .. nowPlaying) or ">> (silent)"
    term.write(npText:sub(1, w - 2))

    term.setTextColor(fg)
    term.setCursorPos(1, 5)
    term.write(string.rep("\x83", w))

    -- Volume bar (row 6)
    drawVolumeBar(2, 6, w - 2, volume)

    -- Pitch row 7
    term.setCursorPos(2, 7)
    term.setTextColor(fg)
    term.write(string.format("PITCH  %.1f  [\x1b -] [\x1a +]", pitch))

    term.setCursorPos(1, 8)
    term.setTextColor(dim)
    term.write(string.rep("\x83", w))

    -- Preset list header
    term.setCursorPos(2, 9)
    term.setTextColor(fg)
    term.write("SOUNDS:")

    drawPresetList(2, 10, w - 2, LIST_H)

    -- Action buttons row
    local btnY = 10 + LIST_H + 1
    term.setCursorPos(2, btnY)
    term.setTextColor(fg)
    term.setBackgroundColor(bg)
    term.write("[ PLAY ]   [ STOP ]")

    -- Message / error
    if message then
        term.setCursorPos(2, btnY + 2)
        term.setTextColor(err)
        term.write(message:sub(1, w - 2))
    end

    -- Hints
    term.setCursorPos(1, h)
    term.setTextColor(dim)
    term.write("\x1e\x1f select  enter play  -/+ vol  ,/. pitch")
end

function radio.handleEvent(ev, p1, p2, p3)
    if ev == "key" then
        local k = p1
        if k == keys.up then
            if selectedPreset > 1 then
                selectedPreset = selectedPreset - 1
                if selectedPreset <= listScroll then listScroll = listScroll - 1 end
            end
        elseif k == keys.down then
            if selectedPreset < #PRESETS then
                selectedPreset = selectedPreset + 1
                if selectedPreset > listScroll + LIST_H then listScroll = listScroll + 1 end
            end
        elseif k == keys.enter then
            local preset = PRESETS[selectedPreset]
            if preset then playSound(preset.sound) end
        elseif k == keys.space then
            stopSound()
        elseif k == keys.minus then
            volume = math.max(0.0, volume - 0.1)
            volume = math.floor(volume * 10 + 0.5) / 10
        elseif k == keys.equals then  -- '=' key (same key as '+' without shift)
            volume = math.min(3.0, volume + 0.1)
            volume = math.floor(volume * 10 + 0.5) / 10
        elseif k == keys.comma then
            pitch = math.max(0.5, pitch - 0.1)
            pitch = math.floor(pitch * 10 + 0.5) / 10
        elseif k == keys.period then
            pitch = math.min(2.0, pitch + 0.1)
            pitch = math.floor(pitch * 10 + 0.5) / 10
        end

    elseif ev == "mouse_click" then
        local mx, my = p2, p3
        -- Preset list click
        if my >= 10 and my < 10 + LIST_H then
            local idx = my - 10 + listScroll + 1
            if idx >= 1 and idx <= #PRESETS then
                if idx == selectedPreset then
                    local preset = PRESETS[selectedPreset]
                    if preset then playSound(preset.sound) end
                else
                    selectedPreset = idx
                end
            end
        end
        -- Button clicks
        local btnY = 10 + LIST_H + 1
        if my == btnY then
            if mx >= 2 and mx <= 9 then
                local preset = PRESETS[selectedPreset]
                if preset then playSound(preset.sound) end
            elseif mx >= 13 and mx <= 20 then
                stopSound()
            end
        end
        -- Volume bar click (row 6, cols 6 to w-4)
        if my == 6 and mx >= 6 then
            local barW  = 74   -- approximate, matches drawVolumeBar
            local ratio = (mx - 6) / barW
            volume = math.max(0, math.min(3.0, ratio * 3.0))
            volume = math.floor(volume * 10 + 0.5) / 10
        end

    elseif ev == "mouse_scroll" then
        local dir = p1
        local my  = p3
        if my >= 10 and my < 10 + LIST_H then
            listScroll     = math.max(0, math.min(math.max(0, #PRESETS - LIST_H), listScroll + dir))
            selectedPreset = math.max(listScroll + 1, math.min(listScroll + LIST_H, selectedPreset))
        end
    end
end

return radio
