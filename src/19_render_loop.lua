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
local renderErrAt, renderErrCount = 0, 0

-- ── BETTER: Performance Mode ────────────────────────────────────────
-- Adaptive build pacing (only new ESP objects are built every N ms),
-- a hard cap on objects styled per frame, and a rolling FPS estimate.
-- Refresh + styling still run every frame so boxes never freeze.
local perfFrames, perfFps, perfWindow = 0, 0, tick()
local perfLastBuild = 0

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

function SA.PerfState()
    return {
        fps = perfFps,
        frame = renderFrame,
        enabled = CFG.perfMode == true,
        rebuildMs = CFG.perfEspRebuildMs,
        effectiveRebuildMs = SA.PerfEffectiveRebuildMs(),
        maxEntities = CFG.perfMaxEntities,
        effectiveEntityCap = SA.PerfEffectiveEntityCap(),
        pool = SA.DrawPoolStats and SA.DrawPoolStats() or nil,
        visible = SA.EspPassStats and SA.EspPassStats() or nil,
    }
end

local function renderGuard(name, fn)
    local ok, err = pcall(fn)
    if not ok then
        renderErrCount = renderErrCount + 1
        local now = tick()
        if now - renderErrAt > 5 then
            renderErrAt = now
            warn("[esp] " .. name .. " pass error (" .. renderErrCount
                .. " total): " .. tostring(err))
        end
    end
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
    -- In Performance Mode, building new ESP objects is paced. A fresh
    -- character still appears within one rebuild window.
    local buildOk = true
    if CFG.perfMode then
        local targetMs = SA.PerfEffectiveRebuildMs()
        buildOk = (now - perfLastBuild) >= targetMs / 1000
        if buildOk then perfLastBuild = now end
    end

    renderGuard("players", function()
        if not CFG.espEnabled then return end
        for plr, o in pairs(espObjects) do
            if not plr.Parent or (o.char and o.char ~= plr.Character) then
                clearESP(plr)
            end
        end
        if buildOk then
            buildBatch(Players:GetPlayers(), espObjects,
                function(p) return p == lp end, buildESP)
        end
        refreshESP()
    end)

    renderGuard("npcs", function()
        if not CFG.npcEspEnabled then return end
        if buildOk then buildBatch(SA.GetNpcs(), npcObjects, nil, buildNpc) end
        refreshNpcESP()
    end)

    renderGuard("crates", function()
        if not CFG.crateEnabled then return end
        local built = 0
        if buildOk then built = buildBatch(SA.GetCrates(), crateObjects, nil, buildCrate) end
        if renderFrame % 3 == 0 or built > 0 then refreshCrateESP() end
    end)

    -- one styling pass for all three ESP types (18_esp_fx_*.lua)
    renderGuard("fx", function()
        if SA.ApplyEspFx then SA.ApplyEspFx(cam) end
    end)
end)
