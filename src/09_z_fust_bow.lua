-- ==================================================================
-- Hanami / 09_z_fust_bow.lua — Fust bow ballistic silent aim + peek-origin
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- FUST BOW — one hookfunction on Fust Remotes.Shoot.FireServer.
--
-- Guns keep the v7.7 camera-snap / tap-fire resolver and are untouched.
-- This part only intercepts a Shoot remote call when a Fust bow is held,
-- solves a gravity-compensated intercept for the arrow velocity argument,
-- and (when Manipulation is ON) walks an 8-direction peek from the camera
-- to find a clear origin behind cover. The origin argument is rewritten to
-- that peek position only when a matching near-camera Vector3 arg exists.
--
-- Default OFF, reversible, silent: no print / warn / debug output. The
-- remote is resolved with FindFirstChild + a short WaitForChild timeout,
-- so a non-Fust game simply leaves remotesReady = false. FullUnload and a
-- loader re-execute restore the original FireServer through hookfunction.
-- ────────────────────────────────────────────────────────────────────

if SA.FustBowDispose then pcall(SA.FustBowDispose) end
local fb = _G.__saFustBow or {
    hooked = false, remotesReady = false, reason = "idle",
    shots = 0, rewrites = 0, peeks = 0, errors = 0,
    generation = 0, oldFireServer = nil, newFireServer = nil, shoot = nil,
    lastBow = nil, lastSpeed = 0, lastGravity = 0, lastPeek = 0,
    lastReason = "idle",
}
_G.__saFustBow = fb
fb.generation = SA.Generation or 0

-- Fust.Items bow specs. The fust_* aliases let a mock / saved profile use
-- an ItemId that does not trip SA.IsBowTool()'s name-based bow gate.
fb.bows = {
    hunting_bow  = { maxSpeed = 220, gravity = 50, drawTime = 0.8,
                     chargeMin = 0.15 },
    compound_bow = { maxSpeed = 290, gravity = 40, drawTime = 1.1,
                     chargeMin = 0.15 },
    crossbow     = { maxSpeed = 320, gravity = 28, drawTime = 0,
                     chargeMin = 0, fullCharge = true },
    fust_hunting  = { maxSpeed = 220, gravity = 50, drawTime = 0.8,
                      chargeMin = 0.15 },
    fust_compound = { maxSpeed = 290, gravity = 40, drawTime = 1.1,
                      chargeMin = 0.15 },
    fust_crossbow = { maxSpeed = 320, gravity = 28, drawTime = 0,
                      chargeMin = 0, fullCharge = true },
}
fb.arrowLife = 4.5

fb.alive = function(plr)
    local h = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
    if not h or h.Health <= 0 then return false end
    if plr.Team and lp.Team and plr.Team == lp.Team then return false end
    return true
end

fb.hasLOS = function(origin, pos, ignore)
    local p = SA.MarkInternalRayParams(RaycastParams.new())
    p.FilterType = Enum.RaycastFilterType.Exclude
    p.FilterDescendantsInstances = { lp.Character, ignore, Workspace.Terrain }
    return Workspace:Raycast(origin, pos - origin, p) == nil
end

fb.getTarget = function(origin, requireLOS)
    local best, bestScore, center = nil, math.huge,
        Vector2.new(ws.CurrentCamera.ViewportSize.X * 0.5,
                    ws.CurrentCamera.ViewportSize.Y * 0.5)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= lp and fb.alive(plr) then
            local part = plr.Character:FindFirstChild(CFG.fustBowTargetPart)
            if part then
                local sp, on = ws.CurrentCamera:WorldToViewportPoint(part.Position)
                if on then
                    local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                    if d < CFG.fustBowFov
                        and (not requireLOS or fb.hasLOS(origin, part.Position, plr.Character)) then
                        if d < bestScore then bestScore, best = d, plr end
                    end
                end
            end
        end
    end
    return best
end

fb.targetState = function(plr)
    local c = plr.Character
    if not c then return nil end
    local part = c:FindFirstChild(CFG.fustBowTargetPart)
    local root = c:FindFirstChild("HumanoidRootPart")
    if not part or not root then return nil end
    return part.Position, root.AssemblyLinearVelocity
end

fb.getEquippedBow = function()
    local c = lp.Character
    if not c then return nil end
    for _, tool in ipairs(c:GetChildren()) do
        if tool:IsA("Tool") then
            local id = tool:GetAttribute("ItemId")
            if id and fb.bows[id] then return id, fb.bows[id] end
        end
    end
    return nil
end

