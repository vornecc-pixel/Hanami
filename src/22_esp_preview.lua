-- ==================================================================
-- Hanami / 22_esp_preview.lua — ESP Preview panel (Atlanta window.esp_section)
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- ESP PREVIEW — populate Atlanta's floating "ESP Preview" panel
--
-- library:window() ALREADY creates a draggable 300x325 panel and exposes
-- it as window.esp_section; Hanami simply never put anything in it, so
-- the panel looked broken/empty. The template's
-- `window.esp_section:esp_preview({})` cannot be used as-is:
--   * it reads ~13 template flags (Name_Color, Box_Color, Health_Low,
--     Enabled, Box_Type ...) that Hanami never registers, so it errors
--     immediately on `flags["Name_Color"].Color`;
--   * it assumes lp.Character exists, blindly destroys a mandatory
--     "Animate" script and calls SetPrimaryPartCFrame on a model that
--     may have no PrimaryPart -> errors on spawn / respawn;
--   * its Camera is parented to Workspace, and it leaks an infinite
--     `while true do task.wait() end` loop on every re-execute;
--   * its colours have nothing to do with Hanami's ESP_COLORS.
--
-- This replacement is self-contained and pcall-guarded. Every overlay is
-- driven live by CFG + ESP_COLORS through the same pick() helper the real
-- ESP uses, so the panel genuinely previews box / corner boxes / name /
-- distance / weapon / state / health bar / VIS-WALL / skeleton / head dot
-- / tracer / chams tint / rainbow / text size / outline.
-- ────────────────────────────────────────────────────────────────────

local pv = _G.__saEspPreview or {}
_G.__saEspPreview = pv

local function pvTeardown()
    if pv.renderConn then pcall(function() pv.renderConn:Disconnect() end) end
    if pv.root then pcall(function() pv.root:Destroy() end) end
    pv.renderConn, pv.root, pv.camera, pv.clone = nil, nil, nil, nil
    pv.parts, pv.ui, pv.model = nil, nil, nil
    pv.styleErr, pv.styleWarned, pv.lastStyle = nil, nil, nil
end

-- Re-execution: remove the old run's viewport, render loop AND its
-- floating panel, otherwise a second empty "ESP Preview" window piles up.
local pvOldSgui = pv.sgui
pv.sgui = nil
pvTeardown()
if pvOldSgui then pcall(function() pvOldSgui:Destroy() end) end
if _G.__saEspPreviewCharConn then
    pcall(function() _G.__saEspPreviewCharConn:Disconnect() end)
end

local UDim2new = UDim2.new
local vec2 = Vector2.new
local c3 = Color3.fromRGB

local function pvFrame(parent, name, size, pos, anchor)
    local f = Instance.new("Frame")
    f.Name = name
    f.BackgroundTransparency = 1
    f.BorderSizePixel = 0
    f.Size = size
    f.Position = pos
    if anchor then f.AnchorPoint = anchor end
    f.Parent = parent
    return f
end

local function pvSolid(parent, name, size, pos, anchor, col)
    local f = pvFrame(parent, name, size, pos, anchor)
    f.BackgroundTransparency = 0
    f.BackgroundColor3 = col or c3(255, 255, 255)
    return f
end

local function pvLabel(parent, name, size, pos, anchor)
    local l = Instance.new("TextLabel")
    l.Name = name
    l.BackgroundTransparency = 1
    l.BorderSizePixel = 0
    l.Font = Enum.Font.GothamBold
    l.TextSize = 11
    l.TextStrokeTransparency = 0
    l.TextXAlignment = Enum.TextXAlignment.Center
    l.Text = ""
    l.Size = size
    l.Position = pos
    if anchor then l.AnchorPoint = anchor end
    l.Parent = parent
    return l
end

local function pvDot(parent, name, pos, anchor, col)
    local d = pvSolid(parent, name, UDim2new(0, 9, 0, 9), pos, anchor, col)
    pcall(function()
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0.5, 0)
        c.Parent = d
    end)
    return d
end

