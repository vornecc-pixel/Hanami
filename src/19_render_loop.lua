-- ==================================================================
-- Hanami / 19_render_loop.lua — Master player/NPC/crate ESP render loop
-- Loaded in order by loader.lua. Parts are joined into ONE chunk
-- before running, so every `local` is shared just like the original.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- MASTER RENDER LOOP (ESP + Crates + FX)
-- Crates are re-discovered from the live registry (built by the yielding
-- walker, not a GetDescendants() call), but at most MAX_BUILDS new
-- BillboardGuis/Highlights are created per frame. Building dozens of
-- Instances in one frame was the other half of the periodic stutter.
-- Crate refresh runs at ~20 Hz (crates don't move); player/NPC boxes
-- still update every frame.
-- ────────────────────────────────────────────────────────────────────

local MAX_BUILDS = 2
local renderFrame = 0

bindRender(function()
    renderFrame = renderFrame + 1
    local cam = ws.CurrentCamera

    if CFG.espEnabled then
        for plr in pairs(espObjects) do
            if not plr.Parent then clearESP(plr) end
        end
        local built = 0
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= lp and not espObjects[p] and built < MAX_BUILDS then
                buildESP(p); built = built + 1
            end
        end
        refreshESP()
    end
    if CFG.npcEspEnabled then
        local built = 0
        for _, m in ipairs(SA.GetNpcs()) do
            if not npcObjects[m] and built < MAX_BUILDS then
                buildNpc(m); built = built + 1
            end
        end
        refreshNpcESP()
    end
    if CFG.crateEnabled then
        local built = 0
        for _, m in ipairs(SA.GetCrates()) do
            if not crateObjects[m] and built < MAX_BUILDS then
                buildCrate(m); built = built + 1
            end
        end
        if renderFrame % 3 == 0 or built > 0 then refreshCrateESP() end
    end
    -- one styling pass for all three ESP types (18_esp_fx_*.lua)
    if SA.ApplyEspFx then SA.ApplyEspFx(cam) end
end)
