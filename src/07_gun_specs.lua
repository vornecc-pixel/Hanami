-- ==================================================================
-- Hanami / 07_gun_specs.lua — Guns, attributes, ammo, damage
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- GAME DATA (pasted `Guns` / `Falloff` tables + u3492 / u3338)
--
-- Every field from the pasted gun table is kept verbatim: name, ammo,
-- mag, pellets, rate, auto, damageMult, s2Damage, spread, adsSpread,
-- moveSpread, speed, reload, recoil, range, plus the optional gravity,
-- life, scope, headGuard, shellReload, rocket, huntOnly and duelOnly.
-- `balance` is derived from s2Damage (the legacy GUN_BALANCE.damage
-- readout) and is NEVER used to compute hits.
--
-- `speed` is the projectile speed (the field is called `speed`, not
-- bulletSpeed). The sniper values already include the u3338.GUNS
-- overrides (bolt_action_rifle 2600 -> 2200, lr_sniper 3000 -> 2600).
--
-- SMGs keep gravity=8 / life=1 from the previously validated u3338
-- ballistic overrides. The pasted `Guns` table is an ITEM table and
-- omits gravity for them; only the two scoped rifles list it. Live
-- values always win when "Sync Gun Defs (GC)" is pressed.
-- ────────────────────────────────────────────────────────────────────

