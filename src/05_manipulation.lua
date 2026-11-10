-- ==================================================================
-- Hanami / 05_manipulation.lua — Bullet Manipulation (classic sliders)
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- BULLET MANIPULATION — classic six-slider behaviour, modern engine
--
--   * CLASSIC sliders back: Range (0-300 studs), Base Peek (4-6 only),
--     Max CanQuery Parts (0-8), Ray Budget (8-128), Cache Hysteresis
--     (0-12) and Max Peek Delta (2-12). No "Adaptive Peek Cap".
--   * fixed maxPeek = Base Peek. The v7.7 adaptive formula made
--     `deltaCap = math.max(delta, maxPeek)` ALWAYS >= maxPeek, so Max
--     Peek Delta could never reject a peek — it was a dead slider. Now
--     deltaCap is just the slider value and genuinely caps peekDist.
--   * Every slider is clamped to its UI range each frame, so imported
--     profiles and manual edits can't silently break a control.
--   * one shared RaycastParams (target model included in the filter)
--   * GUNS ONLY: bows bail out before any ray is cast
--   * 8 peek directions: 4 cardinals + 4 diagonals
--   * disabled parts are tracked by a counter and reused entries, so
--     the restore pass never grows a table every frame
--
-- `CanQuery = false` is always restored by saManipRestore(), which the
-- silent-aim restore bind calls every frame. Any parts left disabled by
-- a previous execution are restored below on load.
-- ────────────────────────────────────────────────────────────────────

local saManipSharedRP = SA.MarkInternalRayParams(RaycastParams.new())
saManipSharedRP.FilterType = Enum.RaycastFilterType.Exclude
saManipSharedRP.IgnoreWater = true

local saManipDisabled = _G.__saManipDisabled or {}
_G.__saManipDisabled = saManipDisabled
local saManipDisabledN = 0
if #saManipDisabled > 0 then
    for i = #saManipDisabled, 1, -1 do
        local e = saManipDisabled[i]
        if e then pcall(function() e.part.CanQuery = e.original end) end
        saManipDisabled[i] = nil
    end
end

local saManipPeekOrigin = nil
local saManipLastMaxPeek = 0
local saManipLastNpc = false
local saManipCache = {}
local saManipBudget = 0
local saManipFrame = 0

-- Match the UI slider bounds exactly; a value outside the range is not a
-- "valid" setting and would make the control lie about what it does.
local function saManipNum(key, lo, hi, def)
    local n = tonumber(CFG[key])
    if not n then return def end
    return math.clamp(n, lo, hi)
end

