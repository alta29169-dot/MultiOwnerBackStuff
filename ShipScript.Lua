-- ============================================================
--  ShipMove_Final.lua
--  Destroys the native "Control" LocalScript that fights
--  BodyMovers, then moves the ship smoothly to a target.
-- ============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local SHIP_TYPES = { "Destroyer", "Cruiser", "Heavy Cruiser" }
local TARGET_POS = Vector3.new(1000, 0, 1000)   -- change to any world position

local FORWARD_SPEED = 43
local TURN_SPEED_RAD = 0.30
local STOP_DISTANCE = 50

-- ---------- Remove the native control script ----------
local function disableNativeControl()
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not backpack then return end

    -- Kill existing copies
    for _, child in ipairs(backpack:GetChildren()) do
        if child.Name == "Control" and child:IsA("LocalScript") then
            child:Destroy()
            print("[ShipMove] Destroyed native Control script")
        end
    end

    -- Watch for the game cloning a new one (e.g. on re‑seat)
    backpack.ChildAdded:Connect(function(child)
        if child.Name == "Control" and child:IsA("LocalScript") then
            child:Destroy()
            print("[ShipMove] Destroyed new Control script")
        end
    end)
end

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
    if not seat then warn("[ShipMove] No Seat"); return false end
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart")
    local hum = char:WaitForChild("Humanoid")
    hrp.CFrame = seat.CFrame + Vector3.new(0, 2, 0)
    task.wait(0.3)
    seat:Sit(hum)
    print("[ShipMove] Seated in", ship.Name)
    return true
end

-- ---------- Movement ----------
local function moveToTarget(ship)
    local mainBody = ship:FindFirstChild("MainBody")
    if not mainBody then warn("[ShipMove] MainBody not found"); return end

    -- Destroy AlignOrientation so it doesn't fight us
    local align = mainBody:FindFirstChild("AlignOrientation")
    if align then align:Destroy() end

    local bodyVel = mainBody:FindFirstChild("BodyVelocity") or mainBody:FindFirstChildWhichIsA("LinearVelocity")
    local bodyAngVel = mainBody:FindFirstChild("BodyAngularVelocity") or mainBody:FindFirstChildWhichIsA("AngularVelocity")

    if not bodyVel or not bodyAngVel then
        warn("[ShipMove] Missing BodyVelocity or BodyAngularVelocity")
        return
    end

    -- CRITICAL: raise per‑axis force limits
    if bodyVel:IsA("LinearVelocity") then
        bodyVel.MaxForce = 1e9
        bodyVel.MaxAxesForce = Vector3.new(1e9, 1e9, 1e9)
    else
        bodyVel.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    end
    bodyAngVel.MaxTorque = 1e9

    local lastPrint = tick()

    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not ship.Parent then conn:Disconnect() return end

        local myPos = mainBody.Position
        local toTarget = TARGET_POS - myPos
        local dist = toTarget.Magnitude
        local targetDir = toTarget.Unit

        -- Stop when close enough
        if dist < STOP_DISTANCE then
            if bodyVel:IsA("LinearVelocity") then
                bodyVel.VectorVelocity = Vector3.zero
            else
                bodyVel.Velocity = Vector3.zero
            end
            if bodyAngVel:IsA("AngularVelocity") then
                bodyAngVel.AngularVelocity = Vector3.zero
            else
                bodyAngVel.AngularVelocity = Vector3.zero
            end
            print("[ShipMove] Reached target.")
            conn:Disconnect()
            return
        end

        -- Angle error (radians)
        local dot = mainBody.CFrame.LookVector:Dot(targetDir)
        local angleRad = math.acos(math.clamp(dot, -1, 1))

        -- Cross for turn direction
        local cross = mainBody.CFrame.LookVector:Cross(targetDir)
        local sign = (cross.Y >= 0) and 1 or -1

        -- Proportional turn, capped at max turn rate
        local turnGain = 1.5
        local desiredTurn = sign * math.min(angleRad * turnGain, TURN_SPEED_RAD)

        -- Apply turn
        if bodyAngVel:IsA("AngularVelocity") then
            bodyAngVel.AngularVelocity = Vector3.new(0, desiredTurn, 0)
        else
            bodyAngVel.AngularVelocity = Vector3.new(0, desiredTurn, 0)
        end

        -- Always move forward
        local forwardDir = mainBody.CFrame.LookVector
        if bodyVel:IsA("LinearVelocity") then
            bodyVel.VectorVelocity = forwardDir * FORWARD_SPEED
        else
            bodyVel.Velocity = forwardDir * FORWARD_SPEED
        end

        -- Debug every second
        local now = tick()
        if now - lastPrint > 1.0 then
            local speed = mainBody.AssemblyLinearVelocity.Magnitude
            local turnRate = bodyAngVel.AngularVelocity.Y
            print(string.format("[ShipMove] Dist: %.0f  Angle: %.1f°  Speed: %.1f  Turn: %.2f rad/s",
                dist, math.deg(angleRad), speed, turnRate))
            lastPrint = now
        end
    end)
end

-- ---------- Entry ----------
local function start()
    print("[ShipMove] Looking for ship...")
    local ship = findMyShip()
    if not ship then warn("[ShipMove] No ship found"); return end
    if not seatInShip(ship) then return end
    task.wait(0.5)
    disableNativeControl()   -- kill the Control script
    moveToTarget(ship)
end

start()
