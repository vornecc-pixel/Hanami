-- ==================================================================
-- Hanami / 18_ui_misc.lua — Misc tab + quick actions
-- Loaded in order by loader.lua. Parts are joined into ONE chunk
-- before running, so every `local` is shared just like the original.
-- ==================================================================

-- ── MISC ──
local InfoSec = MiscTab:Section({ Text = "Info" })
InfoSec:Label({ Text = "@abusegpt — full suite",
    Color = Color3.fromRGB(217, 97, 99),
    Tooltip = "Silent Aim + Wall Pen + ESP + Crates + Gun Mods" })
InfoSec:Label({ Text = "Toggle key: RightShift (silent aim)" })
InfoSec:Label({ Text = "Gun Mods: GC scan (getgc + rawset)" })

local ActSec = MiscTab:Section({ Text = "Quick Actions", Side = "Right" })
ActSec:Toggle({ Text = "Hit Sound", Default = CFG.hitSoundEnabled,
    Callback = function(v) CFG.hitSoundEnabled = v end })
ActSec:Button({ Text = "Disable All",
    Callback = function()
        CFG.masterEnabled = false; masterToggle:Set(false)
        CFG.gmEnabled = false; CFG.espEnabled = false; CFG.crateEnabled = false
        disableESP(); disableCrateESP()
    end })
ActSec:Button({ Text = "Apply Blatant",
    Callback = function()
        CFG.masterEnabled = true; masterToggle:Set(true)
        CFG.hitChance = 100; CFG.gunCooldown = 0
    end })
ActSec:Button({ Text = "Toggle Manip",
    Callback = function()
        CFG.manipulation = not CFG.manipulation
        print("[sa] manip:", CFG.manipulation and "on" or "off")
    end })
ActSec:Button({ Text = "Unload Everything",
    Callback = function()
        CFG.masterEnabled = false; CFG.gmEnabled = false
        disableESP(); disableCrateESP()
        if HitLogGui then HitLogGui:Destroy() end
        RunService:UnbindFromRenderStep(snapName)
        RunService:UnbindFromRenderStep(restoreName)
        print("[sa] unloaded")
    end })

AimTab:Select()

