-- ============================================================
--  ShipMoveTest.lua 3
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

-- ---------- Smooth movement loop ----------
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

    -- Helpers
    local function setForward(speed)
        local dir = mainBody.CFrame.LookVector
        if bodyVel:IsA("LinearVelocity") then
            bodyVel.VectorVelocity = dir * speed
        else
            bodyVel.Velocity = dir * speed
        end
        bodyVel.MaxForce = 1e9
    end

    local function stopMovement()
        if bodyVel:IsA("LinearVelocity") then
            bodyVel.VectorVelocity = Vector3.zero
        else
            bodyVel.Velocity = Vector3.zero
        end
    end

    local function setTurn(radPerSec)
        if bodyAngVel:IsA("AngularVelocity") then
            bodyAngVel.AngularVelocity = Vector3.new(0, radPerSec, 0)
        else
            bodyAngVel.AngularVelocity = Vector3.new(0, radPerSec, 0)
        end
        bodyAngVel.MaxTorque = 1e9
    end

    local lastPrint = tick()

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
            setTurn(0)
            print("[ShipMove] Reached target.")
            conn:Disconnect()
            return
        end

        -- Angle error in radians
        local dot = mainBody.CFrame.LookVector:Dot(targetDir)
        local angleRad = math.acos(math.clamp(dot, -1, 1))

        -- Cross product to get sign (Y axis rotation)
        local cross = mainBody.CFrame.LookVector:Cross(targetDir)
        local sign = (cross.Y >= 0) and 1 or -1

        -- Proportional turn: larger error → faster turn, capped at max
        local turnGain = 1.5   -- increase for snappier turning
        local desiredTurn = sign * math.min(angleRad * turnGain, TURN_SPEED_RAD)

        setTurn(desiredTurn)

        -- Always move forward (no toggling)
        setForward(FORWARD_SPEED)

        -- Speed checker (once per second)
        local now = tick()
        if now - lastPrint > 1.0 then
            local actualSpeed = mainBody.AssemblyLinearVelocity.Magnitude
            local actualTurn = bodyAngVel:IsA("AngularVelocity")
                and bodyAngVel.AngularVelocity.Y or 0
            print(string.format("[ShipMove] Speed: %.1f studs/s | Turn: %.2f rad/s | Angle: %.1f deg",
                actualSpeed, actualTurn, math.deg(angleRad)))
            lastPrint = now
        end
    end)

    print("[ShipMove] Smooth movement to", TARGET_POS)
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
