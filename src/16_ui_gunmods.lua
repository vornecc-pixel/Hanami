-- ==================================================================
-- Hanami / 16_ui_gunmods.lua — Gun Mods tab controls
-- Loaded in order by loader.lua. Parts are joined into ONE chunk
-- before running, so every `local` is shared just like the original.
-- ==================================================================

-- ── GUN MODS ──
local GmSec = GunTab:Section({ Text = "Gun Mods (GC Scan)" })
GmSec:Toggle({ Text = "Enable Gun Mods", Default = CFG.gmEnabled,
    Callback = function(v) CFG.gmEnabled = v end })
GmSec:Toggle({ Text = "Instant Equip", Default = CFG.gmInstantEquip,
    Callback = function(v) CFG.gmInstantEquip = v end })
GmSec:Toggle({ Text = "Instant ADS", Default = CFG.gmInstantAds,
    Callback = function(v) CFG.gmInstantAds = v end })
GmSec:Toggle({ Text = "No Spread", Default = CFG.gmNoSpread,
    Callback = function(v) CFG.gmNoSpread = v end })
GmSec:Toggle({ Text = "Force Auto", Default = CFG.gmForceAuto,
    Callback = function(v) CFG.gmForceAuto = v end })
GmSec:Toggle({ Text = "No Recoil", Default = CFG.gmNoRecoil,
    Callback = function(v) CFG.gmNoRecoil = v end })
GmSec:Toggle({ Text = "No Sway", Default = CFG.gmNoSway,
    Callback = function(v) CFG.gmNoSway = v end })
GmSec:Toggle({ Text = "No Kick", Default = CFG.gmNoKick,
    Callback = function(v) CFG.gmNoKick = v end })

