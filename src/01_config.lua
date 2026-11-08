-- ==================================================================
-- Hanami / 01_config.lua — Services, config defaults, backfill, shared state
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
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

-- Every RenderStepped loop binds through this helper. Re-executing the
-- loader bumps Generation, so loops from the previous run disconnect
-- themselves instead of piling up duplicate work (a common cause of a
-- stutter that gets worse the more times you run the script).
local function bindRender(fn)
    local gen = SA.Generation
    local conn
    conn = RunService.RenderStepped:Connect(function(...)
        if (SA.Generation or 0) ~= gen then
            pcall(function() conn:Disconnect() end)
            return
        end
        fn(...)
    end)
    return conn
end

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
    predictionAutoPing   = true,   -- read live ping, no manual guessing
    predictionPingScale  = 1,      -- multiplier on the measured ping
    predictionLatency    = 0,      -- extra manual offset on top of auto ping
    gunBulletSpeed       = 0,     -- 0 = exact speed from 07_gun_specs.lua
    gunAmmoOverride      = "Auto",
    saturday2Mode        = false,
    muzzleBoost          = false,

    -- fov visual (the FOV circle is THE reference point for aiming)
    showFov         = true,
    fovFilled       = false,
    fovTransparency = 50,
    fovThickness    = 1,
    fovCenterMode   = "Mouse",     -- "Mouse" / "Screen Center"
    forceGuiDrawing = true,        -- ScreenGui backend always works; native Drawing often doesn't

    -- manipulation v4 (v7.7 defaults — adaptive peek, 8 directions)
    manipulation      = false,
    manipDist         = 1000,   -- was 30
    manipPeek         = 20,     -- was 4 (base peek; scales with distance)
    manipMaxPeek      = 120,    -- NEW: ceiling for the adaptive peek
    manipMaxParts     = 48,     -- was 20 in the extract / 3 in the old build
    manipBudget       = 96,     -- was 48 / 40
    manipHysteresis   = 3,
    manipMaxPeekDelta = 40,     -- was 20 / 6

    -- silent aim v7.7 (tap-fire reorder + bow remote hook)
    saTapReorder = true,        -- Fix A (InputBegan) + Fix B (Tool.Activated)
    saTapWindow  = 0.35,        -- PATCH: widened from 0.2
    saBowHook    = true,        -- hook ReplicatedStorage.Fust.Remotes.Shoot

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
    crateHighlight     = false,    -- off by default: no stray chams on scenery
    crateInvertState   = false,    -- flip if the game's opened/closed signal is inverted
    crateLidDetect     = false,    -- lid-angle guess is unreliable; opt-in only
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
    espArrowFOV         = true,    -- arrows sit on the FOV circle edge
    espTextSize         = 11,      -- one slider for ALL ESP text
    espShowHealthText   = false,
    espTextOutline      = true,
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
    manipulation = false, manipDist = 1000, manipPeek = 20, manipMaxPeek = 120,
    manipMaxParts = 48, manipBudget = 96, manipHysteresis = 3, manipMaxPeekDelta = 40,
    saTapReorder = true, saTapWindow = 0.35, saBowHook = true,
    espEnabled = false, espShowName = true, espShowDist = true,
    espShowHealth = true, espMaxDist = 2000,
    espVisibleCheck = true, espShowTool = true, espShowState = true,
    npcEspEnabled = false, npcShowName = true, npcShowDist = true,
    npcShowHealth = true, npcShowTool = true, npcShowState = true,
    npcVisibleCheck = true, npcMaxDist = 2000,
    snapLineEnabled = true, snapLineOrigin = "Mouse", snapLineThickness = 1,
    snapShowLead = true,
    prediction = true, predictionGravity = true, predictionAmmo = true,
    predictionIterations = 4, predictionAutoPing = true, predictionPingScale = 1,
    predictionLatency = 0, gunBulletSpeed = 0,
    gunAmmoOverride = "Auto", saturday2Mode = false, muzzleBoost = false,
    crateEnabled = false, crateShowMilitary = true, crateShowElite = true,
    crateShowLoot = true, crateShowOpened = true, crateLooseDetect = true,
    crateHighlight = false, crateInvertState = false, crateLidDetect = false,
    crateMaxDist = 3000,
    showFov = true, fovFilled = false, fovTransparency = 50, fovThickness = 1,
    fovCenterMode = "Mouse", forceGuiDrawing = true,
    espPerElementColors = true, espShowBox = true, espCornerBox = false,
    espShowFill = true, espShowOutline = false, espShowSkeleton = false,
    espShowHeadDot = false, espShowTracer = false, espShowOffscreen = false,
    espHighlightTarget = true, espRainbow = false, espRainbowSpeed = 2,
    espFade = false, espFadeStart = 60, espBoxThickness = 1,
    espTracerOrigin = "Bottom", espArrowFOV = true, espTextSize = 11,
    espShowHealthText = false, espTextOutline = true,
    npcUseTypeColors = false,
    gmEnabled = false, gmInstantEquip = false, gmInstantAds = false,
    gmNoSpread = false, gmForceAuto = false, gmNoRecoil = false,
    gmNoSway = false, gmNoKick = false,
}) do if CFG[k] == nil then CFG[k] = v end end

-- One-time migration for configs saved by older builds: those defaulted
-- showFov to FALSE and inverted the transparency slider, so the circle
-- stayed invisible even after the code was fixed. Force it visible ONCE.
if _G.__saFovFix ~= 2 then
    CFG.showFov = true
    CFG.fovTransparency = 50
    CFG.fovThickness = math.max(CFG.fovThickness or 1, 1)
    CFG.fovCenterMode = "Mouse"
    CFG.forceGuiDrawing = true
    _G.__saFovFix = 2
end

-- One-time migration: v7.7 raised the manipulation defaults a lot. Only
-- replace values that are still one of the OLD defaults, so a profile the
-- user tuned is never clobbered. Old values came from either the pre-v7.7
-- build (30/4/3/40/6) or the v7.7 extract (850/20/20/48/40).
if _G.__saManipFix ~= 2 then
    local oldDist  = { [30] = true, [75] = true, [850] = true }
    local oldPeek  = { [4] = true }
    local oldParts = { [3] = true, [20] = true }
    local oldBudg  = { [40] = true, [48] = true, [64] = true }
    local oldDelta = { [6] = true, [20] = true }
    if oldDist[CFG.manipDist]                 then CFG.manipDist = 1000 end
    if oldPeek[CFG.manipPeek]                 then CFG.manipPeek = 20 end
    if oldParts[CFG.manipMaxParts]            then CFG.manipMaxParts = 48 end
    if oldBudg[CFG.manipBudget]               then CFG.manipBudget = 96 end
    if oldDelta[CFG.manipMaxPeekDelta]        then CFG.manipMaxPeekDelta = 40 end
    if CFG.manipMaxPeek == nil                then CFG.manipMaxPeek = 120 end
    if CFG.saTapReorder == nil                then CFG.saTapReorder = true end
    if CFG.saTapWindow == nil                 then CFG.saTapWindow = 0.35 end
    if CFG.saBowHook == nil                   then CFG.saBowHook = true end
    _G.__saManipFix = 2
end

-- The old hardcoded GUN_SPEEDS / GUN_DEFAULT_SPEED table is gone.
-- Exact per-gun projectile speeds, ammo damage, gravity, life and range
-- live in 07_gun_specs.lua; 08_prediction.lua does the intercept solve.
