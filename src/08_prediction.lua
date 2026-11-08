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
    local latency = SA.LeadLatencyMs() / 1000
    local iters = math.clamp(CFG.predictionIterations or 4, 1, 8)
    local d = targetPos - origin

    -- tf = bullet flight time; tTotal = tf + ping compensation.
    -- Keeping them separate means latency is added exactly once, not
    -- once per solver iteration.
    local tf = math.min(interceptTime(d, v, s), life)
    local tTotal = tf + latency
    local aim = targetPos + v * tTotal
    for _ = 1, iters do
        local drop = 0.5 * g * tf * tf
        aim = targetPos + v * tTotal + Vector3.new(0, drop, 0)
        tf = math.min((aim - origin).Magnitude / s, life)
        tTotal = tf + latency
    end
    local drop = 0.5 * g * tf * tf
    aim = targetPos + v * tTotal + Vector3.new(0, drop, 0)

    local dist = (aim - origin).Magnitude
    return aim, {
        t = tf, total = tTotal, speed = s, velocity = v, drop = drop,
        latency = latency, lead = (aim - targetPos).Magnitude,
        range = range, inRange = dist <= range,
        expired = tf >= life and life ~= math.huge,
        id = gun.id, ammo = gun.ammo, gravity = g,
    }
end

function SA.PrintPrediction(origin, targetPos, model)
    local aim, i = SA.Predict(origin, targetPos, model)
    print(string.format(
        "[pred] %s | ammo %s | speed %.0f | t %.3fs | lead %.1f | drop %.2f | range %d %s",
        i.id, tostring(i.ammo), i.speed, i.t, i.lead, i.drop, i.range,
        i.inRange and "OK" or "OUT OF RANGE"))
    print(string.format("[pred] ping %.0f ms | auto %s | scale %.1f | offset %.0f ms | total %.0f ms",
        SA.GetPing(), CFG.predictionAutoPing and "ON" or "OFF",
        CFG.predictionPingScale or 1, CFG.predictionLatency or 0,
        i.latency * 1000))
    return aim, i
end

-- ────────────────────────────────────────────────────────────────────
-- GUN DEBUG HELPERS
-- ────────────────────────────────────────────────────────────────────

function SA.PrintGunSpec()
    local g = SA.GetEquippedGun(true)
    local s = g.spec
    print("════════════ GUN SPEC ════════════")
    print(string.format("  id       : %s  (%s)%s", g.id, s.name, g.known and "" or "  [UNKNOWN -> fallback]"))
    print(string.format("  ammo     : %s%s", tostring(g.ammo), g.alt and "  [alt ammo]" or ""))
    print(string.format("  speed    : %.0f studs/s%s", g.speed,
        CFG.gunBulletSpeed > 0 and "  [manual override]" or ""))
    print(string.format("  drop     : gravity %.1f  life %s", g.gravity,
        g.life and tostring(g.life) .. "s" or "none"))
    print(string.format("  range    : %d studs   pellets %d   rate %.3fs", g.range, g.pellets, g.rate))
    print(string.format("  damage   : %.2f / pellet   (Defs[%s].damage %s x damageMult %.2f)",
        g.damage, tostring(g.ammo), tostring(AMMO_DAMAGE[(g.alt and AMMO_ALTS[g.ammo].base or g.ammo)] or 0), s.damageMult or 0))
    print(string.format("  burst    : %.1f total per shot   ~%.1f DPS", g.damage * g.pellets,
        g.rate > 0 and (g.damage * g.pellets) / g.rate or 0))
    print(string.format("  NOTE     : GUN_BALANCE.damage = %s (legacy, NOT the real damage)",
        tostring(s.balance)))
    if s.falloff then
        print(string.format("  falloff  : full %s  min %s  mult %s", tostring(s.falloff.full),
            tostring(s.falloff.min), tostring(s.falloff.mult)))
    end
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
                    for id, d in pairs(guns) do
                        local spec = GUN_SPECS[id]
                        if spec and typeof(d) == "table" then
                            local sp = rawget(d, "speed")
                            if tonumber(sp) then spec.speed = tonumber(sp); n = n + 1 end
                            local gr = rawget(d, "gravity")
                            if tonumber(gr) then spec.gravity = tonumber(gr) end
                            local lf = rawget(d, "life")
                            if tonumber(lf) then spec.life = tonumber(lf) end
                        end
                    end
                end
            end
        end
    end)
    gunCache.val = nil
    print(string.format("[sa] synced %d live gun fields from GC", n))
    return n, err
end
