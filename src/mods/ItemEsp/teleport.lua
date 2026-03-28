local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

return function(deps)
    local getPrimaryPart = deps.getPrimaryPart
    local isEspEnabled = deps.isEspEnabled

    local Teleport = {}

    function Teleport.teleportToTarget(target)
        local localPlayer = Players.LocalPlayer
        local character = localPlayer and localPlayer.Character
        if not character then
            return
        end

        local root = character:FindFirstChild("HumanoidRootPart")
        local targetPart = getPrimaryPart(target)
        if not root or not targetPart then
            return
        end

        character:PivotTo(CFrame.new(targetPart.Position + Vector3.new(0, 3, 0)))
    end

    function Teleport.createOverlay(targetData)
        local localPlayer = Players.LocalPlayer
        local playerGui = localPlayer and localPlayer:FindFirstChild("PlayerGui")
        if not playerGui then
            return nil, nil, nil
        end

        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = "ItemEspTeleportOverlay"
        screenGui.IgnoreGuiInset = true
        screenGui.ResetOnSpawn = false
        screenGui.Parent = playerGui

        local button = Instance.new("TextButton")
        button.Name = "TeleportButton"
        button.Size = UDim2.new(0, 90, 0, 22)
        button.AnchorPoint = Vector2.new(0.5, 1)
        button.BackgroundTransparency = 1
        button.Text = ""
        button.AutoButtonColor = false
        button.Parent = screenGui

        local overlayConnection = RunService.RenderStepped:Connect(function()
            if not isEspEnabled() or not targetData.instance or not targetData.instance.Parent then
                screenGui.Enabled = false
                return
            end

            local refreshedAdornee = getPrimaryPart(targetData.instance)
            if not refreshedAdornee then
                screenGui.Enabled = false
                return
            end

            local camera = Workspace.CurrentCamera
            if not camera then
                screenGui.Enabled = false
                return
            end

            local position, isVisible = camera:WorldToViewportPoint(refreshedAdornee.Position + Vector3.new(0, 2.3, 0))
            if isVisible then
                screenGui.Enabled = true
                button.Position = UDim2.new(0, position.X, 0, position.Y)
            else
                screenGui.Enabled = false
            end
        end)

        local clickConnection = button.MouseButton1Click:Connect(function()
            Teleport.teleportToTarget(targetData.instance)
        end)

        return screenGui, overlayConnection, clickConnection
    end

    return Teleport
end
