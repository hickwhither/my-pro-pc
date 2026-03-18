local OfflineService = _G.class()

function OfflineService:__init(name)
    assert(type(name) == "string", "Name must be a string")
    _G[name] = self
    self.name = name
    self.handlers = {}
    self._cleanups = {}
    self._states = {}
    print("[" .. name .. "] is here~")
end

function OfflineService:addCleanup(cleanup)
    if type(cleanup) ~= "function" then
        return cleanup
    end

    table.insert(self._cleanups, cleanup)
    return cleanup
end

function OfflineService:trackConnection(connection)
    if not connection then
        return connection
    end

    return self:addCleanup(function()
        if connection.Disconnect then
            connection:Disconnect()
        end
    end)
end

function OfflineService:trackInstance(instance)
    if not instance then
        return instance
    end

    return self:addCleanup(function()
        if instance.Parent then
            instance:Destroy()
        end
    end)
end

function OfflineService:cleanup()
    for index = #self._cleanups, 1, -1 do
        local cleanup = self._cleanups[index]
        self._cleanups[index] = nil
        pcall(cleanup)
    end
end

function OfflineService:registerToggle(options)
    assert(_G.KeybindManager, "KeybindManager must be loaded before mods register toggles")

    local stateKey = options.stateKey or options.settingKey
    self._states[stateKey] = nil

    return _G.KeybindManager:registerToggle({
        id = options.id or (self.name .. "." .. options.settingKey),
        label = options.label,
        settingKey = options.settingKey,
        keybindKey = options.keybindKey,
        defaultKeybind = options.defaultKeybind,
        defaultEnabled = options.defaultEnabled,
        isMomentary = options.isMomentary,
        getState = function()
            return self._states[stateKey]
        end,
        onToggle = function(enabled)
            if self._states[stateKey] == enabled then
                return
            end

            self._states[stateKey] = enabled
            options.onToggle(enabled)
        end,
    })
end

function OfflineService:setState(stateKey, enabled)
    self._states[stateKey] = enabled
end

function OfflineService:getState(stateKey)
    return self._states[stateKey]
end

function OfflineService:killAll(toggleSettingKeys)
    if toggleSettingKeys then
        for _, settingKey in ipairs(toggleSettingKeys) do
            self._states[settingKey] = false
            _G.updateSettings(settingKey, false)
        end
    end

    self:cleanup()
end

return OfflineService
