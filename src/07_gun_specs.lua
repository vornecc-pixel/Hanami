-- ==================================================================
-- Hanami / 07_gun_specs.lua — Exact gun definitions, ammo, damage
-- Loaded in order by loader.lua. Parts are joined into ONE chunk
-- before running, so every `local` is shared just like the original.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- GAME DATA (from u3492 / u3338)
-- NOTE: the `damage` field on every gun definition is 0 and is NOT the
-- damage. Real damage = Defs[ammo].damage * damageMult, or s2Damage when
-- Saturday2() is on. `balance` below is GUN_BALANCE.damage (UI/legacy
-- number) and is only printed for reference — never used to compute hits.
--
-- `speed` is the projectile speed (the field is called `speed`, not
-- bulletSpeed). Values below already include the u3338.GUNS overrides
-- for bolt_action_rifle (2600 -> 2200) and lr_sniper (3000 -> 2600).
-- ────────────────────────────────────────────────────────────────────

-- Ammo base damage (u3492 Defs[ammo].damage)
local AMMO_DAMAGE = {
    handmade_shell = 13,   -- stack 64
    pistol_bullet  = 32,   -- stack 128
    rifle_ammo     = 40,   -- stack 128
    rocket         = 1,    -- stack 3
}

-- Alternate ammo. `speed`/`damage`/`pellets` are multipliers; `speedAbs`
-- is an absolute override; `gravity` overrides the gun's bullet drop.
local AMMO_ALTS = {
    hv_rifle_ammo       = { base = "rifle_ammo",     speed = 1.5, damage = 0.85 },
    explosive_rifle_ammo= { base = "rifle_ammo" },
    buckshot_shell      = { base = "handmade_shell", damage = 1.35, pellets = 0.75 },
    slug_shell          = { base = "handmade_shell", pellets = 1, whole = 0.7 },
    hv_rocket           = { base = "rocket",          speedAbs = 140, gravity = 2 },
    incendiary_rocket   = { base = "rocket" },
}

-- GUN_BALANCE falloff profiles (used for the spec readout, not for aim)
local F_V20 = { full = 60,  min = 200,  mult = 0.6  }  -- revolver, semi_auto_pistol, service_pistol, hunt_smg
local F_V21 = { full = 25,  min = 100,  mult = 0.8  }  -- custom_smg, tactical_smg, drum_smg
local F_V22 = { full = 150, min = 500,  mult = 0.75 }  -- scar, assault_rifle, m249
local F_PEL = { full = 25,  min = 60              }  -- pellet falloff (all 3 shotguns)

local DEFAULT_RANGE = 550  -- u3492.GUN_RANGE fallback

local function S(name, speed, ammo, mult, pellets, rate, auto, gravity, life, range, balance, falloff)
    return {
        name = name, speed = speed, ammo = ammo, damageMult = mult,
        pellets = pellets, rate = rate, auto = auto,
        gravity = gravity or 0, life = life, range = range or DEFAULT_RANGE,
        balance = balance, falloff = falloff,
    }
end

