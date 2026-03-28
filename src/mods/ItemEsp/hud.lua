local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

return function(deps)
    local getTrackedTargets = deps.getTrackedTargets

    local Hud = {}
    local gui
    local heartbeatConnection
    local passwordLabel
    local anglerLabel

    local function ensureGui()
        if gui and gui.Parent then
            return true
        end

        local localPlayer = Players.LocalPlayer
        local playerGui = localPlayer and localPlayer:FindFirstChild("PlayerGui")
        if not playerGui then
            return false
        end

        gui = Instance.new("ScreenGui")
        gui.Name = "PressureModHud"
        gui.IgnoreGuiInset = true
        gui.ResetOnSpawn = false
        gui.Parent = playerGui

        passwordLabel = Instance.new("TextLabel")
        passwordLabel.Name = "PasswordHint"
        passwordLabel.BackgroundTransparency = 1
        passwordLabel.AnchorPoint = Vector2.new(0.5, 0)
        passwordLabel.Position = UDim2.new(0.5, 0, 0, 70)
        passwordLabel.Size = UDim2.new(0, 500, 0, 40)
        passwordLabel.Font = Enum.Font.GothamBold
        passwordLabel.TextColor3 = Color3.fromRGB(255, 120, 255)
        passwordLabel.TextStrokeTransparency = 0.35
        passwordLabel.TextScaled = true
        passwordLabel.Visible = false
        passwordLabel.Parent = gui

        anglerLabel = Instance.new("TextLabel")
        anglerLabel.Name = "AnglerWarning"
        anglerLabel.BackgroundTransparency = 1
        anglerLabel.AnchorPoint = Vector2.new(0.5, 0)
        anglerLabel.Position = UDim2.new(0.5, 0, 0, 110)
        anglerLabel.Size = UDim2.new(0, 620, 0, 40)
        anglerLabel.Font = Enum.Font.GothamBlack
        anglerLabel.TextColor3 = Color3.fromRGB(255, 70, 70)
        anglerLabel.TextStrokeTransparency = 0.25
        anglerLabel.TextScaled = true
        anglerLabel.Visible = false
        anglerLabel.Parent = gui

        return true
    end

    local function resolveHudState()
        local passwordText
        local hasClosedDoor = false
        local hasOpenedDoor = false
        local detectedAnglers = 0

        for target, targetData in pairs(getTrackedTargets()) do
            if not target or not target.Parent then
                -- ignore stale entries; tracker loop will clean these up
            elseif targetData.kind == "password" and targetData.password and targetData.password ~= "????" then
                passwordText = targetData.password
            elseif targetData.kind == "door" then
                if targetData.isDoorOpened then
                    hasOpenedDoor = true
                else
                    hasClosedDoor = true
                end
            elseif targetData.kind == "angler" then
                detectedAnglers = detectedAnglers + 1
            end
        end

        local shouldShowPassword = passwordText and hasClosedDoor and not hasOpenedDoor
        local shouldShowAnglerWarning = detectedAnglers > 0

        return shouldShowPassword, passwordText, shouldShowAnglerWarning, detectedAnglers
    end

    function Hud.start()
        if heartbeatConnection then
            return
        end

        heartbeatConnection = RunService.Heartbeat:Connect(function()
            if not ensureGui() then
                return
            end

            local shouldShowPassword, passwordText, shouldShowAnglerWarning, detectedAnglers = resolveHudState()

            passwordLabel.Visible = shouldShowPassword
            if shouldShowPassword then
                passwordLabel.Text = "ROOM PASSWORD: " .. passwordText
            end

            anglerLabel.Visible = shouldShowAnglerWarning
            if shouldShowAnglerWarning then
                anglerLabel.Text = "ANGLER WARNING: " .. tostring(detectedAnglers) .. " threat(s) nearby"
            end
        end)
    end

    function Hud.stop()
        if heartbeatConnection then
            heartbeatConnection:Disconnect()
            heartbeatConnection = nil
        end

        if gui and gui.Parent then
            gui:Destroy()
        end

        gui = nil
        passwordLabel = nil
        anglerLabel = nil
    end

    return Hud
end
