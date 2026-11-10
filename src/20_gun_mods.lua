-- ==================================================================
-- Hanami / 20_gun_mods.lua — reversible, timing-safe GC gun mods
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- GUN MODS — config patcher + per-frame state enforcer
--
-- The previous build left weapons "stuck" and unable to fire because it
-- zeroed EQUIP_TIME / HOLSTER_TIME / AdsTime / AdsOutTime / adsTime to 0
-- and wrote equipAt = -math.huge. A zero divisor in the game's equip /
-- ADS springs produces inf / NaN, so the weapon never finishes equipping.
-- It also unfroze EVERY getgc table, used direct assignment on live
-- states, never saved originals and never restored them.
--
-- This rewrite follows the pasted fust_gun_mods.lua functional source:
--   * two layers per mod: config constants (patched once, re-applied) and
--     live state fields (enforced every frame with rawget / rawset);
--   * shape-matched tables only — setreadonly(tbl, false) is called on
--     matched tables, never on the whole GC;
--   * timing fields use GM_MIN_TIME = 0.001 instead of 0, and equipAt is
--     a FINITE past timestamp, so no spring can divide by zero;
--   * originals are saved in _G.__saGunMods.saved and restored on toggle
--     OFF, "Restore Gun Timings", re-execute and SA.FullUnload().
--
-- No console output. All table writes are pcall-guarded rawset.
-- ────────────────────────────────────────────────────────────────────

if SA.GunModsRestore then pcall(SA.GunModsRestore) end
local gm = _G.__saGunMods or {
    saved = {}, unlocked = {}, config = {}, defs = {},
    recoilLive = {}, spreadLive = {}, swayLive = {}, adsLive = {},
    generation = 0, scanned = false, wasOn = false, signature = "",
    scans = 0, patches = 0, enforces = 0, errors = 0,
}
_G.__saGunMods = gm
-- Re-executing after an older build must not inherit stale table refs.
gm.saved = gm.saved or {}
gm.unlocked = gm.unlocked or {}
gm.config, gm.defs = {}, {}
gm.recoilLive, gm.spreadLive = {}, {}
gm.swayLive, gm.adsLive = {}, {}
gm.generation = SA.Generation or 0
gm.scanned, gm.wasOn, gm.signature = false, false, ""
gm.scans = gm.scans or 0
gm.patches = gm.patches or 0
gm.enforces = gm.enforces or 0
gm.errors = gm.errors or 0

local GM_MIN_TIME = 0.001
local GM_TREMBLE_AFTER = 9999
local GM_EQUIP_BACK = 10
local GM_ZERO3 = Vector3.new(0, 0, 0)

local EQUIP_CONFIG_FIELDS = { "EQUIP_TIME", "HOLSTER_TIME" }
local ADS_CONFIG_FIELDS = { "AdsTime", "AdsOutTime", "adsTime" }
local SPREAD_CONFIG_ZERO = { "MOVE_SPREAD", "AirSpread" }
local SPREAD_CONFIG_ONE = { "AdsMoveMult", "AimRun" }
local SPREAD_DEF_FIELDS = { "spread", "adsSpread", "moveSpread" }
local RECOIL_CONFIG_FIELDS = {
    "RecoilClimb", "RecoilRecover", "RecoilTail", "VisualBloom",
    "ShakeMax", "ShakeDur", "KICK_PITCH", "KICK_BACK",
    "ADS_KICK", "ADS_KICK_ROLL",
}
local SWAY_CONFIG_ZERO = {
    "SWAY", "SWAY_MAX", "SWAY_ROT", "SWAY_ROT_MAX",
    "BOB_WALK", "BOB_IDLE", "BOB_ROLL", "LEAN", "LEAN_SHIFT",
    "KICK_PITCH", "KICK_BACK", "ADS_LEAN", "ADS_LAND",
    "ADS_INERTIA", "ADS_SWAY", "TREMBLE_MAX",
}
local RECOIL_LIVE_FIELDS = {
    "recoil", "recoilYaw", "RecoilPend", "RecoilYawPend",
    "shakeUntil", "shakeStrength",
}
local KICK_LIVE_FIELDS = {
    "kick", "kickV", "kickBack", "kickPitch", "kickRoll",
}
local SWAY_LIVE_VEC = { "sway", "swayV", "swayRot", "swayRotV" }
local SWAY_LIVE_NUM = { "lean", "leanV", "land", "landV" }

-- ── shape detectors (rawget only; never triggers a metatable) ───────
local function gmHas(t, keys)
    for _, k in ipairs(keys) do
        if rawget(t, k) ~= nil then return true end
    end
    return false
end
local function gmIsConfig(t)
    return gmHas(t, { "KICK_RECOVER", "RecoilClimb" })
        or (rawget(t, "MOVE_SPREAD") ~= nil and rawget(t, "AirSpread") ~= nil)
        or rawget(t, "SWAY_MAX") ~= nil
        or gmHas(t, ADS_CONFIG_FIELDS)
        or gmHas(t, EQUIP_CONFIG_FIELDS)
