-- ShipCombat.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = {}
local Config = nil
local lastBombTime = 0

function Combat.init(cfg)
    Config = cfg
end

function Combat.engage(enemyShip)
    if not Config then return end
    if not enemyShip then return end
    local enemyBody = enemyShip:FindFirstChild("MainBody")
    if not enemyBody then return end

    -- Temporary debug marker (remove after testing)
    local marker = Instance.new("Part")
    marker.Name = "AimMarker"
    marker.Anchored = true
    marker.CanCollide = false
    marker.Shape = Enum.PartType.Ball
    marker.Size = Vector3.new(4, 4, 4)
    marker.BrickColor = BrickColor.new("Bright red")
    marker.Position = enemyBody.Position
    marker.Parent = workspace
    task.delay(1, function() marker:Destroy() end)

    pcall(function()
        ReplicatedStorage.Event:FireServer("aim", { enemyBody.Position })
    end)

    local now = tick()
    if now - lastBombTime >= Config.BOMB_COOLDOWN then
        pcall(function()
            ReplicatedStorage.Event:FireServer("bomb", { true })
        end)
        lastBombTime = now
    end
end

return Combat
