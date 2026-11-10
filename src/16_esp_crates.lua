-- ==================================================================
-- Hanami / 16_esp_crates.lua — Crate ESP: robust detection + objects
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
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

-- FIX for "highlight on other things": the old rule accepted ANY instance
-- with an `Opened`/`Looted` attribute, so doors, scenery and whole folders
-- got a Highlight. Now only container-like Models/BaseParts with a real
-- crate signal qualify, and the Highlight is bound to one anchor part.
local CRATE_WORDS = { "military", "elite", "crate", "loot", "supply",
                      "airdrop", "cache", "chest", "stash" }
local CRATE_LOOSE = { "box", "container", "parcel", "pile", "drop" }

local function crateKind(d)
    if not d or not d.Parent then return nil end
    local nm = d.Name
    -- never classify our own ESP instances (they get parented into crates,
    -- which would otherwise re-trigger DescendantAdded -> infinite rescan)
    if string.sub(nm, 1, 6) == "Hanami" then return nil end
    -- Folders / Attachments / GUIs are not crates. A "Loot" folder holding
    -- every spawn point was the main source of highlights on other items.
    if not (d:IsA("Model") or d:IsA("BasePart")) then return nil end
    if d:IsA("Model") then
        if Players:GetPlayerFromCharacter(d) then return nil end
        if isNpc(d) or d:FindFirstChildOfClass("Humanoid") then return nil end
    end

    local n = normKey(nm)
    if n:find("military") then return "Military" end
    if n:find("elite") then return "Elite" end

    local named = false
    for _, w in ipairs(CRATE_WORDS) do
        if n:find(w) then named = true; break end
    end
    -- explicit crate metadata on otherwise generic / hashed names
    if not named then
        for _, a in ipairs({ "CrateType", "Tier", "Rarity", "LootTier" }) do
            local v = d:GetAttribute(a)
            if type(v) == "string" then
                local s = normKey(v)
                if s:find("military") then return "Military" end
                if s:find("elite") then return "Elite" end
                if s:find("crate") or s:find("loot") then return "Loot" end
            end
        end
    end
    if named then return "Loot" end
    if not CFG.crateLooseDetect then return nil end

    -- loose mode still needs BOTH a container-ish name and a loot state
    local loose = false
    for _, w in ipairs(CRATE_LOOSE) do
        if n:find(w) then loose = true; break end
    end
    if loose then
        for _, a in ipairs({ "Opened", "Looted", "IsOpen", "LootTable", "CrateType" }) do
            if d:GetAttribute(a) ~= nil then return "Loot" end
        end
    end
    return nil
end

-- ────────────────────────────────────────────────────────────────────
-- OPENED / UNOPENED STATE — was showing the exact opposite label
--
-- Causes found:
--  * `local _, x = lid.CFrame:ToEulerAnglesXYZ()` grabs the SECOND return
--    (Y rotation), not X. Crates spawn at random Y rotations, so closed
--    crates were reported OPENED and vice versa.
--  * The lid angle was measured in WORLD space, so the crate's own
--    placement rotation counted as "the lid is open".
--  * ANY non-BoolValue child called "Opened"/"Looted" (a Part, a Folder…)
--    returned true unconditionally.
--  * ANY non-empty string attribute returned true — including "false",
--    "0", "no" and "closed".
--  * There was no way to flip the label for games whose flag is inverted.
--
-- Now: strict truthiness, explicit "still closed" signals win, a
-- ProximityPrompt / loot container is used as a reliable secondary signal,
-- the lid guess is opt-in and measured relative to the crate, and
-- ESP -> Crate ESP -> Invert Crate State flips the result if needed.
-- ────────────────────────────────────────────────────────────────────

local OPENED_ATTRS = { "Opened", "Looted", "IsOpen", "WasOpened", "Used",
                       "Empty", "LootedBy", "OpenedBy", "Searched", "Taken" }
local CLOSED_ATTRS = { "Closed", "Sealed", "Unopened", "Available", "CanOpen",
                       "CanLoot", "HasLoot", "Full", "Ready", "NotLooted" }
local OPENED_CHILDREN = { "Opened", "Looted", "IsOpen", "WasOpened", "Used",
                          "Empty", "Searched", "Taken" }
local CLOSED_CHILDREN = { "Closed", "Sealed", "Unopened", "Available",
                          "CanOpen", "HasLoot", "Full" }

-- nil = no signal at all; true/false = explicit state
local function stateTruthy(v)
    if v == nil then return nil end
    local tv = type(v)
    if tv == "boolean" then return v end
    if tv == "number"  then return v ~= 0 end
    if tv == "string" then
        local s = v:lower():gsub("%s", "")
        if s == "" or s == "false" or s == "0" or s == "no" or s == "nil"
            or s == "none" or s == "closed" or s == "unopened" or s == "off" then
            return false
        end
        return true
    end
    return nil
end

-- Only real state ValueBase objects count. A Part named "Opened" is NOT a
-- state flag (the old code treated it as one).
local function valueBaseTruthy(c)
    if not c then return nil end
    local ok, r = pcall(function()
        if c:IsA("BoolValue") then return c.Value end
        if c:IsA("IntValue") or c:IsA("NumberValue") then return c.Value ~= 0 end
        if c:IsA("StringValue") then return stateTruthy(c.Value) end
        return nil
    end)
    if not ok then return nil end
    return r          -- false is a real signal, do not collapse it to nil