end
local function gmIsDef(t)
    return rawget(t, "spread") ~= nil and rawget(t, "adsSpread") ~= nil
end
local function gmIsRecoilLive(t)
    return rawget(t, "recoil") ~= nil and rawget(t, "RecoilPend") ~= nil
end
local function gmIsSpreadLive(t)
    return rawget(t, "SpreadPx") ~= nil and rawget(t, "equipAt") ~= nil
end
local function gmIsSwayLive(t)
    -- typeof (not type) is required: Roblox Vector3 is userdata to type().
    return typeof(rawget(t, "sway")) == "Vector3"
        and typeof(rawget(t, "swayV")) == "Vector3"
        and type(rawget(t, "bobPhase")) == "number"
end
local function gmIsAdsLive(t)
    return rawget(t, "ads") ~= nil and rawget(t, "AdsV") ~= nil
end

-- ── reversible config patching ─────────────────────────────────────
local function gmSave(t, k)
    local saved = gm.saved[t]
    if not saved then saved = {}; gm.saved[t] = saved end
    if saved[k] == nil then
        local v = rawget(t, k)
        if v ~= nil then saved[k] = v end
    end
end
local function gmSet(t, k, v)
    gmSave(t, k)
    pcall(rawset, t, k, v)
    gm.patches = gm.patches + 1
end
local function gmUnlock(t)
    if type(setreadonly) ~= "function" then return end
    if gm.unlocked[t] == nil then
        local wasReadOnly = false
        if type(isreadonly) == "function" then
            pcall(function() wasReadOnly = isreadonly(t) == true end)
        end
        gm.unlocked[t] = wasReadOnly
    end
    pcall(setreadonly, t, false)
end
local function gmPatchFields(t, keys, value)
    for _, k in ipairs(keys) do
        if rawget(t, k) ~= nil then gmSet(t, k, value) end
    end
end

local function gmPatchConfig()
    for _, t in ipairs(gm.config) do
        gmUnlock(t)
        if CFG.gmInstantEquip then
            gmPatchFields(t, EQUIP_CONFIG_FIELDS, GM_MIN_TIME)
        end
        if CFG.gmInstantAds then
            gmPatchFields(t, ADS_CONFIG_FIELDS, GM_MIN_TIME)
        end
        if CFG.gmNoSpread then
            gmPatchFields(t, SPREAD_CONFIG_ZERO, 0)
            gmPatchFields(t, SPREAD_CONFIG_ONE, 1)
        end
        if CFG.gmNoRecoil then
            gmPatchFields(t, RECOIL_CONFIG_FIELDS, 0)
        end
        if CFG.gmNoSway then
            gmPatchFields(t, SWAY_CONFIG_ZERO, 0)
            gmPatchFields(t, { "TREMBLE_AFTER" }, GM_TREMBLE_AFTER)
        end
    end
    for _, d in ipairs(gm.defs) do
        gmUnlock(d)
        if CFG.gmNoSpread then gmPatchFields(d, SPREAD_DEF_FIELDS, 0) end
        if CFG.gmForceAuto and rawget(d, "auto") ~= nil then
            gmSet(d, "auto", true)
        end
    end
end

-- ── per-frame live-state enforcer ──────────────────────────────────
local function gmEnforceLive()
    local noRecoil = CFG.gmNoRecoil == true
    local noKick = CFG.gmNoKick == true
    local noSpread = CFG.gmNoSpread == true
    local instantEquip = CFG.gmInstantEquip == true
    local noSway = CFG.gmNoSway == true
    for _, s in ipairs(gm.recoilLive) do
        if noRecoil then gmPatchFields(s, RECOIL_LIVE_FIELDS, 0) end
        if noRecoil or noKick then gmPatchFields(s, KICK_LIVE_FIELDS, 0) end
    end
    for _, s in ipairs(gm.spreadLive) do
        if noSpread and rawget(s, "SpreadPx") ~= nil then
            pcall(rawset, s, "SpreadPx", 0)
        end
        if instantEquip and rawget(s, "equipAt") ~= nil then
            -- FINITE past value: -math.huge made tick()-equipAt overflow.
            pcall(rawset, s, "equipAt", os.clock() - GM_EQUIP_BACK)
        end
    end
    if noSway then
        for _, s in ipairs(gm.swayLive) do
            gmPatchFields(s, SWAY_LIVE_VEC, GM_ZERO3)
            gmPatchFields(s, SWAY_LIVE_NUM, 0)
        end
    end
    -- InstantAds deliberately does NOT force `ads` per frame: the pasted
    -- source warns that fighting the eye interpolation looks jittery.
end

