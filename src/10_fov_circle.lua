-- ==================================================================
-- Hanami / 10_fov_circle.lua — FOV circle drawing + shared FOV centre
-- Loaded in order by loader.lua. Parts are joined into ONE chunk
-- before running, so every `local` is shared just like the original.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- FOV CIRCLE — fixes:
--  * used `Drawing.new` directly; on executors without a complete
--    Drawing API the pcall failed silently -> "FOV won't show up".
--    Now uses SA.NewDraw (native or ScreenGui fallback).
--  * gated on CFG.masterEnabled, so turning aim off hid the circle.
--  * fovTransparency was inverted: 0 % produced Transparency = 1, i.e. a
--    completely invisible circle. The slider now means what it says.
--  * no recreation if the draw object was invalidated by the executor.
-- ────────────────────────────────────────────────────────────────────

-- ESP_COLORS.fov lives in 01_config.lua; ESP -> Colours -> Global owns its picker.
function SA.FovCenter()
    local ok, p = pcall(function() return UserInputService:GetMouseLocation() end)
    if ok and p then return p end
    local vp = ws.CurrentCamera and ws.CurrentCamera.ViewportSize
    return vp and Vector2.new(vp.X / 2, vp.Y / 2) or Vector2.new(0, 0)
end

local fovCircle = nil

local function ensureFov()
    if fovCircle then return fovCircle end
    local ok, c = pcall(function() return SA.NewDraw("Circle") end)
    if not (ok and c) then return nil end
    local ok2 = pcall(function()
        c.Filled = false
        c.Thickness = 1
        c.NumSides = 64
        c.Visible = false
    end)
    if not ok2 then
        pcall(function() if c.Remove then c:Remove() end end)
        return nil
    end
    fovCircle = c
    return c
end

ensureFov()

bindRender(function()
    if CFG.showFov and CFG.fov > 0 then
        local c = ensureFov()
        if not c then return end
        local ok = pcall(function()
            c.Radius       = CFG.fov
            c.Position     = SA.FovCenter()
            c.Filled       = CFG.fovFilled
            c.Thickness    = math.max(CFG.fovThickness or 1, 1)
            c.Transparency = math.clamp((CFG.fovTransparency or 50) / 100, 0, 0.95)
            c.Color        = CFG.manipulation and ESP_COLORS.fovManip or ESP_COLORS.fov
            c.Visible      = true
        end)
        if not ok then   -- executor invalidated the object -> recreate next frame
            pcall(function() if c.Remove then c:Remove() end end)
            fovCircle = nil
        end
    elseif fovCircle then
        pcall(function() fovCircle.Visible = false end)
    end
end)
