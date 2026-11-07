-- ==================================================================
-- Hanami / 24_ui_visual.lua — Visual tab (FOV, snapline, debug)
-- Loaded in order by loader.lua. Parts are joined into ONE chunk
-- before running, so every `local` is shared just like the original.
-- ==================================================================

-- ── VISUAL : FOV + Snapline ─────────────────────────────────────────
local fovCol = VisualTab:column()
local fovSec = fovCol:section({ name = "FOV Circle / Snapline" })

bindToggle(fovSec, "Show FOV Circle", "showFov",
    "The circle IS the aim reference point: silent aim, snapline, tracers and arrows all use the same centre + radius")
bindToggle(fovSec, "Filled", "fovFilled")
bindDropdown(fovSec, "FOV Centre", "fovCenterMode", { "Mouse", "Screen Center" })
fovSec:label({ name = "Centre = crosshair / screen centre; invalid mouse -> centre" })
bindToggle(fovSec, "Force ScreenGui Drawing", "forceGuiDrawing",
    "ON (default) = reliable Roblox GUI frames. Turn OFF only if you want to try the executor's native Drawing API")
fovSec:label({ name = "FOV / snapline / lead colours: ESP -> Colours -> Global" })
-- CFG.fov -> SA.FovRadius(): ONE radius for the circle, aim cone, tracers and arrows
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
    print("[sa]", SA.DrawDiag())
end)
addButton(dbgSec, "Print FOV State", function()
    local s = SA.FovState()
    print("[fov] enabled:", s.enabled, "| exists:", s.exists, "| visible:", s.visible)
    print(string.format("[fov] centre: %.0f,%.0f (%s) | radius: %.0f | filled: %s | transparency: %s | thickness: %s",
        s.centre.X, s.centre.Y, tostring(s.centreMode), s.radius,
        tostring(s.filled), tostring(s.transparency), tostring(s.thickness)))
    print("[fov] backend:", s.backend, "| write failures:", s.failures)
    print("[fov]", s.diag)
    print("[fov] fix: toggle 'Show FOV Circle', set Centre = Screen Center, keep 'Force ScreenGui Drawing' ON")
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
