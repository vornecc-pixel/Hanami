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
--   GUNS ONLY (camera-snap resolver): whenever a bow is equipped THIS
--          resolver skips camera snap, shot resolution and manipulation.
--          Ballistic Fust bow shots use the separate hook in 09_z_fust_bow.lua.
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
-- _G, so the InputBegan/Tool hooks installed once by an older run always
-- call into the CURRENT chunk instead of stale closures.
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

-- ────────────────────────────────────────────────────────────────────
-- RE-EXECUTION PURGE — retired bow-aim entry points
-- SA persists in _G (01_config.lua), so a much older Hanami run can leave
-- a Shoot remote wrapper that calls SA.BowShot(data). Neutralise those
-- retired entry points. The CURRENT bow hook lives in 09_z_fust_bow.lua:
-- its own hookfunction wrapper is generation-guarded and restored by
-- SA.FustBowDispose(), so it is deliberately not touched here.
-- ────────────────────────────────────────────────────────────────────
function SA.BowShot(data) return data end
function SA.InstallBowHook() return false end
SA.BowGravity = nil
SA.BOW_MUZZLE = nil
SA.BowDrawing, SA.BowDrawingAt, SA.BowSnapHold = nil, nil, nil
_G.__saBowRemoteHooked = nil

local tapInfo = _G.__saTapReorderInfo or {
    active = false, connections = 0, reason = "not attempted",
}
_G.__saTapReorderInfo = tapInfo

-- ── shared bind names (render step / full unload reference these) ───
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

-- The extract used `flags["sa_lock"]`; Hanami's master switch is CFG.
-- SA.Alive also stops the tap hooks after "Unload Everything".
-- saLockActive() is the SINGLE guns-only gate: ResolveShot, TapSnap and the
-- render-step snap all go through it, so a bow can never be aimed.
local function saLockActive()
    if SA.Alive ~= true or CFG.masterEnabled ~= true or CFG.gunEnabled ~= true then
        return false
    end
    if type(SA.IsEquippedBow) ~= "function" then return true end
    return SA.IsEquippedBow() ~= true
end

-- ────────────────────────────────────────────────────────────────────
-- TARGET RESOLUTION — one path for tap snap and render step (guns only)
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
    return cf, camera
end

function SA.TapRestore(cf, camera)
    if cf and camera then pcall(function() camera.CFrame = cf end) end
    if cf and _G.__saTapCF == cf then
        _G.__saTapCF, _G.__saTapCam, _G.__saTapAt = nil, nil, nil
    end
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
    else
        tapInfo.active = false
        tapInfo.reason = "unavailable: " .. tostring(err)
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
    -- Gun tap-fire Fix B is guns only; the Fust bow hook is separate.
    if type(SA.IsBowTool) == "function" and SA.IsBowTool(tool) then return end
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
-- CAMERA-SNAP RENDER BINDS
-- These still handle held fire / automatic weapons and keep CanQuery
-- restoration tied to the frame. Tap-fire is covered by fixes A + B.
-- ══════════════════════════════════════════════════════════════════
-- State machine for the camera sandwich. `realCFrame` is the ORIGINAL
-- camera CFrame captured before the first snap of a hold sequence. The
-- restore bind (priority +4) owns restoration, so the snap bind must NOT
-- clear `snapped` / `realCFrame` at the top of every frame: doing that
-- (as the extract did) orphans a snap and leaves the camera permanently
-- pointed at the target once the hold expires.
RunService:BindToRenderStep(snapName, snapPrio, function()
    saSnappedThisFrame = false
    if not SA.Alive then saManipRestore(); return end
    saManipBeginFrame()

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
        gunsOnly = true,
        bowEquipped = SA.IsEquippedBow() == true,
        tapWindow = CFG.saTapWindow or 0.35,
        forceHead = CFG.forceHead == true,
        resolvedBone = SA.ResolveTargetBone and SA.ResolveTargetBone()
            or CFG.targetBone,
        snapped = snapped, snappedThisFrame = saSnappedThisFrame,
        snapBind = snapName, restoreBind = restoreName,
        snapPriority = snapPrio, restorePriority = restorePrio,
    }
end

-- ══════════════════════════════════════════════════════════════════
-- TRIGGERBOT / AUTO FIRE (guns only, both OFF by default)
-- Triggerbot needs a valid FOV target and can pick Head / a random hit
-- part / a specific part. Auto Fire clicks continuously with no target
-- requirement unless the dedicated fire-assist wall check is ON. Both are
-- INDEPENDENT of the silent-aim master/gun toggles; only SA.Alive and the
-- guns-only bow gate apply. Tool:Activate() is tried first, with executor
-- mouse input as the fallback. The read-only manipulation probe gates
-- shots when Manipulation Support is ON but cannot bypass the wall check.
-- ══════════════════════════════════════════════════════════════════
if SA.DisposeFireAssist then pcall(SA.DisposeFireAssist) end
local saFireAssist = _G.__saFireAssist or {
    last = 0, shots = 0, reason = "idle", backend = "none",
    target = nil, part = nil, visible = false, conn = nil,
}
_G.__saFireAssist = saFireAssist

function SA.DisposeFireAssist()
    if saFireAssist.conn then pcall(function() saFireAssist.conn:Disconnect() end) end
    saFireAssist.conn = nil
    saFireAssist.reason = "disposed"
    saFireAssist.backend = "none"
    saFireAssist.target, saFireAssist.part = nil, nil
    saFireAssist.visible = false
end

