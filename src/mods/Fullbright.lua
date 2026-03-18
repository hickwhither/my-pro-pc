local Fullbright = _G.offlineservice("Fullbright")

local Lighting = game:GetService("Lighting")

Fullbright.defaultKeybind = "F6"

local originalLighting
local propertyConnections = {}

local function saveOriginalLighting()
    if originalLighting then
        return
    end

    originalLighting = {
        Brightness = Lighting.Brightness,
        ClockTime = Lighting.ClockTime,
        FogEnd = Lighting.FogEnd,
        GlobalShadows = Lighting.GlobalShadows,
        Ambient = Lighting.Ambient,
        OutdoorAmbient = Lighting.OutdoorAmbient,
    }
end

local function applyFullbright()
    Lighting.Brightness = 5
    Lighting.ClockTime = 12
    Lighting.FogEnd = 1e10
    Lighting.GlobalShadows = false
    Lighting.Ambient = Color3.fromRGB(255, 255, 255)
    Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
end

local function disconnectPropertyConnections()
    for _, connection in ipairs(propertyConnections) do
        connection:Disconnect()
    end

    table.clear(propertyConnections)
end

local function connectPropertyLocks()
    disconnectPropertyConnections()

    local properties = {
        "Brightness",
        "ClockTime",
        "FogEnd",
        "GlobalShadows",
        "Ambient",
        "OutdoorAmbient",
    }

    for _, propertyName in ipairs(properties) do
        table.insert(propertyConnections, Lighting:GetPropertyChangedSignal(propertyName):Connect(function()
            applyFullbright()
        end))
    end
end

function Fullbright.toggle(enabled)
    if enabled then
        saveOriginalLighting()
        applyFullbright()
        connectPropertyLocks()
    else
        disconnectPropertyConnections()

        if originalLighting then
            Lighting.Brightness = originalLighting.Brightness
            Lighting.ClockTime = originalLighting.ClockTime
            Lighting.FogEnd = originalLighting.FogEnd
            Lighting.GlobalShadows = originalLighting.GlobalShadows
            Lighting.Ambient = originalLighting.Ambient
            Lighting.OutdoorAmbient = originalLighting.OutdoorAmbient
            originalLighting = nil
        end
    end

    _G.updateSettings("fullbrightEnabled", enabled)
end

return Fullbright
