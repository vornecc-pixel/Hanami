-- ==================================================================
-- Hanami / 20_gm_b_records.lua — named-field discovery and reversible holds.
-- Strong-keyed originals make every ON/OFF change and unload restore work
-- without rescanning. Only explicitly named client-side fields are written.
-- ==================================================================

GMP.records = { spread = {}, recoil = {}, rate = {}, ammo = {}, movement = {} }
GMP.seen = {}
GMP.observed = {}
GMP.restored = { spread = true, recoil = true, rate = true, ammo = true,
                 movement = true }
GMP.disabledSources = {}
GMP.modes = { "spread", "recoil", "rate", "ammo", "movement" }
GMP.observationBaseline = nil

GMP.GENERIC_MODEL_NAMES = {
    model = true, weapon = true, item = true, tool = true, viewmodel = true,
    character = true, handle = true, firearm = true,
}

function GMP.modeOn(mode)
    if mode == "spread" then return GMP.on("gunNoSpread") end
    if mode == "recoil" then return GMP.on("gunNoRecoil") end
    if mode == "rate" then return GMP.on("gunFireRate") end
    if mode == "ammo" then return GMP.on("gunInfiniteAmmo") end
    if mode == "movement" then return GMP.on("gunMoveShoot") end
    return false
end

function GMP.recoilKey(key)
    local k = GMP.norm(key)
    if not (k:find("recoil", 1, true) or k:find("kick", 1, true)
        or k:find("aimpunch", 1, true) or k:find("viewpunch", 1, true)
        or k:find("sway", 1, true)) then return false end
    for _, denied in ipairs({ "recovery", "recover", "return", "decay",
        "cooldown", "reset", "damp", "spring", "duration", "interval", "time",
        "speed", "rate", "friction", "spread" }) do
        if k:find(denied, 1, true) then return false end
    end
    return true
end

function GMP.isFiringProfile(tab)
    if type(tab) ~= "table" then return false end
    local rate, mag = rawget(tab, "rate"), rawget(tab, "mag")
    local reload, spread = rawget(tab, "reload"), rawget(tab, "spread")
    local auto = rawget(tab, "auto")
    return GMP.finite(rate) and rate > 0 and rate < 5
        and type(mag) == "number" and mag >= 1 and mag <= 500
        and GMP.finite(reload) and reload > 0 and reload <= 45
        and GMP.finite(spread) and spread >= 0 and type(auto) == "boolean"
end

function GMP.rateKind(key, tab)
    local k = GMP.norm(key)
    if k:find("reload", 1, true) or k:find("animation", 1, true)
        or k:find("sound", 1, true) or k:find("visual", 1, true)
        or k:find("burst", 1, true) or k:find("sprint", 1, true) then
        return nil
    end
    if (k == "rate" or k == "cooldown") and GMP.isFiringProfile(tab) then
        return "lower"
    end
    local higher = { rpm = true, roundsperminute = true, firerate = true,
        rateoffire = true, shotspersecond = true, bulletspersecond = true,
        firefrequency = true, shotfrequency = true, rps = true, sps = true,
        bulletfrequency = true, firingspeed = true, shotsperminute = true,
        weaponrpm = true, shootrate = true }
    local lower = { firedelay = true, shotdelay = true, fireinterval = true,
        shotinterval = true, timebetweenshots = true,
        timebetweenbullets = true, shotcooldown = true, firecooldown = true,
        weaponcycletime = true, cycletime = true, timebetweenfires = true,
        shootdelay = true, shootinterval = true, shoottime = true,
        shotperiod = true, fireperiod = true, firewait = true,
        shotwait = true, bulletsdelay = true, cooldownbetweenshots = true }
    if higher[k] then return "higher" end
    if lower[k] then return "lower" end
    return nil
end

