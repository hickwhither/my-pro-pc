local PressureMod = _G.offlineservice("PressureMod")

local ESP_ENABLED_KEY = "pressureEspEnabled"
local AUTO_PICKUP_ENABLED_KEY = "pressureAutoPickupEnabled"
local REMOTE_USE_ENABLED_KEY = "pressureRemoteUseEnabled"

local ITEM_COLORS = {
    default = Color3.fromRGB(0, 255, 255),
    locker = Color3.fromRGB(0, 160, 255),
    paper = Color3.fromRGB(255, 100, 255),
    generator = Color3.fromRGB(255, 255, 0),
    door = Color3.fromRGB(255, 255, 0),
    angler = Color3.fromRGB(255, 70, 70),
}

local ItemEspUtils = _G.fetch("mods/ItemEsp/utils.lua")
local createTeleport = _G.fetch("mods/ItemEsp/teleport.lua")
local createEsp = _G.fetch("mods/ItemEsp/esp.lua")
local createAutoPickup = _G.fetch("mods/ItemEsp/auto_pickup.lua")
local createTracker = _G.fetch("mods/ItemEsp/tracker.lua")
local createHud = _G.fetch("mods/ItemEsp/hud.lua")
local registerToggles = _G.fetch("mods/ItemEsp/toggle_handler.lua")

if not ItemEspUtils or not createTeleport or not createEsp or not createAutoPickup or not createTracker or not createHud
    or not registerToggles then
    warn("PressureMod failed to load helper files")
    return PressureMod
end

local function isEspEnabled()
    return _G.getSetting(ESP_ENABLED_KEY, false)
end

local function isAutoPickupEnabled()
    return _G.getSetting(AUTO_PICKUP_ENABLED_KEY, false)
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

local Teleport = createTeleport({
    getPrimaryPart = ItemEspUtils.getPrimaryPart,
    isEspEnabled = isEspEnabled,
})

local Esp = createEsp({
    getPrimaryPart = ItemEspUtils.getPrimaryPart,
    createOverlay = Teleport.createOverlay,
})

local Tracker = createTracker({
    ITEM_COLORS = ITEM_COLORS,
    findPrompt = ItemEspUtils.findPrompt,
    getPaperPassword = ItemEspUtils.getPaperPassword,
    onTrack = function(targetData)
        Esp.apply(targetData, isEspEnabled())
        applyRemotePromptState(targetData)
    end,
    onForget = function(target, tracked)
        applyRemotePromptState(tracked)
        Esp.destroyTarget(target)
    end,
})

local AutoPickup = createAutoPickup({
    isAutoPickupEnabled = isAutoPickupEnabled,
    getTrackedTargets = Tracker.getTrackedTargets,
    forgetTarget = Tracker.forgetTarget,
    isWithinPromptDistance = ItemEspUtils.isWithinPromptDistance,
})

local Hud = createHud({
    getTrackedTargets = Tracker.getTrackedTargets,
})

function PressureMod:enableTracking()
    Tracker.start()
    AutoPickup.start()
    Hud.start()
end

function PressureMod:disableTracking()
    Tracker.stop()
    AutoPickup.stop()
    Hud.stop()
    Esp.destroyAll()
end

function PressureMod:syncRemoteUseState()
    for target, targetData in pairs(Tracker.getTrackedTargets()) do
        if not target or not target.Parent then
            Tracker.forgetTarget(target)
        else
            applyRemotePromptState(targetData)
        end
    end
end

function PressureMod:disable()
    self:disableTracking()
end

function PressureMod:kill()
    self:setState(ESP_ENABLED_KEY, false)
    self:setState(AUTO_PICKUP_ENABLED_KEY, false)
    self:setState(REMOTE_USE_ENABLED_KEY, false)
    _G.updateSettings(ESP_ENABLED_KEY, false)
    _G.updateSettings(AUTO_PICKUP_ENABLED_KEY, false)
    _G.updateSettings(REMOTE_USE_ENABLED_KEY, false)
    self:disableTracking()
end

registerToggles({
    itemEsp = PressureMod,
    keys = {
        ESP_ENABLED_KEY = ESP_ENABLED_KEY,
        AUTO_PICKUP_ENABLED_KEY = AUTO_PICKUP_ENABLED_KEY,
        REMOTE_USE_ENABLED_KEY = REMOTE_USE_ENABLED_KEY,
    },
    onEspToggle = function()
        PressureMod:enableTracking()
        Tracker.syncTargets()
    end,
    onAutoPickupToggle = function()
        PressureMod:enableTracking()
    end,
    onRemoteUseToggle = function()
        PressureMod:enableTracking()
        PressureMod:syncRemoteUseState()
    end,
})

return PressureMod
