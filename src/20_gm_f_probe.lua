-- ==================================================================
-- Hanami / 20_gm_f_probe.lua — local VISUAL tracer A/B observer.
-- No shooting remote, RNG hook, server write or hit verification.
-- Pause/resume retains completed observations; Reset clears them.
-- ==================================================================

_G.__saGunSession = _G.__saGunSession
    or (tostring(os.time()) .. "-" .. tostring(math.floor(os.clock() * 1000)))

function GMP.now()
    local ok, value = pcall(tick)
    if ok and type(value) == "number" then return value end
    return os.clock()
end

function GMP.newShotGroup()
    return { n = 0, sum = 0, maximum = 0, scatter = 0, axis = 0,
        axisSum = 0, sumYaw = 0, sumPitch = 0, sumYaw2 = 0,
        sumPitch2 = 0 }
end

GMP.probe = {
    enabled = false, connection = nil, inputConnection = nil,
    shots = {}, pending = {}, seen = {}, names = {}, samples = {},
    modes = { off = GMP.newShotGroup(), on = GMP.newShotGroup() },
    required = 8, generation = 1, nextId = 0, trialId = "new",
    weaponKey = nil, weaponName = "(not locked)",
    lastPress = -1e5, lastHold = -1e5, trialSwitchedAt = -1e5,
    lastProcess = 0, angleSum = 0, recovered = false,
    recoveryStatus = "not restored",
}
GMP.status.shotProbeTrialId = GMP.probe.trialId
GMP.status.shotProbeRecovered = false
GMP.status.shotProbeRecoveryStatus = GMP.probe.recoveryStatus

function GMP.shotScatter(group)
    if group.n < 2 then return 0 end
    local yaw = group.sumYaw2 / group.n
        - (group.sumYaw / group.n) * (group.sumYaw / group.n)
    local pitch = group.sumPitch2 / group.n
        - (group.sumPitch / group.n) * (group.sumPitch / group.n)
    return math.sqrt(math.max(0, yaw + pitch))
end

function GMP.probeGroups()
    return GMP.probe.modes.off, GMP.probe.modes.on
end

function GMP.probeRefreshVerdict()
    local off, on = GMP.probeGroups()
    local writable = GMP.liveActiveCount and GMP.liveActiveCount("spread") or 0
    GMP.setStatus("shotProbeOnWritableMax", writable)
    GMP.setStatus("shotProbeOffCount", off.n)
    GMP.setStatus("shotProbeOnCount", on.n)
    GMP.setStatus("shotProbeOffMean", off.n > 0 and off.sum / off.n or 0)
    GMP.setStatus("shotProbeOnMean", on.n > 0 and on.sum / on.n or 0)
    GMP.setStatus("shotProbeOffScatter", off.scatter)
    GMP.setStatus("shotProbeOnScatter", on.scatter)
    GMP.setStatus("shotProbeOffMax", off.maximum)
    GMP.setStatus("shotProbeOnMax", on.maximum)
    GMP.setStatus("shotProbeAxisOff", off.axis)
    GMP.setStatus("shotProbeAxisOn", on.axis)
    if off.n >= GMP.probe.required and on.n >= GMP.probe.required then
        local delta = on.scatter - off.scatter
        GMP.setStatus("shotProbeComparison",
            string.format("VISUAL ON-OFF %+.2f deg", delta))
        GMP.setStatus("shotProbeVerdict", writable > 0
            and "Only local tracer variation measured; hits unverified"
            or "No exposed spread changed; visuals not hit proof")
    else
        GMP.setStatus("shotProbeComparison",
            string.format("Need OFF %d/%d | ON %d/%d", off.n,
                GMP.probe.required, on.n, GMP.probe.required))
        GMP.setStatus("shotProbeVerdict", writable > 0
            and "Exposed values edited; effect unverified"
            or "No actual spread change verified")
    end
end

