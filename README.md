# my-pro-pc

A lightweight Roblox mod loader for local client-side utility mods.

## Included mods

- `Fullbright` (`F6`) - locks bright daytime lighting.
- `Noclip` (`F7`) - disables your character collision so you can walk through parts.
- `Fly` (`F8`) - enables camera-aligned flight movement.
- `Destroy` (`F9`) - emergency off switch that disables the other loaded mods.
- `AnglerSafety` (`F10`/`F11`) - watches Angler-class entities with ESP and optional height-based safe mode teleport.
- `ItemEsp` (`F12`/`J`/`K`) - highlights keycards and password papers, auto-picks visible keycards/papers, and can extend proximity prompt range for items plus generators.

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
2. Register one or more toggles through the shared keybind manager.
3. Implement explicit `enable`, `disable`, and `kill` cleanup paths for the feature.

## Simple mod template

```lua
local Example = _G.offlineservice("Example")

function Example:enable()
    print("Example enabled")
end

function Example:disable()
    print("Example disabled")
end

function Example:kill()
    self:disable()
    _G.updateSettings("exampleEnabled", false)
end

Example:registerToggle({
    settingKey = "exampleEnabled",
    keybindKey = "exampleKeybind",
    defaultKeybind = "K",
    onToggle = function(enabled)
        if enabled then
            Example:enable()
        else
            Example:disable()
        end
    end,
})
```

## Adding a new mod

1. Create `src/mods/YourMod.lua`.
2. Follow the template above.
3. Add the file path to the `modModules` table in `src/main.lua`.
4. Reload the loader/debug server so the new file is fetched.

## Notes for mod authors

- Keep every mod self-contained.
- Register toggles with `_G.KeybindManager` via `service:registerToggle(...)`.
- Persist any toggle state with `_G.updateSettings`.
- Create missing defaults at startup with `_G.getSetting`.
- If your mod creates instances or connections, clean them up on disable and hard-stop them in `kill()`.
- For panic/cleanup actions, prefer one-shot controls that safely disable existing mods.
