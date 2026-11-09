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
    -- A standalone panel is created only when Atlanta has no
    -- window.esp_section; destroy it too so re-executes never stack.
    if pv.ownGui then pcall(function() pv.ownGui:Destroy() end) end
    pv.renderConn, pv.root, pv.camera, pv.clone = nil, nil, nil, nil
    pv.parts, pv.ui, pv.model, pv.ownGui = nil, nil, nil, nil
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

local function pvLabel(parent, name, size, pos, anchor, align, valign)
    local l = Instance.new("TextLabel")
    l.Name = name
    l.BackgroundTransparency = 1
    l.BorderSizePixel = 0
    SA.ApplyEspFont(l)
    l.TextSize = 11
    l.TextStrokeTransparency = 0
    l.TextXAlignment = align or Enum.TextXAlignment.Center
    l.TextYAlignment = valign or Enum.TextYAlignment.Center
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

local function pvStroke(parent)
    local s = nil
    pcall(function()
        s = Instance.new("UIStroke")
        s.LineJoinMode = Enum.LineJoinMode.Miter
        s.Thickness = 1
        s.Parent = parent
    end)
    return s
end

-- Rounded dark badge behind the weapon / corner tags, matching the
-- `espTagBackdrop` pill that SA.NewDraw("Text") draws in the real ESP.
local function pvBadge(lbl)
    pcall(function()
        lbl.BackgroundColor3 = c3(10, 12, 16)
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0.3, 0)
        c.Parent = lbl
    end)
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

    -- Visibility frame: the padded green/red outline drawEntity() draws
    -- around the box when the visibility check is on.
    ui.visFrame = pvFrame(holder, "VisFrame",
        UDim2new(1, 6, 1, 6), UDim2new(0, -3, 0, -3))
    ui.visFrameStroke = pvStroke(ui.visFrame)

    -- Mirror the in-world layout: name above, distance at the top-left
    -- corner, weapon BELOW the box, VIS/WALL + state + HP beside the
    -- corner. One label PER tag, so WALL can be green/red while the
    -- state / HP tags use the scanner colour (exactly like drawEntity).
    ui.name = pvLabel(holder, "Name", UDim2new(1, 0, 0, 14),
        UDim2new(0, 0, 0, -4), vec2(0, 1))
    ui.dist = pvLabel(holder, "Distance", UDim2new(0, 90, 0, 14),
        UDim2new(0, -7, 0, 0), vec2(1, 0), Enum.TextXAlignment.Right)
    ui.weapon = pvLabel(holder, "Weapon", UDim2new(1, 0, 0, 14),
        UDim2new(0, 0, 1, 5), vec2(0, 0))
    pvBadge(ui.weapon)
    ui.tags = {}
    for i = 1, 3 do
        local lbl = pvLabel(holder, "Tag" .. i, UDim2new(0, 120, 0, 14),
            UDim2new(1, 7, 0, (i - 1) * 14), vec2(0, 0),
            Enum.TextXAlignment.Left, Enum.TextYAlignment.Center)
        pvBadge(lbl)
        ui.tags[i] = lbl
    end

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
    -- Off-screen arrow (a rotated diamond, like the GUI Triangle fallback)
    ui.arrow = pvSolid(viewport, "OffscreenArrow", UDim2new(0, 12, 0, 12),
        UDim2new(0.9, 0, 0.12, 0), vec2(0.5, 0.5), c3(255, 200, 60))
    ui.arrow.Rotation = 45
    return ui
end

