local ItemEsp = _G.offlineservice("ItemEsp")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ESP_ENABLED_KEY = "itemEspEnabled"
local AUTO_PICKUP_ENABLED_KEY = "itemAutoPickupEnabled"
local REMOTE_USE_ENABLED_KEY = "remoteUseEnabled"

local ITEM_COLORS = {
    default = Color3.fromRGB(0, 255, 255),
    locker = Color3.fromRGB(0, 160, 255),
    paper = Color3.fromRGB(255, 100, 255),
    generator = Color3.fromRGB(255, 255, 0),
    door = Color3.fromRGB(255, 255, 0),
}

local AUTO_PICKUP_INTERVAL = 0.2

local ItemEspUtils = _G.fetch("mods/ItemEsp/utils.lua")
local buildClassifier = _G.fetch("mods/ItemEsp/classifier.lua")

if not ItemEspUtils or not buildClassifier then
    warn("ItemEsp failed to load helper files")
    return ItemEsp
end

local classifyTarget = buildClassifier({
    ITEM_COLORS = ITEM_COLORS,
    findPrompt = ItemEspUtils.findPrompt,
    getPaperPassword = ItemEspUtils.getPaperPassword,
})

local trackedTargets = {}
local activeVisuals = {}
local promptStateConnections = {}
local autoPickupConnection
local workspaceAddedConnection
local workspaceRemovingConnection

local function disconnectConnections(connectionMap)
    for key, entry in pairs(connectionMap) do
        local connection = entry and entry.connection or entry
        if connection and connection.Disconnect then
            connection:Disconnect()
        end
        connectionMap[key] = nil
    end
end

local function destroyVisual(target)
    local visuals = activeVisuals[target]
    if not visuals then
        return
    end

    if visuals.clickConnection and visuals.clickConnection.Disconnect then
        visuals.clickConnection:Disconnect()
    end

    if visuals.overlayConnection and visuals.overlayConnection.Disconnect then
        visuals.overlayConnection:Disconnect()
    end

    if visuals.overlayGui and visuals.overlayGui.Parent then
        visuals.overlayGui:Destroy()
    end

    if visuals.billboard and visuals.billboard.Parent then
        visuals.billboard:Destroy()
    end

    if visuals.highlight and visuals.highlight.Parent then
        visuals.highlight:Destroy()
    end

    activeVisuals[target] = nil
end

local function teleportToTarget(target)
    local localPlayer = Players.LocalPlayer
    local character = localPlayer and localPlayer.Character
    if not character then
        return
    end

    local root = character:FindFirstChild("HumanoidRootPart")
    local targetPart = ItemEspUtils.getPrimaryPart(target)
    if not root or not targetPart then
        return
    end

    character:PivotTo(CFrame.new(targetPart.Position + Vector3.new(0, 3, 0)))
end

local function createTeleportOverlay(targetData)
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
        if not _G.getSetting(ESP_ENABLED_KEY, false) or not targetData.instance or not targetData.instance.Parent then
            screenGui.Enabled = false
            return
        end

        local refreshedAdornee = ItemEspUtils.getPrimaryPart(targetData.instance)
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
        teleportToTarget(targetData.instance)
    end)

    return screenGui, overlayConnection, clickConnection
end

local function createVisual(targetData)
    local target = targetData.instance
    if activeVisuals[target] then
        return
    end

    local adornee = ItemEspUtils.getPrimaryPart(target)
    if not adornee then
        return
    end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESP_Tag"
    billboard.Adornee = adornee
    billboard.Size = UDim2.new(0, 200, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 2.3, 0)
    billboard.AlwaysOnTop = true
    billboard.ResetOnSpawn = false
    billboard.Active = true
    billboard.Parent = target

    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 1, 0)
    label.Font = Enum.Font.GothamBold
    label.Text = targetData.label
    label.TextColor3 = targetData.color
    label.TextStrokeTransparency = 0.5
    label.TextSize = 14
    label.TextScaled = false
    label.TextWrapped = false
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.Active = true
    label.Parent = billboard

    local highlight = Instance.new("Highlight")
    highlight.Name = "ItemEspHighlight"
    highlight.Adornee = target
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = targetData.color
    highlight.FillTransparency = 0.7
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.OutlineTransparency = 0.5
    highlight.Parent = target

    local overlayGui, overlayConnection, clickConnection = createTeleportOverlay(targetData)

    activeVisuals[target] = {
        billboard = billboard,
        highlight = highlight,
        overlayGui = overlayGui,
        overlayConnection = overlayConnection,
        clickConnection = clickConnection,
    }
