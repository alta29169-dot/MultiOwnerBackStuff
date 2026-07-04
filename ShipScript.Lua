-- ============================================================
--  ShipMovementTest.lua
--  Finds your Destroyer / Cruiser / Heavy Cruiser, seats you,
--  then measures forward speed & turn rate.
-- ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- CONFIG
local SHIP_TYPES = { "Destroyer", "Cruiser", "Heavy Cruiser" }
local FORWARD_SPEED_TARGET = 200   -- initial speed to try (can be adjusted)
local TURN_SPEED_TARGET   = 1.5    -- rad/s to try for turning

-- ---------- Find my ship ----------
local function findMyShip()
    for _, name in ipairs(SHIP_TYPES) do
        local ship = workspace:FindFirstChild(name)
        if ship then
            local ownerVal = ship:FindFirstChild("Owner")
            if ownerVal and ownerVal:IsA("StringValue") and ownerVal.Value == LocalPlayer.Name then
                return ship
            end
        end
    end
    return nil
end

-- ---------- Seat the player ----------
local function seatInShip(ship)
    local seat = ship:FindFirstChild("Seat")
    if not seat then
        warn("[ShipTest] No Seat found in ship")
        return false
    end

    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart")
    local hum = char:WaitForChild("Humanoid")

    hrp.CFrame = seat.CFrame + Vector3.new(0, 2, 0)   -- slight lift
    task.wait(0.3)
    seat:Sit(hum)
    print("[ShipTest] Seated in", ship.Name)
    return true
end

-- ---------- Main test routine ----------
local function runTests(ship)
    local mainBody = ship:FindFirstChild("MainBody")
    if not mainBody then
        warn("[ShipTest] MainBody not found")
        return
    end

    local bodyVel = mainBody:FindFirstChild("BodyVelocity") or mainBody:FindFirstChildWhichIsA("LinearVelocity")
    local bodyAngVel = mainBody:FindFirstChild("BodyAngularVelocity") or mainBody:FindFirstChildWhichIsA("AngularVelocity")

    if not bodyVel or not bodyAngVel then
        warn("[ShipTest] Missing BodyVelocity or BodyAngularVelocity")
        return
    end

    -- Helper: set forward speed
    local function setForwardSpeed(speed)
        local dir = mainBody.CFrame.LookVector
        if bodyVel:IsA("BodyVelocity") then
            bodyVel.Velocity = dir * speed
            bodyVel.MaxForce = Vector3.new(1e6, 1e6, 1e6)  -- plenty of force
        elseif bodyVel:IsA("LinearVelocity") then
            bodyVel.VectorVelocity = dir * speed
            bodyVel.MaxForce = 1e6
        end
    end

    -- Helper: stop movement
    local function stopMovement()
        if bodyVel:IsA("BodyVelocity") then
            bodyVel.Velocity = Vector3.zero
        elseif bodyVel:IsA("LinearVelocity") then
            bodyVel.VectorVelocity = Vector3.zero
        end
    end

    -- Helper: set turn speed
    local function setTurnSpeed(radPerSec)
        if bodyAngVel:IsA("BodyAngularVelocity") then
            bodyAngVel.AngularVelocity = Vector3.new(0, radPerSec, 0)
            bodyAngVel.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
        elseif bodyAngVel:IsA("AngularVelocity") then
            bodyAngVel.AngularVelocity = Vector3.new(0, radPerSec, 0)
            bodyAngVel.MaxTorque = 1e9
        end
    end

    -- Helper: stop turning
    local function stopTurning()
        if bodyAngVel:IsA("BodyAngularVelocity") then
            bodyAngVel.AngularVelocity = Vector3.zero
        elseif bodyAngVel:IsA("AngularVelocity") then
            bodyAngVel.AngularVelocity = Vector3.zero
        end
    end

    print("[ShipTest] === Forward Speed Test ===")
    setForwardSpeed(FORWARD_SPEED_TARGET)
    for i = 1, 10 do
        task.wait(0.5)
        local speed = mainBody.AssemblyLinearVelocity.Magnitude
        print(string.format("[ShipTest] Forward speed: %.1f studs/s", speed))
    end
    stopMovement()
    task.wait(1)

    print("[ShipTest] === Turn Speed Test ===")
    setTurnSpeed(TURN_SPEED_TARGET)
    local startYaw = mainBody.Orientation.Y
    for i = 1, 10 do
        task.wait(0.5)
        local currentYaw = mainBody.Orientation.Y
        local diff = math.abs(currentYaw - startYaw)
        print(string.format("[ShipTest] Yaw change: %.1f deg", diff))
        startYaw = currentYaw
    end
    stopTurning()

    print("[ShipTest] Tests complete. You can now control the ship manually.")
end

-- ---------- Entry point ----------
local function start()
    print("[ShipTest] Waiting for character...")
    while not LocalPlayer.Character do task.wait(0.5) end
    print("[ShipTest] Looking for ship...")
    local ship = findMyShip()
    if not ship then
        warn("[ShipTest] No ship found. Make sure you spawned one.")
        return
    end
    if not seatInShip(ship) then return end
    task.wait(1)   -- let the seat settle
    runTests(ship)
end

start()
