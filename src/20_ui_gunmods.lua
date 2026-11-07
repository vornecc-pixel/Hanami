-- ==================================================================
-- Hanami / 20_ui_gunmods.lua — Gun Mods tab controls
-- Loaded in order by loader.lua. Parts are joined into ONE chunk
-- before running, so every `local` is shared just like the original.
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