function GMP.probePack()
    local off, on = GMP.probeGroups()
    return {
        schema = "HanamiShotProbe/1",
        session = tostring(_G.__saGunSession),
        placeId = tostring(game.PlaceId or "mock"),
        jobId = tostring(game.JobId or "mock"),
        userId = tostring(lp.UserId or "0"),
        at = os.time(),
        trialId = GMP.probe.trialId,
        weaponKey = GMP.probe.weaponKey,
        weaponName = GMP.probe.weaponName,
        off = GMP.copy(off), on = GMP.copy(on),
        angleSum = GMP.probe.angleSum,
        counters = {
            fireInputs = GMP.status.shotProbeFireInputs,
            aimSnapshots = GMP.status.shotProbeAimSnapshots,
            effects = GMP.status.shotProbeEffects,
            nearbyAdded = GMP.status.shotProbeNearbyAdded,
            tracers = GMP.status.shotProbeTracers,
            directional = GMP.status.shotProbeDirectional,
            ambiguous = GMP.status.shotProbeAmbiguous,
            unmatched = GMP.status.shotProbeUnmatched,
            wrongWeapon = GMP.status.shotProbeMismatchedWeapon,
        },
        names = GMP.copy(GMP.status.shotProbeNames),
        recent = GMP.copy(GMP.status.shotProbeRecent),
        samples = GMP.copy(GMP.status.shotProbeSamples),
    }
end

function GMP.probeSaveCheckpoint()
    local env = _G
    if type(getgenv) == "function" then
        local ok, result = pcall(getgenv)
        if ok and type(result) == "table" then env = result end
    end
    env.HanamiGunShotProbeCheckpoint = GMP.probePack()
end

function GMP.probeValidCheckpoint(c)
    if type(c) ~= "table" or c.schema ~= "HanamiShotProbe/1" then
        return false
    end
    if c.session ~= tostring(_G.__saGunSession)
        or c.placeId ~= tostring(game.PlaceId or "mock")
        or c.jobId ~= tostring(game.JobId or "mock")
        or c.userId ~= tostring(lp.UserId or "0") then return false end
    local at = tonumber(c.at) or 0
    if os.time() - at < 0 or os.time() - at > 21600 then return false end
    return type(c.off) == "table" and type(c.on) == "table"
        and type(c.off.n) == "number" and type(c.on.n) == "number"
end

function GMP.probeRestoreCheckpoint()
    local env = _G
    if type(getgenv) == "function" then
        local ok, result = pcall(getgenv)
        if ok and type(result) == "table" then env = result end
    end
    local c = env.HanamiGunShotProbeCheckpoint
    if not GMP.probeValidCheckpoint(c) then
        GMP.probe.recoveryStatus = "No same-session checkpoint"
        GMP.setStatus("shotProbeRecoveryStatus", GMP.probe.recoveryStatus)
        GMP.probeRefreshVerdict()
        return false
    end
    GMP.probe.modes.off, GMP.probe.modes.on = GMP.copy(c.off), GMP.copy(c.on)
    GMP.probe.trialId = tostring(c.trialId or "recovered")
    GMP.probe.weaponKey = c.weaponKey
    GMP.probe.weaponName = tostring(c.weaponName or "(not locked)")
    GMP.probe.angleSum = tonumber(c.angleSum) or 0
    GMP.status.shotProbeTrialId = GMP.probe.trialId
    GMP.status.shotProbeWeapon = GMP.probe.weaponName
    local counters = c.counters or {}
    for key, value in pairs(counters) do
        local field = ({ fireInputs = "shotProbeFireInputs",
            aimSnapshots = "shotProbeAimSnapshots",
            effects = "shotProbeEffects",
            nearbyAdded = "shotProbeNearbyAdded",
            tracers = "shotProbeTracers",
            directional = "shotProbeDirectional",
            ambiguous = "shotProbeAmbiguous",
            unmatched = "shotProbeUnmatched",
            wrongWeapon = "shotProbeMismatchedWeapon" })[key]
        if field and type(value) == "number" and value >= 0
            and value < 100000 then GMP.status[field] = value end
    end
    GMP.status.shotProbeNames = GMP.copy(c.names)
    GMP.status.shotProbeRecent = GMP.copy(c.recent)
    GMP.status.shotProbeSamples = GMP.copy(c.samples)
    GMP.probe.recovered = true
    GMP.probe.recoveryStatus = "Recovered same-session checkpoint"
    GMP.setStatus("shotProbeRecovered", true)
    GMP.setStatus("shotProbeRecoveryStatus", GMP.probe.recoveryStatus)
    GMP.setStatus("shotProbeStatus",
        "Recovered A/B trial; enable observer to continue")
    GMP.probeRefreshVerdict()
    return true
