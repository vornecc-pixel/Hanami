-- ==================================================================
-- Hanami / 08_attachments.lua — Attachment defs, detection, auto tune
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- ATTACHMENTS (pasted `Attachments` / `AttFit` / `ATT_*` tables)
--
-- Every attachment definition is kept with its slot, model name, tag and
-- description. Detection walks the equipped Tool's attributes, slot
-- attributes, ValueBase children and descendant names/ItemIds. The
-- resolved effects are folded into SA.GetEquippedGun()'s result, so
-- SA.Predict() automatically uses the tuned projectile speed and extra
-- aim-time lead. No manual toggle is needed.
--
-- Where the pasted descriptions give a percentage (recoil, spread, rate,
-- damage, mag) the number is exact. Where they only give words ("slower
-- bullets", "slower to aim", "steadier aim") the value is an ESTIMATE in
-- ATT_EFFECTS / CFG and is clearly marked as tunable. See the README.
-- ────────────────────────────────────────────────────────────────────

local ATT_SLOTS     = { "sight", "muzzle", "under", "mag" }
local ATT_SLOT_NAME = { sight="Sight", muzzle="Muzzle", under="Underbarrel", mag="Magazine" }
local ATT_TAG = {
    red_dot_sight="RED DOT", holo_sight="HOLO", scope_4x="4X", acog_sight="ACOG", reflex_sight="REFLEX",
    muzzle_brake="BRAKE", silencer="SUPP", muzzle_boost="BOOST",
    vertical_grip="GRIP", laser_sight="LASER", flashlight="LIGHT",
    mag_extender="EXT MAG",
}
local MAG_EXT = { MULT = 1.3333333333333333 }

local ATTACHMENTS = {
    -- SIGHT slot
    red_dot_sight = {name="Red Dot Sight", kind="attachment", attach="sight", stack=1, model="RedDotSight", color=Color3.fromRGB(150,60,50),
        desc="Drag onto a gun to attach  ·  a clear red dot to aim with"},
    holo_sight = {name="Holo Sight", kind="attachment", attach="sight", stack=1, model="HoloSight", color=Color3.fromRGB(70,90,100),
        desc="Drag onto a gun to attach  ·  wide window, slight zoom, steadier aim", removed=true},
    scope_4x = {name="4x Scope", kind="attachment", attach="sight", stack=1, model="Scope4x", color=Color3.fromRGB(40,44,48),
        desc="Drag onto a gun to attach  ·  4x zoom for long shots"},
    acog_sight = {name="3x ACOG Sight", kind="attachment", attach="sight", stack=1, model="AcogSight", color=Color3.fromRGB(52,50,44),
        desc="Drag onto a gun to attach  ·  3x zoom, red chevron  ·  a bit slower to aim"},
    reflex_sight = {name="Reflex Sight", kind="attachment", attach="sight", stack=1, model="ReflexSight", color=Color3.fromRGB(60,120,70),
        desc="Drag onto a gun to attach  ·  Red Dot zoom, green chevron  ·  faster to aim, a bit less steady"},

    -- MUZZLE slot
    muzzle_brake = {name="Muzzle Brake", kind="attachment", attach="muzzle", stack=1, model="MuzzleBrake", color=Color3.fromRGB(58,60,62),
        desc="Drag onto a gun to attach  ·  -30% recoil  ·  +15% spread, louder"},
    silencer = {name="Silencer", kind="attachment", attach="muzzle", stack=1, model="Silencer", color=Color3.fromRGB(36,38,40),
        desc="Drag onto a gun to attach  ·  quiet shots, no tracers, -10% recoil  ·  slower bullets, wears out",
        dur=300, repair={metal_fragments=200, high_quality_metal=8, cloth=20}, durWord="Silencer"},
    muzzle_boost = {name="Muzzle Boost", kind="attachment", attach="muzzle", stack=1, model="MuzzleBoost", color=Color3.fromRGB(66,62,58),
        desc="Drag onto a gun to attach  ·  +15% fire rate  ·  -10% damage per bullet, more recoil"},

    -- UNDER slot
    vertical_grip = {name="Vertical Grip", kind="attachment", attach="under", stack=1, model="VerticalGrip", color=Color3.fromRGB(44,44,42),
        desc="Drag onto a gun to attach  ·  -25% vertical recoil  ·  a bit slower to aim"},
    laser_sight = {name="Laser Sight", kind="attachment", attach="under", stack=1, model="LaserSight", color=Color3.fromRGB(120,40,36),
        desc="Drag onto a gun to attach  ·  -40% hip-fire spread  ·  a red dot others can see"},
    flashlight = {name="Flashlight", kind="attachment", attach="under", stack=1, model="Flashlight", color=Color3.fromRGB(150,140,110),
        desc="Drag onto a gun to attach  ·  a light on the gun (V: on / off)  ·  others see it too"},

    -- MAG slot
    mag_extender = {name="Mag Extender", kind="attachment", attach="mag", stack=1, model="MagExtender", color=Color3.fromRGB(48,50,52),
        desc="Drag onto a gun to attach  ·  +33% magazine (AR 40, SMG 32, pistol 13)  ·  rifles, SMG, pistol"},
}
for attId, attDef in pairs(ATTACHMENTS) do
    attDef.id    = attId
    attDef.slot  = attDef.attach
    attDef.tag   = ATT_TAG[attId] or ""
end

-- ATTACHMENT FIT: which guns accept each attachment. Sights are handled
-- by SA.AttachmentFits() (any non-scoped gun; bolt_action_rifle and
-- lr_sniper have scope=8 and are blocked).
local ATT_FIT = {
    muzzle_brake   = {"semi_auto_rifle","assault_rifle","m249","scar","revolver","semi_auto_pistol","custom_smg","bolt_action_rifle","lr_sniper","service_pistol","tactical_smg","drum_smg","lever_carbine","high_caliber_revolver"},
    silencer       = {"semi_auto_rifle","assault_rifle","m249","scar","semi_auto_pistol","custom_smg","bolt_action_rifle","lr_sniper","service_pistol","tactical_smg","drum_smg","lever_carbine"},
    muzzle_boost   = {"revolver","semi_auto_pistol","custom_smg","semi_auto_rifle","assault_rifle","m249","scar","service_pistol","tactical_smg","drum_smg"},
    vertical_grip  = {"semi_auto_rifle","assault_rifle","m249","scar","custom_smg","tactical_smg"},
    laser_sight    = {"semi_auto_rifle","assault_rifle","m249","scar","custom_smg","semi_auto_pistol","service_pistol","tactical_smg","high_caliber_revolver"},
    flashlight     = {"semi_auto_pistol","custom_smg","semi_auto_rifle","assault_rifle","m249","scar","service_pistol","tactical_smg"},
    mag_extender   = {"semi_auto_pistol","custom_smg","semi_auto_rifle","assault_rifle","scar","service_pistol","tactical_smg"},
}

-- ── EFFECTS ─────────────────────────────────────────────────────────
-- Exact values come straight from the descriptions. ESTIMATES are marked:
--   * silencer speed multiplier  -> CFG.attachmentSilencerSpeed (0.85)
--   * sight zoom / adsSpread     -> best-effort reading of the desc
--   * aimMs                      -> extra time-to-aim used as extra lead
-- All of them are editable at runtime through SA.ATT_EFFECTS.
local ATT_EFFECTS = {
    red_dot_sight = { zoom=1,    adsSpread=1.00, aimMs=0   },  -- ESTIMATE: neutral
    holo_sight    = { zoom=1.25, adsSpread=0.90, aimMs=20  },  -- ESTIMATE: "slight zoom, steadier aim"
    scope_4x      = { zoom=4,    adsSpread=0.90, aimMs=60  },  -- exact 4x zoom; aimMs ESTIMATE
    acog_sight    = { zoom=3,    adsSpread=0.95, aimMs=80  },  -- exact 3x zoom; "a bit slower to aim"
    reflex_sight  = { zoom=1,    adsSpread=1.10, aimMs=-30 },  -- ESTIMATE: "faster, a bit less steady"
    muzzle_brake  = { recoil=0.70, spread=1.15 },               -- exact: -30% recoil, +15% spread
    silencer      = { recoil=0.90, speed="cfg_silencer", noTracer=true }, -- exact -10% recoil; speed ESTIMATE
    muzzle_boost  = { rate=1/1.15, damage=0.90, recoil=1.15 }, -- exact +15% rate, -10% damage; recoil ESTIMATE
    vertical_grip = { recoilPitch=0.75, aimMs=50 },             -- exact -25% vertical; aimMs ESTIMATE
    laser_sight   = { spread=0.60 },                            -- exact: -40% hip-fire spread
    flashlight    = {},                                          -- no ballistic effect
    mag_extender  = { mag="ext" },                              -- exact MAG_EXT.MULT formula
}

-- Normalised lookup: ids, display names, model names, tags and a few
-- common synonyms. `norm` comes from 07_gun_specs.lua (hoisted global).
local ATT_LOOKUP = {}       -- full: ids, names, models, tags, synonyms
local ATT_NAME_LOOKUP = {}  -- strong aliases only: for descendant names
local function attIndex(s, id)
    if s == nil or id == nil then return end
    local k = norm(s)
    if k ~= "" then ATT_LOOKUP[k] = id end
end
for attId, attDef in pairs(ATTACHMENTS) do
    attIndex(attId, attId)
    attIndex(attDef.name, attId)
    attIndex(attDef.model, attId)
    attIndex(attDef.tag, attId)
    -- Descendant names use ONLY the strong aliases. Guns commonly have
    -- generic children called "Grip", "Light" or "Muzzle"; matching the
    -- short UI tags there would invent attachments that aren't fitted.
    ATT_NAME_LOOKUP[norm(attId)] = attId
    ATT_NAME_LOOKUP[norm(attDef.name)] = attId
    ATT_NAME_LOOKUP[norm(attDef.model)] = attId
end
local ATT_SYNONYMS = {
    silenced="silencer", suppressed="silencer", suppressor="silencer",
    extendedmag="mag_extender", extendedmagazine="mag_extender",
    muzzlebooster="muzzle_boost", reddot="red_dot_sight",
}
for attWord, attId in pairs(ATT_SYNONYMS) do ATT_LOOKUP[norm(attWord)] = attId end

-- Attribute names that may hold an attachment id even when the executor
-- does not implement Instance:GetAttributes().
local ATT_SLOT_ATTRS = {
    "Sight","SightAttachment","AttachmentSight","Optic","ScopeAttachment",
    "Muzzle","MuzzleAttachment","AttachmentMuzzle","BarrelAttachment",
    "Under","Underbarrel","UnderAttachment","AttachmentUnder",
    "Mag","Magazine","MagAttachment","AttachmentMag",
    "Attachment","Attachments","EquippedAttachments","Mods","Upgrades",
}
local ATT_CHILD_ID_ATTRS = { "ItemId", "Attachment", "AttachmentId", "Item", "WeaponId" }
local ATT_OVERRIDE_KEYS = {
    sight="attOverrideSight", muzzle="attOverrideMuzzle",
    under="attOverrideUnder", mag="attOverrideMag",
}

-- Add one candidate string (plus comma/space separated tokens) to `found`.
local function attCollect(found, s, source, lookup)
    if s == nil then return end
    local lk = lookup or ATT_LOOKUP
    local str = tostring(s)
    if str == "" then return end
    local id = lk[norm(str)]
    if id and not found[id] then found[id] = source or "?" end
    for tok in str:gmatch("[^,;|/%s]+") do
        local tid = lk[norm(tok)]
        if tid and not found[tid] then
            found[tid] = tostring(source or "?") .. ":" .. tok
        end
    end
end

-- Fit check is INFORMATIONAL, not a hard
-- gate: the game may allow a combination the pasted AttFit omits, and the
-- new duel_rifle is not in any list. duel_rifle is a semi_auto_rifle clone.
function SA.AttachmentFits(attId, gunId)
    local d = ATTACHMENTS[attId]
    if not d then return false end
    if gunId == "duel_rifle" then gunId = "semi_auto_rifle" end
    if d.slot == "sight" then
        local spec = GUN_SPECS[gunId]
        return spec == nil or spec.scope == nil
    end
    local list = ATT_FIT[attId]
    if not list then return false end
    for _, g in ipairs(list) do if g == gunId then return true end end
    return false
end

-- Right mouse button = ADS. "Force ADS Spread" is a manual override for
-- executors where IsMouseButtonPressed is unavailable.
function SA.IsAds()
    if CFG.attachmentAds == true then return true end
    local ok, v = pcall(function()
        return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    end)
    return ok and v == true
end

-- ── DETECTION ───────────────────────────────────────────────────────
-- Returns id -> source. Every read is pcall-guarded and the descendant
-- walk is capped, so a strange Tool can never break silent aim.
function SA.DetectAttachments(tool, gunId)
    local found = {}
    if not tool then return found end

    -- 1) All attributes on the tool: both keys (e.g. Silencer=true) and
    --    values (e.g. Muzzle="silencer", Attachments="SUPP,GRIP").
    pcall(function()
        local attrs = tool:GetAttributes()
        if type(attrs) ~= "table" then return end
        for k, v in pairs(attrs) do
            local nk = norm(k)
            if ATT_LOOKUP[nk] then
                local on = false
                if v == true then on = true
                elseif type(v) == "number" and v ~= 0 then on = true
                elseif type(v) == "string" then
                    local nv = norm(v)
                    on = v ~= "" and nv ~= "false" and nv ~= "none"
                        and nv ~= "nil" and nv ~= "0" and nv ~= "off"
                end
                if on then attCollect(found, k, "attr:" .. tostring(k)) end
            end
            if type(v) == "string" then
                attCollect(found, v, "attr:" .. tostring(k))
            end
        end
    end)

    -- 2) Explicit slot attributes (fallback for GetAttributes-less envs).
    pcall(function()
        for _, a in ipairs(ATT_SLOT_ATTRS) do
            local v = tool:GetAttribute(a)
            if type(v) == "string" then
                attCollect(found, v, "slot:" .. a)
            end
        end
    end)

    -- 3) Descendants: attachment model names, ValueBase values and the
    --    ItemId / Attachment attribute on attachment containers.
    pcall(function()
        local kids = tool:GetDescendants()
        local n = math.min(#kids, 400)
        for i = 1, n do
            local o = kids[i]
            attCollect(found, o.Name, "child:" .. o.Name, ATT_NAME_LOOKUP)
            if o:IsA("ValueBase") then
                local okV, val = pcall(function() return o.Value end)
                if okV and type(val) == "string" then
                    attCollect(found, val, "value:" .. o.Name)
                end
            elseif o:IsA("Model") or o:IsA("Folder") or o:IsA("ObjectValue") then
                for _, a in ipairs(ATT_CHILD_ID_ATTRS) do
                    local v = o:GetAttribute(a)
                    if type(v) == "string" then
                        attCollect(found, v, "childattr:" .. a)
                    end
                end
            end
        end
    end)

    -- 4) Per-slot manual overrides ("Auto" / "None" / an attachment id).
    for slot, key in pairs(ATT_OVERRIDE_KEYS) do
        local v = CFG[key]
        if type(v) == "string" and v ~= "Auto" then
            for id in pairs(found) do
                if ATTACHMENTS[id] and ATTACHMENTS[id].slot == slot then
                    found[id] = nil
                end
            end
            if ATTACHMENTS[v] and ATTACHMENTS[v].slot == slot then
                found[v] = "override:" .. key
            end
        end
    end

    -- 5) The legacy manual "Muzzle Boost Equipped" toggle stays usable as
    --    a fallback, but a detected/overridden muzzle always wins.
    if CFG.muzzleBoost and CFG.attOverrideMuzzle ~= "None" then
        local occupied = false
        for id in pairs(found) do
            if ATTACHMENTS[id] and ATTACHMENTS[id].slot == "muzzle" then
                occupied = true
            end
        end
        if not occupied then found.muzzle_boost = "manual toggle" end
    end
    return found
