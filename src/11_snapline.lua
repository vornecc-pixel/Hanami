-- ==================================================================
-- Hanami / 11_snapline.lua — Aim preview line + target/lead markers
-- Loaded in order by loader.lua. Parts are joined into ONE chunk
-- before running, so every `local` is shared just like the original.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- SNAPLINE (FOV AIM PREVIEW)
-- Draws from the FOV centre to the exact target silent aim would pick.
-- GREEN = line of sight clear, RED = wall/blocked (will need wall pen).
-- Uses `preview` mode so hit-chance RNG can't make the line flicker.
-- ────────────────────────────────────────────────────────────────────

local snapLine, snapDot, leadLine, leadDot = nil, nil, nil, nil
do
    local ok = pcall(function()
        snapLine = SA.NewDraw("Line")
        snapDot  = SA.NewDraw("Circle")
        leadLine = SA.NewDraw("Line")
        leadDot  = SA.NewDraw("Circle")
    end)
    if ok and snapLine and snapDot and leadLine and leadDot then
        snapLine.Thickness = 1
        snapLine.Transparency = 0.2
        snapLine.Visible = false
        snapDot.Radius = 4
        snapDot.Filled = true
        snapDot.NumSides = 24
        snapDot.Transparency = 0.2
        snapDot.Visible = false
        leadLine.Thickness = 1
        leadLine.Transparency = 0.35
        leadLine.Visible = false
        leadDot.Radius = 5
        leadDot.Filled = false
        leadDot.NumSides = 24
        leadDot.Transparency = 0.35
        leadDot.Visible = false
    else
        snapLine, snapDot, leadLine, leadDot = nil, nil, nil, nil
    end
end

local function hideSnap()
    if snapLine then snapLine.Visible = false end
    if snapDot  then snapDot.Visible  = false end
    if leadLine then leadLine.Visible = false end
    if leadDot  then leadDot.Visible  = false end
end

local function snapOrigin(cam)
    if CFG.snapLineOrigin == "Center" then
        return Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
    elseif CFG.snapLineOrigin == "Bottom" then
        return Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y)
    end
    return UserInputService:GetMouseLocation()
end

local function updateSnapLine()
    if not (snapLine and CFG.snapLineEnabled and CFG.masterEnabled and CFG.gunEnabled) then
        hideSnap(); return
    end
    local cam = ws.CurrentCamera
    if not cam then hideSnap(); return end
    local aimPx = UserInputService:GetMouseLocation()
    -- the FOV picker is always measured from the mouse, even when the
    -- line itself is drawn from screen centre / bottom
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

    snapLine.From = snapOrigin(cam)
    snapLine.To = toPx
    snapLine.Color = col
    snapLine.Thickness = CFG.snapLineThickness
    snapLine.Visible = true

    snapDot.Position = toPx
    snapDot.Color = col
    snapDot.Visible = true

    -- lead marker: where the ballistic solver will actually send the shot
    if leadLine and CFG.snapShowLead and CFG.prediction then
        local aimPos, info = SA.Predict(cam.CFrame.Position, best.pos, best.model)
        local lp2, leadOn = cam:WorldToViewportPoint(aimPos)
        local leadPx = Vector2.new(lp2.X, lp2.Y)
        if leadOn and (leadPx - toPx).Magnitude > 1.5 and info.inRange then
            leadLine.From = toPx
            leadLine.To = leadPx
            leadLine.Color = ESP_COLORS.lead
            leadLine.Visible = true
            leadDot.Position = leadPx
            leadDot.Color = ESP_COLORS.lead
            leadDot.Visible = true
        else
            leadLine.Visible = false; leadDot.Visible = false
        end
    elseif leadLine then
        leadLine.Visible = false; leadDot.Visible = false
    end

    SA.Target.model   = best.model
    SA.Target.pos     = best.pos
    SA.Target.visible = visible
    SA.Target.screen  = toPx
    SA.Target.t       = tick()
end

if snapLine then
    bindRender(updateSnapLine)
end
