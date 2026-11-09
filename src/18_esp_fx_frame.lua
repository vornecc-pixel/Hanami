-- ==================================================================
-- Hanami / 18_esp_fx_frame.lua — Per-frame ESP styling entry point
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- Frame entry point (called by 19_render_loop.lua after all refreshes)
--
-- Every player is styled inside its own pcall now. Previously one bad
-- character (a destroyed Head, a failed Raycast, a Drawing write that
-- throws on this executor) aborted the entire FX pass, so all remaining
-- players in pairs(espObjects) silently kept last frame's drawings.
-- ────────────────────────────────────────────────────────────────────

local function safeDrawEntity(cam, o, opt)
    if not pcall(drawEntity, cam, o, opt) then pcall(hideFx, o) end
end

-- FPS counters are shared with 19_render_loop.lua (throttled data refresh)
-- and survive re-execution so Print ESP FPS State shows the whole session.
SA.EspPerf = SA.EspPerf or { fxPasses = 0, dataRefreshes = 0, dataSkips = 0 }
SA.EspFxFrame = SA.EspFxFrame or 0

-- ── BETTER: ESP decluttering / FPS pass ──────────────────────────────
SA.EspVisibleCount = { players = 0, npcs = 0, crates = 0 }
SA.CrateFovCount = { inside = 0, outside = 0, dots = 0, highlights = 0 }
local espNearestSet = {}
local espNearestBuilt, espNearestCount, espNearestFrame = false, nil, -1
local espTeamSetMode, espTeamSetFrame = nil, -1
local espTeamMateByChar = {}

local function espDataInterval()
    if type(SA.EspDataIntervalFrames) == "function" then
        return SA.EspDataIntervalFrames()
    end
    return 6
end

-- The build / refresh files already cached the rig. Reuse it in the FX
-- pass instead of walking FindFirstChild / IsA again for every entity.
local function fxPlayerRig(o, char)
    local root, head, hum = o.root, o.head, o.hum
    if o.char == char and root and root.Parent and head and head.Parent and hum then
        return root, head, hum
    end
    root, head, hum = SA.PlayerRig(char)
    o.root, o.head, o.hum = root, head, hum
    return root, head, hum
end

local function fxNpcRig(o, model)
    local hum, hrp, head = o.hum, o.root, o.head
    if model.Parent and hum and hrp and hrp.Parent and head and head.Parent then
        return hum, hrp, head
    end
    hum  = model.Parent and model:FindFirstChildOfClass("Humanoid")
    hrp  = model.Parent and (model:FindFirstChild("HumanoidRootPart")
        or model:FindFirstChild("Head"))
    head = model.Parent and (model:FindFirstChild("Head") or hrp)
    o.hum, o.root, o.head = hum, hrp, head
    return hum, hrp, head
end

local function addAimToNearest(aimModel)
    if not aimModel then return end
    espNearestSet[aimModel] = true
    for plr in pairs(espObjects) do
        if plr == aimModel or plr.Character == aimModel then
            espNearestSet[plr.Character or plr] = true
        end
    end
end

