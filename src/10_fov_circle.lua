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
--     persists, so the new `true` default never applied. `SA.FOV_STARTUP`
--     in 01_config.lua now applies it on a fresh session / migration and
--     ResetToDefaults() keeps the solid, visible circle.
--  5. The circle used its own mouse lookup while aim/snapline/arrows each
--     used `GetMouseLocation()` directly. Now all of them use
--     SA.AimPoint() + SA.FovRadius() (02_shared.lua) — the FOV circle IS
--     the reference point.
--
-- Fixes: tolerant per-property writes, Visible always written last, a
-- runtime downgrade to the ScreenGui backend, a lazy retry until a GUI
-- parent is available, and SA.FovState() for state checks.
-- ────────────────────────────────────────────────────────────────────

local fovCircle   = nil
-- Declared HERE, above SA.FovState(), so the state reader captures the
-- real pool as an upvalue instead of silently reading a nil global.
local fovRing = {}          -- pooled Line draws for segment styles
local fovRingStyle = nil    -- which style / count built the pool
local fovPulse = 0          -- accumulated pulse phase (seconds)
local fovRingLive = 0       -- ring lines visible in the last drawn frame
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
            SA.DrawRemove(fovCircle)
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
    fovSet(c, "Thickness", math.max(CFG.fovThickness or 3, 1))
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
        centreMode   = "Mouse / crosshair reference",
        mode         = SA.FovMode and SA.FovMode() or "Pixels",
        degrees      = SA.FovDegrees and SA.FovDegrees() or nil,
        radius       = SA.FovRadius(),
        style        = CFG.fovStyle or "Circle",
        segments     = CFG.fovSegments,
        ringDraws    = fovRingLive or 0,
        ringAllocated = #fovRing,
        visible      = vis,
        transparency = CFG.fovTransparency,
        thickness    = CFG.fovThickness,
        filled       = CFG.fovFilled,
        failures     = fovFailures,
        diag         = SA.DrawDiag and SA.DrawDiag() or "n/a",
    }
end

function SA.FovDispose()
    if fovCircle then SA.DrawRemove(fovCircle) end
    fovCircle, fovBackend = nil, "none"
    fovNeedRebuild, lastForced = false, nil
    return true
end

-- ────────────────────────────────────────────────────────────────────
-- FOV DRAWING STYLES
--
-- Every style is assembled from primitives an executor can actually
-- provide, so a missing Drawing kind degrades to the next best thing
-- instead of drawing nothing:
--
--   Circle   native SA.NewDraw("Circle") (ScreenGui ring fallback)
--   Segments one Line per arc slice        -> Line only
--   Corners  four 90-degree corner arcs    -> Line only
--   Dots     a dotted ring                 -> Line only
--   Double   two concentric rings          -> Circle + Line
--   Dashes   a dashed ring                 -> Line only
--   Cross    ring + centre crosshair       -> Circle/Line + Line
--   Pulse    ring whose radius breathes    -> Circle/Line
--
-- All of them ride the SAME centre + radius as aim (SA.AimPoint /
-- SA.FovRadius), so a style can never desync from what silent aim uses.
-- The segment rings are pooled: the draw count only changes when the
-- style or the segment count changes, never per frame.
-- ────────────────────────────────────────────────────────────────────

local function fovColor()
    return (CFG.manipulation and ESP_COLORS.fovManip or ESP_COLORS.fov)
        or Color3.fromRGB(255, 50, 50)
end

local function fovAlpha()
    -- 0% transparency = solid. 100% = nearly invisible, never invisible.
    return math.clamp((CFG.fovTransparency or 1) / 100, 0, 0.95)
end

local function fovThick()
    return math.max(tonumber(CFG.fovThickness) or 3, 1)
end

-- Release the pooled ring lines (style change / dispose / toggle OFF).
local function fovClearRing()
    for i = #fovRing, 1, -1 do
        local d = fovRing[i]
        fovRing[i] = nil
        if d then
            pcall(function() if d.Visible ~= false then d.Visible = false end end)
            -- RecycleDraw pools the draw when Performance Mode is ON and
            -- removes it otherwise; either way nothing stays on screen.
            if SA.RecycleDraw then
                pcall(SA.RecycleDraw, d)
            else
                pcall(SA.DrawRemove, d)
            end
        end
    end
    fovRingStyle = nil
