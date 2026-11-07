-- ==================================================================
-- Hanami / 19_render_loop.lua — Master player/NPC/crate ESP render loop
-- Loaded in order by loader.lua. Parts are joined into ONE chunk
-- before running, so every `local` is shared just like the original.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- MASTER RENDER LOOP (ESP + Crates + FX)
-- Crates are re-discovered every frame from the live registry: this is the
-- fix for containers that stream in (or whose parts arrive after their
-- Model) and were previously skipped forever.
-- ────────────────────────────────────────────────────────────────────

RunService.RenderStepped:Connect(function()
    if CFG.espEnabled then
        for plr in pairs(espObjects) do
            if not plr.Parent then clearESP(plr) end
        end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= lp and not espObjects[p] then buildESP(p) end
        end
        refreshESP()
    end
    if CFG.npcEspEnabled then
        for _, m in ipairs(SA.GetNpcs()) do
            if not npcObjects[m] then buildNpc(m) end
        end
        refreshNpcESP()
    end
    if CFG.crateEnabled then
        for _, m in ipairs(SA.GetCrates()) do
            if not crateObjects[m] then buildCrate(m) end
        end
        refreshCrateESP()
    end
    -- one styling pass for all three ESP types (18_esp_fx_*.lua)
    if SA.ApplyEspFx then SA.ApplyEspFx(ws.CurrentCamera) end
end)
