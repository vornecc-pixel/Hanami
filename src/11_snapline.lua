-- ==================================================================
-- Hanami / 11_snapline.lua — Aim preview line + target/lead markers
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- SNAPLINE (FOV AIM PREVIEW)
-- Draws from the FOV reference point to the exact target silent aim
-- would pick. GREEN = line of sight clear, RED = wall/blocked. The
-- snapline toggle works on its own; no Silent Aim master / gun gate.
--
-- ── REWRITE NOTES ───────────────────────────────────────────────────
-- The previous version re-derived EVERYTHING from the shared preview
-- memo on every render frame and wrote ~8 native Drawing properties per
-- frame whether or not anything had moved. That was the source of the
-- recurring "stuck to the FOV" reports, for three separate reasons:
--
--   1. ONE-FRAME-LATE PROJECTION. This part binds its own RenderStepped
--      (loader order: this file comes before 19_render_loop), so the
--      memo it reads was filled on the PREVIOUS frame, and the camera
--      can have moved since. The line was drawn to last frame's pixel.
--      Fix: re-project the memo's WORLD position with the camera as it
--      is RIGHT NOW, and use the memo only to choose WHICH model. A
--      target that moved or a camera that turned is corrected this
--      frame instead of one frame later.
--
--   2. NO HYSTERESIS. A candidate sitting on the edge of the circle
--      flickered in and out as the pixel crossed the radius, which reads
--      as the line "sticking" then snapping. Fix: STAICKY retention.
--      Once a model is being drawn it keeps being drawn while it is
--      inside a slightly WIDER release radius (RELEASE = 1.18x), so
--      edge jitter cannot flip it. It is still hard-cleared the moment
--      it leaves the outer circle, dies, or the camera turns away.
--
--   3. WRITE CHURN. Every frame rewrote From / To / Color / Thickness /
--      Visible on four draws. Each write dirties the drawing proxy and
--      costs a ScreenGui sync. Fix: every property goes through a
--      last-value cache and is only written when it actually changed.
--      A stationary target costs ZERO writes per frame.
--
-- The shared memo (02_shared.lua) is the single source of truth for
-- WHO the target is; this file never picks its own target and never
-- resets the memo. It also never clears SA.Target.model while Gun Silent
-- Aim owns it -- that ownership confusion was the original freeze.
-- ────────────────────────────────────────────────────────────────────

local function drawSet(d, prop, v)
    if not d then return end
    pcall(function() d[prop] = v end)
end

-- Write a property only when it differs from the last value we wrote.
-- Returns true when a write actually happened.
local function drawSetIf(d, cache, prop, v)
    if not d then return end
    local prev = cache[prop]
    if prev ~= nil then
        if prev == v then return false end
        -- Vectors / colours are value types in Roblox, but the Fengari
        -- mock hands out plain tables: compare them component-wise so a
        -- "same" vector is not treated as a change and re-synced.
        local ta, tb = type(prev), type(v)
        if ta == "table" and tb == "table" then
            local same = true
            for k, pv in pairs(prev) do
                if v[k] ~= pv then same = false break end
            end
            for k in pairs(v) do
                if prev[k] == nil then same = false break end
            end
            if same then return false end
        end
    end
    pcall(function() d[prop] = v end)
    cache[prop] = v
    return true
end

local function initDraw(kind, props)
    local ok, d = pcall(function() return SA.NewDraw(kind) end)
    if not (ok and d) then return nil end
    for k, v in pairs(props) do drawSet(d, k, v) end
    return d
end

local snapLine = initDraw("Line", { Thickness = 3, Transparency = 0.2, Visible = false })
local snapDot  = initDraw("Circle", { Radius = 6, Filled = true, NumSides = 24,
                                      Transparency = 0.2, Visible = false })
local leadLine = initDraw("Line", { Thickness = 3, Transparency = 0.35, Visible = false })
local leadDot  = initDraw("Circle", { Radius = 7, Filled = false, NumSides = 24,
                                      Transparency = 0.35, Visible = false })