end

local function refreshVisual(targetData)
    local visuals = activeVisuals[targetData.instance]
    if not visuals then
        return
    end

    if visuals.billboard and visuals.billboard:FindFirstChild("Label") then
        visuals.billboard.Label.Text = targetData.label
        visuals.billboard.Label.TextColor3 = targetData.color
    end

    if visuals.highlight then
        visuals.highlight.FillColor = targetData.color
    end
end

local function applyEspState(targetData)
    if _G.getSetting(ESP_ENABLED_KEY, false) then
        createVisual(targetData)
        refreshVisual(targetData)
    else
        destroyVisual(targetData.instance)
    end
end

local function applyRemotePromptState(targetData)
    local prompt = targetData.prompt
    if not prompt or not prompt.Parent or not targetData.originalPromptState then
        return
    end

    local originalState = targetData.originalPromptState
    if _G.getSetting(REMOTE_USE_ENABLED_KEY, false) and targetData.allowRemoteUse then
        prompt.RequiresLineOfSight = false
        prompt.MaxActivationDistance = originalState.maxActivationDistance
        prompt.HoldDuration = 0
    else
        prompt.RequiresLineOfSight = originalState.requiresLineOfSight
        prompt.MaxActivationDistance = originalState.maxActivationDistance
        prompt.HoldDuration = originalState.holdDuration
    end
end

local function forgetTarget(target)
    local tracked = trackedTargets[target]
    if tracked then
        applyRemotePromptState(tracked)
    end

    trackedTargets[target] = nil
    destroyVisual(target)

    local entry = promptStateConnections[target]
    local connection = entry and entry.connection or entry
    if connection and connection.Disconnect then
        connection:Disconnect()
    end
    promptStateConnections[target] = nil
end

local function triggerPrompt(prompt)
    if not prompt or not prompt.Parent or not prompt.Enabled then
        return false
    end

    if typeof(fireproximityprompt) == "function" then
        return pcall(function()
            fireproximityprompt(prompt, 0, true)
        end)
    end

    return false
end

local function attachPromptWatcher(targetData)
    if not targetData.prompt then
        return
    end

    local existingEntry = promptStateConnections[targetData.id]
    if existingEntry and existingEntry.prompt == targetData.prompt then
        return
    end

    if existingEntry and existingEntry.connection and existingEntry.connection.Disconnect then
        existingEntry.connection:Disconnect()
    end

    promptStateConnections[targetData.id] = {
        prompt = targetData.prompt,
        connection = targetData.prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
            local refreshed = classifyTarget(targetData.instance, trackedTargets)
            if not refreshed then
                forgetTarget(targetData.id)
                return
            end

            trackedTargets[targetData.id] = refreshed
            applyEspState(refreshed)
            applyRemotePromptState(refreshed)
            attachPromptWatcher(refreshed)
        end),
    }
end

local function refreshTarget(instance)
    local targetData = classifyTarget(instance, trackedTargets)
    if not targetData then
        return
    end

    trackedTargets[targetData.id] = targetData
    applyEspState(targetData)
    applyRemotePromptState(targetData)
    attachPromptWatcher(targetData)
end

local function scanWorkspace()
    for _, descendant in ipairs(Workspace:GetDescendants()) do
        refreshTarget(descendant)
    end
end

local function syncTargets()
    for target, targetData in pairs(trackedTargets) do
        if not target or not target.Parent then
            forgetTarget(target)
        else
            local refreshed = classifyTarget(targetData.instance, trackedTargets)
            if refreshed then
                trackedTargets[target] = refreshed
                applyEspState(refreshed)
                applyRemotePromptState(refreshed)
                attachPromptWatcher(refreshed)
            else
                forgetTarget(target)
            end
        end
    end
