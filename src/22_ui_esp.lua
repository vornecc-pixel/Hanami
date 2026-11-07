-- ==================================================================
-- Hanami / 22_ui_esp.lua — ESP tab (players, NPCs, crates, all colours)
-- Loaded in order by loader.lua. Parts are joined into ONE chunk
-- before running, so every `local` is shared just like the original.
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

bindToggle(playerSec, "Visibility Check", "espVisibleCheck",
    "GREEN = clear line of sight, RED = behind a wall. Both colours are pickable in Colours -> Player")
bindToggle(playerSec, "Show Names", "espShowName")
bindToggle(playerSec, "Show Distance", "espShowDist")
bindToggle(playerSec, "Show Health Bar", "espShowHealth")
bindToggle(playerSec, "Show Weapon", "espShowTool",
    "Reads equipped Tool / ItemId / Weapon attributes")
bindToggle(playerSec, "Show State", "espShowState",
    "Reads Knocked / Downed / Dead / State attributes, else HumanoidStateType")
bindSlider(playerSec, "Max Distance (studs)", "espMaxDist", 200, 5000, 10, "")
addButton(playerSec, "Scan Players", function() SA.PrintScan("PLAYER") end)

local npcEspEnabledToggle = npcSec:toggle({
    name = "Enabled", flag = "hn_npcEspEnabled",
    enabled = CFG.npcEspEnabled, default = CFG.npcEspEnabled,
    callback = function(v) if v then enableNpcESP() else disableNpcESP() end end,
})
library.config_flags["hn_npcEspEnabled"] = function(v) setToggle(npcEspEnabledToggle, v) end

bindToggle(npcSec, "Visibility Check", "npcVisibleCheck",
    "Uses the NPC green/red colourpickers in Colours -> NPC")
bindToggle(npcSec, "Show Names", "npcShowName")
bindToggle(npcSec, "Show Distance", "npcShowDist")
bindToggle(npcSec, "Show Health Bar", "npcShowHealth")
bindToggle(npcSec, "Show Weapon", "npcShowTool")
bindToggle(npcSec, "Show State", "npcShowState")
bindToggle(npcSec, "NPC Type Colours", "npcUseTypeColors",
    "Guard / Scavenger / Soldier each get their own colour (Colours -> NPC)")
bindSlider(npcSec, "Max Distance (studs)", "npcMaxDist", 200, 5000, 10, "")
npcSec:label({ name = "Detects: Guard / Scavenger / Soldier" })
addButton(npcSec, "Rescan NPCs", function()
    local snap = {}
    for m in pairs(npcObjects) do table.insert(snap, m) end
    for _, m in ipairs(snap) do clearNpc(m) end
    local list = SA.RefreshNpcs()
    if CFG.npcEspEnabled then
        for _, m in ipairs(list) do buildNpc(m) end
    end
end)
addButton(npcSec, "Scan NPCs", function() SA.PrintScan("NPC") end)

-- ── ESP : column 2 — Crates / shared visual features ────────────────
local espCol2 = EspTab:column()
local crateSec, featSec = espCol2:multi_section({ names = { "Crate ESP", "ESP Features" } })

local crateEnabledToggle = crateSec:toggle({
    name = "Enabled", flag = "hn_crateEnabled",
    enabled = CFG.crateEnabled, default = CFG.crateEnabled,
    callback = function(v) if v then enableCrateESP() else disableCrateESP() end end,
})
library.config_flags["hn_crateEnabled"] = function(v) setToggle(crateEnabledToggle, v) end

bindToggle(crateSec, "Show Military Crates", "crateShowMilitary")
bindToggle(crateSec, "Show Elite Crates", "crateShowElite")
bindToggle(crateSec, "Show Other Loot", "crateShowLoot",
    "Supply drops, airdrops, caches, chests and any other container")
bindToggle(crateSec, "Show Opened Crates", "crateShowOpened")
bindToggle(crateSec, "Loose Crate Detection", "crateLooseDetect",
    "Fuzzy name + attribute matching. Fixes crates named MilitaryCrate, Crate_Military, hashes, Folders…")
bindSlider(crateSec, "Crate Max Distance", "crateMaxDist", 200, 5000, 10, "")
crateSec:label({ name = "Live registry re-scans Workspace every 1.5s" })
addButton(crateSec, "Rescan Crates", function()
    local snap = {}
    for m in pairs(crateObjects) do table.insert(snap, m) end
    for _, m in ipairs(snap) do clearCrate(m) end
    local n = SA.RefreshCrates()
    print("[sa] crates found:", n)
end)
addButton(crateSec, "Print Crate Names (debug)", function()
    SA.PrintCrateCandidates()
end)

bindToggle(featSec, "Per-Element Colours", "espPerElementColors",
    "ON (default): every element uses its own picker. OFF: the green/red visibility colour paints everything")
