-- ==================================================================
-- Hanami / 07_esp_players.lua — Player ESP objects, box, health bar
-- Loaded in order by loader.lua. Parts are joined into ONE chunk
-- before running, so every `local` is shared just like the original.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- PLAYER ESP
-- ────────────────────────────────────────────────────────────────────

local espObjects = {}

local function clearESP(plr)
    local o = espObjects[plr]
    if not o then return end
    for _, d in pairs(o) do
        if typeof(d) == "userdata" and d.Remove then pcall(d.Remove, d) end
    end
    if o.bb then o.bb:Destroy() end
    if o.highlight then o.highlight:Destroy() end
    espObjects[plr] = nil
end

local function buildESP(plr)
    if plr == lp then return end
    local char = plr.Character
    if not char then return end
    local hrp  = char:FindFirstChild("HumanoidRootPart")
    local head = char:FindFirstChild("Head")
    local hum  = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not head or not hum or hum.Health <= 0 then return end
    clearESP(plr)

    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.fromOffset(200, 40)
    bb.StudsOffset = Vector3.new(0, 2.5, 0)
    bb.AlwaysOnTop = true
    bb.Parent = head

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(1, 0, 0, 14)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 11
    nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLbl.TextStrokeTransparency = 0
    nameLbl.Parent = bb

    local distLbl = Instance.new("TextLabel")
    distLbl.Size = UDim2.new(1, 0, 0, 12)
    distLbl.Position = UDim2.new(0, 0, 0, 14)
    distLbl.BackgroundTransparency = 1
    distLbl.Font = Enum.Font.GothamMedium
    distLbl.TextSize = 11
    distLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
    distLbl.TextStrokeTransparency = 0
    distLbl.Parent = bb

    local hl = Instance.new("Highlight")
    hl.Adornee = char
    hl.FillTransparency = 0.3
    hl.OutlineTransparency = 1
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = char

    local lines = {
        top = Drawing.new("Line"), bottom = Drawing.new("Line"),
        left = Drawing.new("Line"), right = Drawing.new("Line"),
        hpBg = Drawing.new("Line"), hpFill = Drawing.new("Line"),
    }
    for _, l in pairs(lines) do l.Thickness = 1; l.Visible = false end
    lines.hpBg.Thickness = 2; lines.hpFill.Thickness = 2

    espObjects[plr] = {
        bb = bb, nameLbl = nameLbl, distLbl = distLbl,
        highlight = hl, lines = lines,
    }
end

