local Noclip = _G.offlineservice("Noclip")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ENABLED_KEY = "noclipEnabled"

local localPlayer = Players.LocalPlayer
local stepConnection
local characterAddedConnection
local originalCollisionStates = {}

local function getCharacter()
    return localPlayer and localPlayer.Character
end

local function rememberCollisionState(part)
    if originalCollisionStates[part] == nil then
        originalCollisionStates[part] = part.CanCollide
    end
end

local function setCharacterCollision(character, canCollide)
    if not character then
        return
    end

    for _, descendant in ipairs(character:GetDescendants()) do
        if descendant:IsA("BasePart") then
            if canCollide then
                local originalState = originalCollisionStates[descendant]
                if originalState ~= nil then
                    descendant.CanCollide = originalState
                    originalCollisionStates[descendant] = nil
                else
                    descendant.CanCollide = true
                end
            else
                rememberCollisionState(descendant)
                descendant.CanCollide = false
            end
        end
    end
end

local function bindCharacterReset()
    if characterAddedConnection or not localPlayer then
        return
    end

    characterAddedConnection = localPlayer.CharacterAdded:Connect(function(character)
        if _G.getSetting(ENABLED_KEY, false) then
            task.wait(0.1)
            setCharacterCollision(character, false)
        end
    end)
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
    table.clear(originalCollisionStates)
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

bindCharacterReset()

return Noclip
