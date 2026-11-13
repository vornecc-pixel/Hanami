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

-- drawEntity (18_esp_fx_draw.lua) already guards drawEntityInner and the
-- usage-mark finaliser. Calling it through another pcall added a third
-- per-entity protected call; this keeps the same isolation without the wrapper.
local function safeDrawEntity(cam, o, opt)
    if not opt or not opt.enabled then pcall(hideFx, o); return end
    startFxFrame(o)
    local ok = pcall(drawEntityInner, cam, o, opt)
    pcall(hideUnusedFx, o)
    if not ok then pcall(hideFx, o) end
end

-- FPS counters are shared with 19_render_loop.lua (throttled data refresh)
-- and survive re-execution for the session-long ESP perf state.
SA.EspPerf = SA.EspPerf or { fxPasses = 0, dataRefreshes = 0, dataSkips = 0 }
SA.EspFxFrame = SA.EspFxFrame or 0
SA.EspHiddenPass = { players = false, npcs = false, crates = false }
-- Ghost / stale-drawing cleanup counters (dead, teleported, streamed out,
-- character swapped). Read-only diagnostics, never drawn.
SA.EspGhostCleanup = SA.EspGhostCleanup or {
    hidden = 0, lastReason = nil, disposed = 0,
}
SA.EspGeomStats = SA.EspGeomStats or { cacheHits = 0, cacheMisses = 0,
    w2vCalls = 0, cameraKeyBuilds = 0 }

local ESP_HEAD_OFFSET   = Vector3.new(0, 0.5, 0)
local ESP_LOW_OFFSET    = Vector3.new(0, 3, 0)
local ESP_CRATE_TOP     = Vector3.new(0, 2, 0)
local ESP_CRATE_BOTTOM  = Vector3.new(0, 2, 0)

local function espNum(v)   -- 0.01 quantisation: the cheap rig-anchor key
    return tostring(math.floor((tonumber(v) or 0) * 100 + 0.5))
end

local function espVecKey(v)
    if not v then v = Vector3.new(0, 0, 0) end
    return espNum(v.X) .. "," .. espNum(v.Y) .. "," .. espNum(v.Z)
end

local espCamSig = { has = false, key = "" }

-- The camera signature is identical for every entity in one frame. Build
-- its string once instead of repeating a CFrame rotation pcall and ~11
-- number-to-string conversions for every player / NPC / crate.
local function espCameraKey(cam)
    local cf = cam.CFrame
    local cp = cf and cf.Position or Vector3.new(0, 0, 0)
    local look = cf and cf.LookVector or Vector3.new(0, 0, 0)
    local up = cf and cf.UpVector or Vector3.new(0, 0, 0)
    local vp = cam.ViewportSize or Vector2.new(1280, 720)
    local fov = tonumber(cam.FieldOfView) or 0
    local sig = espCamSig
    local cfChanged = sig.cf ~= cf
    if sig.has and not cfChanged
        and sig.cpX == cp.X and sig.cpY == cp.Y and sig.cpZ == cp.Z
        and sig.lx == look.X and sig.ly == look.Y and sig.lz == look.Z
        and sig.ux == up.X and sig.uy == up.Y and sig.uz == up.Z
        and sig.vx == vp.X and sig.vy == vp.Y and sig.fov == fov then
        return sig.key
    end
    -- LookVector / UpVector cover real Roblox CFrames; the Euler fallback
    -- also catches a rotation-only change when those axes are mocked flat.
    local rx, ry, rz = 0, 0, 0
    if cf and cf.ToEulerAnglesXYZ then
        pcall(function() rx, ry, rz = cf:ToEulerAnglesXYZ() end)
    end
    sig.has, sig.cf = true, cf
    sig.cpX, sig.cpY, sig.cpZ = cp.X, cp.Y, cp.Z
    sig.lx, sig.ly, sig.lz = look.X, look.Y, look.Z
    sig.ux, sig.uy, sig.uz = up.X, up.Y, up.Z
    sig.vx, sig.vy, sig.fov = vp.X, vp.Y, fov
    -- PRECISION: espNum() rounds to 0.01, which on a unit look vector is
    -- asin(0.01) = 0.57 degrees of camera rotation silently treated as "no
    -- change". At 720p / 70 deg that is ~6 px of stale box position on
    -- every slow sweep, snapping into place whenever the key finally
    -- ticks over — precisely the "ESP drifts away while you look at it,
    -- then comes back" report. Camera keys therefore use a 1e-6
    -- quantisation (0.00006 deg, well under a pixel) instead of 0.01.
    sig.key = SA.EspKey6(cp) .. "|" .. SA.EspKey6(look) .. "|"
        .. SA.EspKey6(up) .. "|" .. SA.EspKey6({ X = rx, Y = ry, Z = rz })
        .. "|" .. SA.EspNum6(vp.X) .. "," .. SA.EspNum6(vp.Y)
        .. "|" .. SA.EspNum6(fov)
    local st = SA.EspGeomStats
    st.cameraKeyBuilds = (st.cameraKeyBuilds or 0) + 1
    return sig.key
