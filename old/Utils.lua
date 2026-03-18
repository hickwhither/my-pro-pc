-- Utils.lua
local Utils = _G.offlineservice("Utils")

local Workspace = _G.services.Workspace
local Players = _G.services.Players

function Utils.safeDisconnectList(list)
    if not list then return end
    for _, c in ipairs(list) do
        pcall(function() if c and c.Disconnect then c:Disconnect() end end)
    end
end

function Utils.storeObjectConnection(obj, conn)
    if not obj then return end
    _G.state.objectConnections[obj] = _G.state.objectConnections[obj] or {}
    table.insert(_G.state.objectConnections[obj], conn)
    table.insert(_G.state.connections, conn)
end

function Utils.clearObjectConnections(obj)
    if not obj then return end
    local tbl = _G.state.objectConnections[obj]
    if tbl then
        for _, c in ipairs(tbl) do
            pcall(function() c:Disconnect() end)
        end
        _G.state.objectConnections[obj] = nil
    end
end

-- teleport tới một object đã biết (model hoặc part).
-- Nếu là model và có ProxyPart thì ưu tiên teleport tới ProxyPart.
-- Nếu ProxyPart đã bị xóa, hàm trả về false + message và (tuỳ cấu hình) remove visual.
function Utils.teleportToTarget(targetObj)
    local player = Players.LocalPlayer
    local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not root then return false end

    if targetObj:IsA("Model") then
        local proxy = targetObj:FindFirstChild("ProxyPart", true)
        if proxy and proxy:IsA("BasePart") then
            root.CFrame = CFrame.new(proxy.Position + Vector3.new(0,3,0))
            return true
        end

        local part =
            targetObj.PrimaryPart
            or targetObj:FindFirstChildWhichIsA("BasePart", true)

        if part then
            root.CFrame = CFrame.new(part.Position + Vector3.new(0,3,0))
            return true
        end
    end

    if targetObj:IsA("BasePart") then
        root.CFrame = CFrame.new(targetObj.Position + Vector3.new(0,3,0))
        return true
    end

    return false
end


function Utils.getRoomNumber(room)
    local lights = room:WaitForChild("Lights", 10)
    if not lights then return nil end

    local nums = {}

    for _, child in ipairs(lights:GetChildren()) do
        if child.Name == "Sign" then
            local sg = child:FindFirstChild("SurfaceGui")
            local tl = sg and sg:FindFirstChild("TextLabel")
            if tl then
                local num = tonumber(tl.Text)
                if num then
                    table.insert(nums, num)
                end
            end
        end
    end
    if #nums >= 2 then
        return math.floor((nums[1] + nums[2]) / 2)
    end

    return nil
end
