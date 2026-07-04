-- MainShipController.lua
local RunService = game:GetService("RunService")

local MainCtrl = {}
local Scanner = nil
local Mover = nil
local Combat = nil
local Config = nil

local WAYPOINT = Vector3.new(1000, 0, 1000)

function MainCtrl.start()
    -- Lazy-load module references after init
    Scanner = _G._Modules.ShipScanner
    Mover   = _G._Modules.ShipMover
    Combat  = _G._Modules.ShipCombat
    Config  = _G._Modules.ShipConfig

    print("[ShipCtrl] Looking for ship...")
    local ship = Scanner.findMyShip()
    if not ship then
        warn("[ShipCtrl] No ship found – retrying in 3s...")
        task.wait(3)
        MainCtrl.start()
        return
    end

    if not Scanner.seatInShip(ship) then
        warn("[ShipCtrl] Could not seat")
        return
    end

    task.wait(0.5)
    Mover.disableNativeControl()

    local mainBody, bodyVel, bodyAngVel = Mover.prepareBodyMovers(ship)
    if not mainBody then return end

    local myTeam = (ship:FindFirstChild("Team") and ship:FindFirstChild("Team").Value) or ""

    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not ship.Parent then
            conn:Disconnect()
            print("[ShipCtrl] Ship destroyed.")
            return
        end

        local enemyShip = Scanner.findEnemyShip(myTeam)
        if enemyShip then
            Combat.engage(enemyShip, mainBody)
        end

        local arrived = Mover.navigateTo(mainBody, bodyVel, bodyAngVel, WAYPOINT)
        if arrived then
            print("[ShipCtrl] Arrived at waypoint.")
            conn:Disconnect()
        end
    end)
end

return MainCtrl
