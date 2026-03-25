local AnglerSafety = _G.offlineservice("AnglerSafety")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ESP_ENABLED_KEY = "anglerSafetyEspEnabled"
local SAFE_TP_ENABLED_KEY = "anglerSafetySafeTpEnabled"
local SAFE_HEIGHT = 200
local WATCH_NAMES = {
    angler = true,
    froger = true,
    pinkie = true,
    blitz = true,
    chainsmoker = true,
}

local workspaceAddedConnection
local workspaceRemovingConnection
local heartbeatConnection
local trackedEntities = {}
local highlightedEntities = {}
local clearEsp
local safeModeState = {
    active = false,
    originalCFrame = nil,
    originalAnchored = nil,
}

local function matchesAnglerEntity(instance)
    if not instance or instance:IsA("Attachment") or instance:IsA("Beam") then
        return false
    end

    local lowerName = string.lower(instance.Name or "")
    for fragment in pairs(WATCH_NAMES) do
        if string.find(lowerName, fragment, 1, true) then
            return true
        end
    end

    return false
end

local function getCharacterParts()
    local player = Players.LocalPlayer
    local character = player and player.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")

    return character, rootPart, humanoid
end

local function resolveAdornee(target)
    if target:IsA("BasePart") then
        return target
    end

    if target:IsA("Model") then
        return target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart", true)
    end
end

local function hasDangerousEntity()
    for entity in pairs(trackedEntities) do
        if entity and entity.Parent then
            return true
        end

        trackedEntities[entity] = nil
        clearEsp(entity)
    end

    return false
end

