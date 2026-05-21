-- ChronosOS v1.0
-- PipBoy-style OS for ComputerCraft Pocket Computer

package.path = package.path
    .. ";/core/os/?.lua"
    .. ";/core/libs/?.lua"
    .. ";/core/os/games/?.lua"

local ThemeManager = require("ThemeManager")
local Peripherals  = require("Peripherals")
local TabManager   = require("TabManager")

ThemeManager.init()
Peripherals.init()
TabManager.run()
