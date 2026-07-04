-- ============================================================
--  ShipMovementTest.lua 3
--  Finds your ship, seats you, and measures real speed & turn.
-- ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local SHIP_TYPES = { "Destroyer", "Cruiser", "Heavy Cruiser" }

-- ---------- Find my ship (owner‑matched) ----------
local function findMyShip()
    for _, shipType in ipairs(SHIP_TYPES) do
        for _, ship in ipairs(workspace:GetChildren()) do
            if ship:IsA("Model") and ship.Name == shipType then
                local ownerVal = ship:FindFirstChild("Owner")
                if ownerVal and ownerVal:IsA("StringValue") and ownerVal.Value == LocalPlayer.Name then
                    print("[ShipTest] Found", shipType, "– Owner:", ownerVal.Value)
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
    if not seat then
        warn("[ShipTest] No Seat found")
        return false
    end
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart")
    local hum = char:WaitForChild("Humanoid")
    hrp.CFrame = seat.CFrame + Vector3.new(0, 2, 0)
    task.wait(0.3)
    seat:Sit(hum)
    print("[ShipTest] Seated in", ship.Name)
    return true
end

-- ---------- Run tests ----------
local function runTests(ship)
    local mainBody = ship:FindFirstChild("MainBody")
    if not mainBody then
        warn("[ShipTest] MainBody not found")
        return
    end

    local bodyVel = mainBody:FindFirstChild("BodyVelocity")
        or mainBody:FindFirstChildWhichIsA("LinearVelocity")
    local bodyAngVel = mainBody:FindFirstChild("BodyAngularVelocity")
        or mainBody:FindFirstChildWhichIsA("AngularVelocity")
    local alignOrientation = mainBody:FindFirstChild("AlignOrientation")

    if not bodyVel or not bodyAngVel then
        warn("[ShipTest] Missing BodyVelocity or BodyAngularVelocity")
        return
    end

    -- Temporarily remove AlignOrientation so it doesn't fight turns
    if alignOrientation then
        alignOrientation:Destroy()
        print("[ShipTest] Removed AlignOrientation for testing")
    end

    -- Helper: set forward speed via BodyVelocity/LinearVelocity
    local function setForwardSpeed(speed)
        local dir = mainBody.CFrame.LookVector
        if bodyVel:IsA("LinearVelocity") then
            bodyVel.VectorVelocity = dir * speed
        else
            bodyVel.Velocity = dir * speed
        end
        bodyVel.MaxForce = 1e9   -- plenty of force to reach target speed
    end

    -- Helper: stop forward movement
    local function stopForward()
        if bodyVel:IsA("LinearVelocity") then
            bodyVel.VectorVelocity = Vector3.zero
        else
            bodyVel.Velocity = Vector3.zero
        end
    end

    -- Helper: set turn speed (Y‑axis rotation)
    local function setTurnSpeed(radPerSec)
        if bodyAngVel:IsA("AngularVelocity") then
            bodyAngVel.AngularVelocity = Vector3.new(0, radPerSec, 0)
        else
            bodyAngVel.AngularVelocity = Vector3.new(0, radPerSec, 0)
        end
        bodyAngVel.MaxTorque = 1e9
    end

    -- Helper: stop turning
    local function stopTurning()
        if bodyAngVel:IsA("AngularVelocity") then
            bodyAngVel.AngularVelocity = Vector3.zero
        else
            bodyAngVel.AngularVelocity = Vector3.zero
        end
    end

    -- ---------- Forward Speed Test ----------
    print("\n[ShipTest] === Forward Speed Test ===")
    local testSpeeds = { 20, 40, 60, 80, 100 }
    for _, targetSpeed in ipairs(testSpeeds) do
        setForwardSpeed(targetSpeed)
        task.wait(1.5)   -- let the ship accelerate
        local maxObserved = 0
        for i = 1, 10 do
            local speed = mainBody.AssemblyLinearVelocity.Magnitude
            if speed > maxObserved then maxObserved = speed end
            task.wait(0.2)
        end
        print(string.format("  Target: %3d studs/s  →  Max observed: %.1f studs/s", targetSpeed, maxObserved))
    end
    stopForward()
    task.wait(1)

    -- ---------- Turn Rate Test ----------
    print("\n[ShipTest] === Turn Rate Test ===")
    local testAngles = { 0.3, 0.6, 0.9, 1.2, 1.5 }
    for _, targetRad in ipairs(testAngles) do
        setTurnSpeed(targetRad)
        task.wait(0.5)   -- let rotation start
        local startYaw = mainBody.CFrame.Orientation.Y
        task.wait(1.0)   -- measure over 1 second
        local endYaw = mainBody.CFrame.Orientation.Y
        local deltaDeg = math.deg(math.abs(endYaw - startYaw))
        print(string.format("  Target: %.1f rad/s  →  Observed: %.1f deg/s", targetRad, deltaDeg))
    end
    stopTurning()

    print("\n[ShipTest] Tests complete. Ship is now idle and ready for manual control.")
end

-- ---------- Entry ----------
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
    task.wait(1)
    runTests(ship)
end

start()
