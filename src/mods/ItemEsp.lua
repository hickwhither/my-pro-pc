local ItemEsp = _G.offlineservice("ItemEsp")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ESP_ENABLED_KEY = "itemEspEnabled"
local AUTO_PICKUP_ENABLED_KEY = "itemAutoPickupEnabled"
local REMOTE_USE_ENABLED_KEY = "remoteUseEnabled"

local KEYCARD_COLOR = Color3.fromRGB(0, 255, 255)
local PAPER_COLOR = Color3.fromRGB(255, 100, 255)
local GENERATOR_COLOR = Color3.fromRGB(255, 255, 0)
local REMOTE_DISTANCE = 9999
local AUTO_PICKUP_INTERVAL = 0.2

local trackedTargets = {}
local activeVisuals = {}
local autoPickupConnection
local workspaceAddedConnection
local workspaceRemovingConnection
local promptStateConnections = {}

local function disconnectConnections(connectionMap)
    for key, connection in pairs(connectionMap) do
        if connection and connection.Disconnect then
            connection:Disconnect()
        end
        connectionMap[key] = nil
    end
end

local function getCharacterRoot()
    local player = Players.LocalPlayer
    local character = player and player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function getPrimaryPart(target)
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
end

local function findPrompt(target)
    if not target then
        return nil
    end

    if target:IsA("ProximityPrompt") then
        return target
    end

    return target:FindFirstChildWhichIsA("ProximityPrompt", true)
end

local function getPaperPassword(target)
    local codePart = target and target:FindFirstChild("Code", true)
    local surfaceGui = codePart and codePart:FindFirstChild("SurfaceGui")
    local label = surfaceGui and surfaceGui:FindFirstChild("TextLabel")
    local text = label and label.Text

    if text and text ~= "" then
        return text
    end

    return "????"
end

local function buildTargetData(target, prompt, kind, color, label, shouldAutoPickup)
    return {
        id = target,
        instance = target,
        prompt = prompt,
        kind = kind,
        color = color,
        label = label,
        shouldAutoPickup = shouldAutoPickup,
        allowRemoteUse = true,
        originalPromptState = {
            maxActivationDistance = prompt.MaxActivationDistance,
            requiresLineOfSight = prompt.RequiresLineOfSight,
            holdDuration = prompt.HoldDuration,
        },
    }
end

local function classifyTarget(instance)
    if not instance or instance:IsA("Attachment") or instance:IsA("Beam") then
        return nil
    end

    local name = instance.Name or ""

    if name == "PasswordPaper" then
        local prompt = findPrompt(instance)
        if prompt and prompt.Enabled then
            return buildTargetData(
                instance,
                prompt,
                "paper",
                PAPER_COLOR,
                "Pass: " .. getPaperPassword(instance),
                true
            )
        end

        return nil
    end

    if string.find(name, "KeyCard", 1, true) then
        local proxy = instance:FindFirstChild("ProxyPart", true)
        local prompt = findPrompt(proxy)
        if proxy and prompt and prompt.Enabled then
            return buildTargetData(instance, prompt, "keycard", KEYCARD_COLOR, name, true)
        end

        return nil
    end

    if name == "Generator" then
        local prompt = findPrompt(instance)
        if prompt and prompt.Enabled then
            return buildTargetData(instance, prompt, "generator", GENERATOR_COLOR, "Generator", false)
        end

        return nil
    end

    return nil
end

local function destroyVisual(target)
    local visuals = activeVisuals[target]
    if not visuals then
        return
    end

    if visuals.billboard and visuals.billboard.Parent then
        visuals.billboard:Destroy()
    end

    if visuals.highlight and visuals.highlight.Parent then
        visuals.highlight:Destroy()
    end

    activeVisuals[target] = nil
end

