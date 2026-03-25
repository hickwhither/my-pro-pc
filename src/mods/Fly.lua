local Fly = _G.offlineservice("Fly")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ENABLED_KEY = "flyEnabled"
local FLY_SPEED = 60
local SWIM_FLY_SPEED = 110

local localPlayer = Players.LocalPlayer
local renderConnection
local inputBeganConnection
local inputEndedConnection
local characterAddedConnection
local flightController
local activeDirections = {
    forward = false,
    backward = false,
    left = false,
    right = false,
    up = false,
    down = false,
}

local movementKeys = {
    [Enum.KeyCode.W] = "forward",
    [Enum.KeyCode.S] = "backward",
    [Enum.KeyCode.A] = "left",
    [Enum.KeyCode.D] = "right",
    [Enum.KeyCode.Space] = "up",
    [Enum.KeyCode.LeftControl] = "down",
    [Enum.KeyCode.RightControl] = "down",
}

local function getCharacter()
    return localPlayer and localPlayer.Character
end

local function getHumanoid(character)
    if not character then
        return nil
    end

    return character:FindFirstChildOfClass("Humanoid")
end

local function getRootPart(character)
    if not character then
        return nil
    end

    return character:FindFirstChild("HumanoidRootPart")
end

local function clearDirections()
    for direction in pairs(activeDirections) do
        activeDirections[direction] = false
    end
end

local function destroyFlightController()
    if flightController then
        if flightController.bodyVelocity then
            flightController.bodyVelocity:Destroy()
        end

        if flightController.bodyGyro then
            flightController.bodyGyro:Destroy()
        end

        if flightController.humanoid then
            flightController.humanoid.PlatformStand = false
            flightController.humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end

        flightController = nil
    end
end

local function updateFlightVelocity()
    if not flightController or not flightController.rootPart then
        return
    end

    local camera = Workspace.CurrentCamera
    if not camera then
        flightController.bodyVelocity.Velocity = Vector3.zero
        return
    end

    local moveVector = Vector3.zero

    if activeDirections.forward then
        moveVector += camera.CFrame.LookVector
    end

    if activeDirections.backward then
        moveVector -= camera.CFrame.LookVector
    end

    if activeDirections.left then
        moveVector -= camera.CFrame.RightVector
    end

    if activeDirections.right then
        moveVector += camera.CFrame.RightVector
    end

    if activeDirections.up then
        moveVector += camera.CFrame.UpVector
    end

    if activeDirections.down then
        moveVector -= camera.CFrame.UpVector
    end

    local currentSpeed = FLY_SPEED
    if flightController.humanoid and flightController.humanoid:GetState() == Enum.HumanoidStateType.Swimming then
        currentSpeed = SWIM_FLY_SPEED
    end

    if moveVector.Magnitude > 0 then
        moveVector = moveVector.Unit * currentSpeed
    end

    flightController.bodyVelocity.Velocity = moveVector
    flightController.bodyGyro.CFrame = camera.CFrame
end

local function stopFlight()
    if renderConnection then
        renderConnection:Disconnect()
        renderConnection = nil
    end

    destroyFlightController()
    clearDirections()
end

local function startFlight()
    local character = getCharacter()
    local humanoid = getHumanoid(character)
    local rootPart = getRootPart(character)

    if not character or not humanoid or not rootPart then
        return false
    end

    stopFlight()

    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.Name = "FlyBodyVelocity"
    bodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bodyVelocity.Velocity = Vector3.zero
    bodyVelocity.Parent = rootPart

    local bodyGyro = Instance.new("BodyGyro")
    bodyGyro.Name = "FlyBodyGyro"
    bodyGyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    bodyGyro.P = 1e4
    bodyGyro.CFrame = Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame or rootPart.CFrame
    bodyGyro.Parent = rootPart

    humanoid.PlatformStand = true
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)

    flightController = {
        bodyVelocity = bodyVelocity,
        bodyGyro = bodyGyro,
        humanoid = humanoid,
        rootPart = rootPart,
    }

    renderConnection = RunService.RenderStepped:Connect(function()
        local currentCharacter = getCharacter()
        if currentCharacter ~= character or not rootPart.Parent then
            if _G.getSetting(ENABLED_KEY, false) then
                task.defer(startFlight)
            end
            stopFlight()
            return
        end

        updateFlightVelocity()
    end)

    updateFlightVelocity()
    return true
end

local function bindMovementInput()
    if inputBeganConnection then
        return
    end

    inputBeganConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed or input.UserInputType ~= Enum.UserInputType.Keyboard then
            return
        end

        local direction = movementKeys[input.KeyCode]
        if direction and _G.getSetting(ENABLED_KEY, false) then
            activeDirections[direction] = true
        end
    end)

    inputEndedConnection = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.Keyboard then
            return
        end

        local direction = movementKeys[input.KeyCode]
        if direction then
            activeDirections[direction] = false
        end
    end)
end

local function bindCharacterReset()
    if characterAddedConnection or not localPlayer then
        return
    end

    characterAddedConnection = localPlayer.CharacterAdded:Connect(function()
        if _G.getSetting(ENABLED_KEY, false) then
            task.wait(0.1)
            startFlight()
        end
    end)
end

function Fly:enable()
    if not startFlight() then
        self:setState(ENABLED_KEY, false)
        _G.updateSettings(ENABLED_KEY, false)
    end
end

function Fly:disable()
    stopFlight()
end

function Fly:kill()
    self:disable()
    self:setState(ENABLED_KEY, false)
    _G.updateSettings(ENABLED_KEY, false)
end

Fly:registerToggle({
    id = "FlyToggle",
    settingKey = ENABLED_KEY,
    keybindKey = "flyKeybind",
    defaultKeybind = "F8",
    onToggle = function(enabled)
        if enabled then
            Fly:enable()
        else
            Fly:disable()
        end
    end,
})

bindMovementInput()
bindCharacterReset()

return Fly
