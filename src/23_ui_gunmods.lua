-- ==================================================================
-- Hanami / 23_ui_gunmods.lua — Gun Mods tab controls
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================

-- ── GUN MODS ───────────────────────────────────────────────────────
local gmCol1 = GunTab:column()
local gmSec = gmCol1:section({ name = "Gun Mods (GC Scan)" })

local gmToggle = bindToggle(gmSec, "Enable Gun Mods", "gmEnabled", "Needs getgc + setreadonly")
SA.FeatureKeybind(gmToggle, "Enable Gun Mods", "hn_bind_gmEnabled",
    Enum.KeyCode.G, "gmEnabled")
bindToggle(gmSec, "Instant Equip", "gmInstantEquip")
bindToggle(gmSec, "Instant ADS", "gmInstantAds")
bindToggle(gmSec, "No Spread", "gmNoSpread")

local gmCol2 = GunTab:column()
local gmSec2 = gmCol2:section({ name = "State Overrides" })

bindToggle(gmSec2, "Force Auto", "gmForceAuto")
bindToggle(gmSec2, "No Recoil", "gmNoRecoil")
bindToggle(gmSec2, "No Sway", "gmNoSway")
bindToggle(gmSec2, "No Kick", "gmNoKick")

-- ── HIPFIRE NO RECOIL (standalone, reversible) ──────────────────────
-- Full supplied scope: live camera climb / gun kick / spread bloom, plus
-- def spread / bloom / climb / shake / recover constants. There is NO ADS
-- check: it is enforced whenever the toggle is ON.
local hnrSec = gmCol2:section({ name = "Hipfire No Recoil" })
bindToggle(hnrSec, "Enable Hipfire No Recoil", "hipfireNoRecoil",
    "Always ON when enabled (no ADS check): zeroes recoil, kick, bloom and gun-def spread")
hnrSec:label({ name = "Def originals are saved and restored on OFF / unload" })
addButton(hnrSec, "Print Hipfire No Recoil", function()
    SA.PrintHipfireNoRecoil()
end)
addButton(hnrSec, "Rescan Live + Defs", function()
    local live, defs = SA.HipfireNoRecoilScan()
    print("[hipfire] rescan:", live, "live states,", defs, "gun defs")
end)
addButton(hnrSec, "Restore Def Tables", function()
    SA.HipfireNoRecoilRestore()
    print("[hipfire] saved def originals restored")
end)

-- ── BOW MODS (ONLY instant charge + no cooldown) ────────────────────
-- Bows are excluded from silent aim / manipulation; these two toggles
-- only change the bow's own charge / cooldown timing.
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
addButton(bowSec, "Print Bow Mods State", function()
    local b = SA.BowModsState()
    print(string.format("[bow] master=%s instantCharge=%s noCooldown=%s | u10=%d u14=%d patched=%d | getgc=%s setreadonly=%s",
        tostring(b.enabled), tostring(b.instantCharge), tostring(b.noCooldown),
        b.configTables, b.liveStates, b.patched, tostring(b.gc), tostring(b.readonly)))
end)
addButton(bowSec, "Restore Bow Timings", function()
    SA.BowModsRestore()
    print("[bow] original SHOT_GAP / REDRAW_GAP / MIN_DRAW restored")
end)

-- ── BETTER : live gun tuning ────────────────────────────────────────
-- No hit log / damage tracker. Just a new-gun diff against the shipped
-- 20-gun DB and a manual numeric override editor for the ballistics
-- solver. Overrides are re-applied after every GC sync.
local tuneCol = GunTab:column()
local tuneSec = tuneCol:section({ name = "Live Gun Tuning / Overrides" })
bindToggle(tuneSec, "Print New-Gun Diff on Sync", "gunDiffOnScan",
    "After Sync Gun Defs, list guns added by the game and every field that differs from the shipped DB")
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
addButton(tuneSec, "Print Override Help", function() SA.PrintGunOverrides() end)
addButton(tuneSec, "Print Live Gun Diff", function() SA.PrintGunDiff() end)
addButton(tuneSec, "Sync Gun Defs + Diff", function()
    local n = SA.SyncGunDefs()
    print("[gun] synced", n, "live fields")
    SA.PrintGunDiff()
end)
addButton(tuneSec, "Print Full Gun Table", function() SA.PrintGunTable() end)