-- Last value written to each draw, so an unchanged frame writes nothing.
local snapCache, dotCache = {}, {}
local leadLCache, leadDCache = {}, {}

-- Set once the snapline has actually drawn; lets the disabled path skip
-- all work on a cold start (the draws begin hidden) while still running
-- exactly one hide when the user turns the feature off.
local snapWasOn = false

-- Sticky retention: the model currently being drawn and the world
-- position it was last seen at. Guarded by the release radius below.
local stickyModel, stickyPos = nil, nil
-- How much wider than the configured circle the retention ring is. A
-- target already being drawn keeps the line until it is 18% outside.
local RELEASE_SCALE = 1.18

local function clearSnapTarget()
    if not SA.Target then return end
    -- Keep the silent-aim fields (pred / lastShot / lastShotAt) intact.
    SA.Target.visible, SA.Target.screen, SA.Target.t = nil, nil, nil
    -- ONLY clear the model when nothing else owns it. Gun Silent Aim
    -- writes SA.Target.model when it is armed; stomping it here is what
    -- made the ESP highlight and the nearest-set flicker. With the
    -- snapline ON we own it; with Gun Silent Aim armed IT owns it.
    local silentOwns = CFG.masterEnabled == true and CFG.gunEnabled == true
    if CFG.snapLineEnabled == true or not silentOwns then
        SA.Target.model, SA.Target.pos = nil, nil
    end
end

local function hideSnap()
    -- Only write Visible = false when it is not already false, so a
    -- disabled snapline costs zero writes per frame.
    drawSetIf(snapLine, snapCache, "Visible", false)
    drawSetIf(snapDot,  dotCache,  "Visible", false)
    drawSetIf(leadLine, leadLCache, "Visible", false)
    drawSetIf(leadDot,  leadDCache, "Visible", false)
    -- Clearing the shared preview memo is NOT this file's job (it owns
    -- only its own four draws). Doing it here wiped the ESP highlight and
    -- the nearest-set 60x per second and was the original freeze.
    stickyModel, stickyPos = nil, nil
    clearSnapTarget()
end

function SA.SnaplineDispose()
    local n = 0
    local function one(d)
        if d then SA.DrawRemove(d); n = n + 1 end
    end
    one(snapLine); one(snapDot); one(leadLine); one(leadDot)
    snapLine, snapDot, leadLine, leadDot = nil, nil, nil, nil
    snapCache, dotCache, leadLCache, leadDCache = {}, {}, {}, {}
    stickyModel, stickyPos = nil, nil
    CFG.snapLineEnabled = false
    clearSnapTarget()
    return n
end

local function snapOrigin()
    -- The snapline ALWAYS starts at the same mouse / crosshair reference
    -- point as the FOV circle. Legacy Center / Bottom origins are gone.
    return SA.AimPoint()
end

local function snapSize()
    return math.clamp(tonumber(CFG.snapLineThickness) or 1, 1, 10)
end

function SA.SnaplineState()
    return {
        enabled = CFG.snapLineEnabled == true,
        master = CFG.masterEnabled == true and CFG.gunEnabled == true,
        independent = true,
        gate = "snapline toggle only",
        thickness = snapSize(),
        origin = "FOV Reference",
        reference = SA.AimPoint(),
        target = SA.Target and SA.Target.screen or nil,
        -- Rewrite diagnostics: how many draw writes this frame, and
        -- whether a sticky model is being retained.
        writes = SA.SnaplineWrites or 0,
        sticky = stickyModel ~= nil,
    }
end

local function snapProject(cam, v3, ok)
    local vp = cam.ViewportSize or Vector2.new(1280, 720)
    local m = 34
    local inView = ok == true and (tonumber(v3.Z) or 0) > 0
        and v3.X >= -m and v3.X <= vp.X + m
        and v3.Y >= -m and v3.Y <= vp.Y + m
    return Vector2.new(v3.X, v3.Y), inView
end

