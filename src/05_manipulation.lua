-- ==================================================================
-- Hanami / 05_manipulation.lua — Bullet Manipulation v4 (v7.7 patched)
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- BULLET MANIPULATION v4 — patched from the vault v7.7 extract
--
--   * one shared RaycastParams instead of a new one per ray (the old
--     module rebuilt it inside every peek / clearance raycast)
--   * filter includes BOTH the local character and the target model, so
--     the target's own body never counts as "cover"
--   * GUNS ONLY: bows bail out before any ray is cast
--   * 8 peek directions: 4 cardinals + 4 diagonals
--   * adaptive maxPeek = clamp(base + distance * 0.06, base, cap) so
--     long shots still clear cover, with a hard manipMaxPeek ceiling
--   * raised defaults: parts 48, budget 96, range 1000, peek 20,
--     max peek 120, max delta 40 (see 01_config.lua)
--   * disabled parts are tracked by a counter and reused entries, so
--     the restore pass never grows a table every frame
--
-- `CanQuery = false` is always restored by saManipRestore(), which the
-- silent-aim restore bind calls every frame. Any parts left disabled by
-- a previous execution are restored below on load.
-- ────────────────────────────────────────────────────────────────────

local saManipSharedRP = RaycastParams.new()
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
local saManipCache = {}
local saManipBudget = 0
local saManipFrame = 0

-- PATCH: targetModel is part of the filter. Without it, a ray from the
-- peek origin to a target's head can hit the target's own torso first.
local function saInitParams(targetModel)
    local f = {}
    if lp.Character then f[#f + 1] = lp.Character end
    if targetModel  then f[#f + 1] = targetModel  end
    saManipSharedRP.FilterDescendantsInstances = f
end

local function saBudgetReset()
    saManipBudget = math.max(CFG.manipBudget or 96, 0)
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
    local ttl = math.max(CFG.manipHysteresis or 3, 0)
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
    local dist = (targetPos - origin).Magnitude
    if dist > (CFG.manipDist or 1000) then return origin, false end
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

    -- PATCH: adaptive peek. A fixed 4-stud peek cannot clear cover on a
    -- long shot; scaling with distance (capped) fixes that without letting
    -- the origin drift arbitrarily far from the crosshair.
    local basePeek = math.max(CFG.manipPeek or 20, 0)
    local capPeek  = math.max(CFG.manipMaxPeek or 120, basePeek)
    local maxPeek  = math.clamp(basePeek + dist * 0.06, basePeek, capPeek)
    saManipLastMaxPeek = maxPeek
    local deltaCap = math.max(CFG.manipMaxPeekDelta or 40, maxPeek)
    local parts    = math.max(CFG.manipMaxParts or 48, 0)
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
        budget = CFG.manipBudget or 96, disabled = saManipDisabledN,
        cached = n, peek = saManipPeekOrigin,
        adaptivePeek = saManipLastMaxPeek,
        adaptiveCap = math.max(CFG.manipMaxPeek or 120, CFG.manipPeek or 20),
        directions = 8,
    }
end
