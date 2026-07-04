-- ShipScanner.lua
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Scanner = {}
local Config = nil

function Scanner.init(cfg)
    Config = cfg
end

function Scanner.findMyShip()
    if not Config then warn("[ShipScanner] Config not set"); return nil end
    for _, shipType in ipairs(Config.SHIP_TYPES) do
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

function Scanner.findEnemyShip(myTeam)
    if not Config then return nil end
    local bestDist = math.huge
    local bestShip = nil
    local myPos = (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart"))
                  and LocalPlayer.Character.HumanoidRootPart.Position
                  or Vector3.zero

    for _, shipType in ipairs(Config.SHIP_TYPES) do
        for _, ship in ipairs(workspace:GetChildren()) do
            if ship:IsA("Model") and ship.Name == shipType then
                local teamVal = ship:FindFirstChild("Team")
                if teamVal and teamVal:IsA("StringValue") and teamVal.Value ~= myTeam then
                    local mainBody = ship:FindFirstChild("MainBody")
                    if mainBody then
                        local dist = (mainBody.Position - myPos).Magnitude
                        if dist < bestDist then
                            bestDist = dist
                            bestShip = ship
                        end
                    end
                end
            end
        end
    end
    return bestShip
end

function Scanner.seatInShip(ship)
    local seat = ship:FindFirstChild("Seat")
    if not seat then return false end
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart")
    local hum = char:WaitForChild("Humanoid")
    hrp.CFrame = seat.CFrame + Vector3.new(0, 2, 0)
    task.wait(0.3)
    seat:Sit(hum)
    return true
end

return Scanner
