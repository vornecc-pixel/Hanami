-- ==================================================================
-- Hanami / 11_render_loop.lua — Master ESP + crate render loop
-- Loaded in order by loader.lua. Parts are joined into ONE chunk
-- before running, so every `local` is shared just like the original.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- MASTER RENDER LOOP (ESP + Crates)
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
    if CFG.crateEnabled then refreshCrateESP() end
end)

