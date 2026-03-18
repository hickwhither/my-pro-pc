local baseUrl = ""
baseUrl = "http://localhost:5000/src/" -- debug

local UserInputService = game:GetService("UserInputService")

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

local function keyCodeFromSetting(value)
    if typeof(value) ~= "string" then
        return nil
    end

    return Enum.KeyCode[value:upper()]
end

local function buildSettingKey(modName, suffix)
    return string.lower(modName) .. suffix
end

local loadedMods = {}

local modDefinitions = {
    {
        name = "Fullbright",
        moduleName = "mods/Fullbright.lua",
    },
    {
        name = "Noclip",
        moduleName = "mods/Noclip.lua",
    },
    {
        name = "Fly",
        moduleName = "mods/Fly.lua",
    },
    {
        name = "Destroy",
        defaultKeybind = "F9",
        isMomentary = true,
        run = function()
            local targetMods = {"Fullbright", "Noclip", "Fly"}

            for _, modName in ipairs(targetMods) do
                local targetMod = loadedMods[modName]
                local enabledKey = buildSettingKey(modName, "Enabled")
                if targetMod and type(targetMod.toggle) == "function" then
                    targetMod.toggle(false)
                else
                    _G.updateSettings(enabledKey, false)
                end
            end

            _G.updateSettings("destroyEnabled", false)
        end,
    },
}

local modStates = {}

local function syncMods(settings)
    for _, modInfo in ipairs(modDefinitions) do
        local enabledKey = modInfo.enabledKey
        local enabled = settings[enabledKey]

        if enabled == nil then
            enabled = false
            _G.updateSettings(enabledKey, enabled)
        end

        if modInfo.run then
            if enabled then
                modInfo.run()
            end
        else
            local loadedMod = loadedMods[modInfo.name]
            if loadedMod and type(loadedMod.toggle) == "function" and modStates[modInfo.name] ~= enabled then
                loadedMod.toggle(enabled)
                modStates[modInfo.name] = enabled
            end
        end
    end
end

local function bindInput()
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed or input.UserInputType ~= Enum.UserInputType.Keyboard then
            return
        end

        for _, modInfo in ipairs(modDefinitions) do
            local keybind = _G.getSetting(modInfo.keybindKey, modInfo.defaultKeybind)
            local keyCode = keyCodeFromSetting(keybind)
            if keyCode and input.KeyCode == keyCode then
                if modInfo.isMomentary then
                    _G.updateSettings(modInfo.enabledKey, true)
                else
                    _G.updateSettings(modInfo.enabledKey, not _G.getSetting(modInfo.enabledKey, false))
                end
                return
            end
        end
    end)
end

print("The PRO PC is on now!")

local settings = fetchSettings()

for _, modInfo in ipairs(modDefinitions) do
    modInfo.enabledKey = buildSettingKey(modInfo.name, "Enabled")
    modInfo.keybindKey = buildSettingKey(modInfo.name, "Keybind")

    if modInfo.moduleName then
        local loadedMod = fetch(modInfo.moduleName)
        if loadedMod then
            loadedMods[modInfo.name] = loadedMod
            modInfo.defaultKeybind = loadedMod.defaultKeybind
            modStates[modInfo.name] = false
        end
    end

    _G.getSetting(modInfo.enabledKey, false)
    _G.getSetting(modInfo.keybindKey, modInfo.defaultKeybind)
end

syncMods(settings)
bindInput()

task.spawn(function()
    while true do
        syncMods(fetchSettings())
        task.wait(1)
    end
end)
