-- ==================================================================
-- Hanami / 16_esp_crates.lua — Crate ESP: robust detection + objects
-- Loaded in order by loader.lua. Parts are joined into ONE chunk
-- before running, so every `local` is shared just like the original.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- CRATE ESP — root cause of "it just doesn't work" (fixed here)
--
--  * The old code matched ONLY two exact model names, "Military Crate"
--    and "Elite Crate". Real revisions use MilitaryCrate, Crate_Military,
--    Elite_Crate, LootCrate, a Folder + CrateType attribute, hashed ids…
--    -> nothing was ever classified, so nothing was ever drawn.
--  * enableCrateESP() scanned Workspace ONCE. The only follow-up was
--    DescendantAdded, which fires for a Model BEFORE its parts are
--    parented: buildCrate() found no anchor and gave up permanently.
--    Unlike NPCs, the render loop never re-discovered crates.
--  * buildCrate() used FindFirstChildWhichIsA (direct children ONLY),
--    so crates whose parts live in nested sub-models had no anchor.
--  * BillboardGui / Highlight had no explicit Adornee; Folders, Part
--    roots and nested models rendered nothing.
--
-- Fixes: fuzzy name + attribute classification, a live background
-- registry (same pattern as the NPC scanner) that the render loop reads
-- every frame, recursive anchor lookup, and explicit Adornee targets.
-- ────────────────────────────────────────────────────────────────────

local CRATE_KIND_LABEL = {
    Military = "Military Crate", Elite = "Elite Crate", Loot = "Loot Crate",
}

local function normKey(s)
    return (tostring(s or ""):lower():gsub("[^%a%d]", ""))
end

local function crateKind(d)
    if not d or not d.Parent then return nil end
    -- never classify our own ESP instances (they get parented into crates,
    -- which would otherwise re-trigger DescendantAdded -> infinite rescan)
    if string.sub(d.Name, 1, 6) == "Hanami" then return nil end
    -- never mis-classify a player character or a known NPC as loot
    if d:IsA("Model") then
        if Players:GetPlayerFromCharacter(d) then return nil end
        if isNpc(d) then return nil end
    end
    local n = normKey(d.Name)
    if n:find("military") then return "Military" end
    if n:find("elite") then return "Elite" end
    for _, a in ipairs({ "CrateType", "Tier", "Rarity", "LootTier", "Crate", "Type" }) do
        local v = d:GetAttribute(a)
        if type(v) == "string" then
            local s = normKey(v)
            if s:find("military") then return "Military" end
            if s:find("elite") then return "Elite" end
            if s:find("crate") or s:find("loot") then return "Loot" end
        end
    end
    if not CFG.crateLooseDetect then return nil end
    for _, w in ipairs({ "crate", "loot", "supply", "airdrop", "cache", "chest", "stash" }) do
        if n:find(w) then return "Loot" end
    end
    -- containers tagged Opened / Looted are crates even when the model name
    -- is a hash or something generic like "Box1".
    for _, a in ipairs({ "Opened", "Looted", "IsOpen", "Used", "Empty", "LootTable" }) do
        if d:GetAttribute(a) ~= nil then return "Loot" end
    end
    return nil
end

local function isCrateOpened(model)
    if not model or not model.Parent then return false end
    for _, attr in ipairs({ "Opened", "Looted", "IsOpen", "WasOpened", "Used", "Empty", "LootedBy" }) do
        local v = model:GetAttribute(attr)
        if v == true or (type(v) == "number" and v ~= 0)
            or (type(v) == "string" and v ~= "") then return true end
    end
    for _, name in ipairs({ "Opened", "Looted" }) do
        local c = model:FindFirstChild(name)
        if c then
            if c:IsA("BoolValue") then
                if c.Value then return true end
            else return true end
        end
    end
    local lid = model:FindFirstChild("Lid") or model:FindFirstChild("Door")
    if lid and lid:IsA("BasePart") then
        local ok, pitchX = pcall(function()
            local _, x = lid.CFrame:ToEulerAnglesXYZ(); return x end)
        if ok and math.abs(math.deg(pitchX)) > 30 then return true end
    end
    return false
end

local function crateAnchor(model)
    if model:IsA("BasePart") then return model end
    local ok, part = pcall(function()
        if model:IsA("Model") and model.PrimaryPart then return model.PrimaryPart end
        return model:FindFirstChildWhichIsA("BasePart", true)
    end)
    return ok and part or nil
end

local function cratePivotPos(model)
    local ok, cf = pcall(function() return model:GetPivot() end)
    if ok and cf then return cf.Position end
    local part = crateAnchor(model)
    return part and part.Position or nil
end

local crateObjects = {}

local function clearCrate(model)
    local o = crateObjects[model]
    if not o then return end
    if SA.DisposeEspFx then SA.DisposeEspFx(o) end
    if o.bb then o.bb:Destroy() end
    if o.highlight then o.highlight:Destroy() end
    crateObjects[model] = nil
end

local function buildCrate(model)
    if crateObjects[model] or not model or not model.Parent then return end
    local anchor = crateAnchor(model)
    if not anchor then return end   -- parts not streamed in yet; registry retries
    local pos = cratePivotPos(model)
    if not pos then return end

    local bb = Instance.new("BillboardGui")
    bb.Name = "HanamiCrateGui"
    bb.Size = UDim2.fromOffset(220, 48)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.Adornee = anchor
    bb.Parent = anchor

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(1, 0, 0, 14)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 12
    nameLbl.TextStrokeTransparency = 0
    nameLbl.Parent = bb

    local stateLbl = Instance.new("TextLabel")
    stateLbl.Size = UDim2.new(1, 0, 0, 12)
    stateLbl.Position = UDim2.new(0, 0, 0, 14)
    stateLbl.BackgroundTransparency = 1
    stateLbl.Font = Enum.Font.GothamBold
    stateLbl.TextSize = 11
    stateLbl.TextStrokeTransparency = 0
    stateLbl.Parent = bb

    local distLbl = Instance.new("TextLabel")
    distLbl.Size = UDim2.new(1, 0, 0, 12)
    distLbl.Position = UDim2.new(0, 0, 0, 28)
    distLbl.BackgroundTransparency = 1
    distLbl.Font = Enum.Font.GothamMedium
    distLbl.TextSize = 11
    distLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
    distLbl.TextStrokeTransparency = 0
    distLbl.Parent = bb

    local hl = Instance.new("Highlight")
    hl.Name = "HanamiCrateHighlight"
    hl.Adornee = model:IsA("Model") and model or anchor
    hl.FillTransparency = 0.5
    hl.OutlineTransparency = 1
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = model

    crateObjects[model] = {
        bb = bb, nameLbl = nameLbl, stateLbl = stateLbl,
        distLbl = distLbl, highlight = hl, anchor = anchor,
    }
end