-- PATCH: targetModel is part of the filter. Without it, a ray from the
-- peek origin to a target's head can hit the target's own torso first.
local function saInitParams(targetModel)
    local f = {}
    if lp.Character then f[#f + 1] = lp.Character end
    if targetModel  then f[#f + 1] = targetModel  end
    saManipSharedRP.FilterDescendantsInstances = f
end

local function saBudgetReset()
    saManipBudget = saManipNum("manipBudget", 8, 128, 40)
    saManipFrame = saManipFrame + 1
end

local function saBudgetTake(n)
    n = n or 1
    if saManipBudget < n then return false end
    saManipBudget = saManipBudget - n
    return true
end

local function saPeekAlongDir(origin, targetPos, dir, maxPeek)
    if maxPeek <= 0 then return nil end
    if not saBudgetTake(1) then return nil end
    local pMax = origin + dir * maxPeek
    if ws:Raycast(pMax, targetPos - pMax, saManipSharedRP) then return nil end
    local lo, hi = 0, maxPeek
    for _ = 1, 6 do
        if not saBudgetTake(1) then break end
        local mid = (lo + hi) * 0.5
        local p = origin + dir * mid
        if ws:Raycast(p, targetPos - p, saManipSharedRP) then lo = mid else hi = mid end
    end
    return origin + dir * hi, hi
end

-- PATCH: 8 directions instead of 4. Diagonals find a clear line around
-- corner pillars where the four cardinals all stay blocked.
local function saFindPeek(origin, targetPos, wallNormal, maxPeek)
    local up = Vector3.new(0, 1, 0)
    local right = wallNormal:Cross(up)
    if right.Magnitude < 0.01 then
        right = CFrame.lookAt(origin, targetPos).RightVector
    end
    right = right.Unit
    local wallUp = wallNormal:Cross(right).Unit
    local d45  = (right + wallUp).Unit
    local d135 = (right - wallUp).Unit
    local dirs = { right, -right, wallUp, -wallUp, d45, -d45, d135, -d135 }
    local best, bestDist = nil, math.huge
    for _, dir in ipairs(dirs) do
        local p, d = saPeekAlongDir(origin, targetPos, dir, maxPeek)
        if p and d < bestDist then
            best, bestDist = p, d
            if d < 1 then break end
        end
    end
    return best, bestDist
end

local function saClearCanQuery(origin, targetPos, maxParts)
    if maxParts <= 0 then return false end
    local dir = targetPos - origin
    local count = 0
    for _ = 1, maxParts + 2 do
        if count >= maxParts then return false end
        if not saBudgetTake(1) then return false end
        local result = ws:Raycast(origin, dir, saManipSharedRP)
        if result == nil then return true end
        local hit = result.Instance
        if not hit or not hit:IsA("BasePart") then return false end
        if hit:IsA("Terrain") then return false end
        local isChar = false
        local anc = hit.Parent
        while anc and anc ~= ws do
            if anc:FindFirstChildOfClass("Humanoid") then isChar = true; break end
            anc = anc.Parent
        end
        if isChar then return false end
        local n = saManipDisabledN + 1
        local entry = saManipDisabled[n]
        if entry then
            entry.part = hit; entry.original = hit.CanQuery
        else
            saManipDisabled[n] = { part = hit, original = hit.CanQuery }
        end
        saManipDisabledN = n
        hit.CanQuery = false
        count = count + 1
    end
    return false
end

local function saManipRestore()
    if saManipDisabledN > 0 then
        for i = saManipDisabledN, 1, -1 do
            local e = saManipDisabled[i]
            if e then pcall(function() e.part.CanQuery = e.original end) end
        end
        saManipDisabledN = 0
    end
    saManipPeekOrigin = nil
end

local function saManipBeginFrame()
    saBudgetReset()
    local ttl = saManipNum("manipHysteresis", 0, 12, 3)
    for k, v in pairs(saManipCache) do
        if saManipFrame - v.frame > ttl then saManipCache[k] = nil end
    end
end

-- Returns (origin, ok). `ok = false` means no clear line was found, so a
-- strict Wall Check shot can be aborted instead of snapping at a wall.
local function saManipResolve(origin, targetPos, targetModel)
    if not (CFG.manipulation and targetModel) then return origin, true end
    -- Silent aim / manipulation are guns only. SA.IsEquippedBow() lives in
    -- 07_gun_specs.lua and is a plain name classifier, not an aim path.
    if type(SA.IsEquippedBow) == "function" and SA.IsEquippedBow() then
        return origin, true
    end
    -- NPC targets use the SAME six-slider peek / CanQuery engine. Respect
    -- the dedicated NPC toggle (and the existing Target NPCs gate) so a
    -- user can wall-peek players without touching NPC models.
    local isNpc = type(SA.IsNpcModel) == "function"
        and SA.IsNpcModel(targetModel) or false
    saManipLastNpc = isNpc
    if isNpc and (CFG.targetNpcs ~= true or CFG.manipNpcs == false) then
        return origin, true
    end
    local dist = (targetPos - origin).Magnitude
    if dist > saManipNum("manipDist", 0, 300, 30) then return origin, false end
    saInitParams(targetModel)
    if not saBudgetTake(1) then return origin, false end
    local direct = ws:Raycast(origin, targetPos - origin, saManipSharedRP)
    if not direct then return origin, true end

    local cache = saManipCache[targetModel]
    if cache and cache.peek then
        if saBudgetTake(1)
            and not ws:Raycast(cache.peek, targetPos - cache.peek, saManipSharedRP) then
            cache.frame = saManipFrame
            saManipPeekOrigin = cache.peek
            return cache.peek, true
        end
        saManipCache[targetModel] = nil
    end

    -- CLASSIC: Base Peek IS the maximum peek (4-6 studs). The adaptive
    -- v7.7 formula is gone — it silently neutralised Max Peek Delta.
    local maxPeek  = saManipNum("manipPeek", 4, 6, 4)
    saManipLastMaxPeek = maxPeek
    local deltaCap = saManipNum("manipMaxPeekDelta", 2, 12, 6)
    local parts    = saManipNum("manipMaxParts", 0, 8, 3)
    local peek, peekDist = saFindPeek(origin, targetPos, direct.Normal, maxPeek)
    if peek and peekDist <= deltaCap then
        saClearCanQuery(peek, targetPos, parts)
        saManipCache[targetModel] = { peek = peek, frame = saManipFrame }
        saManipPeekOrigin = peek
        return peek, true
    end
    if saClearCanQuery(origin, targetPos, parts) then return origin, true end
    saManipRestore()
    return origin, false
end

function SA.ManipState()
    local n = 0
    for _ in pairs(saManipCache) do n = n + 1 end
    return {
        frame = saManipFrame, remaining = saManipBudget,
        budget = saManipNum("manipBudget", 8, 128, 40),
        disabled = saManipDisabledN, cached = n, peek = saManipPeekOrigin,
        range = saManipNum("manipDist", 0, 300, 30),
        basePeek = saManipNum("manipPeek", 4, 6, 4),
        maxPeek = saManipLastMaxPeek,
        parts = saManipNum("manipMaxParts", 0, 8, 3),
        hysteresis = saManipNum("manipHysteresis", 0, 12, 3),
        deltaCap = saManipNum("manipMaxPeekDelta", 2, 12, 6),
        directions = 8,
        npcsEnabled = CFG.manipNpcs ~= false,
        npcTargets = #(SA.GetNpcs and SA.GetNpcs() or {}),
        lastNpc = saManipLastNpc,
    }
end

function SA.ManipNpcState()
    local npcs = SA.GetNpcs and SA.GetNpcs() or {}
    return {
        enabled = CFG.manipNpcs ~= false,
        targeting = CFG.targetNpcs == true,
        count = #npcs,
        range = saManipNum("manipDist", 0, 300, 30),
        parts = saManipNum("manipMaxParts", 0, 8, 3),
        peek = saManipNum("manipPeek", 4, 6, 4),
        lastNpc = saManipLastNpc,
    }
end


-- ── BETTER: read-only "can manipulation find a shot?" probe ─────────
-- The crosshair popup needs the SAME answer as saManipResolve() without
-- actually consuming the ray budget, changing CanQuery or caching a peek.
-- It uses a private RaycastParams and only reads the Workspace; the real
-- shot resolver is still the only place that mutates world state.
do
    local probeRP = SA.MarkInternalRayParams(RaycastParams.new())
    probeRP.FilterType = Enum.RaycastFilterType.Exclude
    probeRP.IgnoreWater = true

    local function probeFilters(targetModel)
        local f = {}
        if lp.Character then f[#f + 1] = lp.Character end
        if targetModel then f[#f + 1] = targetModel end
        return f
    end

    local function probeRay(origin, targetPos, filters)
        probeRP.FilterDescendantsInstances = filters
        local ok, hit = pcall(function()
            return ws:Raycast(origin, targetPos - origin, probeRP)
        end)
        if not ok then return nil end
        return hit
    end

    local function probePeek(origin, targetPos, normal, maxPeek)
        local up = Vector3.new(0, 1, 0)
        local n = normal or Vector3.new(0, 0, -1)
        local right = n:Cross(up)
        if right.Magnitude < 0.01 then
            right = CFrame.lookAt(origin, targetPos).RightVector
        end
        right = right.Unit
        local wallUp = n:Cross(right).Unit
        local d45  = (right + wallUp).Unit
        local d135 = (right - wallUp).Unit
        local dirs = { right, -right, wallUp, -wallUp, d45, -d45, d135, -d135 }
        local best, bestDist = nil, math.huge
        for _, dir in ipairs(dirs) do
            local pMax = origin + dir * maxPeek
            if not probeRay(pMax, targetPos, probeRP.FilterDescendantsInstances) then
                local lo, hi = 0, maxPeek
                for _ = 1, 6 do
                    local mid = (lo + hi) * 0.5
                    local p = origin + dir * mid
                    if probeRay(p, targetPos, probeRP.FilterDescendantsInstances) then
                        lo = mid
                    else
                        hi = mid
                    end
                end
                if hi < bestDist then
                    best, bestDist = origin + dir * hi, hi
                end
            end
        end
        return best, bestDist
    end

    local function probeWallParts(origin, targetPos, maxParts, targetModel)
        if maxParts <= 0 then return nil end
        local filters = probeFilters(targetModel)
        local count = 0
        for _ = 1, maxParts + 2 do
            local hit = probeRay(origin, targetPos, filters)
            if not hit then return count end
            local part = hit.Instance
            if not part or not part:IsA("BasePart") or part:IsA("Terrain") then
                return nil
            end
            local anc = part.Parent
            local isChar = false
            while anc and anc ~= ws do
                if anc:FindFirstChildOfClass("Humanoid") then
                    isChar = true
                    break
                end
                anc = anc.Parent
            end
            if isChar then return nil end
            count = count + 1
            if count > maxParts then return nil end
            filters[#filters + 1] = part
        end
        return nil
    end

    -- allowNoAim = true is used by Triggerbot / Auto Fire. Those features
    -- are deliberately independent of the silent-aim master/gun toggles;
    -- the manipulation READY line check itself is still identical.
    function SA.ManipPossible(modelOverride, allowNoAim)
        local info = {
            enabled = CFG.manipulation == true,
            aim = CFG.masterEnabled == true and CFG.gunEnabled == true,
            popup = CFG.showManipPopup == true,
            npc = false,
            npcEnabled = CFG.manipNpcs ~= false,
            targetingNpcs = CFG.targetNpcs == true,
            allowNoAim = allowNoAim == true,
        }
        if not info.aim and allowNoAim ~= true then
            return false, "aim master / gun silent aim OFF", info
        end
        if not info.enabled then
            return false, "manipulation OFF", info
        end
        if type(SA.IsEquippedBow) == "function" and SA.IsEquippedBow() then
            return false, "bow equipped (guns only)", info
        end
        local cam = ws.CurrentCamera
        if not cam then return false, "no camera", info end
        local origin = cam.CFrame.Position
        local best
        if modelOverride then
            -- State checks / tests can probe one specific NPC without
            -- fighting the crosshair picker for the closest target.
            local boneName = SA.ResolveTargetBone and SA.ResolveTargetBone()
                or (CFG.targetBone or "Head")
            local bone = bonePart(modelOverride, boneName)
            if not bone then
                return false, "override target has no aim bone", info
            end
            best = { model = modelOverride, bone = bone, pos = bone.Position }
        else
            local okPick, picked = pcall(function()
                return pickBestTarget(cam, SA.AimPoint(), origin, true)
            end)
            best = picked
            if not okPick or not best or not best.model or not best.pos then
                return false, (SA.NoTargetReason and SA.NoTargetReason()
                    or "no target in FOV"), info
            end
        end
        info.npc = type(SA.IsNpcModel) == "function"
            and SA.IsNpcModel(best.model) or false
        if info.npc and not info.targetingNpcs then
            return false, "NPC targeting OFF", info
        end
        if info.npc and not info.npcEnabled then
            return false, "NPC manipulation OFF", info
        end
        local npcTag = info.npc and " [NPC]" or ""
        local targetPos = best.pos
        if CFG.prediction and type(SA.Predict) == "function" then
            local okPred, pred = pcall(SA.Predict, origin, targetPos, best.model)
            if okPred and pred then targetPos = pred end
        end
        local dist = (targetPos - origin).Magnitude
        local range = saManipNum("manipDist", 0, 300, 30)
        info.model = best.model.Name
        info.distance = dist
        info.range = range
        if range > 0 and dist > range then
            return false, "out of manip range" .. npcTag, info
        end

        local filters = probeFilters(best.model)
        local direct = probeRay(origin, targetPos, filters)
        if not direct then
            info.clear = true
            return true, "clear line (no manip needed)" .. npcTag, info
        end

        local maxPeek = saManipNum("manipPeek", 4, 6, 4)
        local deltaCap = saManipNum("manipMaxPeekDelta", 2, 12, 6)
        local peek, peekDist = probePeek(origin, targetPos, direct.Normal, maxPeek)
        if peek and peekDist <= deltaCap then
            info.peek = peekDist
            return true, string.format("peek %.1f studs%s", peekDist, npcTag), info
        end

        local parts = saManipNum("manipMaxParts", 0, 8, 3)
        local wallParts = probeWallParts(origin, targetPos, parts, best.model)
        if wallParts then
            info.wallParts = wallParts
            return true, string.format("wall bypass (%d parts)%s", wallParts, npcTag), info
        end
        return false, "wall blocked / no peek or CanQuery path" .. npcTag, info
    end
end
