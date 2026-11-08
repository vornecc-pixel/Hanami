-- ==================================================================
-- Hanami / 09_silent_aim.lua — Camera-snap Silent Aim v7.7
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- SILENT AIM — camera-snap v7.7 (from the vault extract, integrated)
--
-- This REPLACES the old camera sandwich. The old build only snapped the
-- camera inside a RenderStep bind, so a gun that fires its remote
-- synchronously from InputBegan / Tool.Activated had already sent the
-- shot with the UNSNAPPED camera. v7.7 adds:
--
--   Fix A  InputBegan connection reorder: disconnect the game's
--          InputBegan handlers, install our snap-first connection, then
--          reattach the originals. A double task.defer restore keeps the
--          camera snapped long enough for nested task.spawn(fire) paths.
--   Fix B  Tool.Activated connection reorder for games that fire from the
--          tool's Activated handler instead of InputBegan.
--   Tap window widened 0.2 -> 0.35 (and InputEnded now stamps `last`).
--   Bow path: Shoot remote hook rewrites data.dir / data.origin, with the
--          target MODEL passed to manipulation (the old extract passed
--          nil). Bow draw/release keeps the snap alive a few frames.
--   Manipulation v4: see 05_manipulation.lua (8 peek directions,
--          adaptive peek, filter includes the target model, higher caps).
--
-- KEPT from Hanami (do not regress):
--   * SA.AimPoint() + SA.FovRadius() are still the ONE reference point for
--     target picking (the FOV circle, snapline, tracers and arrows all use
--     the same centre/radius).
--   * SA.Predict() stays the ballistic solver: exact quadratic intercept
--     with per-gun speed, bullet drop, alt ammo and live ping. The
--     extract's simple `dist/speed * velocity` guess was NOT copied.
--   * Exact gun speeds/damage from 07_gun_specs.lua, not the extract's
--     saBulletSpeeds table.
--   * The FOV circle stays in 10_fov_circle.lua (no duplicate Drawing).
--
-- Everything that has to survive a re-execute is dispatched through SA or
-- _G, so the InputBegan/Tool/remote hooks installed once by an older run
-- always call into the CURRENT chunk instead of stale closures.
-- ────────────────────────────────────────────────────────────────────

-- Executor-only helpers. Look in _G and getgenv(); the isolated chunk env
-- created by loader.lua inherits both, so this also works without setfenv.
local function executorFn(name)
    local v = rawget(_G, name)
    if type(v) == "function" then return v end
    local ok, g = pcall(function()
        if type(getgenv) ~= "function" then return nil end
        return getgenv()[name]
    end)
    if ok and type(g) == "function" then return g end
    return nil
end

local function connFn(c)
    local ok, fn = pcall(function() return c.Function or c.fn or c.func end)
    if ok and type(fn) == "function" then return fn end
    return nil
end

local getconnectionsFn = executorFn("getconnections")
local tapInfo = _G.__saTapReorderInfo or {
    active = false, connections = 0, reason = "not attempted",
}
_G.__saTapReorderInfo = tapInfo

-- ── shared bind names (banner / Debug / Unload all reference these) ───
if not _G.__saSnapName then
    _G.__saSnapName    = "s_" .. tostring(math.random(1e6, 9e6))
    _G.__saRestoreName = "r_" .. tostring(math.random(1e6, 9e6))
end
local snapName    = _G.__saSnapName
local restoreName = _G.__saRestoreName
local snapPrio    = Enum.RenderPriority.Camera.Value + 2
local restorePrio = Enum.RenderPriority.Camera.Value + 4

local realCFrame, snapped = nil, false
local saSnappedThisFrame = false
local saBowWasDrawing = false

-- The extract used `flags["sa_lock"]`; Hanami's master switch is CFG.
-- SA.Alive also stops the tap/bow hooks after "Unload Everything".
local function saLockActive()
    return SA.Alive == true and CFG.masterEnabled == true and CFG.gunEnabled == true
end