end

-- Static crates keep the same anchor for their whole lifetime; moving rigs
-- still invalidate as soon as root / head positions change by > 0.01 studs.
local function espAnchorKey(o, rootPos, headPos, kindName)
    local hp = headPos or rootPos
    local a = o.geomAnchor
    if a and a.kind == kindName and a.rx == rootPos.X and a.ry == rootPos.Y
        and a.rz == rootPos.Z and a.hx == hp.X and a.hy == hp.Y
        and a.hz == hp.Z then
        return a.key
    end
    local key = kindName .. "|" .. espVecKey(rootPos) .. "|" .. espVecKey(hp)
    o.geomAnchor = { kind = kindName, key = key,
        rx = rootPos.X, ry = rootPos.Y, rz = rootPos.Z,
        hx = hp.X, hy = hp.Y, hz = hp.Z }
    return key
end

function SA.EspGeomReset()
    SA.EspGeomStats = { cacheHits = 0, cacheMisses = 0,
        w2vCalls = 0, cameraKeyBuilds = 0 }
    return true
end

function SA.EspGeomState()
    local s = SA.EspGeomStats
    return { cacheHits = s.cacheHits, cacheMisses = s.cacheMisses,
        w2vCalls = s.w2vCalls, savedW2vCalls = s.cacheHits * 3,
        cameraKeyBuilds = s.cameraKeyBuilds or 0 }
end

function SA.EspGeomInvalidate()
    for _, o in pairs(espObjects or {}) do
        o.geomKey, o.geomCache, o.geomAnchor = nil, nil, nil
        o.geomForceFresh = false
    end
    for _, o in pairs(npcObjects or {}) do
        o.geomKey, o.geomCache, o.geomAnchor = nil, nil, nil
        o.geomForceFresh = false
    end
    for _, o in pairs(crateObjects or {}) do
        o.geomKey, o.geomCache, o.geomAnchor = nil, nil, nil
        o.geomForceFresh = false
    end
    espCamSig.has = false
    espCamSig.fxKey = nil
    return true
end

