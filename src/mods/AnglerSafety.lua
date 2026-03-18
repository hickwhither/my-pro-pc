local AnglerSafety = _G.offlineservice("AnglerSafety")

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local ESP_ENABLED_KEY = "anglerSafetyEspEnabled"
local SAFE_TP_ENABLED_KEY = "anglerSafetySafeTpEnabled"
local WATCH_NAMES = {
    angler = true,
    froger = true,
    pinkie = true,
    blitz = true,
    chainsmoker = true,
}

local workspaceAddedConnection
local workspaceRemovingConnection
local trackedEntities = {}
local highlightedEntities = {}
local teleportedEntities = {}

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

local function getCharacterRoot()
    local player = Players.LocalPlayer
    return player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end

local function resolveAdornee(target)
    if target:IsA("BasePart") then
        return target
    end

    if target:IsA("Model") then
        return target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart", true)
    end
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

local function clearEsp(entity)
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

local function getLockerPosition(locker)
    if locker:IsA("Model") then
        local proxyPart = locker:FindFirstChild("ProxyPart", true)
        if proxyPart and proxyPart:IsA("BasePart") then
            return proxyPart.Position
        end

        local part = locker.PrimaryPart or locker:FindFirstChildWhichIsA("BasePart", true)
        if part then
            return part.Position
        end
    elseif locker:IsA("BasePart") then
        return locker.Position
    end

    return nil
end

local function findNearestLocker(origin)
    local nearestLocker
    local nearestDistance

    for _, descendant in ipairs(Workspace:GetDescendants()) do
        if descendant.Name == "Locker" then
            local lockerPosition = getLockerPosition(descendant)
            if lockerPosition then
                local distance = (lockerPosition - origin).Magnitude
                if not nearestDistance or distance < nearestDistance then
                    nearestDistance = distance
                    nearestLocker = descendant
                end
            end
        end
    end

    return nearestLocker
end

local function teleportToSafeLocker(entity)
    if teleportedEntities[entity] then
        return
    end

    local rootPart = getCharacterRoot()
    if not rootPart then
        return
    end

    local locker = findNearestLocker(rootPart.Position)
    if not locker then
        warn("[AnglerSafety] No locker found for safe teleport")
        return
    end

    local lockerPosition = getLockerPosition(locker)
    if not lockerPosition then
        return
    end

    rootPart.CFrame = CFrame.new(lockerPosition + Vector3.new(0, 3, 0))
    teleportedEntities[entity] = true
end

local function refreshEntity(entity)
    if not entity or not entity.Parent then
        clearEsp(entity)
        trackedEntities[entity] = nil
        teleportedEntities[entity] = nil
        return
    end

    trackedEntities[entity] = true

    if _G.getSetting(ESP_ENABLED_KEY, false) then
        createEsp(entity)
    else
        clearEsp(entity)
    end

    if _G.getSetting(SAFE_TP_ENABLED_KEY, false) then
        teleportToSafeLocker(entity)
    end
end

local function scanWorkspace()
    for _, descendant in ipairs(Workspace:GetDescendants()) do
        if matchesAnglerEntity(descendant) then
            refreshEntity(descendant)
        end
    end
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
            teleportedEntities[descendant] = nil
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

    for entity in pairs(highlightedEntities) do
        clearEsp(entity)
    end

    table.clear(trackedEntities)
    table.clear(teleportedEntities)
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
            for entity in pairs(highlightedEntities) do
                clearEsp(entity)
            end
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
            scanWorkspace()
        else
            table.clear(teleportedEntities)
            stopWatcherIfUnused()
        end
    end,
})

return AnglerSafety
