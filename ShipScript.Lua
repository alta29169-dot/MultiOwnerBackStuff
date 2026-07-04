-- ============================================================
--  ShipMovementSpam.lua  (spams 40 studs/s forward)
-- ============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local SHIP_TYPES = { "Destroyer", "Cruiser", "Heavy Cruiser" }

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
    print("[Spam] Seated in", ship.Name)
    return true
end

-- ---------- Spam test ----------
local function spamTest(ship)
    local mainBody = ship:FindFirstChild("MainBody")
    if not mainBody then warn("MainBody not found"); return end

    local bodyVel = mainBody:FindFirstChild("BodyVelocity") or mainBody:FindFirstChildWhichIsA("LinearVelocity")
    if not bodyVel then warn("No BodyVelocity/LinearVelocity"); return end

    -- Remove AlignOrientation if present
    local align = mainBody:FindFirstChild("AlignOrientation")
    if align then align:Destroy(); print("[Spam] AlignOrientation destroyed") end

    -- Boost force to absurd levels so nothing limits it
    if bodyVel:IsA("LinearVelocity") then
        bodyVel.ForceLimitMode = Enum.ForceLimitMode.Magnitude  -- keep it magnitude
        bodyVel.MaxForce = 1e15
        -- Also set MaxAxesForce huge in case it matters
        bodyVel.MaxAxesForce = Vector3.new(1e15, 1e15, 1e15)
    else
        bodyVel.MaxForce = Vector3.new(1e15, 1e15, 1e15)
    end

    print("[Spam] Force maxed. Spamming 40 studs/s forward for 5 seconds...")

    local dir = mainBody.CFrame.LookVector
    local startTime = tick()

    local conn = RunService.Heartbeat:Connect(function()
        if tick() - startTime > 5 then
            conn:Disconnect()
            -- Stop movement
            if bodyVel:IsA("LinearVelocity") then
                bodyVel.VectorVelocity = Vector3.zero
            else
                bodyVel.Velocity = Vector3.zero
            end
            print("[Spam] Test finished.")
            return
        end
        -- Spam velocity every frame
        if bodyVel:IsA("LinearVelocity") then
            bodyVel.VectorVelocity = dir * 40
        else
            bodyVel.Velocity = dir * 40
        end
    end)

    -- Print speed every 0.5 seconds
    while tick() - startTime < 5 do
        task.wait(0.5)
        local speed = mainBody.AssemblyLinearVelocity.Magnitude
        print(string.format("  Speed: %.1f studs/s", speed))
    end

    -- Cleanup
    conn:Disconnect()
    if bodyVel:IsA("LinearVelocity") then
        bodyVel.VectorVelocity = Vector3.zero
    else
        bodyVel.Velocity = Vector3.zero
    end
end

-- ---------- Entry ----------
local function start()
    print("[Spam] Looking for ship...")
    local ship = findMyShip()
    if not ship then warn("No ship found"); return end
    if not seatInShip(ship) then return end
    task.wait(1)
    spamTest(ship)
end

start()