fb.findPeek = function(origin, targetPos, targetModel, maxPeek)
    local wallFilter = { lp.Character }
    if targetModel then table.insert(wallFilter, targetModel) end
    local wp = SA.MarkInternalRayParams(RaycastParams.new())
    wp.FilterType = Enum.RaycastFilterType.Exclude
    wp.FilterDescendantsInstances = wallFilter
    wp.IgnoreWater = true
    local wallHit = Workspace:Raycast(origin, targetPos - origin, wp)
    if not wallHit then return origin, 0 end

    local normal = wallHit.Normal
    local right = normal:Cross(Vector3.new(0, 1, 0))
    if right.Magnitude < 0.01 then
        right = CFrame.lookAt(origin, targetPos).RightVector
    end
    right = right.Unit
    local wallUp = normal:Cross(right).Unit
    local dirs = {
        right, -right, wallUp, -wallUp,
        (right + wallUp).Unit, (right - wallUp).Unit,
        (-right + wallUp).Unit, (-right - wallUp).Unit,
    }

    local losFilter = { lp.Character }
    if targetModel then table.insert(losFilter, targetModel) end
    local losParams = SA.MarkInternalRayParams(RaycastParams.new())
    losParams.FilterType = Enum.RaycastFilterType.Exclude
    losParams.FilterDescendantsInstances = losFilter
    losParams.IgnoreWater = true

    local bestPeek, bestDist = nil, math.huge
    for _, dir in ipairs(dirs) do
        for step = 1, math.floor(maxPeek / 0.5) do
            local peekPos = origin + dir * (step * 0.5)
            if Workspace:Raycast(peekPos, targetPos - peekPos, losParams) == nil then
                local d = (peekPos - origin).Magnitude
                if d < bestDist then bestDist, bestPeek = d, peekPos end
                break
            end
        end
    end
    return bestPeek or origin, bestPeek and bestDist or 0
end

fb.solveAim = function(origin, targetPos, targetVel, speed, gravity)
    local aimPos, theta = targetPos, 0
    for _ = 1, 6 do
        local d = aimPos - origin
        local dh = Vector3.new(d.X, 0, d.Z).Magnitude
        local dy = d.Y
        if dh < 0.001 then
            return Vector3.new(0, dy > 0 and 1 or -1, 0)
        end
        local v2 = speed * speed
        local disc = v2 * v2 - gravity * (gravity * dh * dh + 2 * dy * v2)
        if disc < 0 then return nil end
        local root = math.sqrt(disc)
        theta = math.atan((v2 - root) / (gravity * dh))
        local t = dh / (speed * math.cos(theta))
        if t > fb.arrowLife then return nil end
        aimPos = targetPos + targetVel * t
    end
    local d = aimPos - origin
    return Vector3.new(d.X, 0, d.Z).Unit * math.cos(theta)
        + Vector3.new(0, math.sin(theta), 0)
end

fb.isVel = function(v)
    return typeof(v) == "Vector3" and v.Magnitude > 20 and v.Magnitude < 600
end

fb.findVelArg = function(args)
    for i = 1, args.n do
        local v = args[i]
        if typeof(v) == "Vector3" and fb.isVel(v) then return { i } end
        if type(v) == "table" then
            for k, vv in pairs(v) do
                if typeof(vv) == "Vector3" and fb.isVel(vv) then
                    return { i, k }
                end
            end
        end
    end
    return nil
end

fb.findOriginArg = function(args, camPos)
    local r = CFG.fustBowOriginRadius
    for i = 1, args.n do
        local v = args[i]
        if typeof(v) == "Vector3" and (v - camPos).Magnitude < r then
            return { i }
        end
        if type(v) == "table" then
            for k, vv in pairs(v) do
                if typeof(vv) == "Vector3" and (vv - camPos).Magnitude < r then
                    return { i, k }
                end
            end
        end
    end
    return nil
end

fb.getAt = function(args, slot)
    if #slot == 1 then return args[slot[1]] end
    return args[slot[1]][slot[2]]
end

fb.setAt = function(args, slot, val)
    if #slot == 1 then args[slot[1]] = val
    else args[slot[1]][slot[2]] = val end
end

fb.intercept = function(args, camPos)
    local velSlot = fb.findVelArg(args)
    if not velSlot then return end
    local speed = fb.getAt(args, velSlot).Magnitude
    local bowId, bow = fb.getEquippedBow()
    if not bow then return end
    local gravity = bow.gravity or 50
    local tgt = fb.getTarget(camPos, not CFG.fustBowManipulation)
    if not tgt then return end
    local targetPos, targetVel = fb.targetState(tgt)
    if not targetPos or not targetVel then return end

    local aimFrom, peekUsed, peekDist = camPos, false, 0
    if CFG.fustBowManipulation then
        local dist = (targetPos - camPos).Magnitude
        if dist <= CFG.fustBowManipMaxDist then
            local peek, pd = fb.findPeek(camPos, targetPos, tgt.Character,
                                         CFG.fustBowManipPeek)
            if peek and pd > 0.01 then
                aimFrom, peekUsed, peekDist = peek, true, pd
            end
        end
    end

    local dir = fb.solveAim(aimFrom, targetPos, targetVel, speed, gravity)
    if not dir then return end
    fb.setAt(args, velSlot, dir * speed)
    fb.rewrites = fb.rewrites + 1

    if peekUsed then
        local originSlot = fb.findOriginArg(args, camPos)
        if originSlot then
            fb.setAt(args, originSlot, aimFrom)
            fb.peeks = fb.peeks + 1
        else
            peekUsed = false
        end
    end

    fb.lastBow = bowId
    fb.lastSpeed = speed
    fb.lastGravity = gravity
    fb.lastPeek = peekUsed and peekDist or 0
    fb.lastReason = peekUsed and "velocity + peek origin" or "velocity"
