-- ==================================================================
-- Hanami / 02_shared.lua — Velocity cache, checks, target selection, debug
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- SHARED LOGIC
-- ────────────────────────────────────────────────────────────────────

-- ────────────────────────────────────────────────────────────────────
-- THE FOV REFERENCE POINT
-- Every subsystem must measure the aim cone from the SAME centre and
-- radius: the drawn circle, silent-aim target picking, the snapline,
-- tracer origins and the off-screen arrows. Previously each part called
-- UserInputService:GetMouseLocation() itself and only the circle had a
-- screen-centre fallback, so a broken mouse API put the circle in one
-- place while aim still measured from (0,0).
--
-- Bogus mouse positions (0,0 / off-screen) automatically fall back to the
-- screen centre, so the circle is never drawn off-screen.
-- ────────────────────────────────────────────────────────────────────
function SA.ViewportSize()
    local cam = ws.CurrentCamera
    if cam and cam.ViewportSize and cam.ViewportSize.X > 0 then
        return cam.ViewportSize
    end
    return Vector2.new(1920, 1080)
end

function SA.AimPoint()
    local vp = SA.ViewportSize()
    if CFG.fovCenterMode ~= "Screen Center" then
        local ok, p = pcall(function() return UserInputService:GetMouseLocation() end)
        if ok and p and type(p.X) == "number" and type(p.Y) == "number" then
            if p.X > 0 and p.Y > 0 and p.X < vp.X and p.Y < vp.Y then
                return Vector2.new(p.X, p.Y)
            end
        end
    end
    return Vector2.new(vp.X / 2, vp.Y / 2)
end

-- Alias kept so older FX code and any saved snippets keep working.
function SA.FovCenter() return SA.AimPoint() end

function SA.FovRadius()
    local vp = SA.ViewportSize()
    local r = math.max(tonumber(CFG.fov) or 220, 1)
    -- cap at half the shorter screen side: a radius bigger than the
    -- viewport cannot be drawn or used as a meaningful reference
    return math.min(r, math.min(vp.X, vp.Y) / 2)
end

-- Target velocity is now sampled/smoothed by 08_prediction.lua
-- (SA.TargetVelocity); the old single-frame velCache is gone.

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
    -- EXACTLY the same centre + radius the FOV circle is drawn with.
    -- `aimPx` must be SA.AimPoint(); the radius always comes from
    -- SA.FovRadius() so targets inside the circle are the ones picked.
    local aimRef = aimPx or SA.AimPoint()
    local radius = SA.FovRadius()
    local r2 = radius * radius
    local function consider(bone, model)
        if not bone then return end
        local bp = bone.Position
        if CFG.distance > 0 and (bp - originPos).Magnitude > CFG.distance then return end
        local sp, onScreen = camera:WorldToViewportPoint(bp)
        if not onScreen then return end
        local dx, dy = sp.X - aimRef.X, sp.Y - aimRef.Y
        local d2 = dx * dx + dy * dy
        if radius > 0 and d2 > r2 then return end
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