end

-- How many Line slots this style needs (and how to lay each one out).
local RING_PIECES = {
    Segments = function(n) return n end,
    Corners  = function() return 4 * 10 end,
    Dots     = function() return 24 end,
    Dashes   = function() return 32 end,
    Double   = function(n) return n end,
}

local function fovRingCount(style, segs)
    local f = RING_PIECES[style]
    return f and f(segs) or 0
end

local function fovEnsureRing(style, count)
    -- floor() so a float CFG value cannot churn the pool key every frame
    local key = style .. ":" .. tostring(math.floor(count + 0.5))
    if fovRingStyle == key then return true end
    fovClearRing()
    fovRingStyle = key
    for i = 1, count do
        local ok, d = pcall(function() return SA.NewDraw("Line") end)
        if not ok or not d then
            fovRingStyle = nil
            return false
        end
        pcall(function() d.Visible = false; d.Thickness = 1 end)
        fovRing[i] = d
    end
    return true
end

-- Write one ring line and count it as used this frame.
local function fovSeg(i, cx, cy, a1, a2, r1, r2, col, alpha, thick, used)
    local d = fovRing[i]
    if not d then return false end
    local c1, s1 = math.cos(a1), math.sin(a1)
    local c2, s2 = math.cos(a2), math.sin(a2)
    -- r2 == r1 for an arc slice; different radii give a radial tick
    -- (Cross / Corner styles use that form).
    local ok = pcall(function()
        d.From = Vector2.new(cx + c1 * r1, cy + s1 * r1)
        d.To   = Vector2.new(cx + c2 * (r2 or r1), cy + s2 * (r2 or r1))
        d.Color = col
        d.Transparency = alpha
        d.Thickness = thick
        d.Visible = true
    end)
    -- Only a write that actually landed counts as drawn, so fovRingLive
    -- reports what is ON SCREEN rather than what was allocated.
    if ok then used[i] = true end
    return ok
end

local function fovHideRingFrom(fromIndex, used)
    local live = 0
    for i = 1, #fovRing do
        local d = fovRing[i]
        if used[i] then
            live = live + 1
        elseif d then
            pcall(function() if d.Visible ~= false then d.Visible = false end end)
        end
    end
    fovRingLive = live
end

