-- ==================================================================
-- Hanami / 18_esp_fx_draw.lua — Unified per-entity styling (players / NPCs / crates)
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- Generic per-entity styling
--
-- FPS pass 2: the old drawEntity() created three closures and several
-- temporary segment / label tables for EVERY entity EVERY frame, then hid
-- and re-showed every draw. Helpers are now hoisted, lines are written
-- directly, and per-frame usage marks hide only unused draws. 02_drawing
-- also skips unchanged Roblox Instance / GUI-proxy property writes.
-- ────────────────────────────────────────────────────────────────────

local BOX_KEYS = { "top", "bottom", "left", "right" }

local function fxColor(p, base, seed, suffix)
    local key = p .. suffix
    if ESP_COLORS[key] == nil then key = "player" .. suffix end
    return pick(key, base, seed)
end

local function fxTextWidth(ts, text)
    return math.max(46, #tostring(text or "") * ts * 0.62 + 14)
end

local function showText(o, key, text, x, y, w, h, anchor, align, size,
                        color, backdrop, outline, t, onScreen)
    if not text or text == "" or not onScreen then return end
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

local function setFxLine(o, key, x1, y1, x2, y2, color, t, thick, legacy)
    local l
    if legacy and o.lines then
        l = o.lines[key]
        if l then
            markLegacyLine(o, key)
            if not o.instApplied then o.instApplied = {} end
            SA.ApplyInstProp(o.instApplied, l, "Visible", true)
        end
    else
        l = getDraw(o, key, "Line")
    end
    if not l then return end
    l.From = Vector2.new(x1, y1)
    l.To = Vector2.new(x2, y2)
    l.Color = color
    l.Transparency = t
    l.Thickness = thick
    l.Visible = true
end

local function hideLegacyLabels(o)
    -- Shared helper also disables the BillboardGui. The legacy labels are
    -- only read above for tx fallback; screen-space text is the one source.
    SA.HideEspBillboard(o)
end

local function drawEntityInner(cam, o, opt)
    local p         = opt.pal
    local base      = opt.base
    local seed      = opt.seed
    local t         = fadeAmount(opt.dist, opt.maxDist)
    local thick     = math.max(CFG.espBoxThickness or 1, 1)
    local isTarget  = opt.target and CFG.espHighlightTarget
    local g         = opt.geom

    -- CLEAN ESP: the screenshot-style dark pills / filled chams covered
    -- the whole top of the screen. When clean mode is explicitly ON, force
    -- thin outlines + text stroke and ignore the busy saved values.
    local cleanEsp   = CFG.espCleanMode == true
    local backdrop   = (not cleanEsp) and CFG.espTagBackdrop == true
    local cornerBox  = (not cleanEsp) and CFG.espCornerBox == true
    -- Corner boxes are a box style in their own right: do not require the
    -- separate full-box switch, which used to hide every corner segment.
    local showBox    = cleanEsp or CFG.espShowBox == true or cornerBox
    local showFill   = (not cleanEsp) and CFG.espShowFill == true
    local showOutline= cleanEsp or CFG.espShowOutline == true
    local textOutline= cleanEsp or CFG.espTextOutline == true

    -- ONE FOV reference for off-screen arrows AND the crate ESP mode.
    -- fov.point is the real projection; px is only the clamped edge pixel.
    local fov = SA.EspFovSnapshot(cam, g, opt.fovCenter, opt.fovRadius)
    local px = fov.onScreen and fov.point or fov.clamped
    local onScr = fov.onScreen
    local fovC, fovR, dir = fov.center, fov.radius, fov.dir
    local outsideFov = fov.outside
    local crateFov = p == "crate" and CFG.crateFovAware == true
    local crateInsideFov = fov.onScreen and fov.inside

    local boxCol = fxColor(p, base, seed, "Box")
    local fillCol = fxColor(p, base, seed, "Fill")
    local outlineCol = fxColor(p, base, seed, "Outline")
    if opt.typeColor and not CFG.espRainbow then
        boxCol, fillCol, outlineCol = opt.typeColor, opt.typeColor, opt.typeColor
    end
    if isTarget then
        boxCol, fillCol, outlineCol = espC("target"), espC("target"), espC("target")
    end

    local ts      = math.clamp(CFG.espTextSize or 11, 6, 30)
    local rowH    = math.floor(ts + 3)
    local outline = textOutline
    local tx = o.tx
    if not tx then
        tx = o.txFallback
        if not tx then tx = {}; o.txFallback = tx end
        if o.nameLbl and o.nameLbl.Visible then tx.name = o.nameLbl.Text end
        if o.distLbl and o.distLbl.Visible then tx.dist = o.distLbl.Text end
        if o.stateLbl and o.stateLbl.Visible then
            tx.tags = { { text = o.stateLbl.Text, kind = "state" } }
        elseif o.infoLbl and o.infoLbl.Visible then
            tx.tags = { { text = o.infoLbl.Text, kind = "info" } }
        end
    end

    -- A FOV enter/leave, viewport enter/leave or visual-toggle change must
    -- erase every pooled arrow/tracer/box before the new frame is styled.
    -- Otherwise a clamped edge draw survives while the entity is already
    -- inside the circle. Only transitions trigger this, not every frame.
    local stateKey = tostring(p) .. "|" .. tostring(fov.onScreen) .. "|"
        .. tostring(fov.inside) .. "|" .. tostring(SA.EspDrawSignature or "")
    if o.espFovState ~= stateKey then
        o.espFovState = stateKey
        SA.EspFovTransitions = (SA.EspFovTransitions or 0) + 1
        pcall(hideFx, o)
        pcall(SA.EspHideDuplicateOverlays, o, opt.model)
        startFxFrame(o)
        -- Keep the projection object for state probes, but force ONE fresh
        -- SA.EspGeom() next frame so a sliced entity cannot reuse it.
        o.geomKey = nil
        o.geomForceFresh = true
    end

    -- Read label visibility BEFORE hiding them: the refreshes rewrite
    -- those flags, so a hidden label still has fresh text.
    hideLegacyLabels(o)

    -- Most entities are behind the camera or outside the viewport. With
    -- tracers / arrows / crate FOV dots OFF there is nothing to draw.
    local playerOnly = (p == "player")
    local crateDot = crateFov and not crateInsideFov
    local offscreenVisual = (playerOnly and (CFG.espShowTracer or CFG.espShowOffscreen))
        or crateDot
    if not g.onScreen and not offscreenVisual then return end

    local nameCol = fxColor(p, base, seed, "Name")
    if opt.keepNameColor then
        nameCol = opt.base
    elseif opt.typeColor and not CFG.espRainbow then
        nameCol = opt.typeColor
    end
    local cx = g.x + g.w / 2
    local cache = o.instApplied

    -- FOV-AWARE CRATE ESP: outside the aim circle draw ONLY a dot; inside
    -- the circle draw name + distance and an outline-only Highlight.
    if crateFov then
        local counts = SA.CrateFovCount
        if not counts then
            counts = { inside = 0, outside = 0, dots = 0, highlights = 0 }
            SA.CrateFovCount = counts
        end
        if not crateInsideFov then
            counts.outside = counts.outside + 1
            local dot = getDraw(o, "cratefovdot", "Circle")
            if dot then
                dot.Position = px
                dot.Radius = 4
                dot.Color = base
                dot.Transparency = t
                dot.Visible = true
                counts.dots = counts.dots + 1
            end
            if o.highlight then
                SA.ApplyInstProp(cache, o.highlight, "Enabled", false)
            end
            return
        end
        counts.inside = counts.inside + 1
        showText(o, "txName", tx.name, cx, g.y - 4,
            fxTextWidth(ts, tx.name), rowH + 2,
            Vector2.new(0.5, 1), "Center", ts + 1, nameCol, false,
            outline, t, g.onScreen)
        showText(o, "txDist", tx.dist, cx, g.y + g.h + 4,
            fxTextWidth(ts, tx.dist), rowH,
            Vector2.new(0.5, 0), "Center", math.max(ts - 2, 6),
            fxColor(p, base, seed, "Distance"), false,
            outline, t, g.onScreen)
        if o.highlight then
            markHighlight(o)
            SA.ApplyInstProp(cache, o.highlight, "Enabled", true)
            SA.ApplyInstProp(cache, o.highlight, "FillColor", base)
            SA.ApplyInstProp(cache, o.highlight, "OutlineColor", base)
            SA.ApplyInstProp(cache, o.highlight, "FillTransparency", 1)
            SA.ApplyInstProp(cache, o.highlight, "OutlineTransparency",
                math.clamp(t, 0, 1))
            counts.highlights = counts.highlights + 1
        end
        return
    end

    showText(o, "txName", tx.name, cx, g.y - 4,
        fxTextWidth(ts, tx.name), rowH + 2,
        Vector2.new(0.5, 1), "Center", ts + 1, nameCol, false,
        outline, t, g.onScreen)
    showText(o, "txDist", tx.dist, g.x - 7, g.y,
        fxTextWidth(ts, tx.dist), rowH,
        Vector2.new(1, 0), "Right", math.max(ts - 2, 6),
        fxColor(p, base, seed, "Distance"), false,
        outline, t, g.onScreen)
    showText(o, "txWeapon", tx.weapon and ("[ " .. tx.weapon .. " ]") or nil,
        cx, g.y + g.h + 4, fxTextWidth(ts, tx.weapon) + 16, rowH,
        Vector2.new(0.5, 0), "Center", ts,
        fxColor(p, base, seed, "Info"), backdrop,
        outline, t, g.onScreen)

    local tags = tx.tags or {}
    for i, tag in ipairs(tags) do
        local tagColor = fxColor(p, base, seed, "Info")
        if p == "crate" and tag.kind == "state" then
            tagColor = opt.opened and espC("crateOpened") or espC("crateState")
        elseif tag.kind == "vis" then
            tagColor = opt.checkVisible and opt.visColor or tagColor
        elseif tag.kind == "state" and opt.typeColor and not CFG.espRainbow then
            tagColor = opt.typeColor
        end
        local side = CFG.espTagSide == true
        showText(o, "txTag" .. i, tag.text,
            side and (g.x + g.w + 7) or cx,
            side and (g.y + (i - 1) * rowH)
                or (g.y + g.h + 4 + rowH + (i - 1) * rowH),
            fxTextWidth(ts, tag.text), rowH,
            side and Vector2.new(0, 0) or Vector2.new(0.5, 0),
            side and "Left" or "Center", ts, tagColor,
            backdrop, outline, t, g.onScreen)
    end

    -- chams
    if o.highlight then
        markHighlight(o)
        SA.ApplyInstProp(cache, o.highlight, "Enabled",
            g.onScreen and (showOutline or showFill))
        SA.ApplyInstProp(cache, o.highlight, "FillColor", fillCol)
        SA.ApplyInstProp(cache, o.highlight, "OutlineColor", outlineCol)
        SA.ApplyInstProp(cache, o.highlight, "FillTransparency",
            showFill and math.clamp(0.7 + t, 0, 1) or 1)
        SA.ApplyInstProp(cache, o.highlight, "OutlineTransparency",
            showOutline and math.clamp(t, 0, 1) or 1)
    end

    -- box: direct segment writes avoid 4–8 nested temporary tables per
    -- entity per frame. Prebuilt legacy lines are marked as used; pooled
    -- fallback lines are marked by getDraw().
    if showBox and g.onScreen then
        local x, y, w, h = g.x, g.y, g.w, g.h
        if o.lines and not cornerBox then
            setFxLine(o, "top", x, y, x + w, y, boxCol, t, thick, true)
            setFxLine(o, "bottom", x, y + h, x + w, y + h, boxCol, t, thick, true)
            setFxLine(o, "left", x, y, x, y + h, boxCol, t, thick, true)
            setFxLine(o, "right", x + w, y, x + w, y + h, boxCol, t, thick, true)
        else
            if o.lines then
                for _, k in ipairs(BOX_KEYS) do
                    local l = o.lines[k]
                    if l then SA.ApplyInstProp(cache, l, "Visible", false) end
                end
            end
            if cornerBox then
                local s = math.max(math.min(w, h) * 0.3, 8)
                setFxLine(o, "box1", x, y, x + s, y, boxCol, t, thick, false)
                setFxLine(o, "box2", x, y, x, y + s, boxCol, t, thick, false)
                setFxLine(o, "box3", x + w, y, x + w - s, y, boxCol, t, thick, false)
                setFxLine(o, "box4", x + w, y, x + w, y + s, boxCol, t, thick, false)
                setFxLine(o, "box5", x, y + h, x + s, y + h, boxCol, t, thick, false)
                setFxLine(o, "box6", x, y + h, x, y + h - s, boxCol, t, thick, false)
                setFxLine(o, "box7", x + w, y + h, x + w - s, y + h, boxCol, t, thick, false)
                setFxLine(o, "box8", x + w, y + h, x + w, y + h - s, boxCol, t, thick, false)
            else
                setFxLine(o, "box1", x, y, x + w, y, boxCol, t, thick, false)
                setFxLine(o, "box2", x, y + h, x + w, y + h, boxCol, t, thick, false)
                setFxLine(o, "box3", x, y, x, y + h, boxCol, t, thick, false)
                setFxLine(o, "box4", x + w, y, x + w, y + h, boxCol, t, thick, false)
            end
        end
    elseif o.lines then
        for _, k in ipairs(BOX_KEYS) do
            local l = o.lines[k]
            if l then SA.ApplyInstProp(cache, l, "Visible", false) end
        end
    end

    -- visibility frame: a larger outline painted with the user's
    -- green/red pick.
    if opt.checkVisible and showBox and g.onScreen then
        local pad = 3
        local x, y = g.x - pad, g.y - pad
        local w, h = g.w + pad * 2, g.h + pad * 2
        setFxLine(o, "visframe1", x, y, x + w, y, opt.visColor, t, thick, false)
        setFxLine(o, "visframe2", x, y + h, x + w, y + h, opt.visColor, t, thick, false)
        setFxLine(o, "visframe3", x, y, x, y + h, opt.visColor, t, thick, false)
        setFxLine(o, "visframe4", x + w, y, x + w, y + h, opt.visColor, t, thick, false)
    end

    -- health bar gradient
    if o.lines then
        local showHp = CFG.espShowHealth and g.onScreen
        local hpBg, hpFill = o.lines.hpBg, o.lines.hpFill
        if hpBg then
            if showHp then markLegacyLine(o, "hpBg") end
            SA.ApplyInstProp(cache, hpBg, "Visible", showHp)
        end
        if hpFill then
            if showHp then markLegacyLine(o, "hpFill") end
            SA.ApplyInstProp(cache, hpFill, "Visible", showHp)
        end
        if showHp and hpBg and hpFill then
            local hi, lo = espC(p .. "HealthHigh"), espC(p .. "HealthLow")
            SA.ApplyInstProp(cache, hpBg, "Color", Color3.fromRGB(20, 20, 20))
            SA.ApplyInstProp(cache, hpBg, "Transparency", t)
            SA.ApplyInstProp(cache, hpFill, "Color",
                CFG.espRainbow and rainbowColor(seed)
                or lo:Lerp(hi, math.clamp(opt.ratio or 1, 0, 1)))
            SA.ApplyInstProp(cache, hpFill, "Transparency", t)
        end
    end

    -- small visibility dot beside the box
    if g.onScreen and showBox then
        local d = getDraw(o, "visdot", "Circle")
        if d then
            d.Position = Vector2.new(g.x - 6, g.y - 6)
            d.Radius = 3
            d.Color = opt.visColor
            d.Transparency = t
            d.Visible = true
        end
    end

    -- bones + head dot (crates get a spine + top marker)
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
                            l.From = Vector2.new(va.X, va.Y)
                            l.To = Vector2.new(vb.X, vb.Y)
                            l.Color = fxColor(p, base, seed, "Skeleton")
                            l.Transparency = t
                            l.Thickness = thick
                            l.Visible = true
                        end
                    end
                end
            elseif g.onScreen then
                local spineColor = fxColor(p, base, seed, "Skeleton")
                setFxLine(o, "csk1", cx, g.y, cx, g.y + g.h,
                    spineColor, t, thick, false)
                setFxLine(o, "csk2", g.x, g.y + g.h / 2,
                    g.x + g.w, g.y + g.h / 2, spineColor, t, thick, false)
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
                hx, hy = cx, g.y
            end
            if hx then
                local d = getDraw(o, "headdot", "Circle")
                if d then
                    d.Position = Vector2.new(hx, hy)
                    d.Radius = 4
                    d.Color = fxColor(p, base, seed, "HeadDot")
                    d.Transparency = t
                    d.Visible = true
                end
            end
        end
    end

    -- tracer + off-screen arrow (PLAYER-ONLY)
    if CFG.espShowTracer and playerOnly then
        local l = getDraw(o, "tracer", "Line")
        if l then
            l.From = opt.origin
            l.To = (CFG.espArrowFOV and outsideFov) and fov.edge or px
            l.Color = fxColor(p, base, seed, "Tracer")
            l.Transparency = t
            l.Thickness = thick
            l.Visible = true
        end
    end

    -- FOV arrows use the real direction and hide the instant the target is
    -- inside the circle; screen-edge arrows are shown only off-viewport.
    local showArrow = CFG.espShowOffscreen and playerOnly
        and ((CFG.espArrowFOV and outsideFov)
            or ((not CFG.espArrowFOV) and not onScr))
    if showArrow then
        local tri = getDraw(o, "arrow", "Triangle")
        if tri then
            pcall(function()
                local anchorAt = CFG.espArrowFOV and fov.edge or fov.clamped
                local a = SA.Atan2(dir.Y, dir.X)
                local r = math.clamp(fovR * 0.035, 7, 16)
                tri.PointA = anchorAt + Vector2.new(math.cos(a), math.sin(a)) * r
                tri.PointB = anchorAt + Vector2.new(math.cos(a + 2.4), math.sin(a + 2.4)) * r
                tri.PointC = anchorAt + Vector2.new(math.cos(a - 2.4), math.sin(a - 2.4)) * r
                tri.Color = fxColor(p, base, seed, "Offscreen")
                tri.Transparency = t
                tri.Visible = true
            end)
        end
    end
end

local function drawEntity(cam, o, opt)
    if not opt or not opt.enabled then hideFx(o); return end
    startFxFrame(o)
    local ok, err = pcall(drawEntityInner, cam, o, opt)
    pcall(hideUnusedFx, o)
    if not ok then error(err, 0) end
end
