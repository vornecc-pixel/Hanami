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
infoSec:label({ name = "Menu key: RightShift (show/hide)" })
infoSec:label({ name = "Aim key: Insert | UI: Atlanta library" })
infoSec:label({ name = "Feature keys: P/N/G/B/M · right-click = None" })
infoSec:label({ name = "ESP: green = visible, red = behind wall" })
infoSec:label({ name = "ESP -> Colours: a picker for EVERY element" })
infoSec:label({ name = "Crates: fuzzy detection + live registry" })
infoSec:label({ name = "NPC names: Guard / Scavenger / Soldier" })
infoSec:label({ name = "Ballistics: all 20 guns + every attribute" })
infoSec:label({ name = "Attachments: auto tune on 12 detected mods" })
infoSec:label({ name = "Gun Mods: GC scan (getgc + rawset)" })
infoSec:label({ name = "Bow Mods: instant charge + no cooldown only" })
infoSec:label({ name = "Silent aim + manip: GUNS ONLY (bows skipped)" })

-- ── MISC : Quick Actions ───────────────────────────────────────────
local actCol = MiscTab:column()
local actSec = actCol:section({ name = "Quick Actions" })

addButton(actSec, "Scan All Entities", function()
    SA.PrintScan()
end)

addButton(actSec, "Disable All", function()
    setFlag("masterEnabled", false)
    setFlag("gmEnabled", false)
    setFlag("bowModsEnabled", false)
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

addButton(actSec, "Print Feature Keybinds", function()
    SA.FeatureBindDiag()
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
    setFlag("bowModsEnabled", false)
    setFlag("bowInstantCharge", false)
    setFlag("bowNoCooldown", false)
    if SA.BowModsRestore then pcall(SA.BowModsRestore) end
    disableESP(); disableNpcESP(); disableCrateESP()
    if SA.EspPreviewDispose then pcall(SA.EspPreviewDispose) end
    if SA.NearestWindowDispose then pcall(SA.NearestWindowDispose) end
    RunService:UnbindFromRenderStep(snapName)
    RunService:UnbindFromRenderStep(restoreName)
    -- leave no snapped camera and no disabled CanQuery parts
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