end

fb.install = function()
    if fb.hooked then return true end
    if type(hookfunction) ~= "function" then
        fb.reason = "hookfunction unavailable"
        return false
    end
    local RS = game:GetService("ReplicatedStorage")
    local fust = RS:FindFirstChild("Fust") or RS:WaitForChild("Fust", 2)
    local remotes = fust and (fust:FindFirstChild("Remotes")
        or fust:WaitForChild("Remotes", 2))
    local shoot = remotes and (remotes:FindFirstChild("Shoot")
        or remotes:WaitForChild("Shoot", 2))
    if not shoot or type(shoot.FireServer) ~= "function" then
        fb.remotesReady = false
        fb.reason = "Fust Shoot remote unavailable"
        return false
    end
    fb.remotesReady = true
    local old = shoot.FireServer
    local thisGen = fb.generation
    -- hookfunction(old, hook) returns a callable copy of the ORIGINAL
    -- implementation in real executors; fallback to `old` keeps the
    -- Fengari mock (which returns its first argument) equally valid.
    local passThrough = old
    local function newFireServer(self, ...)
        local camPos = ws.CurrentCamera.CFrame.Position
        local args = table.pack(...)
        fb.shots = fb.shots + 1
        if CFG.fustBowEnabled == true and SA.Alive
            and SA.Generation == thisGen then
            local ok = pcall(fb.intercept, args, camPos)
            if not ok then fb.errors = fb.errors + 1 end
        end
        return passThrough(self, table.unpack(args, 1, args.n))
    end
    local okHook, original = pcall(hookfunction, old, newFireServer)
    if not okHook or type(original) ~= "function" then
        fb.reason = "hookfunction failed"
        return false
    end
    passThrough = original
    fb.oldFireServer = old
    fb.originalFireServer = original
    fb.newFireServer = newFireServer
    fb.shoot = shoot
    fb.hooked = true
    fb.reason = "active"
    return true
end

function SA.FustBowState()
    return {
        enabled = CFG.fustBowEnabled == true,
        hooked = fb.hooked == true,
        remotesReady = fb.remotesReady == true,
        method = "hookfunction on Shoot.FireServer",
        scope = "Fust bows only (players)",
        targetPart = CFG.fustBowTargetPart,
        fov = CFG.fustBowFov,
        manipulation = CFG.fustBowManipulation == true,
        peek = CFG.fustBowManipPeek,
        maxDist = CFG.fustBowManipMaxDist,
        originRadius = CFG.fustBowOriginRadius,
        bows = 6,
        arrowLife = fb.arrowLife,
        shots = fb.shots,
        rewrites = fb.rewrites,
        peeks = fb.peeks,
        errors = fb.errors,
        lastBow = fb.lastBow,
        lastSpeed = fb.lastSpeed,
        lastGravity = fb.lastGravity,
        lastPeek = fb.lastPeek,
        lastReason = fb.lastReason,
        reason = fb.reason,
        generation = fb.generation,
    }
end

function SA.FustBowDispose()
    if fb.hooked and fb.shoot and fb.newFireServer and fb.oldFireServer then
        -- Restore the unhooked callable original; pcall-wrapped because
        -- hook signatures differ between executors and the Fengari mock.
        pcall(function()
            hookfunction(fb.newFireServer, fb.originalFireServer or fb.oldFireServer)
        end)
        pcall(function() fb.shoot.FireServer = fb.oldFireServer end)
    end
    fb.hooked = false
    fb.remotesReady = false
    fb.oldFireServer, fb.originalFireServer = nil, nil
    fb.newFireServer, fb.shoot = nil, nil
    fb.reason = "disposed"
    fb.lastReason = "disposed"
    return SA.FustBowState()
end

function SA.FustBowRefresh()
    SA.FustBowDispose()
    fb.install()
    return SA.FustBowState()
end

SA.FustBowRestore = SA.FustBowRefresh

-- Install once at load; a saved ON profile becomes active immediately,
-- while default OFF simply records why the intercept is idle.
SA.FustBowRefresh()