function GMP.ammoKey(key)
    local k = GMP.norm(key)
    if k:find("max", 1, true) or k:find("capacity", 1, true)
        or k:find("cost", 1, true) or k:find("reload", 1, true)
        or k:find("type", 1, true) or k:find("multiplier", 1, true) then
        return false
    end
    local names = { ammo = true, currentammo = true, currentbullets = true,
        clipammo = true, ammoinclip = true, magammo = true,
        magazineammo = true, ammoinmag = true, ammoinmagazine = true,
        remainingammo = true, bulletsleft = true, reserveammo = true,
        ammoreserve = true, storedammo = true, loadedammo = true,
        roundsinmag = true, roundsinmagazine = true, currentmag = true,
        magrounds = true, magazinecount = true, clipcount = true,
        bulletcount = true, roundcount = true, chamberammo = true,
        chamberedrounds = true, ammoamount = true, ammocount = true,
        magsizecurrent = true, carriedammo = true, ammleft = true }
    return names[k] == true
end

GMP.motionKeys = {}
do
    local activities = { "shoot", "fire", "aim", "ads" }
    local movements = { "sprint", "sprinting", "run", "running", "jump",
        "jumping", "move", "moving", "air", "airborne" }
    for _, act in ipairs(activities) do
        for _, mv in ipairs(movements) do
            GMP.motionKeys["can" .. act .. "while" .. mv] = true
            GMP.motionKeys["allow" .. act .. "while" .. mv] = true
            GMP.motionKeys[act .. "while" .. mv] = true
            GMP.motionKeys["can" .. act .. "during" .. mv] = true
            GMP.motionKeys["allow" .. act .. "during" .. mv] = true
            GMP.motionKeys["block" .. act .. "while" .. mv] = false
            GMP.motionKeys["disable" .. act .. "while" .. mv] = false
            GMP.motionKeys["prevent" .. act .. "while" .. mv] = false
            GMP.motionKeys[mv .. act .. "blocked"] = false
        end
    end
    local extra = { sprintshoot = true, sprintfire = true, sprintaim = true,
        sprintads = true, jumpfire = true, jumpshoot = true, jumpaim = true,
        jumpads = true, allowfireinair = true, allowshootinair = true,
        allowaiminair = true, allowadsinair = true, canfireinair = true,
        canshootinair = true, canaiminair = true, canadsinair = true,
        prohibitfiresprinting = false, prohibitshootsprinting = false,
        firesprintblocked = false, shootsprintblocked = false,
        firejumpblocked = false, shootjumpblocked = false,
        disableshootingwhilesprinting = false,
        disableshootingwhilejumping = false, blocksprintfire = false,
        blockjumpfire = false, fireonmove = true, shootonmove = true,
        fireinair = true, aiminair = true }
    for k, v in pairs(extra) do GMP.motionKeys[k] = v end
end

function GMP.classify(key, value, tab)
    if type(key) ~= "string" then return nil, nil end
    if type(value) == "number" and GMP.finite(value) then
        if GMP.isNumericSpreadName(key) then return "spread", 0 end
        if GMP.recoilKey(key) and value ~= 0 then return "recoil", 0 end
        local kind = GMP.rateKind(key, tab)
        if kind and value > 0 then return "rate", value end
        if GMP.ammoKey(key) then
            return "ammo", math.max(value, 9999)
        end
    elseif type(value) == "boolean" then
        local setting = GMP.motionKeys[GMP.norm(key)]
        if setting ~= nil then return "movement", setting end
    end
    return nil, nil
end

function GMP.multiplier()
    return math.clamp(tonumber(CFG.gunFireRateMultiplier) or 1.5, 1, 3)
end

function GMP.desiredFor(rec)
    if rec.mode == "rate" then
        local old = tonumber(rec.old) or 0
        if old <= 0 then return old end
        if rec.rateKind == "higher" then
            return old * GMP.multiplier()
        end
        return math.max(0.001, old / GMP.multiplier())
    end
    return rec.desired
end

