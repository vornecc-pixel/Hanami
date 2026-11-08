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
print("  aim   :", CFG.masterEnabled and "on" or "off")
print("  manip :", CFG.manipulation and "on" or "off")
print("  esp   :", CFG.espEnabled and "on" or "off")
print("  npcesp:", CFG.npcEspEnabled and "on" or "off")
print("  crates:", CFG.crateEnabled and "on" or "off")
print("  gunmod:", CFG.gmEnabled and "on" or "off")
print("  snapln:", CFG.snapLineEnabled and "on" or "off")
print("  pred  :", CFG.prediction and "ballistic" or "off")
local equippedGun = SA.GetEquippedGun()
print(string.format("  gun   : %s | %s | %.0f studs/s",
    equippedGun.id, tostring(equippedGun.ammo), equippedGun.speed))
print("  npcaim:", CFG.targetNpcs and "on" or "off")
print("  npcs  :", #SA.GetNpcs())
print("  crates:", #SA.GetCrates(), "(live registry)")
print("  espfx :", CFG.espPerElementColors and "per-element" or "visibility colours")
print("  colors:", "ESP -> Colours tab (every element)")
print("  ui    : Atlanta")
print("  toggle: RightShift | menu: Insert")
print("══════════════════════════════════════════════")

return CFG
