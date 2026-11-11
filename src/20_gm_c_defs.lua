-- ==================================================================
-- Hanami / 20_gm_c_defs.lua — Fust.Items definition cache and identity.
-- Read-only matching diagnostics; named definition dispersion fields are
-- cached for the opt-in No Spread hold and restored on OFF / unload.
-- ==================================================================

GMP.items = { data = nil, status = "not requested", nextAttempt = 0,
              attempts = 0 }
GMP.aliasCache = { defs = nil, map = nil }
GMP.candidateCache = { defs = nil, token = nil, list = nil }
GMP.manualDefinition = { id = nil, token = nil }
GMP.DEFINITION_IDENTITY_FIELDS = { "name", "Name", "displayName",
    "DisplayName", "id", "Id", "ID", "itemId", "ItemId", "ItemID",
    "ItemName", "toolName", "ToolName", "modelName", "ModelName",
    "weaponName", "WeaponName", "internalName", "InternalName",
    "assetName", "AssetName", "shortName", "ShortName", "label", "Label" }
GMP.DEFINITION_NESTED_FIELDS = { "identity", "Identity", "info", "Info",
    "meta", "Meta", "metadata", "Metadata", "item", "Item", "weapon",
    "Weapon", "config", "Config", "data", "Data", "stats", "Stats",
    "display", "Display", "properties", "Properties" }

function GMP.requestItems(force)
    if not GMP.master() then
        GMP.items.status = "Enable Gun Mods first"
        return nil
    end
    if GMP.items.data and not force then return GMP.items.data end
    local now = os.clock()
    if not force and now < GMP.items.nextAttempt then return GMP.items.data end
    GMP.items.nextAttempt = now + 1.5
    GMP.items.attempts = GMP.items.attempts + 1
    local RS = game:GetService("ReplicatedStorage")
    local fust = RS:FindFirstChild("Fust") or RS:WaitForChild("Fust", 1)
    local obj = nil
    if fust then
        obj = fust:FindFirstChild("Items") or fust:WaitForChild("Items", 1)
    end
    if not obj then
        GMP.items.status = "Fust.Items not found"
        return nil
    end
    local data = rawget(obj, "__saRequireValue")
    if type(data) ~= "table" and type(require) == "function" then
        local ok, result = pcall(require, obj)
        if ok and type(result) == "table" then data = result end
    end
    if type(data) ~= "table" and rawget(obj, "Defs") then data = obj end
    if type(data) ~= "table" then
        GMP.items.status = "Fust.Items require unavailable"
        return nil
    end
    GMP.items.data = data
    GMP.items.status = "Fust.Items cached"
    return data
end

