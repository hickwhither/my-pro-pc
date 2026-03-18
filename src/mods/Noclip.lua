local Noclip = _G.offlineservice("Noclip")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ENABLED_KEY = "noclipEnabled"

local localPlayer = Players.LocalPlayer
local stepConnection

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

function Noclip:enable()
    if stepConnection then
        stepConnection:Disconnect()
    end

    stepConnection = RunService.Stepped:Connect(function()
        setCharacterCollision(getCharacter(), false)
    end)

    setCharacterCollision(getCharacter(), false)
end

function Noclip:disable()
    if stepConnection then
        stepConnection:Disconnect()
        stepConnection = nil
    end

    setCharacterCollision(getCharacter(), true)
end

function Noclip:kill()
    self:disable()
    self:setState(ENABLED_KEY, false)
    _G.updateSettings(ENABLED_KEY, false)
end

Noclip:registerToggle({
    id = "NoclipToggle",
    settingKey = ENABLED_KEY,
    keybindKey = "noclipKeybind",
    defaultKeybind = "F7",
    onToggle = function(enabled)
        if enabled then
            Noclip:enable()
        else
            Noclip:disable()
        end
    end,
})

return Noclip