local function refreshNearestSet(myPos, aimModel)
    -- The aim target always keeps a slot, even between nearest-N sorts.
    addAimToNearest(aimModel)
    if not CFG.espOnlyNearest then return end
    local frame = SA.EspFxFrame or 0
    if espNearestBuilt and espNearestCount == CFG.espNearestCount
        and (frame - espNearestFrame) < espDataInterval() then return end
    espNearestSet = {}
    addAimToNearest(aimModel)
    local list = {}
    for plr, o in pairs(espObjects) do
        local char = plr.Character
        local root = o.root
        if not root or not root.Parent then
            root = SA.PlayerRig(char)
            o.root = root
        end
        if char and root then
            local ok, d = pcall(function() return (myPos - root.Position).Magnitude end)
            if ok and d then list[#list + 1] = { model = char, d = d } end
        end
    end
    table.sort(list, function(a, b) return a.d < b.d end)
    local n = math.min(math.floor(CFG.espNearestCount or 5), #list)
    for i = 1, n do espNearestSet[list[i].model] = true end
    espNearestBuilt, espNearestCount, espNearestFrame = true, CFG.espNearestCount, frame
end

-- Build ONE character -> teammate map per frame. The old code called
-- Players:GetPlayers() inside EspPassAllowed for every player (O(n^2)).
local function refreshTeamSet()
    local mode = CFG.espTeamMode or "All"
    local frame = SA.EspFxFrame or 0
    if espTeamSetMode == mode and espTeamSetFrame == frame then return end
    espTeamSetMode, espTeamSetFrame = mode, frame
    espTeamMateByChar = {}
    if mode == "All" or type(SA.IsTeammate) ~= "function" then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        local char = plr.Character
        if char then
            local ok, mate = pcall(SA.IsTeammate, plr)
            espTeamMateByChar[char] = ok and mate or false
        end
    end
end

function SA.EspPassAllowed(kind, model, dist, targetModel)
    if kind ~= "player" then return true end
    if targetModel and targetModel == model then espNearestSet[model] = true end
    if CFG.espOnlyAimTarget then
        if not targetModel or targetModel ~= model then return false end
    end
    if CFG.espOnlyNearest and not espNearestSet[model] then return false end
    local team = CFG.espTeamMode or "All"
    if team ~= "All" then
        refreshTeamSet()
        local mate = espTeamMateByChar[model] == true
        if team == "Teammates Only" and not mate then return false end
        if team == "Exclude Teammates" and mate then return false end
    end
    return true
end

function SA.CrateFovState()
    local c = SA.CrateFovCount or {}
    return {
        enabled = CFG.crateFovAware ~= false,
        crateEsp = CFG.crateEnabled == true,
        radius = SA.FovRadius and SA.FovRadius() or nil,
        center = SA.AimPoint and SA.AimPoint() or nil,
        inside = c.inside or 0,
        outside = c.outside or 0,
        dots = c.dots or 0,
        highlights = c.highlights or 0,
    }
end

function SA.PrintCrateFovState()
    local s = SA.CrateFovState()
    print("========== CRATE ESP FOV ==========")
    print("  enabled:", tostring(s.enabled), "| crate ESP:", tostring(s.crateEsp))
    print("  radius:", tostring(s.radius), "| inside:", tostring(s.inside),
        "| outside:", tostring(s.outside))
    print("  dots:", tostring(s.dots), "| outline highlights:",
        tostring(s.highlights))
    print("===================================")
end

function SA.EspPassStats()
    return {
        players = SA.EspVisibleCount.players,
        npcs = SA.EspVisibleCount.npcs,
        crates = SA.EspVisibleCount.crates,
        nearest = CFG.espOnlyNearest and CFG.espNearestCount or nil,
        teamMode = CFG.espTeamMode,
        onlyAimTarget = CFG.espOnlyAimTarget == true,
    }
end

local function drawPlayerFx(plr, o, cam, myPos, targetModel, origin, fovC, fovR, seed)
    local char = plr.Character
    if not char or (o.char and o.char ~= char) then hideFx(o); return end
    local hrp, head, hum = fxPlayerRig(o, char)
    if not (hum and hrp and head) then hideFx(o); return end
    local dist = (myPos - hrp.Position).Magnitude
    -- The throttled refresh owns LOS; between refreshes reuse o.vis so the
    -- FX pass does not call SA.IsVisible() a second time every frame.
    local vis = false
    if CFG.espVisibleCheck then
        if type(o.vis) == "boolean" then vis = o.vis
        else vis = SA.IsVisible(char, hrp.Position); o.vis = vis end
    end
    local base = CFG.espVisibleCheck
        and (vis and espC("playerVisible") or espC("playerHidden"))
        or espC("playerFlat")
    local dot = CFG.espVisibleCheck
        and (vis and espC("playerVisible") or espC("playerHidden"))
        or espC("playerVisDot")
    local raw, ok = cam:WorldToViewportPoint(hrp.Position)
    local hv = cam:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
    local lv = cam:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
    local h, w = math.abs(hv.Y - lv.Y), 0
    w = h / 2
    safeDrawEntity(cam, o, {
        enabled = dist <= CFG.espMaxDist, pal = "player",
        base = base, visColor = dot, seed = seed,
        checkVisible = CFG.espVisibleCheck,
        dist = dist, maxDist = CFG.espMaxDist, model = char,
        target = (targetModel == char), origin = origin, opened = false,
        fovCenter = fovC, fovRadius = fovR,
        ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1),
        geom = { x = raw.X - w / 2, y = hv.Y, w = w, h = h,
                 raw = raw, ok = ok, onScreen = ok and raw.Z > 0 },
    })
end

function SA.ApplyEspFx(cam)
    if not cam then return end
    SA.EspFxFrame = (SA.EspFxFrame or 0) + 1
    SA.EspPerf.fxPasses = (SA.EspPerf.fxPasses or 0) + 1
    SA.EspVisibleCount.players, SA.EspVisibleCount.npcs,
        SA.EspVisibleCount.crates = 0, 0, 0
    SA.CrateFovCount.inside, SA.CrateFovCount.outside = 0, 0
    SA.CrateFovCount.dots, SA.CrateFovCount.highlights = 0, 0
    local origin = tracerOrigin(cam)
    local myRoot = SA.PlayerRig(lp.Character)
    local myPos = myRoot and myRoot.Position or cam.CFrame.Position
    local targetModel = SA.Target and SA.Target.model or nil
    refreshTeamSet()
    refreshNearestSet(myPos, targetModel)
    local seed = 0
    -- shared with the FOV circle (10_fov_circle.lua) so off-screen arrows
    -- ride the exact same radius/centre the user sees
    local fovC = SA.AimPoint()
    local fovR = SA.FovRadius()

    if CFG.espEnabled then
        local drawn = 0
        local cap = CFG.perfMode and (SA.PerfEffectiveEntityCap
            and SA.PerfEffectiveEntityCap() or math.max(math.floor(CFG.perfMaxEntities or 40), 1))
            or math.huge
        for plr, o in pairs(espObjects) do
            seed = seed + 0.137
            if drawn >= cap or
                not SA.EspPassAllowed("player", plr.Character, nil, targetModel) then
                pcall(hideFx, o)
            else
                if not pcall(drawPlayerFx, plr, o, cam, myPos, targetModel,
                             origin, fovC, fovR, seed) then
                    pcall(hideFx, o)
                else
                    drawn = drawn + 1
                    SA.EspVisibleCount.players = SA.EspVisibleCount.players + 1
                end
            end
        end
    else for _, o in pairs(espObjects) do hideFx(o) end end

    if CFG.npcEspEnabled then
        for model, o in pairs(npcObjects) do
            seed = seed + 0.137
            local hum, hrp, head = fxNpcRig(o, model)
            if not (model.Parent and hum and hum.Health > 0 and hrp and head) then hideFx(o)
            else
                local dist = (myPos - hrp.Position).Magnitude
                local vis = false
                if CFG.npcVisibleCheck then
                    if type(o.vis) == "boolean" then vis = o.vis
                    else vis = SA.IsVisible(model, hrp.Position); o.vis = vis end
                end
                local base = CFG.npcVisibleCheck
                    and (vis and espC("npcVisible") or espC("npcHidden"))
                    or espC("npcFlat")
                local typeColor = nil
                if CFG.npcUseTypeColors then
                    local n = string.lower(model.Name)
                    typeColor = n:find("guard") and espC("npcGuard")
                        or (n:find("scav") and espC("npcScavenger")
                        or (n:find("soldier") and espC("npcSoldier") or nil))
                end
                local dot = CFG.npcVisibleCheck
                    and (vis and espC("npcVisible") or espC("npcHidden"))
                    or espC("npcFlat")
                local raw, ok = cam:WorldToViewportPoint(hrp.Position)
                local hv = cam:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
                local lv = cam:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
                local h = math.abs(hv.Y - lv.Y); local w = h / 2
                safeDrawEntity(cam, o, {
                    enabled = dist <= CFG.npcMaxDist, pal = "npc",
                    base = base, visColor = dot, seed = seed,
                    checkVisible = CFG.npcVisibleCheck, typeColor = typeColor,
                    dist = dist, maxDist = CFG.npcMaxDist, model = model,
                    target = (targetModel == model), origin = origin, opened = false,
                    fovCenter = fovC, fovRadius = fovR,
                    ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1),
                    geom = { x = raw.X - w / 2, y = hv.Y, w = w, h = h,
                             raw = raw, ok = ok, onScreen = ok and raw.Z > 0 },
                })
                if dist <= CFG.npcMaxDist then
                    SA.EspVisibleCount.npcs = SA.EspVisibleCount.npcs + 1
                end
            end
        end
    else for _, o in pairs(npcObjects) do hideFx(o) end end

    if CFG.crateEnabled then
        for _, o in pairs(crateObjects) do
            seed = seed + 0.137
            if not o.visible or not o.pos then hideFx(o)
            else
                local base = o.opened and espC("crateOpened")
                    or (o.kind == "Military" and espC("crateMilitary")
                    or (o.kind == "Elite" and espC("crateElite") or espC("crateLoot")))
                local raw, ok = cam:WorldToViewportPoint(o.pos)
                local tv = cam:WorldToViewportPoint(o.pos + Vector3.new(0, 2, 0))
                local bv = cam:WorldToViewportPoint(o.pos - Vector3.new(0, 2, 0))
                local h = math.max(math.abs(tv.Y - bv.Y), 18)
                local w = math.max(h * 0.9, 24)
                safeDrawEntity(cam, o, {
                    enabled = true, pal = "crate", base = base, visColor = base,
                    seed = seed, dist = o.dist or 0, maxDist = CFG.crateMaxDist,
                    model = nil, target = false, origin = origin,
                    opened = o.opened, ratio = 1, checkVisible = false,
                    fovCenter = fovC, fovRadius = fovR,
                    typeColor = base, keepNameColor = true,
                    geom = { x = raw.X - w / 2, y = tv.Y, w = w, h = h,
                             raw = raw, ok = ok, onScreen = ok and raw.Z > 0 },
                })
                SA.EspVisibleCount.crates = SA.EspVisibleCount.crates + 1
            end
        end
    else for _, o in pairs(crateObjects) do hideFx(o) end end
end