-- Ammo base damage (u3492 Defs[ammo].damage). `duel_ammo` is an
-- ESTIMATE: the Arena Rifle is a semi_auto_rifle clone (same speed,
-- damageMult and s2Damage=39), so it inherits the rifle_ammo base.
local AMMO_DAMAGE = {
    handmade_shell = 13,   -- stack 64
    pistol_bullet  = 32,   -- stack 128
    rifle_ammo     = 40,   -- stack 128
    duel_ammo      = 40,   -- ESTIMATE (see README)
    rocket         = 1,    -- stack 3 (explosive damage is not modelled)
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

-- FALLOFF tables (pasted `Falloff`, per gun family). Stored on each spec
-- for the ballistics resolver; not used by the aim.
local FALLOFF = {
    pistol_family     = { full = 60,  min = 200,  mult = 0.6  },
    smg_family        = { full = 25,  min = 100,  mult = 0.8  },
    rifle_family      = { full = 150, min = 500,  mult = 0.75 },
    semi_auto_rifle   = { full = 250, min = 550,  mult = 0.75 },
    lever_carbine     = { full = 200, min = 550,  mult = 0.75 },
    high_cal_revolver = { full = 150, min = 450,  mult = 0.7  },
    lr_sniper         = { full = 300, min = 1600, mult = 0.7  },
    shotgun_pellet    = { full = 25,  min = 60              },
}

local DEFAULT_RANGE = 550  -- u3492.GUN_RANGE fallback

-- Bows are NOT guns and are deliberately absent from this table. Silent
-- aim / manipulation use SA.IsEquippedBow() below ONLY as a negative gate;
-- no bow ever resolves to a ballistic spec.

local function gunDef(d)
    d.mag        = d.mag or 1
    d.pellets    = d.pellets or 1
    d.rate       = d.rate or 0.2
    d.auto       = d.auto == true
    d.spread     = d.spread or 0
    d.adsSpread  = d.adsSpread or d.spread
    d.moveSpread = d.moveSpread or 0
    d.speed      = d.speed or 1000
    d.recoil     = d.recoil or {}
    d.gravity    = d.gravity or 0
    d.range      = d.range or DEFAULT_RANGE
    d.balance    = d.s2Damage
    return d
end

-- ── id = every attribute from the pasted Guns table ──────────────────
local GUN_SPECS = {
    pipe_shotgun = gunDef{name="Pipe Shotgun", ammo="handmade_shell", mag=1, pellets=8, rate=0.9, auto=false, damageMult=1, s2Damage=11, spread=5, adsSpread=3.25, moveSpread=1, speed=560, reload=2.2, recoil={pitch=5.75,yaw=1.45,recover=6}, range=200, falloff=FALLOFF.shotgun_pellet},
    revolver = gunDef{name="Revolver", ammo="pistol_bullet", mag=8, pellets=1, rate=0.22, auto=false, damageMult=1, s2Damage=27, spread=1.2, adsSpread=0.1, moveSpread=1.8, speed=950, reload=3, recoil={pitch=1.7,yaw=0.45,recover=9}, range=400, falloff=FALLOFF.pistol_family},
    semi_auto_pistol = gunDef{name="Semi-Auto Pistol", ammo="pistol_bullet", mag=10, pellets=1, rate=0.13, auto=false, damageMult=0.85, s2Damage=24, spread=1.5, adsSpread=0.18, moveSpread=1.6, speed=900, reload=2.2, recoil={pitch=1.3,yaw=0.4,recover=10}, range=400, falloff=FALLOFF.pistol_family},
    service_pistol = gunDef{name="Service Pistol", ammo="pistol_bullet", mag=12, pellets=1, rate=0.15, auto=false, damageMult=0.9, s2Damage=28, spread=1.5, adsSpread=0.16, moveSpread=1.6, speed=950, reload=2.3, recoil={pitch=1.5,yaw=0.42,recover=9.5}, range=400, falloff=FALLOFF.pistol_family},
    high_caliber_revolver = gunDef{name="High Caliber Revolver", ammo="pistol_bullet", mag=6, pellets=1, rate=0.35, auto=false, damageMult=1.72, s2Damage=51.5, spread=1.4, adsSpread=0.05, moveSpread=2, speed=1100, reload=4, recoil={pitch=4.5,yaw=0.8,recover=7}, range=700, falloff=FALLOFF.high_cal_revolver},
    custom_smg = gunDef{name="Custom SMG", ammo="pistol_bullet", mag=24, pellets=1, rate=0.1, auto=true, damageMult=0.8, s2Damage=22, spread=2.2, adsSpread=0.45, moveSpread=1.2, speed=900, reload=2.8, recoil={pitch=1.15,yaw=0.6,recover=6,rise=0.3,sway=0.4}, range=450, gravity=8, life=1, falloff=FALLOFF.smg_family},
    hunt_smg = gunDef{name="Dino Hunt SMG", ammo="pistol_bullet", mag=24, pellets=1, rate=0.1, auto=true, damageMult=0.8, s2Damage=20, spread=2.2, adsSpread=0.45, moveSpread=1.2, speed=900, reload=2.8, recoil={pitch=1.15,yaw=0.6,recover=6,rise=0.3,sway=0.4}, range=450, gravity=8, life=1, huntOnly=true, falloff=FALLOFF.pistol_family},
    tactical_smg = gunDef{name="Tactical SMG", ammo="pistol_bullet", mag=30, pellets=1, rate=0.085, auto=true, damageMult=0.75, s2Damage=21, spread=1.8, adsSpread=0.3, moveSpread=1.1, speed=950, reload=2.6, recoil={pitch=0.95,yaw=0.45,recover=6.5,rise=0.25,sway=0.3}, range=450, gravity=8, life=1, falloff=FALLOFF.smg_family},
    drum_smg = gunDef{name="Drum SMG", ammo="pistol_bullet", mag=50, pellets=1, rate=0.095, auto=true, damageMult=0.85, s2Damage=24, spread=2.6, adsSpread=0.55, moveSpread=1.4, speed=880, reload=4.2, recoil={pitch=1.25,yaw=0.65,recover=5.5,rise=0.3,sway=0.45}, range=450, gravity=8, life=1, falloff=FALLOFF.smg_family},
    lever_carbine = gunDef{name="Lever Carbine", ammo="pistol_bullet", mag=10, pellets=1, rate=0.6, auto=false, damageMult=1.4, s2Damage=45, spread=2.5, adsSpread=0.08, moveSpread=2.4, speed=1250, reload=4.85, recoil={pitch=3.8,yaw=0.5,recover=5}, range=700, shellReload={lead=0.5,per=0.4,tail=0.35}, falloff=FALLOFF.lever_carbine},
    semi_auto_rifle = gunDef{name="Semi-Automatic Rifle", ammo="rifle_ammo", mag=16, pellets=1, rate=0.175, auto=false, damageMult=1, s2Damage=39, spread=2, adsSpread=0.06, moveSpread=2, speed=1425, reload=4.4, recoil={pitch=1.2,yaw=0.35,recover=9}, range=900, falloff=FALLOFF.semi_auto_rifle},
    assault_rifle = gunDef{name="Assault Rifle", ammo="rifle_ammo", mag=30, pellets=1, rate=0.133, auto=true, damageMult=0.9, s2Damage=39, spread=2.8, adsSpread=0.25, moveSpread=2, speed=1350, reload=4, recoil={pitch=1.1,yaw=0.5,recover=6,rise=0.25,sway=0.25}, range=900, falloff=FALLOFF.rifle_family},
    m249 = gunDef{name="M249", ammo="rifle_ammo", mag=100, pellets=1, rate=0.12, auto=true, damageMult=1.1, s2Damage=40, spread=3.6, adsSpread=0.4, moveSpread=3, speed=1400, reload=6, recoil={pitch=1.4,yaw=0.6,recover=5,rise=0.25,sway=0.4}, range=900, falloff=FALLOFF.rifle_family},
    scar = gunDef{name="SCAR", ammo="rifle_ammo", mag=20, pellets=1, rate=0.16, auto=true, damageMult=1.15, s2Damage=42, spread=3, adsSpread=0.22, moveSpread=2.2, speed=1450, reload=4.2, recoil={pitch=1.6,yaw=0.62,recover=5.5,rise=0.3,sway=0.3}, range=900, falloff=FALLOFF.rifle_family},
    bolt_action_rifle = gunDef{name="Bolt Action Rifle", ammo="rifle_ammo", mag=5, pellets=1, rate=1.5, auto=false, damageMult=1.9, s2Damage=78, spread=5, adsSpread=0.05, moveSpread=3.5, speed=2200, reload=4.5, recoil={pitch=5.2,yaw=0.7,recover=4}, gravity=30, life=1.9, scope=8, headGuard={item="coffee_can_helmet",keep=0.25}, range=1400},
    lr_sniper = gunDef{name="LR Sniper Rifle", ammo="rifle_ammo", mag=5, pellets=1, rate=1.8, auto=false, damageMult=2.1, s2Damage=82, spread=6, adsSpread=0.03, moveSpread=4, speed=2600, reload=5, recoil={pitch=6.3,yaw=0.8,recover=3.5}, gravity=24, life=1.8, scope=8, headGuard={item="coffee_can_helmet",keep=0.1}, range=1600, falloff=FALLOFF.lr_sniper},
    double_barrel = gunDef{name="Double Barrel Shotgun", ammo="handmade_shell", mag=2, pellets=10, rate=0.25, auto=false, damageMult=1, s2Damage=8, spread=5.5, adsSpread=3.75, moveSpread=1.2, speed=520, reload=3.4, recoil={pitch=7,yaw=1.6,recover=6}, range=200, falloff=FALLOFF.shotgun_pellet},
    pump_shotgun = gunDef{name="Pump Shotgun", ammo="handmade_shell", mag=6, pellets=9, rate=0.9, auto=false, damageMult=1, s2Damage=9, spread=5, adsSpread=3.4, moveSpread=1.2, speed=560, reload=3.55, recoil={pitch=6.6,yaw=1.5,recover=6}, range=200, shellReload={lead=0.55,per=0.45,tail=0.3}, falloff=FALLOFF.shotgun_pellet},
    rocket_launcher = gunDef{name="Rocket Launcher", ammo="rocket", mag=1, pellets=1, rate=1.5, auto=false, damageMult=nil, s2Damage=nil, spread=1.6, adsSpread=0.45, moveSpread=3, speed=80, reload=6, recoil={pitch=7.5,yaw=1.6,recover=3.5}, rocket=true, range=550},
    duel_rifle = gunDef{name="Arena Rifle", ammo="duel_ammo", mag=16, pellets=1, rate=0.175, auto=false, damageMult=1, s2Damage=39, spread=2, adsSpread=0.06, moveSpread=2, speed=1425, reload=4.4, recoil={pitch=1.2,yaw=0.35,recover=9}, range=900, huntOnly=true, duelOnly=true, falloff=FALLOFF.semi_auto_rifle},
}

-- Used when the equipped tool isn't one of the known guns.
local UNKNOWN_SPEC = gunDef{
    name="Unknown / fallback", speed=1000, ammo=nil, damageMult=1,
    pellets=1, rate=0.2, auto=false, gravity=0, life=nil,
    range=DEFAULT_RANGE, balance=nil, falloff=nil, mag=1,
    spread=2, adsSpread=0.5, moveSpread=1, reload=3, recoil={},
}

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
    DinoHuntSMG="hunt_smg", HuntSMG="hunt_smg", ArenaSMG="hunt_smg",
    ArenaRifle="duel_rifle", DuelRifle="duel_rifle",
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
-- otherwise Defs[ammo].damage * damageMult. The real s2Damage numbers
-- are now in the spec table, so no external hook is required.
function SA.GunDamage(id, ammoId, spec)
    spec = spec or GUN_SPECS[id] or UNKNOWN_SPEC
    local s2on = CFG.saturday2Mode
    if not s2on and type(SA.Saturday2) == "function" then
        local ok, v = pcall(SA.Saturday2); s2on = ok and v == true
    end
    if s2on then
        if type(SA.S2Damage) == "function" then
            local ok, v = pcall(SA.S2Damage, id, spec)
            if ok and tonumber(v) then return tonumber(v) end
        end
        if tonumber(spec.s2Damage) then return tonumber(spec.s2Damage) end
    end
    local alt  = AMMO_ALTS[ammoId]
    local base = alt and alt.base or ammoId or spec.ammo
    local dmg  = (AMMO_DAMAGE[base] or 0) * (spec.damageMult or 1)
    if alt then
        if alt.whole then dmg = dmg * spec.pellets * alt.whole
        else dmg = dmg * (alt.damage or 1) end
    end
    return dmg
end

SA.GUN_SPECS   = GUN_SPECS
SA.FALLOFF     = FALLOFF
SA.AMMO_DAMAGE = AMMO_DAMAGE
SA.AMMO_ALTS   = AMMO_ALTS

-- Resolved, cached description of the currently equipped gun. The cache
-- is keyed by the Tool instance as well as time, so switching weapons
-- changes the prediction on the very next frame (important now that
-- attachments are part of the ballistic profile).
local gunCache = { t = 0, val = nil, tool = nil }
function SA.InvalidateGunCache() gunCache.val = nil end

function SA.GetEquippedGun(force)
    local char = lp.Character
    local tool = nil
    if char then pcall(function() tool = char:FindFirstChildOfClass("Tool") end) end
    if not force and gunCache.val and gunCache.tool == tool
        and (tick() - gunCache.t) < 0.15 then
        return gunCache.val
    end
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

    -- Copy recoil rather than pointing at the shared spec table: the
    -- attachment pass multiplies its fields in place on this gun only.
    local recoil = {}
    for k, v in pairs(spec.recoil or {}) do recoil[k] = v end

    local damage = SA.GunDamage(id, ammoId, spec)
    local out = {
        id = id or "unknown", known = id ~= nil, spec = spec, tool = tool,
        ammo = ammoId, alt = alt ~= nil, speed = math.max(speed, 1),
        gravity = gravity, life = spec.life, range = spec.range,
        pellets = pellets, rate = spec.rate, damage = damage,
        -- every new attribute from the pasted Guns table
        mag = spec.mag, spread = spec.spread, adsSpread = spec.adsSpread,
        moveSpread = spec.moveSpread, reload = spec.reload, recoil = recoil,
        zoom = spec.scope or 1, scope = spec.scope, headGuard = spec.headGuard,
        rocket = spec.rocket == true, huntOnly = spec.huntOnly == true,
        duelOnly = spec.duelOnly == true, shellReload = spec.shellReload,
        falloff = spec.falloff,
        -- base values (before attachments) for the state readout
        baseSpeed = math.max(speed, 1), baseDamage = damage,
        baseRate = spec.rate, baseMag = spec.mag,
        baseSpread = spec.spread, baseAdsSpread = spec.adsSpread,
        baseMoveSpread = spec.moveSpread, baseRecoil = spec.recoil,
        manualSpeed = CFG.gunBulletSpeed > 0,
        -- filled in by 08_attachments.lua (auto tune)
        attachments = {}, att = nil, attSpeedMult = 1, attAimMs = 0,
        ads = false, effSpread = spec.spread or 0,
    }
    if CFG.attachmentAutoTune == true then
        if type(SA.ApplyAttachments) == "function" then
            pcall(SA.ApplyAttachments, out, tool)
        end
    elseif CFG.muzzleBoost then
        -- Manual fallback when auto tuning is disabled.
        out.damage = out.damage * 0.9
        out.rate   = out.rate / 1.15
    end
    gunCache.t, gunCache.val, gunCache.tool = tick(), out, tool
    return out
end

-- ────────────────────────────────────────────────────────────────────
-- BOW CLASSIFIER — GUNS-ONLY GATE (NOT an aim path)
-- Bows are deliberately excluded from silent aim / manipulation. This is a
-- plain name/attribute check with NO ballistic data: readToolId() cannot
-- return a bow id because bows are absent from GUN_SPECS. Word stems only;
-- "Elbow Pad" and "Compound Rifle" must not match.
-- ────────────────────────────────────────────────────────────────────
local function bowWord(s)
    local n = norm(s)
    if n == "" or n:find("elbow", 1, true) then return false end
    if n:find("crossbow", 1, true) or n:find("compoundbow", 1, true)
       or n:find("huntingbow", 1, true) or n:find("longbow", 1, true)
       or n:find("shortbow", 1, true) then
        return true
    end
    return n == "bow" or n:sub(1, 3) == "bow"
end

-- Single-Tool check; used to skip bow tools for tap-fire Fix B.
function SA.IsBowTool(tool)
    local ok, found = pcall(function()
        if not tool or not tool:IsA("Tool") then return false end
        if bowWord(tool.Name) then return true end
        for _, a in ipairs(TOOL_ID_ATTRS) do
            local v = tool:GetAttribute(a)
            if v ~= nil and v ~= "" and bowWord(v) then return true end
        end
        return false
    end)
    return ok and found == true
end

-- The EQUIPPED bow disables silent aim / manipulation for the whole frame.
-- Deliberately the same tool SA.GetEquippedGun() resolves, so carrying a
-- bow in another slot never switches off aim for the gun in your hands.
function SA.IsEquippedBow()
    local char = lp.Character
    if not char then return false end
    local ok, tool = pcall(function() return char:FindFirstChildOfClass("Tool") end)
    if not ok or not tool then return false end
    return SA.IsBowTool(tool) == true
end
