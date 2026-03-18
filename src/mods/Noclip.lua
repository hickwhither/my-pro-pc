local Noclip = _G.offlineservice("Noclip")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

Noclip.defaultKeybind = "F7"

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

    _G.updateSettings("noclipEnabled", enabled)
end

