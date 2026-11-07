-- ==================================================================
-- Hanami / 09_esp_crates.lua — Crate ESP objects, state, labels
-- Loaded in order by loader.lua. Parts are joined into ONE chunk
-- before running, so every `local` is shared just like the original.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- CRATE ESP
-- ────────────────────────────────────────────────────────────────────

local CRATE_NAMES = { ["Military Crate"] = "Military", ["Elite Crate"] = "Elite" }
local crateObjects = {}
local crateColorMilitary = Color3.fromRGB(80, 200, 255)
local crateColorElite    = Color3.fromRGB(255, 200, 60)
local crateColorOpened   = Color3.fromRGB(120, 120, 120)

local function isCrateOpened(model)
    if not model or not model.Parent then return false end
    for _, attr in ipairs({ "Opened", "Looted", "IsOpen", "Used", "Empty" }) do
        if model:GetAttribute(attr) == true then return true end
    end
    for _, name in ipairs({ "Opened", "Looted" }) do
        if model:FindFirstChild(name) then return true end
    end
    local lid = model:FindFirstChild("Lid") or model:FindFirstChild("Door")
    if lid and lid:IsA("BasePart") then
        local _, pitchX = lid.CFrame:ToEulerAnglesXYZ()
        if math.abs(math.deg(pitchX)) > 30 then return true end
    end
    return false
end

local function cratePivotPos(model)
    local ok, cf = pcall(function() return model:GetPivot() end)
    if ok and cf then return cf.Position end
    local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
    return part and part.Position or nil
end

local function clearCrate(model)
    local o = crateObjects[model]
    if not o then return end
    if o.bb then o.bb:Destroy() end
    if o.highlight then o.highlight:Destroy() end
    crateObjects[model] = nil
end

local function buildCrate(model)
    if crateObjects[model] then return end
    if not model:IsA("Model") and not model:IsA("BasePart") then return end
    local anchor = model:IsA("Model")
        and (model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")) or model
    if not anchor then return end

    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.fromOffset(220, 48)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
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
    hl.Adornee = model
    hl.FillTransparency = 0.5
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = model

    crateObjects[model] = {
        bb = bb, nameLbl = nameLbl, stateLbl = stateLbl,
        distLbl = distLbl, highlight = hl,
    }
end

