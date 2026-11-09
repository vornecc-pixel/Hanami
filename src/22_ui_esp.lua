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
addButton(playerSec, "Print Player ESP State", function()
    SA.PlayerEspDiag()
end)
addButton(playerSec, "Rebuild Player ESP", function()
    local list = {}
    for plr in pairs(espObjects) do list[#list + 1] = plr end
    for _, plr in ipairs(list) do clearESP(plr) end
    print("[esp] cleared " .. #list .. " objects; render loop will rebuild them")
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
    SA.RequestScan()
    print("[sa] NPC rescan queued — background walker, no frame freeze")
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
crateSec:label({ name = "── OPENED / UNOPENED STATE ──" })
bindToggle(crateSec, "Invert Crate State", "crateInvertState",
    "Turn ON if every label is backwards in your game. Flips OPENED <-> UNOPENED everywhere (label, colour, filter)")
bindToggle(crateSec, "Lid Angle Detection", "crateLidDetect",
    "OFF by default. Only use if the game exposes NO state attribute/Prompt; lid angle is an unreliable guess")
bindToggle(crateSec, "Crate Chams Highlight", "crateHighlight",
    "OFF by default. When ON, the highlight is bound to the crate's own anchor part only — never to scenery")
bindToggle(crateSec, "Loose Crate Detection", "crateLooseDetect",
    "Fuzzy name + attribute matching. Fixes crates named MilitaryCrate, Crate_Military, hashes, Folders…")
bindSlider(crateSec, "Crate Max Distance", "crateMaxDist", 200, 5000, 10, "")
addButton(crateSec, "Rescan Crates", function()
    local snap = {}
    for m in pairs(crateObjects) do table.insert(snap, m) end
    for _, m in ipairs(snap) do clearCrate(m) end
    SA.RequestScan()
    print("[sa] crate rescan queued —", #SA.GetCrates(), "known so far")
end)
addButton(crateSec, "Print Crate Names (debug)", function()
    SA.PrintCrateCandidates()
end)
addButton(crateSec, "Print Crate States (debug)", function()
    SA.PrintCrateStates()
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
featSec:label({ name = "── TAHOMA LAYOUT ──" })
bindToggle(featSec, "Tags On Box Side", "espTagSide",
    "VIS / WALL, state and HP sit beside the top-right corner. OFF stacks them under the weapon")
bindToggle(featSec, "Tag Backdrops", "espTagBackdrop",
    "Dark pill behind the weapon badge and each side tag")
featSec:label({ name = "Name above · Weapon below · Flags at corner" })
featSec:label({ name = "Font: " .. tostring(SA.ESP_FONT_NAME) })

-- ── BEST ESP PRESET (Players + NPCs) ────────────────────────────────
-- The curated "best" set: every feature that makes an ESP readable and
-- informative, without the two that deliberately wash colours out
-- (Rainbow) or hide distant boxes (Distance Fade). Applied through the
-- Atlanta flags so all widgets stay in sync, and mirrored into CFG as a
-- safety net for any flag a library build never registered.
local BEST_ESP = {
    -- Player ESP
    espEnabled = true, espVisibleCheck = true, espShowName = true,
    espShowDist = true, espShowHealth = true, espShowTool = true,
    espShowState = true,
    -- NPC ESP
    npcEspEnabled = true, npcVisibleCheck = true, npcShowName = true,
    npcShowDist = true, npcShowHealth = true, npcShowTool = true,
    npcShowState = true, npcUseTypeColors = true,
    -- Shared visual features
    espPerElementColors = true, espShowBox = true, espCornerBox = true,
    espShowFill = true, espShowOutline = false, espShowSkeleton = true,
    espShowHeadDot = true, espShowTracer = true, espShowOffscreen = true,
    espHighlightTarget = true, espRainbow = false, espFade = false,
    espArrowFOV = true, espShowHealthText = true, espTextOutline = true,
    espTagSide = true, espTagBackdrop = true, espPreview = true,
}

function SA.ApplyBestEsp()
    for k, v in pairs(BEST_ESP) do
        pcall(setFlag, k, v)
        CFG[k] = v
    end
    -- Re-open the floating preview so the result is visible immediately.
    if SA.EspPreviewSet then pcall(SA.EspPreviewSet, true) end
    print("[esp] Best ESP applied (Player + NPC): 15 visual features ON")
end

function SA.EspFeatureDiag()
    print("════════════ ESP FEATURES ════════════")
    local groups = {
        { "PLAYER", { "espEnabled", "espVisibleCheck", "espShowName",
            "espShowDist", "espShowHealth", "espShowTool", "espShowState" } },
        { "NPC", { "npcEspEnabled", "npcVisibleCheck", "npcShowName",
            "npcShowDist", "npcShowHealth", "npcShowTool", "npcShowState",
            "npcUseTypeColors" } },
        { "SHARED", { "espPerElementColors", "espShowBox", "espCornerBox",
            "espShowFill", "espShowOutline", "espShowSkeleton", "espShowHeadDot",
            "espShowTracer", "espShowOffscreen", "espHighlightTarget",
            "espRainbow", "espFade", "espArrowFOV", "espShowHealthText",
            "espTextOutline", "espTagSide", "espTagBackdrop" } },
    }
    for _, g in ipairs(groups) do
        local bits = {}
        for _, k in ipairs(g[2]) do
            bits[#bits + 1] = k .. "=" .. tostring(CFG[k])
        end
        print(string.format("[%-6s] %s", g[1], table.concat(bits, " | ")))
    end
    local missing = {}
    for k in pairs(BEST_ESP) do
        if not library.config_flags["hn_" .. k] then
            missing[#missing + 1] = k
        end
    end
    table.sort(missing)
    print("unbound UI flags:", #missing == 0 and "none (all functional)"
        or table.concat(missing, ", "))
    print("preview kind:", tostring(CFG.espPreviewKind),
        "| target sim:", tostring(CFG.espPreviewTarget))
    print("══════════════════════════════════════")
end

featSec:label({ name = "── BEST ESP · PLAYERS + NPCS ──" })
addButton(featSec, "Apply Best ESP", function() SA.ApplyBestEsp() end)
addButton(featSec, "Print ESP Features", function() SA.EspFeatureDiag() end)

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
