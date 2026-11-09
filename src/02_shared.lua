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
-- Public so ESP decluttering / HUD can apply the same team rules as aim.
function SA.IsTeammate(p) return isTeammate(p) end

-- ── BETTER: target priority, pinned target, live "why no target" ─────
-- A pinned target survives target-priority changes until it dies or the
-- player clears it. It is deliberately NOT used by the snapline preview
-- (preview=true), so the aim line never jumps to a stale pin.
function SA.ClearPinnedTarget()
    SA.PinnedTarget = nil
end

function SA.PinNearestTarget()
    local myRoot = lp.Character and (lp.Character:FindFirstChild("HumanoidRootPart")
        or lp.Character:FindFirstChild("Head")) or nil
    local myPos = myRoot and myRoot.Position or nil
    if not myPos then return nil, "no local character" end
    local best, bestD = nil, math.huge
    local ok = pcall(function()
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= lp and plr.Character then
                local char = plr.Character
                local root = char:FindFirstChild("HumanoidRootPart")
                    or char:FindFirstChild("Head")
                local hum = char:FindFirstChildOfClass("Humanoid")
                if root and hum and hum.Health > 0 then
                    local d = (myPos - root.Position).Magnitude
                    if d < bestD then bestD, best = d, { plr = plr, char = char,
                        hum = hum, head = char:FindFirstChild("Head") or root } end
                end
            end
        end
    end)
    if not ok or not best then return nil, "no other player with a live rig" end
    SA.PinnedTarget = { model = best.char, bone = best.head,
                        name = best.plr.Name, at = tick() }
    if type(setFlag) == "function" then pcall(setFlag, "targetPriority", "Pinned") end
    print("[sa] pinned nearest target:", tostring(best.plr.Name),
        string.format("(%.1f m)", bestD / (SA.STUDS_PER_METER or 3.571)))
    return best.plr.Name, nil
end

function SA.NoTargetReason()
    if not lp.Character then return "no local character" end
    if CFG.masterEnabled ~= true then return "aim master OFF" end
    if CFG.gunEnabled ~= true then return "gun silent aim OFF" end
    if CFG.targetPriority == "Pinned" then
        return SA.PinnedTarget and ("pinned: " .. tostring(SA.PinnedTarget.name))
            or "no pinned target (use Pin Nearest Player)"
    end
    local t = SA.Target
    if t and t.model then return "target: " .. tostring(t.model.Name) end
    if CFG.hitChance < 100 then return "no target in FOV / hit-chance roll" end
    if CFG.wallCheck and not CFG.manipulation then
        return "no target in FOV / wall blocked"
    end
    return "no target in FOV (widen Aim Radius / enable Target NPCs)"
end

-- Per-weapon bone override. "Global" keeps the classic Target Bone
-- dropdown; the two modes only change it for scoped guns / shotguns.
function SA.ResolveTargetBone()
    local base = CFG.targetBone or "Head"
    local mode = CFG.targetBoneMode or "Global"
    if mode == "Global" then return base end
    local id = ""
    pcall(function() id = tostring(SA.GetEquippedGun().id or "") end)
    local scoped = id:find("sniper", 1, true) or id:find("bolt", 1, true)
        or id:find("rifle", 1, true)
    local shotgun = id:find("shotgun", 1, true)
    if mode == "Head for snipers" then return scoped and "Head" or "Hrp" end
    if mode == "Hrp for shotguns" then return shotgun and "Hrp" or "Head" end
    return base
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
    -- Pinned target wins for the REAL shot, but never hijacks the
    -- snapline preview (which must stay the closest-to-crosshair pick).
    if not preview and (CFG.targetPriority or "Crosshair") == "Pinned"
        and SA.PinnedTarget then
        local pin = SA.PinnedTarget
        local okPin = pcall(function()
            local hum = pin.model and pin.model:FindFirstChildOfClass("Humanoid")
            if pin.model and pin.model.Parent and pin.bone and pin.bone.Parent
                and hum and hum.Health > 0 then
                pin.pos = pin.bone.Position
            else
                SA.PinnedTarget = nil
            end
        end)
        if okPin and SA.PinnedTarget and pin.pos then
            return { bone = pin.bone, model = pin.model, pos = pin.pos,
                     pinned = true }
        end
    end
    local best = { delta = math.huge }
    local priority = preview and "Crosshair" or (CFG.targetPriority or "Crosshair")
    local resolvedBone = SA.ResolveTargetBone and SA.ResolveTargetBone() or CFG.targetBone
    local function score(bp, d2, hum)
        if priority == "Nearest" then return (bp - originPos).Magnitude end
        if priority == "Lowest HP" then return hum and hum.Health or math.huge end
        return d2  -- Crosshair (and everything unknown)
    end
    -- EXACTLY the same centre + radius the FOV circle is drawn with.
    -- `aimPx` must be SA.AimPoint(); the radius always comes from
    -- SA.FovRadius() so targets inside the circle are the ones picked.
    local aimRef = aimPx or SA.AimPoint()
    local radius = SA.FovRadius()
    local r2 = radius * radius
    local function consider(bone, model, hum)
        if not bone then return end
        local bp = bone.Position
        if CFG.distance > 0 and (bp - originPos).Magnitude > CFG.distance then return end
        local sp, onScreen = camera:WorldToViewportPoint(bp)
        if not onScreen then return end
        local dx, dy = sp.X - aimRef.X, sp.Y - aimRef.Y
        local d2 = dx * dx + dy * dy
        if radius > 0 and d2 > r2 then return end
        local sc = score(bp, d2, hum)
        if sc < best.delta then
            best = { delta = sc, bone = bone, model = model, pos = bp }
        end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= lp then
            if not (CFG.teamCheck and isTeammate(p)) then
                local model = p.Character
                local hum = model and model:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    consider(bonePart(model, resolvedBone), model, hum)
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
                consider(bonePart(model, resolvedBone), model, hum)
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
