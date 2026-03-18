local baseUrl = ""
baseUrl = "http://localhost:5000/src/" -- debug

local function fetch(name)
    local ok, res = pcall(function() return loadstring(game:HttpGet(baseUrl .. name))() end)
    if not ok then
        warn("Error loading module " .. name .. ": " .. tostring(res))
    end
    print("Success loaded " .. name)
    return res
end

_G.class = fetch("class.lua")
_G.offlineservice = fetch("offlineservice.lua")

_G.fire = function(name, data)
    local HttpService = game:GetService("HttpService")
    local success, err = pcall(function()
        local url = "http://localhost:5000/fire?name=" .. HttpService:UrlEncode(name) .. "&data=" .. HttpService:UrlEncode(HttpService:JSONEncode(data))
        game:HttpGet(url)
    end)
    if not success then
        warn("Failed to fire " .. name .. ": " .. err)
    end
end

_G.updateSetting = function(key, value)
    local HttpService = game:GetService("HttpService")
    local success, err = pcall(function()
        local url = "http://localhost:5000/updateSettings?key=" .. HttpService:UrlEncode(key) .. "&value=" .. HttpService:UrlEncode(HttpService:JSONEncode(value))
        game:HttpGet(url)
    end)
    if not success then
        warn("Failed to update setting " .. key .. ": " .. err)
    end
end

print("The PRO PC is on now!")

fetch("mods/Explorer.lua")

local HttpService = game:GetService("HttpService")

local function fetchSettings()
    local success, response = pcall(function() return game:HttpGet("http://localhost:5000/settings") end)
    if success then
        local data = HttpService:JSONDecode(response)
        _G.settings = data
    else
        warn("Failed to fetch settings: " .. response)
    end
end

task.spawn(function()
    while true do
        fetchSettings()
        task.wait(1)
    end
end)
