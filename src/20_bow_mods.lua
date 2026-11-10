-- ==================================================================
-- Hanami / 20_bow_mods.lua — Bow mods: Instant Charge + No Cooldown
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- BOW MODS — ONLY the two requested features
--
-- Adapted from the pasted anti-externa.wtf bow section. Everything else
-- in that script was deliberately NOT copied:
--   * NoDrop / Items.BowSpec wrap          (excluded)
--   * Instant Reload / crossbow u17        (excluded)
--   * NoRecoil / tremble / sway / u185     (excluded)
--   * InfiniteAmmo, NoAirBlock / u16       (excluded)
--   * WindUI, hit log, hit sound, damage tracker, ESP, gun mods (excluded)
--
-- KEPT, exactly two:
--   * Instant Charge  -> live bow state (u14).drawStart = os.clock() - 10,
--                        so every shot is treated as fully drawn.
--   * No Cooldown     -> bow config (u10) SHOT_GAP / REDRAW_GAP / MIN_DRAW
--                        are zeroed, and live state (u14).lastShot is kept
--                        at -math.huge so the fire gate never blocks.
--
-- This file only changes the bow's own charge / cooldown timing; it never
-- touches aim, targets or hit-scan. Ballistic silent aim / peek-origin
-- wallbang for Fust bows is a separate, default-OFF hook in
-- 09_z_fust_bow.lua; the camera-snap gun resolver stays guns-only.
--
-- Like 20_gun_mods.lua this uses a generation-guarded GC scan plus a
-- per-frame state pass. rawget/rawset bypass __index/__newindex on plain
-- Lua tables; setreadonly unfreezes a matched table before rawset. No
-- metatable is written.
-- ────────────────────────────────────────────────────────────────────

local bowCfg = {}        -- u10-style bow config tables (rebuilt by each scan)
local bowLive = {}       -- u14-style live draw states (rebuilt by each scan)
-- Originals MUST survive a re-execute: SA/CFG persist in _G, so a new run
-- would otherwise re-read the already-zeroed values as "original" and could
-- never restore them. bowCfg / bowLive are cheap caches and stay per-run.
local bowSaved = _G.__saBowSaved or {}
_G.__saBowSaved = bowSaved
local bowGen = SA.Generation
local bowWasOn = false
local bowCdWasOn = false

local BOW_CFG_KEYS = { "SHOT_GAP", "REDRAW_GAP", "MIN_DRAW" }

local function bowOn()
    return SA.Alive == true and CFG.bowModsEnabled == true
        and (CFG.bowInstantCharge == true or CFG.bowNoCooldown == true)
end

-- u10: five numeric constants identify the bow config table.
local function bowIsConfig(tbl)
    return type(rawget(tbl, "DRAW_TIME"))     == "number"
       and type(rawget(tbl, "SHOT_GAP"))      == "number"
       and type(rawget(tbl, "MIN_DRAW"))      == "number"
       and type(rawget(tbl, "SPEED_BASE"))    == "number"
       and type(rawget(tbl, "SPEED_CHARGE"))  == "number"
end

-- u14: live bow draw/ammunition state.
local function bowIsLive(tbl)
    return type(rawget(tbl, "drawStart"))     == "number"
       and type(rawget(tbl, "lastShot"))      == "number"
       and type(rawget(tbl, "drawing"))       == "boolean"
       and type(rawget(tbl, "shotId"))        == "number"
       and type(rawget(tbl, "pendingSpent"))  == "number"
end

local function bowPatchConfig(tbl)
    if not bowSaved[tbl] then
        local saved = {}
        for _, k in ipairs(BOW_CFG_KEYS) do
            local v = rawget(tbl, k)
            if v ~= nil then saved[k] = v end
        end
        bowSaved[tbl] = saved
    end
    -- Only zero keys the game actually defined; never invent new fields.
    for _, k in ipairs(BOW_CFG_KEYS) do
        if rawget(tbl, k) ~= nil then pcall(rawset, tbl, k, 0) end
    end
