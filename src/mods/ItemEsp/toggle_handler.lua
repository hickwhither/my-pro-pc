return function(deps)
    local itemEsp = deps.itemEsp
    local keys = deps.keys
    local onEspToggle = deps.onEspToggle
    local onAutoPickupToggle = deps.onAutoPickupToggle
    local onRemoteUseToggle = deps.onRemoteUseToggle

    itemEsp:registerToggle({
        id = "ItemEspToggle",
        settingKey = keys.ESP_ENABLED_KEY,
        keybindKey = "itemEspKeybind",
        defaultKeybind = "F12",
        onToggle = onEspToggle,
    })

    itemEsp:registerToggle({
        id = "ItemAutoPickupToggle",
        settingKey = keys.AUTO_PICKUP_ENABLED_KEY,
        keybindKey = "itemAutoPickupKeybind",
        defaultKeybind = "J",
        onToggle = onAutoPickupToggle,
    })

    itemEsp:registerToggle({
        id = "RemoteUseToggle",
        settingKey = keys.REMOTE_USE_ENABLED_KEY,
        keybindKey = "remoteUseKeybind",
        defaultKeybind = "K",
        onToggle = onRemoteUseToggle,
    })
end
