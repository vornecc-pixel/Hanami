-- ==================================================================
-- Hanami / 26_banner.lua — Startup banner + return CFG
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- BANNER
-- ────────────────────────────────────────────────────────────────────

task.wait(0.3)
print("══════════════════════════════════════════════")
print("@abusegpt — Silent Aim + Wall Pen + ESP + Crates + Gun Mods")
print(string.format("  snap @ %d | restore @ %d", snapPrio, restorePrio))
print("  binds :", snapName, "/", restoreName)
local saInfo = SA.SilentAimState()
print(string.format("  aim   : v7.7 camera snap | tap fix A %s (%d conns) | fix B %d tools | GUNS ONLY",
    saInfo.reorder and "ON" or "OFF", saInfo.reorderedConnections,
    saInfo.hookedTools))
local bowInfo = SA.BowModsState()
print(string.format("  bowmod: %s | instant charge %s | no cooldown %s | u10=%d u14=%d",
    CFG.bowModsEnabled and "on" or "off",
    CFG.bowInstantCharge and "on" or "off",
    CFG.bowNoCooldown and "on" or "off",
    bowInfo.configTables, bowInfo.liveStates))
print("  manip : classic sliders — 8 peek dirs, 0-300 studs, base peek 4-6")
print("  esp   : Tahoma text — weapon below box, VIS/WALL + state at corner")
print("  fx    : tracer + arrows PLAYERS ONLY | feature keys P/N/G/B/M")
print("  hud   : nearest player (metres + gun) while menu hidden")
print("  keys  : menu RightShift | aim Insert | right-click a bind = None")
print("  aim   :", CFG.masterEnabled and "on" or "off")
print("  manip :", CFG.manipulation and "on" or "off")
print("  esp   :", CFG.espEnabled and "on" or "off")
print("  npcesp:", CFG.npcEspEnabled and "on" or "off")
print("  crates:", CFG.crateEnabled and "on" or "off")
print("  gunmod:", CFG.gmEnabled and "on" or "off")
print("  snapln:", CFG.snapLineEnabled and "on" or "off")
print("  pred  :", CFG.prediction and "ballistic" or "off")
local equippedGun = SA.GetEquippedGun()
print(string.format("  gun   : %s | %s | %.0f studs/s | mag %d | spread %.2f/%.2f",
    equippedGun.id, tostring(equippedGun.ammo), equippedGun.speed,
    equippedGun.mag or 0, equippedGun.spread or 0, equippedGun.adsSpread or 0))
local attInfo = SA.AttachmentState()
print(string.format("  att   : %d detected [%s] | speed x%.3f | +%.0f ms aim | %s",
    attInfo.count, table.concat(attInfo.ids, ","), attInfo.speedMult,
    attInfo.aimMs, attInfo.auto and "auto tune ON" or "auto tune OFF"))
print("  npcaim:", CFG.targetNpcs and "on" or "off")
print("  npcs  :", #SA.GetNpcs())
print("  crates:", #SA.GetCrates(), "(live registry)")
print("  espfx :", CFG.espPerElementColors and "per-element" or "visibility colours")
print("  colors:", "ESP -> Colours tab (every element)")
print("  ui    : Atlanta")
print("  prevw :", CFG.espPreview and "on" or "off", "| floating ESP Preview panel")
print("  menu  : RightShift (default) | aim: Insert")
print("══════════════════════════════════════════════")

return CFG
