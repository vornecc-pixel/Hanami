-- ==================================================================
-- Hanami / 12_esp_players.lua — Player ESP objects, box, health bar
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- PLAYER ESP
-- ────────────────────────────────────────────────────────────────────

local espObjects = {}

local function removeDrawing(d)
    if (typeof(d) == "userdata" or type(d) == "table") and d.Remove then
        pcall(d.Remove, d)
    end
end

local function clearESP(plr)
    local o = espObjects[plr]
    if not o then return end
    if o.lines then for _, d in pairs(o.lines) do removeDrawing(d) end end
    if SA.DisposeEspFx then SA.DisposeEspFx(o) end
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
    bb.Size = UDim2.fromOffset(220, 56)
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

    -- weapon / state / VIS-WALL line (filled by 13_esp_players_refresh)
    local infoLbl = Instance.new("TextLabel")
    infoLbl.Size = UDim2.new(1, 0, 0, 12)
    infoLbl.Position = UDim2.new(0, 0, 0, 28)
    infoLbl.BackgroundTransparency = 1
    infoLbl.Font = Enum.Font.GothamMedium
    infoLbl.TextSize = 10
    infoLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
    infoLbl.TextStrokeTransparency = 0
    infoLbl.Visible = false
    infoLbl.Parent = bb

    local hl = Instance.new("Highlight")
    hl.Adornee = char
    hl.FillTransparency = 0.3
    hl.OutlineTransparency = 1
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = char

    local lines = {
        top = SA.NewDraw("Line"), bottom = SA.NewDraw("Line"),
        left = SA.NewDraw("Line"), right = SA.NewDraw("Line"),
        hpBg = SA.NewDraw("Line"), hpFill = SA.NewDraw("Line"),
    }
    for _, l in pairs(lines) do l.Thickness = 1; l.Visible = false end
    lines.hpBg.Thickness = 2; lines.hpFill.Thickness = 2

    espObjects[plr] = {
        bb = bb, nameLbl = nameLbl, distLbl = distLbl, infoLbl = infoLbl,
        highlight = hl, lines = lines,
    }
end
