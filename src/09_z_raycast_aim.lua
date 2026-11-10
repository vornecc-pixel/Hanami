-- ==================================================================
-- Hanami / 09_z_raycast_aim.lua — SECOND silent aim version (raycast hook)
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- RAYCAST SILENT AIM — a separate, independent silent-aim version.
--
-- Hooks workspace.Raycast and workspace.Spherecast with hookfunction.
-- Bullet raycasts are detected by signature (long direction, a real
-- RaycastParams, and a filter holding one Humanoid Model per player),
-- then redirected toward the nearest valid target inside the FOV cone.
--
-- Two modes:
--   true       single-pass redirect; the game's collision filter still
--              applies, so walls block the shot.
--   aggressive two-pass redirect; the second pass uses an Include-only-
--              players filter. A target hit from that pass is returned,
--              so the redirected shot passes through walls (wallbang).
--
-- This is deliberately separate from 09_silent_aim.lua (camera-snap gun
-- resolver) and 09_z_fust_bow.lua (Shoot.FireServer bow hook). Default
-- OFF, generation-guarded, silent, and restored by FullUnload / re-execute.
-- ────────────────────────────────────────────────────────────────────

if SA.RaycastAimDispose then pcall(SA.RaycastAimDispose) end
local ra = _G.__saRaycastAim or {
    hooked = false, reason = "idle", generation = 0,
    oldRaycast = nil, oldSpherecast = nil, originals = nil,
    passRay = nil, passSphere = nil,
    rayWrapped = nil, sphereWrapped = nil,
    redirects = 0, wallbangs = 0, bulletRays = 0, errors = 0,
    lastTargetPart = nil, lastMode = nil, lastReason = "idle",
}
_G.__saRaycastAim = ra
ra.generation = SA.Generation or 0

ra.keys = {
    Enabled = "raycastAimEnabled", Aggressive = "raycastAimAggressive",
    TargetPart = "raycastAimTargetPart", FOV = "raycastAimFov",
    MIN_RAY_MAG = "raycastAimMinRayMag", CHAR_COUNT = "raycastAimCharCount",
}
ra.newCC = (type(newcclosure) == "function") and newcclosure
    or function(f) return f end
ra.hookFn = (type(hookfunction) == "function") and hookfunction
    or (type(replaceclosure) == "function") and replaceclosure
    or (type(hookfunc) == "function") and hookfunc
    or nil
ra.clamp = math.clamp or function(v, lo, hi)
    return math.max(lo, math.min(hi, v))
end

-- ── detection ───────────────────────────────────────────────────────
-- Fust's bullet params exclude every player character, so the filter
-- holds one Humanoid Model per player. A floor of the live player count
-- keeps ESP / manipulation / LOS probes (which filter only 1–2 rigs)
-- from being mistaken for bullets. CFG.raycastAimCharCount can tighten it.
ra.isBulletRaycast = function(origin, direction, params)
    if typeof(direction) ~= "Vector3" then return false end
    if direction.Magnitude < CFG.raycastAimMinRayMag then return false end
    if typeof(params) ~= "RaycastParams" then return false end
    local filter = params.FilterDescendantsInstances
    if type(filter) ~= "table" then return false end
    local minChars = CFG.raycastAimCharCount
    local playerCount = #Players:GetPlayers()
    if playerCount > minChars then minChars = playerCount end
    local chars = 0
    for _, v in ipairs(filter) do
        if typeof(v) == "Instance" and v:IsA("Model")
            and v:FindFirstChildOfClass("Humanoid") then
            chars = chars + 1
            if chars >= minChars then return true end
        end
    end
    return false
end

-- ── target selection ────────────────────────────────────────────────
ra.getTargetPart = function(character)
    if not character then return nil end
    return character:FindFirstChild(CFG.raycastAimTargetPart)
        or character:FindFirstChild("HumanoidRootPart")
        or character:FindFirstChild("Head")
end

