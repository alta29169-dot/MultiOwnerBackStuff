-- ShipCombat.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = {}
local Config = nil
local lastBombTime = 0

function Combat.init(cfg)
    Config = cfg
end

-- Aim and fire at an enemy ship (pass the enemy model)
function Combat.engage(enemyShip)
    if not enemyShip then return end
    local enemyBody = enemyShip:FindFirstChild("MainBody")
    if not enemyBody then return end

    -- Aim
    pcall(function()
        ReplicatedStorage.Event:FireServer("aim", { enemyBody.Position })
    end)

    -- Fire bomb on cooldown
    local now = tick()
    if now - lastBombTime >= Config.BOMB_COOLDOWN then
        pcall(function()
            ReplicatedStorage.Event:FireServer("bomb", { true })
        end)
        lastBombTime = now
    end
end

return Combat