end

function GMP.probeReset(enabled)
    GMP.probe.shots, GMP.probe.pending = {}, {}
    GMP.probe.seen, GMP.probe.names, GMP.probe.samples = {}, {}, {}
    GMP.probe.modes.off, GMP.probe.modes.on = GMP.newShotGroup(),
        GMP.newShotGroup()
    GMP.probe.generation = GMP.probe.generation + 1
    GMP.probe.nextId = 0
    GMP.probe.angleSum = 0
    GMP.probe.weaponKey, GMP.probe.weaponName = nil, "(not locked)"
    GMP.probe.trialSwitchedAt = GMP.now() - 10
    GMP.probe.lastPress, GMP.probe.lastHold = -1e5, -1e5
    GMP.probe.lastProcess = 0
    GMP.probe.trialId = tostring(os.time()) .. "-"
        .. tostring(math.floor(os.clock() * 1000))
    GMP.probe.recovered = false
    GMP.probe.recoveryStatus = "Reset manually"
    GMP.status.shotProbeTrialId = GMP.probe.trialId
    GMP.setStatus("shotProbeRecovered", false)
    GMP.setStatus("shotProbeRecoveryStatus", GMP.probe.recoveryStatus)
    GMP.setStatus("shotProbeFireInputs", 0)
    GMP.setStatus("shotProbeAimSnapshots", 0)
    GMP.setStatus("shotProbeEffects", 0)
    GMP.setStatus("shotProbeNearbyAdded", 0)
    GMP.setStatus("shotProbeTracers", 0)
    GMP.setStatus("shotProbeDirectional", 0)
    GMP.setStatus("shotProbeAmbiguous", 0)
    GMP.setStatus("shotProbeUnmatched", 0)
    GMP.setStatus("shotProbeAngleMean", 0)
    GMP.setStatus("shotProbeAngleMax", 0)
    GMP.setStatus("shotProbeAngleLatest", nil)
    GMP.setStatus("shotProbeMethod", "none")
    GMP.setStatus("shotProbeWeapon", GMP.probe.weaponName)
    GMP.setStatus("shotProbeMismatchedWeapon", 0)
    GMP.setStatus("shotProbeNames", {})
    GMP.setStatus("shotProbeSamples", {})
    GMP.setStatus("shotProbeRecent", {})
    GMP.setStatus("shotProbeComparison", "Need motion samples")
    GMP.setStatus("shotProbeVerdict", "No bullet-spread verification")
    GMP.setStatus("shotProbeStatus", enabled and "Watching tracer FX" or "OFF")
    GMP.probeRefreshVerdict()
    GMP.probeSaveCheckpoint()
end

function GMP.probeSwitchTrial()
    GMP.probe.shots, GMP.probe.pending = {}, {}
    GMP.probe.generation = GMP.probe.generation + 1
    GMP.probe.trialSwitchedAt = GMP.now()
    GMP.probe.lastPress, GMP.probe.lastHold = -1e5, -1e5
    if GMP.on("gunShotProbe") then
        GMP.setStatus("shotProbeStatus", "Mode changed; wait before firing")
    end
    GMP.probeRefreshVerdict()
    GMP.probeSaveCheckpoint()
end

