local PlayerEsp = _G.offlineservice("PlayerEsp")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ESP_ENABLED_KEY = "playerEspEnabled"
local trackedPlayers = {}

local playerAddedConnection
local playerRemovingConnection

local function getTargetRoot(player)
    local character = player and player.Character
    if not character then
        return nil
    end

    return character:FindFirstChild("HumanoidRootPart")
        or character:FindFirstChild("UpperTorso")
        or character:FindFirstChildWhichIsA("BasePart")
end

local function getLocalRoot()
    local localPlayer = Players.LocalPlayer
    local character = localPlayer and localPlayer.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function destroyVisual(player)
    local tracked = trackedPlayers[player]
    if not tracked then
        return
    end

    if tracked.clickConnection and tracked.clickConnection.Disconnect then
        tracked.clickConnection:Disconnect()
        tracked.clickConnection = nil
    end

    if tracked.overlayConnection and tracked.overlayConnection.Disconnect then
        tracked.overlayConnection:Disconnect()
        tracked.overlayConnection = nil
    end

    if tracked.overlayGui and tracked.overlayGui.Parent then
        tracked.overlayGui:Destroy()
    end

    if tracked.billboard and tracked.billboard.Parent then
        tracked.billboard:Destroy()
    end

    if tracked.highlight and tracked.highlight.Parent then
        tracked.highlight:Destroy()
    end

    tracked.billboard = nil
    tracked.highlight = nil
    tracked.overlayGui = nil
end

local function teleportToPlayer(player)
    local localRoot = getLocalRoot()
    local targetRoot = getTargetRoot(player)
    if not localRoot or not targetRoot then
        return
    end

    localRoot.CFrame = CFrame.new(targetRoot.Position + Vector3.new(0, 3, 0))
end

local function createTeleportOverlay(player)
    local localPlayer = Players.LocalPlayer
    local playerGui = localPlayer and localPlayer:FindFirstChild("PlayerGui")
    if not playerGui then
        return nil, nil, nil
    end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "PlayerEspTeleportOverlay"
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
        if not _G.getSetting(ESP_ENABLED_KEY, false) then
            screenGui.Enabled = false
            return
        end

        local targetRoot = getTargetRoot(player)
        if not targetRoot or not targetRoot.Parent then
            screenGui.Enabled = false
            return
        end

        local camera = Workspace.CurrentCamera
        if not camera then
            screenGui.Enabled = false
            return
        end

        local position, isVisible = camera:WorldToViewportPoint(targetRoot.Position + Vector3.new(0, 3, 0))
        if isVisible then
            screenGui.Enabled = true
            button.Position = UDim2.new(0, position.X, 0, position.Y)
        else
            screenGui.Enabled = false
        end
    end)

    local clickConnection = button.MouseButton1Click:Connect(function()
        teleportToPlayer(player)
    end)

    return screenGui, overlayConnection, clickConnection
end

local function createVisual(player)
    local tracked = trackedPlayers[player]
    if not tracked then
        return
    end

    destroyVisual(player)

    local character = player.Character
    local adornee = getTargetRoot(player)
    if not character or not adornee then
        return
    end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "PlayerEspTag"
    billboard.Adornee = adornee
    billboard.Size = UDim2.new(0, 200, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = character

    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Font = Enum.Font.GothamBold
    label.Text = "PLAYER: " .. player.Name
    label.TextColor3 = Color3.fromRGB(0, 255, 120)
    label.TextStrokeTransparency = 0.5
    label.TextScaled = true
    label.Parent = billboard

    local highlight = Instance.new("Highlight")
    highlight.Name = "PlayerEspHighlight"
    highlight.Adornee = character
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = Color3.fromRGB(0, 255, 120)
    highlight.FillTransparency = 0.75
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.OutlineTransparency = 0.25
    highlight.Parent = character

    tracked.billboard = billboard
    tracked.highlight = highlight
    tracked.overlayGui, tracked.overlayConnection, tracked.clickConnection = createTeleportOverlay(player)
end

local function refreshPlayer(player)
    local tracked = trackedPlayers[player]
    if not tracked then
        return
    end

    if _G.getSetting(ESP_ENABLED_KEY, false) then
        createVisual(player)
    else
        destroyVisual(player)
    end
end

local function trackPlayer(player)
    if player == Players.LocalPlayer then
        return
    end

    if trackedPlayers[player] then
        return
    end

    trackedPlayers[player] = {}

    trackedPlayers[player].characterAddedConnection = player.CharacterAdded:Connect(function()
        task.defer(refreshPlayer, player)
    end)

    refreshPlayer(player)
end

local function untrackPlayer(player)
    local tracked = trackedPlayers[player]
    if not tracked then
        return
    end

    destroyVisual(player)

    if tracked.characterAddedConnection and tracked.characterAddedConnection.Disconnect then
        tracked.characterAddedConnection:Disconnect()
        tracked.characterAddedConnection = nil
    end

    trackedPlayers[player] = nil
end

local function scanPlayers()
    for _, player in ipairs(Players:GetPlayers()) do
        trackPlayer(player)
    end
end

local function enableTracking()
    scanPlayers()

    if not playerAddedConnection then
        playerAddedConnection = Players.PlayerAdded:Connect(function(player)
            trackPlayer(player)
        end)
    end

    if not playerRemovingConnection then
        playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
            untrackPlayer(player)
        end)
    end

    for player in pairs(trackedPlayers) do
        refreshPlayer(player)
    end
end

local function disableTracking()
    if playerAddedConnection then
        playerAddedConnection:Disconnect()
        playerAddedConnection = nil
    end

    if playerRemovingConnection then
        playerRemovingConnection:Disconnect()
        playerRemovingConnection = nil
    end

    local playersToRemove = {}
    for player in pairs(trackedPlayers) do
        table.insert(playersToRemove, player)
    end

    for _, player in ipairs(playersToRemove) do
        untrackPlayer(player)
    end
end

function PlayerEsp:disable()
    disableTracking()
end

function PlayerEsp:kill()
    self:setState(ESP_ENABLED_KEY, false)
    _G.updateSettings(ESP_ENABLED_KEY, false)
    disableTracking()
end

PlayerEsp:registerToggle({
    id = "PlayerEspToggle",
    settingKey = ESP_ENABLED_KEY,
    keybindKey = "playerEspKeybind",
    defaultKeybind = "Y",
    onToggle = function()
        enableTracking()
    end,
})

return PlayerEsp