-- id = name, speed, ammo, damageMult, pellets, rate, auto, gravity, life, GUN_RANGE, GUN_BALANCE.damage, falloff
local GUN_SPECS = {
    pipe_shotgun          = S("Pipe Shotgun",           560, "handmade_shell", 1,    8,  0.9,   false, 0,  nil,  200, 11,   F_PEL),
    revolver              = S("Revolver",               950, "pistol_bullet",  1,    1,  0.22,  false, 0,  nil,  400, 27,   F_V20),
    custom_smg            = S("Custom SMG",             900, "pistol_bullet",  0.8,  1,  0.1,   true,  8,  1,    450, 22,   F_V21),
    hunt_smg              = S("Dino Hunt SMG",          900, "pistol_bullet",  0.8,  1,  0.1,   true,  8,  1,    450, 20,   F_V20),
    semi_auto_rifle       = S("Semi-Automatic Rifle", 1425, "rifle_ammo",     1,    1,  0.175, false, 0,  nil,  900, 39,   { full=250, min=550,  mult=0.75 }),
    assault_rifle         = S("Assault Rifle",        1350, "rifle_ammo",     0.9,  1,  0.133, true,  0,  nil,  900, 39,   F_V22),
    m249                  = S("M249",                 1400, "rifle_ammo",     1.1,  1,  0.12,  true,  0,  nil,  900, 40,   F_V22),
    semi_auto_pistol      = S("Semi-Auto Pistol",      900, "pistol_bullet",  0.85, 1,  0.13,  false, 0,  nil,  400, 24,   F_V20),
    bolt_action_rifle     = S("Bolt Action Rifle",    2200, "rifle_ammo",     1.9,  1,  1.5,   false, 30, 1.9, 1400, 78,   nil),
    lr_sniper             = S("LR Sniper Rifle",      2600, "rifle_ammo",     2.1,  1,  1.8,   false, 24, 1.8, 1600, 82,   { full=300, min=1600, mult=0.7 }),
    scar                  = S("SCAR",                 1450, "rifle_ammo",     1.15, 1,  0.16,  true,  0,  nil,  900, 42,   F_V22),
    double_barrel         = S("Double Barrel Shotgun", 520, "handmade_shell", 1,    10, 0.25,  false, 0,  nil,  200, 8,    F_PEL),
    rocket_launcher       = S("Rocket Launcher",        80, "rocket",         1,    1,  1.5,   false, 0,  nil,  550, nil,  nil),
    pump_shotgun          = S("Pump Shotgun",          560, "handmade_shell", 1,    9,  0.9,   false, 0,  nil,  200, 9,    F_PEL),
    service_pistol        = S("Service Pistol",        950, "pistol_bullet",  0.9,  1,  0.15,  false, 0,  nil,  400, 28,   F_V20),
    tactical_smg          = S("Tactical SMG",          950, "pistol_bullet",  0.75, 1,  0.085, true,  8,  1,    450, 21,   F_V21),
    drum_smg              = S("Drum SMG",              880, "pistol_bullet",  0.85, 1,  0.095, true,  8,  1,    450, 24,   F_V21),
    lever_carbine         = S("Lever Carbine",        1250, "pistol_bullet",  1.4,  1,  0.6,   false, 0,  nil,  700, 45,   { full=200, min=550,  mult=0.75 }),
    high_caliber_revolver = S("High Caliber Revolver",1100, "pistol_bullet",  1.72, 1,  0.35,  false, 0,  nil,  700, 51.5, { full=150, min=450,  mult=0.7 }),
}

-- Used when the equipped tool isn't one of the known guns.
local UNKNOWN_SPEC = S("Unknown / fallback", 1000, nil, 1, 1, 0.2, false, 0, nil, DEFAULT_RANGE, nil, nil)

-- Tool `model` values and display names -> spec ids. Normalised to
-- lowercase alphanumeric so "SemiAutoPistol", "semi_auto_pistol" and
-- "Semi-Auto Pistol" all resolve to the same gun.
local MODEL_TO_ID = {
    PipeShotgun="pipe_shotgun", Revolver="revolver", CustomSMG="custom_smg",
    SemiAutoRifle="semi_auto_rifle", AssaultRifle="assault_rifle", M249="m249",
    SemiAutoPistol="semi_auto_pistol", BoltActionRifle="bolt_action_rifle",
    LRSniper="lr_sniper", ScarRifle="scar", DoubleBarrel="double_barrel",
    RocketLauncher="rocket_launcher", PumpShotgun="pump_shotgun",
    ServicePistol="service_pistol", TacticalSmg="tactical_smg",
    DrumSmg="drum_smg", LeverCarbine="lever_carbine",
    HighCaliberRevolver="high_caliber_revolver",
}
local GUN_ALIASES = {}
local function norm(s) return (tostring(s):lower():gsub("[^%w]", "")) end
for id, spec in pairs(GUN_SPECS) do
    GUN_ALIASES[norm(id)] = id
    GUN_ALIASES[norm(spec.name)] = id
end
for model, id in pairs(MODEL_TO_ID) do GUN_ALIASES[norm(model)] = id end

local TOOL_ID_ATTRS = { "ItemId", "WeaponId", "ToolId", "Item", "Weapon", "Gun" }
local AMMO_ATTRS    = { "Ammo", "AmmoType", "LoadedAmmo", "CurrentAmmo", "AmmoId", "ItemAmmo" }

local function readToolId(tool)
    if not tool then return nil end
    for _, a in ipairs(TOOL_ID_ATTRS) do
        local v = tool:GetAttribute(a)
        if v ~= nil and v ~= "" then
            local id = GUN_ALIASES[norm(v)]
            if id then return id end
        end
    end
    return GUN_ALIASES[norm(tool.Name)]
