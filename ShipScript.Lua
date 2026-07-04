-- ============================================================
--  ShipMove_Buttons.lua
--  Moves a ship by simulating mobile button holds via
--  ContextActionService.  Action names discovered:
--    Forward : "foward"
--    Backward: "back"
--    Turn L  : "left"
--    Turn R  : "right"
-- ============================================================
local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local SHIP_TYPES = { "Destroyer", "Cruiser", "Heavy Cruiser" }
local TARGET_POS = Vector3.new(1000, 0, 1000)   -- change to any world position

local STOP_DISTANCE = 50
local ANGLE_THRESHOLD_DEG = 8

-- ---------- Find my ship ----------
local function findMyShip()
    for _, shipType in ipairs(SHIP_TYPES) do
        for _, ship in ipairs(workspace:GetChildren()) do
            if ship:IsA("Model") and ship.Name == shipType then
                local ownerVal = ship:FindFirstChild("Owner")
                if ownerVal and ownerVal:IsA("StringValue") and ownerVal.Value == LocalPlayer.Name then
                    return ship
                end
            end
        end
    end
    return nil
end

-- ---------- Seat the player ----------
local function seatInShip(ship)
    local seat = ship:FindFirstChild("Seat")
    if not seat then warn("No Seat"); return false end
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart")
    local hum = char:WaitForChild("Humanoid")
    hrp.CFrame = seat.CFrame + Vector3.new(0, 2, 0)
    task.wait(0.3)
    seat:Sit(hum)
    return true
end

-- ---------- Button hold / release ----------
local function holdAction(actionName)
    if not actionName then return end
    pcall(function()
        ContextActionService:CallFunction(actionName, Enum.UserInputState.Begin, nil)
    end)
end

local function releaseAction(actionName)
    if not actionName then return end
    pcall(function()
        ContextActionService:CallFunction(actionName, Enum.UserInputState.End, nil)
    end)
end

-- ---------- Movement loop ----------
local function moveToTarget(ship)
    local mainBody = ship:FindFirstChild("MainBody")
    if not mainBody then warn("MainBody not found"); return end

    -- Remove AlignOrientation so it doesn't fight turns
    local align = mainBody:FindFirstChild("AlignOrientation")
    if align then align:Destroy() end

    local lastPrint = tick()

    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not ship.Parent then conn:Disconnect() return end

        local myPos = mainBody.Position
        local toTarget = TARGET_POS - myPos
        local dist = toTarget.Magnitude

        if dist < STOP_DISTANCE then
            releaseAction("foward")
            releaseAction("left")
            releaseAction("right")
            print("[ShipMove] Reached target.")
            conn:Disconnect()
            return
        end

        local targetDir = toTarget.Unit
        local dot = mainBody.CFrame.LookVector:Dot(targetDir)
        local angleDeg = math.deg(math.acos(math.clamp(dot, -1, 1)))

        local cross = mainBody.CFrame.LookVector:Cross(targetDir)
        local needTurnLeft = (cross.Y > 0)

        if angleDeg > ANGLE_THRESHOLD_DEG then
            -- Rotate toward target – release forward, hold turn
            releaseAction("foward")
            if needTurnLeft then
                holdAction("left")
                releaseAction("right")
            else
                holdAction("right")
                releaseAction("left")
            end
        else
            -- Facing target – hold forward, release turns
            releaseAction("left")
            releaseAction("right")
            holdAction("foward")
        end

        -- Debug every second
        local now = tick()
        if now - lastPrint > 1.0 then
            local speed = mainBody.AssemblyLinearVelocity.Magnitude
            print(string.format("[ShipMove] Dist: %.0f  Angle: %.1f°  Speed: %.1f",
                dist, angleDeg, speed))
            lastPrint = now
        end
    end)
end

-- ---------- Entry ----------
local function start()
    print("[ShipMove] Looking for ship...")
    local ship = findMyShip()
    if not ship then warn("No ship found"); return end
    if not seatInShip(ship) then return end
    task.wait(1)

    moveToTarget(ship)
end

start()