-- One projection set per entity per camera / rig change. Both the throttled
-- BillboardGui refresh and the unified FX pass reuse the same cached geom.
function SA.EspGeom(o, cam, rootPos, headPos, kind)
    if not o or not cam or not rootPos then return nil end
    local kindName = tostring(kind or "player")
    local key = espAnchorKey(o, rootPos, headPos, kindName) .. "|"
        .. espCameraKey(cam)
    local stats = SA.EspGeomStats
    if o.geomKey == key and o.geomCache then
        stats.cacheHits = stats.cacheHits + 1
        return o.geomCache
    end
    stats.cacheMisses = stats.cacheMisses + 1
    local headWorld, lowWorld = nil, nil
    if kindName == "crate" then
        headWorld = rootPos + ESP_CRATE_TOP
        lowWorld = rootPos - ESP_CRATE_BOTTOM
    else
        headWorld = (headPos or rootPos) + ESP_HEAD_OFFSET
        lowWorld = rootPos - ESP_LOW_OFFSET
    end
    local raw, ok = cam:WorldToViewportPoint(rootPos)
    local hv = cam:WorldToViewportPoint(headWorld)
    local lv = cam:WorldToViewportPoint(lowWorld)
    stats.w2vCalls = stats.w2vCalls + 3
    local h, w = 0, 0
    if kindName == "crate" then
        h = math.max(math.abs(hv.Y - lv.Y), 18)
        w = math.max(h * 0.9, 24)
    else
        -- A far target is a handful of pixels tall, and `h` had NO floor:
        -- at 200+ studs the box degenerated to a sliver (or to 0 px when
        -- the two projections rounded together) with the text stacked on
        -- top of it. Clamp like the crate path so a distant player still
        -- gets a readable, correctly ordered tag.
        h = math.max(math.abs(hv.Y - lv.Y), 18)
        w = math.max(h / 2, 12)
    end
    local z = tonumber(raw.Z) or 0
    local vp = cam.ViewportSize or Vector2.new(1280, 720)
    local margin = 34
    -- A target in front of the camera but outside the viewport is OFF-SCREEN.
    -- Treat it as such so text, boxes and chams are hidden immediately on a
    -- fast turn instead of keeping their last on-screen position.
    local inView = ok == true and z > 0
        and raw.X >= -margin and raw.X <= vp.X + margin
        and raw.Y >= -margin and raw.Y <= vp.Y + margin
    local g = { x = raw.X - w / 2, y = hv.Y, w = w, h = h,
        raw = raw, ok = ok, onScreen = inView }
    o.geomKey, o.geomCache = key, g
    return g
end

-- ── BETTER: ESP decluttering / FPS pass ──────────────────────────────
SA.EspVisibleCount = { players = 0, npcs = 0, crates = 0 }
SA.CrateFovCount = SA.CrateFovCount
    or { inside = 0, outside = 0, dots = 0, highlights = 0 }
local espNearestSet = {}
local espNearBuilt, espNearCount, espNearFrame = false, nil, -1
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
    if aimModel.Character then espNearestSet[aimModel.Character] = true end
end

local function refreshNearestSet(myPos, aimModel)
    -- Drop stale aim-target slots every frame; only the live target keeps
    -- the full-rate geometry path. With Only Nearest N OFF this is the whole
    -- set, so a target that left the FOV cannot stay "stuck" forever.
    if not CFG.espOnlyNearest then
        espNearestSet = {}
        addAimToNearest(aimModel)
        return
    end
    local frame = SA.EspFxFrame or 0
    if espNearBuilt and espNearCount == CFG.espNearestCount
        and (frame - espNearFrame) < espDataInterval() then
        addAimToNearest(aimModel)
        return
    end
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
    espNearBuilt, espNearCount, espNearFrame = true, CFG.espNearestCount, frame
end

-- Build ONE character -> teammate map per DATA INTERVAL. The old code
-- called Players:GetPlayers() inside EspPassAllowed for every player
-- (O(n^2)); rebuilding that map on every FX frame was redundant too.
local function refreshTeamSet()
    local mode = CFG.espTeamMode or "All"
    local frame = SA.EspFxFrame or 0
    if espTeamSetMode == mode
        and (frame - espTeamSetFrame) < espDataInterval() then return end
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
    -- NOTE: the aim target is NOT injected into the nearest set here.
    -- addAimToNearest() already gives it a guaranteed slot, and mutating
    -- the set from a predicate that runs for every player made the set
    -- depend on pairs() order (a different member looked "nearest" on
    -- every frame, which defeated geometry slicing while silent aim /
    -- snapline were ON).
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

function SA.EspFovState()
    return {
        center = SA.AimPoint and SA.AimPoint() or nil,
        radius = SA.FovRadius and SA.FovRadius() or nil,
        mode = SA.FovMode and SA.FovMode() or "Pixels",
        degrees = SA.FovDegrees and SA.FovDegrees() or nil,
        signature = SA.EspDrawSignature or "",
        transitions = SA.EspFovTransitions or 0,
        reference = "Mouse / crosshair",
    }
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

