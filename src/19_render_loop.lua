-- ==================================================================
-- Hanami / 19_render_loop.lua — Master player/NPC/crate ESP render loop
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- MASTER RENDER LOOP (ESP + Crates + FX)
-- Crates are re-discovered from the live registry (built by the yielding
-- walker, not a GetDescendants() call), but at most MAX_BUILDS new
-- BillboardGuis/Highlights are created per frame. Building dozens of
-- Instances in one frame was the other half of the periodic stutter.
-- Crate refresh runs at ~20 Hz (crates don't move); player/NPC boxes
-- still update every frame.
--
-- BUILD QUEUE FIX ("some players show, some don't"):
-- The old loop started at index 1 every frame and incremented `built`
-- even when buildESP() returned early (no character, dead, custom rig,
-- parts still streaming in). Two permanently unbuildable players at the
-- front of GetPlayers() therefore consumed both slots FOREVER and no
-- player after them was ever built. Now only successful builds count,
-- and the starting index rotates each frame, so neither a failed build
-- nor a stable list order can starve anyone.
--
-- Each ESP pass is also pcall-guarded: an error in the NPC or crate pass
-- used to abort the whole RenderStepped callback (including the FX pass
-- that actually draws the player boxes).
-- ────────────────────────────────────────────────────────────────────

local MAX_BUILDS = 2
local MAX_ATTEMPTS = 10
local renderFrame = 0
local renderErrCount = 0

-- ── BETTER: Performance Mode + 60 FPS frame budget ──────────────────
-- Adaptive build pacing (only new ESP objects are built every N ms),
-- a hard cap on objects styled per frame, and a rolling FPS estimate.
-- Geometry styling runs every frame while the frame is within budget; slow
-- frames slice only low-priority entities. Name / weapon / state text and
-- the legacy BillboardGui lines are refreshed at the user's data interval.
-- When a RenderStepped frame is already slower than 60 FPS, new builds and
-- data refreshes are spread out so ESP does not add another spike on top.
local perfFrames, perfFps, perfWindow = 0, 0, tick()
local ESP_TARGET_FPS = 60
local ESP_TARGET_MS = 1000 / ESP_TARGET_FPS
local espLastDt = 1 / ESP_TARGET_FPS
local espDataAccum, espBuildAccum = 0, 0

-- ADAPTIVE rebuild pacing: when FPS drops, spread new-ESP builds over
-- a longer window; when the game is smooth, stay at the user's fast rate.
function SA.PerfEffectiveRebuildMs()
    if CFG.perfMode ~= true then return 0 end
    local base = tonumber(CFG.perfEspRebuildMs) or 100
    if perfFps <= 0 then return base end
    return math.clamp(base * 60 / math.max(perfFps, 20), 16, 500)
end

function SA.PerfEffectiveEntityCap()
    if CFG.perfMode ~= true then return math.huge end
    local fps = perfFps > 0 and perfFps or 60
    return math.max(1, math.floor((tonumber(CFG.perfMaxEntities) or 40)
        * math.clamp(fps / 60, 0.5, 1)))
end

-- Adaptive geometry slicing: a healthy frame styles every entity; a slow
-- frame styles a rotating bucket instead of adding a full ESP pass on top.
-- The existing master RenderStepped callback owns this work; no second loop.
function SA.EspGeometryBudget()
    local dtMs = math.max((tonumber(espLastDt) or 1 / ESP_TARGET_FPS) * 1000, 0)
    local fps = perfFps > 0 and perfFps or ESP_TARGET_FPS
    -- dt is the authoritative signal for the current frame. The rolling
    -- FPS estimate only biases stride when Performance Mode is explicitly
    -- ON, so a stale / mock-clock FPS sample cannot slice a healthy frame.
    local over = dtMs > ESP_TARGET_MS * 1.1
        or (CFG.perfMode == true and fps > 0 and fps < 50)
    local ratio = dtMs / ESP_TARGET_MS
    if CFG.perfMode == true and fps > 0 then
        ratio = math.max(ratio, ESP_TARGET_FPS / math.max(fps, 1))
    end
    local stride = 1
    if CFG.perfMode == true then
        stride = math.ceil(ratio)
    elseif over then
        stride = math.max(2, math.ceil(ratio / 1.35))
    end
    stride = math.clamp(stride, 1, 4)
    local frame = SA.EspFxFrame or 0
    return {
        stride = stride,
        bucket = frame % stride,
        overBudget = over,
        fps = fps,
        lastDtMs = dtMs,
        targetFps = ESP_TARGET_FPS,
        entityCap = CFG.perfMode == true and SA.PerfEffectiveEntityCap()
            or math.huge,
    }
end

-- ESP text / legacy-line refresh is throttled in FRAMES, not tick(), so a
-- 60 Hz client with the default 100 ms interval refreshes every 6 frames.
-- A new build still forces an immediate refresh for that entity list.
function SA.EspDataIntervalFrames()
    local ms = tonumber(CFG.espDataRefreshMs) or 100
    return math.clamp(math.floor(ms * 60 / 1000 + 0.5), 1, 30)
end

function SA.EspFrameBudget()
    local dtMs = math.max(tonumber(espLastDt) or 1 / ESP_TARGET_FPS, 0) * 1000
    local over = dtMs > ESP_TARGET_MS * 1.1
    local dataMs = math.clamp(tonumber(CFG.espDataRefreshMs) or 100, 16, 500)
    local adaptiveDataMs = dataMs
    if over then
        adaptiveDataMs = math.min(math.max(dataMs * 1.5, dtMs * 3), 250)
    end
    local buildMs = 0
    if CFG.perfMode == true then
        buildMs = SA.PerfEffectiveRebuildMs()
    elseif over then
        buildMs = math.min(math.max(ESP_TARGET_MS * 2, dtMs * 2), 100)
    end
    local p = SA.EspPerf or {}
    local geom = SA.EspGeometryBudget()
    return {
        targetFps = ESP_TARGET_FPS,
        targetMs = ESP_TARGET_MS,
        lastDtMs = dtMs,
        overBudget = over,
        dataIntervalMs = dataMs,
        adaptiveDataIntervalMs = adaptiveDataMs,
        buildIntervalMs = buildMs,
        dataAccumMs = espDataAccum,
        buildAccumMs = espBuildAccum,
        budgetSkips = p.budgetSkips or 0,
        buildSkips = p.buildSkips or 0,
        geometryStride = geom.stride,
        geometryBucket = geom.bucket,
        geometryFps = geom.fps,
        geometryLastDtMs = geom.lastDtMs,
        geometryBudget = geom,
    }
end

function SA.EspFrameBudgetReset()
    espLastDt = 1 / ESP_TARGET_FPS
    espDataAccum, espBuildAccum = 0, 0
    local p = SA.EspPerf or {}
    p.budgetSkips, p.buildSkips = 0, 0
    p.geometryUpdates, p.geometrySkips = 0, 0
    p.geometryHiddenPasses = 0
    if SA.EspGeomReset then SA.EspGeomReset() end
    return true
end


function SA.EspPerfState()
    local p = SA.EspPerf or {}
    local fx = p.fxPasses or 0
    local data = p.dataRefreshes or 0
    return {
        fxPasses = fx,
        dataRefreshes = data,
        dataSkips = p.dataSkips or 0,
        budgetSkips = p.budgetSkips or 0,
        buildSkips = p.buildSkips or 0,
        geometryUpdates = p.geometryUpdates or 0,
        geometrySkips = p.geometrySkips or 0,
        geometryHiddenPasses = p.geometryHiddenPasses or 0,
        dataIntervalFrames = SA.EspDataIntervalFrames(),
        refreshRatio = fx > 0 and data / fx or 0,
        frameBudget = SA.EspFrameBudget(),
        geometryBudget = SA.EspGeometryBudget(),
        geom = SA.EspGeomState and SA.EspGeomState() or nil,
        drawSync = SA.DrawSyncStats and SA.DrawSyncStats() or nil,
    }
end


function SA.PerfState()
    return {
        fps = perfFps,
        frame = renderFrame,
        enabled = CFG.perfMode == true,
        rebuildMs = CFG.perfEspRebuildMs,
        effectiveRebuildMs = SA.PerfEffectiveRebuildMs(),
        maxEntities = CFG.perfMaxEntities,
        effectiveEntityCap = SA.PerfEffectiveEntityCap(),
        dataRefreshMs = CFG.espDataRefreshMs,
        dataIntervalFrames = SA.EspDataIntervalFrames(),
        frameBudget = SA.EspFrameBudget(),
        geometry = SA.EspGeometryBudget(),
        geom = SA.EspGeomState and SA.EspGeomState() or nil,
        pool = SA.DrawPoolStats and SA.DrawPoolStats() or nil,
        visible = SA.EspPassStats and SA.EspPassStats() or nil,
        esp = SA.EspPerfState(),
        drawSync = SA.DrawSyncStats and SA.DrawSyncStats() or nil,
    }
end

local function renderGuard(name, fn)
    local ok = pcall(fn)
    if not ok then renderErrCount = renderErrCount + 1 end
end

local function buildBatch(list, exists, skip, builder)
    local n = #list
    if n == 0 then return 0 end
    local built, attempts = 0, 0
    local start = (renderFrame % n) + 1
    for i = 0, n - 1 do
        -- Cap BOTH successes (instance churn) and attempts (CPU cost).
        -- Rotation makes even a long run of failures finite: the next
        -- frame starts one entry further along the list.
        if built >= MAX_BUILDS or attempts >= MAX_ATTEMPTS then break end
        local item = list[((start + i - 1) % n) + 1]
        if item and not exists[item] and (not skip or not skip(item)) then
            attempts = attempts + 1
            local ok = pcall(builder, item)
            -- A build only consumes a SUCCESS slot if it actually
            -- registered an object; failed attempts still count against
            -- MAX_ATTEMPTS so one bad list can't stall the frame.
            if ok and exists[item] then built = built + 1 end
        end
    end
    return built
end

bindRender(function(dt)
    renderFrame = renderFrame + 1
    local cam = ws.CurrentCamera
    local now = tick()
    perfFrames = perfFrames + 1
    if now - perfWindow >= 0.5 then
        perfFps = perfFrames / math.max(now - perfWindow, 0.001)
        perfFrames, perfWindow = 0, now
    end
    SA.EspPerf = SA.EspPerf or { fxPasses = 0, dataRefreshes = 0, dataSkips = 0 }
    SA.EspPerf.geometryUpdates = SA.EspPerf.geometryUpdates or 0
    SA.EspPerf.geometrySkips = SA.EspPerf.geometrySkips or 0
    SA.EspPerf.geometryHiddenPasses = SA.EspPerf.geometryHiddenPasses or 0

    -- Time-based 60 FPS budget: a frame already over ~16.7 ms must not also
    -- build new ESP objects or refresh every text label. Priority box
    -- geometry still runs every frame, so the active target never freezes.
    local dtSec = tonumber(dt) or 1 / ESP_TARGET_FPS
    if dtSec <= 0 then dtSec = 1 / ESP_TARGET_FPS end
    espLastDt = dtSec
    local dtMs = dtSec * 1000
    espDataAccum = espDataAccum + dtMs
    espBuildAccum = espBuildAccum + dtMs
    local budget = SA.EspFrameBudget()
    local dataDue = espDataAccum >= budget.adaptiveDataIntervalMs
    if dataDue then espDataAccum = 0 end
    local buildOk = true
    if budget.buildIntervalMs > 0 then
        buildOk = espBuildAccum >= budget.buildIntervalMs
    else
        espBuildAccum = 0
    end
    if buildOk then espBuildAccum = 0 end
    if not buildOk then
        SA.EspPerf.buildSkips = (SA.EspPerf.buildSkips or 0) + 1
    end
    if budget.overBudget and not dataDue then
        SA.EspPerf.budgetSkips = (SA.EspPerf.budgetSkips or 0) + 1
    end
    local didDataRefresh = false

    renderGuard("players", function()
        if not CFG.espEnabled then return end
        for plr, o in pairs(espObjects) do
            if not plr.Parent or (o.char and o.char ~= plr.Character) then
                clearESP(plr)
            end
        end
        local built = 0
        if buildOk then
            built = buildBatch(Players:GetPlayers(), espObjects,
                function(p) return p == lp end, buildESP)
        end
        if dataDue or built > 0 then
            refreshESP()
            didDataRefresh = true
            espDataAccum = 0
        end
    end)

    renderGuard("npcs", function()
        if not CFG.npcEspEnabled then return end
        local built = 0
        if buildOk then
            built = buildBatch(SA.NpcListRaw(), npcObjects, function(m)
                if not m or not m.Parent then return true end
                local ok, hum = pcall(function()
                    return m:FindFirstChildOfClass("Humanoid")
                end)
                return not (ok and hum)
            end, buildNpc)
        end
        if dataDue or built > 0 then
            refreshNpcESP()
            didDataRefresh = true
            espDataAccum = 0
        end
    end)

    renderGuard("crates", function()
        if not CFG.crateEnabled then return end
        local built = 0
        if buildOk then
            built = buildBatch(SA.CrateListRaw(), crateObjects,
                function(d) return not (d and d.Parent) end, buildCrate)
        end
        if (renderFrame % 3 == 0 and not budget.overBudget) or built > 0 then
            refreshCrateESP()
        end
    end)

    if didDataRefresh then
        SA.EspPerf.dataRefreshes = (SA.EspPerf.dataRefreshes or 0) + 1
    else
        SA.EspPerf.dataSkips = (SA.EspPerf.dataSkips or 0) + 1
    end

    -- one styling pass for all three ESP types (18_esp_fx_*.lua)
    renderGuard("fx", function()
        if SA.ApplyEspFx then SA.ApplyEspFx(cam) end
    end)

    -- V16.46-style gun mods, local brightness, camera-kick filter and the
    -- visual tracer observer all share this ONE master render callback.
    if SA.GunFrame then pcall(SA.GunFrame, dtSec, now) end
end)
