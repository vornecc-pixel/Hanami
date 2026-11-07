-- ==================================================================
-- Hanami / 22_ui_misc.lua — Misc tab, quick actions, UI init
-- Loaded in order by loader.lua. Parts are joined into ONE chunk
-- before running, so every `local` is shared just like the original.
-- ==================================================================

-- ── MISC : Info ────────────────────────────────────────────────────
local infoCol = MiscTab:column()
local infoSec = infoCol:section({ name = "Info" })
infoSec:label({ name = "@abusegpt — full suite" })
infoSec:label({ name = "Aim + Wall Pen + Player/NPC/Crate ESP + Gun Mods" })
infoSec:label({ name = "Toggle key: RightShift (silent aim)" })
infoSec:label({ name = "Menu key: Insert | UI: Atlanta library" })
infoSec:label({ name = "ESP: green = visible, red = behind wall" })
infoSec:label({ name = "NPC names: Guard / Scavenger / Soldier" })
infoSec:label({ name = "Gun Mods: GC scan (getgc + rawset)" })

-- ── MISC : Quick Actions ───────────────────────────────────────────
local actCol = MiscTab:column()
local actSec = actCol:section({ name = "Quick Actions" })

addButton(actSec, "Scan All Entities", function()
    SA.PrintScan()
end)

addButton(actSec, "Disable All", function()
    setFlag("masterEnabled", false)
    setFlag("gmEnabled", false)
    setFlag("espEnabled", false)
    setFlag("npcEspEnabled", false)
    setFlag("crateEnabled", false)
    setFlag("showFov", false)
    setFlag("snapLineEnabled", false)
end)

addButton(actSec, "Apply Blatant", function()
    setFlag("masterEnabled", true)
    presetDropdown.set("Blatant")
end)

addButton(actSec, "Toggle Manip", function()
    setFlag("manipulation", not CFG.manipulation)
    print("[sa] manip:", CFG.manipulation and "on" or "off")
end)

addButton(actSec, "Unload Everything", function()
    setFlag("masterEnabled", false)
    setFlag("gmEnabled", false)
    disableESP(); disableNpcESP(); disableCrateESP()
    RunService:UnbindFromRenderStep(snapName)
    RunService:UnbindFromRenderStep(restoreName)
    pcall(function() window.set_menu_visibility(false) end)
    print("[sa] unloaded")
end)

-- ── Initialisation (from the Atlanta template) ─────────────────────
Aiming.open_tab()

pcall(function() library:config_list_update() end)
for index, value in themes.preset do
    pcall(function() library:update_theme(index, value) end)
end

task.wait()
pcall(function() library.old_config = library:get_config() end)
