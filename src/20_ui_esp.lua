-- ==================================================================
-- Hanami / 20_ui_esp.lua — ESP tab (players, NPCs, loot crates)
-- Loaded in order by loader.lua. Parts are joined into ONE chunk
-- before running, so every `local` is shared just like the original.
-- ==================================================================

-- ── ESP : Player / NPC (tabbed column) ──────────────────────────────
local espCol = EspTab:column()
local playerSec, npcSec = espCol:multi_section({ names = { "Player ESP", "NPC ESP" } })

local espEnabledToggle = playerSec:toggle({
    name = "Enabled", flag = "hn_espEnabled",
    enabled = CFG.espEnabled, default = CFG.espEnabled,
    callback = function(v)
        if v then enableESP() else disableESP() end
    end,
})
espEnabledToggle:colorpicker({
    name = "Flat Color", flag = "hn_esp_color", color = espColor,
    callback = function(c) espColor = c end,
})
library.config_flags["hn_espEnabled"] = function(v) setToggle(espEnabledToggle, v) end

bindToggle(playerSec, "Visibility Check (red/green)", "espVisibleCheck",
    "GREEN = clear line of sight, RED = behind a wall (cached camera raycast)")
    :colorpicker({
        name = "Visible", flag = "hn_esp_vis_color", color = espColorVisible,
        callback = function(c) espColorVisible = c end,
    })
bindToggle(playerSec, "Show Names", "espShowName")
    :colorpicker({
        name = "Hidden", flag = "hn_esp_hidden_color", color = espColorHidden,
        callback = function(c) espColorHidden = c end,
    })
bindToggle(playerSec, "Show Weapon (scanner)", "espShowTool",
    "Reads equipped Tool / ItemId / Weapon attributes")
bindToggle(playerSec, "Show State (scanner)", "espShowState",
    "Reads Knocked / Downed / Dead / State attributes, else HumanoidStateType")
bindToggle(playerSec, "Show Distance", "espShowDist")
bindToggle(playerSec, "Show Health Bar", "espShowHealth")
bindSlider(playerSec, "Max Distance (studs)", "espMaxDist", 200, 5000, 10, "")
addButton(playerSec, "Scan Players", function() SA.PrintScan("PLAYER") end)

-- ── ESP : NPCs (Guard / Scavenger / Soldier) ────────────────────────
local npcEspEnabledToggle = npcSec:toggle({
    name = "Enabled", flag = "hn_npcEspEnabled",
    enabled = CFG.npcEspEnabled, default = CFG.npcEspEnabled,
    callback = function(v)
        if v then enableNpcESP() else disableNpcESP() end
    end,
})
library.config_flags["hn_npcEspEnabled"] = function(v) setToggle(npcEspEnabledToggle, v) end

bindToggle(npcSec, "Visibility Check (red/green)", "npcVisibleCheck")
    :colorpicker({
        name = "Visible", flag = "hn_npc_vis_color", color = npcColorVisible,
        callback = function(c) npcColorVisible = c end,
    })
bindToggle(npcSec, "Show Names", "npcShowName")
    :colorpicker({
        name = "Hidden", flag = "hn_npc_hidden_color", color = npcColorHidden,
        callback = function(c) npcColorHidden = c end,
    })
bindToggle(npcSec, "Show Weapon (scanner)", "npcShowTool")
bindToggle(npcSec, "Show State (scanner)", "npcShowState")
bindToggle(npcSec, "Show Distance", "npcShowDist")
bindToggle(npcSec, "Show Health Bar", "npcShowHealth")
bindSlider(npcSec, "Max Distance (studs)", "npcMaxDist", 200, 5000, 10, "")
npcSec:label({ name = "Detects: Guard / Scavenger / Soldier" })
addButton(npcSec, "Rescan NPCs", function()
    local snap = {}
    for m in pairs(npcObjects) do table.insert(snap, m) end
    for _, m in ipairs(snap) do clearNpc(m) end
    if CFG.npcEspEnabled then
        for _, m in ipairs(SA.RefreshNpcs()) do buildNpc(m) end
    else
        SA.RefreshNpcs()
    end
end)
addButton(npcSec, "Scan NPCs", function() SA.PrintScan("NPC") end)

-- ── ESP : Loot Crates ───────────────────────────────────────────────
local crateCol = EspTab:column()
local crateSec = crateCol:section({ name = "Loot Crate ESP" })

local crateEnabledToggle = crateSec:toggle({
    name = "Enabled", flag = "hn_crateEnabled",
    enabled = CFG.crateEnabled, default = CFG.crateEnabled,
    callback = function(v)
        if v then enableCrateESP() else disableCrateESP() end
    end,
})
crateEnabledToggle:colorpicker({
    name = "Opened Color", flag = "hn_crate_open_color", color = crateColorOpened,
    callback = function(c) crateColorOpened = c end,
})
library.config_flags["hn_crateEnabled"] = function(v) setToggle(crateEnabledToggle, v) end

bindToggle(crateSec, "Show Military Crates", "crateShowMilitary")
    :colorpicker({
        name = "Military Color", flag = "hn_crate_mil_color", color = crateColorMilitary,
        callback = function(c) crateColorMilitary = c end,
    })
bindToggle(crateSec, "Show Elite Crates", "crateShowElite")
    :colorpicker({
        name = "Elite Color", flag = "hn_crate_elite_color", color = crateColorElite,
        callback = function(c) crateColorElite = c end,
    })
bindToggle(crateSec, "Show Opened Crates", "crateShowOpened")
bindSlider(crateSec, "Crate Max Distance", "crateMaxDist", 200, 5000, 10, "")

addButton(crateSec, "Rescan Crates", function()
    local snap = {}
    for m in pairs(crateObjects) do table.insert(snap, m) end
    for _, m in ipairs(snap) do clearCrate(m) end
    if CFG.crateEnabled then
        for _, d in ipairs(Workspace:GetDescendants()) do
            if CRATE_NAMES[d.Name] then buildCrate(d) end
        end
    end
end)
