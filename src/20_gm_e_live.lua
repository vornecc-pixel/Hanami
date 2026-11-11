-- ==================================================================
-- Hanami / 20_gm_e_live.lua — source-attributed live-controller scanner.
-- One bounded getgc discovery pass, then cached strong-keyed field holds.
-- No firing remotes, no function replacement and no protected source reads.
-- ==================================================================

GMP.live = { scanned = false, busy = false, generation = 0,
    nextRun = 0, lastHold = 0, gcInspected = 0,
    gcMode = "not attempted", closures = 0, tables = 0,
    apis = "not checked", errors = {}, clues = {} }
GMP.controllerNames = { FustGuns = true, FustCombat = true,
    FustCombatHub = true, FustCombatKits = true, FustCombatLook = true }

function GMP.liveAddError(text)
    if #GMP.live.errors < 10 then
        GMP.live.errors[#GMP.live.errors + 1] = tostring(text):sub(1, 160)
    end
end

function GMP.liveAddClue(text)
    local clue = tostring(text):sub(1, 160)
    for _, existing in ipairs(GMP.live.clues) do
        if existing == clue then return end
    end
    if #GMP.live.clues < 20 then
        GMP.live.clues[#GMP.live.clues + 1] = clue
    end
end

function GMP.liveSources()
    local targets = {}
    local RS = game:GetService("ReplicatedStorage")
    local roots = { lp:FindFirstChild("PlayerScripts"),
        lp:FindFirstChildOfClass("PlayerGui"), RS }
    for _, root in ipairs(roots) do
        if root then
            local descendants = nil
            pcall(function() descendants = root:GetDescendants() end)
            local visited = 0
            for _, object in ipairs(descendants or {}) do
                visited = visited + 1
                if visited > 700 then break end
                local name = tostring(object.Name or "")
                if GMP.controllerNames[name] then
                    targets[object] = name
                else
                    local normal = GMP.norm(name)
                    if normal:find("fustguns", 1, true)
                        or normal:find("fustcombat", 1, true) then
                        targets[object] = name
                    end
                end
            end
        end
    end
    return targets
end

function GMP.liveSourceFor(item, targets)
    if type(item) == "table" then
        local tagged = rawget(item, "__saGunSource")
        if type(tagged) == "string" and tagged ~= "" then return tagged end
    end
    if type(item) ~= "function" then return nil end
    if type(getfenv) == "function" then
        local ok, env = pcall(getfenv, item)
        if ok and type(env) == "table" then
            local scriptObj = rawget(env, "script")
            if scriptObj and targets[scriptObj] then return targets[scriptObj] end
        end
    end
    if type(debug) == "table" and type(debug.info) == "function" then
        local ok, source = pcall(debug.info, item, "s")
        if ok and type(source) == "string" then
            local normal = source:lower():gsub("[/\\]", ".")
            for name in pairs(GMP.controllerNames) do
                if normal:find(name:lower(), 1, true) then return name end
            end
        end
    end
    return nil
end

function GMP.liveUpvalues(item)
    if type(debug) ~= "table" or type(debug.getupvalues) ~= "function" then
        return nil
    end
    local ok, values = pcall(debug.getupvalues, item)
    if ok and type(values) == "table" then return values end
    return nil
end

function GMP.liveConstants(item)
    if type(debug) ~= "table" or type(debug.getconstants) ~= "function" then
        return nil
    end
    local ok, values = pcall(debug.getconstants, item)
    if ok and type(values) == "table" then return values end
    return nil
end

function GMP.liveInspectTable(tab, path, source, seen)
    if type(tab) ~= "table" or seen[tab] then return end
    seen[tab] = true
    GMP.live.tables = GMP.live.tables + 1
    if GMP.live.tables > 1200 then return end
    GMP.scanTable(tab, path, "live controller")
    if not source then return end
    local visited = 0
    for key, value in next, tab do
        visited = visited + 1
        if visited > 80 then break end
        if type(value) == "table" and not seen[value]
            and type(key) == "string" then
            local k = GMP.norm(key)
            if k:find("gun", 1, true) or k:find("fire", 1, true)
                or k:find("state", 1, true) or k:find("settings", 1, true)
                or k:find("profile", 1, true) then
                GMP.liveInspectTable(value, path .. "." .. tostring(key),
                    source, seen)
            end
        end
    end
end

function GMP.liveInspect(item, targets, seen)
    if type(item) == "table" then
        local tagged = rawget(item, "__saGunSource")
        if type(tagged) == "string" and tagged ~= "" then
            GMP.liveInspectTable(item, tagged .. ".gc", tagged, seen)
        end
        return
    end
    if type(item) ~= "function" then return end
    local source = GMP.liveSourceFor(item, targets)
    if not source then return end
    GMP.live.closures = GMP.live.closures + 1
    if GMP.live.closures > 120 then return end
    local constants = GMP.liveConstants(item)
    if constants then
        local words = {}
        for _, value in pairs(constants) do
            if type(value) == "string" and #words < 8 then
                local low = value:lower()
                if low:find("spread", 1, true) or low:find("fire", 1, true)
                    or low:find("shot", 1, true) or low:find("ammo", 1, true)
                    or low:find("recoil", 1, true) or low:find("sprint", 1, true) then
                    words[#words + 1] = value:sub(1, 45)
                end
            end
        end
        if #words > 0 then
            GMP.liveAddClue(source .. " constants=" .. table.concat(words, ", "))
        end
    end
    local upvalues = GMP.liveUpvalues(item)
    if not upvalues then return end
    local count = 0
    for _, value in pairs(upvalues) do count = count + 1 end
    if GMP.live.closures <= 6 then
        GMP.liveAddClue(source .. " upvalues=" .. count)
    end
    for key, value in pairs(upvalues) do
        if type(value) == "table" then
            GMP.liveInspectTable(value,
                source .. ".upvalue[" .. tostring(key) .. "]", source, seen)
        end
    end
end

function GMP.liveApiStatus()
    local haveEnv = type(getsenv) == "function"
    local haveGC = type(getgc) == "function"
    local haveUp = type(debug) == "table"
        and type(debug.getupvalues) == "function"
    GMP.live.apis = "getsenv=" .. tostring(haveEnv)
        .. ", getgc=" .. tostring(haveGC)
        .. ", debug.getupvalues=" .. tostring(haveUp)
    return GMP.live.apis
end

function GMP.liveCount(mode, source)
    local total = 0
    for _, rec in ipairs(GMP.records[mode] or {}) do
        if not source or rec.source == source then total = total + 1 end
    end
    return total
end

function GMP.liveActiveCount(mode)
    local total = 0
    for _, rec in ipairs(GMP.records[mode] or {}) do
        if rec.active then total = total + 1 end
    end
    return total
end

function GMP.syncLiveStatus()
    GMP.setStatus("liveGunClosures", GMP.live.closures)
    GMP.setStatus("liveGunTables", GMP.live.tables)
    GMP.setStatus("liveGunAPIs", GMP.live.apis)
    GMP.status.liveGunErrors = GMP.copy(GMP.live.errors)
    GMP.setStatus("liveGunFields", GMP.liveCount("spread", "live controller"))
    GMP.setStatus("liveRecoilFields", GMP.liveCount("recoil", "live controller"))
    GMP.setStatus("liveFireRateFields", GMP.liveCount("rate", "live controller"))
    GMP.setStatus("liveAmmoFields", GMP.liveCount("ammo", "live controller"))
    GMP.setStatus("liveMovementFields",
        GMP.liveCount("movement", "live controller"))
    GMP.setStatus("liveGunZeroed", GMP.liveActiveCount("spread"))
    GMP.setStatus("liveRecoilZeroed", GMP.liveActiveCount("recoil"))
    GMP.setStatus("liveFireRateChanged", GMP.liveActiveCount("rate"))
    GMP.setStatus("liveAmmoChanged", GMP.liveActiveCount("ammo"))
    GMP.setStatus("liveMovementChanged", GMP.liveActiveCount("movement"))
    local rows = {}
    for _, mode in ipairs(GMP.modes) do
        for _, rec in ipairs(GMP.records[mode]) do
            if rec.source == "live controller" and #rows < 18 then
                rows[#rows + 1] = rec.mode .. " | " .. rec.path
            end
        end
    end
    GMP.status.liveGunCandidates = rows
end

function GMP.scanLive(force)
    if CFG.gunInspectLiveGun ~= true then
        GMP.setStatus("liveGunStatus",
            "Enable live firing-state inspection first")
        return false
    end
    if not GMP.master() then
        GMP.setStatus("liveGunStatus", "Enable Gun Mods first")
        return false
    end
    if GMP.live.busy then return false end
    if GMP.live.scanned and not force then return true end
    local now = os.clock()
    if not force and now < GMP.live.nextRun then return false end
    GMP.live.busy = true
    GMP.live.nextRun = math.huge
    GMP.live.generation = GMP.live.generation + 1
    GMP.live.gcInspected, GMP.live.gcMode = 0, "not attempted"
    GMP.live.closures, GMP.live.tables = 0, 0
    GMP.live.errors, GMP.live.clues = {}, {}
    GMP.liveApiStatus()
    GMP.enableSource("live controller")
    GMP.enableSource("equipped tool")
    GMP.inspectTool()
    local targets = GMP.liveSources()
    local targetCount = 0
    for _ in pairs(targets) do targetCount = targetCount + 1 end
    if targetCount == 0 then
        GMP.liveAddError("Fust controller script names not found")
    end
    if type(getsenv) == "function" then
        for scriptObj, name in pairs(targets) do
            local ok, env = pcall(getsenv, scriptObj)
            if ok and type(env) == "table" then
                GMP.liveInspectTable(env, name .. ".env", name, {})
            elseif not ok then
                GMP.liveAddError(name .. " getsenv: " .. tostring(env))
            end
        end
    end
    local function inspectObjects(objects)
        local checked = 0
        for _, item in pairs(objects) do
            checked = checked + 1
            GMP.live.gcInspected = GMP.live.gcInspected + 1
            if checked > 3500 then break end
            GMP.liveInspect(item, targets, {})
            if checked % 500 == 0 and type(task) == "table"
                and type(task.wait) == "function" then
                pcall(task.wait)
            end
        end
        if checked > 3500 then
            GMP.liveAddError("GC discovery capped at 3500 objects")
        end
    end
    if type(getgc) == "function" then
        local fastOK, fastObjects = pcall(getgc, false)
        if fastOK and type(fastObjects) == "table" then
            GMP.live.gcMode = "getgc(false)"
            inspectObjects(fastObjects)
        else
            GMP.liveAddError("Light GC pass unavailable: " .. tostring(fastObjects))
        end
        if GMP.liveCount("spread", "live controller") < 1 then
            local fullOK, fullObjects = pcall(getgc, true)
            if fullOK and type(fullObjects) == "table" then
                GMP.live.gcMode = GMP.live.gcMode .. " + full fallback"
                inspectObjects(fullObjects)
            else
                GMP.liveAddError("Full GC fallback unavailable")
            end
        end
    else
        GMP.liveAddError("getgc unavailable")
    end
    GMP.live.busy = false
    GMP.live.scanned = true
    GMP.syncLiveStatus()
    if GMP.live.tables > 0 then
        GMP.setStatus("liveGunStatus", "Live controller fields cached: "
            .. GMP.liveCount("spread", "live controller")
            .. " spread (shot result unverified)")
    else
        GMP.setStatus("liveGunStatus",
            "No accessible live controller fields (check report APIs)")
    end
    GMP.reconcile()
    return true
end

function GMP.holdLive(force)
    if not GMP.master() then return false end
    local now = os.clock()
    if not force and now - GMP.live.lastHold < 0.10 then return false end
    GMP.live.lastHold = now
    GMP.reconcile()
    GMP.syncLiveStatus()
    return true
end

function GMP.liveReport()
    local lines = {
        "Hanami V16.46-style live controller field report",
        "Weapon: " .. tostring(GMP.getWeapon().Name),
        "Inspector: " .. tostring(CFG.gunInspectLiveGun == true),
        "Status: " .. tostring(GMP.status.liveGunStatus),
        "Available APIs: " .. tostring(GMP.live.apis),
        "GC mode: " .. tostring(GMP.live.gcMode),
        "GC objects inspected: " .. tostring(GMP.live.gcInspected),
        "Source-matched closures: " .. tostring(GMP.live.closures),
        "Controller tables inspected: " .. tostring(GMP.live.tables),
        "Spread fields: " .. tostring(GMP.status.liveGunFields)
            .. " | held: " .. tostring(GMP.status.liveGunZeroed),
        "Recoil fields: " .. tostring(GMP.status.liveRecoilFields)
            .. " | held: " .. tostring(GMP.status.liveRecoilZeroed),
        "Rate fields: " .. tostring(GMP.status.liveFireRateFields)
            .. " | held: " .. tostring(GMP.status.liveFireRateChanged),
        "Ammo fields: " .. tostring(GMP.status.liveAmmoFields)
            .. " | held: " .. tostring(GMP.status.liveAmmoChanged),
        "Movement permissions: " .. tostring(GMP.status.liveMovementFields)
            .. " | held: " .. tostring(GMP.status.liveMovementChanged),
        "Tool: " .. tostring(GMP.status.liveToolSettingsStatus),
        "Observation: " .. tostring(GMP.status.observationStatus),
    }
    for i, clue in ipairs(GMP.live.clues) do
        lines[#lines + 1] = "Clue " .. i .. ": " .. clue
    end
    for i, row in ipairs(GMP.status.liveGunCandidates) do
        lines[#lines + 1] = "Field " .. i .. ": " .. row
    end
    for i, row in ipairs(GMP.status.observationRows) do
        lines[#lines + 1] = "Changed scalar " .. i .. ": " .. row
    end
    for i, err in ipairs(GMP.live.errors) do
        lines[#lines + 1] = "Diagnostic " .. i .. ": " .. err
    end
    lines[#lines + 1] = "Only named local client fields are edited."
    lines[#lines + 1] = "No remote, RNG, function replacement or protected source read."
    lines[#lines + 1] = "Server may override rate, ammo and movement gates."
    lines[#lines + 1] = "Even if fields are held, shot/hit direction remains UNVERIFIED."
    return table.concat(lines, "\n")
end

-- One generation-guarded background discovery task. The expensive scan is
-- one-shot; this only retries until the cached scan succeeds. There is no
-- second RenderStepped callback and no periodic full-GC sweep.
if type(task) == "table" and type(task.spawn) == "function" then
    task.spawn(function()
        local gen = GMP.generation
        while GMP.alive and SA.Alive and SA.Generation == gen do
            if GMP.master() and CFG.gunInspectLiveGun == true
                and not GMP.live.scanned then
                GMP.scanLive(false)
            end
            if type(task) == "table" and type(task.wait) == "function" then
                pcall(task.wait, 2)
            end
        end
    end)
end
