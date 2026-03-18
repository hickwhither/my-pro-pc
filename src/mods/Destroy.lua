local Destroy = _G.offlineservice("Destroy")

local UserInputService = game:GetService("UserInputService")

local ENABLED_KEY = "destroyEnabled"
local KEYBIND_KEY = "destroyKeybind"
local DEFAULT_KEYBIND = "F9"

local inputConnection

local TARGET_MODS = {
    {
        serviceName = "Fullbright",
        enabledKey = "fullbrightEnabled",
    },
    {
        serviceName = "Noclip",
        enabledKey = "noclipEnabled",
    },
    {
        serviceName = "Fly",
        enabledKey = "flyEnabled",
    },
}

local function keyCodeFromSetting(value)
    if typeof(value) ~= "string" then
        return nil
    end

    return Enum.KeyCode[value:upper()]
end

local function destroyMods()
    for _, modInfo in ipairs(TARGET_MODS) do
        local service = _G[modInfo.serviceName]
        if service and type(service.toggle) == "function" then
            service.toggle(false)
        else
            _G.updateSettings(modInfo.enabledKey, false)
        end
    end
end

function Destroy.toggle(enabled)
    if enabled then
        destroyMods()
        enabled = false
    end

    _G.updateSettings(ENABLED_KEY, enabled)
end

local function bindInput()
    if inputConnection then
        return
    end

    inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed or input.UserInputType ~= Enum.UserInputType.Keyboard then
            return
        end

        local keyCode = keyCodeFromSetting(_G.getSetting(KEYBIND_KEY, DEFAULT_KEYBIND))
        if keyCode and input.KeyCode == keyCode then
            Destroy.toggle(true)
        end
    end)
end

_G.getSetting(ENABLED_KEY, false)
_G.getSetting(KEYBIND_KEY, DEFAULT_KEYBIND)
bindInput()

return Destroy