local function createEsp(entity)
    if highlightedEntities[entity] then
        return
    end

    local adornee = resolveAdornee(entity)
    if not adornee then
        return
    end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "AnglerSafetyTag"
    billboard.Adornee = adornee
    billboard.Size = UDim2.new(0, 220, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 4, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = entity

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Font = Enum.Font.GothamBold
    label.Text = "ANGLER: " .. entity.Name
    label.TextColor3 = Color3.fromRGB(255, 90, 90)
    label.TextStrokeTransparency = 0.5
    label.TextScaled = true
    label.Parent = billboard

    local highlight = Instance.new("Highlight")
    highlight.Name = "AnglerSafetyHighlight"
    highlight.Adornee = entity
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = Color3.fromRGB(255, 0, 0)
    highlight.FillTransparency = 0.7
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.OutlineTransparency = 0.2
    highlight.Parent = entity

    highlightedEntities[entity] = {
        billboard = billboard,
        highlight = highlight,
    }
end

clearEsp = function(entity)
    local visuals = highlightedEntities[entity]
    if not visuals then
        return
    end

    if visuals.billboard and visuals.billboard.Parent then
        visuals.billboard:Destroy()
    end

    if visuals.highlight and visuals.highlight.Parent then
        visuals.highlight:Destroy()
    end

    highlightedEntities[entity] = nil
end

local function clearAllEsp()
    for entity in pairs(highlightedEntities) do
        clearEsp(entity)
    end
end

local function enableSafeHeightMode()
    if safeModeState.active then
        return
    end

    local _, rootPart, humanoid = getCharacterParts()
    if not rootPart or not humanoid then
        return
    end

    safeModeState.originalCFrame = rootPart.CFrame
    safeModeState.originalAnchored = rootPart.Anchored
    safeModeState.active = true

    humanoid.PlatformStand = true
    rootPart.Anchored = true
    rootPart.CFrame = CFrame.new(rootPart.Position.X, SAFE_HEIGHT, rootPart.Position.Z)
    rootPart.AssemblyLinearVelocity = Vector3.zero
    rootPart.AssemblyAngularVelocity = Vector3.zero
end

local function disableSafeHeightMode()
    if not safeModeState.active then
        return
    end

    local _, rootPart, humanoid = getCharacterParts()
    safeModeState.active = false

    if humanoid then
        humanoid.PlatformStand = false
    end

    if rootPart then
        if safeModeState.originalCFrame then
            rootPart.CFrame = safeModeState.originalCFrame + Vector3.new(0, 3, 0)
        end

        if safeModeState.originalAnchored ~= nil then
            rootPart.Anchored = safeModeState.originalAnchored
        else
            rootPart.Anchored = false
        end

        rootPart.AssemblyLinearVelocity = Vector3.zero
        rootPart.AssemblyAngularVelocity = Vector3.zero
    end

    safeModeState.originalCFrame = nil
    safeModeState.originalAnchored = nil
end

local function refreshEntity(entity)
    if not entity or not entity.Parent then
        clearEsp(entity)
        trackedEntities[entity] = nil
        return
    end

    trackedEntities[entity] = true

    if _G.getSetting(ESP_ENABLED_KEY, false) then
        createEsp(entity)
    else
        clearEsp(entity)
    end
end

local function scanWorkspace()
    for _, descendant in ipairs(Workspace:GetDescendants()) do
        if matchesAnglerEntity(descendant) then
            refreshEntity(descendant)
        end
    end
end

local function ensureHeartbeat()
    if heartbeatConnection then
        return
    end

    heartbeatConnection = RunService.Heartbeat:Connect(function()
        local shouldUseSafeMode = _G.getSetting(SAFE_TP_ENABLED_KEY, false) and hasDangerousEntity()
        if shouldUseSafeMode then
            enableSafeHeightMode()
        else
            disableSafeHeightMode()
        end
    end)
end

local function ensureWatcher()
    if workspaceAddedConnection then
        return
    end

    workspaceAddedConnection = Workspace.DescendantAdded:Connect(function(descendant)
        if matchesAnglerEntity(descendant) then
            task.defer(function()
                refreshEntity(descendant)
            end)
        end
    end)

    workspaceRemovingConnection = Workspace.DescendantRemoving:Connect(function(descendant)
        if trackedEntities[descendant] or highlightedEntities[descendant] then
            clearEsp(descendant)
            trackedEntities[descendant] = nil
        end
    end)

    scanWorkspace()
end

local function stopWatcherIfUnused()
    if _G.getSetting(ESP_ENABLED_KEY, false) or _G.getSetting(SAFE_TP_ENABLED_KEY, false) then
        return
    end

    if workspaceAddedConnection then
        workspaceAddedConnection:Disconnect()
        workspaceAddedConnection = nil
    end

    if workspaceRemovingConnection then
        workspaceRemovingConnection:Disconnect()
        workspaceRemovingConnection = nil
    end

    if heartbeatConnection then
        heartbeatConnection:Disconnect()
        heartbeatConnection = nil
    end

    clearAllEsp()
    disableSafeHeightMode()
    table.clear(trackedEntities)
end

function AnglerSafety:disable()
    clearAllEsp()
    disableSafeHeightMode()
    stopWatcherIfUnused()
end

function AnglerSafety:kill()
    self:setState(ESP_ENABLED_KEY, false)
    self:setState(SAFE_TP_ENABLED_KEY, false)
    _G.updateSettings(ESP_ENABLED_KEY, false)
    _G.updateSettings(SAFE_TP_ENABLED_KEY, false)
    stopWatcherIfUnused()
end

AnglerSafety:registerToggle({
    id = "AnglerSafetyEspToggle",
    settingKey = ESP_ENABLED_KEY,
    keybindKey = "anglerSafetyEspKeybind",
    defaultKeybind = "F10",
    onToggle = function(enabled)
        if enabled then
            ensureWatcher()
            scanWorkspace()
        else
            clearAllEsp()
            stopWatcherIfUnused()
        end
    end,
})

AnglerSafety:registerToggle({
    id = "AnglerSafetySafeTpToggle",
    settingKey = SAFE_TP_ENABLED_KEY,
    keybindKey = "anglerSafetySafeTpKeybind",
    defaultKeybind = "F11",
    onToggle = function(enabled)
        if enabled then
            ensureWatcher()
            ensureHeartbeat()
            scanWorkspace()
        else
            disableSafeHeightMode()
            stopWatcherIfUnused()
        end
    end,
})

return AnglerSafety
