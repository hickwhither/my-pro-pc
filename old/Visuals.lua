-- Visuals.lua
local Visuals = _G.offlineservice("Visuals")

local Players = _G.services.Players
local RunService = _G.services.RunService
local Camera = workspace.CurrentCamera

_G.state.screenButtons = _G.state.screenButtons or {}

function Visuals.addTracer(targetObj, color)

if not _G.state.running or not targetObj then return end

task.spawn(function()

    task.wait(0.4)

    if _G.state.itemTracers[targetObj] then return end

    local player = Players.LocalPlayer
    local char = player and player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local targetPart =
        targetObj:IsA("Model")
        and (
            targetObj.PrimaryPart
            or targetObj:FindFirstChild("ProxyPart", true)
            or targetObj:FindFirstChildWhichIsA("BasePart", true)
        )
        or targetObj

    if not targetPart then return end

    local att0 = Instance.new("Attachment")
    att0.Parent = targetPart

    local att1 = Instance.new("Attachment")
    att1.Parent = root

    local beam = Instance.new("Beam")
    beam.Attachment0 = att0
    beam.Attachment1 = att1
    beam.Color = ColorSequence.new(color or Color3.fromRGB(0,255,255))
    beam.FaceCamera = true
    beam.Width0 = 0.05
    beam.Width1 = 0.05
    beam.Transparency = NumberSequence.new(0.25)
    beam.Parent = att0

    _G.state.itemTracers[targetObj] = {
        Beam = beam,
        Att0 = att0,
        Att1 = att1
    }

end)
end


local function resolveAdornee(target)
    if target:IsA("BasePart") then return target end
    if target:IsA("Model") then
        return target.PrimaryPart
            or target:FindFirstChild("ProxyPart")
            or target:FindFirstChildWhichIsA("BasePart")
    end
end
--------------------------------------------------
-- Billboard (CHỈ TEXT - NO BACKGROUND)
--------------------------------------------------

local function createBillboard(target, text, color)

    local adornee = resolveAdornee(target)
    if not adornee then return end

    local bb = Instance.new("BillboardGui")
    bb.Name = "ESP_Tag"
    bb.Adornee = adornee
    bb.Size = UDim2.new(0, 200, 0, 40)
    bb.StudsOffset = Vector3.new(0, 2.3, 0)
    bb.AlwaysOnTop = true
    bb.ResetOnSpawn = false

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,0,1,0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = color
    lbl.TextStrokeTransparency = 0.5
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 14
    lbl.TextXAlignment = Enum.TextXAlignment.Center
    lbl.TextYAlignment = Enum.TextYAlignment.Center
    lbl.Parent = bb

    bb.Parent = target
    return bb
end

--------------------------------------------------
-- Screen Button (click cả khung)
--------------------------------------------------

local function createTeleportButton(target)

    local player = Players.LocalPlayer
    local pgui = player:WaitForChild("PlayerGui")

    local screenGui = Instance.new("ScreenGui")
    screenGui.IgnoreGuiInset = true
    screenGui.ResetOnSpawn = false
    screenGui.Parent = pgui

    local btn = Instance.new("TextButton")

    -- khung rất nhỏ, gần như invisible
    btn.Size = UDim2.new(0, 90, 0, 22)
    btn.AnchorPoint = Vector2.new(0.5, 1)

    btn.BackgroundTransparency = 1
    btn.Text = "" -- không chữ -> nhìn sạch

    btn.Parent = screenGui

    --------------------------------------------------
    -- TRACK vị trí trên đầu chữ
    --------------------------------------------------

    local conn
    conn = RunService.RenderStepped:Connect(function()

        if not _G.state.running or not target or not target.Parent then
            screenGui:Destroy()
            conn:Disconnect()
            return
        end

        local part = resolveAdornee(target)
        if not part then
            screenGui.Enabled = false
            return
        end

        local pos, visible =
            Camera:WorldToViewportPoint(part.Position + Vector3.new(0, 3.4, 0))

        if visible then
            screenGui.Enabled = true
            btn.Position = UDim2.new(0, pos.X, 0, pos.Y)
        else
            screenGui.Enabled = false
        end
    end)

    --------------------------------------------------
    -- CLICK TELEPORT
    --------------------------------------------------

    btn.MouseButton1Click:Connect(function()

        if not _G.state.running then return end

        local ok = _G.Utils.teleportToTarget(target)

        if not ok then
            Visuals.removeVisual(target)
        end
    end)

    return {
        gui = screenGui,
        conn = conn
    }