-- Synthetic R6-ish rig used when the character cannot be cloned (no
-- character yet, Archivable locked, custom rig, executor restriction).
-- The preview must still show SOMETHING instead of erroring.
local function pvDummyRig()
    local m = Instance.new("Model")
    m.Name = "HanamiPreviewDummy"
    local skin = c3(205, 205, 215)
    local accent = c3(90, 110, 150)
    local function add(name, sx, sy, sz, x, y, z, col)
        local p = Instance.new("Part")
        p.Name = name
        p.Size = Vector3.new(sx, sy, sz)
        p.CFrame = CFrame.new(x, y, z)
        p.Anchored = true
        p.Material = Enum.Material.SmoothPlastic
        p.Color = col
        p.Parent = m
        return p
    end
    local hrp = add("HumanoidRootPart", 2, 2, 1, 0, 3, 0, skin)
    hrp.Transparency = 1
    add("Torso", 2, 2, 1, 0, 3, 0, accent)
    add("Head", 1, 1, 1, 0, 4.5, 0, skin)
    add("Left Arm", 1, 2, 1, -1.5, 3, 0, skin)
    add("Right Arm", 1, 2, 1, 1.5, 3, 0, skin)
    add("Left Leg", 1, 2, 1, -0.5, 1, 0, accent)
    add("Right Leg", 1, 2, 1, 0.5, 1, 0, accent)
    pcall(function() m.PrimaryPart = hrp end)
    pcall(function() Instance.new("Humanoid").Parent = m end)
    return m
end

-- Clone the local character safely. The Atlanta version assumed
-- `lp.Character.Animate` exists and would error on respawn; here every
-- step is optional and the dummy rig is the fallback.
local function pvMakeModel()
    local char = lp.Character
    local clone, why = nil, "no character"
    if char then
        -- Restore Archivable even when :Clone() itself throws, otherwise
        -- the live character is left permanently clonable.
        local prev, okPrev = nil, false
        okPrev = pcall(function() prev = char.Archivable; char.Archivable = true end)
        local okClone, cloned = pcall(function() return char:Clone() end)
        if okPrev then pcall(function() char.Archivable = prev end) end
        if okClone then clone = cloned end
        if okPrev and okClone and clone then
            why = "cloned local character"
            pcall(function()
                for _, d in ipairs(clone:GetDescendants()) do
                    if d:IsA("Script") or d:IsA("LocalScript")
                        or d:IsA("ModuleScript") or d:IsA("BillboardGui")
                        or d:IsA("SurfaceGui") or d:IsA("Highlight")
                        or d:IsA("ParticleEmitter") or d:IsA("Sound")
                        or d:IsA("ForceField") then
                        pcall(function() d:Destroy() end)
                    end
                end
            end)
            pcall(function()
                if not clone.PrimaryPart then
                    local hrp = clone:FindFirstChild("HumanoidRootPart")
                        or clone:FindFirstChild("Head")
                    if hrp and hrp:IsA("BasePart") then clone.PrimaryPart = hrp end
                end
            end)
        else
            clone, why = nil, "clone blocked; using dummy rig"
        end
    end
    if not clone then
        local okDummy, dummy = pcall(pvDummyRig)
        clone = okDummy and dummy or nil
        why = clone and why or "dummy rig unavailable"
        return clone, why, true
    end
    return clone, why, false
end

-- Both the real clone and the dummy rig use a HumanoidRootPart at y≈3,
-- so recentering the pivot on the origin puts the model in exactly the
-- same place for the orbit camera either way.
local function pvRecenter(model)
    if not model then return end
    local ok = pcall(function() model:PivotTo(CFrame.new(0, 0, 0)) end)
    if not ok then
        pcall(function() model:SetPrimaryPartCFrame(CFrame.new(0, 0, 0)) end)
    end
end

