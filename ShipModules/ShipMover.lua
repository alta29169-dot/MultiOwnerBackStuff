-- ShipMover.lua
local RunService = game:GetService("RunService")
local LocalPlayer = game:GetService("Players").LocalPlayer

local Mover = {}
local Config = nil

function Mover.init(cfg)
    Config = cfg
end

-- Kill the native Control script and watch for new copies
function Mover.disableNativeControl()
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not backpack then return end

    local function destroyControl()
        for _, child in ipairs(backpack:GetChildren()) do
            if child.Name == "Control" and child:IsA("LocalScript") then
                child:Destroy()
                print("[ShipMover] Destroyed Control script")
            end
        end
    end
    destroyControl()
    backpack.ChildAdded:Connect(function(child)
        if child.Name == "Control" and child:IsA("LocalScript") then
            child:Destroy()
        end
    end)
end

-- Prepare the ship's BodyMovers for our commands
function Mover.prepareBodyMovers(ship)
    local mainBody = ship:FindFirstChild("MainBody")
    if not mainBody then return nil, nil, nil end

    -- Remove AlignOrientation
    local align = mainBody:FindFirstChild("AlignOrientation")
    if align then align:Destroy() end

    local bodyVel = mainBody:FindFirstChild("BodyVelocity") or mainBody:FindFirstChildWhichIsA("LinearVelocity")
    local bodyAngVel = mainBody:FindFirstChild("BodyAngularVelocity") or mainBody:FindFirstChildWhichIsA("AngularVelocity")

    if not bodyVel or not bodyAngVel then
        warn("[ShipMover] Missing BodyMovers")
        return nil, nil, nil
    end

    -- Raise force limits
    if bodyVel:IsA("LinearVelocity") then
        bodyVel.MaxForce = 1e9
        bodyVel.MaxAxesForce = Vector3.new(1e9, 1e9, 1e9)
    else
        bodyVel.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    end
    bodyAngVel.MaxTorque = 1e9

    return mainBody, bodyVel, bodyAngVel
end

-- Steer and move toward a target position (called every heartbeat)
function Mover.navigateTo(body, bodyVel, bodyAngVel, targetPos)
    local myPos = body.Position
    local toTarget = targetPos - myPos
    local dist = toTarget.Magnitude
    local targetDir = toTarget.Unit

    if dist < Config.STOP_DISTANCE then
        -- Stop
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
        return true   -- arrived
    end

    -- Angle error
    local dot = body.CFrame.LookVector:Dot(targetDir)
    local angleRad = math.acos(math.clamp(dot, -1, 1))
    local cross = body.CFrame.LookVector:Cross(targetDir)
    local sign = (cross.Y >= 0) and 1 or -1
    local desiredTurn = sign * math.min(angleRad * Config.TURN_GAIN, Config.TURN_SPEED_RAD)

    -- Apply turn
    if bodyAngVel:IsA("AngularVelocity") then
        bodyAngVel.AngularVelocity = Vector3.new(0, desiredTurn, 0)
    else
        bodyAngVel.AngularVelocity = Vector3.new(0, desiredTurn, 0)
    end

    -- Apply forward speed
    local forwardDir = body.CFrame.LookVector
    if bodyVel:IsA("LinearVelocity") then
        bodyVel.VectorVelocity = forwardDir * Config.FORWARD_SPEED
    else
        bodyVel.Velocity = forwardDir * Config.FORWARD_SPEED
    end

    return false
end

return Mover
