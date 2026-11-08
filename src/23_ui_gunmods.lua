-- ==================================================================
-- Hanami / 23_ui_gunmods.lua — Gun Mods tab controls
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================

-- ── GUN MODS ───────────────────────────────────────────────────────
local gmCol1 = GunTab:column()
local gmSec = gmCol1:section({ name = "Gun Mods (GC Scan)" })

bindToggle(gmSec, "Enable Gun Mods", "gmEnabled", "Needs getgc + setreadonly")
bindToggle(gmSec, "Instant Equip", "gmInstantEquip")
bindToggle(gmSec, "Instant ADS", "gmInstantAds")
bindToggle(gmSec, "No Spread", "gmNoSpread")

local gmCol2 = GunTab:column()
local gmSec2 = gmCol2:section({ name = "State Overrides" })

bindToggle(gmSec2, "Force Auto", "gmForceAuto")
bindToggle(gmSec2, "No Recoil", "gmNoRecoil")
bindToggle(gmSec2, "No Sway", "gmNoSway")
bindToggle(gmSec2, "No Kick", "gmNoKick")

-- ── BOW MODS (ONLY instant charge + no cooldown) ────────────────────
-- Bows are excluded from silent aim / manipulation; these two toggles
-- only change the bow's own charge / cooldown timing.
local bowCol = GunTab:column()
local bowSec = bowCol:section({ name = "Bow Mods (GC Scan)" })
bowSec:label({ name = "Bows are NOT aimed — silent aim is guns only" })
bindToggle(bowSec, "Enable Bow Mods", "bowModsEnabled",
    "Master switch. Needs getgc + setreadonly; turn this ON before the two mods below")
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
