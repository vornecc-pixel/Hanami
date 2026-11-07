-- ==================================================================
-- Hanami / 19_banner.lua — Startup banner + return CFG
-- Loaded in order by loader.lua. Parts are joined into ONE chunk
-- before running, so every `local` is shared just like the original.
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
print("  crates:", CFG.crateEnabled and "on" or "off")
print("  gunmod:", CFG.gmEnabled and "on" or "off")
print("  toggle: RightShift")
print("══════════════════════════════════════════════")

return CFG
