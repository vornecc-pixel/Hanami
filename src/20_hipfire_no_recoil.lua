-- ==================================================================
-- Hanami / 20_hipfire_no_recoil.lua — Hipfire No Recoil (camera + kick + bloom)
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- HIPFIRE NO RECOIL — full supplied scope
--
-- Applies whenever CFG.hipfireNoRecoil is ON (there is deliberately NO
-- ADS / hipfire detection, per the requested behaviour). It combines:
--   1. LIVE STATE: camera climb, gun-model kick and spread-bloom
--      accumulators are zeroed every frame.
--   2. DEF TABLES: spread / bloom / climb / shake / recover constants
--      are patched once per gun definition, re-scanned for new guns.
--   3. REVERSIBILITY: every def field's original value is saved in a
--      weak-key table that survives a loader re-execute. Turning the
--      toggle OFF, pressing Restore, or "Unload Everything" puts the
--      originals back instead of leaving the game permanently patched.
--
-- Like 20_gun_mods.lua / 20_bow_mods.lua this uses getgc(true) plus a
-- generation-guarded scanner. Live state writes use normal assignment
-- (so the game's own __newindex hooks still run); def writes use rawset
-- after setreadonly(tbl, false). No metatable is replaced.
-- ────────────────────────────────────────────────────────────────────

local hnrLive = {}
local hnrDefs = {}
local hnrSaved = _G.__saHnrSaved or setmetatable({}, { __mode = "k" })
_G.__saHnrSaved = hnrSaved
local hnrLiveSaved = _G.__saHnrLiveSaved or setmetatable({}, { __mode = "k" })
_G.__saHnrLiveSaved = hnrLiveSaved
local hnrGen = SA.Generation
local hnrWasOn = false
local hnrScans = 0

-- key, patched value. Only fields the game actually defined are written.
local hnrDefPatches = {
    { "spread", 0 }, { "adsSpread", 0 }, { "moveSpread", 0 },
    { "MOVE_SPREAD", 0 }, { "AirSpread", 0 },
    { "AdsMoveMult", 1 }, { "AimRun", 1 },
    { "VisualBloom", 0 }, { "RecoilClimb", 0 },
    { "RecoilRecover", 999 }, { "ShakeMax", 0 }, { "ShakeDur", 0 },
}

local hnrZeroKeys = {
    "recoil", "recoilYaw", "RecoilPend", "RecoilYawPend",
    "shakeUntil", "shakeStrength",
    "kick", "kickV", "kickBack", "kickPitch", "kickRoll", "BoltKick",
    "SpreadPx",
}

function hnrOn()
    return SA.Alive == true and CFG.hipfireNoRecoil == true
end

-- The pasted signature identifies the live camera / kick state. Hanami's
-- older gun-mods scanner used SpreadPx + equipAt, so accept that too.
function hnrIsLive(tbl)
    if type(rawget(tbl, "recoil")) == "number"
        and type(rawget(tbl, "RecoilPend")) == "number"
        and type(rawget(tbl, "kick")) == "number"
        and type(rawget(tbl, "kickV")) == "number" then
        return true
    end
    return rawget(tbl, "SpreadPx") ~= nil and rawget(tbl, "equipAt") ~= nil
end

-- A gun def has `spread` AND one of the rate / recoil / bloom constants.
function hnrIsDef(tbl)
    if rawget(tbl, "spread") == nil then return false end
    return rawget(tbl, "rate") ~= nil
        or rawget(tbl, "RecoilClimb") ~= nil
        or rawget(tbl, "VisualBloom") ~= nil
end

function hnrPatchDef(tbl)
    if not hnrSaved[tbl] then
        local saved = {}
        for _, p in ipairs(hnrDefPatches) do
            local v = rawget(tbl, p[1])
            if v ~= nil then saved[p[1]] = v end
        end
        hnrSaved[tbl] = saved
    end
    if type(setreadonly) == "function" then pcall(setreadonly, tbl, false) end
    for _, p in ipairs(hnrDefPatches) do
        if rawget(tbl, p[1]) ~= nil then pcall(rawset, tbl, p[1], p[2]) end
    end
end

-- Explicit rescan (UI button + tests). Def patches only happen while ON.
function SA.HipfireNoRecoilScan()
    local live, defs = {}, {}
    if type(getgc) == "function" then
        local ok, objects = pcall(function() return getgc(true) end)
        if ok and type(objects) == "table" then
            local n = 0
            for _, tbl in pairs(objects) do
                if type(tbl) == "table" then
                    n = n + 1
                    if n % 1000 == 0 then
                        pcall(function() RunService.RenderStepped:Wait() end)
                    end
                    if hnrIsLive(tbl) then
                        live[#live + 1] = tbl
                    elseif hnrIsDef(tbl) then
                        defs[#defs + 1] = tbl
                        if hnrOn() then pcall(hnrPatchDef, tbl) end
                    end
                end
            end
        end
    end
    hnrLive, hnrDefs = live, defs
    hnrScans = hnrScans + 1
    return #live, #defs
end

-- Restore every patched def field and the two structural live-state
-- fields (BasePitch / CamBound). Numeric recoil / kick values are left
-- alone: the game recomputes them on its next shot with the def restored.
function SA.HipfireNoRecoilRestore()
    for tbl, saved in pairs(hnrSaved) do
        pcall(function()
            if type(setreadonly) == "function" then pcall(setreadonly, tbl, false) end
            for k, v in pairs(saved) do pcall(rawset, tbl, k, v) end
        end)
        hnrSaved[tbl] = nil
    end
    for s, saved in pairs(hnrLiveSaved) do
        pcall(function()
            if saved.hasBasePitch then rawset(s, "BasePitch", saved.basePitch)
            else rawset(s, "BasePitch", nil) end
            if saved.hasCamBound then rawset(s, "CamBound", saved.camBound)
            else rawset(s, "CamBound", nil) end
        end)
        hnrLiveSaved[s] = nil
    end
    hnrLive, hnrDefs = {}, {}
    hnrWasOn = false
    return true
end

function SA.HipfireNoRecoilState()
    local patched = 0
    for _ in pairs(hnrSaved) do patched = patched + 1 end
    return {
        enabled = CFG.hipfireNoRecoil == true,
        alwaysOn = true,               -- no ADS gate, per requested behaviour
        liveStates = #hnrLive,
        defTables = #hnrDefs,
        patched = patched,
        scans = hnrScans,
        gc = type(getgc) == "function",
        readonly = type(setreadonly) == "function",
    }
end

function SA.PrintHipfireNoRecoil()
    local s = SA.HipfireNoRecoilState()
    print(string.format(
        "[hipfire] enabled=%s alwaysOn=%s live=%d defs=%d patched=%d scans=%d gc=%s setreadonly=%s",
        tostring(s.enabled), tostring(s.alwaysOn), s.liveStates,
        s.defTables, s.patched, s.scans, tostring(s.gc), tostring(s.readonly)))
end

-- ── GC scanner (1 s cadence; generator guard stops old loops) ─────────
task.spawn(function()
    while SA.Alive and (SA.Generation or 0) == hnrGen do
        if hnrOn() then pcall(SA.HipfireNoRecoilScan) end
        task.wait(1)
    end
end)

-- ── Per-frame enforcer ──────────────────────────────────────────────
function hnrTick()
    if not hnrOn() then
        if hnrWasOn or next(hnrSaved) ~= nil or next(hnrLiveSaved) ~= nil then
            pcall(SA.HipfireNoRecoilRestore)
        end
        return
    end
    hnrWasOn = true
    for _, s in ipairs(hnrLive) do
        pcall(function()
            for _, k in ipairs(hnrZeroKeys) do
                if rawget(s, k) ~= nil then s[k] = 0 end
            end
            if not hnrLiveSaved[s] then
                hnrLiveSaved[s] = {
                    hasBasePitch = rawget(s, "BasePitch") ~= nil,
                    basePitch = rawget(s, "BasePitch"),
                    hasCamBound = rawget(s, "CamBound") ~= nil,
                    camBound = rawget(s, "CamBound"),
                }
            end
            s.BasePitch = nil
            s.CamBound = false
        end)
    end
end

bindRender(function() pcall(hnrTick) end)
