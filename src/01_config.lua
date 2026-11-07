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
local SoundService      = game:GetService("SoundService")
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
SA.Target = SA.Target or {}   -- current aim-preview target, written by 09_snapline

-- Colours live here so every drawing part and every UI colourpicker
-- writes the same shared locals.
local espColor         = Color3.fromRGB(255, 60, 60)  -- flat colour when check is off
local espColorVisible  = Color3.fromRGB(60, 255, 100)
local espColorHidden   = Color3.fromRGB(255, 60, 60)
local npcColorVisible  = Color3.fromRGB(60, 255, 100)
local npcColorHidden   = Color3.fromRGB(255, 60, 60)
local snapColorVisible = Color3.fromRGB(60, 255, 100)
local snapColorHidden  = Color3.fromRGB(255, 60, 60)
local fovColor         = Color3.fromRGB(255, 50, 50)

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
    prediction = true,
    targetNpcs = true,
    targetBone = "Head",

    -- gun silent aim
    gunEnabled     = true,
    gunShotOnly    = true,
    gunBulletSpeed = 0,
    gunCooldown    = 0,

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

    -- crate esp
    crateEnabled       = false,
    crateShowMilitary  = true,
    crateShowElite     = true,
    crateShowOpened    = true,
    crateMaxDist       = 3000,

    -- gun mods
    gmEnabled      = false,
    gmInstantEquip = false,
    gmInstantAds   = false,
    gmNoSpread     = false,
    gmForceAuto    = false,
    gmNoRecoil     = false,
    gmNoSway       = false,
    gmNoKick       = false,

    -- hit sound
    hitSoundEnabled = false,
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
    crateEnabled = false, crateShowMilitary = true, crateShowElite = true,
    crateShowOpened = true, crateMaxDist = 3000,
    gmEnabled = false, gmInstantEquip = false, gmInstantAds = false,
    gmNoSpread = false, gmForceAuto = false, gmNoRecoil = false,
    gmNoSway = false, gmNoKick = false, hitSoundEnabled = false,
}) do if CFG[k] == nil then CFG[k] = v end end

local GUN_SPEEDS = {
    assault_rifle = 1173, semi_auto_rifle = 1110, bolt_action_rifle = 1200,
    hunting_rifle = 1100, tactical_smg = 825, custom_smg = 824, hunt_smg = 825,
    m249 = 1097, pump_shotgun = 525, double_barrel = 525, pipe_shotgun = 525,
    pistol = 828, service_pistol = 828, revolver = 885,
    musket = 1100, flintlock = 700, rocket_launcher = 250,
}
local GUN_DEFAULT_SPEED = 1000