-- ────────────────────────────────────────────────────────────────────
-- TARGET RESOLUTION — one path for tap snap, render step and bow hook
-- The FOV centre/radius come from 02_shared.lua, and the exact ballistic
-- solver lives in 08_prediction.lua. Returns (aimPos, model, bone).
-- ────────────────────────────────────────────────────────────────────
local function findSilentTarget(camera, origin)
    -- ONE reference point: the centre of the drawn FOV circle.
    local best = pickBestTarget(camera, SA.AimPoint(), origin)
    if not best then return nil, nil, nil end
    local aim = best.pos
    if CFG.prediction then
        local newAim, info = SA.Predict(origin, aim, best.model)
        aim = newAim
        SA.Target.pred = info
        if CFG.debug then
            dbg(string.format("pred %s | speed %.0f | t %.3fs | lead %.1f | drop %.2f | %s",
                info.id, info.speed, info.t, info.lead, info.drop,
                info.inRange and "in range" or "OUT OF RANGE"))
        end
    end
    return aim, best.model, best.bone
end

function SA.ResolveShot()
    if not saLockActive() then return nil end
    local camera = ws.CurrentCamera
    if not camera then return nil end
    local origin = camera.CFrame.Position
    local aim, model, bone = findSilentTarget(camera, origin)
    if not aim then return nil end
    if (aim - origin).Magnitude < 0.05 then return nil end
    local manipOrigin = origin
    if CFG.manipulation then
        local resolved, ok = saManipResolve(origin, aim, model)
        if not ok and CFG.wallCheck then return nil end
        manipOrigin = resolved
    end
    if (aim - manipOrigin).Magnitude < 0.05 then return nil end
    return { aim = aim, origin = manipOrigin, model = model, bone = bone, camera = camera }
end

-- Called by the InputBegan / Tool.Activated wrappers (installed once).
-- Idempotent per input event: many games dispatch the fire remote from
-- BOTH InputBegan and Tool.Activated. Two snaps would capture the already
-- snapped CFrame as "real" and leave the camera pointing at the target.
-- A 1 s TTL clears stale state if a restore ever fails to run.
function SA.TapSnap()
    if not (CFG.saTapReorder and saLockActive()) then return nil, nil end
    if _G.__saTapCF then
        if (tick() - (_G.__saTapAt or 0)) < 1 then return nil, nil end
        _G.__saTapCF, _G.__saTapCam, _G.__saTapAt = nil, nil, nil
    end
    local shot = SA.ResolveShot()
    if not shot then return nil, nil end
    local camera = shot.camera
    local cf = camera.CFrame
    local ok = pcall(function()
        camera.CFrame = CFrame.lookAt(shot.origin, shot.aim)
    end)
    if not ok then return nil, nil end
    _G.__saTapCF, _G.__saTapCam, _G.__saTapAt = cf, camera, tick()
    SA.Target.lastShot = shot.model
    SA.Target.lastShotAt = tick()
    dbg("tap snap ->", shot.model and shot.model.Name or "?")
    return cf, camera
end

function SA.TapRestore(cf, camera)
    if cf and camera then pcall(function() camera.CFrame = cf end) end
    if cf and _G.__saTapCF == cf then
        _G.__saTapCF, _G.__saTapCam, _G.__saTapAt = nil, nil, nil
    end
end

-- Called from the hooked Fust.Remotes.Shoot. `data.draw` packets mark the
-- bow as being drawn; shoot packets get the exact predicted direction.
function SA.BowShot(data)
    if type(data) ~= "table" then return data end
    -- A cancelled draw may never send a shoot packet; the 5 s TTL in
    -- isFiring() keeps SA.BowDrawing from pinning the snap forever.
    if data.draw then
        SA.BowDrawing = true
        SA.BowDrawingAt = tick()
        return data
    end
    SA.BowDrawing = false
    if not (CFG.saBowHook and saLockActive() and SA.IsEquippedBow()) then return data end
    if not data.dir then return data end
    local shot = SA.ResolveShot()
    if not shot then return data end
    local dir = (shot.aim - shot.origin).Unit
    data.dir = dir
    data.origin = shot.origin + dir * (SA.BOW_MUZZLE or 0.5)
    SA.Target.lastShot = shot.model
    SA.Target.lastShotAt = tick()
    dbg("bow shot ->", shot.model and shot.model.Name or "?")
    return data
end

