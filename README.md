# my-pro-pc

A lightweight Roblox mod loader for local client-side utility mods.

## Included mods

- `Fullbright` (`F6`) - locks bright daytime lighting.
- `Noclip` (`F7`) - disables your character collision so you can walk through parts.
- `Fly` (`F8`) - enables camera-aligned flight movement.
- `Destroy` (`F9`) - emergency off switch that disables the other loaded mods.

If you want full fly noclip, enable both `Fly` and `Noclip` together.

## Project layout

- `src/main.lua` loads shared helpers, fetches settings, and starts each mod.
- `src/offlineservice.lua` creates the simple service objects returned by mods.
- `src/mods/*.lua` contains one file per mod.
- `settings.json` stores persisted values used by `_G.getSetting` and `_G.updateSettings`.

## How mods work

Each mod is a Lua module under `src/mods/`.

Basic pattern:

1. Create a service with `_G.offlineservice("YourModName")`.
2. Create setting keys for enabled state + keybind.
3. Implement `toggle(enabled)` to apply and clean up the feature.

## Simple mod template

```lua
local Example = _G.offlineservice("Example")
Noclip.defaultKeybind = "K"

local function keyCodeFromSetting(value)
    if typeof(value) ~= "string" then
        return nil
    end

    return Enum.KeyCode[value:upper()]
end

function Example.toggle(enabled)
    print("Example enabled:", enabled)
    _G.updateSettings(ENABLED_KEY, enabled)
end
```

## Adding a new mod

1. Create `src/mods/YourMod.lua`.
2. Follow the template above.
3. Add the file path to the `modDefinitions` table in `src/main.lua`.
4. Reload the loader/debug server so the new file is fetched.

## Notes for mod authors

- Keep every mod self-contained.
- Persist any toggle state with `_G.updateSettings`.
- Create missing defaults at startup with `_G.getSetting`.
- If your mod creates instances or connections, clean them up on disable.
- For panic/cleanup actions, prefer one-shot controls that safely disable existing mods.
