-- ==================================================================
-- Hanami / 24_ui_visual.lua — Visual tab (FOV, snapline, debug)
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
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
addButton(dbgSec, "Print Silent Aim (v7.7)", function()
    local s = SA.SilentAimState()
    local prio = Enum.RenderPriority.Camera.Value
    print(string.format("[sa] snap @ %d | restore @ %d (Camera @ %d)",
        s.snapPriority, s.restorePriority, prio))
    print("[sa] binds:", s.snapBind, "/", s.restoreBind, "| lock:", s.lock)
    print("[sa] fix A reorder:", s.reorder, "| conns:", s.reorderedConnections,
        "| reason:", s.reorderReason)
    print("[sa] fix B hooked tools:", s.hookedTools,
        "| bow remote:", s.bowRemoteHooked, "| bow drawing:", s.bowDrawing)
    print(string.format("[sa] tap window: %.2fs | bow hold: %d | snapped: %s",
        s.tapWindow, s.bowHold, tostring(s.snapped)))
end)
addButton(dbgSec, "Retry Tap / Bow Hooks", function()
    SA.InstallTapReorder()
    SA.InstallBowHook()
    local s = SA.SilentAimState()
    print("[sa] fix A:", s.reorderReason, "| fix B tools:", s.hookedTools)
    print("[sa] bow remote: hook runs in the background; check console")
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
addButton(dbgSec, "Print Manip State (v4)", function()
    local m = SA.ManipState()
    print(string.format("[manip] frame=%d rays left=%d/%d disabled=%d cached=%d dirs=%d",
        m.frame, m.remaining, m.budget, m.disabled, m.cached, m.directions))
    print(string.format("[manip] base=%s adaptive=%.1f hardCap=%s peekOrigin=%s",
        tostring(CFG.manipPeek), m.adaptivePeek or 0, tostring(m.adaptiveCap),
        tostring(m.peek or "none")))
end)
addButton(dbgSec, "Print Current Target", function()
    local t = SA.Target
    if not t.model then print("[sa] target: none in FOV"); return end
    print(string.format("[sa] target: %s | %s | age %.2fs | last shot: %s",
        t.model.Name, t.visible and "VISIBLE" or "BLOCKED",
        tick() - (t.t or 0), t.lastShot and t.lastShot.Name or "never"))
end)