local function pvCollectParts(model)
    local list = {}
    if not model then return list end
    pcall(function()
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("BasePart") and d.Transparency < 0.9 then
                local ok, col = pcall(function() return d.Color end)
                if ok and col then list[#list + 1] = { part = d, original = col } end
            end
        end
    end)
    return list
end

local function pvBuildOverlays(viewport)
    local ui = {}
    local holder = pvFrame(viewport, "PreviewHolder",
        UDim2new(0, 120, 0, 190), UDim2new(0.5, 0, 0.5, 0), vec2(0.5, 0.5))

    ui.holder = holder
    ui.box = pvFrame(holder, "Box", UDim2new(1, -2, 1, -2), UDim2new(0, 1, 0, 1))
    pcall(function()
        ui.boxStroke = Instance.new("UIStroke")
        ui.boxStroke.LineJoinMode = Enum.LineJoinMode.Miter
        ui.boxStroke.Parent = ui.box
        ui.outlineStroke = Instance.new("UIStroke")
        ui.outlineStroke.LineJoinMode = Enum.LineJoinMode.Miter
        ui.outlineStroke.Parent = ui.box
    end)

    ui.corners = {}
    local cornerSpec = {
        { UDim2new(0, 0, 0, 0), vec2(0, 0), 18, 3 },
        { UDim2new(0, 0, 0, 0), vec2(0, 0), 3, 18 },
        { UDim2new(1, 0, 0, 0), vec2(1, 0), 18, 3 },
        { UDim2new(1, 0, 0, 0), vec2(1, 0), 3, 18 },
        { UDim2new(0, 0, 1, 0), vec2(0, 1), 18, 3 },
        { UDim2new(0, 0, 1, 0), vec2(0, 1), 3, 18 },
        { UDim2new(1, 0, 1, 0), vec2(1, 1), 18, 3 },
        { UDim2new(1, 0, 1, 0), vec2(1, 1), 3, 18 },
    }
    local cornersFrame = pvFrame(holder, "Corners", UDim2new(1, 0, 1, 0), UDim2new(0, 0, 0, 0))
    ui.cornersFrame = cornersFrame
    for i, s in ipairs(cornerSpec) do
        ui.corners[i] = pvSolid(cornersFrame, "Corner" .. i,
            UDim2new(0, s[3], 0, s[4]), s[1], s[2], c3(255, 255, 255))
    end

    ui.name = pvLabel(holder, "Name", UDim2new(1, 0, 0, 14),
        UDim2new(0, 0, 0, -5), vec2(0, 1))
    ui.dist = pvLabel(holder, "Distance", UDim2new(1, 0, 0, 14),
        UDim2new(0, 0, 1, 5), vec2(0, 0))
    ui.info = pvLabel(holder, "Info", UDim2new(1, 0, 0, 14),
        UDim2new(0, 0, 1, 20), vec2(0, 0))

    ui.hpBg = pvSolid(holder, "HpBg", UDim2new(0, 4, 1, 0),
        UDim2new(0, -5, 0, 0), vec2(1, 0), c3(20, 20, 20))
    ui.hpFill = pvSolid(ui.hpBg, "HpFill", UDim2new(1, -2, 1, -2),
        UDim2new(0, 1, 0, 1), nil, c3(60, 255, 100))

    ui.visDot = pvDot(holder, "VisDot", UDim2new(1, -4, 0, -4), vec2(1, 1), c3(60, 255, 100))
    ui.headDot = pvDot(holder, "HeadDot", UDim2new(0.5, 0, 0, 14), vec2(0.5, 0.5), c3(255, 255, 255))

    ui.skeleton = {}
    local skSpec = {
        { UDim2new(0.5, 0, 0.35, 0), 2, 70, 0 },
        { UDim2new(0.38, 0, 0.4, 0), 2, 52, -35 },
        { UDim2new(0.62, 0, 0.4, 0), 2, 52, 35 },
        { UDim2new(0.44, 0, 0.68, 0), 2, 55, 12 },
        { UDim2new(0.56, 0, 0.68, 0), 2, 55, -12 },
    }
    for i, s in ipairs(skSpec) do
        local l = pvSolid(holder, "Bone" .. i,
            UDim2new(0, s[2], 0, s[3]), s[1], vec2(0.5, 0.5), c3(120, 220, 255))
        l.Rotation = s[4]
        ui.skeleton[i] = l
    end

    ui.tracer = pvSolid(viewport, "Tracer", UDim2new(0, 2, 0, 110),
        UDim2new(0.5, 0, 1, 0), vec2(0.5, 1), c3(255, 120, 200))
    return ui
end

-- Live styling: the SAME picker the in-world ESP uses, so this really is
-- a preview of the current settings rather than a static screenshot.
local function pvApplyStyle()
    local ui = pv.ui
    if not ui then return end
    local seed = tick() * 0.11
    -- Alternate VIS / WALL every 2.5 s to demonstrate both colours.
    local simulatedVisible = (math.floor(tick() / 2.5) % 2) == 0
    local base = CFG.espVisibleCheck
        and (simulatedVisible and espC("playerVisible") or espC("playerHidden"))
        or espC("playerFlat")
    local boxCol = pick("playerBox", base, seed)
    local fillCol = pick("playerFill", base, seed)
    local outlineCol = pick("playerOutline", base, seed)
    local thick = math.max(tonumber(CFG.espBoxThickness) or 1, 1)
    local ts = math.clamp(tonumber(CFG.espTextSize) or 11, 6, 30)
    local rowH = math.floor(ts + 2)
    local outlineOn = CFG.espTextOutline == true and 0 or 1

    pcall(function()
        if ui.boxStroke then
            ui.boxStroke.Color = boxCol
            ui.boxStroke.Thickness = thick
        end
        if ui.outlineStroke then
            ui.outlineStroke.Color = outlineCol
            -- Thickness 0 works on every Roblox build (UIStroke.Enabled
            -- is newer); it hides the second outline when disabled.
            ui.outlineStroke.Thickness = CFG.espShowOutline == true
                and math.max(thick - 1, 1) or 0
        end
        ui.box.Visible = CFG.espShowBox == true and CFG.espCornerBox ~= true
        ui.cornersFrame.Visible = CFG.espShowBox == true and CFG.espCornerBox == true
        for _, c in ipairs(ui.corners) do c.BackgroundColor3 = boxCol end
    end)

    local display = lp.Name
    pcall(function() display = lp.DisplayName or lp.Name end)
    ui.name.Text = string.format("%s (@%s)", tostring(display), tostring(lp.Name))
    ui.name.Visible = CFG.espShowName == true
    ui.name.TextColor3 = pick("playerName", base, seed)
    ui.name.TextSize = ts
    ui.name.Size = UDim2new(1, 0, 0, rowH)
    ui.name.TextStrokeTransparency = outlineOn

    ui.dist.Text = string.format("[%dm]", math.floor((tonumber(CFG.espMaxDist) or 2000) / 20))
    ui.dist.Visible = CFG.espShowDist == true
    ui.dist.TextColor3 = pick("playerDistance", base, seed)
    ui.dist.TextSize = ts
    ui.dist.Size = UDim2new(1, 0, 0, rowH)
    ui.dist.TextStrokeTransparency = outlineOn

    local ratio = math.clamp(0.55 + 0.4 * math.sin(tick() * 1.3), 0.05, 1)
    local bits = {}
    if CFG.espShowTool then
        local t = "?"
        pcall(function() t = SA.GetTool(lp.Character) end)
        bits[#bits + 1] = "W: " .. tostring(t)
    end
    if CFG.espShowState then
        local s = "?"
        pcall(function() s = SA.GetState(lp.Character, nil) end)
        bits[#bits + 1] = "S: " .. tostring(s)
    end
    if CFG.espShowHealthText then bits[#bits + 1] = "HP: " .. math.floor(ratio * 100) .. "%" end
    if CFG.espVisibleCheck then bits[#bits + 1] = simulatedVisible and "VIS" or "WALL" end
    ui.info.Text = table.concat(bits, " | ")
    ui.info.Visible = #bits > 0
    ui.info.TextColor3 = CFG.espVisibleCheck and base or pick("playerInfo", base, seed)
    ui.info.TextSize = ts
    ui.info.Size = UDim2new(1, 0, 0, rowH)
    ui.info.Position = UDim2new(0, 0, 1, 5 + rowH)
    ui.info.TextStrokeTransparency = outlineOn

    ui.hpBg.Visible = CFG.espShowHealth == true
    ui.hpFill.Size = UDim2new(1, -2, ratio, -2)
    ui.hpFill.Position = UDim2new(0, 1, 1 - ratio, 1)
    ui.hpFill.BackgroundColor3 = pick("playerHealthLow", base, seed):Lerp(
        pick("playerHealthHigh", base, seed), ratio)

    ui.visDot.Visible = CFG.espVisibleCheck == true
    ui.visDot.BackgroundColor3 = CFG.espVisibleCheck and base or pick("playerVisDot", base, seed)
    ui.headDot.Visible = CFG.espShowHeadDot == true
    ui.headDot.BackgroundColor3 = pick("playerHeadDot", base, seed)
    for _, l in ipairs(ui.skeleton) do
        l.Visible = CFG.espShowSkeleton == true
        l.BackgroundColor3 = pick("playerSkeleton", base, seed)
    end
    ui.tracer.Visible = CFG.espShowTracer == true
    ui.tracer.BackgroundColor3 = pick("playerTracer", base, seed)

    -- ViewportFrames do not reliably render Highlight, so chams are
    -- previewed by tinting the model's parts with the fill colour.
    if pv.parts then
        for _, e in ipairs(pv.parts) do
            pcall(function()
                e.part.Color = CFG.espShowFill == true
                    and e.original:Lerp(fillCol, 0.55) or e.original
            end)
        end
    end
end
