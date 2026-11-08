-- ==================================================================
-- Hanami / 08_prediction.lua — Ballistic intercept solver + gun debug
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

function SA.PrintPrediction(origin, targetPos, model)
    local aim, i = SA.Predict(origin, targetPos, model)
    print(string.format(
        "[pred] %s | ammo %s | speed %.0f | t %.3fs | lead %.1f | drop %.2f | range %d %s",
        i.id, tostring(i.ammo), i.speed, i.t, i.lead, i.drop, i.range,
        i.inRange and "OK" or "OUT OF RANGE"))
    print(string.format("[pred] ping %.0f ms | auto %s | scale %.1f | offset %.0f ms | aimtime %.0f ms | total %.0f ms",
        SA.GetPing(), CFG.predictionAutoPing and "ON" or "OFF",
        CFG.predictionPingScale or 1, CFG.predictionLatency or 0,
        i.aimMs, i.latency * 1000))
    print(string.format("[pred] attachments %d [%s] | speed x%.3f | iters %d | ADS %s | effSpread %.2f | zoom %.1fx",
        i.attachments, i.attIds, i.speedMult, i.iterations,
        tostring(i.ads), i.effSpread, i.zoom))
    return aim, i
end

-- ────────────────────────────────────────────────────────────────────
-- GUN DEBUG HELPERS
-- ────────────────────────────────────────────────────────────────────

function SA.PrintGunSpec()
    local g = SA.GetEquippedGun(true)
    local s = g.spec
    local baseAmmo = g.alt and AMMO_ALTS[g.ammo] and AMMO_ALTS[g.ammo].base or g.ammo
    local baseDmg  = AMMO_DAMAGE[baseAmmo] or 0
    print("════════════ GUN SPEC ════════════")
    print(string.format("  id       : %s  (%s)%s", g.id, s.name, g.known and "" or "  [UNKNOWN -> fallback]"))
    print(string.format("  ammo     : %s%s", tostring(g.ammo), g.alt and "  [alt ammo]" or ""))
    print(string.format("  speed    : %.0f studs/s%s", g.speed,
        g.manualSpeed and "  [manual override]" or ""))
    print(string.format("  drop     : gravity %.1f  life %s", g.gravity or 0,
        g.life and tostring(g.life) .. "s" or "none"))
    print(string.format("  range    : %d studs   pellets %d   rate %.3fs   mag %d   reload %.2fs",
        g.range, g.pellets, g.rate, g.mag or 0, g.reload or 0))
    print(string.format("  spread   : hip %.2f  ads %.2f  move %.2f  | eff %.2f  ADS %s",
        g.spread or 0, g.adsSpread or 0, g.moveSpread or 0,
        g.effSpread or 0, tostring(g.ads)))
    print(string.format("  recoil   : pitch %.2f  yaw %.2f  recover %.2f  rise %s  sway %s",
        g.recoil.pitch or 0, g.recoil.yaw or 0, g.recoil.recover or 0,
        tostring(g.recoil.rise), tostring(g.recoil.sway)))
    print(string.format("  damage   : %.2f / pellet   (Defs[%s].damage %s x damageMult %s)",
        g.damage, tostring(g.ammo), tostring(baseDmg), tostring(s.damageMult)))
    print(string.format("  burst    : %.1f total per shot   ~%.1f DPS", g.damage * g.pellets,
        g.rate > 0 and (g.damage * g.pellets) / g.rate or 0))
    print(string.format("  tags     : scope %s | zoom %.1fx | s2Damage %s | rocket %s | huntOnly %s | duelOnly %s",
        tostring(s.scope), g.zoom or 1, tostring(s.s2Damage),
        tostring(g.rocket), tostring(g.huntOnly), tostring(g.duelOnly)))
    if s.headGuard then
        print(string.format("  headguard: %s keeps %s damage", tostring(s.headGuard.item), tostring(s.headGuard.keep)))
    end
    if s.shellReload then
        print(string.format("  shellrl  : lead %.2f  per %.2f  tail %.2f",
            s.shellReload.lead, s.shellReload.per, s.shellReload.tail))
    end
    print(string.format("  NOTE     : GUN_BALANCE.damage = %s (legacy, NOT the real damage)",
        tostring(s.balance)))
    if s.falloff then
        print(string.format("  falloff  : full %s  min %s  mult %s", tostring(s.falloff.full),
            tostring(s.falloff.min), tostring(s.falloff.mult)))
    end
    local ids = {}
    for _, e in ipairs(g.attachments or {}) do ids[#ids + 1] = e.id end
    print(string.format("  attach   : %d [%s] | base speed %.0f -> %.0f | +%.0f ms aim",
        #ids, table.concat(ids, ","), g.baseSpeed or 0, g.speed,
        g.attAimMs or 0))
    print("═══════════════════════════════════")
end

-- Optional: pull live speed/gravity/range straight out of the game's
-- GC tables (u3492.GUN_RANGE / u3338.GUNS) instead of trusting the
-- static numbers. Off by default; call from the Debug button.
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
    print(string.format("[sa] synced %d live gun fields from GC", n))
    return n, err
end

-- Dump every gun's attributes (the "update the prediction for every gun"
-- audit). Static DB + any fields merged by Sync Gun Defs (GC).
function SA.PrintGunTable()
    local ids = {}
    for id in pairs(SA.GUN_SPECS) do ids[#ids + 1] = id end
    table.sort(ids)
    print("════════════ GUN TABLE ════════════")
    print(string.format("  %-22s %6s %-16s %5s %4s %6s %6s %6s %5s %5s %5s",
        "id", "speed", "ammo", "mag", "pel", "rate", "range", "s2", "hip", "ads", "move"))
    for _, id in ipairs(ids) do
        local s = SA.GUN_SPECS[id]
        print(string.format("  %-22s %6.0f %-16s %5d %4d %6.3f %6d %6s %5.2f %5.2f %5.2f",
            id, s.speed, tostring(s.ammo), s.mag or 0, s.pellets or 1,
            s.rate or 0, s.range or 0, tostring(s.s2Damage),
            s.spread or 0, s.adsSpread or 0, s.moveSpread or 0))
    end
    print(string.format("  %d guns | gravity/life: %s",
        #ids, "SMGs 8/1, bolt 30/1.9, lr 24/1.8"))
    print("═══════════════════════════════════")
    return #ids
end