function GMP.identityAliases(defId, def)
    local result, seen = {}, {}
    local function add(value, source)
        if type(value) ~= "string" and type(value) ~= "number" then return end
        local text = tostring(value)
        local key = GMP.norm(text)
        if key == "" or #text > 120 or seen[key] then return end
        if GMP.GENERIC_MODEL_NAMES[key] or key == "tool" then return end
        seen[key] = true
        result[#result + 1] = { text = text, source = source }
    end
    add(defId, "definition key")
    local function fields(tab, prefix)
        for _, name in ipairs(GMP.DEFINITION_IDENTITY_FIELDS) do
            add(rawget(tab, name), prefix .. name)
        end
    end
    fields(def, "")
    for _, key in ipairs(GMP.DEFINITION_NESTED_FIELDS) do
        local nested = rawget(def, key)
        if type(nested) == "table" then fields(nested, key .. ".") end
    end
    return result
end

function GMP.aliasMap(defs)
    if GMP.aliasCache.defs == defs and GMP.aliasCache.map then
        return GMP.aliasCache.map
    end
    local map = {}
    local visited = 0
    for defId, def in pairs(defs) do
        visited = visited + 1
        if visited > 2048 then break end
        if type(def) == "table" then
            for _, alias in ipairs(GMP.identityAliases(defId, def)) do
                local key = GMP.norm(alias.text)
                if #key >= 3 then
                    local existing = map[key]
                    if not existing then
                        map[key] = { id = defId, def = def, ambiguous = false }
                    elseif existing.def ~= def then
                        existing.ambiguous = true
                    end
                end
            end
        end
    end
    GMP.aliasCache.defs, GMP.aliasCache.map = defs, map
    GMP.candidateCache.defs, GMP.candidateCache.list = nil, nil
    return map
end

function GMP.aliasLookup(map, value)
    local entry = map[GMP.norm(value)]
    if entry and not entry.ambiguous then return entry end
    return nil
end

function GMP.weaponToken(w)
    local obj = w.Tool or w.SourceObject
    return tostring(obj or "none") .. "|" .. GMP.norm(w.Name or "")
end

function GMP.definitionEvidence(w)
    local result, seen = {}, {}
    local function add(value, kind)
        if type(value) ~= "string" and type(value) ~= "number" then return end
        local key = GMP.norm(tostring(value))
        if key == "" or seen[key] then return end
        seen[key] = true
        result[#result + 1] = { text = tostring(value), kind = kind }
    end
    add(w.ItemId, "equipped ID")
    add(w.Name, "equipped name")
    if w.Tool then
        add(w.Tool.Name, "Tool name")
        add(w.Tool.ToolTip, "Tool tooltip")
        for _, field in ipairs(GMP.EQUIP_ATTRS) do
            add(GMP.attrText(w.Tool, { field }), "Tool attribute: " .. field)
        end
    end
    if w.SourceObject and w.SourceObject ~= w.Tool then
        add(w.SourceObject.Name, "source name")
    end
    return result
end

function GMP.definitionWords(value)
    local words = {}
    local fixed = tostring(value):gsub("(%l)(%u)", "%1 %2")
    for word in fixed:lower():gmatch("[%w]+") do
        if #word >= 4 and word ~= "weapon" and word ~= "model"
            and word ~= "item" and word ~= "tool" then words[word] = true end
    end
    return words
end

function GMP.definitionScore(evidence, alias)
    local query, name = GMP.norm(evidence.text), GMP.norm(alias.text)
    if #query < 3 or #name < 3 then return 0 end
    if query == name then return 140 end
    if #query >= 7 and #name >= 7 and (name:find(query, 1, true)
        or query:find(name, 1, true)) then return 72 end
    local qWords, nWords = GMP.definitionWords(evidence.text),
        GMP.definitionWords(alias.text)
    local score = 0
    for word in pairs(qWords) do
        if nWords[word] then score = score + 23 end
    end
    return score
end

function GMP.definitionCandidates(w, defs)
    local token = GMP.weaponToken(w) .. "|" .. tostring(w.ItemId or "")
    if GMP.candidateCache.defs == defs and GMP.candidateCache.token == token
        and GMP.candidateCache.list then return GMP.candidateCache.list end
    local evidence = GMP.definitionEvidence(w)
    local list, sampleIds = {}, {}
    local scanned, total = 0, 0
    for defId, def in pairs(defs) do
        total = total + 1
        if type(def) == "table" then
            scanned = scanned + 1
            if #sampleIds < 6 then
                local keys = {}
                for field in pairs(def) do
                    if #keys < 6 then keys[#keys + 1] = tostring(field) end
                end
                table.sort(keys)
                sampleIds[#sampleIds + 1] = tostring(defId) .. " ["
                    .. table.concat(keys, ", ") .. "]"
            end
            local highest, reason, representative = 0, "", tostring(defId)
            for _, alias in ipairs(GMP.identityAliases(defId, def)) do
                if alias.source ~= "definition key"
                    and representative == tostring(defId) then
                    representative = alias.text
                end
                for _, hint in ipairs(evidence) do
                    local score = GMP.definitionScore(hint, alias)
                    if score > highest then
                        highest, reason = score, hint.kind .. " -> " .. alias.source
                    end
                end
            end
            if highest >= 16 then
                list[#list + 1] = { id = defId, def = def, score = highest,
                    name = representative, reason = reason }
            end
        end
        if total >= 2048 then break end
    end
    table.sort(list, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return tostring(a.id) < tostring(b.id)
    end)
    while #list > 5 do table.remove(list) end
    GMP.candidateCache.defs, GMP.candidateCache.token = defs, token
    GMP.candidateCache.list = list
    GMP.setStatus("definitionSummary",
        scanned .. " table entries / " .. total .. " scanned")
    GMP.setStatus("definitionSchemaSamples", table.concat(sampleIds, " | "))
    local labels = {}
    for i = 1, math.min(#evidence, 6) do
        labels[i] = evidence[i].kind .. "=" .. evidence[i].text
    end
    GMP.setStatus("definitionMatchEvidence", table.concat(labels, ", "))
    GMP.status.definitionCandidates = list
    return list
end

function GMP.discoverDefinitionFromModels(w, defs, map)
    local best = nil
    local function consider(object, label, bonus)
        if not object or not object.Parent then return end
        local attrId = GMP.attrText(object)
        if attrId then
            local entry = GMP.aliasLookup(map, attrId)
            if entry then
                local score = 1000 + bonus + #GMP.norm(attrId)
                if not best or score > best.score then
                    best = { score = score, entry = entry, object = object,
                             label = label .. " attribute" }
                end
            end
        end
        local key = GMP.norm(object.Name)
        if key ~= "" and not GMP.GENERIC_MODEL_NAMES[key] then
            local entry = GMP.aliasLookup(map, key)
            if entry then
                local score = bonus + #key
                if object:IsA("Tool") then score = score + 100 end
                if object:IsA("Model") then score = score + 30 end
                if not best or score > best.score then
                    best = { score = score, entry = entry, object = object,
                             label = label }
                end
            end
        end
    end
    local roots = { { Workspace.CurrentCamera, "camera/viewmodel", 250 },
                    { lp.Character, "character model", 180 } }
    for _, rootData in ipairs(roots) do
        local root, label, bonus = rootData[1], rootData[2], rootData[3]
        if root then
            consider(root, label, bonus)
            local descendants = nil
            pcall(function() descendants = root:GetDescendants() end)
            local visited = 0
            for _, object in ipairs(descendants or {}) do
                visited = visited + 1
                if visited > 600 then break end
                if object:IsA("Model") or object:IsA("Tool")
                    or object:IsA("Accessory") or object:IsA("Folder") then
                    consider(object, label, bonus)
                end
            end
        end
    end
    if not best then return nil, nil end
    local entry = best.entry
    w.Definition, w.DefinitionId = entry.def, entry.id
    w.ItemId = tostring(entry.id)
    w.Name = tostring(rawget(entry.def, "name")
        or rawget(entry.def, "displayName") or best.object.Name)
    w.Source, w.SourceObject = best.label, best.object
    return entry.def, entry.id
end

function GMP.matchDefinition(w)
    local items = GMP.requestItems(false)
    if type(items) ~= "table" then return nil, nil end
    local defs = rawget(items, "Defs")
    if type(defs) ~= "table" then
        GMP.setStatus("definitionScanState", "No Defs table in module")
        GMP.setStatus("definitionMatchStatus", "No standard Defs dictionary")
        return nil, nil
    end
    local map = GMP.aliasMap(defs)
    local token = GMP.weaponToken(w)
    if GMP.manualDefinition.token and token ~= GMP.manualDefinition.token then
        GMP.manualDefinition.id, GMP.manualDefinition.token = nil, nil
        GMP.setStatus("definitionSelectionStatus",
            "Automatic only (equipped weapon changed)")
    end
    if GMP.manualDefinition.id ~= nil then
        local chosen = rawget(defs, GMP.manualDefinition.id)
        if type(chosen) == "table" then
            w.Definition, w.DefinitionId = chosen, GMP.manualDefinition.id
            GMP.setStatus("definitionMatchStatus",
                "Manual candidate: " .. tostring(GMP.manualDefinition.id))
            return chosen, GMP.manualDefinition.id
        end
        GMP.manualDefinition.id, GMP.manualDefinition.token = nil, nil
    end
    if w.Definition and w.DefinitionId ~= nil
        and rawget(defs, w.DefinitionId) == w.Definition then
        GMP.setStatus("definitionMatchStatus",
            "Cached exact definition: " .. tostring(w.DefinitionId))
        return w.Definition, w.DefinitionId
    end
    if w.ItemId ~= nil then
        local direct, directKey = rawget(defs, w.ItemId), w.ItemId
        if type(direct) ~= "table" and tonumber(w.ItemId) then
            directKey = tonumber(w.ItemId)
            direct = rawget(defs, directKey)
        end
        if type(direct) == "table" then
            w.Definition, w.DefinitionId = direct, directKey
            GMP.setStatus("definitionMatchStatus",
                "Exact definition ID: " .. tostring(directKey))
            return direct, directKey
        end
    end
    for _, value in ipairs({ w.ItemId, w.Name }) do
        if value ~= nil then
            local entry = GMP.aliasLookup(map, value)
            if entry then
                w.Definition, w.DefinitionId = entry.def, entry.id
                w.ItemId = tostring(entry.id)
                w.Name = tostring(rawget(entry.def, "name")
                    or rawget(entry.def, "displayName") or w.Name)
                GMP.setStatus("definitionMatchStatus",
                    "Exact identity alias: " .. tostring(entry.id))
                return entry.def, entry.id
            end
        end
    end
    local def, defId = GMP.discoverDefinitionFromModels(w, defs, map)
    if def then
        GMP.setStatus("definitionMatchStatus",
            "Exact viewmodel identity: " .. tostring(defId))
        return def, defId
    end
    local candidates = GMP.definitionCandidates(w, defs)
    GMP.setStatus("definitionMatchStatus", #candidates > 0
        and "No exact match; suggestions are UNVERIFIED"
        or "No matching aliases; inspect the definition schema")
    return nil, nil
end

function GMP.useDefinitionCandidate(index)
    local list = GMP.status.definitionCandidates or {}
    local candidate = list[tonumber(index) or 0]
    if not candidate then return false end
    local w = GMP.getWeapon()
    GMP.manualDefinition.id = candidate.id
    GMP.manualDefinition.token = GMP.weaponToken(w)
    w.Definition, w.DefinitionId = candidate.def, candidate.id
    GMP.setStatus("definitionSelectionStatus",
        "Manual candidate " .. tostring(candidate.id) .. " (unverified)")
    GMP.setStatus("definitionMatchStatus",
        "Manual candidate: " .. tostring(candidate.id))
    return true
end

function GMP.clearManualDefinition()
    GMP.manualDefinition.id, GMP.manualDefinition.token = nil, nil
    GMP.getWeapon().Definition, GMP.getWeapon().DefinitionId = nil, nil
    GMP.setStatus("definitionSelectionStatus", "Automatic only")
    return true
end

function GMP.definitionKeySummary(def)
    if type(def) ~= "table" then return "none" end
    local keys = {}
    for key in pairs(def) do
        if #keys < 20 then keys[#keys + 1] = tostring(key) end
    end
    table.sort(keys)
    return table.concat(keys, ", ")
end

function GMP.refreshDefinitionInspector(force)
    if not GMP.master() then
        GMP.setStatus("definitionScanState", "Enable Gun Mods first")
        return nil
    end
    local w = GMP.getWeapon()
    local items = GMP.requestItems(force == true)
    if type(items) ~= "table" then
        GMP.setStatus("definitionScanState",
            "Waiting: " .. tostring(GMP.items.status))
        return nil
    end
    local def, defId = GMP.matchDefinition(w)
    if type(def) == "table" then
        GMP.setStatus("definitionScanState", "MATCH: " .. tostring(defId))
        GMP.setStatus("definitionSummary", "Definition keys: "
            .. GMP.definitionKeySummary(def))
        if GMP.on("gunNoSpread") then
            GMP.scanTable(def, "Fust.Items." .. tostring(defId),
                "Fust.Items definition")
        end
    else
        GMP.setStatus("definitionScanState",
            "UNMATCHED: " .. tostring(w.Name or "None"))
    end
    return def
end

function GMP.inspectSelectedDefinition()
    local w = GMP.getWeapon()
    local def, defId = GMP.matchDefinition(w)
    return { name = tostring(w.Name), id = tostring(defId),
        keys = GMP.definitionKeySummary(def),
        status = GMP.status.definitionMatchStatus,
        candidates = GMP.status.definitionCandidates or {},
        evidence = GMP.status.definitionMatchEvidence }
end

function GMP.definitionReport()
    local lines = {
        "Hanami Fust.Items definition inspector",
        "Module: " .. tostring(GMP.items.status),
        "Scan: " .. tostring(GMP.status.definitionScanState),
        "Match: " .. tostring(GMP.status.definitionMatchStatus),
        "Evidence: " .. tostring(GMP.status.definitionMatchEvidence),
        "Schema: " .. tostring(GMP.status.definitionSchemaSamples),
        "Selection: " .. tostring(GMP.status.definitionSelectionStatus),
        "Candidates are hints only and UNVERIFIED.",
        "Read-only inspector; No Spread edits named local fields only.",
    }
    for i, candidate in ipairs(GMP.status.definitionCandidates or {}) do
        if i > 5 then break end
        lines[#lines + 1] = "Candidate " .. i .. ": "
            .. tostring(candidate.id) .. " | score "
            .. tostring(candidate.score) .. " | " .. tostring(candidate.reason)
    end
    return table.concat(lines, "\n")
end