function SA.FireOnce()
    -- Tool:Activate() first, with executor mouse input as the fallback.
    -- The VIS FOV bugfix is preserved by the tolerant LOS target picker,
    -- silent-aim independence and read-only manipulation probe above.
    local tool = nil
    pcall(function() tool = SA.GetEquippedGun().tool end)
    if tool then
        local okTool = pcall(function() tool:Activate() end)
        if okTool then return true, "tool" end
    end
    local click = executorFn("mouse1click")
    if click then
        local okClick = pcall(click)
        if okClick then return true, "mouse1click" end
    end
    local press = executorFn("mouse1press")
    local release = executorFn("mouse1release")
    if press and release then
        local okPress = pcall(press)
        if okPress then
            pcall(release)
            return true, "mouse"
        end
    end
    return false, "no fire backend"
end

function SA.FireAssistTick(force)
    if not SA.Alive then
        saFireAssist.reason = "unloaded"
        return false
    end
    if CFG.triggerbot ~= true and CFG.autoFire ~= true then
        saFireAssist.reason = "disabled"
        return false
    end
    -- Fire assist must NOT require the silent-aim master / gun toggles.
    -- A visible player in FOV should trigger it even with silent aim OFF.
    if type(SA.IsEquippedBow) == "function" and SA.IsEquippedBow() then
        saFireAssist.reason = "bow equipped (guns only)"
        return false
    end
    local now = tick()
    if not force and now - (saFireAssist.last or 0) < 0.08 then return false end
    saFireAssist.last = now
    saFireAssist.target, saFireAssist.part = nil, nil
    local camera = ws.CurrentCamera
    if not camera then
        saFireAssist.reason = "no camera"
        return false
    end
    local origin = camera.CFrame.Position
    local triggerOn = CFG.triggerbot == true
    local autoOn = CFG.autoFire == true
    local wallOn = CFG.fireWallCheck == true
    -- Auto Fire wins when BOTH are ON (continuous / no-target), except the
    -- dedicated wall check can force a VIS target gate. Triggerbot alone
    -- always needs a FOV target.
    local autoMode = autoOn
    local needTarget = (triggerOn and not autoMode) or (autoMode and wallOn)
    local target = needTarget and SA.TriggerTarget() or nil
    if needTarget and not target then
        if autoMode and wallOn then
            saFireAssist.reason = "no VIS target in FOV (auto fire wall check)"
        elseif wallOn then
            saFireAssist.reason = "no VIS trigger target in FOV"
        else
            saFireAssist.reason = "no trigger target in FOV"
        end
        saFireAssist.visible = false
        return false
    end
    saFireAssist.visible = target and target.visible ~= false or false
    -- Auto Fire keeps firing straight ahead: the wall check only GATES the
    -- click, it never adds a camera snap / aim point.
    local aim = (target and not autoMode) and target.pos or nil
    if aim and target and CFG.prediction and type(SA.Predict) == "function" then
        local okPred, predicted = pcall(SA.Predict, origin, aim, target.model)
        if okPred and predicted then aim = predicted end
    end
    if CFG.triggerUseManip == true then
        if CFG.manipulation ~= true then
            saFireAssist.reason = "manipulation OFF (support enabled)"
            return false
        end
        -- allowNoAim = true: the manipulation line check stays, but the
        -- fire assist does not inherit silent aim's master/gun gate.
        local okProbe, possible, why = pcall(SA.ManipPossible,
            target and target.model or nil, true)
        if not okProbe or not possible then
            saFireAssist.reason = "manip blocked: " .. tostring(why or "probe error")
            return false
        end
    end
    if not gunCanSnap() then
        saFireAssist.reason = "gun cooldown"
        return false
    end
    local original = camera.CFrame
    if aim then
        pcall(function() camera.CFrame = CFrame.lookAt(origin, aim) end)
    end
    -- Keep the v7.7 render-step snap alive for the frame that receives the
    -- synthetic click; isFiring() uses this same timestamp.
    firing.last = tick()
    local fired, backend = SA.FireOnce()
    if aim then pcall(function() camera.CFrame = original end) end
    saFireAssist.backend = backend or "unknown"
    if fired then
        saFireAssist.shots = (saFireAssist.shots or 0) + 1
        saFireAssist.target = target and target.name or nil
        saFireAssist.part = target and target.part or nil
        saFireAssist.visible = target and target.visible ~= false or false
        saFireAssist.reason = "fired via " .. tostring(backend)
        return true
    end
    saFireAssist.reason = tostring(backend or "fire failed")
    return false
end

function SA.FireAssistState()
    return {
        triggerbot = CFG.triggerbot == true,
        autoFire = CFG.autoFire == true,
        headOnly = CFG.triggerHeadOnly == true,
        randomPart = CFG.triggerRandomPart == true,
        part = CFG.triggerPart,
        manipSupport = CFG.triggerUseManip == true,
        wallCheck = CFG.fireWallCheck == true,
        autoFireGated = CFG.autoFire == true and CFG.fireWallCheck == true,
        forceHead = CFG.forceHead == true,
        resolvedAimBone = SA.ResolveTargetBone and SA.ResolveTargetBone()
            or CFG.targetBone,
        shots = saFireAssist.shots or 0,
        reason = saFireAssist.reason,
        backend = saFireAssist.backend,
        silentAimIndependent = true,
        visible = saFireAssist.visible == true,
        target = saFireAssist.target,
        partUsed = saFireAssist.part,
        last = saFireAssist.last or 0,
    }
end


saFireAssist.conn = bindRender(function() SA.FireAssistTick(false) end)
