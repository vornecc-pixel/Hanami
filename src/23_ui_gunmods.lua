-- ==================================================================
-- Hanami / 23_ui_gunmods.lua — V16.46-style Gun Mods tab controls,
-- Bow Mods, Live Gun Tuning, brightness status and silent report actions.
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
SA.GunBindToggle(gmSec, "Inspect Definitions", "gunInspectDefs",
    "Read-only Fust.Items identity diagnostics")
SA.GunBindToggle(gmSec, "Inspect Scripts", "gunInspectScripts",
    "Read-only visible controller names and classes")
SA.GunBindToggle(gmSec, "Inspect GunControl Exports", "gunInspectGunControl",
    "Opt-in: require may run its own initializer")
SA.GunBindToggle(gmSec, "Inspect Live Gun", "gunInspectLiveGun",
    "One bounded source-attributed controller discovery scan")

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

local gmCol3 = GunTab:column()
local stateSec = gmCol3:section({ name = "Silent State / Reports" })
SA.GunBindLabel("weapon", stateSec:label({ name = "Weapon: loading" }))
SA.GunBindLabel("definitions", stateSec:label({ name = "Definitions: loading" }))
SA.GunBindLabel("gunControl", stateSec:label({ name = "GunControl: loading" }))
SA.GunBindLabel("scripts", stateSec:label({ name = "Script hints: loading" }))
SA.GunBindLabel("live", stateSec:label({ name = "Live controller: loading" }))
SA.GunBindLabel("spread", stateSec:label({ name = "No Spread: OFF" }))
SA.GunBindLabel("recoil", stateSec:label({ name = "No Recoil: OFF" }))
SA.GunBindLabel("rate", stateSec:label({ name = "Fire Rate: OFF" }))
SA.GunBindLabel("ammo", stateSec:label({ name = "Infinite Ammo: OFF" }))
SA.GunBindLabel("movement", stateSec:label({ name = "Move Shoot: OFF" }))
SA.GunBindLabel("camera", stateSec:label({ name = "Camera kick: OFF" }))
SA.GunBindLabel("probe", stateSec:label({ name = "Shot probe: OFF" }))
SA.GunBindLabel("verdict", stateSec:label({ name = "Verdict: unverified" }))
SA.GunBindLabel("display", stateSec:label({ name = "Brightness: OFF" }))
SA.GunBindLabel("observation", stateSec:label({ name = "Observation: no baseline" }))
SA.GunBindLabel("report", stateSec:label({ name = "Report: none" }))

SA.GunBindButton(stateSec, "Refresh Gun Mods Sources", function()
    SA.GunRefresh(true)
end)
SA.GunBindButton(stateSec, "Use Definition Candidate 1", function()
    SA.GunUseDefinitionCandidate(1)
end)
SA.GunBindButton(stateSec, "Clear Manual Definition", function()
    SA.GunClearManualDefinition()
end)
SA.GunBindButton(stateSec, "Capture Gun State Baseline", function()
    SA.GunObservationBaseline()
end)
SA.GunBindButton(stateSec, "Compare Gun State", function()
    SA.GunObservationCompare()
end)
SA.GunBindButton(stateSec, "Reset Shot Comparison", function()
    SA.GunShotProbeReset()
end)
SA.GunBindButton(stateSec, "Restore All Gun Fields", function()
    SA.GunRestore()
end)
SA.GunBindButton(stateSec, "Copy Definition Report", function()
    SA.GunCopyReport("definitions")
end)
SA.GunBindButton(stateSec, "Copy GunControl Report", function()
    SA.GunCopyReport("guncontrol")
end)
SA.GunBindButton(stateSec, "Copy Script Hints", function()
    SA.GunCopyReport("scripts")
end)
SA.GunBindButton(stateSec, "Copy Live Controller Report", function()
    SA.GunCopyReport("live")
end)
SA.GunBindButton(stateSec, "Copy Shot Probe Report", function()
    SA.GunCopyReport("shot")
end)
SA.GunBindButton(stateSec, "Copy All Gun Reports", function()
    SA.GunCopyReport("all")
end)

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
