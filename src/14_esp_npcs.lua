-- ==================================================================
-- Hanami / 14_esp_npcs.lua — NPC ESP objects + enable/disable
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- NPC ESP (Guard / Scavenger / Soldier)
-- ────────────────────────────────────────────────────────────────────

local npcObjects = {}

local function clearNpc(model)
    local o = npcObjects[model]
    if not o then return end
    if o.lines then for _, d in pairs(o.lines) do removeDrawing(d) end end
    if SA.DisposeEspFx then SA.DisposeEspFx(o) end
    if o.bb then o.bb:Destroy() end
    if o.highlight then o.highlight:Destroy() end
    npcObjects[model] = nil
end

local function buildNpc(model)
    if npcObjects[model] or not model or not model.Parent then return end
    if not model:IsA("Model") then return end
    local hrp  = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head")
    local head = model:FindFirstChild("Head") or hrp
    local hum  = model:FindFirstChildOfClass("Humanoid")
    if not hrp or not head or not hum or hum.Health <= 0 then return end
    clearNpc(model)

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

    -- weapon / state / VIS-WALL line (filled by 15_esp_npcs_refresh)
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
    hl.Adornee = model
    hl.FillTransparency = 0.35
    hl.OutlineTransparency = 1
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = model

    local lines = {
        top = SA.NewDraw("Line"), bottom = SA.NewDraw("Line"),
        left = SA.NewDraw("Line"), right = SA.NewDraw("Line"),
        hpBg = SA.NewDraw("Line"), hpFill = SA.NewDraw("Line"),
    }
    for _, l in pairs(lines) do l.Thickness = 1; l.Visible = false end
    lines.hpBg.Thickness = 2; lines.hpFill.Thickness = 2

    npcObjects[model] = {
        bb = bb, nameLbl = nameLbl, distLbl = distLbl, infoLbl = infoLbl,
        highlight = hl, lines = lines,
    }
end

local function enableNpcESP()
    CFG.npcEspEnabled = true
    SA.RequestScan()   -- render loop builds NPCs incrementally
end

local function disableNpcESP()
    CFG.npcEspEnabled = false
    local snap = {}
    for m in pairs(npcObjects) do table.insert(snap, m) end
    for _, m in ipairs(snap) do clearNpc(m) end
end

Workspace.DescendantAdded:Connect(function(d)
    if CFG.npcEspEnabled and d:IsA("Model") and isNpc(d) then
        task.wait(0.1)
        if d.Parent then buildNpc(d) end
    end
end)
Workspace.DescendantRemoving:Connect(function(d)
    if npcObjects[d] then clearNpc(d) end
end)