-- Ghost / stale-ESP cleanup for ONE player object. Returns true when the
-- entity must not be drawn at all this frame.
--
-- Symptom it fixes: a player died, was teleported out of range or STREAMED
-- OUT, and their box / name / tracer stayed frozen on screen (frequently
-- at the old position) because the FX pass had no dead / teleport /
-- stream-out branch — drawPlayerFx only hid when the character CHANGED or
-- the rig vanished. Everything below hides the entity's own drawings AND
-- drops a pooled instance cache that belonged to the old character.
local function playerFxStale(plr, o, char)
    if not plr or not plr.Parent then return true end
    if not char or not char.Parent then return true end
    if o.char and o.char ~= char then return true end
    -- A character that is mid-removal (streaming out / respawn) can keep
    -- its parts parented for a frame while its Humanoid is gone. Never
    -- draw from that state: it is exactly the "ghost box" case.
    if not char:FindFirstChildOfClass("Humanoid") then return true end
    return false
end

local function stalePlayerCleanup(o, why)
    if not o then return end
    pcall(hideFx, o)
    -- The pooled draws / legacy lines belonged to the OLD character, so
    -- reusing them on the respawned rig kept stale colours / thickness.
    o.fxUsed, o.linesUsed, o.instApplied = nil, nil, nil
    o.espFovState, o.fovKey = nil, nil
    o.geomKey, o.geomCache, o.geomAnchor, o.geomForceFresh = nil, nil, nil, nil
    o.vis = nil
    local st = SA.EspGhostCleanup
    if st then
        st.hidden = st.hidden + 1
        st.lastReason = tostring(why or "stale")
    end
    return true
end

local function drawPlayerFx(plr, o, cam, myPos, targetModel, origin, fovC, fovR,
                            seed, cachedGeom)
    local char = plr.Character
    if playerFxStale(plr, o, char) then
        stalePlayerCleanup(o, char and "character changed" or "no character")
        return
    end
    local hrp, head, hum = fxPlayerRig(o, char)
    if not (hum and hrp and head) then
        stalePlayerCleanup(o, "incomplete rig")
        return
    end
    -- DEAD: the body can stay parented for several seconds after a kill.
    -- Hide immediately instead of leaving a frozen box on the corpse.
    if (tonumber(hum.Health) or 0) <= 0 then
        stalePlayerCleanup(o, "dead")
        return
    end
    local dist = (myPos - hrp.Position).Magnitude
    -- TELEPORT / STREAM-OUT: a player who is suddenly thousands of studs
    -- away (or whose root part teleports) must lose every drawing in the
    -- same frame. Without this the last projected box stayed on screen and
    -- "followed" the player only after the next throttled data refresh.
    if dist > (tonumber(CFG.espMaxDist) or 5000) then
        stalePlayerCleanup(o, "out of range")
        return
    end
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
    local g = cachedGeom or SA.EspGeom(o, cam, hrp.Position, head.Position, "player")
    if not g then stalePlayerCleanup(o, "no projection"); return end
    safeDrawEntity(cam, o, {
        enabled = dist <= CFG.espMaxDist, pal = "player",
        base = base, visColor = dot, seed = seed,
        checkVisible = CFG.espVisibleCheck,
        dist = dist, maxDist = CFG.espMaxDist, model = char,
        target = (targetModel == char), origin = origin, opened = false,
        fovCenter = fovC, fovRadius = fovR,
        ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1),
        geom = g,
    })
end

local function drawNpcFx(model, o, cam, myPos, targetModel, origin,
                         fovC, fovR, seed, cachedGeom)
    local hum, hrp, head = fxNpcRig(o, model)
    if not (model.Parent and hum and hum.Health > 0 and hrp and head) then
        -- Dead / streamed-out / half-replicated NPC: hide and drop the
        -- stale cache so a recycled rig cannot inherit old colours.
        pcall(hideFx, o)
        o.fxUsed, o.linesUsed, o.instApplied = nil, nil, nil
        o.geomKey, o.geomCache, o.geomAnchor = nil, nil, nil
        return false
    end
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
    -- Out of range: hide and drop the cached projection in the SAME frame
    -- (a sliced entity would otherwise reuse the last screen position).
    if dist > (tonumber(CFG.npcMaxDist) or 2000) then
        pcall(hideFx, o)
        o.geomKey, o.geomCache, o.geomAnchor = nil, nil, nil
        o.geomForceFresh = true
        return false
    end
    local g = cachedGeom or SA.EspGeom(o, cam, hrp.Position, head.Position, "npc")
    if not g then pcall(hideFx, o); return false end
    safeDrawEntity(cam, o, {
        enabled = dist <= CFG.npcMaxDist, pal = "npc",
        base = base, visColor = dot, seed = seed,
        checkVisible = CFG.npcVisibleCheck, typeColor = typeColor,
        dist = dist, maxDist = CFG.npcMaxDist, model = model,
        target = (targetModel == model), origin = origin, opened = false,
        fovCenter = fovC, fovRadius = fovR,
        ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1),
        geom = g,
    })
    return dist <= CFG.npcMaxDist
