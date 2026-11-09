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
-- The ESP labels and the nearest-player HUD both convert Roblox studs to
-- metres with the same factor (1 m ≈ 3.571 studs).
SA.STUDS_PER_METER = 3.571
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
-- ESP FONT — TAHOMA
-- Roblox's `Enum.Font` has NO "Tahoma" member (Legacy / Arial / Gotham /
-- SourceSans / ... only). Prefer a real Tahoma `FontFace` through the
-- newer Font datatype (Font.fromName, then the Tahoma family asset), and
-- keep a bundled enum as a hard fallback so text never disappears on a
-- client that cannot load a custom family. Every ESP TextLabel goes
-- through SA.ApplyEspFont(), including the screen-space labels added by
-- SA.NewDraw("Text") and the ESP Preview panel.
-- ────────────────────────────────────────────────────────────────────
local tahomaEnum, tahomaFace = nil, nil
pcall(function() tahomaEnum = Enum.Font.Tahoma end)  -- patched executors
pcall(function()
    tahomaFace = Font.fromName("Tahoma", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
end)
if not tahomaFace then
    pcall(function()
        tahomaFace = Font.new("rbxasset://fonts/families/Tahoma.json",
            Enum.FontWeight.Regular, Enum.FontStyle.Normal)
    end)
end
SA.ESP_FONT      = tahomaEnum or Enum.Font.ArialBold
SA.ESP_FONT_FACE = tahomaFace
SA.ESP_FONT_NAME = (tahomaFace or tahomaEnum) and "Tahoma" or "ArialBold (Tahoma fallback)"

function SA.ApplyEspFont(lbl)
    if not lbl then return end
    pcall(function() lbl.Font = SA.ESP_FONT end)
    if SA.ESP_FONT_FACE then
        -- FontFace wins over the legacy Font property when it loads; if
        -- the family is unavailable the pcall keeps the enum fallback.
        pcall(function() lbl.FontFace = SA.ESP_FONT_FACE end)
    end
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
    muzzleBoost          = false,   -- manual fallback for muzzle_boost

    -- attachment auto tune (08_attachments.lua)
    attachmentAutoTune      = true,   -- detect + fold attachments into prediction
    attachmentAds           = false,  -- force ADS spread (else RMB is read)
    attachmentAimTune       = true,   -- sights/grip add aim-time lead
    attachmentAimScale      = 1,      -- 0 disables the aim-time lead
    attachmentSilencerSpeed = 0.85,   -- ESTIMATE: "slower bullets"
    attOverrideSight        = "Auto", -- Auto / None / <attachment id>
    attOverrideMuzzle       = "Auto",
    attOverrideUnder        = "Auto",
    attOverrideMag          = "Auto",

    -- fov visual (the FOV circle is THE reference point for aiming)
    showFov         = true,
    fovFilled       = false,
    fovTransparency = 50,
    fovThickness    = 1,
    fovCenterMode   = "Mouse",     -- "Mouse" / "Screen Center"
    forceGuiDrawing = true,        -- ScreenGui backend always works; native Drawing often doesn't

    -- manipulation — CLASSIC six-slider set (8 peek dirs + shared ray params)
    -- Ranges are deliberately tight: 0-300 studs, base peek 4-6 only.
    -- Every slider below has a real effect in 05_manipulation.lua.
    manipulation      = false,
    manipDist         = 30,     -- studs, slider 0..300
    manipPeek         = 4,      -- base peek, slider 4..6
    manipMaxParts     = 3,      -- slider 0..8
    manipBudget       = 40,     -- rays / frame, slider 8..128
    manipHysteresis   = 3,      -- frames, slider 0..12
    manipMaxPeekDelta = 6,      -- slider 2..12 (genuinely caps the peek)

    -- silent aim v7.7 (tap-fire reorder; GUNS ONLY — bows are skipped)
    saTapReorder = true,        -- Fix A (InputBegan) + Fix B (Tool.Activated)
    saTapWindow  = 0.35,        -- PATCH: widened from 0.2

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
    -- New ESP text layout (Tahoma, weapon below the box, tags at corner)
    espTagSide          = true,    -- VIS/WALL, state, HP beside top-right corner
    espTagBackdrop      = true,    -- dark pill behind each side tag
    npcUseTypeColors    = false,

    -- ESP preview panel (Atlanta's floating "ESP Preview" window)
    espPreview       = true,
    espPreviewSpin   = true,
    espPreviewSpeed  = 25,         -- degrees / second
    -- The preview mirrors EITHER the Player or the NPC ESP pipeline
    -- (flags, palette, archetype colours, feature set). "Simulate Aim
    -- Target" paints it with the global target colour.
    espPreviewKind   = "Player",   -- "Player" / "NPC"
    espPreviewTarget = false,
    -- Small HUD that appears when the Atlanta menu is hidden / minimised.
    -- Reports the nearest player, their distance in metres and held tool.
    nearestWindow    = true,

    -- gun mods
    gmEnabled      = false,
    gmInstantEquip = false,
    gmInstantAds   = false,
    gmNoSpread     = false,
    gmForceAuto    = false,
    gmNoRecoil     = false,
    gmNoSway       = false,
    gmNoKick       = false,

    -- bow mods (GC scan; NOT part of silent aim / manipulation)
    -- Only two features: instant (max) charge and no shot cooldown.
    bowModsEnabled   = false,
    bowInstantCharge = false,
    bowNoCooldown    = false,
}
_G.__saCFG = CFG

-- backfill (keeps settings from older versions usable)
for k, v in pairs({
    manipulation = false, manipDist = 30, manipPeek = 4,
    manipMaxParts = 3, manipBudget = 40, manipHysteresis = 3, manipMaxPeekDelta = 6,
    saTapReorder = true, saTapWindow = 0.35,
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
    attachmentAutoTune = true, attachmentAds = false, attachmentAimTune = true,
    attachmentAimScale = 1, attachmentSilencerSpeed = 0.85,
    attOverrideSight = "Auto", attOverrideMuzzle = "Auto",
    attOverrideUnder = "Auto", attOverrideMag = "Auto",
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
    espTagSide = true, espTagBackdrop = true,
    espPreview = true, espPreviewSpin = true, espPreviewSpeed = 25,
    espPreviewKind = "Player", espPreviewTarget = false,
    nearestWindow = true,
    npcUseTypeColors = false,
    gmEnabled = false, gmInstantEquip = false, gmInstantAds = false,
    gmNoSpread = false, gmForceAuto = false, gmNoRecoil = false,
    gmNoSway = false, gmNoKick = false,
    bowModsEnabled = false, bowInstantCharge = false, bowNoCooldown = false,
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

-- One-time migration back to the CLASSIC manipulation slider set. v7.7
-- pushed every value outside the useful 0-300 / 4-6 window and added an
-- "Adaptive Peek Cap" that silently turned Max Peek Delta into a no-op.
-- Only replace values still equal to a known v7.7 default, so a profile
-- the user tuned by hand is never clobbered.
if _G.__saManipFix ~= 3 then
    local v77Dist  = { [1000] = true, [850] = true }
    local v77Peek  = { [20] = true }
    local v77Parts = { [48] = true, [20] = true }
    local v77Budg  = { [96] = true, [48] = true }
    local v77Delta = { [40] = true, [20] = true }
    if v77Dist[CFG.manipDist]                 then CFG.manipDist = 75 end
    if v77Peek[CFG.manipPeek]                 then CFG.manipPeek = 4 end
    if v77Parts[CFG.manipMaxParts]            then CFG.manipMaxParts = 3 end
    if v77Budg[CFG.manipBudget]               then CFG.manipBudget = 64 end
    if v77Delta[CFG.manipMaxPeekDelta]        then CFG.manipMaxPeekDelta = 6 end
    CFG.manipMaxPeek = nil                    -- retire the adaptive cap
    if CFG.saTapReorder == nil                then CFG.saTapReorder = true end
    if CFG.saTapWindow == nil                 then CFG.saTapWindow = 0.35 end
    -- Bows are no longer aimed; drop the retired flag from saved profiles.
    CFG.saBowHook = nil
    _G.__saManipFix = 3
end

-- Clamp on EVERY load: saved profiles, preset imports and console edits
-- must all land inside the slider ranges or the controls lie about what
-- they do. `manipMaxPeek` is removed from saved configs entirely.
local function saClampNum(v, lo, hi, def)
    local n = tonumber(v)
    if not n then return def end
    return math.clamp(n, lo, hi)
end
CFG.manipDist         = saClampNum(CFG.manipDist, 0, 300, 30)
CFG.manipPeek         = saClampNum(CFG.manipPeek, 4, 6, 4)
CFG.manipMaxParts     = saClampNum(CFG.manipMaxParts, 0, 8, 3)
CFG.manipBudget       = saClampNum(CFG.manipBudget, 8, 128, 40)
CFG.manipHysteresis   = saClampNum(CFG.manipHysteresis, 0, 12, 3)
CFG.manipMaxPeekDelta = saClampNum(CFG.manipMaxPeekDelta, 2, 12, 6)
CFG.manipMaxPeek      = nil
-- Preview mirror inputs must also land inside their widget ranges; an
-- out-of-range / bogus saved value would otherwise make the Player/NPC
-- switch silently fall into the wrong pipeline forever.
CFG.espPreviewSpeed  = saClampNum(CFG.espPreviewSpeed, 0, 90, 25)
CFG.espPreviewKind   = (CFG.espPreviewKind == "NPC") and "NPC" or "Player"
CFG.espPreviewTarget = CFG.espPreviewTarget == true
CFG.nearestWindow    = CFG.nearestWindow ~= false  -- HUD defaults ON

-- The old hardcoded GUN_SPEEDS / GUN_DEFAULT_SPEED table is gone.
-- Exact per-gun projectile speeds, ammo damage, gravity, life and range
-- live in 07_gun_specs.lua; 08_prediction.lua does the intercept solve.