-- ══════════════════════════════════════════════════════════════════
-- TAP-FIRE FIX A — InputBegan connection reorder (snap before dispatch)
-- ══════════════════════════════════════════════════════════════════
local function saInstallInputReorder()
    if not CFG.saTapReorder then
        tapInfo.reason = "disabled in config"
        return
    end
    if not getconnectionsFn then
        tapInfo.reason = "getconnections unavailable"
        return
    end
    if _G.__saTapInputHooked then
        tapInfo.active = true
        tapInfo.reason = "installed (earlier run)"
        return
    end
    local ok, err = pcall(function()
        local conns = getconnectionsFn(UserInputService.InputBegan)
        if type(conns) ~= "table" or #conns == 0 then
            error("no InputBegan connections")
        end
        -- Extract EVERY function first. If any connection cannot be read,
        -- abort WITHOUT disconnecting anything (the extract disconnected
        -- first and could leave the game with no input handlers at all).
        local fns = {}
        for i, c in ipairs(conns) do
            local fn = connFn(c)
            if not fn then error("connection " .. i .. " has no callable Function") end
            fns[i] = fn
        end
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end

        UserInputService.InputBegan:Connect(function(input, gp)
            if not CFG.saTapReorder then return end
            if not input or input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            if gp then return end
            local cf, camera = SA.TapSnap()
            if cf and camera then
                -- double defer: nested task.spawn(fire) inside the game's
                -- handlers still sees the snapped camera.
                task.defer(function()
                    task.defer(function()
                        SA.TapRestore(cf, camera)
                    end)
                end)
            end
        end)
        for _, fn in ipairs(fns) do
            UserInputService.InputBegan:Connect(fn)
        end
        tapInfo.connections = #fns
    end)
    if ok then
        _G.__saTapInputHooked = true
        tapInfo.active = true
        tapInfo.reason = "active"
        print("[sa] tap fix A active (InputBegan reorder, " .. tapInfo.connections .. " conns)")
    else
        tapInfo.active = false
        tapInfo.reason = "unavailable: " .. tostring(err)
        warn("[sa] tap fix A unavailable: " .. tostring(err))
    end
end
SA.InstallTapReorder = saInstallInputReorder
saInstallInputReorder()

-- ══════════════════════════════════════════════════════════════════
-- TAP-FIRE FIX B — Tool.Activated connection reorder (fallback)
-- ══════════════════════════════════════════════════════════════════
local function saHookToolTap(tool)
    if not tool or not tool:IsA("Tool") then return end
    if not getconnectionsFn then return end
    local hooked = false
    pcall(function() hooked = tool:GetAttribute("__saTapHooked") == true end)
    if hooked then return end
    local ok, conns = pcall(function() return getconnectionsFn(tool.Activated) end)
    if not ok or type(conns) ~= "table" or #conns == 0 then return end
    local handlers = {}
    for i, c in ipairs(conns) do
        local fn = connFn(c)
        if not fn then return end   -- abort before touching anything
        handlers[i] = fn
    end
    pcall(function() tool:SetAttribute("__saTapHooked", true) end)
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    tool.Activated:Connect(function()
        local cf, camera = nil, nil
        if CFG.saTapReorder then cf, camera = SA.TapSnap() end
        for _, fn in ipairs(handlers) do pcall(fn) end
        if cf and camera then
            task.defer(function()
                task.defer(function() SA.TapRestore(cf, camera) end)
            end)
        end
    end)
    _G.__saTapTools = (_G.__saTapTools or 0) + 1
    dbg("tap fix B armed on", tool.Name)
end

local function saScanTools()
    local char = lp.Character
    if not char then return end
    for _, c in ipairs(char:GetChildren()) do saHookToolTap(c) end
end

if not _G.__saToolWatchBound then
    _G.__saToolWatchBound = true
    lp.CharacterAdded:Connect(function()
        task.wait(0.4)
        saScanTools()
    end)
    lp.ChildAdded:Connect(function(c)
        if c:IsA("Tool") then saHookToolTap(c) end
    end)
end
if lp.Character then saScanTools() end

-- ══════════════════════════════════════════════════════════════════
-- BOW SA REMOTE HOOK (patched: passes the target model to manipulation)
-- Installed ONCE; the wrapper dispatches through SA.BowShot so a
-- re-execute never stacks hooks or keeps a stale closure alive.
-- ══════════════════════════════════════════════════════════════════
local function saInstallBowHook()
    if _G.__saBowRemoteHooked then return true end
    task.spawn(function()
        if _G.__saBowRemoteHooked then return end
        local ok, err = pcall(function()
            local rs = game:GetService("ReplicatedStorage")
            local fust = rs:WaitForChild("Fust", 10)
            local remotes = fust and fust:WaitForChild("Remotes", 10)
            local shoot = remotes and remotes:WaitForChild("Shoot", 10)
            if not shoot then error("Shoot remote not found") end
            local hookFn = executorFn("hookfunction")
            if not hookFn then error("hookfunction unavailable") end
            local ncFn = executorFn("newcclosure")
            local wrap = ncFn or function(f) return f end
            local original = shoot.FireServer
            local origFS
            origFS = hookFn(original, wrap(function(self, data, ...)
                if self == shoot then
                    pcall(function() SA.BowShot(data) end)
                end
                return (origFS or original)(self, data, ...)
            end))
            _G.__saBowRemoteHooked = true
            print("[sa] bow Shoot remote hook active")
        end)
        if not ok then
            warn("[sa] bow remote hook unavailable: " .. tostring(err))
        end
    end)
    return false
