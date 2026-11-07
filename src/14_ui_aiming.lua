-- ==================================================================
-- Hanami / 14_ui_aiming.lua — Shaman UI setup + Aiming tab
-- Loaded in order by loader.lua. Parts are joined into ONE chunk
-- before running, so every `local` is shared just like the original.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- UI (Shaman Library)
-- ────────────────────────────────────────────────────────────────────

local Library = loadstring(game:HttpGet(
    'https://raw.githubusercontent.com/Rain-Design/Libraries/main/Shaman/Library.lua'))()
local Window  = Library:Window({ Text = "@abusegpt" })

local AimTab    = Window:Tab({ Text = "Aiming" })
local EspTab    = Window:Tab({ Text = "ESP" })
local GunTab    = Window:Tab({ Text = "Gun Mods" })
local VisualTab = Window:Tab({ Text = "Visual" })
local MiscTab   = Window:Tab({ Text = "Misc" })

-- ── AIMING : Silent Aim ──
local MasterSec = AimTab:Section({ Text = "Silent Aim" })
local masterToggle = MasterSec:Toggle({
    Text = "Enabled", Default = CFG.masterEnabled,
    Callback = function(v) CFG.masterEnabled = v end,
})
MasterSec:Keybind({
    Default = Enum.KeyCode.RightShift, Text = "Toggle Key",
    Callback = function()
        CFG.masterEnabled = not CFG.masterEnabled
        masterToggle:Set(CFG.masterEnabled)
    end,
})
MasterSec:RadioButton({
    Text = "Preset", Options = { "Legit", "Blatant" },
    Callback = function(mode)
        if mode == "Legit" then
            CFG.hitChance = 60; CFG.gunCooldown = 0.1; CFG.prediction = true
        elseif mode == "Blatant" then
            CFG.hitChance = 100; CFG.gunCooldown = 0; CFG.prediction = true
        end
    end,
})

-- ── AIMING : Gun ──
local GunSec = AimTab:Section({ Text = "Gun" })
GunSec:Toggle({ Text = "Gun Silent Aim", Default = CFG.gunEnabled,
    Callback = function(v) CFG.gunEnabled = v end })
GunSec:Toggle({ Text = "Only While Firing", Default = CFG.gunShotOnly,
    Callback = function(v) CFG.gunShotOnly = v end })
GunSec:Toggle({ Text = "Prediction", Default = CFG.prediction,
    Callback = function(v) CFG.prediction = v end })
GunSec:Toggle({ Text = "Wall Check", Default = CFG.wallCheck,
    Callback = function(v) CFG.wallCheck = v end })
GunSec:Toggle({ Text = "Team Check", Default = CFG.teamCheck,
    Callback = function(v) CFG.teamCheck = v end })
GunSec:Toggle({ Text = "Target NPCs", Default = CFG.targetNpcs,
    Callback = function(v) CFG.targetNpcs = v end })

-- ── AIMING : Target ──
local TargetSec = AimTab:Section({ Text = "Target", Side = "Right" })
TargetSec:Dropdown({
    Text = "Target Bone", List = { "Head", "Hrp" },
    Default = CFG.targetBone, Callback = function(v) CFG.targetBone = v end,
})
TargetSec:Slider({ Text = "Hit Chance (%)",
    Default = CFG.hitChance, Minimum = 0, Maximum = 100,
    Callback = function(v) CFG.hitChance = v end })
TargetSec:Slider({ Text = "Max Distance (studs)",
    Default = CFG.distance, Minimum = 0, Maximum = 500,
    Callback = function(v) CFG.distance = v end })
TargetSec:Slider({ Text = "Cooldown (s)",
    Default = CFG.gunCooldown, Minimum = 0, Maximum = 1,
    Callback = function(v) CFG.gunCooldown = v end })

-- ── AIMING : Wall Penetration ──
local ManipSec = AimTab:Section({ Text = "Wall Penetration", Side = "Right" })
ManipSec:Toggle({ Text = "Enabled (FOV-aware)",
    Default = CFG.manipulation, Callback = function(v) CFG.manipulation = v end })
ManipSec:Slider({ Text = "Range (studs)",
    Default = CFG.manipDist, Minimum = 5, Maximum = 100,
    Callback = function(v) CFG.manipDist = v end })
ManipSec:Slider({ Text = "Max Peek Offset",
    Default = CFG.manipPeek, Minimum = 0, Maximum = 8,
    Callback = function(v) CFG.manipPeek = v end })
ManipSec:Slider({ Text = "Max CanQuery Parts",
    Default = CFG.manipMaxParts, Minimum = 0, Maximum = 8,
    Callback = function(v) CFG.manipMaxParts = v end })
ManipSec:Slider({ Text = "Ray Budget / Frame",
    Default = CFG.manipBudget, Minimum = 8, Maximum = 128,
    Callback = function(v) CFG.manipBudget = v end })
ManipSec:Slider({ Text = "Cache Hysteresis (frames)",
    Default = CFG.manipHysteresis, Minimum = 0, Maximum = 12,
    Callback = function(v) CFG.manipHysteresis = v end })
ManipSec:Slider({ Text = "Max Peek Delta",
    Default = CFG.manipMaxPeekDelta, Minimum = 2, Maximum = 12,
    Callback = function(v) CFG.manipMaxPeekDelta = v end })