end

local function readAmmo(tool, spec)
    if CFG.gunAmmoOverride ~= "Auto" then return CFG.gunAmmoOverride end
    if not CFG.predictionAmmo or not tool then return spec.ammo end
    for _, a in ipairs(AMMO_ATTRS) do
        local v = tool:GetAttribute(a)
        if v ~= nil and v ~= "" then
            local k = tostring(v):lower():gsub("%s+", "_")
            if AMMO_DAMAGE[k] or AMMO_ALTS[k] then return k end
        end
    end
    for _, n in ipairs(AMMO_ATTRS) do
        local c = tool:FindFirstChild(n)
        if c and (c:IsA("StringValue") or c:IsA("ObjectValue")) then
            local k = tostring(c.Value):lower():gsub("%s+", "_")
            if AMMO_DAMAGE[k] or AMMO_ALTS[k] then return k end
        end
    end
    return spec.ammo
end

-- Hooks the game can fill in for the Saturday2() branch of GunDamage.
-- e.g. SA.Saturday2 = u3492.Saturday2; SA.S2Damage = function(id, spec) ... end
SA.Saturday2 = SA.Saturday2 or rawget(_G, "Saturday2") or nil
SA.S2Damage  = SA.S2Damage  or rawget(_G, "s2Damage")  or nil

-- u3492.GunDamage: s2Damage if Saturday2() is on,
-- otherwise Defs[ammo].damage * damageMult.
function SA.GunDamage(id, ammoId, spec)
    spec = spec or GUN_SPECS[id] or UNKNOWN_SPEC
    local s2on = CFG.saturday2Mode
    if not s2on and type(SA.Saturday2) == "function" then
        local ok, v = pcall(SA.Saturday2); s2on = ok and v == true
    end
    if s2on and type(SA.S2Damage) == "function" then
        local ok, v = pcall(SA.S2Damage, id, spec)
        if ok and tonumber(v) then return tonumber(v) end
    end
    local alt  = AMMO_ALTS[ammoId]
    local base = alt and alt.base or ammoId or spec.ammo
    local dmg  = (AMMO_DAMAGE[base] or 0) * (spec.damageMult or 1)
    if alt then
        if alt.whole then dmg = dmg * spec.pellets * alt.whole
        else dmg = dmg * (alt.damage or 1) end
    end
    if CFG.muzzleBoost then dmg = dmg * 0.9 end  -- muzzle_boost: -10% damage
    return dmg
end

SA.GUN_SPECS   = GUN_SPECS
SA.AMMO_DAMAGE = AMMO_DAMAGE
SA.AMMO_ALTS   = AMMO_ALTS

-- Resolved, cached description of the currently equipped gun.
local gunCache = { t = 0, val = nil }
function SA.GetEquippedGun(force)
    if not force and gunCache.val and (tick() - gunCache.t) < 0.15 then
        return gunCache.val
    end
    local char = lp.Character
    local tool = char and char:FindFirstChildOfClass("Tool") or nil
    local id   = readToolId(tool)
    local spec = GUN_SPECS[id] or UNKNOWN_SPEC
    local ammoId = readAmmo(tool, spec)
    local alt  = AMMO_ALTS[ammoId]
    local baseAmmo = alt and alt.base or ammoId

    local speed = spec.speed
    if alt and alt.speed then speed = speed * alt.speed end
    if alt and alt.speedAbs then speed = alt.speedAbs end
    if CFG.gunBulletSpeed > 0 then speed = CFG.gunBulletSpeed end

    local gravity = spec.gravity
    if alt and alt.gravity then gravity = alt.gravity end

    local pellets = spec.pellets
    if alt and alt.pellets then
        pellets = alt.pellets == 1 and 1 or math.max(1, math.floor(spec.pellets * alt.pellets))
    end
    local rate = spec.rate
    if CFG.muzzleBoost then rate = rate / 1.15 end  -- +15% fire rate

    local out = {
        id = id or "unknown", known = id ~= nil, spec = spec, tool = tool,
        ammo = ammoId, alt = alt ~= nil, speed = math.max(speed, 1),
        gravity = gravity, life = spec.life, range = spec.range,
        pellets = pellets, rate = rate,
        damage = SA.GunDamage(id, ammoId, spec),
    }
    gunCache.t, gunCache.val = tick(), out
    return out
end