end

-- Any explicit `true` wins; an explicit `false` is only returned when no
-- signal said true (so `Opened=false, Looted=true` still reads as opened).
local function anySignal(model, attrs, children)
    local sawFalse, falseName = false, nil
    for _, a in ipairs(attrs) do
        local ok, v = pcall(function() return stateTruthy(model:GetAttribute(a)) end)
        if ok and v == true then return true, a end
        if ok and v == false then sawFalse, falseName = true, a end
    end
    for _, n in ipairs(children) do
        local v = valueBaseTruthy(model:FindFirstChild(n))
        if v == true then return true, n end
        if v == false then sawFalse, falseName = true, n end
    end
    if sawFalse then return false, falseName end
    return nil, nil
end

local function isCrateOpened(model)
    if not model or not model.Parent then return false end
    -- explicit if, NOT `and/or`: `false or state` would break the flip
    local applyInvert = function(state)
        if CFG.crateInvertState then return not state end
        return state
    end

    -- 1. An explicit "still closed / loot available" signal is the most
    --    reliable, and it also auto-corrects games with inverted "Opened".
    local closed = anySignal(model, CLOSED_ATTRS, CLOSED_CHILDREN)
    if closed == true then return applyInvert(false) end

    -- 2. Explicit "already consumed" signals.
    local opened = anySignal(model, OPENED_ATTRS, OPENED_CHILDREN)

    -- 3. A disabled ProximityPrompt means the crate can no longer be
    --    opened; an enabled one means it is still lootable.
    local prompt, promptEnabled
    pcall(function() prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true) end)
    if prompt then
        pcall(function() promptEnabled = prompt.Enabled end)
    end

    -- 3b. AUTO-CORRECT inverted games: if the attribute says OPENED but
    --     the crate is still interactable (or says UNOPENED but the prompt
    --     is disabled), the two signals contradict. The prompt is the
    --     player-facing truth, so it wins. This is exactly the "every
    --     label is backwards" case in games whose `Opened` flag means
    --     "available to open".
    if opened ~= nil and type(promptEnabled) == "boolean" then
        if opened ~= (not promptEnabled) then
            return applyInvert(not promptEnabled)
        end
    end

    if opened == true then return applyInvert(true) end
    if opened == false then return applyInvert(false) end
    if type(promptEnabled) == "boolean" then return applyInvert(not promptEnabled) end

    -- 4. Loot container: empty = already taken, contents = untouched.
    for _, n in ipairs({ "Loot", "Contents", "Items", "Rewards", "Inventory" }) do
        local box = model:FindFirstChild(n)
        if box then
            local n2 = 0
            pcall(function() n2 = #box:GetChildren() end)
            return applyInvert(n2 == 0)
        end
    end

    -- 5. OPT-IN lid-angle guess (default OFF). Measured RELATIVE to the
    --    crate so the crate's world rotation cannot trigger a false hit.
    if CFG.crateLidDetect then
        local lid = model:FindFirstChild("Lid") or model:FindFirstChild("Door")
        if lid and lid:IsA("BasePart") then
            local ok, rx = pcall(function()
                local rel = model:GetPivot():ToObjectSpace(lid.CFrame)
                return (rel:ToEulerAnglesXYZ())   -- FIRST return = X rotation
            end)
            if ok and type(rx) == "number" and math.abs(math.deg(rx)) > 30 then
                return applyInvert(true)
            end
        end
    end
    return applyInvert(false)
end

-- Resolve opened / unopened state from the model's own signals.

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
    SA.ApplyEspFont(nameLbl)
    nameLbl.TextSize = 12
    nameLbl.TextStrokeTransparency = 0
    nameLbl.Parent = bb

    local stateLbl = Instance.new("TextLabel")
    stateLbl.Size = UDim2.new(1, 0, 0, 12)
    stateLbl.Position = UDim2.new(0, 0, 0, 14)
    stateLbl.BackgroundTransparency = 1
    SA.ApplyEspFont(stateLbl)
    stateLbl.TextSize = 11
    stateLbl.TextStrokeTransparency = 0
    stateLbl.Parent = bb

    local distLbl = Instance.new("TextLabel")
    distLbl.Size = UDim2.new(1, 0, 0, 12)
    distLbl.Position = UDim2.new(0, 0, 0, 28)
    distLbl.BackgroundTransparency = 1
    SA.ApplyEspFont(distLbl)
    distLbl.TextSize = 11
    distLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
    distLbl.TextStrokeTransparency = 0
    distLbl.Parent = bb

    local hl = Instance.new("Highlight")
    hl.Name = "HanamiCrateHighlight"
    -- bind to ONE part, never to a whole Model/Folder: a parent model can
    -- contain scenery, and Highlight would have lit all of it up.
    hl.Adornee = anchor
    hl.FillTransparency = 0.5
    hl.OutlineTransparency = 1
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Enabled = false        -- refresh enables it only when the toggle is ON
    hl.Parent = anchor

    crateObjects[model] = {
        bb = bb, nameLbl = nameLbl, stateLbl = stateLbl,
        distLbl = distLbl, highlight = hl, anchor = anchor,
    }
end