featSec:label({ name = "Visible check: outer frame + dot + VIS tag" })
bindToggle(featSec, "Box Outline", "espShowBox")
bindToggle(featSec, "Corner Boxes", "espCornerBox")
bindToggle(featSec, "Chams Fill", "espShowFill")
bindToggle(featSec, "Chams Outline", "espShowOutline")
bindToggle(featSec, "Skeleton (bones)", "espShowSkeleton")
bindToggle(featSec, "Head Dot", "espShowHeadDot")
bindToggle(featSec, "Tracer Lines", "espShowTracer")
bindToggle(featSec, "Off-screen Arrows", "espShowOffscreen")
bindToggle(featSec, "Highlight Aim Target", "espHighlightTarget",
    "The entity silent aim is currently choosing is painted with the Target colour")
bindToggle(featSec, "Rainbow Mode", "espRainbow")
bindSlider(featSec, "Rainbow Speed", "espRainbowSpeed", 0.5, 10, 0.5, "")
bindToggle(featSec, "Distance Fade", "espFade")
bindSlider(featSec, "Fade Start (%)", "espFadeStart", 0, 95, 5, "%")
bindSlider(featSec, "Line Thickness", "espBoxThickness", 1, 5, 1, "")
bindDropdown(featSec, "Tracer Origin", "espTracerOrigin", { "Mouse", "Center", "Bottom" })

-- ── ESP : column 3 — one colourpicker for EVERY drawn element ────────
-- Atlanta labels expose a `right_holder`, so each labelled row can carry
-- its own colourpicker without a dummy toggle. `cfg.set` fires on build,
-- which writes straight back into the shared ESP_COLORS table.
local COLOR_GROUPS = {
    { title = "Player", rows = {
        { "Visible (clear LOS)", "playerVisible" },
        { "Hidden (behind wall)", "playerHidden" },
        { "Flat (check off)", "playerFlat" },
        { "Visibility dot", "playerVisDot" },
        { "Name text", "playerName" },
        { "Distance text", "playerDistance" },
        { "Scanner text", "playerInfo" },
        { "Box outline", "playerBox" },
        { "Chams fill", "playerFill" },
        { "Chams outline", "playerOutline" },
        { "Health · full", "playerHealthHigh" },
        { "Health · empty", "playerHealthLow" },
        { "Skeleton", "playerSkeleton" },
        { "Head dot", "playerHeadDot" },
        { "Tracer", "playerTracer" },
        { "Off-screen arrow", "playerOffscreen" },
    } },
    { title = "NPC", rows = {
        { "Visible (clear LOS)", "npcVisible" },
        { "Hidden (behind wall)", "npcHidden" },
        { "Flat (check off)", "npcFlat" },
        { "Guard", "npcGuard" },
        { "Scavenger", "npcScavenger" },
        { "Soldier", "npcSoldier" },
        { "Name text", "npcName" },
        { "Distance text", "npcDistance" },
        { "Scanner text", "npcInfo" },
        { "Box outline", "npcBox" },
        { "Chams fill", "npcFill" },
        { "Chams outline", "npcOutline" },
        { "Health · full", "npcHealthHigh" },
        { "Health · empty", "npcHealthLow" },
        { "Skeleton", "npcSkeleton" },
        { "Head dot", "npcHeadDot" },
        { "Tracer", "npcTracer" },
        { "Off-screen arrow", "npcOffscreen" },
    } },
    { title = "Crate", rows = {
        { "Military", "crateMilitary" },
        { "Elite", "crateElite" },
        { "Other loot", "crateLoot" },
        { "Opened", "crateOpened" },
        { "State text", "crateState" },
        { "Distance text", "crateDistance" },
        { "Tracer", "crateTracer" },
        { "Off-screen arrow", "crateOffscreen" },
    } },
    { title = "Global", rows = {
        { "Snapline visible", "snapVisible" },
        { "Snapline blocked", "snapHidden" },
        { "Lead marker", "lead" },
        { "FOV circle", "fov" },
        { "FOV (wall pen on)", "fovManip" },
        { "Aim target", "target" },
    } },
}

local colorCol = EspTab:column()
local groupNames = {}
for _, g in ipairs(COLOR_GROUPS) do table.insert(groupNames, g.title) end
local colorSections = { colorCol:multi_section({ names = groupNames }) }

for i, group in ipairs(COLOR_GROUPS) do
    local sec = colorSections[i]
    sec:label({ name = "COLOURS · " .. group.title:upper() })
    sec:label({ name = "Every row has its own picker — instant" })
    sec:label({ name = "Visible/Hidden = frame, dot and VIS tag" })
    if group.title == "Crate" then
        sec:label({ name = "Type colour also paints box / fill / name" })
    end
    for _, row in ipairs(group.rows) do
        local key = row[2]
        local lbl = sec:label({ name = row[1] })
        lbl:colorpicker({
            name = row[1], flag = "hn_col_" .. key,
            color = ESP_COLORS[key],
            callback = function(c) ESP_COLORS[key] = c end,
        })
    end
end
