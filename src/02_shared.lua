-- ==================================================================
-- Hanami / 02_shared.lua — Velocity cache, checks, target selection, debug
-- Loaded in order by loader.lua. Parts are joined into ONE chunk
-- before running, so every `local` is shared just like the original.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- SHARED LOGIC
-- ────────────────────────────────────────────────────────────────────

local velCache = _G.__saVelCache or {}
_G.__saVelCache = velCache
if not _G.__saVelCleanup then
    _G.__saVelCleanup = true
    task.spawn(function()
        while true do
            task.wait(5)
            local now = tick()
            for k, v in pairs(velCache) do
                if now - v.t > 3 then velCache[k] = nil end
            end
        end
    end)
end

local function getVelocity(part)
    local model = part and part.Parent
    if not model then return Vector3.zero end
    local hrp = model:FindFirstChild("HumanoidRootPart")
    if not hrp then return Vector3.zero end
    local now, pos = tick(), hrp.Position
    local e = velCache[model]
    if not e then
        velCache[model] = { p = pos, t = now, v = Vector3.zero }
        return Vector3.zero
    end
    local dt = now - e.t
    if dt < 0.016 then return e.v end
    local v = (pos - e.p) / dt
    if v.Magnitude > 100 then v = Vector3.zero end
    e.p, e.t, e.v = pos, now, v
    return v
end

local function isTeammate(p)
    local mates = lp:GetAttribute("FustMates")
    if not mates or mates == "" then return false end
    for id in mates:gmatch("[^,;]+") do
        if tonumber(id) == p.UserId then return true end
    end
    return false
end

-- The NPC names used by this game. Also accept the common attribute
-- variants and models that live inside an "Npcs" container.
local NPC_NAMES = { Guard = true, Scavenger = true, Soldier = true }
local NPC_ATTRS = { "Scavenger", "IsNpc", "IsNPC", "NPC", "Npc" }
local NPC_FOLDERS = { Npcs = true, NPCs = true, NPCS = true, Enemies = true }

local function isNpc(model)
    if not model then return false end
    if NPC_NAMES[model.Name] then return true end
    for _, attr in ipairs(NPC_ATTRS) do
        if model:GetAttribute(attr) == true then return true end
    end
    local parent = model.Parent
    if parent and NPC_FOLDERS[parent.Name] and model:IsA("Model") then return true end
    return false
end

local losParams = RaycastParams.new()
losParams.FilterType = Enum.RaycastFilterType.Exclude
losParams.IgnoreWater = true

local function checkWall(origin, targetPos, targetModel)
    local filter = {}
    if lp.Character then table.insert(filter, lp.Character) end
    if targetModel  then table.insert(filter, targetModel)  end
    losParams.FilterDescendantsInstances = filter
    return workspace:Raycast(origin, targetPos - origin, losParams) == nil
end

local function bonePart(model, boneName)
    if boneName == "Hrp" then
        return model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head")
    end
    return model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
end

local function rollHit()
    if CFG.hitChance >= 100 then return true end
    if CFG.hitChance <= 0   then return false end
    return math.random(1, 100) <= CFG.hitChance
end

-- preview = true -> pure "closest to crosshair inside FOV" lookup for the
-- snapline. Skips the wall abort and the hit-chance roll so the line stays
-- stable instead of flickering with RNG.
local function pickBestTarget(camera, aimPx, originPos, preview)
    if not camera or not lp.Character then return nil end
    local best = { delta = math.huge }
    local function consider(bone, model)
        if not bone then return end
        local bp = bone.Position
        if CFG.distance > 0 and (bp - originPos).Magnitude > CFG.distance then return end
        local sp, onScreen = camera:WorldToViewportPoint(bp)
        if not onScreen then return end
        local dx, dy = sp.X - aimPx.X, sp.Y - aimPx.Y
        local d2 = dx * dx + dy * dy
        if CFG.fov > 0 and d2 > CFG.fov * CFG.fov then return end
        if d2 < best.delta then
            best = { delta = d2, bone = bone, model = model, pos = bp }
        end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= lp then
            if not (CFG.teamCheck and isTeammate(p)) then
                local model = p.Character
                local hum = model and model:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    consider(bonePart(model, CFG.targetBone), model)
                end
            end
        end
    end
    if CFG.targetNpcs then
        -- SA.GetNpcs() is provided by 03_entity_scan.lua (whole-workspace scan)
        local npcs = SA.GetNpcs and SA.GetNpcs() or {}
        for _, model in ipairs(npcs) do
            local hum = model:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                consider(bonePart(model, CFG.targetBone), model)
            end
        end
    end
    if not best.bone then return nil end
    if not preview then
        if CFG.wallCheck and not CFG.manipulation
            and not checkWall(originPos, best.pos, best.model) then return nil end
        if not rollHit() then return nil end
    end
    return best
end

local function dbg(...)
    if CFG.debug then print("[sa]", ...) end
end
