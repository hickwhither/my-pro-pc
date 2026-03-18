local Fly = _G.offlineservice("Fly")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ENABLED_KEY = "flyEnabled"
local KEYBIND_KEY = "flyKeybind"
local DEFAULT_KEYBIND = "F8"
local FLY_SPEED = 75
local VERTICAL_SPEED = 1

local localPlayer = Players.LocalPlayer
local stepConnection
local inputBeganConnection
local inputEndedConnection
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

local function keyCodeFromSetting(value)
    if typeof(value) ~= "string" then
        return nil
    end

    return Enum.KeyCode[value:upper()]
end

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

local function updateFlightVelocity()
    if not flightController or not flightController.rootPart then
        return
    end

    local camera = Workspace.CurrentCamera
    if not camera then
        flightController.velocity.VectorVelocity = Vector3.zero
        return
    end

    local moveVector = Vector3.zero
    local flattenedLook = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
    local flattenedRight = Vector3.new(camera.CFrame.RightVector.X, 0, camera.CFrame.RightVector.Z)

    if flattenedLook.Magnitude > 0 then
        flattenedLook = flattenedLook.Unit
    end

    if flattenedRight.Magnitude > 0 then
        flattenedRight = flattenedRight.Unit
    end

    if activeDirections.forward then
        moveVector += flattenedLook
    end

    if activeDirections.backward then
        moveVector -= flattenedLook
    end

    if activeDirections.left then
        moveVector -= flattenedRight
    end

    if activeDirections.right then
        moveVector += flattenedRight
    end

    if activeDirections.up then
        moveVector += Vector3.yAxis * VERTICAL_SPEED
    end

    if activeDirections.down then
        moveVector -= Vector3.yAxis * VERTICAL_SPEED
    end

    if moveVector.Magnitude > 0 then
        moveVector = moveVector.Unit * FLY_SPEED
    end

    flightController.velocity.VectorVelocity = moveVector
    flightController.gyro.CFrame = camera.CFrame
end

local function stopFlight()
    if stepConnection then
        stepConnection:Disconnect()
        stepConnection = nil
    end

    if flightController then
        local humanoid = flightController.humanoid
        if humanoid then
            humanoid.PlatformStand = false
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end

        if flightController.attachment then
            flightController.attachment:Destroy()
        end

        if flightController.velocity then
            flightController.velocity:Destroy()
        end

        if flightController.gyro then
            flightController.gyro:Destroy()
        end

        flightController = nil
    end

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

    local attachment = Instance.new("Attachment")
    attachment.Name = "FlyAttachment"
    attachment.Parent = rootPart

    local velocity = Instance.new("LinearVelocity")
    velocity.Name = "FlyVelocity"
    velocity.Attachment0 = attachment
    velocity.RelativeTo = Enum.ActuatorRelativeTo.World
    velocity.MaxForce = math.huge
    velocity.VectorVelocity = Vector3.zero
    velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
    velocity.Parent = rootPart

    local gyro = Instance.new("AlignOrientation")
    gyro.Name = "FlyGyro"
    gyro.Attachment0 = attachment
    gyro.Mode = Enum.OrientationAlignmentMode.OneAttachment
    gyro.RigidityEnabled = true
    gyro.Responsiveness = 200
    gyro.CFrame = Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame or rootPart.CFrame
    gyro.Parent = rootPart

    humanoid.PlatformStand = true
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)

    flightController = {
        attachment = attachment,
        velocity = velocity,
        gyro = gyro,
        humanoid = humanoid,
        rootPart = rootPart,
    }

    stepConnection = RunService.RenderStepped:Connect(function()
        local currentCharacter = getCharacter()
        if currentCharacter ~= character or not rootPart.Parent then
            Fly.toggle(false)
            return
        end

        updateFlightVelocity()
    end)

    updateFlightVelocity()
    return true
end

function Fly.toggle(enabled)
    if enabled then
        if not startFlight() then
            enabled = false
        end
    else
        stopFlight()
    end

    _G.updateSettings(ENABLED_KEY, enabled)
end

local function bindInput()
    if inputBeganConnection then
        return
    end

    inputBeganConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed or input.UserInputType ~= Enum.UserInputType.Keyboard then
            return
        end

        local keyCode = keyCodeFromSetting(_G.getSetting(KEYBIND_KEY, DEFAULT_KEYBIND))
        if keyCode and input.KeyCode == keyCode then
            Fly.toggle(not _G.getSetting(ENABLED_KEY, false))
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

_G.getSetting(ENABLED_KEY, false)
_G.getSetting(KEYBIND_KEY, DEFAULT_KEYBIND)
bindInput()

if _G.getSetting(ENABLED_KEY, false) then
    Fly.toggle(true)
end

return Fly
