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
-- FIX: the old init block wrote ~14 native Drawing properties OUTSIDE a
-- pcall. On executors with a partial Drawing API the very first bad write
-- aborted the entire joined chunk at load time -> "the script doesn't
-- load". Every write is now individually guarded, and a missing draw
-- object no longer stops SA.Target from being refreshed.
-- ────────────────────────────────────────────────────────────────────

local function drawSet(d, prop, v)
    if not d then return end
    pcall(function() d[prop] = v end)
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

-- Set once the snapline has actually drawn; lets the disabled path skip
-- all work on a cold start (the draws begin hidden) while still running
-- exactly one hide when the user turns the feature off.
local snapWasOn = false

local function clearSnapTarget()
    if not SA.Target then return end
    -- Keep the silent-aim fields (pred / lastShot / lastShotAt) intact.
    -- While the snapline is ON it owns SA.Target.model, so a target that
    -- leaves the FOV must clear the ESP highlight immediately. With the
    -- snapline OFF and Gun Silent Aim ON, saRefreshAimTarget() owns the
    -- model; with BOTH OFF there is no owner, so clear it here too.
    SA.Target.visible, SA.Target.screen, SA.Target.t = nil, nil, nil
    if CFG.snapLineEnabled == true
        or not (CFG.masterEnabled == true and CFG.gunEnabled == true) then
        SA.Target.model, SA.Target.pos = nil, nil
    end
end

local function hideSnap()
    drawSet(snapLine, "Visible", false)
    drawSet(snapDot,  "Visible", false)
    drawSet(leadLine, "Visible", false)
    drawSet(leadDot,  "Visible", false)
    -- The snapline must hide ITS OWN four draws and nothing else.
    --
    -- This used to also call SA.PreviewTargetReset(), which threw away the
    -- shared per-frame preview memo owned by 02_shared.lua. That memo is
    -- what the ESP target highlight and the nearest-set read; destroying
    -- it here had two consequences:
    --
    --   1. With the toggle OFF, updateSnapLine() runs every render frame
    --      and takes this branch (see below), so the memo was wiped 60x
    --      per second FOREVER — the ESP target highlight and the
    --      nearest-set slot flickered on and off permanently even though
    --      the snapline was disabled.
    --   2. With the toggle ON, ANY frame whose pick failed (a target
    --      crossing the circle edge, one rollHit miss) wiped the memo, so
    --      the target jumped nil -> player -> nil while the circle sat on
    --      a player. That is the reported "everything gets stuck while
    --      the FOV is on a player, normal again once it is off".
    --
    -- Clearing the shared memo is not the snapline's job: it only owns
    -- its own line / dot. SA.Target is cleared by clearSnapTarget()
    -- below, which is the contract every other consumer already expects.
    clearSnapTarget()
end

function SA.SnaplineDispose()
    local n = 0
    local function one(d)
        if d then SA.DrawRemove(d); n = n + 1 end
    end
    one(snapLine); one(snapDot); one(leadLine); one(leadDot)
    snapLine, snapDot, leadLine, leadDot = nil, nil, nil, nil
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
    local ref = SA.AimPoint()
    return {
        enabled = CFG.snapLineEnabled == true,
        master = CFG.masterEnabled == true and CFG.gunEnabled == true,
        independent = true,
        gate = "snapline toggle only",
        thickness = snapSize(),
        origin = "FOV Reference",
        reference = ref,
        target = SA.Target and SA.Target.screen or nil,
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

local function updateSnapLine()
    -- Works with JUST the Visual -> Snapline toggle ON. Gun Silent Aim is
    -- no longer a prerequisite; the line is an aim preview, not a shot.
    --
    -- EARLY EXIT BEFORE ANY WORK. This callback is bound at load time and
    -- runs on every render frame whether or not the user ever enables the
    -- snapline, so the disabled path must be as cheap as possible and
    -- must not touch shared state. The four draws are created Visible =
    -- false and are only ever made visible below, so there is nothing to
    -- hide the first time: skip the whole function, and only run the
    -- (idempotent) hide once after the toggle has actually been used.
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

    -- ONE reference point: the centre of the drawn FOV circle.
    -- ONE target: the shared per-frame preview memo (02_shared.lua). The
    -- snapline used to run its own pickBestTarget() every frame while
    -- saRefreshAimTarget() ran another one, so two FULL candidate scans
    -- (all players + all NPCs, one WorldToViewportPoint each) hit the
    -- render thread every frame and the two owners disagreed about
    -- SA.Target.model. That mismatch is what made the ESP appear stuck /
    -- jittery while the snapline or Gun Silent Aim was ON.
    local best = SA.PreviewTarget and SA.PreviewTarget() or nil
    if not best then hideSnap(); return end
    local sp, w2vOk = cam:WorldToViewportPoint(best.pos)
    local toPx, onScreen = snapProject(cam, sp, w2vOk)
    if not onScreen then hideSnap(); return end
    -- The LOS result is already cached inside SA.IsVisible(); reuse the
    -- same value the ESP box uses for this frame so the line colour and
    -- the VIS / WALL tag can never disagree.
    local visible = SA.IsVisible(best.model, best.pos)
    local col = visible and ESP_COLORS.snapVisible or ESP_COLORS.snapHidden

    -- Keep SA.Target fresh even if this executor has no working draws.
    -- Only write a field that actually changed: the FX pass reads this
    -- table every frame, and unconditional writes churned the ESP
    -- highlight state for no reason.
    local t = SA.Target
    if t.model ~= best.model then t.model = best.model end
    if t.pos ~= best.pos then t.pos = best.pos end
    if t.visible ~= visible then t.visible = visible end
    local samePx = false
    if t.screen ~= nil then
        pcall(function() samePx = (t.screen - toPx).Magnitude <= 0.01 end)
    end
    if not samePx then t.screen = toPx end
    t.t = SA.FrameClock and SA.FrameClock() or tick()

    if snapLine then
        drawSet(snapLine, "From", snapOrigin())
        drawSet(snapLine, "To", toPx)
        drawSet(snapLine, "Color", col)
        drawSet(snapLine, "Thickness", snapSize())
        drawSet(snapLine, "Visible", true)
    end
    if snapDot then
        drawSet(snapDot, "Position", toPx)
        drawSet(snapDot, "Color", col)
        drawSet(snapDot, "Radius", snapSize() + 3)
        drawSet(snapDot, "Visible", true)
    end

    -- lead marker: where the ballistic solver will actually send the shot
    local showLead = leadLine and CFG.snapShowLead and CFG.prediction
    if showLead then
        local aimPos, info = SA.Predict(cam.CFrame.Position, best.pos, best.model)
        local lp2, leadOk = cam:WorldToViewportPoint(aimPos)
        local leadPx, leadOn = snapProject(cam, lp2, leadOk)
        if leadOn and (leadPx - toPx).Magnitude > 1.5 and info.inRange then
            drawSet(leadLine, "From", toPx)
            drawSet(leadLine, "To", leadPx)
            drawSet(leadLine, "Color", ESP_COLORS.lead)
            drawSet(leadLine, "Thickness", snapSize())
            drawSet(leadLine, "Visible", true)
            drawSet(leadDot, "Position", leadPx)
            drawSet(leadDot, "Color", ESP_COLORS.lead)
            drawSet(leadDot, "Radius", snapSize() + 4)
            drawSet(leadDot, "Visible", true)
        else
            drawSet(leadLine, "Visible", false); drawSet(leadDot, "Visible", false)
        end
    else
        drawSet(leadLine, "Visible", false); drawSet(leadDot, "Visible", false)
    end
end

bindRender(updateSnapLine)