-- Live styling: the SAME picker the in-world ESP uses, so this really is
-- a preview of the current settings rather than a static screenshot.
-- `CFG.espPreviewKind` switches the WHOLE pipeline between the Player and
-- the NPC ESP (flags, palette, archetype colours and sample text), so the
-- best features of BOTH sections are previewable with live CFG values.
local function pvApplyStyle()
    local ui = pv.ui
    if not ui then return end

    local seed = tick() * 0.11
    local isNpc = CFG.espPreviewKind == "NPC"
    local pal = isNpc and "npc" or "player"
    local function flag(npcKey, playerKey)
        if isNpc then return CFG[npcKey] end
        return CFG[playerKey]
    end
    local visCheck   = flag("npcVisibleCheck", "espVisibleCheck") == true
    local showName   = flag("npcShowName", "espShowName") == true
    local showDist   = flag("npcShowDist", "espShowDist") == true
    local showTool   = flag("npcShowTool", "espShowTool") == true
    local showState  = flag("npcShowState", "espShowState") == true
    local showHealth = flag("npcShowHealth", "espShowHealth") == true
    local maxDist    = tonumber(flag("npcMaxDist", "espMaxDist")) or 2000

    -- Alternate VIS / WALL every 2.5 s to demonstrate both colours.
    local simulatedVisible = (math.floor(tick() / 2.5) % 2) == 0
    local base = espC(pal .. "Flat")
    if visCheck then base = espC(pal .. (simulatedVisible and "Visible" or "Hidden")) end

    -- NPC Type Colours: rotate Guard / Scavenger / Soldier every 3 s so
    -- all three archetype pickers show up in the preview.
    local typeColor, archetype = nil, "Guard"
    if isNpc and CFG.npcUseTypeColors == true then
        local archetypes = { "Guard", "Scavenger", "Soldier" }
        archetype = archetypes[(math.floor(tick() / 3) % 3) + 1]
        typeColor = espC("npc" .. archetype)
    end

    local function col(suffix) return pick(pal .. suffix, base, seed) end

    local boxCol, fillCol, outlineCol = col("Box"), col("Fill"), col("Outline")
    if typeColor and not CFG.espRainbow then
        boxCol, fillCol, outlineCol = typeColor, typeColor, typeColor
    end
    if CFG.espPreviewTarget == true and CFG.espHighlightTarget == true then
        boxCol, fillCol, outlineCol = espC("target"), espC("target"), espC("target")
    end

    local thick    = math.max(tonumber(CFG.espBoxThickness) or 1, 1)
    local ts       = math.clamp(tonumber(CFG.espTextSize) or 11, 6, 30)
    local rowH     = math.floor(ts + 3)   -- EXACTLY drawEntity()'s spacing
    local outlineOn = CFG.espTextOutline == true and 0 or 1
    -- Simulate a target at 85% of Max Distance when Distance Fade is ON.
    local fade      = CFG.espFade and fadeAmount(maxDist * 0.85, maxDist) or 0
    local textAlpha = math.clamp(fade, 0, 0.9)
    local badgeT    = CFG.espTagBackdrop == true and math.clamp(0.45 + fade, 0, 1) or 1

    pcall(function()
        if ui.boxStroke then
            ui.boxStroke.Color = boxCol
            ui.boxStroke.Thickness = thick
            ui.boxStroke.Transparency = fade
        end
        if ui.outlineStroke then
            ui.outlineStroke.Color = outlineCol
            -- Thickness 0 works on every Roblox build (UIStroke.Enabled
            -- is newer); it hides the second outline when disabled.
            ui.outlineStroke.Thickness = CFG.espShowOutline == true
                and math.max(thick - 1, 1) or 0
            ui.outlineStroke.Transparency = fade
        end
        if ui.visFrameStroke then
            ui.visFrameStroke.Color = base
            ui.visFrameStroke.Thickness = thick
            ui.visFrameStroke.Transparency = fade
        end
        ui.box.Visible = CFG.espShowBox == true and CFG.espCornerBox ~= true
        ui.cornersFrame.Visible = CFG.espShowBox == true and CFG.espCornerBox == true
        ui.visFrame.Visible = CFG.espShowBox == true and visCheck
        for _, c in ipairs(ui.corners) do
            c.BackgroundColor3 = boxCol
            c.BackgroundTransparency = fade
        end
    end)

    local display = lp.Name
    pcall(function() display = lp.DisplayName or lp.Name end)
    ui.name.Text = isNpc and ("[NPC] " .. archetype)
        or string.format("%s (@%s)", tostring(display), tostring(lp.Name))
    ui.name.Visible = showName
    ui.name.TextColor3 = (typeColor and not CFG.espRainbow) and typeColor or col("Name")
    ui.name.TextSize = ts
    ui.name.Size = UDim2new(1, 0, 0, rowH)
    ui.name.TextStrokeTransparency = outlineOn
    ui.name.TextTransparency = textAlpha

    ui.dist.Text = string.format("%dm", math.floor(maxDist / 20))
    ui.dist.Visible = showDist
    ui.dist.TextColor3 = col("Distance")
    ui.dist.TextSize = ts
    ui.dist.Size = UDim2new(0, 90, 0, rowH)
    ui.dist.TextStrokeTransparency = outlineOn
    ui.dist.TextTransparency = textAlpha

    local ratio = math.clamp(0.55 + 0.4 * math.sin(tick() * 1.3), 0.05, 1)

    -- WEAPON AT THE BOTTOM (the in-world ESP does exactly this)
    local tool = "?"
    if isNpc then
        tool = "Guard Rifle"
    else
        pcall(function() tool = SA.GetTool(lp.Character) end)
    end
    ui.weapon.Text = "[ " .. tostring(tool) .. " ]"
    ui.weapon.Visible = showTool
    ui.weapon.TextColor3 = col("Info")
    ui.weapon.TextSize = ts
    ui.weapon.Size = UDim2new(1, 0, 0, rowH)
    ui.weapon.Position = UDim2new(0, 0, 1, 4)
    ui.weapon.TextStrokeTransparency = outlineOn
    ui.weapon.TextTransparency = textAlpha
    pcall(function() ui.weapon.BackgroundTransparency = badgeT end)

    -- One label PER tag, so WALL keeps the green/red visibility colour
    -- while state / HP use the scanner colour (matches drawEntity).
    local stateText = "?"
    if isNpc then
        stateText = "Patrolling"
    else
        pcall(function() stateText = SA.GetState(lp.Character, nil) end)
    end
    local tagLines = {}
    if visCheck then
        tagLines[#tagLines + 1] = {
            text = simulatedVisible and "VIS" or "WALL", color = base }
    end
    if showState then
        tagLines[#tagLines + 1] = {
            text = "S: " .. tostring(stateText),
            color = (typeColor and not CFG.espRainbow) and typeColor or col("Info"),
        }
    end
    if CFG.espShowHealthText == true then
        tagLines[#tagLines + 1] = {
            text = "HP: " .. math.floor(ratio * 100) .. "%", color = col("Info") }
    end
    local side = CFG.espTagSide ~= false
    for i, lbl in ipairs(ui.tags) do
        local tag = tagLines[i]
        lbl.Visible = tag ~= nil
        if tag then
            lbl.Text = tag.text
            lbl.TextColor3 = tag.color
            lbl.TextSize = ts
            lbl.TextStrokeTransparency = outlineOn
            lbl.TextTransparency = textAlpha
            pcall(function() lbl.BackgroundTransparency = badgeT end)
            if side then
                lbl.AnchorPoint = vec2(0, 0)
                lbl.Position = UDim2new(1, 7, 0, (i - 1) * rowH)
                lbl.Size = UDim2new(0, 120, 0, rowH)
                lbl.TextXAlignment = Enum.TextXAlignment.Left
            else
                lbl.AnchorPoint = vec2(0.5, 0)
                lbl.Position = UDim2new(0.5, 0, 1, 4 + rowH + (i - 1) * rowH)
                lbl.Size = UDim2new(1, 0, 0, rowH)
                lbl.TextXAlignment = Enum.TextXAlignment.Center
            end
        end
    end

    ui.hpBg.Visible = showHealth
    ui.hpFill.Size = UDim2new(1, -2, ratio, -2)
    ui.hpFill.Position = UDim2new(0, 1, 1 - ratio, 1)
    ui.hpFill.BackgroundColor3 = col("HealthLow"):Lerp(col("HealthHigh"), ratio)
    pcall(function()
        ui.hpBg.BackgroundTransparency = fade
        ui.hpFill.BackgroundTransparency = fade
    end)

    ui.visDot.Visible = CFG.espShowBox == true and visCheck
    ui.visDot.BackgroundColor3 = visCheck and base or espC("playerVisDot")
    pcall(function() ui.visDot.BackgroundTransparency = fade end)

    ui.headDot.Visible = CFG.espShowHeadDot == true
    ui.headDot.BackgroundColor3 = col("HeadDot")
    pcall(function() ui.headDot.BackgroundTransparency = fade end)

    for _, l in ipairs(ui.skeleton) do
        l.Visible = CFG.espShowSkeleton == true
        l.BackgroundColor3 = col("Skeleton")
        pcall(function() l.BackgroundTransparency = fade end)
    end

    ui.tracer.Visible = CFG.espShowTracer == true
    ui.tracer.BackgroundColor3 = col("Tracer")
    ui.tracer.Position = UDim2new(CFG.espTracerOrigin == "Mouse" and 0.32 or 0.5, 0, 1, 0)
    pcall(function() ui.tracer.BackgroundTransparency = fade end)

    ui.arrow.Visible = CFG.espShowOffscreen == true
    ui.arrow.BackgroundColor3 = col("Offscreen")
    pcall(function() ui.arrow.BackgroundTransparency = fade end)

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
