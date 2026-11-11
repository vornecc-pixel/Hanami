-- ==================================================================
-- Hanami / 23_ui_gunmods.lua — V16.46-style Gun Mods tab controls,
-- Bow Mods and Live Gun Tuning. Inspections, live-controller scanner,
-- observation and reports are embedded, automatic and silent.
-- ==================================================================

-- ── V16.46 GUN MODS ───────────────────────────────────────────────
local gmCol1 = GunTab:column()
local gmSec = gmCol1:section({ name = "Gun Mods (V16.46-style)" })
local gmToggle = SA.GunBindToggle(gmSec, "Enable Gun Mods", "gmEnabled",
    "Master switch: named local fields, visual probes and reversible holds")
SA.FeatureKeybind(gmToggle, "Enable Gun Mods", "hn_bind_gmEnabled",
    Enum.KeyCode.G, "gmEnabled")
SA.GunBindToggle(gmSec, "No Spread", "gunNoSpread",
    "Named spread fields only; shot/hit direction remains UNVERIFIED")
SA.GunBindToggle(gmSec, "Observe Visible Shot Effects", "gunShotProbe",
    "Visual tracer A/B observer; no hit verification")
-- No inspection toggle and no reports column: the four legacy CFG keys
-- stay as hidden always-ON flags for saved-profile / config coverage.
-- Every scan, observation and combined report runs inside the gun module.
local autoInspectKeys = {
    "gunInspectDefs", "gunInspectScripts",
    "gunInspectGunControl", "gunInspectLiveGun",
}
for _, key in ipairs(autoInspectKeys) do
    local flag = "hn_" .. key
    CFG[key] = true
    library.flags[flag] = true
    library.config_flags[flag] = function()
        CFG[key] = true
        library.flags[flag] = true
    end
    library.visible_flags[flag] = nil
end
gmSec:label({ name = "Inspections + live scanner run automatically" })

local gmCol2 = GunTab:column()
local gmSec2 = gmCol2:section({ name = "Controller Field Holds" })
SA.GunBindToggle(gmSec2, "No Recoil (sway + camera test)", "gunNoRecoil",
    "Named recoil fields plus optional camera-pitch correction")
SA.GunBindToggle(gmSec2, "Enable Camera Kick Correction", "gunCameraKickFilter",
    "Experimental; may restrict manual upward aim")
SA.GunBindToggle(gmSec2, "Increase Fire Rate (local test)", "gunFireRate",
    "Server may cap firing cadence")
SA.GunBindSlider(gmSec2, "Fire Rate Multiplier", "gunFireRateMultiplier",
    1, 3, 0.25, "x")
SA.GunBindToggle(gmSec2, "Infinite Ammo (local test)", "gunInfiniteAmmo",
    "Named live counters only; mag capacity ignored")
SA.GunBindToggle(gmSec2, "Shoot + ADS While Sprint/Jump", "gunMoveShoot",
    "Explicit local permission fields; controller/server may gate")

-- ── BOW MODS (ONLY instant charge + no cooldown) ────────────────────
local bowCol = GunTab:column()
local bowSec = bowCol:section({ name = "Bow Mods (GC Scan)" })
bowSec:label({ name = "Bows are NOT aimed — silent aim is guns only" })
local bowToggle = bindToggle(bowSec, "Enable Bow Mods", "bowModsEnabled",
    "Master switch. Needs getgc + setreadonly; turn this ON before the two mods below")
SA.FeatureKeybind(bowToggle, "Enable Bow Mods", "hn_bind_bowModsEnabled",
    Enum.KeyCode.B, "bowModsEnabled")
bindToggle(bowSec, "Instant Charge (max draw)", "bowInstantCharge",
    "Forces drawStart back 10 s so every shot counts as fully charged")
bindToggle(bowSec, "No Shot Cooldown", "bowNoCooldown",
    "Zeros SHOT_GAP / REDRAW_GAP / MIN_DRAW and keeps lastShot cleared")
addButton(bowSec, "Restore Bow Timings", function()
    SA.BowModsRestore()
end)

-- ── BETTER : live gun tuning ────────────────────────────────────────
local tuneCol = GunTab:column()
local tuneSec = tuneCol:section({ name = "Live Gun Tuning / Overrides" })
tuneSec:textbox({
    name = "Per-Gun Overrides", flag = "hn_gunOverrideString",
    default = CFG.gunOverrideString or "",
    placeholder = "assault_rifle.speed=1400;lr_sniper.gravity=20",
    callback = function(text)
        CFG.gunOverrideString = tostring(text or "")
        SA.ApplyGunOverrides(CFG.gunOverrideString)
    end,
})
tuneSec:label({ name = "Format: gun_id.field=value; separated by ;" })
tuneSec:label({ name = "Fields: speed, gravity, life, range, mag, spread …" })
addButton(tuneSec, "Apply Overrides Now", function()
    SA.ApplyGunOverrides(CFG.gunOverrideString or "")
end)
addButton(tuneSec, "Sync Gun Defs + Diff", function()
    SA.SyncGunDefs()
end)
addButton(tuneSec, "Toggle Manip", function()
    setFlag("manipulation", not CFG.manipulation)
end)