end
SA.InstallBowHook = saInstallBowHook
saInstallBowHook()

-- ══════════════════════════════════════════════════════════════════
-- CAMERA-SNAP RENDER BINDS
-- These still handle held fire / automatic weapons and keep CanQuery
-- restoration tied to the frame. Tap-fire is covered by fixes A + B.
-- ══════════════════════════════════════════════════════════════════
-- State machine for the camera sandwich. `realCFrame` is the ORIGINAL
-- camera CFrame captured before the first snap of a hold sequence. The
-- restore bind (priority +4) owns restoration, so the snap bind must NOT
-- clear `snapped` / `realCFrame` at the top of every frame: doing that
-- (as the extract did) orphans a bow-hold snap and leaves the camera
-- permanently pointed at the target once the hold expires.
RunService:BindToRenderStep(snapName, snapPrio, function()
    saSnappedThisFrame = false
    if not SA.Alive then saManipRestore(); return end
    saManipBeginFrame()

    local isBow = SA.IsEquippedBow()
    if isBow then
        if saBowWasDrawing and not SA.BowDrawing then SA.BowSnapHold = 5 end
        saBowWasDrawing = SA.BowDrawing or false
    else
        saBowWasDrawing = false
    end

    if not saLockActive() then return end
    -- PATCH: a tap that landed inside this frame must still snap even if
    -- the button was released before the render step ran.
    local tappedThisFrame = (tick() - firing.last) < (1 / 30)
    if not isFiring() and not tappedThisFrame then return end
    if not gunCanSnap() then return end

    local shot = SA.ResolveShot()
    if not shot then return end
    local camPos = shot.camera.CFrame.Position
    if not realCFrame then realCFrame = shot.camera.CFrame end
    local ok = pcall(function()
        shot.camera.CFrame = CFrame.lookAt(shot.origin, shot.aim)
    end)
    if ok then snapped = true end
    saSnappedThisFrame = ok
    if ok then
        SA.Target.lastShot = shot.model
        SA.Target.lastShotAt = tick()
        dbg("snap ->", shot.model and shot.model.Name or "?",
            shot.origin == camPos and "" or "[manip]")
    end
end)

RunService:BindToRenderStep(restoreName, restorePrio, function()
    if not SA.Alive then
        if snapped and realCFrame then
            local camera = ws.CurrentCamera
            if camera then pcall(function() camera.CFrame = realCFrame end) end
        end
        snapped, realCFrame = false, nil
        saManipRestore()
        return
    end
    -- Hold the bow snap while drawing and for a few frames after release,
    -- otherwise the arrow inherits the restored (unsnapped) camera.
    if snapped and SA.IsEquippedBow()
        and (SA.BowDrawing or (SA.BowSnapHold or 0) > 0) then
        if (SA.BowSnapHold or 0) > 0 then SA.BowSnapHold = SA.BowSnapHold - 1 end
        saManipRestore()
        return
    end
    if snapped and realCFrame then
        local camera = ws.CurrentCamera
        if camera then pcall(function() camera.CFrame = realCFrame end) end
    end
    snapped, realCFrame = false, nil
    saManipRestore()
end)

function SA.SilentAimState()
    return {
        lock = saLockActive(),
        reorder = tapInfo.active, reorderReason = tapInfo.reason,
        reorderedConnections = tapInfo.connections,
        hookedTools = _G.__saTapTools or 0,
        bowRemoteHooked = _G.__saBowRemoteHooked == true,
        bowDrawing = SA.BowDrawing, bowHold = SA.BowSnapHold or 0,
        tapWindow = CFG.saTapWindow or 0.35,
        snapped = snapped, snappedThisFrame = saSnappedThisFrame,
        snapBind = snapName, restoreBind = restoreName,
        snapPriority = snapPrio, restorePriority = restorePrio,
    }
end
