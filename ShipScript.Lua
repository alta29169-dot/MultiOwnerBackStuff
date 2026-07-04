-- ============================================================
--  ShipMoveTest.lua
--  Rotates toward a target, then moves forward at 43 studs/s.
-- ============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local SHIP_TYPES = { "Destroyer", "Cruiser", "Heavy Cruiser" }
local TARGET_POS = Vector3.new(1000, 0, 1000)   -- change to any world position

-- Real measured constants
local TURN_SPEED_RAD = 0.30          -- rad/s
local FORWARD_SPEED = 43             -- studs/s
local STOP_DISTANCE = 50             -- studs from target
local ANGLE_THRESHOLD_DEG = 5        -- how close before moving

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

-- ---------- Seat ----------
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

-- ---------- Remove AlignOrientation ----------
local function disableAlign(mainBody)
    local align = mainBody:FindFirstChild("AlignOrientation")
    if align then
        align:Destroy()
        print("[ShipMove] AlignOrientation removed")
    end
end

-- ---------- Movement loop ----------
local function moveToTarget(ship)
    local mainBody = ship:FindFirstChild("MainBody")
    if not mainBody then warn("MainBody not found"); return end

    disableAlign(mainBody)

    local bodyVel = mainBody:FindFirstChild("BodyVelocity") or mainBody:FindFirstChildWhichIsA("LinearVelocity")
    local bodyAngVel = mainBody:FindFirstChild("BodyAngularVelocity") or mainBody:FindFirstChildWhichIsA("AngularVelocity")

    if not bodyVel or not bodyAngVel then
        warn("Missing BodyMovers")
        return
    end

    -- Helper: set forward speed
    local function setForward(speed)
        local dir = mainBody.CFrame.LookVector
        if bodyVel:IsA("LinearVelocity") then
            bodyVel.VectorVelocity = dir * speed
        else
            bodyVel.Velocity = dir * speed
        end
        bodyVel.MaxForce = 1e9
    end

    -- Helper: stop movement
    local function stopMovement()
        if bodyVel:IsA("LinearVelocity") then
            bodyVel.VectorVelocity = Vector3.zero
        else
            bodyVel.Velocity = Vector3.zero
        end
    end

    -- Helper: set turn
    local function setTurn(radPerSec)
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

    -- Main control loop
    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not ship.Parent then conn:Disconnect() return end

        local myPos = mainBody.Position
        local toTarget = TARGET_POS - myPos
        local dist = toTarget.Magnitude
        local targetDir = toTarget.Unit

        -- Stop if close enough
        if dist < STOP_DISTANCE then
            stopMovement()
            stopTurning()
            print("[ShipMove] Reached target.")
            conn:Disconnect()
            return
        end

        -- Angle between ship's LookVector and target direction (in degrees)
        local dot = mainBody.CFrame.LookVector:Dot(targetDir)
        local angleDeg = math.deg(math.acos(math.clamp(dot, -1, 1)))

        if angleDeg > ANGLE_THRESHOLD_DEG then
            -- Rotate toward target
            local cross = mainBody.CFrame.LookVector:Cross(targetDir)
            local sign = (cross.Y >= 0) and 1 or -1   -- Y axis rotation
            setTurn(sign * TURN_SPEED_RAD)
            stopMovement()
        else
            -- Facing target – move forward
            stopTurning()
            setForward(FORWARD_SPEED)
        end
    end)

    print("[ShipMove] Moving to", TARGET_POS)
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
