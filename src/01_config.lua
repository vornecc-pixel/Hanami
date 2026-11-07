-- ==================================================================
-- Hanami / 01_config.lua — Services, config defaults, backfill, shared state
-- Loaded in order by loader.lua. Parts are joined into ONE chunk
-- before running, so every `local` is shared just like the original.
-- ==================================================================

-- ==================================================================
-- @abusegpt — Silent Aim + Wall Pen + ESP + Crate ESP + Gun Mods
-- Pure renderstep + raycast. No metatable writes on silent aim.
-- Gun mods use rawget/rawset + setreadonly (GC scan).
-- ==================================================================

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local Workspace         = game:GetService("Workspace")
local lp                = Players.LocalPlayer
local ws                = workspace

-- ────────────────────────────────────────────────────────────────────
-- SHARED STATE
-- A plain table so early parts can call helpers assigned by later parts
-- (no forward-local problem), while `_G` keeps it across re-executes.
-- ────────────────────────────────────────────────────────────────────

local SA = _G.__saShared or {}
_G.__saShared = SA
SA.Target = SA.Target or {}   -- current aim-preview target, written by 11_snapline
SA.Alive  = true              -- set false by "Unload Everything" to stop scanners
-- Re-executing the loader bumps the generation: old scanner loops exit and
-- the new chunk starts exactly one replacement loop.
SA.Generation = (SA.Generation or 0) + 1

-- ────────────────────────────────────────────────────────────────────
-- UNIFIED ESP PALETTE
-- One table for EVERY drawn element. Each key has its own colourpicker in
-- the ESP -> Colours mini-tabs, and the table survives re-execution via _G.
-- --------------------------------------------------------------------
local ESP_DEFAULT_COLORS = {
    -- dynamic visibility (the user-facing green / red check)
    playerVisible    = Color3.fromRGB(60, 255, 100),
    playerHidden     = Color3.fromRGB(255, 60, 60),
    playerFlat       = Color3.fromRGB(255, 60, 60),
    npcVisible       = Color3.fromRGB(60, 255, 100),
    npcHidden        = Color3.fromRGB(255, 60, 60),
    npcFlat          = Color3.fromRGB(255, 60, 60),

    -- per-NPC-archetype colours (optional override)
    npcGuard         = Color3.fromRGB(90, 200, 255),
    npcScavenger     = Color3.fromRGB(255, 180, 70),
    npcSoldier       = Color3.fromRGB(255, 90, 90),

    -- player per-element
    playerName       = Color3.fromRGB(255, 255, 255),
    playerDistance   = Color3.fromRGB(210, 210, 210),
    playerInfo       = Color3.fromRGB(210, 210, 210),
    playerBox        = Color3.fromRGB(255, 255, 255),
    playerFill       = Color3.fromRGB(255, 60, 60),
    playerOutline    = Color3.fromRGB(255, 255, 255),
    playerHealthHigh = Color3.fromRGB(60, 255, 100),
    playerHealthLow  = Color3.fromRGB(255, 60, 60),
    playerSkeleton   = Color3.fromRGB(120, 220, 255),
    playerHeadDot    = Color3.fromRGB(255, 255, 255),
    playerTracer     = Color3.fromRGB(255, 120, 200),
    playerOffscreen  = Color3.fromRGB(255, 200, 60),
    playerVisDot     = Color3.fromRGB(60, 255, 100),

    -- npc per-element
    npcName          = Color3.fromRGB(255, 255, 255),
    npcDistance      = Color3.fromRGB(210, 210, 210),
    npcInfo          = Color3.fromRGB(210, 210, 210),
    npcBox           = Color3.fromRGB(255, 255, 255),
    npcFill          = Color3.fromRGB(255, 160, 60),
    npcOutline       = Color3.fromRGB(255, 255, 255),
    npcHealthHigh    = Color3.fromRGB(60, 255, 100),
    npcHealthLow     = Color3.fromRGB(255, 60, 60),
    npcSkeleton      = Color3.fromRGB(255, 190, 90),
    npcHeadDot       = Color3.fromRGB(255, 255, 255),
    npcTracer        = Color3.fromRGB(255, 170, 60),
    npcOffscreen     = Color3.fromRGB(255, 200, 60),

    -- crates
    crateMilitary    = Color3.fromRGB(80, 200, 255),
    crateElite       = Color3.fromRGB(255, 200, 60),
    crateLoot        = Color3.fromRGB(180, 130, 255),
    crateOpened      = Color3.fromRGB(120, 120, 120),
    crateState       = Color3.fromRGB(60, 255, 120),
    crateDistance    = Color3.fromRGB(210, 210, 210),
    crateTracer      = Color3.fromRGB(140, 200, 255),
    crateOffscreen   = Color3.fromRGB(255, 200, 60),

    -- global overlays (snapline / FOV / lead / current target)
    snapVisible      = Color3.fromRGB(60, 255, 100),
    snapHidden       = Color3.fromRGB(255, 60, 60),
    lead             = Color3.fromRGB(255, 200, 60),
    fov              = Color3.fromRGB(255, 50, 50),
    fovManip         = Color3.fromRGB(255, 160, 40),
    target           = Color3.fromRGB(255, 240, 120),
}
local ESP_COLORS = _G.__saEspColors or {}
for k, v in pairs(ESP_DEFAULT_COLORS) do
    if typeof(ESP_COLORS[k]) ~= "Color3" then ESP_COLORS[k] = v end
end
_G.__saEspColors = ESP_COLORS