-- Pixel distance from the aim point, and whether a world position is
-- inside a circle of `radius` (with the sticky floor applied).
-- `floor` is the minimum radius treated as "inside". It is ONLY passed
-- for the sticky/held case, where a crosshair sitting exactly on a
-- player must not flicker out over a few pixels of jitter. A radius the
-- user actually configured is always honoured exactly -- applying the
-- floor to every check made a 10 px circle still match a target 25 px
-- away, which is exactly the "snapline stuck to the FOV" symptom.
local function snapInside(cam, worldPos, aim, radius, floor)
    local sp, ok = cam:WorldToViewportPoint(worldPos)
    if not ok or (tonumber(sp.Z) or 0) <= 0 then return false, nil end
    local px = Vector2.new(sp.X, sp.Y)
    local d = (px - aim).Magnitude
    if d <= math.max(radius, tonumber(floor) or 0) then return true, px end
    return false, px
end

local function updateSnapLine()
    -- EARLY EXIT BEFORE ANY WORK. Runs on every render frame whether or
    -- not the feature was ever enabled, so the disabled path must not
    -- touch shared state and must not write draws.
    if not CFG.snapLineEnabled then
        if snapWasOn then
            snapWasOn = false
            hideSnap()
        end
        return
    end
    snapWasOn = true
    local cam = ws.CurrentCamera
    if not cam then hideSnap(); return end

    local aim = snapOrigin()
    local radius = SA.FovRadius()
    -- The shared per-frame memo decides WHICH model. It is the same answer
    -- Gun Silent Aim and the manipulation probe read, so the three can
    -- never disagree about the target.
    local best = SA.PreviewTarget and SA.PreviewTarget() or nil

    -- ── STICKY RETENTION ────────────────────────────────────────────
    -- If the memo changed its mind this frame, only switch when the new
    -- pick is clearly inside; otherwise hold the model already drawn
    -- while it is still inside the wider release ring. This is what
    -- stops an edge-of-circle candidate from flickering the line off.
    local targetModel, targetPos = nil, nil
    if best and best.model and best.pos then
        targetModel, targetPos = best.model, best.pos
    elseif stickyModel and stickyPos then
        -- Memo lost the target (edge jitter, one failed pick). Keep the
        -- line only while the held model is still inside the release
        -- ring; anything further out hard-clears below.
        local stillThere = snapInside(cam, stickyPos, aim,
            radius * RELEASE_SCALE)
        if stillThere and stickyModel.Parent then
            targetModel, targetPos = stickyModel, stickyPos
        end
    end

    if not targetModel or not targetPos then
        stickyModel, stickyPos = nil, nil
        hideSnap()
        return
    end

    -- ── FRESH PROJECTION ────────────────────────────────────────────
    -- Re-project the WORLD position against the camera as it is NOW.
    -- The memo's pixel would be one frame stale because this callback
    -- runs before the FX pass that filled it; the world position is not.
    local sp, w2vOk = cam:WorldToViewportPoint(targetPos)
    local toPx, onScreen = snapProject(cam, sp, w2vOk)
    if not onScreen then
        stickyModel, stickyPos = nil, nil
        hideSnap()
        return
    end
    -- Hysteresis applies ONLY to a retained (held-over) target. A model
    -- the memo picked THIS frame is authoritative and is judged against
    -- the configured circle exactly, so shrinking the FOV or turning away
    -- must clear the line immediately -- an over-eager release ring here
    -- would keep drawing to a target that is no longer selected.
    local held = stickyModel == targetModel
    -- A retained target gets the wider release ring (edge-jitter
    -- tolerance); a fresh pick is judged against the configured circle.
    -- Neither path widens beyond that, so shrinking the FOV or turning
    -- away always clears the line on the same frame.
    local inside = snapInside(cam, targetPos, aim,
        held and radius * RELEASE_SCALE or radius)
    if not inside then
        stickyModel, stickyPos = nil, nil
        hideSnap()
        return
    end
    if stickyModel ~= targetModel then
        -- Switching models is a deliberate change: reset the caches so
        -- the next writes are not suppressed by the old model's values.
        snapCache, dotCache, leadLCache, leadDCache = {}, {}, {}, {}
    end
    stickyModel, stickyPos = targetModel, targetPos

    -- The LOS result is already cached inside SA.IsVisible(); reuse the
    -- same value the ESP box uses so the line colour and the VIS / WALL
    -- tag can never disagree.
    local visible = SA.IsVisible(targetModel, targetPos)
    local col = visible and ESP_COLORS.snapVisible or ESP_COLORS.snapHidden

    -- Keep SA.Target fresh even on an executor with no working draws.
    local t = SA.Target
    if t.model ~= targetModel then t.model = targetModel end
    if t.pos ~= targetPos then t.pos = targetPos end
    if t.visible ~= visible then t.visible = visible end
    if t.screen ~= toPx then
        local same = false
        if t.screen ~= nil then
            pcall(function() same = (t.screen - toPx).Magnitude <= 0.01 end)
        end
        if not same then t.screen = toPx end
    end
    t.t = SA.FrameClock and SA.FrameClock() or tick()

    -- ── DRAWS (change-gated) ────────────────────────────────────────
    local writes = 0
    local thick = snapSize()
    if snapLine then
        if drawSetIf(snapLine, snapCache, "From", aim) then writes = writes + 1 end
        if drawSetIf(snapLine, snapCache, "To", toPx) then writes = writes + 1 end
        if drawSetIf(snapLine, snapCache, "Color", col) then writes = writes + 1 end
        if drawSetIf(snapLine, snapCache, "Thickness", thick) then writes = writes + 1 end
        if drawSetIf(snapLine, snapCache, "Visible", true) then writes = writes + 1 end
    end
    if snapDot then
        if drawSetIf(snapDot, dotCache, "Position", toPx) then writes = writes + 1 end
        if drawSetIf(snapDot, dotCache, "Color", col) then writes = writes + 1 end
        if drawSetIf(snapDot, dotCache, "Radius", thick + 3) then writes = writes + 1 end
        if drawSetIf(snapDot, dotCache, "Visible", true) then writes = writes + 1 end
    end

    -- lead marker: where the ballistic solver will actually send the shot
    local showLead = leadLine and CFG.snapShowLead and CFG.prediction
    if showLead then
        local aimPos, info = SA.Predict(cam.CFrame.Position, targetPos, targetModel)
        local lp2, leadOk = cam:WorldToViewportPoint(aimPos)
        local leadPx, leadOn = snapProject(cam, lp2, leadOk)
        if leadOn and (leadPx - toPx).Magnitude > 1.5 and info.inRange then
            if drawSetIf(leadLine, leadLCache, "From", toPx) then writes = writes + 1 end
            if drawSetIf(leadLine, leadLCache, "To", leadPx) then writes = writes + 1 end
            if drawSetIf(leadLine, leadLCache, "Color", ESP_COLORS.lead) then writes = writes + 1 end
            if drawSetIf(leadLine, leadLCache, "Thickness", thick) then writes = writes + 1 end
            if drawSetIf(leadLine, leadLCache, "Visible", true) then writes = writes + 1 end
            if drawSetIf(leadDot, leadDCache, "Position", leadPx) then writes = writes + 1 end
            if drawSetIf(leadDot, leadDCache, "Color", ESP_COLORS.lead) then writes = writes + 1 end
            if drawSetIf(leadDot, leadDCache, "Radius", thick + 4) then writes = writes + 1 end
            if drawSetIf(leadDot, leadDCache, "Visible", true) then writes = writes + 1 end
        else
            if drawSetIf(leadLine, leadLCache, "Visible", false) then writes = writes + 1 end
            if drawSetIf(leadDot, leadDCache, "Visible", false) then writes = writes + 1 end
        end
    else
        if drawSetIf(leadLine, leadLCache, "Visible", false) then writes = writes + 1 end
        if drawSetIf(leadDot, leadDCache, "Visible", false) then writes = writes + 1 end
    end
    SA.SnaplineWrites = writes
end

bindRender(updateSnapLine)
