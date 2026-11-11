-- ==================================================================
-- Hanami / 11_snapline.lua — Aim preview line + target/lead markers
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- SNAPLINE (FOV AIM PREVIEW)
-- Draws from the FOV reference point to the exact target silent aim
-- would pick. GREEN = line of sight clear, RED = wall/blocked.
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

local snapLine = initDraw("Line", { Thickness = 1, Transparency = 0.2, Visible = false })
local snapDot  = initDraw("Circle", { Radius = 4, Filled = true, NumSides = 24,
                                      Transparency = 0.2, Visible = false })
local leadLine = initDraw("Line", { Thickness = 1, Transparency = 0.35, Visible = false })
local leadDot  = initDraw("Circle", { Radius = 5, Filled = false, NumSides = 24,
                                      Transparency = 0.35, Visible = false })

local function clearSnapTarget()
    if not SA.Target then return end
    -- Keep the silent-aim fields (pred / lastShot / lastShotAt) intact.
    SA.Target.model, SA.Target.pos = nil, nil
    SA.Target.visible, SA.Target.screen, SA.Target.t = nil, nil, nil
end

local function hideSnap()
    drawSet(snapLine, "Visible", false)
    drawSet(snapDot,  "Visible", false)
    drawSet(leadLine, "Visible", false)
    drawSet(leadDot,  "Visible", false)
    clearSnapTarget()
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
    if not (CFG.snapLineEnabled and CFG.masterEnabled and CFG.gunEnabled) then
        hideSnap(); return
    end
    local cam = ws.CurrentCamera
    if not cam then hideSnap(); return end

    -- ONE reference point: the centre of the drawn FOV circle.
    local aimPx = SA.AimPoint()
    local best = pickBestTarget(cam, aimPx, cam.CFrame.Position, true)
    if not best then hideSnap(); return end
    local sp, w2vOk = cam:WorldToViewportPoint(best.pos)
    local toPx, onScreen = snapProject(cam, sp, w2vOk)
    if not onScreen then hideSnap(); return end
    local visible = SA.IsVisible(best.model, best.pos)
    local col = visible and ESP_COLORS.snapVisible or ESP_COLORS.snapHidden

    -- Keep SA.Target fresh even if this executor has no working draws.
    SA.Target.model   = best.model
    SA.Target.pos     = best.pos
    SA.Target.visible = visible
    SA.Target.screen  = toPx
    SA.Target.t       = tick()

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