end

--------------------------------------------------
-- ADD VISUAL
--------------------------------------------------

function Visuals.addVisuals(obj, kind, nameOverride)
    if not obj:IsDescendantOf(workspace) then return end

    if not _G.state.running or not obj then return end
    if _G.state.visualObjects[obj] then return end

    local visuals = {}

    if kind == "Enemy" then

        visuals.Billboard =
            createBillboard(obj,
            "☠️ "..(nameOverride or obj.Name).." ☠️",
            Color3.fromRGB(255,0,0))

        local box = Instance.new("SelectionBox")
        box.Adornee = obj
        box.Color3 = Color3.fromRGB(255,0,0)
        box.LineThickness = 0.05
        box.SurfaceTransparency = 0.9
        box.AlwaysOnTop = true
        box.Parent = obj

        visuals.SelectionBox = box

    elseif kind == "Item" then

        local color = Color3.fromRGB(0,255,255)

        if string.find(nameOverride or "", "Locker") then
            color = Color3.fromRGB(0,160,255)
        end

        if string.find(nameOverride or "", "Door") then
            color = Color3.fromRGB(255,255,0)
        end

        if string.find(nameOverride or "", "Pass") then
            color = Color3.fromRGB(255,100,255)
        end

        visuals.Billboard =
            createBillboard(obj, nameOverride or obj.Name, color)

        local hl = Instance.new("Highlight")
        hl.FillColor = color
        hl.FillTransparency = 0.7
        hl.OutlineTransparency = 0.5
        hl.Adornee = obj
        hl.Parent = obj

        visuals.Highlight = hl

        --------------------------------------------------
        -- CHỈ tạo teleport nếu đúng item
        --------------------------------------------------

        local lowerName = string.lower(obj.Name)
        local overrideLower = string.lower(nameOverride or "")

        if string.find(lowerName, "passwordpaper")
        or string.find(lowerName, "keycard")
        or string.find(lowerName, "generator")
        or string.find(overrideLower, "door") then
            visuals.TeleportButton = createTeleportButton(obj)
        end

    end

    _G.state.visualObjects[obj] = visuals

    --------------------------------------------------
    -- remove nếu ProxyPart mất
    --------------------------------------------------

    if obj:IsA("Model") then
        local conn = obj.ChildRemoved:Connect(function(child)
            if child.Name == "ProxyPart" then
                Visuals.removeVisual(obj)
            end
        end)

        _G.Utils.storeObjectConnection(obj, conn)
    end
end

--------------------------------------------------
-- REMOVE
--------------------------------------------------

function Visuals.removeVisual(obj)

    local v = _G.state.visualObjects[obj]
    if not v then return end

    pcall(function() if v.Highlight then v.Highlight:Destroy() end end)
    pcall(function() if v.Billboard then v.Billboard:Destroy() end end)
    pcall(function() if v.SelectionBox then v.SelectionBox:Destroy() end end)

    if v.TeleportButton then
        pcall(function()
            v.TeleportButton.conn:Disconnect()
            v.TeleportButton.gui:Destroy()
        end)
    end

    _G.state.visualObjects[obj] = nil
    _G.Utils.clearObjectConnections(obj)
    
    -- remove tracer
    if _G.state.itemTracers[obj] then
        local t = _G.state.itemTracers[obj]

        pcall(function() t.Beam:Destroy() end)
        pcall(function() t.Att0:Destroy() end)
        pcall(function() t.Att1:Destroy() end)

        _G.state.itemTracers[obj] = nil
    end

end