end

local function drawCrateFx(o, cam, origin, fovC, fovR, seed, cachedGeom)
    if not o.visible or not o.pos then pcall(hideFx, o); return end
    local base = o.opened and espC("crateOpened")
        or (o.kind == "Military" and espC("crateMilitary")
        or (o.kind == "Elite" and espC("crateElite") or espC("crateLoot")))
    local g = cachedGeom or SA.EspGeom(o, cam, o.pos, o.pos, "crate")
    if not g then pcall(hideFx, o); return end
    -- Classify BEFORE styling so this frame's branch and the counters
    -- agree, and a circle crossing is applied in the frame it happens.
    if CFG.crateFovAware == true then
        crateFovClassify(o, g)
    else
        o.crateInside, o.crateOnScreen = nil, nil
    end
    safeDrawEntity(cam, o, {
        enabled = true, pal = "crate", base = base, visColor = base,
        seed = seed, dist = o.dist or 0, maxDist = CFG.crateMaxDist,
        model = nil, target = false, origin = origin,
        opened = o.opened, ratio = 1, checkVisible = false,
        fovCenter = fovC, fovRadius = fovR,
        typeColor = base, keepNameColor = true,
        geom = g,
    })
end

-- One hidden pass per object, not one per kind. The old version bailed out
-- as soon as SA.EspHiddenPass[kind] was true, so an object that appeared
-- AFTER the first pass (a build finishing late, a rig that streamed in, a
-- pooled draw re-used by another feature) kept its last Visible = true and
-- stayed on screen with ESP OFF — the classic ghost drawing. Each object
-- now records the frame it was hidden and only pays for hiding once.
local function hideAllOnce(kind, objects)
    local n = 0
    if type(hideFx) == "function" then
        for _, o in pairs(objects) do
            -- o.fxHidden is cleared by startFxFrame() on every drawn pass,
            -- so an object that shows up later is still hidden exactly
            -- once. Steady-state cost is one boolean read per object.
            if o and not o.fxHidden then
                pcall(hideFx, o)
                o.fxHidden = true
                n = n + 1
            end
        end
    end
    if n > 0 then
        SA.EspPerf.geometryHiddenPasses =
            (SA.EspPerf.geometryHiddenPasses or 0) + n
    end
    SA.EspHiddenPass[kind] = true
    return n
end

-- ONE sweep for a real style change (draw flag / circle radius / viewport
-- mode). It replaces the old behaviour where every entity noticed the
-- changed signature BY ITSELF and each ran hideFx + overlay cleanup +
-- geomForceFresh on the same frame. Same visible result (stale pooled
-- draws and legacy labels are erased, then redrawn from fresh geometry),
-- but the cleanup cost is paid once per toggle instead of once per
-- entity per frame — the stutter while silent aim / snapline were ON.
function SA.EspStyleSweep(reason)
    local n = 0
    local lists = { espObjects or {}, npcObjects or {}, crateObjects or {} }
    for _, list in ipairs(lists) do
        for _, o in pairs(list) do
            if o then
                pcall(function()
                    o.espFovState = nil
                    o.fovKey = nil
                    if type(hideFx) == "function" then hideFx(o) end
                    if SA.EspHideDuplicateOverlays then
                        SA.EspHideDuplicateOverlays(o, o.char)
                    end
                    startFxFrame(o)
                end)
                o.geomKey, o.geomCache, o.geomAnchor = nil, nil, nil
                o.geomForceFresh = true
                n = n + 1
            end
        end
    end
    SA.EspPerf.styleSweeps = (SA.EspPerf.styleSweeps or 0) + 1
    SA.EspPerf.styleSweepObjects = (SA.EspPerf.styleSweepObjects or 0) + n
    SA.EspLastStyleSweep = { reason = tostring(reason or "style"),
        objects = n, frame = SA.EspFxFrame or 0 }
    return n
