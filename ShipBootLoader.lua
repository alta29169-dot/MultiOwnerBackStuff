-- ShipBootLoader.lua
local GITHUB_USER = "swiftlyrandom"
local GITHUB_REPO = "QuurpMethod"
local GITHUB_BRANCH = "main"
local MODULES_PATH = "ShipModules"   -- folder inside your repo

local MODULE_NAMES = {
    "ShipConfig",
    "ShipScanner",
    "ShipMover",
    "ShipCombat",
    "MainShipController",
}

local RAW_BASE = string.format(
    "https://raw.githubusercontent.com/%s/%s/refs/heads/%s/%s/",
    GITHUB_USER, GITHUB_REPO, GITHUB_BRANCH, MODULES_PATH
)

_G._Modules = _G._Modules or {}

local function fetchModule(name, retries)
    retries = retries or 3
    local url = RAW_BASE .. name .. ".lua"
    print("[ShipBoot] Fetching:", name)

    for attempt = 1, retries do
        local ok, result = pcall(function()
            return request({ Url = url, Method = "GET" })
        end)
        if ok and result and result.StatusCode == 200 then
            local fn, err = loadstring(result.Body, name)
            if not fn then error("[ShipBoot] Compile error in " .. name .. ": " .. tostring(err)) end
            local mod = fn()
            if type(mod) ~= "table" then error("[ShipBoot] " .. name .. " did not return a table.") end
            _G._Modules[name] = mod
            print("[ShipBoot] Loaded:", name)
            return
        else
            if attempt < retries then
                warn("[ShipBoot] Attempt " .. attempt .. " failed for " .. name .. ", retrying...")
                task.wait(1)
            else
                error("[ShipBoot] Failed to load " .. name .. " after " .. retries .. " attempts.")
            end
        end
    end
end

-- Load all ship modules
print("[ShipBoot] Loading ship modules...")
for _, name in ipairs(MODULE_NAMES) do
    local success, err = pcall(fetchModule, name, 3)
    if not success then
        warn("[ShipBoot] FATAL: " .. tostring(err))
        return
    end
end

-- Initialise sub-modules
_G._Modules.ShipScanner.init(_G._Modules.ShipConfig)
_G._Modules.ShipMover.init(_G._Modules.ShipConfig)
_G._Modules.ShipCombat.init(_G._Modules.ShipConfig)

-- The MainShipController starts automatically (it calls start() at the bottom)
print("[ShipBoot] All ship modules loaded. Controller starting...")
