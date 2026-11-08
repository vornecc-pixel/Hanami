-- ==================================================================
-- Hanami / 10_fov_circle.lua — FOV circle + the shared reference point
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- FOV CIRCLE — why it never showed up
--
--  1. `ensureFov()` demanded that ALL of Filled / Thickness / NumSides /
--     Visible be writable. One unsupported property (NumSides on many
--     executors) made it return nil FOREVER -> no circle, no retry.
--  2. Every frame all property writes were inside ONE pcall. If any one
--     failed, `c.Visible = true` (the LAST write) was never reached, and
--     the object was immediately removed -> invisible, recreated forever.
--  3. `SA.NewDraw` only probed "Line", never "Circle", and could never
--     downgrade after a runtime property failure.
--  4. `showFov` defaulted to false in older builds and `_G.__saCFG`
--     persists, so the new `true` default never applied (see the one-time
--     migration in 01_config.lua).
--  5. The circle used its own mouse lookup while aim/snapline/arrows each
--     used `GetMouseLocation()` directly. Now all of them use
--     SA.AimPoint() + SA.FovRadius() (02_shared.lua) — the FOV circle IS
--     the reference point.
--
-- Fixes: tolerant per-property writes, Visible always written last, a
-- runtime downgrade to the ScreenGui backend, a lazy retry until a GUI
-- parent is available, and SA.FovState() for diagnostics.
-- ────────────────────────────────────────────────────────────────────

local fovCircle   = nil
local fovBackend  = "none"
local fovFailures = 0
local lastForced  = nil
local fovNeedRebuild = false

-- Write one property at a time. A single unsupported property must never
-- stop the other writes (especially `Visible`).
local function fovSet(d, prop, value)
    if not d then return false end
    local ok = pcall(function() d[prop] = value end)
    if not ok then
        fovFailures = fovFailures + 1
        fovNeedRebuild = true
        if SA.InvalidateDrawKind then SA.InvalidateDrawKind("Circle") end
    end
    return ok
end

local function ensureFov()
    -- a no-op proxy means no ScreenGui parent existed yet; keep retrying.
    -- The read is pcall-guarded because some native Drawing objects throw
    -- on unknown properties.
    if fovCircle then
        local noop = false
        pcall(function() noop = (fovCircle.Backend == "none") end)
        if noop then
            pcall(function() if fovCircle.Remove then fovCircle:Remove() end end)
            fovCircle = nil
            fovBackend = "none"
        end
    end
    if fovCircle then return fovCircle end
    local ok, c = pcall(function() return SA.NewDraw("Circle") end)
    if not (ok and c) then return nil end
    -- None of these is fatal. Even if NumSides / Filled are unsupported the
    -- object can still be shown (the GUI backend supports all of them).
    fovSet(c, "Filled", false)
    fovSet(c, "Thickness", 1)
    fovSet(c, "NumSides", 64)
    fovSet(c, "Visible", false)
    pcall(function() if c.Backend == "ScreenGui" then fovBackend = "ScreenGui" end end)
    if fovBackend == "none" then
        local okB, b = pcall(function() return SA.DrawBackend() end)
        fovBackend = (okB and b) or "unknown"
    end
    fovCircle = c
    return c
end

ensureFov()

function SA.FovState()
    local c = fovCircle
    local centre = SA.AimPoint()
    local vis = "unknown"
    if c then pcall(function() vis = tostring(c.Visible) end) end
    return {
        enabled      = CFG.showFov == true,
        exists       = c ~= nil,
        backend      = fovBackend,
        centre       = centre,
        centreMode   = CFG.fovCenterMode,
        radius       = SA.FovRadius(),
        visible      = vis,
        transparency = CFG.fovTransparency,
        thickness    = CFG.fovThickness,
        filled       = CFG.fovFilled,
        failures     = fovFailures,
        diag         = SA.DrawDiag and SA.DrawDiag() or "n/a",
    }
end

bindRender(function()
    -- Switching the drawing backend at runtime must recreate the circle,
    -- otherwise the old object (native or GUI) would stay on screen.
    if lastForced ~= CFG.forceGuiDrawing then
        lastForced = CFG.forceGuiDrawing
        if fovCircle then
            pcall(function() if fovCircle.Remove then fovCircle:Remove() end end)
        end
        fovCircle = nil
        fovBackend = "none"
    end

    if not (CFG.showFov and SA.FovRadius() > 0) then
        if fovCircle then fovSet(fovCircle, "Visible", false) end
        return
    end

    local c = ensureFov()
    if not c then return end   -- no GUI parent yet; retried next frame

    -- Each write is independent, so an executor missing `Filled` or
    -- `NumSides` still gets a visible circle.
    fovSet(c, "Radius",       SA.FovRadius())
    fovSet(c, "Position",     SA.AimPoint())
    fovSet(c, "Filled",       CFG.fovFilled)
    fovSet(c, "Thickness",    math.max(CFG.fovThickness or 1, 1))
    fovSet(c, "Transparency", math.clamp((CFG.fovTransparency or 50) / 100, 0, 0.95))
    fovSet(c, "Color",        (CFG.manipulation and ESP_COLORS.fovManip or ESP_COLORS.fov)
                              or Color3.fromRGB(255, 50, 50))

    -- ALWAYS last and ALWAYS attempted: this is the write that matters.
    local shown = fovSet(c, "Visible", true)
    if (not shown) or fovNeedRebuild then
        -- a native object just proved it cannot be written to. Drop it and
        -- rebuild next frame on the ScreenGui backend.
        pcall(function() if c.Remove then c:Remove() end end)
        fovCircle = nil
        fovBackend = "none"
        fovNeedRebuild = false
    end
end)
