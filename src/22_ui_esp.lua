-- ==================================================================
-- Hanami / 22_ui_esp.lua — ESP tab (players, NPCs, crates, all colours)
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================

-- ── ESP : column 1 — Player / NPC ───────────────────────────────────
local espCol = EspTab:column()
local playerSec, npcSec = espCol:multi_section({ names = { "Player ESP", "NPC ESP" } })

local espEnabledToggle = playerSec:toggle({
    name = "Enabled", flag = "hn_espEnabled",
    enabled = CFG.espEnabled, default = CFG.espEnabled,
    callback = function(v) if v then enableESP() else disableESP() end end,
})
library.config_flags["hn_espEnabled"] = function(v) setToggle(espEnabledToggle, v) end
SA.FeatureKeybind(espEnabledToggle, "Enable Player ESP", "hn_bind_espEnabled",
    Enum.KeyCode.P, "espEnabled")

bindToggle(playerSec, "Visibility Check", "espVisibleCheck",
    "VIS / WALL / Flat / dot pickers sit inline on this row")
bindToggle(playerSec, "Show Names", "espShowName")
bindToggle(playerSec, "Show Distance", "espShowDist")
bindToggle(playerSec, "Show Health Bar", "espShowHealth")
bindToggle(playerSec, "Show Weapon", "espShowTool",
    "Reads equipped Tool / ItemId / Weapon attributes")
bindToggle(playerSec, "Show State", "espShowState",
    "Reads Knocked / Downed / Dead / State attributes, else HumanoidStateType")
bindToggle(playerSec, "Staff / Admin Detector", "espStaffDetect",
    "Read-only ESP tag: STAFF / ADMIN / NONE plus the AdminESP flag. No warnings, no attribute writes.")
