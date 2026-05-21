-- Peripherals: wraps pocketUnlimited's multi-upgrade back peripheral

local P = {}
local back = nil

function P.init()
    -- pocketUnlimited exposes all upgrades through peripheral "back"
    if peripheral.isPresent("back") then
        back = peripheral.wrap("back")
    end
end

-- Returns the speaker upgrade object, or nil if not connected
function P.getSpeaker()
    if not back then return nil end
    local ok, upgrades = pcall(function() return back.upgrades() end)
    if not ok or not upgrades then return nil end
    return upgrades.speaker
end

-- Returns the ender modem upgrade object, or nil if not connected
function P.getModem()
    if not back then return nil end
    local ok, upgrades = pcall(function() return back.upgrades() end)
    if not ok or not upgrades then return nil end
    -- pocketUnlimited key may be "ender_modem" or "wireless_modem"
    return upgrades.wireless_modem_advanced or upgrades.wireless_modem
end

-- Returns a status table: { speaker = bool, modem = bool }
function P.status()
    return {
        speaker = P.getSpeaker() ~= nil,
        modem   = P.getModem() ~= nil,
    }
end

-- Returns the raw back peripheral (for direct upgrade method calls)
function P.getBack()
    return back
end

return P
