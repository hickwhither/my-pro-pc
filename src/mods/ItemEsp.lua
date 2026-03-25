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

local REMOTE_DISTANCE = 9999
local AUTO_PICKUP_INTERVAL = 0.2
local AUTO_PICKUP_DISTANCE = 10

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

    return nil
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

local function getRoomNumber(room)
    if not room then
        return nil
    end

    local lights = room:FindFirstChild("Lights")
    if not lights then
        return nil
    end

    local numbers = {}
    for _, child in ipairs(lights:GetChildren()) do
        if child.Name == "Sign" then
            local surfaceGui = child:FindFirstChild("SurfaceGui")
            local textLabel = surfaceGui and surfaceGui:FindFirstChild("TextLabel")
            local number = tonumber(textLabel and textLabel.Text)
            if number then
                numbers[#numbers + 1] = number
            end
        end
    end

    if #numbers >= 2 then
        return math.floor((numbers[1] + numbers[2]) / 2)
    end

    return numbers[1]
end

local function findRoomAncestor(instance)
    local current = instance
    while current and current ~= Workspace do
        if current.Parent and current.Parent.Name == "Rooms" then
            return current
        end
        current = current.Parent
    end
    return nil
end

local function getRoomSuffix(instance)
    local room = findRoomAncestor(instance)
    local roomNumber = getRoomNumber(room)
    if roomNumber then
        return " [P." .. tostring(roomNumber) .. "]"
    end
    return ""
end

local function getDoorLabel(instance)
    local room = findRoomAncestor(instance)
    local roomNumber = getRoomNumber(room)
    return "Door [" .. tostring(roomNumber or "?") .. "]"
end

local function getOriginalPromptState(prompt, existingTarget)
    if existingTarget and existingTarget.originalPromptState then
        return existingTarget.originalPromptState
    end

    return {
        maxActivationDistance = prompt.MaxActivationDistance,
        requiresLineOfSight = prompt.RequiresLineOfSight,
        holdDuration = prompt.HoldDuration,
    }
end

local function buildTargetData(target, prompt, color, label, shouldAutoPickup, existingTarget)
    return {
        id = target,
        instance = target,
        prompt = prompt,
        color = color,
        label = label,
        shouldAutoPickup = shouldAutoPickup,
        allowRemoteUse = true,
        originalPromptState = getOriginalPromptState(prompt, existingTarget),
    }
end

local function classifyTarget(instance)
    if not instance or not instance.Parent or instance:IsA("Attachment") or instance:IsA("Beam") then
        return nil
    end

    local existingTarget = trackedTargets[instance]
    local name = instance.Name or ""
    local roomSuffix = getRoomSuffix(instance)

    if name == "Locker" then
        local prompt = findPrompt(instance)
        if prompt and prompt.Enabled then
            return buildTargetData(instance, prompt, ITEM_COLORS.locker, "Locker", false, existingTarget)
        end
        return nil
    end

    if name == "PasswordPaper" then
        local prompt = findPrompt(instance)
        if prompt and prompt.Enabled then
            return buildTargetData(
                instance,
                prompt,
                ITEM_COLORS.paper,
                "Pass: " .. getPaperPassword(instance) .. roomSuffix,
                true,
                existingTarget
            )
        end
        return nil
    end

    if string.find(name, "KeyCard", 1, true) then
        local prompt = findPrompt(instance)
        if prompt and prompt.Enabled then
            return buildTargetData(instance, prompt, ITEM_COLORS.default, name .. roomSuffix, true, existingTarget)
        end

        local proxy = instance:FindFirstChild("ProxyPart", true)
        prompt = findPrompt(proxy)
        if proxy and prompt and prompt.Enabled then
            return buildTargetData(instance, prompt, ITEM_COLORS.default, name .. roomSuffix, true, existingTarget)
        end
        return nil
    end

    if name == "Generator" then
        local prompt = findPrompt(instance)
        if prompt and prompt.Enabled then
            return buildTargetData(instance, prompt, ITEM_COLORS.generator, "Generator" .. roomSuffix, false, existingTarget)
        end
        return nil
    end

    if name == "ProxyPart" then
        local prompt = findPrompt(instance)
        if not prompt or not prompt.Enabled then
            return nil
        end

        local target = (instance.Parent and instance.Parent:IsA("Model")) and instance.Parent or instance
        if target ~= instance and string.find(target.Name or "", "KeyCard", 1, true) then
            return nil
        end

        return buildTargetData(target, prompt, ITEM_COLORS.default, (target.Name or "Item") .. roomSuffix, true, trackedTargets[target])
    end

    if instance.Parent and instance.Parent.Name == "Entrances" and (instance:IsA("Model") or instance:IsA("BasePart")) then
        return {
            id = instance,
            instance = instance,
            color = ITEM_COLORS.door,
            label = getDoorLabel(instance),
            shouldAutoPickup = false,
            allowRemoteUse = false,
        }
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
    billboard.Name = "ESP_Tag"
    billboard.Adornee = adornee
    billboard.Size = UDim2.new(0, 200, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 2.3, 0)
    billboard.AlwaysOnTop = true
    billboard.ResetOnSpawn = false
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

    activeVisuals[target] = {
        billboard = billboard,
        highlight = highlight,
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
        prompt.MaxActivationDistance = REMOTE_DISTANCE
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

local function isPromptVisible(target)
    local part = getPrimaryPart(target)
    local camera = Workspace.CurrentCamera
    if not part or not camera then
        return false
    end

    local viewportPoint, onScreen = camera:WorldToViewportPoint(part.Position)
    return onScreen and viewportPoint.Z > 0
end

local function isWithinAutoPickupDistance(target)
    local root = getCharacterRoot()
    local part = getPrimaryPart(target)
    if not root or not part then
        return false
    end

    return (root.Position - part.Position).Magnitude <= AUTO_PICKUP_DISTANCE
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
            local refreshed = classifyTarget(targetData.instance)
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
    local targetData = classifyTarget(instance)
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
            local refreshed = classifyTarget(targetData.instance)
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
                and isWithinAutoPickupDistance(targetData.instance)
                and isPromptVisible(targetData.instance) then
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
