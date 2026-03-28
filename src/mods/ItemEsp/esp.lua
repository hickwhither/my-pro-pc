return function(deps)
    local getPrimaryPart = deps.getPrimaryPart
    local createOverlay = deps.createOverlay

    local Esp = {}
    local activeVisuals = {}

    local function destroyVisual(target)
        local visuals = activeVisuals[target]
        if not visuals then
            return
        end

        if visuals.clickConnection and visuals.clickConnection.Disconnect then
            visuals.clickConnection:Disconnect()
        end

        if visuals.overlayConnection and visuals.overlayConnection.Disconnect then
            visuals.overlayConnection:Disconnect()
        end

        if visuals.overlayGui and visuals.overlayGui.Parent then
            visuals.overlayGui:Destroy()
        end

        if visuals.billboard and visuals.billboard.Parent then
            visuals.billboard:Destroy()
        end

        if visuals.highlight and visuals.highlight.Parent then
            visuals.highlight:Destroy()
        end

        activeVisuals[target] = nil
    end

    local function createVisual(targetData)
        local target = targetData.instance
        if activeVisuals[target] then
            return
        end

        local adornee = getPrimaryPart(target)
        if not adornee then
            return
        end

        local billboard = Instance.new("BillboardGui")
        billboard.Name = "ESP_Tag"
        billboard.Adornee = adornee
        billboard.Size = UDim2.new(0, 200, 0, 40)
        billboard.StudsOffset = Vector3.new(0, 2.3, 0)
        billboard.AlwaysOnTop = true
        billboard.ResetOnSpawn = false
        billboard.Active = true
        billboard.Parent = target

        local label = Instance.new("TextLabel")
        label.Name = "Label"
        label.BackgroundTransparency = 1
        label.Size = UDim2.new(1, 0, 1, 0)
        label.Font = Enum.Font.GothamBold
        label.Text = targetData.label
        label.TextColor3 = targetData.color
        label.TextStrokeTransparency = 0.5
        label.TextSize = 14
        label.TextScaled = false
        label.TextWrapped = false
        label.TextXAlignment = Enum.TextXAlignment.Center
        label.TextYAlignment = Enum.TextYAlignment.Center
        label.Active = true
        label.Parent = billboard

        local highlight = Instance.new("Highlight")
        highlight.Name = "ItemEspHighlight"
        highlight.Adornee = target
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.FillColor = targetData.color
        highlight.FillTransparency = 0.7
        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
        highlight.OutlineTransparency = 0.5
        highlight.Parent = target

        local overlayGui, overlayConnection, clickConnection = createOverlay(targetData)

        activeVisuals[target] = {
            billboard = billboard,
            highlight = highlight,
            overlayGui = overlayGui,
            overlayConnection = overlayConnection,
            clickConnection = clickConnection,
        }
    end

    local function refreshVisual(targetData)
        local visuals = activeVisuals[targetData.instance]
        if not visuals then
            return
        end

        if visuals.billboard and visuals.billboard:FindFirstChild("Label") then
            visuals.billboard.Label.Text = targetData.label
            visuals.billboard.Label.TextColor3 = targetData.color
        end

        if visuals.highlight then
            visuals.highlight.FillColor = targetData.color
        end
    end

    function Esp.apply(targetData, enabled)
        if enabled then
            createVisual(targetData)
            refreshVisual(targetData)
        else
            destroyVisual(targetData.instance)
        end
    end

    function Esp.destroyAll()
        for target in pairs(activeVisuals) do
            destroyVisual(target)
        end
    end

    function Esp.destroyTarget(target)
        destroyVisual(target)
    end

    return Esp
end
