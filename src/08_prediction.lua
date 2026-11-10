-- ==================================================================
-- Hanami / 08_prediction.lua — Ballistic intercept solver + live gun tuning
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- TARGET VELOCITY
-- Smoothed exponential estimate from HumanoidRootPart positions. Weak
-- keys so despawned models are collected; teleports/respawns are dropped
-- instead of producing a giant bogus lead.
-- ────────────────────────────────────────────────────────────────────

local velTrack = _G.__saVelTrack or setmetatable({}, { __mode = "k" })
_G.__saVelTrack = velTrack

function SA.TargetVelocity(model)
    if not model then return Vector3.zero end
    local hrp = model:FindFirstChild("HumanoidRootPart")
    if not hrp then return Vector3.zero end
    local now, pos = tick(), hrp.Position
    local e = velTrack[model]
    if not e then
        velTrack[model] = { p = pos, t = now, v = Vector3.zero }
        return Vector3.zero
    end
    local dt = now - e.t
    if dt < 0.016 then return e.v end
    local raw = (pos - e.p) / dt
    if raw.Magnitude > 120 then raw = Vector3.zero end  -- teleport guard
    local alpha = math.clamp(dt * 12, 0.15, 0.6)
    e.v = e.v:Lerp(raw, alpha)
    e.p, e.t = pos, now
    return e.v
end

-- ────────────────────────────────────────────────────────────────────
-- LIVE PING (auto extra lead)
-- Player:GetNetworkPing() returns round-trip seconds; the legacy
-- Stats.Network "Data Ping" item is already milliseconds. Both are
-- pcall-guarded, clamped and exponentially smoothed so the lead doesn't
-- jitter when the reported ping fluctuates.
-- ────────────────────────────────────────────────────────────────────

local pingState = { t = 0, ms = 0 }

function SA.GetPing()
    local now = tick()
    if now - pingState.t < 0.25 then return pingState.ms end
    pingState.t = now
    local ms = nil
    pcall(function()
        local v = lp:GetNetworkPing()
        if type(v) == "number" and v > 0 then ms = v * 1000 end
    end)
    if not ms then
        pcall(function()
            local net = game:GetService("Stats"):FindFirstChild("Network")
            local ssi = net and net:FindFirstChild("ServerStatsItem")
            local item = ssi and ssi:FindFirstChild("Data Ping")
            if not item then return end
            if item.GetValue then ms = item:GetValue() end
            if type(ms) ~= "number" and item.Value ~= nil then
                local n = tonumber(tostring(item.Value):match("[%d%.]+"))
                if n then ms = n end
            end
        end)
    end
    if type(ms) ~= "number" or ms < 0 then ms = 0 end
    ms = math.clamp(ms, 0, 1000)
    pingState.ms = (pingState.ms == 0) and ms or (pingState.ms * 0.7 + ms * 0.3)
    return pingState.ms
end

-- Total one-way-ish compensation used by the solver, in milliseconds.
function SA.LeadLatencyMs()
    local auto = CFG.predictionAutoPing and SA.GetPing() or 0
    local scale = CFG.predictionPingScale or 1
    return math.clamp(auto * scale + (CFG.predictionLatency or 0), 0, 1000)
end

-- ────────────────────────────────────────────────────────────────────
-- INTERCEPT SOLVER
-- Exact quadratic solution for a constant-velocity target:
--   |(p0 - o) + v*t|^2 = (s*t)^2
-- then fixed-point refinement for bullet-drop compensation (the aim
-- offset changes the flight time, so it is re-derived every pass).
-- ────────────────────────────────────────────────────────────────────

local function interceptTime(d, v, s)
    local a = v:Dot(v) - s * s
    local b = 2 * d:Dot(v)
    local c = d:Dot(d)
    local disc = b * b - 4 * a * c
    if disc >= 0 and math.abs(a) > 1e-6 then
        local root = math.sqrt(disc)
        local t1 = (-b - root) / (2 * a)
        local t2 = (-b + root) / (2 * a)
        local t = math.huge
        if t1 > 0 then t = t1 end
        if t2 > 0 and t2 < t then t = t2 end
        if t < math.huge then return t end
    end
    return math.sqrt(c) / s
end