local saStaffLabel = playerSec:label({ name = "staff 0 · admins 0" })
bindSlider(playerSec, "Max Distance (studs)", "espMaxDist", 200, 5000, 10, "")
addButton(playerSec, "Rebuild Player ESP", function()
    local list = {}
    for plr in pairs(espObjects) do list[#list + 1] = plr end
    for _, plr in ipairs(list) do clearESP(plr) end
end)
addButton(playerSec, "Show ESP Preview Panel", function()
    if SA.EspPreviewSet then SA.EspPreviewSet(true) end
end)
addButton(playerSec, "Rebuild ESP Preview", function()
    if SA.EspPreviewRefresh then SA.EspPreviewRefresh() end
end)

local npcEspEnabledToggle = npcSec:toggle({
    name = "Enabled", flag = "hn_npcEspEnabled",
    enabled = CFG.npcEspEnabled, default = CFG.npcEspEnabled,
    callback = function(v) if v then enableNpcESP() else disableNpcESP() end end,
})
library.config_flags["hn_npcEspEnabled"] = function(v) setToggle(npcEspEnabledToggle, v) end
SA.FeatureKeybind(npcEspEnabledToggle, "Enable NPC ESP", "hn_bind_npcEspEnabled",
    Enum.KeyCode.N, "npcEspEnabled")

bindToggle(npcSec, "Visibility Check", "npcVisibleCheck",
    "NPC VIS / WALL / Flat pickers sit inline on this row")
bindToggle(npcSec, "Show Names", "npcShowName")
bindToggle(npcSec, "Show Distance", "npcShowDist")
bindToggle(npcSec, "Show Health Bar", "npcShowHealth")
bindToggle(npcSec, "Show Weapon", "npcShowTool")
bindToggle(npcSec, "Show State", "npcShowState")
bindToggle(npcSec, "NPC Type Colours", "npcUseTypeColors",
    "Guard / Scavenger / Soldier pickers sit inline on this row")
bindSlider(npcSec, "Max Distance (studs)", "npcMaxDist", 200, 5000, 10, "")
npcSec:label({ name = "Detects: Guard / Scavenger / Soldier" })
addButton(npcSec, "Rescan NPCs", function()
    local snap = {}
    for m in pairs(npcObjects) do table.insert(snap, m) end
    for _, m in ipairs(snap) do clearNpc(m) end
    SA.RequestScan()
end)

-- ── ESP : column 2 — Crates / shared visual features ────────────────
local espCol2 = EspTab:column()
local crateSec, featSec = espCol2:multi_section({ names = { "Crate ESP", "ESP Features" } })

local crateEnabledToggle = crateSec:toggle({
    name = "Enabled", flag = "hn_crateEnabled",
    enabled = CFG.crateEnabled, default = CFG.crateEnabled,
    callback = function(v) if v then enableCrateESP() else disableCrateESP() end end,
})
library.config_flags["hn_crateEnabled"] = function(v) setToggle(crateEnabledToggle, v) end

bindToggle(crateSec, "FOV-Aware Crate ESP", "crateFovAware",
    "OFF by default: outside the FOV circle = one dot; inside = name + distance and an outline-only Highlight. No box or corners")
bindToggle(crateSec, "Show Military Crates", "crateShowMilitary")
bindToggle(crateSec, "Show Elite Crates", "crateShowElite")
bindToggle(crateSec, "Show Other Loot", "crateShowLoot",
    "Supply drops, airdrops, caches, chests and any other container")
bindToggle(crateSec, "Show Opened Crates", "crateShowOpened")
crateSec:label({ name = "── OPENED / UNOPENED STATE ──" })
bindToggle(crateSec, "Invert Crate State", "crateInvertState",
    "Turn ON if every label is backwards in your game. Flips OPENED <-> UNOPENED everywhere (label, colour, filter)")
bindToggle(crateSec, "Lid Angle Detection", "crateLidDetect",
    "OFF by default. Only use if the game exposes NO state attribute/Prompt; lid angle is an unreliable guess")
bindToggle(crateSec, "Crate Chams Highlight", "crateHighlight",
    "OFF by default. Only used when FOV-Aware Crate ESP is OFF; FOV-aware mode forces an outline-only Highlight inside FOV")
bindToggle(crateSec, "Loose Crate Detection", "crateLooseDetect",
    "Fuzzy name + attribute matching. Fixes crates named MilitaryCrate, Crate_Military, hashes, Folders…")
bindSlider(crateSec, "Crate Max Distance", "crateMaxDist", 200, 5000, 10, "")
addButton(crateSec, "Rescan Crates", function()
    local snap = {}
    for m in pairs(crateObjects) do table.insert(snap, m) end
    for _, m in ipairs(snap) do clearCrate(m) end
    SA.RequestScan()
end)

bindToggle(featSec, "Per-Element Colours", "espPerElementColors",
    "OFF by default: every element uses its own inline picker. OFF: the white visibility colour paints everything")
bindToggle(featSec, "Clean ESP (outlines only)", "espCleanMode",
    "OFF by default: no dark tag pills / chams fill; thin box + chams outline + text stroke only. OFF restores every individual widget")
featSec:label({ name = "Visible check: outer frame + dot + VIS tag" })
bindToggle(featSec, "Box Outline", "espShowBox")
bindToggle(featSec, "Corner Boxes", "espCornerBox")
bindToggle(featSec, "Chams Fill", "espShowFill")
bindToggle(featSec, "Chams Outline", "espShowOutline")
bindToggle(featSec, "Skeleton (bones)", "espShowSkeleton")
bindToggle(featSec, "Head Dot", "espShowHeadDot")
bindToggle(featSec, "Tracer Lines", "espShowTracer",
    "PLAYERS ONLY — line from Mouse / Center / Bottom to each player")
bindToggle(featSec, "Off-screen Arrows", "espShowOffscreen",
    "PLAYERS ONLY — FOV / screen-edge arrow pointing at off-screen players")
bindToggle(featSec, "Highlight Aim Target", "espHighlightTarget",
    "The entity silent aim is currently choosing is painted with the Target colour")
bindToggle(featSec, "Rainbow Mode", "espRainbow")
bindSlider(featSec, "Rainbow Speed", "espRainbowSpeed", 0.5, 10, 0.5, "")
bindToggle(featSec, "Distance Fade", "espFade")
bindSlider(featSec, "Fade Start (%)", "espFadeStart", 0, 95, 5, "%")
bindSlider(featSec, "Line Thickness", "espBoxThickness", 1, 5, 1, "")
bindDropdown(featSec, "Tracer Origin", "espTracerOrigin", { "Mouse", "Center", "Bottom" })
bindToggle(featSec, "Arrows Follow FOV", "espArrowFOV",
    "Off-screen arrows sit on the FOV circle edge and scale with Aim / Circle Radius")
featSec:label({ name = "── ALL ESP TEXT ──" })
bindSlider(featSec, "Text Size", "espTextSize", 6, 30, 1, "px")
bindToggle(featSec, "Show Health %", "espShowHealthText",
    "Adds an HP: NN% tag beside the box corner")
bindToggle(featSec, "Text Outline", "espTextOutline")
featSec:label({ name = "── LIVE FONT / TAG LAYOUT ──" })
bindToggle(featSec, "Tags On Box Side", "espTagSide",
    "VIS / WALL, state and HP sit beside the top-right corner. OFF stacks them under the weapon")
bindToggle(featSec, "Tag Backdrops", "espTagBackdrop",
    "Dark pill behind the weapon badge and each side tag")
featSec:label({ name = "Name above · Weapon below · Flags at corner" })
local fontStatusLabel = featSec:label({ name = "Font: " .. tostring(SA.ESP_FONT_NAME) })
SA.RegisterFontStatusLabel(fontStatusLabel)

-- ── BEST ESP PRESET (Players + NPCs) ────────────────────────────────
-- One source of truth: the curated startup snapshot in 01_config.lua.
-- Corner boxes + thin outlines stay readable; opaque chams fill, dark tag
-- pills, skeleton clutter and stuck off-screen tracers/arrows stay OFF.
-- One ESP-only source of truth: the best startup snapshot in 01_config.lua.
-- The button and the fresh-session applier use the same values.
local BEST_ESP = {}
for k, v in pairs(SA.BEST_ESP_STARTUP or {}) do
    BEST_ESP[k] = v
end

function SA.ApplyBestEsp()
    for k, v in pairs(BEST_ESP) do
        pcall(setFlag, k, v)
        CFG[k] = v
    end
    -- Re-open the floating preview so the result is visible immediately.
    if SA.EspPreviewSet then pcall(SA.EspPreviewSet, true) end
end

-- ── CLEAN ESP PRESET (outline-only) ─────────────────────────────────
-- The screenshot-style dark pills covered the top of the screen. This
-- preset keeps ONLY outlines: no tag backdrops, no chams fill, no corner
-- boxes / skeleton / tracers / arrows, and a black text stroke instead of
-- a dark rectangle behind every label.
local CLEAN_ESP = {
    espCleanMode = true, espPerElementColors = true,
    espShowBox = true, espCornerBox = false,
    espShowFill = false, espShowOutline = true,
    espShowSkeleton = false, espShowHeadDot = false,
    espShowTracer = false, espShowOffscreen = false,
    espHighlightTarget = true, espRainbow = false, espFade = false,
    espShowHealthText = false, espTextOutline = true,
    espTagSide = true, espTagBackdrop = false, espPreview = true,
}

function SA.ApplyCleanEsp()
    for k, v in pairs(CLEAN_ESP) do
        pcall(setFlag, k, v)
        CFG[k] = v
    end
    if SA.EspPreviewSet then pcall(SA.EspPreviewSet, true) end
end

function SA.BestEspState()
    local clean = CFG.espCleanMode == true
    return {
        enabled = CFG.espEnabled == true,
        npcEnabled = CFG.npcEspEnabled == true,
        cornerBox = (not clean) and CFG.espCornerBox == true,
        box = clean or CFG.espShowBox == true
            or ((not clean) and CFG.espCornerBox == true),
        preset = BEST_ESP,
        startup = SA.BEST_ESP_STARTUP,
    }
end

function SA.CleanEspState()
    local clean = CFG.espCleanMode == true
    return {
        enabled = clean,
        backdrop = (not clean) and CFG.espTagBackdrop == true,
        box = clean or CFG.espShowBox == true
            or ((not clean) and CFG.espCornerBox == true),
        cornerBox = (not clean) and CFG.espCornerBox == true,
        fill = (not clean) and CFG.espShowFill == true,
        outline = clean or CFG.espShowOutline == true,
        textOutline = clean or CFG.espTextOutline == true,
        preset = CLEAN_ESP,
    }
end


featSec:label({ name = "── CLEAN / BEST ESP PRESETS ──" })
addButton(featSec, "Apply Clean ESP", function() SA.ApplyCleanEsp() end)
addButton(featSec, "Apply Best ESP", function() SA.ApplyBestEsp() end)

-- Every colourpicker is chained INLINE by bindToggle / bindSlider /
-- bindDropdown in 21_ui_aiming.lua. The old ESP -> Colours mini-tabs are
-- gone: no colour picker lives in a different tab or section.

-- ── BETTER : ESP decluttering ───────────────────────────────────────
-- Four live filters (nearest N, aim target, team rule, entity cap) plus
-- a per-kind ON-SCREEN counter. All of it reads SA.EspPassStats(), which
-- is computed in the FX pass itself — so the numbers are what you see.
local declutterCol = EspTab:column()
local declutterSec = declutterCol:section({ name = "Declutter / Live Counts" })

bindToggle(declutterSec, "Only Nearest N Players", "espOnlyNearest",
    "Draw ESP for just the closest players; the current aim target always keeps a slot")
bindSlider(declutterSec, "Nearest N", "espNearestCount", 1, 20, 1, "")
bindToggle(declutterSec, "Only Current Aim Target", "espOnlyAimTarget",
    "Hide every player except the one silent aim / snapline is currently picking")
bindDropdown(declutterSec, "Team Filter", "espTeamMode", {
    "All", "Teammates Only", "Exclude Teammates",
})
bindToggle(declutterSec, "Show Live On-Screen Count", "espShowLiveCount")
local saEspCountLabel = declutterSec:label({ name = "players 0 · npcs 0 · crates 0" })

local saEspCountLast = 0
local saStaffLast = 0
bindRender(function()
    if not SA.Alive then return end
    local now = tick()
    if now - saEspCountLast < 0.2 then return end
    saEspCountLast = now
    -- Staff detector readout: one live read of the replicated role data.
    if now - saStaffLast >= 1 then
        saStaffLast = now
        pcall(function()
            local st = SA.StaffDetectState()
            saStaffLabel.set(string.format("staff %d · admins %d  (of %d players)",
                st.staff, st.admins, st.players))
        end)
        if SA.DetectorReadoutTick then pcall(SA.DetectorReadoutTick) end
    end
    pcall(function()
        local v = SA.EspPassStats()
        if CFG.espShowLiveCount then
            saEspCountLabel.set(string.format(
                "players %d · npcs %d · crates %d  ·  nearest %s",
                v.players, v.npcs, v.crates, tostring(v.nearest or "off")))
        else
            saEspCountLabel.set("live counts hidden (toggle above)")
        end
    end)
end)