function GMP.dist(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return math.huge end
    local ok, value = pcall(function() return (a - b).Magnitude end)
    return ok and value or math.huge
end

function GMP.probeCaptureAim()
    local camera = Workspace.CurrentCamera
    if not camera or GMP.now() - GMP.probe.trialSwitchedAt < 0.35 then
        GMP.setStatus("shotProbeStatus", "Trial change settling; fire again")
        return false
    end
    local w = GMP.getWeapon()
    local key = GMP.norm(tostring(w.ItemId or w.Name or ""))
    if key == "" or key == "none" then
        GMP.setStatus("shotProbeStatus", "Equip a gun before recording")
        return false
    end
    if GMP.probe.weaponKey and GMP.probe.weaponKey ~= key then
        GMP.setStatus("shotProbeMismatchedWeapon",
            (GMP.status.shotProbeMismatchedWeapon or 0) + 1)
        GMP.setStatus("shotProbeStatus", "Weapon changed: reset comparison")
        return false
    end
    if not GMP.probe.weaponKey then
        GMP.probe.weaponKey = key
        GMP.probe.weaponName = tostring(w.Name or key)
        GMP.setStatus("shotProbeWeapon", GMP.probe.weaponName)
    end
    GMP.probe.nextId = GMP.probe.nextId + 1
    local cf = camera.CFrame
    local shot = { id = GMP.probe.nextId, at = GMP.now(),
        origin = cf.Position, aim = cf.LookVector, right = cf.RightVector,
        up = cf.UpVector, generation = GMP.probe.generation,
        mode = CFG.gunNoSpread == true and "on" or "off", used = false }
    GMP.probe.shots[#GMP.probe.shots + 1] = shot
    if #GMP.probe.shots > 32 then table.remove(GMP.probe.shots, 1) end
    GMP.probe.lastPress, GMP.probe.lastHold = GMP.now(), GMP.now()
    GMP.setStatus("shotProbeAimSnapshots",
        (GMP.status.shotProbeAimSnapshots or 0) + 1)
    if GMP.status.shotProbeDirectional == 0 then
        GMP.setStatus("shotProbeStatus", "Aim captured; awaiting tracer")
    end
    GMP.probeSaveCheckpoint()
    return true
end

function GMP.noteShotProbeInput()
    if not GMP.on("gunShotProbe") then return false end
    if type(window) == "table" and window.opened then return false end
    GMP.setStatus("shotProbeFireInputs",
        (GMP.status.shotProbeFireInputs or 0) + 1)
    return GMP.probeCaptureAim()
end

function GMP.probePollHeldFire()
    if not GMP.on("gunShotProbe") then return false end
    if type(window) == "table" and window.opened then return false end
    local ok, pressed = pcall(function()
        return UserInputService:IsMouseButtonPressed(
            Enum.UserInputType.MouseButton1)
    end)
    if ok and pressed and GMP.now() - GMP.probe.lastHold >= 0.11 then
        return GMP.noteShotProbeInput()
    end
    return false
end

function GMP.probeMatchFire(now)
    for i = #GMP.probe.shots, 1, -1 do
        local shot = GMP.probe.shots[i]
        local delta = now - shot.at
        if delta >= 0 and delta <= 0.45 and not shot.used
            and shot.generation == GMP.probe.generation then
            return shot
        end
        if delta > 0.45 then break end
    end
    return nil
end

function GMP.probeRecordDirection(direction, sample, method, unoriented)
    local shot = sample.shot
    if not shot or shot.used or GMP.status.shotProbeDirectional >= 100
        or type(direction) ~= "table" or direction.Magnitude <= 0.0001
        or shot.aim.Magnitude <= 0.0001 then return false end
    local du, au = direction.Unit, shot.aim.Unit
    local dot = math.clamp(du:Dot(au), -1, 1)
    if unoriented then dot = math.abs(dot) end
    if dot < 0.25 then return false end
    local angle = math.deg(math.acos(dot))
    if angle ~= angle or angle > 76 then return false end
    local oriented = du:Dot(au) < 0 and -du or du
    local forward = oriented:Dot(au)
    local yaw = math.deg(SA.Atan2(oriented:Dot(shot.right), forward))
    local pitch = math.deg(SA.Atan2(oriented:Dot(shot.up), forward))
    if not GMP.finite(yaw) or not GMP.finite(pitch) then return false end
    shot.used = true
    GMP.setStatus("shotProbeDirectional",
        (GMP.status.shotProbeDirectional or 0) + 1)
    GMP.probe.angleSum = GMP.probe.angleSum + angle
    GMP.setStatus("shotProbeAngleMean", GMP.probe.angleSum
        / GMP.status.shotProbeDirectional)
    GMP.setStatus("shotProbeAngleMax",
        math.max(GMP.status.shotProbeAngleMax or 0, angle))
    GMP.setStatus("shotProbeAngleLatest", angle)
    GMP.setStatus("shotProbeMethod", method)
    local group = GMP.probe.modes[shot.mode]
    if method == "motion" then
        group.n = group.n + 1
        group.sum = group.sum + angle
        group.maximum = math.max(group.maximum, angle)
        group.sumYaw = group.sumYaw + yaw
        group.sumPitch = group.sumPitch + pitch
        group.sumYaw2 = group.sumYaw2 + yaw * yaw
        group.sumPitch2 = group.sumPitch2 + pitch * pitch
        group.scatter = GMP.shotScatter(group)
    else
        group.axis = group.axis + 1
        group.axisSum = group.axisSum + angle
    end
    local entry = string.format("%s %.1f deg %s", shot.mode, angle, method)
    table.insert(GMP.status.shotProbeRecent, 1, entry)
    while #GMP.status.shotProbeRecent > 8 do
        table.remove(GMP.status.shotProbeRecent)
    end
    GMP.setStatus("shotProbeStatus", "Matched local visual tracer")
    GMP.probeRefreshVerdict()
    GMP.probeSaveCheckpoint()
    return true
end

function GMP.probeTryDirection(sample)
    local obj, shot = sample.object, sample.shot
    if not obj or not obj.Parent or not shot or shot.used then return false end
    if obj:IsA("Beam") and obj.Attachment0 and obj.Attachment1 then
        local p0, p1 = obj.Attachment0.WorldPosition,
            obj.Attachment1.WorldPosition
        if type(p0) == "table" and type(p1) == "table" then
            local displacement = p1 - p0
            if displacement.Magnitude > 0.25
                and math.min(GMP.dist(p0, shot.origin),
                    GMP.dist(p1, shot.origin)) <= 16 then
                return GMP.probeRecordDirection(displacement, sample,
                    "beam axis", true)
            end
        end
        return false
    end
    if not obj:IsA("BasePart") then return false end
    local delta = obj.Position - sample.startPos
    if delta.Magnitude >= 0.35
        and GMP.dist(sample.startPos, shot.origin) <= 16 then
        return GMP.probeRecordDirection(delta, sample, "motion", false)
    end
    local size = obj.Size
    if type(size) ~= "table" or GMP.now() - sample.at < 0.12 then
        return false
    end
    local axis, length, other = 1, size.X, math.max(size.Y, size.Z)
    if size.Y > length then
        axis, length, other = 2, size.Y, math.max(size.X, size.Z)
    end
    if size.Z > length then
        axis, length, other = 3, size.Z, math.max(size.X, size.Y)
    end
    if length < 0.65 or length < other * 2.3 then return false end
    local cf = obj.CFrame
    local direction = axis == 1 and cf.RightVector
        or (axis == 2 and cf.UpVector or cf.LookVector)
    local along = math.clamp((shot.origin - obj.Position):Dot(direction),
        -length * 0.5, length * 0.5)
    local nearest = obj.Position + direction * along
    if GMP.dist(nearest, shot.origin) > 16 then return false end
    return GMP.probeRecordDirection(direction, sample, "part axis", true)
end

function GMP.probeProcessPending()
    if not GMP.on("gunShotProbe") or #GMP.probe.pending == 0 then return 0 end
    local now = GMP.now()
    if now - GMP.probe.lastProcess < 0.016 then return 0 end
    GMP.probe.lastProcess = now
    local i, processed = 1, 0
    while i <= #GMP.probe.pending and processed < 24 do
        local sample = GMP.probe.pending[i]
        local age = now - sample.at
        processed = processed + 1
        if sample.shot.used then
            GMP.setStatus("shotProbeUnmatched",
                (GMP.status.shotProbeUnmatched or 0) + 1)
            table.remove(GMP.probe.pending, i)
        else
            local ok, found = pcall(GMP.probeTryDirection, sample)
            if ok and found then
                table.remove(GMP.probe.pending, i)
            elseif age >= 0.18 or not ok then
                GMP.setStatus("shotProbeAmbiguous",
                    (GMP.status.shotProbeAmbiguous or 0) + 1)
                table.remove(GMP.probe.pending, i)
            else
                i = i + 1
            end
        end
    end
    return processed
end

function GMP.probeNear(obj, origin)
    if type(obj.Position) == "table" then
        return GMP.dist(obj.Position, origin) <= 55
    end
    if type(obj.WorldPosition) == "table" then
        return GMP.dist(obj.WorldPosition, origin) <= 55
    end
    return false
end

function GMP.probeInspect(obj)
    if not GMP.on("gunShotProbe") or GMP.now() - GMP.probe.lastPress > 0.30 then
        return
    end
    if not (obj:IsA("BasePart") or obj:IsA("Beam") or obj:IsA("Trail")
        or obj:IsA("Attachment") or obj:IsA("Decal")
        or obj:IsA("ParticleEmitter") or obj:IsA("Sound")) then return end
    local shot = GMP.probeMatchFire(GMP.now())
    if not shot or not GMP.probeNear(obj, shot.origin) then return end
    GMP.setStatus("shotProbeNearbyAdded",
        (GMP.status.shotProbeNearbyAdded or 0) + 1)
    local identity = tostring(obj.ClassName) .. ":" .. tostring(obj.Name)
    if not GMP.probe.samples[identity] then
        GMP.probe.samples[identity] = true
        if #GMP.status.shotProbeSamples < 5 then
            table.insert(GMP.status.shotProbeSamples, identity)
        end
    end
    local name = tostring(obj.Name):lower()
    local mayBeShot = name:find("bullet", 1, true)
        or name:find("projectile", 1, true) or name:find("tracer", 1, true)
        or name:find("pellet", 1, true) or name:find("shot", 1, true)
        or name:find("impact", 1, true) or name:find("muzzle", 1, true)
        or name:find("gunfire", 1, true) or name:find("casing", 1, true)
        or name:find("shell", 1, true) or name:find("spark", 1, true)
        or name:find("flash", 1, true)
    if mayBeShot then
        GMP.setStatus("shotProbeEffects",
            (GMP.status.shotProbeEffects or 0) + 1)
        if not GMP.probe.names[identity] then
            GMP.probe.names[identity] = true
            if #GMP.status.shotProbeNames < 5 then
                table.insert(GMP.status.shotProbeNames, identity)
            end
        end
    end
    local mayBeTracer = name:find("tracer", 1, true)
        or name:find("bullet", 1, true) or name:find("projectile", 1, true)
    if mayBeTracer and (obj:IsA("BasePart") or obj:IsA("Beam"))
        and not GMP.probe.seen[obj]
        and #GMP.probe.pending < 64 then
        GMP.probe.seen[obj] = true
        GMP.setStatus("shotProbeTracers",
            (GMP.status.shotProbeTracers or 0) + 1)
        local pos = obj:IsA("BasePart") and obj.Position or Vector3.new(0, 0, 0)
        GMP.probe.pending[#GMP.probe.pending + 1] = {
            object = obj, at = GMP.now(), startPos = pos, shot = shot }
    end
end

function GMP.probeSet(enabled)
    if GMP.probe.connection then
        pcall(function() GMP.probe.connection:Disconnect() end)
        GMP.probe.connection = nil
    end
    if GMP.probe.inputConnection then
        pcall(function() GMP.probe.inputConnection:Disconnect() end)
        GMP.probe.inputConnection = nil
    end
    GMP.probe.enabled = enabled == true
    GMP.probeSwitchTrial()
    if GMP.probe.enabled and GMP.master() then
        pcall(function()
            GMP.probe.connection = Workspace.DescendantAdded:Connect(
                GMP.probeInspect)
        end)
        pcall(function()
            GMP.probe.inputConnection = UserInputService.InputBegan:Connect(
                function(input)
                    local kind = input and (input.UserInputType or input.KeyCode)
                    if kind and tostring(kind):find("MouseButton1", 1, true) then
                        GMP.noteShotProbeInput()
                    end
                end)
        end)
        GMP.setStatus("shotProbeStatus", "Observing (A/B measurements retained)")
    else
        GMP.setStatus("shotProbeStatus", "Paused (A/B measurements retained)")
    end
    GMP.probeSaveCheckpoint()
end

function GMP.shotProbeSnapshot()
    local off, on = GMP.probeGroups()
    return { enabled = GMP.on("gunShotProbe"),
        observerPaused = not GMP.on("gunShotProbe"),
        status = GMP.status.shotProbeStatus,
        trialId = GMP.probe.trialId,
        trialRecovered = GMP.probe.recovered,
        recovery = GMP.probe.recoveryStatus,
        mode = CFG.gunNoSpread == true and "ON" or "OFF",
        fireInputs = GMP.status.shotProbeFireInputs,
        aimSnapshots = GMP.status.shotProbeAimSnapshots,
        effects = GMP.status.shotProbeEffects,
        nearbyAdded = GMP.status.shotProbeNearbyAdded,
        tracerCandidates = GMP.status.shotProbeTracers,
        directionSamples = GMP.status.shotProbeDirectional,
        ambiguous = GMP.status.shotProbeAmbiguous,
        unmatched = GMP.status.shotProbeUnmatched,
        meanAngle = GMP.status.shotProbeAngleMean,
        maxAngle = GMP.status.shotProbeAngleMax,
        offCount = off.n, onCount = on.n,
        offMean = GMP.status.shotProbeOffMean,
        onMean = GMP.status.shotProbeOnMean,
        offScatter = off.scatter, onScatter = on.scatter,
        comparison = GMP.status.shotProbeComparison,
        verdict = GMP.status.shotProbeVerdict,
        weapon = GMP.status.shotProbeWeapon,
        wrongWeapon = GMP.status.shotProbeMismatchedWeapon,
        onWritableMax = GMP.status.shotProbeOnWritableMax,
        method = GMP.status.shotProbeMethod,
        names = GMP.copy(GMP.status.shotProbeNames),
        recent = GMP.copy(GMP.status.shotProbeRecent),
        samples = GMP.copy(GMP.status.shotProbeSamples) }
end

function GMP.shotProbeReport()
    local off, on = GMP.probeGroups()
    local lines = {
        "Hanami local tracer A/B diagnostic",
        "Trial ID: " .. GMP.probe.trialId,
        "Same-session recovery: " .. (GMP.probe.recovered and "YES" or "NO"),
        "Observer: " .. (GMP.on("gunShotProbe") and "ON" or "PAUSED"),
        "Weapon: " .. tostring(GMP.status.shotProbeWeapon),
        "Current mode: " .. (CFG.gunNoSpread == true and "ON" or "OFF"),
        string.format("OFF n=%d, mean=%.3f deg, scatter=%.3f deg",
            off.n, GMP.status.shotProbeOffMean, off.scatter),
        string.format("ON n=%d, mean=%.3f deg, scatter=%.3f deg",
            on.n, GMP.status.shotProbeOnMean, on.scatter),
        "Comparison: " .. tostring(GMP.status.shotProbeComparison),
        "Result: " .. tostring(GMP.status.shotProbeVerdict),
        "Observer toggles retain data in the same game session; Reset clears it.",
        "VISUAL effects only; zero spread on actual bullets NOT verified.",
    }
    for i, name in ipairs(GMP.status.shotProbeNames) do
        lines[#lines + 1] = "Effect " .. i .. ": " .. name
    end
    return table.concat(lines, "\n")
end

GMP.probeRestoreCheckpoint()
