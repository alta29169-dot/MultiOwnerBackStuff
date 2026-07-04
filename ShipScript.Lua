-- ============================================================
--  ButtonDeepScanner.lua
--  Prints every property, child, and attribute of the direction
--  buttons so we can find the real ContextActionService names.
-- ============================================================
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local function scanButton(button, expectedText)
    print("============ Button with ActionTitle text:", expectedText, "============")
    print("Button Class:", button.ClassName)
    print("Button Name:", button.Name)
    print("Button Parent:", button.Parent and button.Parent:GetFullName() or "nil")

    -- Print all attributes
    local attrs = button:GetAttributes()
    if next(attrs) then
        print("Attributes:")
        for k, v in pairs(attrs) do
            print("  ", k, "=", v)
        end
    else
        print("Attributes: (none)")
    end

    -- Print all children
    local children = button:GetChildren()
    if #children > 0 then
        print("Children:")
        for _, child in ipairs(children) do
            print("  [", child.ClassName, "]", child.Name, "Value:", child:IsA("StringValue") and child.Value or "N/A")
            -- If it's a StringValue, also print its parent
        end
    else
        print("Children: (none)")
    end

    -- Try to get the bound action name (if there's a script that reads it)
    -- Most games store it in a StringValue named "Action" or "ActionName"
    local actionValue = button:FindFirstChild("Action") or button:FindFirstChild("ActionName")
    if actionValue and actionValue:IsA("StringValue") then
        print("Found StringValue with action name:", actionValue.Value)
    end
    print("")
end

local function scanAll()
    local frame = playerGui:FindFirstChild("ContextActionGui")
    if not frame then
        warn("ContextActionGui not found")
        return
    end
    local buttonFrame = frame:FindFirstChild("ContextButtonFrame")
    if not buttonFrame then
        warn("ContextButtonFrame not found")
        return
    end

    for _, button in ipairs(buttonFrame:GetChildren()) do
        if button:IsA("ImageButton") then
            local titleLabel = button:FindFirstChild("ActionTitle")
            if titleLabel and titleLabel:IsA("TextLabel") then
                local text = titleLabel.Text
                if text == "^" or text == "v" or text == "<" or text == ">" then
                    scanButton(button, text)
                end
            end
        end
    end
end

scanAll()
