-- Watcher.lua
local Watcher = _G.offlineservice("Watcher")

local Workspace = _G.services.Workspace

local function processObject(obj, roomNumber)
    if not obj:IsDescendantOf(Workspace) then return end
    if not _G.state.running or not obj then return end
    if _G.state.visualObjects[obj] then return end
    if obj:IsA("Attachment") then return end
    if obj:IsA("Beam") then return end

    local objName = obj.Name or "Unknown"
    local lowerName = string.lower(objName)
    local roomSuffix = roomNumber and (" [P." .. roomNumber .. "]") or ""

    local breakTarget
    for dangerousName, _ in pairs(_G.config.DANGEROUS_ENTITY_NAMES) do
        if string.find(lowerName, string.lower(dangerousName), 1, true) then
            _G.state.dangerousParts[obj] = true
            _G.Visuals.addVisuals(obj, "Enemy", objName)
            breakTarget = obj
            break
        end
    end

    if objName == "Locker" then
        _G.Visuals.addVisuals(obj, "Item", "Locker")
        breakTarget = obj
    end

    if objName == "Generator" then
        _G.Visuals.addVisuals(obj, "Item", "Generator" .. roomSuffix)
        breakTarget = obj
    end

    if objName == "PasswordPaper" then
        local codePart = obj:WaitForChild("Code")
        local codeText = "????"
        if codePart and codePart:WaitForChild("SurfaceGui") and codePart.SurfaceGui:WaitForChild("TextLabel") then
            codeText = codePart.SurfaceGui.TextLabel.Text
        end
        _G.Visuals.addTracer(obj, Color3.fromRGB(255,100,255))
        _G.Visuals.addVisuals(obj, "Item", "Pass: " .. codeText .. roomSuffix)
        breakTarget = obj
    end

    if string.find(objName, "KeyCard") then
        if obj:FindFirstChild("ProxyPart") then
            task.spawn(function() _G.Visuals.addTracer(obj, Color3.fromRGB(0,255,255)) end)
            _G.Visuals.addVisuals(obj, "Item", objName .. roomSuffix)
            breakTarget = obj
        end
    end

    if objName == "ProxyPart" then
        local prompt = obj:FindFirstChildWhichIsA("ProximityPrompt")
        if prompt and prompt.Enabled then
            local target = (obj.Parent and obj.Parent:IsA("Model")) and obj.Parent or obj
            if not string.find(target.Name, "KeyCard") then
                _G.Visuals.addVisuals(target, "Item", target.Name)
                breakTarget = target
            end
        end
    end

    if breakTarget then

        local proxy = obj:FindFirstChild("ProxyPart", true)
        if not proxy then return end

        local prompt = proxy:FindFirstChildWhichIsA("ProximityPrompt", true)
        if not prompt then return end

        if not prompt.Enabled then return end

        _G.Visuals.addVisuals(obj, "Item", objName .. roomSuffix)

        --------------------------------------------------
        -- AUTO REMOVE LOGIC
        --------------------------------------------------

        local function kill()
            if _G.state.visualObjects[obj] then
                _G.Visuals.removeVisual(obj)
            end
        end

        -- Proxy bị destroy / move
        _G.Utils.storeObjectConnection(obj,
            proxy.AncestryChanged:Connect(function(_, parent)
                if not parent then kill() end
            end)
        )

        -- Prompt bị destroy
        _G.Utils.storeObjectConnection(obj,
            prompt.AncestryChanged:Connect(function(_, parent)
                if not parent then kill() end
            end)
        )

        -- Prompt bị disable
        _G.Utils.storeObjectConnection(obj,
            prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
                if not prompt.Enabled then
                    kill()
                end
            end)
        )
    end

end

local function watchWorkspace()
    for _, child in ipairs(Workspace:GetChildren()) do
        pcall(function() processObject(child, nil) end)
    end

    local descAdded = Workspace.ChildAdded:Connect(function(c)
        if not _G.state.running then return end
        pcall(function() processObject(c, nil) end)
    end)
    table.insert(_G.state.connections, descAdded)

    local descRemoving = Workspace.ChildRemoved:Connect(function(c)
    local parent = c.Parent
    if _G.state.visualObjects[c] then
        _G.Visuals.removeVisual(c)
        return
    end
    if parent and _G.state.visualObjects[parent] then
        _G.Visuals.removeVisual(parent)
    end
end)

    table.insert(_G.state.connections, descRemoving)
end

Watcher.latestDoor = nil
Watcher.latestRoomNumber = -math.huge

local function updateLatestDoor(door, roomNumber)
    if roomNumber and roomNumber > (Watcher.latestRoomNumber or -math.huge) then
        Watcher.latestRoomNumber = roomNumber
        Watcher.latestDoor = door
    end
end

local function registerRoom(room)
    local roomNumber = _G.Utils.getRoomNumber(room)
    for _, obj in ipairs(room:GetDescendants()) do
        pcall(function() processObject(obj, roomNumber) end)
    end

    local entrances = room:WaitForChild("Entrances", 10)
    if not entrances then
        warn("No Entrances in room:", room)
        return
    end

    for _, door in ipairs(entrances:GetChildren()) do
        if door:IsA("Model") or door:IsA("BasePart") then
            local numStr = roomNumber and tostring(roomNumber) or "?"
            _G.Visuals.addVisuals(door, "Item", "Door [".. numStr .."]")
            updateLatestDoor(door, roomNumber)
        end
    end

    local doorConn = entrances.ChildAdded:Connect(function(door)
        task.wait(0.1)
        if door:IsA("Model") or door:IsA("BasePart") then
            local numStr = roomNumber and tostring(roomNumber) or "?"
            _G.Visuals.addVisuals(door, "Item", "Door [".. numStr .."]")
            updateLatestDoor(door, roomNumber)
        end

    end)
    _G.Utils.storeObjectConnection(room, doorConn)


    local connAdd = room.DescendantAdded:Connect(function(obj)
        task.wait(0.05)
        pcall(function() processObject(obj, roomNumber) end)
    end)
    _G.Utils.storeObjectConnection(room, connAdd)

    local connRem = room.DescendantRemoving:Connect(function(obj)
        if _G.state.visualObjects[obj] then _G.Visuals.removeVisual(obj) end
    end)
    _G.Utils.storeObjectConnection(room, connRem)
end

local function watchRooms(roomsFolder)

    for _, room in ipairs(roomsFolder:GetChildren()) do
        task.spawn(function() registerRoom(room) end)
    end

    local roomsAdded = roomsFolder.ChildAdded:Connect(function(r)
        task.spawn(function() registerRoom(r) end)
    end)
    table.insert(_G.state.connections, roomsAdded)
end

watchWorkspace()
local gameplay = Workspace:FindFirstChild("GameplayFolder")
local rooms = gameplay and gameplay:FindFirstChild("Rooms")

if rooms then
    watchRooms(rooms)
else
    task.spawn(function()
        while _G.state.running do
            gameplay = Workspace:FindFirstChild("GameplayFolder")
            rooms = gameplay and gameplay:FindFirstChild("Rooms")
            if rooms then watchRooms(rooms); break end
            task.wait(1)
        end
    end)
end