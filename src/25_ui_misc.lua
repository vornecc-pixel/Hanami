-- ==================================================================
-- Hanami / 25_ui_misc.lua — Misc tab, quick actions, UI init
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================

-- ── MISC : Info ────────────────────────────────────────────────────
local infoCol = MiscTab:column()
local infoSec = infoCol:section({ name = "Info" })
infoSec:label({ name = "@abusegpt — full suite" })
infoSec:label({ name = "Aim + Wall Pen + Player/NPC/Crate ESP + Gun Mods" })
infoSec:label({ name = "Toggle key: RightShift (silent aim)" })
infoSec:label({ name = "Menu key: Insert | UI: Atlanta library" })
infoSec:label({ name = "ESP: green = visible, red = behind wall" })
infoSec:label({ name = "ESP -> Colours: a picker for EVERY element" })
infoSec:label({ name = "Crates: fuzzy detection + live registry" })
infoSec:label({ name = "NPC names: Guard / Scavenger / Soldier" })
infoSec:label({ name = "Ballistics: per-gun speed + drop + alt ammo" })
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

addButton(actSec, "Reset ESP Colours", function()
    for k, v in pairs(ESP_DEFAULT_COLORS) do
        local setter = library.config_flags["hn_col_" .. k]
        if setter then setter(v, 1) else ESP_COLORS[k] = v end
    end
    print("[sa] ESP colours reset to defaults")
end)

addButton(actSec, "Unload Everything", function()
    SA.Alive = false
    setFlag("showFov", false)
    setFlag("masterEnabled", false)
    setFlag("gmEnabled", false)
    disableESP(); disableNpcESP(); disableCrateESP()
    if SA.EspPreviewDispose then pcall(SA.EspPreviewDispose) end
    RunService:UnbindFromRenderStep(snapName)
    RunService:UnbindFromRenderStep(restoreName)
    -- leave no snapped camera, no held bow snap and no disabled CanQuery parts
    SA.BowDrawing = false
    SA.BowSnapHold = 0
    SA.TapRestore(_G.__saTapCF, _G.__saTapCam)
    _G.__saTapCF, _G.__saTapCam, _G.__saTapAt = nil, nil, nil
    saManipRestore()
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
