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

bindRender(function()
    renderFrame = renderFrame + 1
    local cam = ws.CurrentCamera

    renderGuard("players", function()
        if not CFG.espEnabled then return end
        for plr, o in pairs(espObjects) do
            if not plr.Parent or (o.char and o.char ~= plr.Character) then
                clearESP(plr)
            end
        end
        buildBatch(Players:GetPlayers(), espObjects,
            function(p) return p == lp end, buildESP)
        refreshESP()
    end)

    renderGuard("npcs", function()
        if not CFG.npcEspEnabled then return end
        buildBatch(SA.GetNpcs(), npcObjects, nil, buildNpc)
        refreshNpcESP()
    end)

    renderGuard("crates", function()
        if not CFG.crateEnabled then return end
        local built = buildBatch(SA.GetCrates(), crateObjects, nil, buildCrate)
        if renderFrame % 3 == 0 or built > 0 then refreshCrateESP() end
    end)

    -- one styling pass for all three ESP types (18_esp_fx_*.lua)
    renderGuard("fx", function()
        if SA.ApplyEspFx then SA.ApplyEspFx(cam) end
    end)
end)