ra.getClosestTarget = function(origin)
    local cam = ws.CurrentCamera
    if not cam then return nil end
    local camDir = cam.CFrame.LookVector
    local cosHalfFov = math.cos(math.rad(CFG.raycastAimFov) * 0.5)
    -- cos(pi/2) is a tiny positive float, not exactly 0; a 180-degree FOV
    -- must still accept targets at exactly 90 degrees from the camera.
    local cosGate = cosHalfFov - 1e-6
    local best, bestAngle = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= lp and plr.Character then
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local part = ra.getTargetPart(plr.Character)
                if part then
                    local dir = part.Position - origin
                    local mag = dir.Magnitude
                    if mag > 0.1 then
                        local unit = dir / mag
                        local dot = camDir:Dot(unit)
                        if dot >= cosGate then
                            local angle = math.acos(ra.clamp(dot, -1, 1))
                            if angle < bestAngle then
                                best, bestAngle = part.Position, angle
                            end
                        end
                    end
                end
            end
        end
    end
    return best
end

-- ── aggressive helper: Include-only-players params ──────────────────
ra.buildTargetOnlyParams = function()
    local chars = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= lp and plr.Character then
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                chars[#chars + 1] = plr.Character
            end
        end
    end
    local p = RaycastParams.new()
    p.FilterType = Enum.RaycastFilterType.Include
    p.FilterDescendantsInstances = chars
    p.IgnoreWater = true
    return p
end

-- ── true silent aim — single-pass redirect ──────────────────────────
ra.trueRedirect = function(origin, newDir, params, isSphere, radius)
    if isSphere then
        return ra.passSphere(workspace, origin, radius, newDir, params)
    end
    return ra.passRay(workspace, origin, newDir, params)
end

-- ── aggressive silent aim — two-pass wallbang ───────────────────────
-- Pass 1 uses the game's own params (what the server expects). Pass 2
-- uses an Include-only-players filter, which ignores walls. A pass-2
-- player hit wins; otherwise the normal hit is returned unchanged.
ra.aggressiveRedirect = function(origin, newDir, params, isSphere, radius)
    local normalHit, targetHit
    if isSphere then
        normalHit = ra.passSphere(workspace, origin, radius, newDir, params)
        targetHit = ra.passSphere(workspace, origin, radius, newDir,
                                  ra.buildTargetOnlyParams())
    else
        normalHit = ra.passRay(workspace, origin, newDir, params)
        targetHit = ra.passRay(workspace, origin, newDir,
                               ra.buildTargetOnlyParams())
    end
    if targetHit then
        ra.wallbangs = ra.wallbangs + 1
        return targetHit
    end
    return normalHit
end

ra.redirect = function(origin, newDir, params, isSphere, radius)
    if CFG.raycastAimAggressive == true then
        return ra.aggressiveRedirect(origin, newDir, params, isSphere, radius)
    end
    return ra.trueRedirect(origin, newDir, params, isSphere, radius)
end

-- ── hooked entrypoints ──────────────────────────────────────────────
ra.rayWrapped = function(self, origin, direction, params)
    -- Accept both workspace:Raycast(...) and workspace.Raycast(...).
    if self ~= workspace then
        params = direction
        direction = origin
        origin = self
    end
    if CFG.raycastAimEnabled == true and SA.Alive
        and SA.Generation == ra.generation then
        local ok, bullet = pcall(ra.isBulletRaycast, origin, direction, params)
        if not ok then
            ra.errors = ra.errors + 1
        elseif bullet then
            ra.bulletRays = ra.bulletRays + 1
            local targetPoint = ra.getClosestTarget(origin)
            if targetPoint then
                local newDir = targetPoint - origin
                if newDir.Magnitude > 0.1 then
                    ra.redirects = ra.redirects + 1
                    ra.lastTargetPart = CFG.raycastAimTargetPart
                    ra.lastMode = CFG.raycastAimAggressive and "aggressive" or "true"
                    ra.lastReason = "redirected"
                    return ra.redirect(origin, newDir, params, false, nil)
                end
            end
        end
    end
    return ra.passRay(workspace, origin, direction, params)
end

ra.sphereWrapped = function(self, origin, radius, direction, params)
    if self ~= workspace then
        params = direction
        direction = radius
        radius = origin
        origin = self
    end
    if CFG.raycastAimEnabled == true and SA.Alive
        and SA.Generation == ra.generation then
        local ok, bullet = pcall(ra.isBulletRaycast, origin, direction, params)
        if not ok then
            ra.errors = ra.errors + 1
        elseif bullet then
            ra.bulletRays = ra.bulletRays + 1
            local targetPoint = ra.getClosestTarget(origin)
            if targetPoint then
                local newDir = targetPoint - origin
                if newDir.Magnitude > 0.1 then
                    ra.redirects = ra.redirects + 1
                    ra.lastTargetPart = CFG.raycastAimTargetPart
                    ra.lastMode = CFG.raycastAimAggressive and "aggressive" or "true"
                    ra.lastReason = "redirected"
                    return ra.redirect(origin, newDir, params, true, radius)
                end
            end
        end
    end
    return ra.passSphere(workspace, origin, radius, direction, params)
end

ra.install = function()
    if ra.hooked then return true end
    if type(ra.hookFn) ~= "function" then
        ra.reason = "hookfunction unavailable"
        return false
    end
    local oldR, oldS = workspace.Raycast, workspace.Spherecast
    if type(oldR) ~= "function" or type(oldS) ~= "function" then
        ra.reason = "workspace raycast methods unavailable"
        return false
    end
    ra.oldRaycast, ra.oldSpherecast = oldR, oldS
    ra.passRay, ra.passSphere = oldR, oldS
    local okR, origR = pcall(ra.hookFn, oldR, ra.newCC(ra.rayWrapped))
    local okS, origS = pcall(ra.hookFn, oldS, ra.newCC(ra.sphereWrapped))
    if not okR or not okS then
        -- Best-effort rollback: hook implementations differ, so both the
        -- raw method assignment and hookfunction restore are pcall-guarded.
        pcall(function() workspace.Raycast = oldR end)
        pcall(function() workspace.Spherecast = oldS end)
        pcall(function() ra.hookFn(oldR, oldR) end)
        pcall(function() ra.hookFn(oldS, oldS) end)
        ra.passRay, ra.passSphere = nil, nil
        ra.reason = "hookfunction failed"
        return false
    end
    -- Real executors return a callable copy of the ORIGINAL function;
    -- use it for the unhooked pass-through. The mock returns oldR/oldS.
    if type(origR) == "function" then ra.passRay = origR end
    if type(origS) == "function" then ra.passSphere = origS end
    ra.originals = {
        raycast = type(origR) == "function" and origR or oldR,
        spherecast = type(origS) == "function" and origS or oldS,
    }
    ra.hooked = true
    ra.reason = "active"
    return true
end

-- ── control surface ─────────────────────────────────────────────────
-- Mirrors the standalone module's SilentAim.Enabled / .Aggressive /
-- .FOV / .TargetPart / .MIN_RAY_MAG / .CHAR_COUNT fields, backed by CFG.
SA.RaycastAim = setmetatable({}, {
    __index = function(_, k)
        local key = ra.keys[k]
        if key then return CFG[key] end
        return nil
    end,
    __newindex = function(_, k, v)
        local key = ra.keys[k]
        if key then CFG[key] = v end
    end,
})

function SA.RaycastAimState()
    return {
        enabled = CFG.raycastAimEnabled == true,
        aggressive = CFG.raycastAimAggressive == true,
        mode = CFG.raycastAimAggressive and "aggressive" or "true",
        fov = CFG.raycastAimFov,
        targetPart = CFG.raycastAimTargetPart,
        minRayMag = CFG.raycastAimMinRayMag,
        charCount = CFG.raycastAimCharCount,
        method = "hookfunction on workspace.Raycast + Spherecast",
        hooked = ra.hooked == true,
        reason = ra.reason,
        generation = ra.generation,
        redirects = ra.redirects,
        wallbangs = ra.wallbangs,
        bulletRays = ra.bulletRays,
        errors = ra.errors,
        lastTargetPart = ra.lastTargetPart,
        lastMode = ra.lastMode,
        lastReason = ra.lastReason,
    }
end

function SA.RaycastAimDispose()
    if ra.hooked and ra.originals then
        pcall(function()
            ra.hookFn(ra.oldRaycast, ra.originals.raycast)
            ra.hookFn(ra.oldSpherecast, ra.originals.spherecast)
        end)
        pcall(function()
            workspace.Raycast = ra.oldRaycast
            workspace.Spherecast = ra.oldSpherecast
        end)
    end
    ra.hooked = false
    ra.passRay, ra.passSphere = nil, nil
    ra.originals = nil
    ra.reason = "disposed"
    ra.lastReason = "disposed"
    return SA.RaycastAimState()
end

function SA.RaycastAimRefresh()
    SA.RaycastAimDispose()
    ra.install()
    return SA.RaycastAimState()
end

SA.RaycastAimRestore = SA.RaycastAimRefresh

-- Install once at load; default OFF leaves every ray unmodified.
SA.RaycastAimRefresh()
