-- ==================================================================
-- Hanami / 15_ui_esp.lua — ESP tab (players + loot crates)
-- Loaded in order by loader.lua. Parts are joined into ONE chunk
-- before running, so every `local` is shared just like the original.
-- ==================================================================

-- ── ESP : Player ───────────────────────────────────────────────────
local espCol = EspTab:column()
local playerSec = espCol:section({ name = "Player ESP" })

local espEnabledToggle = playerSec:toggle({
    name = "Enabled", flag = "hn_espEnabled",
    enabled = CFG.espEnabled, default = CFG.espEnabled,
    callback = function(v)
        if v then enableESP() else disableESP() end
    end,
})
-- colourpickers write the shared locals used by the ESP drawing code
espEnabledToggle:colorpicker({
    name = "Player Color", flag = "hn_esp_color", color = espColor,
    callback = function(c) espColor = c end,
})
library.config_flags["hn_espEnabled"] = function(v) setToggle(espEnabledToggle, v) end

bindToggle(playerSec, "Show Names", "espShowName")
bindToggle(playerSec, "Show Distance", "espShowDist")
bindToggle(playerSec, "Show Health Bar", "espShowHealth")
bindSlider(playerSec, "Max Distance (studs)", "espMaxDist", 200, 5000, 10, "")

-- ── ESP : Loot Crates ──────────────────────────────────────────────
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
