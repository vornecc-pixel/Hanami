-- ==================================================================
-- Hanami / 20_gm_d_exports.lua — opt-in GunControl exports and read-only
-- visible fire-controller script hints. Reports are state / UI only.
-- ==================================================================

GMP.gunControl = { data = nil, status = "Not inspected (opt-in)",
    type = "unknown", rows = {}, attempts = 0, nextAttempt = 0 }
GMP.fireScript = { status = "Not inspected", scanned = 0, matches = 0,
    candidates = {} }

function GMP.findNamedModule(name)
    local RS = game:GetService("ReplicatedStorage")
    local roots = { RS, lp:FindFirstChild("PlayerScripts"),
        lp:FindFirstChildOfClass("PlayerGui") }
    for _, root in ipairs(roots) do
        if root then
            local descendants = nil
            pcall(function() descendants = root:GetDescendants() end)
            local visited = 0
            for _, object in ipairs(descendants or {}) do
                visited = visited + 1
                if visited > 500 then break end
                if object.Name == name or GMP.norm(object.Name) == GMP.norm(name) then
                    return object
                end
            end
        end
    end
    return nil
end

function GMP.moduleValue(obj)
    if not obj then return nil end
    local data = rawget(obj, "__saRequireValue")
    if type(data) == "table" then return data end
    if type(require) == "function" then
        local ok, result = pcall(require, obj)
        if ok and type(result) == "table" then return result end
    end
    if rawget(obj, "Defs") or rawget(obj, "GetSpread") then return obj end
    return nil
end