end

-- Restore just the config constants (used when No Cooldown is switched off).
function SA.BowModsRestoreConfigs()
    for tbl, saved in pairs(bowSaved) do
        pcall(function()
            pcall(setreadonly, tbl, false)
            for k, v in pairs(saved) do pcall(rawset, tbl, k, v) end
        end)
        bowSaved[tbl] = nil
    end
    -- `lastShot` goes back to 0 rather than staying at -inf; 0 reads as
    -- "no recent shot" under both os.clock() and tick() clocks, and never
    -- blocks the bow. Otherwise the first shot after switching the mod
    -- off would still bypass the cooldown.
    for _, s in ipairs(bowLive) do
        pcall(function() rawset(s, "lastShot", 0) end)
    end
    bowCdWasOn = false
end

-- Full cleanup for "Unload Everything" / master switch OFF.
function SA.BowModsRestore()
    pcall(SA.BowModsRestoreConfigs)
    bowCfg, bowLive = {}, {}
    bowWasOn = false
end

function SA.BowModsState()
    local patched = 0
    for _ in pairs(bowSaved) do patched = patched + 1 end
    return {
        enabled = CFG.bowModsEnabled == true,
        instantCharge = CFG.bowInstantCharge == true,
        noCooldown = CFG.bowNoCooldown == true,
        configTables = #bowCfg,
        liveStates = #bowLive,
        patched = patched,
        gc = type(getgc) == "function",
        readonly = type(setreadonly) == "function",
    }
end

-- ── GC scanner (1.5 s cadence, same yield pattern as 20_gun_mods.lua) ─
task.spawn(function()
    while SA.Alive and (SA.Generation or 0) == bowGen do
        if bowOn() and getgc and setreadonly then
            local cfg, live = {}, {}
            local ok, objects = pcall(function() return getgc(true) end)
            if ok and type(objects) == "table" then
                local n = 0
                for _, tbl in pairs(objects) do
                    if type(tbl) == "table" then
                        n = n + 1
                        if n % 1000 == 0 then RunService.RenderStepped:Wait() end
                        -- rawget on a table cannot throw, so no per-table
                        -- pcall is needed (keeps the scan cheap).
                        if bowIsConfig(tbl) then
                            cfg[#cfg + 1] = tbl
                            pcall(setreadonly, tbl, false)
                        elseif bowIsLive(tbl) then
                            live[#live + 1] = tbl
                            pcall(setreadonly, tbl, false)
                        end
                    end
                end
            end
            bowCfg, bowLive = cfg, live
            if CFG.bowNoCooldown then
                for _, t in ipairs(bowCfg) do bowPatchConfig(t) end
            end
        end
        task.wait(1.5)
    end
end)

-- ── Per-frame enforcer ───────────────────────────────────────────────
-- Live bow state is rewritten every frame; config constants are re-zeroed
-- in case the game resets them. Switching a mod off restores the saved
-- values instead of leaving the game permanently patched.
local function bowTick()
    if not bowOn() then
        if bowWasOn or bowCdWasOn then pcall(SA.BowModsRestore) end
        return
    end
    bowWasOn = true
    local instant = CFG.bowInstantCharge == true
    local noCd = CFG.bowNoCooldown == true
    if bowCdWasOn and not noCd then pcall(SA.BowModsRestoreConfigs) end
    bowCdWasOn = noCd

    if instant or noCd then
        for _, s in ipairs(bowLive) do
            pcall(function()
                if instant then rawset(s, "drawStart", os.clock() - 10) end
                if noCd then rawset(s, "lastShot", -math.huge) end
            end)
        end
    end
    if noCd then
        for _, c in ipairs(bowCfg) do bowPatchConfig(c) end
    end
end

-- GC'd tables can be collected or made read-only again by the game, so the
-- whole tick is isolated: one bad table must never spam RenderStepped.
bindRender(function() pcall(bowTick) end)
