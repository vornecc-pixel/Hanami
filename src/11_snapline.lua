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

local function hideSnap()
    drawSet(snapLine, "Visible", false)
    drawSet(snapDot,  "Visible", false)
    drawSet(leadLine, "Visible", false)
    drawSet(leadDot,  "Visible", false)
end

local function snapOrigin(cam)
    if CFG.snapLineOrigin == "Center" then
        return Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
    elseif CFG.snapLineOrigin == "Bottom" then
        return Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y)
    end
    return SA.AimPoint()   -- same reference point as the FOV circle
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
    if not best then
        SA.Target.model, SA.Target.pos = nil, nil
        hideSnap(); return
    end
    local sp, onScreen = cam:WorldToViewportPoint(best.pos)
    if not onScreen then hideSnap(); return end

    local toPx = Vector2.new(sp.X, sp.Y)
    local visible = SA.IsVisible(best.model, best.pos)
    local col = visible and ESP_COLORS.snapVisible or ESP_COLORS.snapHidden

    -- Keep SA.Target fresh even if this executor has no working draws.
    SA.Target.model   = best.model
    SA.Target.pos     = best.pos
    SA.Target.visible = visible
    SA.Target.screen  = toPx
    SA.Target.t       = tick()

    if snapLine then
        drawSet(snapLine, "From", snapOrigin(cam))
        drawSet(snapLine, "To", toPx)
        drawSet(snapLine, "Color", col)
        drawSet(snapLine, "Thickness", CFG.snapLineThickness)
        drawSet(snapLine, "Visible", true)
    end
    if snapDot then
        drawSet(snapDot, "Position", toPx)
        drawSet(snapDot, "Color", col)
        drawSet(snapDot, "Visible", true)
    end

    -- lead marker: where the ballistic solver will actually send the shot
    local showLead = leadLine and CFG.snapShowLead and CFG.prediction
    if showLead then
        local aimPos, info = SA.Predict(cam.CFrame.Position, best.pos, best.model)
        local lp2, leadOn = cam:WorldToViewportPoint(aimPos)
        local leadPx = Vector2.new(lp2.X, lp2.Y)
        if leadOn and (leadPx - toPx).Magnitude > 1.5 and info.inRange then
            drawSet(leadLine, "From", toPx)
            drawSet(leadLine, "To", leadPx)
            drawSet(leadLine, "Color", ESP_COLORS.lead)
            drawSet(leadLine, "Visible", true)
            drawSet(leadDot, "Position", leadPx)
            drawSet(leadDot, "Color", ESP_COLORS.lead)
            drawSet(leadDot, "Visible", true)
        else
            drawSet(leadLine, "Visible", false); drawSet(leadDot, "Visible", false)
        end
    else
        drawSet(leadLine, "Visible", false); drawSet(leadDot, "Visible", false)
    end
end

bindRender(updateSnapLine)
