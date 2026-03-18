local baseUrl = ""
baseUrl = "http://localhost:5000/src/" -- debug

local function encodeValue(value)
    local valueType = type(value)

    if valueType == "string" then
        return string.format("%q", value)
    end

    if valueType == "boolean" or valueType == "number" then
        return tostring(value)
    end

    if valueType == "table" then
        local parts = {"{"}
        local isFirst = true

        for key, nestedValue in pairs(value) do
            if not isFirst then
                table.insert(parts, ",")
            end

            local keyType = type(key)
            if keyType == "string" then
                table.insert(parts, "[")
                table.insert(parts, string.format("%q", key))
                table.insert(parts, "]=")
            elseif keyType == "number" then
                table.insert(parts, "[")
                table.insert(parts, tostring(key))
                table.insert(parts, "]=")
            else
                error("Unsupported table key type: " .. keyType)
            end

            table.insert(parts, encodeValue(nestedValue))
            isFirst = false
        end

        table.insert(parts, "}")
        return table.concat(parts)
    end

    if value == nil then
        return "nil"
    end

    error("Unsupported value type: " .. valueType)
end

local function urlEncode(value)
    return (tostring(value):gsub("\n", "\r\n"):gsub("([^%w%-_%.~])", function(character)
        return string.format("%%%02X", string.byte(character))
    end))
end

local function fetch(name)
    local ok, res = pcall(function()
        return loadstring(game:HttpGet(baseUrl .. name))()
    end)

    if not ok then
        warn("Error loading module " .. name .. ": " .. tostring(res))
        return nil
    end

    print("Success loaded " .. name)
    return res
end

local function fetchSettings()
    local success, response = pcall(function()
        return loadstring(game:HttpGet("http://localhost:5000/settings.lua"))()
    end)

    if success then
        _G.settings = response
        return response
    end

    warn("Failed to fetch settings: " .. tostring(response))
    _G.settings = _G.settings or {}
    return _G.settings
end

_G.class = fetch("class.lua")
_G.offlineservice = fetch("offlineservice.lua")
_G.KeybindManager = fetch("keybindmanager.lua")

_G.fire = function(name, data)
    local success, err = pcall(function()
        local url = "http://localhost:5000/fire?name="
            .. urlEncode(name)
            .. "&data="
            .. urlEncode(encodeValue(data))
        game:HttpGet(url)
    end)

    if not success then
        warn("Failed to fire " .. name .. ": " .. tostring(err))
    end
end

_G.updateSetting = function(key, value)
    local success, err = pcall(function()
        local url = "http://localhost:5000/updateSettings?key="
            .. urlEncode(key)
            .. "&value="
            .. urlEncode(encodeValue(value))
        game:HttpGet(url)
        _G.settings = _G.settings or {}
        _G.settings[key] = value
    end)

    if not success then
        warn("Failed to update setting " .. key .. ": " .. tostring(err))
    end
end

_G.updateSettings = _G.updateSetting

_G.getSetting = function(key, defaultValue)
    _G.settings = _G.settings or fetchSettings() or {}

    if _G.settings[key] == nil then
        _G.updateSettings(key, defaultValue)
        _G.settings[key] = defaultValue
    end

    return _G.settings[key]
end

local loadedMods = {}
local modModules = {
    "mods/Fullbright.lua",
    "mods/Noclip.lua",
    "mods/Fly.lua",
    "mods/AnglerSafety.lua",
    "mods/ItemEsp.lua",
}

local function syncMods(settings)
    for _, mod in pairs(loadedMods) do
        if mod and type(mod.kill) == "function" and settings.destroyEnabled then
            mod:kill()
        end
    end

    if settings.destroyEnabled then
        _G.updateSettings("destroyEnabled", false)
        return
    end

    _G.KeybindManager:syncAll()
end

print("The PRO PC is on now!")

local settings = fetchSettings()

for _, moduleName in ipairs(modModules) do
    local loadedMod = fetch(moduleName)
    if loadedMod then
        loadedMods[loadedMod.name or moduleName] = loadedMod
    end
end

_G.getSetting("destroyEnabled", false)
_G.getSetting("destroyKeybind", "F9")

_G.KeybindManager:registerToggle({
    id = "DestroyToggle",
    settingKey = "destroyEnabled",
    keybindKey = "destroyKeybind",
    defaultKeybind = "F9",
    isMomentary = true,
    onToggle = function(enabled)
        if not enabled then
            return
        end

        for _, mod in pairs(loadedMods) do
            if mod and type(mod.kill) == "function" then
                mod:kill()
            end
        end

        _G.updateSettings("destroyEnabled", false)
    end,
})

syncMods(settings)
_G.KeybindManager:bindInput()

task.spawn(function()
    while true do
        syncMods(fetchSettings())
        task.wait(0.5)
    end
end)