end

local function startAutoPickupLoop()
    if autoPickupConnection then
        return
    end

    local elapsed = 0
    autoPickupConnection = RunService.Heartbeat:Connect(function(deltaTime)
        elapsed = elapsed + deltaTime
        if elapsed < AUTO_PICKUP_INTERVAL then
            return
        end
        elapsed = 0

        if not _G.getSetting(AUTO_PICKUP_ENABLED_KEY, false) then
            return
        end

        for target, targetData in pairs(trackedTargets) do
            if not target or not target.Parent then
                forgetTarget(target)
            elseif targetData.shouldAutoPickup
                and targetData.prompt
                and ItemEspUtils.isWithinPromptDistance(targetData.instance, targetData.prompt)
                and ItemEspUtils.isPromptVisible(targetData.instance) then
                triggerPrompt(targetData.prompt)
            end
        end
    end)
end

local function stopAutoPickupLoop()
    if autoPickupConnection then
        autoPickupConnection:Disconnect()
        autoPickupConnection = nil
    end
end

function ItemEsp:enableTracking()
    scanWorkspace()
    syncTargets()
    startAutoPickupLoop()

    if not workspaceAddedConnection then
        workspaceAddedConnection = Workspace.DescendantAdded:Connect(function(descendant)
            task.defer(refreshTarget, descendant)
        end)
    end

    if not workspaceRemovingConnection then
        workspaceRemovingConnection = Workspace.DescendantRemoving:Connect(function(descendant)
            if trackedTargets[descendant] then
                forgetTarget(descendant)
            elseif descendant.Name == "ProxyPart" and descendant.Parent and trackedTargets[descendant.Parent] then
                forgetTarget(descendant.Parent)
            end
        end)
    end
end

function ItemEsp:disableTracking()
    if workspaceAddedConnection then
        workspaceAddedConnection:Disconnect()
        workspaceAddedConnection = nil
    end

    if workspaceRemovingConnection then
        workspaceRemovingConnection:Disconnect()
        workspaceRemovingConnection = nil
    end

    stopAutoPickupLoop()

    for target, targetData in pairs(trackedTargets) do
        if target and target.Parent then
            applyRemotePromptState(targetData)
        end
    end

    disconnectConnections(promptStateConnections)

    for target in pairs(activeVisuals) do
        destroyVisual(target)
    end

    trackedTargets = {}
end

function ItemEsp:syncRemoteUseState()
    for target, targetData in pairs(trackedTargets) do
        if not target or not target.Parent then
            forgetTarget(target)
        else
            applyRemotePromptState(targetData)
        end
    end
end

function ItemEsp:disable()
    self:disableTracking()
end

function ItemEsp:kill()
    self:setState(ESP_ENABLED_KEY, false)
    self:setState(AUTO_PICKUP_ENABLED_KEY, false)
    self:setState(REMOTE_USE_ENABLED_KEY, false)
    _G.updateSettings(ESP_ENABLED_KEY, false)
    _G.updateSettings(AUTO_PICKUP_ENABLED_KEY, false)
    _G.updateSettings(REMOTE_USE_ENABLED_KEY, false)
    self:disableTracking()
end

ItemEsp:registerToggle({
    id = "ItemEspToggle",
    settingKey = ESP_ENABLED_KEY,
    keybindKey = "itemEspKeybind",
    defaultKeybind = "F12",
    onToggle = function()
        ItemEsp:enableTracking()
        syncTargets()
    end,
})

ItemEsp:registerToggle({
    id = "ItemAutoPickupToggle",
    settingKey = AUTO_PICKUP_ENABLED_KEY,
    keybindKey = "itemAutoPickupKeybind",
    defaultKeybind = "J",
    onToggle = function()
        ItemEsp:enableTracking()
    end,
})

ItemEsp:registerToggle({
    id = "RemoteUseToggle",
    settingKey = REMOTE_USE_ENABLED_KEY,
    keybindKey = "remoteUseKeybind",
    defaultKeybind = "K",
    onToggle = function()
        ItemEsp:enableTracking()
        ItemEsp:syncRemoteUseState()
    end,
})

return ItemEsp