function GMP.readEntry(rec)
    if rec.kind == "attribute" then
        local ok, value = pcall(function()
            return rec.ref:GetAttribute(rec.key) end)
        return ok and value or nil
    elseif rec.kind == "value" then
        local ok, value = pcall(function() return rec.ref.Value end)
        return ok and value or nil
    end
    local ok, value = pcall(rawget, rec.ref, rec.key)
    return ok and value or nil
end

function GMP.writeEntry(rec, value)
    if rec.kind == "attribute" then
        return pcall(function()
            rec.ref:SetAttribute(rec.key, value) end)
    elseif rec.kind == "value" then
        return pcall(function() rec.ref.Value = value end)
    end
    return pcall(rawset, rec.ref, rec.key, value)
end

function GMP.observeTable(tab, path)
    if type(tab) ~= "table" then return end
    for _, entry in ipairs(GMP.observed) do
        if entry.ref == tab then return end
    end
    if #GMP.observed < 80 then
        GMP.observed[#GMP.observed + 1] = { ref = tab, path = tostring(path) }
    end
end

function GMP.addRecord(mode, source, path, ref, key, value, desired, kind)
    if type(ref) ~= "table" or not GMP.records[mode] then return false end
    local seenForRef = GMP.seen[ref]
    if not seenForRef then seenForRef = {}; GMP.seen[ref] = seenForRef end
    if seenForRef[key] then return false end
    seenForRef[key] = true
    local list = GMP.records[mode]
    if #list >= 240 then return false end
    list[#list + 1] = {
        mode = mode, source = tostring(source), path = tostring(path),
        ref = ref, key = key, old = value, desired = desired,
        rateKind = mode == "rate" and GMP.rateKind(key, ref) or nil,
        kind = kind or "table", active = false, last = nil,
    }
    if kind == "table" or kind == nil then GMP.observeTable(ref, path) end
    return true
end

function GMP.walkFields(tab, path, source, depth, seen)
    if type(tab) ~= "table" or depth > 2 or seen[tab] then return end
    seen[tab] = true
    local visited = 0
    for key, value in next, tab do
        visited = visited + 1
        if visited > 180 then break end
        local mode, desired = GMP.classify(key, value, tab)
        if mode then
            GMP.addRecord(mode, source, tostring(path) .. "." .. tostring(key),
                tab, key, value, desired, "table")
        end
        if type(value) == "table" and depth < 2 and not seen[value]
            and GMP.norm(key) ~= "tags" then
            GMP.walkFields(value, tostring(path) .. "." .. tostring(key),
                source, depth + 1, seen)
        end
    end
end

function GMP.scanTable(tab, path, source)
    GMP.walkFields(tab, path, source, 0, {})
end

function GMP.inspectTool()
    local w = GMP.getWeapon()
    local tool = w.Tool
    if not tool then
        GMP.setStatus("liveToolSettingsStatus", "No equipped gun inspected")
        return 0
    end
    local attrs = nil
    local ok = pcall(function() attrs = tool:GetAttributes() end)
    if not ok or type(attrs) ~= "table" then attrs = {} end
    local found = 0
    for key, value in pairs(attrs) do
        local mode, desired = GMP.classify(key, value, attrs)
        if mode and GMP.addRecord(mode, "equipped tool",
            "Tool." .. tostring(key), tool, key, value, desired, "attribute") then
            found = found + 1
        end
    end
    local descendants = nil
    pcall(function() descendants = tool:GetDescendants() end)
    for _, object in ipairs(descendants or {}) do
        local isValue = object:IsA("IntValue") or object:IsA("NumberValue")
            or object:IsA("BoolValue")
        if isValue then
            local value = nil
            pcall(function() value = object.Value end)
            local mode, desired = GMP.classify(object.Name, value, attrs)
            if mode and GMP.addRecord(mode, "equipped tool value",
                "Tool." .. tostring(object.Name), object, "Value", value,
                desired, "value") then found = found + 1 end
        end
    end
    GMP.setStatus("liveToolSettingsStatus",
        tostring(w.Name or "None") .. ": " .. found .. " named fields")
    return found
end

function GMP.recordCount(mode)
    return #(GMP.records[mode] or {})
end

function GMP.applyMode(mode)
    if not GMP.modeOn(mode) then return 0 end
    local changed = 0
    for _, rec in ipairs(GMP.records[mode] or {}) do
        if not GMP.disabledSources[rec.source] then
            local target = GMP.desiredFor(rec)
            local current = GMP.readEntry(rec)
            if current ~= target then
                local ok = GMP.writeEntry(rec, target)
                if ok then changed = changed + 1 end
            end
            rec.active = true
            rec.last = target
        end
    end
    GMP.restored[mode] = false
    return changed
end

function GMP.restoreSource(source)
    GMP.disabledSources[source] = true
    local restored = 0
    for _, mode in ipairs(GMP.modes) do
        for _, rec in ipairs(GMP.records[mode] or {}) do
            if rec.source == source and rec.active then
                GMP.writeEntry(rec, rec.old)
                rec.active, rec.last = false, nil
                restored = restored + 1
            end
        end
    end
    return restored
end

function GMP.enableSource(source)
    GMP.disabledSources[source] = nil
end

function GMP.restoreMode(mode)
    if GMP.restored[mode] then return 0 end
    local restored = 0
    for _, rec in ipairs(GMP.records[mode] or {}) do
        if rec.active then
            GMP.writeEntry(rec, rec.old)
            restored = restored + 1
        end
        rec.active = false
        rec.last = nil
    end
    GMP.restored[mode] = true
    return restored
end

function GMP.restoreAll()
    for _, mode in ipairs(GMP.modes) do GMP.restoreMode(mode) end
end

function GMP.reconcile()
    if not GMP.alive or SA.Unloaded then
        GMP.restoreAll()
        return
    end
    for _, mode in ipairs(GMP.modes) do
        if GMP.modeOn(mode) then GMP.applyMode(mode)
        else GMP.restoreMode(mode) end
    end
end

function GMP.observationCapture()
    local snapshot = {}
    local count = 0
    for index, entry in ipairs(GMP.observed) do
        local visited = 0
        for key, value in next, entry.ref do
            visited = visited + 1
            if visited > 100 or count >= 2000 then break end
            if (type(value) == "number" and GMP.finite(value))
                or type(value) == "boolean" then
                snapshot[tostring(index) .. ":" .. tostring(key)] = {
                    value = value, path = entry.path .. "." .. tostring(key) }
                count = count + 1
            end
        end
    end
    return snapshot, count
end

function GMP.observationBaselineNow()
    if GMP.recordCount("spread") == 0 and GMP.recordCount("rate") == 0 then
        GMP.setStatus("observationStatus", "Refresh live controller first")
        return false
    end
    local values, count = GMP.observationCapture()
    GMP.observationBaseline = values
    GMP.status.observationRows = {}
    GMP.setStatus("observationStatus",
        "Baseline captured: " .. count .. " scalar values")
    return true
end

function GMP.observationCompareNow()
    if not GMP.observationBaseline then
        GMP.setStatus("observationStatus", "Capture baseline first")
        return false
    end
    local latest = GMP.observationCapture()
    local rows = {}
    for key, original in pairs(GMP.observationBaseline) do
        local current = latest[key]
        if current and current.value ~= original.value then
            if #rows < 30 then
                rows[#rows + 1] = original.path .. " | "
                    .. tostring(original.value) .. " -> "
                    .. tostring(current.value)
            end
        end
    end
    table.sort(rows)
    GMP.status.observationRows = rows
    GMP.setStatus("observationStatus",
        "Compared: " .. #rows .. " changed scalar values (clues only)")
    return true
end
