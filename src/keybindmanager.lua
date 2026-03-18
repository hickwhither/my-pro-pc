local KeybindManager = {
    bindings = {},
    bindingOrder = {},
    inputConnection = nil,
}

local UserInputService = game:GetService("UserInputService")

local function keyCodeFromSetting(value)
    if typeof(value) ~= "string" then
        return nil
    end

    return Enum.KeyCode[value:upper()]
end

function KeybindManager:registerToggle(options)
    assert(type(options) == "table", "registerToggle options must be a table")
    assert(type(options.id) == "string", "registerToggle requires an id")
    assert(type(options.settingKey) == "string", "registerToggle requires a settingKey")
    assert(type(options.defaultKeybind) == "string", "registerToggle requires a defaultKeybind")
    assert(type(options.onToggle) == "function", "registerToggle requires an onToggle callback")

    local binding = {
        id = options.id,
        label = options.label or options.id,
        settingKey = options.settingKey,
        keybindKey = options.keybindKey or (options.settingKey .. "Keybind"),
        defaultKeybind = options.defaultKeybind,
        defaultEnabled = options.defaultEnabled == true,
        isMomentary = options.isMomentary == true,
        onToggle = options.onToggle,
        getState = options.getState,
    }

    if not self.bindings[binding.id] then
        table.insert(self.bindingOrder, binding.id)
    end

    self.bindings[binding.id] = binding

    _G.getSetting(binding.settingKey, binding.defaultEnabled)
    _G.getSetting(binding.keybindKey, binding.defaultKeybind)

    return binding
end

function KeybindManager:syncBinding(binding)
    local enabled = _G.getSetting(binding.settingKey, binding.defaultEnabled)
    binding.onToggle(enabled)
end

function KeybindManager:syncAll()
    for _, bindingId in ipairs(self.bindingOrder) do
        local binding = self.bindings[bindingId]
        if binding then
            self:syncBinding(binding)
        end
    end
end

function KeybindManager:bindInput()
    if self.inputConnection then
        return
    end

    self.inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed or input.UserInputType ~= Enum.UserInputType.Keyboard then
            return
        end

        for _, bindingId in ipairs(self.bindingOrder) do
            local binding = self.bindings[bindingId]
            local keybind = _G.getSetting(binding.keybindKey, binding.defaultKeybind)
            local keyCode = keyCodeFromSetting(keybind)

            if keyCode and input.KeyCode == keyCode then
                if binding.isMomentary then
                    _G.updateSettings(binding.settingKey, true)
                else
                    local currentState = _G.getSetting(binding.settingKey, binding.defaultEnabled)
                    _G.updateSettings(binding.settingKey, not currentState)
                end
                return
            end
        end
    end)
end

return KeybindManager
