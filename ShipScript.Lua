-- ============================================================
--  ShipSpeedometer.lua
--  Seats you in your ship and prints speed + turn rate live.
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
    print("[Speedometer] Seated in", ship.Name)
    return true
end

-- ---------- Speedometer loop ----------
local function runSpeedometer(ship)
    local mainBody = ship:FindFirstChild("MainBody")
    if not mainBody then warn("MainBody not found"); return end

    -- Disable AlignOrientation so it doesn't interfere
    local align = mainBody:FindFirstChild("AlignOrientation")
    if align and align.Enabled then
        align.Enabled = false
        print("[Speedometer] AlignOrientation disabled for accurate readings")
    end

    local lastYaw = mainBody.CFrame.Orientation.Y
    local lastTime = tick()

    local conn = RunService.Heartbeat:Connect(function()
        if not ship.Parent then
            conn:Disconnect()
            print("[Speedometer] Ship destroyed – stopping.")
            return
        end
        if not (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")) then
            -- player died or left seat
            conn:Disconnect()
            print("[Speedometer] Player left seat – stopping.")
            return
        end

        local now = tick()
        local dt = now - lastTime
        if dt < 0.15 then return end   -- only update ~5 times per second

        local speed = mainBody.AssemblyLinearVelocity.Magnitude
        local currentYaw = mainBody.CFrame.Orientation.Y
        local deltaYaw = math.abs(currentYaw - lastYaw)
        local turnRate = deltaYaw / dt   -- rad/s

        print(string.format("Speed: %6.1f studs/s | Turn: %5.2f rad/s (%5.1f deg/s)",
            speed, turnRate, math.deg(turnRate)))

        lastYaw = currentYaw
        lastTime = now
    end)
end

-- ---------- Entry ----------
local function start()
    print("[Speedometer] Looking for ship...")
    local ship = findMyShip()
    if not ship then warn("No ship found – spawn one first."); return end
    if not seatInShip(ship) then return end
    task.wait(1)
    runSpeedometer(ship)
end

start()