end

-- ── APPLY (called by SA.GetEquippedGun on every resolve) ─────────────
function SA.ApplyAttachments(gun, tool)
    if not gun then return end
    local found = SA.DetectAttachments(tool, gun.id)
    local list = {}
    for id, src in pairs(found) do
        local d = ATTACHMENTS[id]
        list[#list + 1] = {
            id = id, name = d and d.name or id, slot = d and d.slot or "?",
            tag = d and d.tag or "", source = src,
            fits = SA.AttachmentFits(id, gun.id),
        }
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    gun.attachments = list

    local eff = {
        speed=1, damage=1, rate=1, recoil=1, recoilPitch=1,
        spread=1, adsSpread=1, moveSpread=1, zoom=1,
        aimMs=0, magExt=false, noTracer=false,
    }
    for _, e in ipairs(list) do
        local m = ATT_EFFECTS[e.id] or {}
        if m.speed == "cfg_silencer" then
            eff.speed = eff.speed * math.clamp(CFG.attachmentSilencerSpeed or 0.85, 0.4, 1)
        elseif tonumber(m.speed) then eff.speed = eff.speed * m.speed end
        if tonumber(m.damage)      then eff.damage      = eff.damage * m.damage end
        if tonumber(m.rate)        then eff.rate        = eff.rate * m.rate end
        if tonumber(m.recoil)      then eff.recoil      = eff.recoil * m.recoil end
        if tonumber(m.recoilPitch) then eff.recoilPitch = eff.recoilPitch * m.recoilPitch end
        if tonumber(m.spread)      then eff.spread      = eff.spread * m.spread end
        if tonumber(m.adsSpread)   then eff.adsSpread   = eff.adsSpread * m.adsSpread end
        if tonumber(m.moveSpread)  then eff.moveSpread  = eff.moveSpread * m.moveSpread end
        if tonumber(m.zoom)        then eff.zoom = math.max(eff.zoom, m.zoom) end
        if tonumber(m.aimMs) and CFG.attachmentAimTune ~= false then
            eff.aimMs = eff.aimMs + m.aimMs * math.clamp(CFG.attachmentAimScale or 1, 0, 3)
        end
        if m.mag == "ext" then eff.magExt = true end
        if m.noTracer then eff.noTracer = true end
    end

    gun.att          = eff
    gun.attSpeedMult = eff.speed
    gun.attAimMs     = eff.aimMs
    gun.noTracer     = eff.noTracer

    -- Bullet speed is the one effect that really changes the intercept.
    -- A manual "Bullet Speed Override" always wins over auto tuning.
    if not gun.manualSpeed then
        gun.speed = math.max(gun.baseSpeed * eff.speed, 1)
    end
    gun.damage    = gun.baseDamage * eff.damage
    gun.rate      = math.max(gun.baseRate * eff.rate, 0.001)
    gun.spread    = gun.baseSpread * eff.spread
    gun.adsSpread = gun.baseAdsSpread * eff.adsSpread
    gun.moveSpread= gun.baseMoveSpread * eff.moveSpread
    gun.recoil.pitch = (gun.recoil.pitch or 0) * eff.recoil * eff.recoilPitch
    gun.recoil.yaw   = (gun.recoil.yaw or 0) * eff.recoil
    gun.zoom = math.max(gun.zoom or 1, eff.zoom)

    -- MagExtended = max(floor(mag), floor(mag * 1.333... + 0.5))
    if eff.magExt then
        local m = gun.baseMag or 1
        gun.mag = math.max(math.floor(m), math.floor(m * MAG_EXT.MULT + 0.5))
    else
        gun.mag = gun.baseMag
    end

    gun.ads = SA.IsAds()
    -- State-only spread estimate: the game's spread units are not
    -- documented, so this NEVER changes the computed aim point.
    local moveFactor = 0
    pcall(function()
        local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
        if hum then moveFactor = math.clamp(hum.MoveDirection.Magnitude / 16, 0, 1) end
    end)
    gun.effSpread = (gun.ads and gun.adsSpread or gun.spread)
        + (gun.moveSpread or 0) * moveFactor
end

-- ── STATE ACCESSORS ────────────────────────────────────────────────
function SA.AttachmentState()
    local g = SA.GetEquippedGun()
    local ids = {}
    for _, e in ipairs(g.attachments or {}) do ids[#ids + 1] = e.id end
    return {
        auto = CFG.attachmentAutoTune ~= false,
        gunId = g.id, count = #ids, ids = ids, list = g.attachments or {},
        speedMult = g.attSpeedMult or 1,
        baseSpeed = g.baseSpeed, speed = g.speed,
        aimMs = g.attAimMs or 0, ads = g.ads == true,
        effSpread = g.effSpread or 0, zoom = g.zoom or 1,
        mag = g.mag, damage = g.damage, rate = g.rate,
    }
end

function SA.RescanAttachments()
    SA.InvalidateGunCache()
    return SA.AttachmentState()
end


SA.ATTACHMENTS   = ATTACHMENTS
SA.ATT_FIT       = ATT_FIT
SA.ATT_SLOTS     = ATT_SLOTS
SA.ATT_SLOT_NAME = ATT_SLOT_NAME
SA.ATT_TAG       = ATT_TAG
SA.ATT_EFFECTS   = ATT_EFFECTS
SA.MAG_EXT       = MAG_EXT
