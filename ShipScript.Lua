-- ============================================================
--  ShipMove_ContextAction.lua  (action discovery via BoundActionInfo)
-- ============================================================
local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local SHIP_TYPES = { "Destroyer", "Cruiser", "Heavy Cruiser" }
local TARGET_POS = Vector3.new(1000, 0, 1000)   -- change me

local STOP_DISTANCE = 50
local ANGLE_THRESHOLD_DEG = 8

-- These will be filled automatically
local ACTION_FORWARD = nil
local ACTION_BACKWARD = nil
local ACTION_TURNLEFT = nil
local ACTION_TURNRIGHT = nil

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

-- ---------- Discover actions using BoundActionInfo ----------
local function discoverActions()
    -- Try the official method first
    local success, actions = pcall(function()
        return ContextActionService:GetAllBoundActionInfo()
    end)

    if success and actions then
        for _, info in ipairs(actions) do
            local title = info.title or ""   -- the text shown on the button
            local name = info.name           -- the actual action name

            if title == "^" then ACTION_FORWARD = name
            elseif title == "v" then ACTION_BACKWARD = name
            elseif title == "<" then ACTION_TURNLEFT = name
            elseif title == ">" then ACTION_TURNRIGHT = name
            end
        end
    else
        -- Fallback: try to guess from GUI (button names may be identical)
        warn("GetAllBoundActionInfo not available; using GUI scan + common names")
        local playerGui = LocalPlayer:WaitForChild("PlayerGui")
        local frame = playerGui:FindFirstChild("ContextActionGui")
        if frame then
            local btnFrame = frame:FindFirstChild("ContextButtonFrame")
            if btnFrame then
                for _, button in ipairs(btnFrame:GetChildren()) do
                    if button:IsA("ImageButton") then
                        local titleLabel = button:FindFirstChild("ActionTitle")
                        if titleLabel and titleLabel:IsA("TextLabel") then
                            local text = titleLabel.Text
                            -- Try to get action name from button's children or attributes
                            local actionName = button.Name   -- might be identical
                            local actionValue = button:FindFirstChild("Action") or button:FindFirstChild("ActionName")
                            if actionValue and actionValue:IsA("StringValue") then
                                actionName = actionValue.Value
                            elseif button:GetAttribute("ActionName") then
                                actionName = button:GetAttribute("ActionName")
                            end
                            if text == "^" then ACTION_FORWARD = actionName
                            elseif text == "v" then ACTION_BACKWARD = actionName
                            elseif text == "<" then ACTION_TURNLEFT = actionName
                            elseif text == ">" then ACTION_TURNRIGHT = actionName
                            end
                        end
                    end
                end
            end
        end
    end

    -- Final safety fallback
    if not ACTION_FORWARD then ACTION_FORWARD = "Forward" end
    if not ACTION_BACKWARD then ACTION_BACKWARD = "Backward" end
    if not ACTION_TURNLEFT then ACTION_TURNLEFT = "TurnLeft" end
    if not ACTION_TURNRIGHT then ACTION_TURNRIGHT = "TurnRight" end

    print("[ShipMove] Actions found – Fwd:", ACTION_FORWARD, "Bwd:", ACTION_BACKWARD,
          "L:", ACTION_TURNLEFT, "R:", ACTION_TURNRIGHT)
end

-- ---------- Hold / release helpers ----------
local function holdAction(name)
    if not name then return end
    pcall(function()
        ContextActionService:CallFunction(name, Enum.UserInputState.Begin, nil)
    end)
end

local function releaseAction(name)
    if not name then return end
    pcall(function()
        ContextActionService:CallFunction(name, Enum.UserInputState.End, nil)
    end)
end

-- ---------- Movement loop ----------
local function moveToTarget(ship)
    local mainBody = ship:FindFirstChild("MainBody")
    if not mainBody then warn("MainBody not found"); return end

    -- Remove AlignOrientation if present
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
            releaseAction(ACTION_FORWARD)
            releaseAction(ACTION_TURNLEFT)
            releaseAction(ACTION_TURNRIGHT)
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
            releaseAction(ACTION_FORWARD)
            if needTurnLeft then
                holdAction(ACTION_TURNLEFT)
                releaseAction(ACTION_TURNRIGHT)
            else
                holdAction(ACTION_TURNRIGHT)
                releaseAction(ACTION_TURNLEFT)
            end
        else
            releaseAction(ACTION_TURNLEFT)
            releaseAction(ACTION_TURNRIGHT)
            holdAction(ACTION_FORWARD)
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

    discoverActions()
    moveToTarget(ship)
end

start()
