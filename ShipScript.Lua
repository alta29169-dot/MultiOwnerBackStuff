-- ============================================================
--  ShipMove_ContextAction.lua
--  Controls the ship by simulating mobile button presses
--  through ContextActionService.  No BodyMover fights.
-- ============================================================

local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local SHIP_TYPES = { "Destroyer", "Cruiser", "Heavy Cruiser" }
local TARGET_POS = Vector3.new(1000, 0, 1000)   -- change to whatever you like

-- Real ship constants (from your measurements)
local FORWARD_SPEED = 43      -- studs/s (not used directly, just for reference)
local TURN_RATE = 0.30        -- rad/s (not used directly, just for reference)
local STOP_DISTANCE = 50      -- studs
local ANGLE_THRESHOLD_DEG = 8 -- how close we aim before moving forward

-- ---------- Find my ship (Owner match) ----------
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

-- ---------- Map action names by direction ----------
-- We'll find the ContextActionService actions that the buttons trigger.
-- The ActionTitle Text tells us the direction: "^", "v", "<", ">"
-- but the actual action name is a string like "Forward" or "MoveForward".
-- We'll scan all bindings and match them to the button text.

local ACTION_FORWARD = nil
local ACTION_BACKWARD = nil
local ACTION_TURNLEFT = nil
local ACTION_TURNRIGHT = nil

local function discoverActions()
    -- Get all bound action names
    local actions = ContextActionService:GetAllActions()
    if not actions then return end

    -- Scan the buttons to find their ActionName (or we guess)
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    local frame = playerGui:FindFirstChild("ContextActionGui")
    if not frame then return end
    local buttonFrame = frame:FindFirstChild("ContextButtonFrame")
    if not buttonFrame then return end

    -- Walk through the buttons and match them
    for _, button in ipairs(buttonFrame:GetChildren()) do
        if button:IsA("ImageButton") then
            local titleLabel = button:FindFirstChild("ActionTitle")
            if titleLabel and titleLabel:IsA("TextLabel") then
                local text = titleLabel.Text  -- "^", "v", "<", ">"
                -- The button might have an attribute or child that tells the action name
                -- Try to find a StringValue or attribute
                local actionName = button:GetAttribute("ActionName") or button.Name
                -- Or search for a child like "Action" that holds the action name
                local actionObj = button:FindFirstChild("Action") or button:FindFirstChild("ActionName")
                if actionObj and actionObj:IsA("StringValue") then
                    actionName = actionObj.Value
                end
                -- If still nil, we'll infer from text later
                if text == "^" and (not ACTION_FORWARD) then
                    ACTION_FORWARD = actionName or button.Name
                elseif text == "v" and (not ACTION_BACKWARD) then
                    ACTION_BACKWARD = actionName or button.Name
                elseif text == "<" and (not ACTION_TURNLEFT) then
                    ACTION_TURNLEFT = actionName or button.Name
                elseif text == ">" and (not ACTION_TURNRIGHT) then
                    ACTION_TURNRIGHT = actionName or button.Name
                end
            end
        end
    end
end

-- Fallback: if discovery didn't work, we'll assume common action names
local function setFallbackActions()
    if not ACTION_FORWARD then ACTION_FORWARD = "Forward" end
    if not ACTION_BACKWARD then ACTION_BACKWARD = "Backward" end
    if not ACTION_TURNLEFT then ACTION_TURNLEFT = "TurnLeft" end
    if not ACTION_TURNRIGHT then ACTION_TURNRIGHT = "TurnRight" end
end

-- ---------- Simulate holding a context action ----------
-- ContextActionService fires functions with (actionName, inputState, inputObject)
-- inputState can be Enum.UserInputState.Begin, .Change, .End
-- To hold, we fire Begin once, then repeated Change? Actually the service expects
-- continuous holding to be handled by the function itself. Usually the function
-- checks if state == Enum.UserInputState.Begin to start, and End to stop.
-- But we can simply call the bound function directly with a fake input object.
-- That's risky. The safest way is to use `ContextActionService:CallFunction(actionName, state, nil)`
-- which triggers the function bound to that action with the given state.
-- We'll start with Begin to press, and End to release.

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

    -- Remove AlignOrientation if present (may interfere)
    local align = mainBody:FindFirstChild("AlignOrientation")
    if align then align:Destroy() end

    print("[ShipMove] Actions: Fwd=", ACTION_FORWARD, "Bwd=", ACTION_BACKWARD, "L=", ACTION_TURNLEFT, "R=", ACTION_TURNRIGHT)

    local lastPrint = tick()

    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not ship.Parent then conn:Disconnect() return end

        local myPos = mainBody.Position
        local toTarget = TARGET_POS - myPos
        local dist = toTarget.Magnitude
        if dist < STOP_DISTANCE then
            -- Release all actions
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

        -- Determine turn direction
        local cross = mainBody.CFrame.LookVector:Cross(targetDir)
        local needTurnLeft = (cross.Y > 0)   -- if cross.Y positive, turning left reduces angle

        -- If angle is large enough, we turn instead of moving forward
        if angleDeg > ANGLE_THRESHOLD_DEG then
            -- Release forward, hold turn
            releaseAction(ACTION_FORWARD)
            if needTurnLeft then
                holdAction(ACTION_TURNLEFT)
                releaseAction(ACTION_TURNRIGHT)
            else
                holdAction(ACTION_TURNRIGHT)
                releaseAction(ACTION_TURNLEFT)
            end
        else
            -- Facing roughly toward target: hold forward, release turns
            releaseAction(ACTION_TURNLEFT)
            releaseAction(ACTION_TURNRIGHT)
            holdAction(ACTION_FORWARD)
        end

        -- Debug print every second
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

    -- Discover actions from buttons
    discoverActions()
    setFallbackActions()   -- in case discovery missed something

    moveToTarget(ship)
end

start()
