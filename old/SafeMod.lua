-- Safe.lua
local Safe = _G.offlineservice("Safe")

local RunService = _G.services.RunService
local Player = _G.services.Players.LocalPlayer

_G.state.settings.safeHeightEnabled = false
_G.UI.createButton("safeHeightEnabled")
_G.UI.addEventHandler("safeHeightEnabled", function(enabled)
    if not enabled then
        Safe.toggleSafeMode(false)
    end
end)
_G.UI.addStopHandler(function() Safe.toggleSafeMode(false) end)

-- Safe mode toggle
function Safe.toggleSafeMode(enable)
    local char = Player and Player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChild("Humanoid")
    if not root or not hum then return end

    if enable then
        if not _G.state.safeModeActive then
            _G.state.originalCFrame = root.CFrame
            _G.state.safeModeActive = true

            hum.PlatformStand = true

            _G.state.bodyVel = Instance.new("BodyVelocity")
            _G.state.bodyVel.MaxForce = Vector3.new(1e9, 1e9, 1e9)
            _G.state.bodyVel.Velocity = Vector3.zero
            _G.state.bodyVel.Parent = root

            _G.state.bodyGyro = Instance.new("BodyGyro")
            _G.state.bodyGyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
            _G.state.bodyGyro.CFrame = root.CFrame
            _G.state.bodyGyro.Parent = root

            root.CFrame = CFrame.new(root.Position.X, 200, root.Position.Z)
        end
    else
        if _G.state.safeModeActive then
            _G.state.safeModeActive = false
            hum.PlatformStand = false

            if _G.state.bodyVel then
                _G.state.bodyVel:Destroy()
                _G.state.bodyVel = nil
            end

            if _G.state.bodyGyro then
                _G.state.bodyGyro:Destroy()
                _G.state.bodyGyro = nil
            end

            if _G.state.originalCFrame then
                root.CFrame = _G.state.originalCFrame + Vector3.new(0, 3, 0)
                _G.state.originalCFrame = nil
            end

            root.AssemblyLinearVelocity = Vector3.zero
        end
    end
end

-- Heartbeat monitor
local heartbeatConn

heartbeatConn = RunService.Heartbeat:Connect(function()
    if not _G.state.running then return end

    local dangerList = {}
    for part, active in pairs(_G.state.dangerousParts) do
        if active and part and part.Parent then
            table.insert(dangerList, part.Name)
        end
    end

    local UI = _G.UI
    if UI and UI.setWarningText then
        if #dangerList > 0 then
            UI.setWarningText(
                "danger",
                "⚠️ NGUY HIỂM: " .. table.concat(dangerList, ", ")
            )
        else
            UI.setWarningText("danger", nil)
        end
    end

    if _G.state.settings.safeHeightEnabled and #dangerList > 0 then
        Safe.toggleSafeMode(true)
    else
        Safe.toggleSafeMode(false)
    end
end)

table.insert(_G.state.connections, heartbeatConn)
