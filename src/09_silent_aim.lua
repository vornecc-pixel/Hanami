-- ==================================================================
-- Hanami / 09_silent_aim.lua — Camera sandwich renderstep binds
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- CAMERA SANDWICH (Silent Aim)
-- ────────────────────────────────────────────────────────────────────

if not _G.__saSnapName then
    _G.__saSnapName    = "s_" .. tostring(math.random(1e6, 9e6))
    _G.__saRestoreName = "r_" .. tostring(math.random(1e6, 9e6))
end
local snapName    = _G.__saSnapName
local restoreName = _G.__saRestoreName
local snapPrio    = Enum.RenderPriority.Camera.Value + 2
local restorePrio = Enum.RenderPriority.Camera.Value + 4

local realCFrame, snapped = nil, false

RunService:BindToRenderStep(snapName, snapPrio, function()
    snapped = false; realCFrame = nil
    saManipBeginFrame()
    if not (CFG.masterEnabled and CFG.gunEnabled) then return end
    if not isFiring()   then return end
    if not gunCanSnap() then return end
    local camera = ws.CurrentCamera
    if not camera then return end
    -- FOV circle centre is the one and only aiming reference point
    local aimPx = SA.AimPoint()
    local best  = pickBestTarget(camera, aimPx, camera.CFrame.Position)
    if not best then return end
    local origin = camera.CFrame.Position
    local targetPos = best.pos
    if CFG.prediction then
        -- exact ballistic intercept: per-gun speed, quadratic lead,
        -- bullet-drop compensation and alt-ammo modifiers (08_prediction.lua)
        local aim, info = SA.Predict(origin, targetPos, best.model)
        targetPos = aim
        SA.Target.pred = info
        if CFG.debug then
            dbg(string.format("pred %s | speed %.0f | t %.3fs | lead %.1f | drop %.2f | %s",
                info.id, info.speed, info.t, info.lead, info.drop,
                info.inRange and "in range" or "OUT OF RANGE"))
        end
    end
    if (targetPos - origin).Magnitude < 0.05 then return end
    local manipOrigin = origin
    if CFG.manipulation then
        local resolved, ok = saManipResolve(origin, targetPos, best.model)
        if not ok and CFG.wallCheck then return end
        manipOrigin = resolved
    end
    realCFrame = camera.CFrame
    local ok = pcall(function()
        camera.CFrame = CFrame.lookAt(manipOrigin, targetPos)
    end)
    snapped = ok
    if ok then
        SA.Target.lastShot = best.model
        SA.Target.lastShotAt = tick()
        dbg("snap ->", best.model.Name, manipOrigin == origin and "" or "[manip]")
    end
end)

RunService:BindToRenderStep(restoreName, restorePrio, function()
    if snapped and realCFrame then
        local camera = ws.CurrentCamera
        if camera then pcall(function() camera.CFrame = realCFrame end) end
    end
    snapped, realCFrame = false, nil
    saManipRestore()
end)