function SA.Predict(origin, targetPos, model, gun)
    gun = gun or SA.GetEquippedGun()
    local s     = math.max(gun.speed or 1000, 1)
    local v     = SA.TargetVelocity(model)
    local g     = (CFG.predictionGravity and gun.gravity) or 0
    local life  = gun.life or math.huge
    local range = gun.range or DEFAULT_RANGE
    -- Attachment sight/grip aim-time joins the ONE latency term, so it is
    -- still applied exactly once (never once per solver iteration).
    local aimMs = (CFG.attachmentAimTune ~= false and gun.attAimMs) or 0
    local latency = (SA.LeadLatencyMs() + aimMs) / 1000
    local speedMult = gun.attSpeedMult or 1
    local iters = math.clamp(CFG.predictionIterations or 4, 1, 8)
    -- AUTO TUNE: a changed projectile speed (silencer) or bullet drop
    -- needs one more refinement pass; a converged solution exits early.
    if g ~= 0 or (speedMult ~= 1 and speedMult ~= 0) then
        iters = math.min(8, iters + 1)
    end
    local d = targetPos - origin

    -- tf = bullet flight time; tTotal = tf + ping + aim-time compensation.
    -- Keeping them separate means latency is added exactly once, not
    -- once per solver iteration.
    local tf = math.min(interceptTime(d, v, s), life)
    local tTotal = tf + latency
    local aim = targetPos + v * tTotal
    for _ = 1, iters do
        local drop = 0.5 * g * tf * tf
        local nextAim = targetPos + v * tTotal + Vector3.new(0, drop, 0)
        local delta = (nextAim - aim).Magnitude
        aim = nextAim
        tf = math.min((aim - origin).Magnitude / s, life)
        tTotal = tf + latency
        if delta < 1e-4 then break end
    end
    local drop = 0.5 * g * tf * tf
    aim = targetPos + v * tTotal + Vector3.new(0, drop, 0)

    local dist = (aim - origin).Magnitude
    local attList = gun.attachments or {}
    local attIds = {}
    for _, e in ipairs(attList) do attIds[#attIds + 1] = e.id end
    return aim, {
        t = tf, total = tTotal, speed = s, velocity = v, drop = drop,
        latency = latency, lead = (aim - targetPos).Magnitude,
        range = range, inRange = dist <= range,
        expired = tf >= life and life ~= math.huge,
        id = gun.id, ammo = gun.ammo, gravity = g,
        iterations = iters, aimMs = aimMs,
        attachments = #attList, attIds = table.concat(attIds, ","),
        speedMult = speedMult, ads = gun.ads == true,
        effSpread = gun.effSpread or 0, zoom = gun.zoom or 1,
    }
end

-- ── BETTER: live gun tuning ─────────────────────────────────────────
-- Snapshot the SHIPPED DB once. "Gun Diff" compares live GC values and
-- manual overrides against this baseline, and reports guns the game has
-- added since the static 20-gun table was written.
local SA_GUN_FIELDS = { "speed", "gravity", "life", "range", "mag",
    "spread", "adsSpread", "moveSpread", "reload", "rate", "pellets",
    "s2Damage", "damageMult" }

if not SA.GunBaselineReady then
    SA.GunBaseline = {}
    for id, spec in pairs(SA.GUN_SPECS or GUN_SPECS) do
        local row = {}
        for _, f in ipairs(SA_GUN_FIELDS) do
            if type(spec[f]) == "number" then row[f] = spec[f] end
        end
        SA.GunBaseline[id] = row
    end
    SA.GunBaselineReady = true
end

function SA.GunDiff()
    local added, changed = {}, {}
    for id, spec in pairs(SA.GUN_SPECS or GUN_SPECS) do
        local base = SA.GunBaseline[id]
        if not base then
            added[#added + 1] = id
        else
            for _, f in ipairs(SA_GUN_FIELDS) do
                if base[f] and type(spec[f]) == "number"
                    and math.abs(spec[f] - base[f]) > 0.0001 then
                    changed[#changed + 1] = string.format(
                        "%s.%s %s -> %s", id, f, tostring(base[f]),
                        tostring(spec[f]))
                end
            end
        end
    end
    table.sort(added); table.sort(changed)
    return { added = added, changed = changed }
end


-- Manual editor: "assault_rifle.speed=1400;lr_sniper.gravity=20".
-- Only numeric ballistics fields are accepted, so a typo can never
-- corrupt another part of the gun spec table.
function SA.ApplyGunOverrides(text)
    text = tostring(text or "")
    local n, bad = 0, {}
    for entry in text:gmatch("[^;]+") do
        local id, field, raw = entry:match(
            "^%s*([%w_]+)%.([%w_]+)%s*=%s*(-?[%d%.]+)%s*$")
        local allowed = false
        for _, f in ipairs(SA_GUN_FIELDS) do
            if f == field then allowed = true; break end
        end
        local spec = id and (SA.GUN_SPECS or GUN_SPECS)[id] or nil
        if id and field and allowed and spec and tonumber(raw) then
            spec[field] = tonumber(raw)
            if field == "s2Damage" then spec.balance = tonumber(raw) end
            n = n + 1
        elseif entry:match("%S") then
            bad[#bad + 1] = entry
        end
    end
    SA.InvalidateGunCache()
    return n, bad
end


function SA.SyncGunDefs()
    if typeof(getgc) ~= "function" then return 0, "getgc unavailable" end
    local n, err = 0, nil
    pcall(function()
        for _, v in ipairs(getgc(true)) do
            if typeof(v) == "table" then
                local ranges = rawget(v, "GUN_RANGE")
                if typeof(ranges) == "table" then
                    for id, r in pairs(ranges) do
                        if GUN_SPECS[id] and tonumber(r) then
                            GUN_SPECS[id].range = tonumber(r); n = n + 1
                        end
                    end
                end
                local guns = rawget(v, "GUNS")
                if typeof(guns) == "table" then
                    -- Every numeric attribute of the pasted Guns table can
                    -- be refreshed from the live game definitions.
                    local fields = { "speed", "gravity", "life", "range", "mag",
                        "spread", "adsSpread", "moveSpread", "reload", "rate",
                        "pellets", "s2Damage", "damageMult" }
                    for id, d in pairs(guns) do
                        local spec = GUN_SPECS[id]
                        -- A gun the static DB has never seen: register a
                        -- safe stub from the live table so prediction and
                        -- aliases work immediately. No GC object is kept.
                        if not spec and typeof(d) == "table" then
                            local stub = {
                                name = tostring(rawget(d, "name") or id),
                                speed = tonumber(rawget(d, "speed")) or 1000,
                                ammo = rawget(d, "ammo"),
                                mag = tonumber(rawget(d, "mag")) or 1,
                                pellets = tonumber(rawget(d, "pellets")) or 1,
                                rate = tonumber(rawget(d, "rate")) or 0.2,
                                damageMult = tonumber(rawget(d, "damageMult")) or 1,
                                s2Damage = tonumber(rawget(d, "s2Damage")),
                                spread = tonumber(rawget(d, "spread")) or 2,
                                adsSpread = tonumber(rawget(d, "adsSpread")) or 0.5,
                                moveSpread = tonumber(rawget(d, "moveSpread")) or 1,
                                range = tonumber(rawget(d, "range")) or DEFAULT_RANGE,
                                reload = tonumber(rawget(d, "reload")) or 3,
                                gravity = tonumber(rawget(d, "gravity")) or 0,
                                life = tonumber(rawget(d, "life")),
                                recoil = {},
                            }
                            stub.balance = stub.s2Damage
                            GUN_SPECS[id] = stub
                            SA.GUN_SPECS = GUN_SPECS
                            if GUN_ALIASES and norm then
                                GUN_ALIASES[norm(id)] = id
                                GUN_ALIASES[norm(stub.name)] = id
                            end
                            spec = stub
                            n = n + 1
                        end
                        if spec and typeof(d) == "table" then
                            for _, f in ipairs(fields) do
                                local val = rawget(d, f)
                                if tonumber(val) then
                                    spec[f] = tonumber(val); n = n + 1
                                end
                            end
                            if tonumber(spec.s2Damage) then
                                spec.balance = spec.s2Damage
                            end
                        end
                    end
                end
            end
        end
    end)
    SA.InvalidateGunCache()
    if CFG.gunOverrideString and CFG.gunOverrideString ~= "" then
        pcall(SA.ApplyGunOverrides, CFG.gunOverrideString)
    end
    return n, err
end

-- Dump every gun's attributes (the "update the prediction for every gun"
-- audit). Static DB + any fields merged by Sync Gun Defs (GC).