function GMP.gunControlRows(data)
    local rows = {}
    local visited = 0
    for key, value in next, data do
        visited = visited + 1
        if visited > 120 or #rows >= 18 then break end
        rows[#rows + 1] = tostring(key) .. " [" .. type(value) .. "]"
    end
    table.sort(rows)
    return rows
end

function GMP.requestGunControlExports(force)
    if not GMP.master() then
        GMP.setStatus("gunControlStatus", "Enable Gun Mods first")
        return nil
    end
    if CFG.gunInspectGunControl ~= true then
        GMP.setStatus("gunControlStatus", "Enable Inspect GunControl exports first")
        GMP.restoreLocalSpread()
        return nil
    end
    GMP.enableSource("GunControl exports")
    if GMP.gunControl.data and not force then
        GMP.applyMode("spread")
        return GMP.gunControl.data
    end
    local now = os.clock()
    if not force and now < GMP.gunControl.nextAttempt then
        return GMP.gunControl.data
    end
    GMP.gunControl.nextAttempt = now + 1.5
    GMP.gunControl.attempts = GMP.gunControl.attempts + 1
    local module = GMP.findNamedModule("GunControl")
    local data = GMP.moduleValue(module)
    if type(data) ~= "table" then
        GMP.setStatus("gunControlStatus", "GunControl module unavailable")
        GMP.gunControl.status = "Unavailable (hints only)"
        return nil
    end
    GMP.gunControl.data = data
    GMP.gunControl.type = typeof and typeof(data) or type(data)
    GMP.gunControl.rows = GMP.gunControlRows(data)
    GMP.gunControl.status = "Exports inspected (require may initialise)"
    GMP.setStatus("gunControlType", tostring(GMP.gunControl.type))
    GMP.setStatus("gunControlExportCount", #GMP.gunControl.rows)
    GMP.status.gunControlExportRows = GMP.gunControl.rows
    GMP.scanTable(data, "GunControl", "GunControl exports")
    GMP.applyMode("spread")
    GMP.setStatus("gunControlStatus", "Exports inspected; fields cached")
    return data
end

function GMP.restoreLocalSpread()
    local restored = GMP.restoreSource("GunControl exports")
    GMP.gunControl.data = nil
    GMP.gunControl.rows = {}
    GMP.gunControl.type = "unknown"
    GMP.gunControl.status = "Paused"
    GMP.setStatus("gunControlStatus", "Paused; originals restored")
    GMP.setStatus("gunControlType", "unknown")
    GMP.setStatus("gunControlFields", 0)
    GMP.setStatus("gunControlModified", restored)
    GMP.status.gunControlExportRows = {}
    GMP.setStatus("gunControlExportCount", 0)
    return restored
end

function GMP.testGunControlSpreadFields()
    local rows = {}
    for _, rec in ipairs(GMP.records.spread) do
        if rec.source == "GunControl exports" and #rows < 18 then
            rows[#rows + 1] = { path = rec.path,
                before = GMP.readEntry(rec), target = GMP.desiredFor(rec),
                original = rec.old, active = rec.active }
        end
    end
    GMP.setStatus("gunControlFields", #rows)
    GMP.setStatus("gunControlModified", GMP.on("gunNoSpread")
        and #rows or 0)
    return rows
end

function GMP.gunControlReport()
    local lines = {
        "Hanami GunControl export inspector",
        "Status: " .. tostring(GMP.gunControl.status),
        "Type: " .. tostring(GMP.gunControl.type),
        "Exported rows: " .. tostring(#GMP.gunControl.rows),
        "Optional require may run its own initializer.",
        "Fields are HINTS ONLY and UNVERIFIED.",
    }
    for i, row in ipairs(GMP.gunControl.rows) do
        lines[#lines + 1] = "Export " .. i .. ": " .. row
    end
    lines[#lines + 1] = "NAMED LOCAL SPREAD FIELDS:"
    for i, row in ipairs(GMP.testGunControlSpreadFields()) do
        lines[#lines + 1] = "Spread " .. i .. ": " .. row.path
            .. " | original=" .. tostring(row.original)
            .. " | current=" .. tostring(row.before)
            .. " | target=" .. tostring(row.target)
    end
    lines[#lines + 1] = "No server direction, hit or damage verification."
    return table.concat(lines, "\n")
end

function GMP.scanVisibleFireScripts()
    if not GMP.master() or CFG.gunInspectScripts ~= true then
        GMP.setStatus("fireScriptStatus", "Enable Inspect scripts first")
        return 0
    end
    local RS = game:GetService("ReplicatedStorage")
    local roots = { RS, lp:FindFirstChild("PlayerScripts"),
        lp:FindFirstChildOfClass("PlayerGui") }
    local candidates, scanned = {}, 0
    for _, root in ipairs(roots) do
        if root then
            local descendants = nil
            pcall(function() descendants = root:GetDescendants() end)
            for _, object in ipairs(descendants or {}) do
                scanned = scanned + 1
                if scanned > 900 then break end
                local name = GMP.norm(object.Name)
                local class = tostring(object.ClassName or "unknown")
                if (class:find("Script", 1, true) or class == "ModuleScript")
                    and (name:find("gun", 1, true) or name:find("fire", 1, true)
                    or name:find("shoot", 1, true) or name:find("combat", 1, true)
                    or name:find("weapon", 1, true)) then
                    if #candidates < 8 then
                        candidates[#candidates + 1] = {
                            name = tostring(object.Name), class = class,
                            path = tostring(root.Name) .. "/" .. tostring(object.Name),
                        }
                    end
                end
            end
        end
    end
    GMP.status.fireScriptCandidates = candidates
    GMP.setStatus("fireScriptScanned", scanned)
    GMP.setStatus("fireScriptMatches", #candidates)
    GMP.setStatus("fireScriptStatus", "Names only; no source or protected reads")
    return #candidates
end

function GMP.fireScriptReport()
    local lines = {
        "Hanami visible fire-controller script hints",
        "Status: " .. tostring(GMP.status.fireScriptStatus),
        "Checked: " .. tostring(GMP.status.fireScriptScanned),
        "Name matches: " .. tostring(GMP.status.fireScriptMatches),
        "Names / classes only; no getsenv or protected source reads.",
        "Candidates are HINTS ONLY and UNVERIFIED.",
    }
    for i, entry in ipairs(GMP.status.fireScriptCandidates) do
        lines[#lines + 1] = "Script " .. i .. ": " .. entry.name
            .. " [" .. entry.class .. "] " .. entry.path
    end
    return table.concat(lines, "\n")
end
