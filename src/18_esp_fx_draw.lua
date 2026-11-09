-- ==================================================================
-- Hanami / 18_esp_fx_draw.lua — Unified per-entity styling (players / NPCs / crates)
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- Generic per-entity styling
-- ────────────────────────────────────────────────────────────────────
local function drawEntity(cam, o, opt)
    hideFx(o)
    if not opt.enabled or not o.bb or not o.bb.Enabled then return end

    local p         = opt.pal
    local base      = opt.base
    local seed      = opt.seed
    local t         = fadeAmount(opt.dist, opt.maxDist)
    local thick     = math.max(CFG.espBoxThickness or 1, 1)
    local isTarget  = opt.target and CFG.espHighlightTarget
    local g         = opt.geom

    -- CLEAN ESP: the screenshot-style dark pills / filled chams covered
    -- the whole top of the screen. When clean mode is ON (default), force
    -- thin outlines + text stroke and ignore the busy saved values. The
    -- user can disable this one toggle in ESP -> ESP Features to restore
    -- every individual widget's own setting.
    local cleanEsp   = CFG.espCleanMode ~= false
    local backdrop   = (not cleanEsp) and CFG.espTagBackdrop == true
    local showBox    = cleanEsp or CFG.espShowBox == true
    local cornerBox  = (not cleanEsp) and CFG.espCornerBox == true
    local showFill   = (not cleanEsp) and CFG.espShowFill == true
    local showOutline= cleanEsp or CFG.espShowOutline == true
    local textOutline= cleanEsp or CFG.espTextOutline == true

    -- crates only define a few palette keys; fall back to the shared
    -- player<Element> picker so skeleton / head dot / health aren't white
    local function col(suffix)
        local key = p .. suffix
        if ESP_COLORS[key] == nil then key = "player" .. suffix end
        return pick(key, base, seed)
    end

    local boxCol, fillCol, outlineCol = col("Box"), col("Fill"), col("Outline")
    if opt.typeColor and not CFG.espRainbow then
        boxCol, fillCol, outlineCol = opt.typeColor, opt.typeColor, opt.typeColor
    end
    if isTarget then
        boxCol, fillCol, outlineCol = espC("target"), espC("target"), espC("target")
    end

    -- ── SCREEN-SPACE TAHOMA TEXT ─────────────────────────────────────
    -- The old build stacked name / distance / "W: ... | S: ... | WALL"
    -- in a BillboardGui above the head, so the weapon could only ever be
    -- at the top. Every label is now a TextLabel in the shared ScreenGui
    -- overlay, anchored to the box geometry:
    --     name     -> centred ABOVE the box
    --     distance -> just LEFT of the top-left corner
    --     weapon   -> centred BELOW the box   (the requested layout)
    --     VIS/WALL, state, HP -> stacked RIGHT of the top-right corner
    -- The world-anchored labels stay as the fallback data source and are
    -- hidden, so nothing is rendered twice.
    local ts      = math.clamp(CFG.espTextSize or 11, 6, 30)
    local rowH    = math.floor(ts + 3)
    local outline = textOutline
    local tx      = o.tx or {}

    -- Read label visibility BEFORE hiding them: the refreshes rewrite
    -- those flags every frame, so a hidden label still has fresh text.
    if not o.tx then
        if o.nameLbl and o.nameLbl.Visible then tx.name = o.nameLbl.Text end
        if o.distLbl and o.distLbl.Visible then tx.dist = o.distLbl.Text end
        if o.stateLbl and o.stateLbl.Visible then
            tx.tags = { { text = o.stateLbl.Text, kind = "state" } }
        elseif o.infoLbl and o.infoLbl.Visible then
            tx.tags = { { text = o.infoLbl.Text, kind = "info" } }
        end
    end
    for _, lbl in ipairs({ o.nameLbl, o.distLbl, o.infoLbl, o.stateLbl }) do
        if lbl then lbl.Visible = false end
    end
    if o.bb then
        o.bb.Size = UDim2.fromOffset(220, 1)
        o.bb.StudsOffset = Vector3.new(0, 0, 0)
    end

    -- ONE text-size slider still controls every ESP label (players, NPCs,
    -- crates, side tags and the weapon badge); rowH keeps them apart.
    local function textWidth(s)
        return math.max(46, #tostring(s) * ts * 0.62 + 14)
    end
    local function showText(key, text, x, y, w, h, anchor, align, size, color, backdrop)
        if not text or text == "" or not g.onScreen then return end
        local d = getDraw(o, key, "Text")
        if not d then return end
        d.Text = tostring(text)
        d.Color = color
        d.Transparency = t
        d.TextSize = size
        d.Size = Vector2.new(w, h)
        d.Position = Vector2.new(x, y)
        d.Anchor = anchor
        d.Align = align
        d.Outline = outline
        d.Backdrop = backdrop == true
        d.ZIndex = 3
        d.Visible = true
    end

    -- Screen-space text must honour the SAME palette overrides the old
    -- BillboardGui labels did: crates keep their kind colour on the name,
    -- and NPC archetype colours paint the name + state tag. Request 16's
    -- text rewrite accidentally dropped both (col("Name") always fell
    -- back to the plain playerName picker).
    local nameCol = col("Name")
    if opt.keepNameColor then
        nameCol = opt.base
    elseif opt.typeColor and not CFG.espRainbow then
        nameCol = opt.typeColor
    end

    local cx = g.x + g.w / 2
    showText("txName", tx.name, cx, g.y - 4,
        textWidth(tx.name or ""), rowH + 2,
        Vector2.new(0.5, 1), "Center", ts + 1, nameCol, false)
    showText("txDist", tx.dist, g.x - 7, g.y,
        textWidth(tx.dist or ""), rowH,
        Vector2.new(1, 0), "Right", math.max(ts - 2, 6), col("Distance"), false)
    showText("txWeapon", tx.weapon and ("[ " .. tx.weapon .. " ]") or nil,
        cx, g.y + g.h + 4, textWidth(tx.weapon or "") + 16, rowH,
        Vector2.new(0.5, 0), "Center", ts, col("Info"), backdrop)

    local tags = tx.tags or {}
    for i, tag in ipairs(tags) do
        local tagColor = col("Info")
        if opt.pal == "crate" and tag.kind == "state" then
            tagColor = opt.opened and espC("crateOpened") or espC("crateState")
        elseif tag.kind == "vis" then
            -- WALL / VIS is ALWAYS the dynamic green/red visibility pick
            tagColor = opt.checkVisible and opt.visColor or col("Info")
        elseif tag.kind == "state" and opt.typeColor and not CFG.espRainbow then
            tagColor = opt.typeColor
        end
        local side = CFG.espTagSide ~= false
        showText("txTag" .. i, tag.text,
            side and (g.x + g.w + 7) or cx,
            side and (g.y + (i - 1) * rowH)
                or (g.y + g.h + 4 + rowH + (i - 1) * rowH),
            textWidth(tag.text), rowH,
            side and Vector2.new(0, 0) or Vector2.new(0.5, 0),
            side and "Left" or "Center", ts, tagColor,
            backdrop)
    end

    -- chams
    if o.highlight then
        o.highlight.FillColor = fillCol
        o.highlight.OutlineColor = outlineCol
        o.highlight.FillTransparency = showFill and math.clamp(0.7 + t, 0, 1) or 1
        o.highlight.OutlineTransparency = showOutline and math.clamp(t, 0, 1) or 1
    end

    -- box: reuse the 4 prebuilt lines for full boxes, lazily create the
    -- 8 corner segments (or a crate's own 4 lines) when needed
    local prebuilt = o.lines and { "top", "bottom", "left", "right" } or nil
    if showBox and g.onScreen then
        if prebuilt and not cornerBox then
            for _, k in ipairs(prebuilt) do
                local l = o.lines[k]
                l.Color = boxCol; l.Transparency = t; l.Thickness = thick
            end
        else
            if prebuilt then for _, k in ipairs(prebuilt) do o.lines[k].Visible = false end end
            for i, s in ipairs(boxSegments(g, cornerBox)) do
                local l = getDraw(o, "box" .. i, "Line")
                if l then
                    l.From = Vector2.new(s[1], s[2]); l.To = Vector2.new(s[3], s[4])
                    l.Color = boxCol; l.Transparency = t; l.Thickness = thick
                    l.Visible = true
                end
            end
        end
    elseif prebuilt then
        for _, k in ipairs(prebuilt) do o.lines[k].Visible = false end
    end

    -- visibility frame: a larger outline painted with the user's
    -- green/red pick. This keeps the visible-check colours unmistakable
    -- even when every element is using its own per-element colour.
    if opt.checkVisible and showBox and g.onScreen then
        local pad = 3
        local frame = boxSegments({ x = g.x - pad, y = g.y - pad,
                                    w = g.w + pad * 2, h = g.h + pad * 2 }, false)
        for i, s in ipairs(frame) do
            local l = getDraw(o, "visframe" .. i, "Line")
            if l then
                l.From = Vector2.new(s[1], s[2]); l.To = Vector2.new(s[3], s[4])
                l.Color = opt.visColor; l.Transparency = t
                l.Thickness = thick; l.Visible = true
            end
        end
    end

    -- health bar gradient (high / low colours are both pickable)
    if o.lines and CFG.espShowHealth and g.onScreen then
        local hi, lo = espC(p .. "HealthHigh"), espC(p .. "HealthLow")
        o.lines.hpBg.Color = Color3.fromRGB(20, 20, 20)
        o.lines.hpBg.Transparency = t
        o.lines.hpFill.Color = CFG.espRainbow and rainbowColor(seed)
            or lo:Lerp(hi, math.clamp(opt.ratio or 1, 0, 1))
        o.lines.hpFill.Transparency = t
    end

    -- small dot beside the box: ALWAYS shows the visibility colour even in
    -- per-element mode, so the user's green/red pick never disappears
    if g.onScreen and showBox then
        local d = getDraw(o, "visdot", "Circle")
        if d then
            d.Position = Vector2.new(g.x - 6, g.y - 6); d.Radius = 3
            d.Color = opt.visColor; d.Transparency = t; d.Visible = true
        end
    end

    -- bones + head dot — now ALSO work on crates (a spine + a top marker
    -- instead of limbs), so these features are visible with only Crate ESP on
    if CFG.espShowSkeleton or CFG.espShowHeadDot then
        if CFG.espShowSkeleton then
            if opt.model then
                for i, bone in ipairs(SKELETON) do
                    local a, b = findPart(opt.model, bone[1]), findPart(opt.model, bone[2])
                    local l = (a and b) and getDraw(o, "sk" .. i, "Line") or nil
                    if l then
                        local va, oka = cam:WorldToViewportPoint(a.Position)
                        local vb, okb = cam:WorldToViewportPoint(b.Position)
                        if oka and okb and va.Z > 0 and vb.Z > 0 then
                            l.From = Vector2.new(va.X, va.Y); l.To = Vector2.new(vb.X, vb.Y)
                            l.Color = col("Skeleton"); l.Transparency = t
                            l.Thickness = thick; l.Visible = true
                        end
                    end
                end
            elseif g.onScreen then
                local cx = g.x + g.w / 2
                local segs = {
                    { Vector2.new(cx, g.y), Vector2.new(cx, g.y + g.h) },
                    { Vector2.new(g.x, g.y + g.h / 2), Vector2.new(g.x + g.w, g.y + g.h / 2) },
                }
                for i, s in ipairs(segs) do
                    local l = getDraw(o, "csk" .. i, "Line")
                    if l then
                        l.From, l.To = s[1], s[2]
                        l.Color = col("Skeleton"); l.Transparency = t
                        l.Thickness = thick; l.Visible = true
                    end
                end
            end
        end
        if CFG.espShowHeadDot then
            local hx, hy = nil, nil
            if opt.model then
                local h = findPart(opt.model, { "Head" })
                if h then
                    local v, ok = cam:WorldToViewportPoint(h.Position)
                    if ok and v.Z > 0 then hx, hy = v.X, v.Y end
                end
            elseif g.onScreen then
                hx, hy = g.x + g.w / 2, g.y
            end
            if hx then
                local d = getDraw(o, "headdot", "Circle")
                if d then
                    d.Position = Vector2.new(hx, hy); d.Radius = 4
                    d.Color = col("HeadDot"); d.Transparency = t; d.Visible = true
                end
            end
        end
    end

    -- tracer + off-screen arrow
    -- With "Arrows Follow FOV" the arrow sits ON the FOV circle perimeter
    -- (radius = SA.FovRadius(), centre = SA.AimPoint() — both shared with the circle),
    -- and it is also shown for targets that are on-screen but outside the
    -- aim cone. Change the FOV radius and the arrows move with it.
    local px, onScr = screenPoint(cam, g.raw, g.ok)
    local fovC = opt.fovCenter or Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
    local fovR = math.max(opt.fovRadius or 150, 20)
    local dir = px - fovC
    if dir.Magnitude < 0.001 then dir = Vector2.new(0, 1) end
    local outsideFov = dir.Magnitude > fovR

    -- Tracer lines + off-screen arrows are PLAYER-ONLY. NPC and crate
    -- entities never create these drawings, so turning the toggles ON
    -- cannot clutter the world with extra lines/arrows.
    local playerOnly = (p == "player")
    if CFG.espShowTracer and playerOnly then
        local l = getDraw(o, "tracer", "Line")
        if l then
            l.From = opt.origin
            l.To = (CFG.espArrowFOV and not onScr) and (fovC + dir.Unit * fovR) or px
            l.Color = col("Tracer"); l.Transparency = t
            l.Thickness = thick; l.Visible = true
        end
    end

    if CFG.espShowOffscreen and playerOnly
        and (not onScr or (CFG.espArrowFOV and outsideFov)) then
        local tri = getDraw(o, "arrow", "Triangle")
        if tri then
            pcall(function()
                local anchorAt = CFG.espArrowFOV and (fovC + dir.Unit * fovR) or px
                local a = SA.Atan2(dir.Y, dir.X)
                local r = math.clamp(fovR * 0.035, 7, 16)  -- scales with the FOV
                tri.PointA = anchorAt + Vector2.new(math.cos(a), math.sin(a)) * r
                tri.PointB = anchorAt + Vector2.new(math.cos(a + 2.4), math.sin(a + 2.4)) * r
                tri.PointC = anchorAt + Vector2.new(math.cos(a - 2.4), math.sin(a - 2.4)) * r
                tri.Color = col("Offscreen"); tri.Transparency = t; tri.Visible = true
            end)
        end
    end
end