end

local function espStyleSweep()
    return SA.EspStyleSweep("style")
end

-- The style sweep runs ONCE, at the top of the frame and BEFORE any
-- entity is drawn, so the frame that reacts to a toggle is already
-- complete: every stale draw is erased first, then every entity is
-- redrawn from fresh geometry in the same pass.
local pendingStyleSweep = nil
-- Crate-only pooling cleanup. Kept separate so a crate toggle can never
-- invalidate a player object's geometry or drawings.
local pendingCrateSweep = nil

-- FOV / viewport transitions are handled PER ENTITY by the state key in
-- 18_esp_fx_draw.lua, and style changes by the one-shot SA.EspStyleSweep.
-- Nothing here invalidates every geometry cache: doing that per entity is
-- exactly what used to thrash the whole pass while silent aim was ON.

function SA.ApplyEspFx(cam)
    if not cam then return end
    local camKey = espCameraKey(cam)
    local cameraTurned = espCamSig.fxKey ~= camKey
    espCamSig.fxKey = camKey
    SA.EspFxFrame = (SA.EspFxFrame or 0) + 1
    SA.EspPerf.fxPasses = (SA.EspPerf.fxPasses or 0) + 1
    SA.EspPerf.geometryUpdates = SA.EspPerf.geometryUpdates or 0
    SA.EspPerf.geometrySkips = SA.EspPerf.geometrySkips or 0
    SA.EspPerf.geometryHiddenPasses = SA.EspPerf.geometryHiddenPasses or 0
    SA.EspVisibleCount.players, SA.EspVisibleCount.npcs,
        SA.EspVisibleCount.crates = 0, 0, 0
    SA.CrateFovCount.inside, SA.CrateFovCount.outside = 0, 0
    SA.CrateFovCount.dots, SA.CrateFovCount.highlights = 0, 0

    local playerOn = CFG.espEnabled == true
    local npcOn = CFG.npcEspEnabled == true
    local crateOn = CFG.crateEnabled == true
    if playerOn then SA.EspHiddenPass.players = false
    else hideAllOnce("players", espObjects) end
    if npcOn then SA.EspHiddenPass.npcs = false
    else hideAllOnce("npcs", npcObjects) end
    if crateOn then SA.EspHiddenPass.crates = false
    else hideAllOnce("crates", crateObjects) end
    if not (playerOn or npcOn or crateOn) then return end

    local origin = tracerOrigin(cam)
    local myRoot = SA.PlayerRig(lp.Character)
    local myPos = myRoot and myRoot.Position or cam.CFrame.Position
    local targetModel = SA.Target and SA.Target.model or nil
    refreshTeamSet()
    refreshNearestSet(myPos, targetModel)
    local seed = 0
    local fovC = SA.AimPoint()
    local fovR = SA.FovRadius()
    SA.EspFovTransitions = SA.EspFovTransitions or 0
    -- ── DRAW SIGNATURE (toggles only, NEVER the live target) ─────────
    -- Changing the circle radius or a draw style flag needs ONE cleanup
    -- pass; ordinary mouse movement does NOT, because arrows/tracers are
    -- repositioned from the current fovC every frame.
    --
    -- BUG FIX (ESP stuck / stuttering with Gun Silent Aim or Snapline ON):
    -- this signature used to contain the live-target boolean. The
    -- aim target appears / disappears many times per second (enter-leave
    -- the FOV, hit-chance roll, pickBestTarget returning nil for one
    -- frame), so that flag flipped constantly. Every flip changed
    -- SA.EspDrawSignature, which is folded into each entity's state key
    -- in 18_esp_fx_draw.lua — so EVERY entity ran a full
    -- hideFx + duplicate-overlay cleanup + fresh-geometry rebuild, every
    -- frame or two, while silent aim / snapline were ON. That was the
    -- freeze. The target is now handled per entity (highlight colour and
    -- usage marks) instead of through a global transition.
    local drawSig = table.concat({
        tostring(CFG.fov), tostring(CFG.fovMode), tostring(CFG.fovDegrees),
        espNum(fovR),
        tostring(CFG.masterEnabled), tostring(CFG.gunEnabled),
        tostring(CFG.snapLineEnabled), tostring(CFG.showFov),
        tostring(CFG.fovFilled),
        tostring(CFG.espShowOffscreen), tostring(CFG.espArrowFOV),
        tostring(CFG.espShowTracer), tostring(CFG.espTracerOrigin),
        tostring(CFG.espShowBox), tostring(CFG.espCornerBox),
        tostring(CFG.espCleanMode), tostring(CFG.espShowFill),
        tostring(CFG.espShowOutline), tostring(CFG.espShowSkeleton),
        tostring(CFG.espShowHeadDot), tostring(CFG.espShowName),
        tostring(CFG.espShowDist), tostring(CFG.espShowHealth),
        tostring(CFG.espShowTool), tostring(CFG.espShowState),
        tostring(CFG.espTextOutline), tostring(CFG.espTagBackdrop),
        tostring(CFG.espTagSide), tostring(CFG.espHighlightTarget),
        -- crateHighlight is folded in below only for the CRATE objects;
        -- see the crate-only sweep. crateFovAware is NOT here on purpose:
        -- -- it changes crate drawing alone, and putting it in the shared
        -- signature made every PLAYER object hide + rebuild whenever the
        -- crate mode was toggled (the "crate FOV turns my player ESP off"
        -- report), because the sweep is global.
    }, "|")
    if SA.EspDrawSignature ~= drawSig then
        -- ONE sweep over the whole ESP set for a real toggle change, not
        -- one sweep per entity (the old per-entity transition storm).
        SA.EspDrawSignature = drawSig
        SA.EspFovTransitions = SA.EspFovTransitions + 1
        pendingStyleSweep = "draw signature"
    end
    -- ONE cleanup for the whole frame (before the entity loops below).
    -- The old code folded the same signature into EVERY entity's state
    -- key, so a single toggle — or the live aim target appearing in the
    -- signature — rebuilt every entity separately, every frame.
    if pendingStyleSweep then
        local why = pendingStyleSweep
        pendingStyleSweep = nil
        pcall(SA.EspStyleSweep, why)
    end
    -- CRATE-ONLY settings get a crate-only sweep: a pooled crate draw is
    -- recycled, but no PLAYER object is touched. This is what keeps the
    -- crate FOV / chams toggles from resetting the player ESP.
    local crateSig = tostring(CFG.crateFovAware) .. "|"
        .. tostring(CFG.crateHighlight) .. "|"
        .. tostring(CFG.crateShowMilitary) .. "|"
        .. tostring(CFG.crateShowElite) .. "|"
        .. tostring(CFG.crateShowLoot) .. "|"
        .. tostring(CFG.crateShowOpened)
    if SA.EspCrateDrawSignature ~= crateSig then
        SA.EspCrateDrawSignature = crateSig
        pendingCrateSweep = "crate style"
    end
    if pendingCrateSweep then
        pendingCrateSweep = nil
        pcall(SA.EspCrateSweep)
    end
    local geomBudget = SA.EspGeometryBudget and SA.EspGeometryBudget()
        or { stride = 1, bucket = 0 }
    -- Cached screen coordinates are only valid while the camera is static.
    -- On a turn, style every entity from fresh geometry for this one frame;
    -- slicing resumes on the next unchanged camera signature.
    local stride = cameraTurned and 1
        or math.clamp(tonumber(geomBudget.stride) or 1, 1, 4)
    local bucket = tonumber(geomBudget.bucket) or 0
    local geomIndex = 0
    -- Aim target and nearest-N entities stay on the full-rate path even
    -- when slicing is active. Only the remaining entities rotate buckets,
    -- so the entity the user is actually aiming at never waits 4 frames.
    --
    -- Slicing no longer depends on WHO the aim target is this frame. The
    -- old code also treated every espNearestSet member as priority, and
    -- addAimToNearest() inserted the aim target into that set — so with
    -- silent aim / snapline ON the highlighted entity changed buckets
    -- constantly and the stride pattern became useless (every entity
    -- looked "priority" on a rotating basis, i.e. no slicing at all,
    -- which is the stutter reported with those features ON).
    local function dueGeometry(model, isTarget, o)
        if o and o.geomForceFresh then
            o.geomForceFresh = false
            return true
        end
        if stride <= 1 or isTarget then return true end
        if not o or not o.geomCache then return true end
        geomIndex = geomIndex + 1
        -- Nearest-N members are sliced like everyone else, but they are
        -- still guaranteed a refresh inside the stride window because the
        -- bucket rotates with SA.EspFxFrame.
        return (geomIndex % stride) == bucket
    end

    if playerOn then
        local eligible = 0
        local cap = CFG.perfMode and (SA.PerfEffectiveEntityCap
            and SA.PerfEffectiveEntityCap() or math.max(math.floor(CFG.perfMaxEntities or 40), 1))
            or math.huge
        for plr, o in pairs(espObjects) do
            seed = seed + 0.137
            local allowed = eligible < cap
                and SA.EspPassAllowed("player", plr.Character, nil, targetModel)
            if not allowed then
                pcall(hideFx, o)
            else
                eligible = eligible + 1
                local char = plr.Character
                if not dueGeometry(char, targetModel == char, o) then
                    -- Static-camera skip: reuse the cached projection but
                    -- still run the FX pass so legacy BillboardGui labels,
                    -- off-screen boxes and unused pooled draws cannot stick.
                    if not pcall(drawPlayerFx, plr, o, cam, myPos, targetModel,
                                 origin, fovC, fovR, seed, o.geomCache) then
                        pcall(hideFx, o)
                    else
                        SA.EspVisibleCount.players = SA.EspVisibleCount.players + 1
                    end
                    SA.EspPerf.geometrySkips = SA.EspPerf.geometrySkips + 1
                else
                    if not pcall(drawPlayerFx, plr, o, cam, myPos, targetModel,
                                 origin, fovC, fovR, seed) then
                        pcall(hideFx, o)
                    else
                        SA.EspVisibleCount.players = SA.EspVisibleCount.players + 1
                        SA.EspPerf.geometryUpdates = SA.EspPerf.geometryUpdates + 1
                    end
                end
            end
        end
    end

    if npcOn then
        for model, o in pairs(npcObjects) do
            seed = seed + 0.137
            local isTarget = targetModel == model
            local skip = not dueGeometry(model, isTarget, o)
            local ok, visible = pcall(drawNpcFx, model, o, cam, myPos,
                targetModel, origin, fovC, fovR, seed,
                skip and o.geomCache or nil)
            if not ok then pcall(hideFx, o)
            elseif visible then
                SA.EspVisibleCount.npcs = SA.EspVisibleCount.npcs + 1
            end
            if skip then
                SA.EspPerf.geometrySkips = SA.EspPerf.geometrySkips + 1
            else
                SA.EspPerf.geometryUpdates = SA.EspPerf.geometryUpdates + 1
            end
        end
    end

    if crateOn then
        local crateFovOn = CFG.crateFovAware == true
        local crateCounts = SA.CrateFovCount
        for _, o in pairs(crateObjects) do
            seed = seed + 0.137
            local skip = not dueGeometry(nil, false, o)
            local ok = pcall(drawCrateFx, o, cam, origin, fovC, fovR, seed,
                skip and o.geomCache or nil)
            if not ok then pcall(hideFx, o)
            elseif o.visible and o.pos then
                SA.EspVisibleCount.crates = SA.EspVisibleCount.crates + 1
            end
            -- Counters come from the crate's OWN cached membership, so
            -- they cost one boolean read and no projection. Nothing is
            -- projected a second time just to feed a counter.
            if crateFovOn and o.visible then
                if o.crateInside then
                    crateCounts.inside = crateCounts.inside + 1
                    if o.highlight and o.highlight.Enabled then
                        crateCounts.highlights = crateCounts.highlights + 1
                    end
                else
                    crateCounts.outside = crateCounts.outside + 1
                    if o.fx and o.fx.cratefovdot and o.fx.cratefovdot.Visible then
                        crateCounts.dots = crateCounts.dots + 1
                    end
                end
            end
            if skip then
                SA.EspPerf.geometrySkips = SA.EspPerf.geometrySkips + 1
            else
                SA.EspPerf.geometryUpdates = SA.EspPerf.geometryUpdates + 1
            end
        end
    end

end
