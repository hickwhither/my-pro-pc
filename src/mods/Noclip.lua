local Noclip = _G.offlineservice("Noclip")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ENABLED_KEY = "noclipEnabled"
local KEYBIND_KEY = "noclipKeybind"
local DEFAULT_KEYBIND = "F7"

local localPlayer = Players.LocalPlayer
local stepConnection
local inputConnection

local function keyCodeFromSetting(value)
    if typeof(value) ~= "string" then
        return nil
    end

    return Enum.KeyCode[value:upper()]
end

local function getCharacter()
    return localPlayer and localPlayer.Character
end

local function setCharacterCollision(character, canCollide)
    if not character then
        return
    end

    for _, descendant in ipairs(character:GetDescendants()) do
        if descendant:IsA("BasePart") then
            descendant.CanCollide = canCollide
        end
    end
end

function Noclip.toggle(enabled)
    if enabled then
        if stepConnection then
            stepConnection:Disconnect()
        end

        stepConnection = RunService.Stepped:Connect(function()
            setCharacterCollision(getCharacter(), false)
        end)

        setCharacterCollision(getCharacter(), false)
    else
        if stepConnection then
            stepConnection:Disconnect()
            stepConnection = nil
        end

        setCharacterCollision(getCharacter(), true)
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
            Noclip.toggle(not _G.getSetting(ENABLED_KEY, false))
        end
    end)
end

_G.getSetting(ENABLED_KEY, false)
_G.getSetting(KEYBIND_KEY, DEFAULT_KEYBIND)
bindInput()

if _G.getSetting(ENABLED_KEY, false) then
    Noclip.toggle(true)
end

return Noclip
