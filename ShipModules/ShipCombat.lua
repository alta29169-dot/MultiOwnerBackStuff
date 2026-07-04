-- ShipCombat.lua (with prediction math)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = {}
local Config = nil
local lastBombTime = 0

-- Prediction math (from your old code)
local function solveQuadratic(a, b, c)
    local d = b * b - 4 * a * c
    if d < 0 then return nil end
    local sqrtD = math.sqrt(d)
    local t1 = (-b - sqrtD) / (2 * a)
    local t2 = (-b + sqrtD) / (2 * a)
    return (t1 > 0 and t1) or (t2 > 0 and t2) or nil
end

local function getAimPosition(gunPos, targetPos, targetVel, bulletSpeed)
    local dp = targetPos - gunPos
    local a = targetVel:Dot(targetVel) - bulletSpeed * bulletSpeed
    local b = 2 * dp:Dot(targetVel)
    local c = dp:Dot(dp)
    local t = solveQuadratic(a, b, c)
    if not t then return nil end
    return targetPos + targetVel * t
end

function Combat.init(cfg)
    Config = cfg
end

function Combat.engage(enemyShip, ownMainBody)
    if not Config then return end
    if not enemyShip then return end
    local enemyBody = enemyShip:FindFirstChild("MainBody")
    if not enemyBody then return end

    local gunPos = ownMainBody.Position  -- approximate gun position
    local targetPos = enemyBody.Position
    local targetVel = enemyBody.AssemblyLinearVelocity or Vector3.zero

    -- 1. Predict future position (horizontal lead)
    local predictedPos = getAimPosition(gunPos, targetPos, targetVel, Config.BULLET_SPEED)
    if not predictedPos then
        -- If prediction fails, fall back to current position
        predictedPos = targetPos
    end

    -- 2. Apply vertical offset (factor * distance)
    local dist = (gunPos - targetPos).Magnitude
    local yOffset = Config.AIM_FACTOR * dist
    local aimPos = Vector3.new(predictedPos.X, predictedPos.Y + yOffset, predictedPos.Z)

    -- 3. Aim
    pcall(function()
        ReplicatedStorage.Event:FireServer("aim", { aimPos })
    end)

    -- 4. Fire on cooldown
    local now = tick()
    if now - lastBombTime >= Config.BOMB_COOLDOWN then
        pcall(function()
            ReplicatedStorage.Event:FireServer("bomb", { true })
        end)
        lastBombTime = now
    end
end

return Combat