local function createVisual(targetData)
    local target = targetData.instance
    if activeVisuals[target] then
        return
    end

    local adornee = getPrimaryPart(target)
    if not adornee then
        return
    end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ItemEspTag"
    billboard.Adornee = adornee
    billboard.Size = UDim2.new(0, 220, 0, 44)
    billboard.StudsOffset = Vector3.new(0, 2.5, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = target

    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Font = Enum.Font.GothamBold
    label.Text = targetData.label
    label.TextColor3 = targetData.color
    label.TextStrokeTransparency = 0.45
    label.TextScaled = true
    label.Parent = billboard

    local highlight = Instance.new("Highlight")
    highlight.Name = "ItemEspHighlight"
    highlight.Adornee = target
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = targetData.color
    highlight.FillTransparency = 0.72
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.OutlineTransparency = 0.25
    highlight.Parent = target

    activeVisuals[target] = {
        billboard = billboard,
        highlight = highlight,
    }
end

local function refreshVisual(targetData)
    local visuals = activeVisuals[targetData.instance]
    if visuals and visuals.billboard and visuals.billboard:FindFirstChild("Label") then
        visuals.billboard.Label.Text = targetData.label
        visuals.billboard.Label.TextColor3 = targetData.color
    end

    if visuals and visuals.highlight then
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
    if not prompt or not prompt.Parent then
        return
    end

    local originalState = targetData.originalPromptState
    if _G.getSetting(REMOTE_USE_ENABLED_KEY, false) and targetData.allowRemoteUse then
        prompt.RequiresLineOfSight = false
        prompt.MaxActivationDistance = REMOTE_DISTANCE
        prompt.HoldDuration = 0
    elseif originalState then
        prompt.RequiresLineOfSight = originalState.requiresLineOfSight
        prompt.MaxActivationDistance = originalState.maxActivationDistance
        prompt.HoldDuration = originalState.holdDuration
    end
end

local function forgetTarget(target)
    trackedTargets[target] = nil
    destroyVisual(target)

    local connection = promptStateConnections[target]
    if connection and connection.Disconnect then
        connection:Disconnect()
    end
    promptStateConnections[target] = nil
end

local function canSeeTarget(target)
    local root = getCharacterRoot()
    local part = getPrimaryPart(target)
    local camera = Workspace.CurrentCamera
    if not root or not part or not camera then
        return false
    end

    local viewportPoint, onScreen = camera:WorldToViewportPoint(part.Position)
    if not onScreen or viewportPoint.Z <= 0 then
        return false
    end

    local direction = part.Position - camera.CFrame.Position
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = {
        Players.LocalPlayer.Character,
    }

    local result = Workspace:Raycast(camera.CFrame.Position, direction, params)
    return result == nil or result.Instance:IsDescendantOf(target)
end

local function triggerPrompt(prompt)
    if not prompt or not prompt.Parent or not prompt.Enabled then
        return false
    end

    if typeof(fireproximityprompt) == "function" then
        pcall(function()
            fireproximityprompt(prompt)
        end)
        return true
    end

    return false
end

local function refreshTarget(instance)
    local targetData = classifyTarget(instance)
    if not targetData then
        return
    end

    trackedTargets[targetData.id] = targetData
    applyEspState(targetData)
    applyRemotePromptState(targetData)

    if promptStateConnections[targetData.id] then
        return
    end

    promptStateConnections[targetData.id] = targetData.prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
        local refreshed = classifyTarget(targetData.instance)
        if not refreshed then
            forgetTarget(targetData.id)
            return
        end

        trackedTargets[targetData.id] = refreshed
        applyEspState(refreshed)
        applyRemotePromptState(refreshed)
    end)
end

local function scanWorkspace()
    for _, descendant in ipairs(Workspace:GetDescendants()) do
        refreshTarget(descendant)
    end
end

local function syncEsp()
    for target, targetData in pairs(trackedTargets) do
        if not target or not target.Parent then
            forgetTarget(target)
        else
            local refreshed = classifyTarget(targetData.instance)
            if refreshed then
                trackedTargets[target] = refreshed
                applyEspState(refreshed)
                applyRemotePromptState(refreshed)
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
            elseif targetData.shouldAutoPickup and canSeeTarget(targetData.instance) then
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
    syncEsp()
    startAutoPickupLoop()

    if not workspaceAddedConnection then
        workspaceAddedConnection = Workspace.DescendantAdded:Connect(function(descendant)
            task.defer(function()
                refreshTarget(descendant)
            end)
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

    for _, targetData in pairs(trackedTargets) do
        applyRemotePromptState(targetData)
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
        syncEsp()
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