-- ────────────────────────────────────────────────────────────────────
-- CONFIG
-- ────────────────────────────────────────────────────────────────────

local CFG = _G.__saCFG or {
    masterEnabled = true,
    debug         = false,

    -- targeting
    fov        = 220,
    distance   = 0,
    wallCheck  = false,
    teamCheck  = true,
    hitChance  = 100,
    targetNpcs = true,
    targetBone = "Head",

    -- gun silent aim
    gunEnabled     = true,
    gunShotOnly    = true,
    gunCooldown    = 0,

    -- ballistics / prediction
    prediction           = true,
    predictionGravity    = true,
    predictionAmmo       = true,
    predictionIterations = 4,
    predictionLatency    = 0,
    gunBulletSpeed       = 0,     -- 0 = exact speed from 07_gun_specs.lua
    gunAmmoOverride      = "Auto",
    saturday2Mode        = false,
    muzzleBoost          = false,

    -- fov visual
    showFov         = false,
    fovFilled       = false,
    fovTransparency = 50,
    fovThickness    = 1,

    -- manipulation
    manipulation      = false,
    manipDist         = 30,
    manipPeek         = 4,
    manipMaxParts     = 3,
    manipBudget       = 40,
    manipHysteresis   = 3,
    manipMaxPeekDelta = 6,

    -- player esp
    espEnabled      = false,
    espShowName     = true,
    espShowDist     = true,
    espShowHealth   = true,
    espMaxDist      = 2000,
    espVisibleCheck = true,
    espShowTool     = true,
    espShowState    = true,

    -- npc esp (Guard / Scavenger / Soldier)
    npcEspEnabled   = false,
    npcShowName     = true,
    npcShowDist     = true,
    npcShowHealth   = true,
    npcShowTool     = true,
    npcShowState    = true,
    npcVisibleCheck = true,
    npcMaxDist      = 2000,

    -- aim preview / snapline
    snapLineEnabled   = true,
    snapLineOrigin    = "Mouse",
    snapLineThickness = 1,
    snapShowLead      = true,

    -- crate esp
    crateEnabled       = false,
    crateShowMilitary  = true,
    crateShowElite     = true,
    crateShowLoot      = true,
    crateShowOpened    = true,
    crateLooseDetect   = true,
    crateMaxDist       = 3000,

    -- esp visual features (shared by players, NPCs and crates)
    espPerElementColors = true,
    espShowBox          = true,
    espCornerBox        = false,
    espShowFill         = true,
    espShowOutline      = false,
    espShowSkeleton     = false,
    espShowHeadDot      = false,
    espShowTracer       = false,
    espShowOffscreen    = false,
    espHighlightTarget  = true,
    espRainbow          = false,
    espRainbowSpeed     = 2,
    espFade             = false,
    espFadeStart        = 60,
    espBoxThickness     = 1,
    espTracerOrigin     = "Bottom",
    npcUseTypeColors    = false,

    -- gun mods
    gmEnabled      = false,
    gmInstantEquip = false,
    gmInstantAds   = false,
    gmNoSpread     = false,
    gmForceAuto    = false,
    gmNoRecoil     = false,
    gmNoSway       = false,
    gmNoKick       = false,
}
_G.__saCFG = CFG

-- backfill (keeps settings from older versions usable)
for k, v in pairs({
    manipulation = false, manipDist = 30, manipPeek = 4, manipMaxParts = 3,
    manipBudget = 40, manipHysteresis = 3, manipMaxPeekDelta = 6,
    espEnabled = false, espShowName = true, espShowDist = true,
    espShowHealth = true, espMaxDist = 2000,
    espVisibleCheck = true, espShowTool = true, espShowState = true,
    npcEspEnabled = false, npcShowName = true, npcShowDist = true,
    npcShowHealth = true, npcShowTool = true, npcShowState = true,
    npcVisibleCheck = true, npcMaxDist = 2000,
    snapLineEnabled = true, snapLineOrigin = "Mouse", snapLineThickness = 1,
    snapShowLead = true,
    prediction = true, predictionGravity = true, predictionAmmo = true,
    predictionIterations = 4, predictionLatency = 0, gunBulletSpeed = 0,
    gunAmmoOverride = "Auto", saturday2Mode = false, muzzleBoost = false,
    crateEnabled = false, crateShowMilitary = true, crateShowElite = true,
    crateShowLoot = true, crateShowOpened = true, crateLooseDetect = true,
    crateMaxDist = 3000,
    espPerElementColors = true, espShowBox = true, espCornerBox = false,
    espShowFill = true, espShowOutline = false, espShowSkeleton = false,
    espShowHeadDot = false, espShowTracer = false, espShowOffscreen = false,
    espHighlightTarget = true, espRainbow = false, espRainbowSpeed = 2,
    espFade = false, espFadeStart = 60, espBoxThickness = 1,
    espTracerOrigin = "Bottom", npcUseTypeColors = false,
    gmEnabled = false, gmInstantEquip = false, gmInstantAds = false,
    gmNoSpread = false, gmForceAuto = false, gmNoRecoil = false,
    gmNoSway = false, gmNoKick = false,
}) do if CFG[k] == nil then CFG[k] = v end end

-- The old hardcoded GUN_SPEEDS / GUN_DEFAULT_SPEED table is gone.
-- Exact per-gun projectile speeds, ammo damage, gravity, life and range
-- live in 07_gun_specs.lua; 08_prediction.lua does the intercept solve.
