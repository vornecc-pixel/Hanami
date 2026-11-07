-- ==================================================================
-- Hanami / 24_ui_visual.lua — Visual tab (FOV, snapline, debug)
-- Loaded in order by loader.lua. Parts are joined into ONE chunk
-- before running, so every `local` is shared just like the original.
-- ==================================================================

-- ── VISUAL : FOV + Snapline ─────────────────────────────────────────
local fovCol = VisualTab:column()
local fovSec = fovCol:section({ name = "FOV Circle / Snapline" })

bindToggle(fovSec, "Show FOV Circle", "showFov",
    "Works with aim OFF and on executors without a full Drawing API (ScreenGui fallback)")
bindToggle(fovSec, "Filled", "fovFilled")
fovSec:label({ name = "FOV / snapline / lead colours: ESP -> Colours -> Global" })
-- CFG.fov is used by both the target picker and the drawn circle
bindSlider(fovSec, "Aim / Circle Radius (px)", "fov", 30, 500, 1, "px")
bindSlider(fovSec, "Transparency (%)", "fovTransparency", 0, 100, 1, "%")
fovSec:label({ name = "Transparency 0% = solid, 100% = nearly invisible" })
bindSlider(fovSec, "Thickness", "fovThickness", 1, 5, 1, "")

bindToggle(fovSec, "Snapline (aim preview)", "snapLineEnabled",
    "Line from the FOV centre to the exact target silent aim would pick. GREEN = clear, RED = blocked")
bindDropdown(fovSec, "Line Origin", "snapLineOrigin", { "Mouse", "Center", "Bottom" })
bindSlider(fovSec, "Snapline Thickness", "snapLineThickness", 1, 5, 1, "")
bindToggle(fovSec, "Show Lead Marker", "snapShowLead",
    "Ring = the exact point the ballistic solver will aim at (moving targets / bullet drop)")

-- ── VISUAL : Debug ─────────────────────────────────────────────────
local dbgCol = VisualTab:column()
local dbgSec = dbgCol:section({ name = "Debug" })

bindToggle(dbgSec, "Debug Log", "debug")
addButton(dbgSec, "Print Sandwich", function()
    local prio = Enum.RenderPriority.Camera.Value
    print(string.format("[sa] snap @ %d | gun @ %d | restore @ %d",
        prio + 2, prio + 3, prio + 4))
    print(string.format("[sa] actual binds: %s @ %d / %s @ %d",
        snapName, snapPrio, restoreName, restorePrio))
end)
addButton(dbgSec, "Print Draw Backend", function()
    print("[sa] drawing backend:", SA.DrawBackend())
end)
addButton(dbgSec, "Print Gun Spec", function()
    SA.PrintGunSpec()
end)
addButton(dbgSec, "Print Prediction", function()
    local cam = ws.CurrentCamera
    local t = SA.Target
    if not (cam and t.model and t.pos) then
        print("[sa] prediction: no target in FOV"); return
    end
    SA.PrintPrediction(cam.CFrame.Position, t.pos, t.model)
end)
addButton(dbgSec, "Sync Gun Defs (GC)", function()
    local n = SA.SyncGunDefs()
    if n == 0 then print("[sa] no live gun tables found; using static specs") end
end)
addButton(dbgSec, "Print Manip State", function()
    local n = 0; for _ in pairs(saManipCache) do n = n + 1 end
    print(string.format("[manip] frame=%d budget=%d disabled=%d cached=%d",
        saManipFrame, saManipBudget, #saManipDisabled, n))
end)
addButton(dbgSec, "Print Current Target", function()
    local t = SA.Target
    if not t.model then print("[sa] target: none in FOV"); return end
    print(string.format("[sa] target: %s | %s | age %.2fs | last shot: %s",
        t.model.Name, t.visible and "VISIBLE" or "BLOCKED",
        tick() - (t.t or 0), t.lastShot and t.lastShot.Name or "never"))
end)