-- ── GC scan (shape-matched, generation-guarded, yields every 1000) ──
function SA.GunModsScan()
    if type(getgc) ~= "function" or type(setreadonly) ~= "function" then
        return false
    end
    local ok, objects = pcall(function() return getgc(true) end)
    if not ok or type(objects) ~= "table" then return false end
    local cfg, defs = {}, {}
    local rl, sl, wl, al = {}, {}, {}, {}
    local seen = {}
    local n = 0
    for _, t in pairs(objects) do
        if type(t) == "table" then
            n = n + 1
            if n % 1000 == 0 then RunService.RenderStepped:Wait() end
            local isCfg, isDef = gmIsConfig(t), gmIsDef(t)
            if isCfg or isDef then gmUnlock(t) end
            if isCfg and not seen[t] then
                seen[t] = true
                cfg[#cfg + 1] = t
            end
            if isDef and not seen[t] then
                seen[t] = true
                defs[#defs + 1] = t
            end
            if gmIsRecoilLive(t) then rl[#rl + 1] = t end
            if gmIsSpreadLive(t) then sl[#sl + 1] = t end
            if gmIsSwayLive(t) then wl[#wl + 1] = t end
            if gmIsAdsLive(t) then al[#al + 1] = t end
        end
    end
    gm.config, gm.defs = cfg, defs
    gm.recoilLive, gm.spreadLive = rl, sl
    gm.swayLive, gm.adsLive = wl, al
    gm.scanned = true
    gm.scans = gm.scans + 1
    gmPatchConfig()
    return true
end

-- ── control surface ────────────────────────────────────────────────
function SA.GunModsState()
    local patched = 0
    for _ in pairs(gm.saved) do patched = patched + 1 end
    return {
        enabled = CFG.gmEnabled == true,
        instantEquip = CFG.gmInstantEquip == true,
        instantAds = CFG.gmInstantAds == true,
        noSpread = CFG.gmNoSpread == true,
        forceAuto = CFG.gmForceAuto == true,
        noRecoil = CFG.gmNoRecoil == true,
        noSway = CFG.gmNoSway == true,
        noKick = CFG.gmNoKick == true,
        minTime = GM_MIN_TIME,
        configTables = #gm.config,
        defs = #gm.defs,
        recoilLive = #gm.recoilLive,
        spreadLive = #gm.spreadLive,
        swayLive = #gm.swayLive,
        adsLive = #gm.adsLive,
        patched = patched,
        scans = gm.scans,
        patches = gm.patches,
        enforces = gm.enforces,
        errors = gm.errors,
        scanned = gm.scanned == true,
        gc = type(getgc) == "function",
        readonly = type(setreadonly) == "function",
        generation = gm.generation,
    }
end

function SA.GunModsRestore()
    for t, saved in pairs(gm.saved) do
        pcall(function()
            gmUnlock(t)
            for k, v in pairs(saved) do pcall(rawset, t, k, v) end
            if gm.unlocked[t] == true then pcall(setreadonly, t, true) end
        end)
        gm.saved[t] = nil
        gm.unlocked[t] = nil
    end
    gm.config, gm.defs = {}, {}
    gm.recoilLive, gm.spreadLive = {}, {}
    gm.swayLive, gm.adsLive = {}, {}
    gm.scanned = false
    gm.wasOn = false
    gm.signature = ""
    return SA.GunModsState()
end

function SA.GunModsRefresh()
    pcall(SA.GunModsRestore)
    SA.GunModsScan()
    return SA.GunModsState()
end

SA.GunModsRestoreTimings = SA.GunModsRestore

local function gmOn()
    return SA.Alive == true and CFG.gmEnabled == true
        and (CFG.gmInstantEquip == true or CFG.gmInstantAds == true
            or CFG.gmNoSpread == true or CFG.gmForceAuto == true
            or CFG.gmNoRecoil == true or CFG.gmNoSway == true
            or CFG.gmNoKick == true)
end

-- A toggle change must re-read the GC's originals. Without this, turning
-- one mod off would leave the other mods' patched constants in place.
local function gmSignature()
    local bits = { "1" }
    local keys = { "gmInstantEquip", "gmInstantAds", "gmNoSpread",
        "gmForceAuto", "gmNoRecoil", "gmNoSway", "gmNoKick" }
    for _, k in ipairs(keys) do bits[#bits + 1] = CFG[k] and "1" or "0" end
    return table.concat(bits)
end

local function gmTick()
    if not gmOn() then
        if gm.wasOn then pcall(SA.GunModsRestore) end
        return
    end
    gm.wasOn = true
    local sig = gmSignature()
    if sig ~= gm.signature then
        pcall(SA.GunModsRestore)
        gm.wasOn = true
        gm.signature = sig
        gm.scanned = false
    end
    -- Scan only on enable / toggle change / the periodic refresh below.
    -- Scanning getgc() every frame is what made the old build stutter.
    if not gm.scanned then pcall(SA.GunModsScan) end
    gmEnforceLive()
    gm.enforces = gm.enforces + 1
end

-- One bad GC table must never spam RenderStepped or leave a weapon stuck.
bindRender(function()
    local good = pcall(gmTick)
    if not good then gm.errors = gm.errors + 1 end
end)

-- Re-scan periodically: the game reallocates config / live tables. This
-- is a 2-second refresh, NOT a full per-frame GC traversal.
task.spawn(function()
    while SA.Alive and (SA.Generation or 0) == gm.generation do
        if gmOn() then pcall(SA.GunModsScan) end
        task.wait(2)
    end
end)
