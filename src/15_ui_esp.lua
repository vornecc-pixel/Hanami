-- ==================================================================
-- Hanami / 15_ui_esp.lua — ESP tab controls
-- Loaded in order by loader.lua. Parts are joined into ONE chunk
-- before running, so every `local` is shared just like the original.
-- ==================================================================

-- ── ESP : Player ──
local PlayerEspSec = EspTab:Section({ Text = "Player ESP" })
PlayerEspSec:Toggle({ Text = "Enable Player ESP", Default = CFG.espEnabled,
    Callback = function(v) if v then enableESP() else disableESP() end end })
PlayerEspSec:Toggle({ Text = "Show Names", Default = CFG.espShowName,
    Callback = function(v) CFG.espShowName = v end })
PlayerEspSec:Toggle({ Text = "Show Distance", Default = CFG.espShowDist,
    Callback = function(v) CFG.espShowDist = v end })
PlayerEspSec:Toggle({ Text = "Show Health Bar", Default = CFG.espShowHealth,
    Callback = function(v) CFG.espShowHealth = v end })
PlayerEspSec:Slider({ Text = "Max Distance (studs)",
    Default = CFG.espMaxDist, Minimum = 200, Maximum = 5000,
    Callback = function(v) CFG.espMaxDist = v end })

-- ── ESP : Crates ──
local CrateEspSec = EspTab:Section({ Text = "Loot Crate ESP", Side = "Right" })
CrateEspSec:Toggle({ Text = "Enable Crate ESP", Default = CFG.crateEnabled,
    Callback = function(v) if v then enableCrateESP() else disableCrateESP() end end })
CrateEspSec:Toggle({ Text = "Show Military Crates", Default = CFG.crateShowMilitary,
    Callback = function(v) CFG.crateShowMilitary = v end })
CrateEspSec:Toggle({ Text = "Show Elite Crates", Default = CFG.crateShowElite,
    Callback = function(v) CFG.crateShowElite = v end })
CrateEspSec:Toggle({ Text = "Show Opened Crates", Default = CFG.crateShowOpened,
    Callback = function(v) CFG.crateShowOpened = v end })
CrateEspSec:Slider({ Text = "Crate Max Distance",
    Default = CFG.crateMaxDist, Minimum = 200, Maximum = 5000,
    Callback = function(v) CFG.crateMaxDist = v end })
CrateEspSec:Button({ Text = "Rescan Crates",
    Callback = function()
        local snap = {}
        for m in pairs(crateObjects) do table.insert(snap, m) end
        for _, m in ipairs(snap) do clearCrate(m) end
        if CFG.crateEnabled then
            for _, d in ipairs(Workspace:GetDescendants()) do
                if CRATE_NAMES[d.Name] then buildCrate(d) end
            end
        end
    end })

