local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Utils = {}

function Utils.getCharacterRoot()
    local player = Players.LocalPlayer
    local character = player and player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

function Utils.getPrimaryPart(target)
    if not target then
        return nil
    end

    if target:IsA("BasePart") then
        return target
    end

    if target:IsA("Model") then
        return target.PrimaryPart
            or target:FindFirstChild("ProxyPart", true)
            or target:FindFirstChildWhichIsA("BasePart", true)
    end

    return nil
end

function Utils.findPrompt(target)
    if not target then
        return nil
    end

    if target:IsA("ProximityPrompt") then
        return target
    end

    return target:FindFirstChildWhichIsA("ProximityPrompt", true)
end

function Utils.getPaperPassword(target)
    local codeText = "????"
    local ok = pcall(function()
        local codePart = target:WaitForChild("Code", 1)
        if not codePart then
            return
        end

        local surfaceGui = codePart:WaitForChild("SurfaceGui", 1)
        if not surfaceGui then
            return
        end

        local textLabel = surfaceGui:WaitForChild("TextLabel", 1)
        if textLabel and textLabel.Text and textLabel.Text ~= "" then
            codeText = textLabel.Text
        end
    end)

    if not ok then
        return "????"
    end

    return codeText
end

function Utils.isPromptVisible(target)
    local part = Utils.getPrimaryPart(target)
    local camera = Workspace.CurrentCamera
    if not part or not camera then
        return false
    end

    local viewportPoint, onScreen = camera:WorldToViewportPoint(part.Position)
    return onScreen and viewportPoint.Z > 0
end

function Utils.isWithinPromptDistance(target, prompt)
    local root = Utils.getCharacterRoot()
    local part = Utils.getPrimaryPart(target)
    if not root or not part or not prompt then
        return false
    end

    return (root.Position - part.Position).Magnitude <= prompt.MaxActivationDistance
end

return Utils