-- Draw the ring for `style` around (cx, cy) with radius r.
local function fovDrawRing(style, cx, cy, r, col, alpha, thick, dt)
    if style == "Pulse" then
        fovPulse = fovPulse + (dt or 0.016)
        local phase = (fovPulse * 1.6) % 1
        r = r * (0.94 + 0.06 * math.abs(phase * 2 - 1))
    end
    -- A plain Circle (or Double / Cross / Pulse ring) uses the native
    -- object, which is the smoothest option when it is available.
    if style == "Circle" or style == "Double" or style == "Cross"
        or style == "Pulse" then
        if style == "Circle" or style == "Pulse" then
            -- no ring lines for these styles; clear any pool left over
            -- from a previous style so nothing stale stays on screen.
            if fovRingStyle and #fovRing > 0 then
                for i = 1, #fovRing do
                    local d = fovRing[i]
                    pcall(function() if d and d.Visible ~= false then
                        d.Visible = false
                    end end)
                end
            end
            fovRingLive = 0
        end
        local c = ensureFov()
        if c then
            fovSet(c, "Radius", r)
            fovSet(c, "Position", Vector2.new(cx, cy))
            fovSet(c, "Filled", CFG.fovFilled)
            fovSet(c, "Thickness", thick)
            fovSet(c, "Transparency", alpha)
            fovSet(c, "Color", col)
            local shown = fovSet(c, "Visible", true)
            if (not shown) or fovNeedRebuild then
                SA.DrawRemove(c)
                fovCircle, fovBackend = nil, "none"
                fovNeedRebuild = false
            end
        end
        -- Double: a second, inner ring (50%) built from Lines so it does
        -- not depend on a second native Circle being available.
        if style == "Double" then
            local n = 48
            if not fovEnsureRing("Double", n) then return end
            local used = {}
            for i = 1, n do
                local a1 = (i - 1) / n * math.pi * 2
                local a2 = i / n * math.pi * 2
                fovSeg(i, cx, cy, a1, a2, r * 0.5, r * 0.5, col, alpha,
                    math.max(thick - 1, 1), used)
            end
            fovHideRingFrom(n + 1, used)
        end
        if style == "Cross" then
            local n = 4
            if not fovEnsureRing("Cross", n) then return end
            local used = {}
            local k = math.max(r * 0.12, 6)
            -- four ticks: up, down, left, right
            fovSeg(1, cx, cy, -math.pi / 2, -math.pi / 2, r, r - k, col, alpha, thick, used)
            fovSeg(2, cx, cy,  math.pi / 2,  math.pi / 2, r, r - k, col, alpha, thick, used)
            fovSeg(3, cx, cy,  math.pi,      math.pi,     r, r - k, col, alpha, thick, used)
            fovSeg(4, cx, cy,  0,            0,           r, r - k, col, alpha, thick, used)
            fovHideRingFrom(n + 1, used)
        end
        return
    end

    -- Line-only styles.
    local segs = math.floor(tonumber(CFG.fovSegments) or 64)
    local count = fovRingCount(style, segs)
    if count <= 0 then return end
    if not fovEnsureRing(style, count) then return end
    local used = {}
    if style == "Segments" then
        for i = 1, count do
            local a1 = (i - 1) / count * math.pi * 2
            -- tiny overlap hides the seam between adjacent segments
            fovSeg(i, cx, cy, a1, a1 + (math.pi * 2 / count) * 1.05,
                r, r, col, alpha, thick, used)
        end
    elseif style == "Corners" then
        local per = 10
        local span = math.pi / 2 * 0.46   -- ~41 deg arc per corner
        local corner = math.pi / 4          -- centre of each corner arc
        for k = 0, 3 do
            local base = k * (math.pi / 2) + corner - span * 0.54
            for j = 1, per do
                local a1 = base + (j - 1) / per * span
                local a2 = base + j / per * span
                fovSeg(k * per + j, cx, cy, a1, a2, r, r, col, alpha, thick, used)
            end
        end
    elseif style == "Dots" then
        local gap = math.pi * 2 / count
        for i = 1, count do
            local a = (i - 1) * gap
            local a2 = a + gap * 0.42
            fovSeg(i, cx, cy, a, a2, r, r, col, alpha, thick, used)
        end
    elseif style == "Dashes" then
        local gap = math.pi * 2 / count
        for i = 1, count do
            local a = (i - 1) * gap
            local a2 = a + gap * 0.62
            fovSeg(i, cx, cy, a, a2, r, r, col, alpha, thick, used)
        end
    end
    fovHideRingFrom(count + 1, used)
end

local fovLastFrame = tick()

bindRender(function(dt)
    -- Switching the drawing backend at runtime must recreate every object,
    -- otherwise the old ones (native or GUI) would stay on screen.
    if lastForced ~= CFG.forceGuiDrawing then
        lastForced = CFG.forceGuiDrawing
        if fovCircle then SA.DrawRemove(fovCircle) end
        fovCircle = nil
        fovBackend = "none"
        fovClearRing()
    end

    local now = tick()
    local frameDt = math.max(now - (fovLastFrame or now), 0)
    fovLastFrame = now

    if not (CFG.showFov and SA.FovRadius() > 0) then
        if fovCircle then fovSet(fovCircle, "Visible", false) end
        fovHideRingFrom(1, {})
        return
    end

    local style = CFG.fovStyle or "Circle"
    local centre = SA.AimPoint()
    local radius = SA.FovRadius()
    fovDrawRing(style, centre.X, centre.Y, radius, fovColor(), fovAlpha(),
        fovThick(), frameDt)
    fovBackend = (style == "Circle" or style == "Double" or style == "Cross"
        or style == "Pulse") and fovBackend or "Segments"
    SA.FovLastStyle = style
end)
