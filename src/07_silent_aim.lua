-- ==================================================================
-- Hanami / 07_silent_aim.lua — Camera sandwich renderstep binds
-- Loaded in order by loader.lua. Parts are joined into ONE chunk
-- before running, so every `local` is shared just like the original.
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
    local aimPx = UserInputService:GetMouseLocation()
    local best  = pickBestTarget(camera, aimPx, camera.CFrame.Position)
    if not best then return end
    local targetPos = best.pos
    if CFG.prediction then
        local speed  = getGunSpeed()
        local travel = (targetPos - camera.CFrame.Position).Magnitude / speed
        local vel    = getVelocity(best.bone)
        if vel.Magnitude > 0.5 then targetPos = targetPos + vel * travel end
    end
    local origin = camera.CFrame.Position
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

