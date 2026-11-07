-- ==================================================================
-- Hanami / 05_manipulation.lua — Wall-peek + CanQuery manipulation
-- Loaded in order by loader.lua. Parts are joined into ONE chunk
-- before running, so every `local` is shared just like the original.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- MANIPULATION MODULE
-- ────────────────────────────────────────────────────────────────────

local saManipDisabled = _G.__saManipDisabled or {}
_G.__saManipDisabled = saManipDisabled
if #saManipDisabled > 0 then
    for i = #saManipDisabled, 1, -1 do
        pcall(function() saManipDisabled[i].part.CanQuery = saManipDisabled[i].original end)
    end
    table.clear(saManipDisabled)
end

local saManipCache = {}
local saManipPeekOrigin = nil
local saManipBudget = 0
local saManipFrame = 0

local function saMakeParams(targetModel)
    local f = {}
    if lp.Character then table.insert(f, lp.Character) end
    if targetModel  then table.insert(f, targetModel)  end
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = f
    rp.IgnoreWater = true
    return rp
end

local function saBudgetTake(n)
    n = n or 1
    if saManipBudget < n then return false end
    saManipBudget = saManipBudget - n
    return true
end

local function saPeekAlongDir(origin, targetPos, dir, maxPeek, targetModel)
    local rp = saMakeParams(targetModel)
    if not saBudgetTake(1) then return nil end
    local pMax = origin + dir * maxPeek
    if ws:Raycast(pMax, targetPos - pMax, rp) then return nil end
    local lo, hi = 0, maxPeek
    for _ = 1, 6 do
        if not saBudgetTake(1) then break end
        local mid = (lo + hi) * 0.5
        local p = origin + dir * mid
        if ws:Raycast(p, targetPos - p, rp) then lo = mid else hi = mid end
    end
    return origin + dir * hi, hi
end

local function saFindPeek(origin, targetPos, wallNormal, targetModel, maxPeek)
    local up = Vector3.new(0, 1, 0)
    local right = wallNormal:Cross(up)
    if right.Magnitude < 0.01 then right = CFrame.lookAt(origin, targetPos).RightVector end
    right = right.Unit
    local wallUp = wallNormal:Cross(right).Unit
    local dirs = { right, -right, wallUp, -wallUp }
    local best, bestDist = nil, math.huge
    for _, dir in ipairs(dirs) do
        local p, d = saPeekAlongDir(origin, targetPos, dir, maxPeek, targetModel)
        if p and d < bestDist then best, bestDist = p, d end
    end
    return best, bestDist
end

local function saClearCanQuery(origin, targetPos, targetModel, maxParts)
    if maxParts <= 0 then return false end
    local rp = saMakeParams(targetModel)
    local dir = targetPos - origin
    local count = 0
    for _ = 1, maxParts + 2 do
        if count >= maxParts then return false end
        if not saBudgetTake(1) then return false end
        local result = ws:Raycast(origin, dir, rp)
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
        table.insert(saManipDisabled, { part = hit, original = hit.CanQuery })
        hit.CanQuery = false
        count = count + 1
    end
    return false
end

local function saManipRestore()
    for i = #saManipDisabled, 1, -1 do
        pcall(function() saManipDisabled[i].part.CanQuery = saManipDisabled[i].original end)
    end
    table.clear(saManipDisabled)
    saManipPeekOrigin = nil
end

local function saManipBeginFrame()
    saManipBudget = CFG.manipBudget or 40
    saManipFrame = saManipFrame + 1
    local ttl = CFG.manipHysteresis or 3
    for k, v in pairs(saManipCache) do
        if saManipFrame - v.frame > ttl then saManipCache[k] = nil end
    end
end

local function saManipResolve(origin, targetPos, targetModel)
    local dist = (targetPos - origin).Magnitude
    local rp = saMakeParams(targetModel)
    if not saBudgetTake(1) then return origin, true end
    local direct = ws:Raycast(origin, targetPos - origin, rp)
    if not direct then return origin, true end
    if dist > (CFG.manipDist or 30) then return origin, false end
    local cache = saManipCache[targetModel]
    if cache and cache.peek then
        if saBudgetTake(1) then
            if not ws:Raycast(cache.peek, targetPos - cache.peek, rp) then
                cache.frame = saManipFrame
                saManipPeekOrigin = cache.peek
                return cache.peek, true
            end
        end
        saManipCache[targetModel] = nil
    end
    local maxPeek = CFG.manipPeek or 4
    local peek, peekDist = saFindPeek(origin, targetPos, direct.Normal, targetModel, maxPeek)
    if peek and peekDist <= (CFG.manipMaxPeekDelta or 6) then
        saClearCanQuery(peek, targetPos, targetModel, CFG.manipMaxParts or 3)
        saManipCache[targetModel] = { peek = peek, frame = saManipFrame }
        saManipPeekOrigin = peek
        return peek, true
    end
    local cleared = saClearCanQuery(origin, targetPos, targetModel, CFG.manipMaxParts or 3)
    if cleared then return origin, true end
    saManipRestore()
    return origin, false
end

