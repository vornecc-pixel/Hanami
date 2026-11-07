-- ==================================================================
-- Hanami / 18_esp_fx_draw.lua — Unified per-entity styling (players / NPCs / crates)
-- Loaded in order by loader.lua. Parts are joined into ONE chunk
-- before running, so every `local` is shared just like the original.
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

    local function col(suffix) return pick(p .. suffix, base, seed) end

    local boxCol, fillCol, outlineCol = col("Box"), col("Fill"), col("Outline")
    if opt.typeColor and not CFG.espRainbow then
        boxCol, fillCol, outlineCol = opt.typeColor, opt.typeColor, opt.typeColor
    end
    if isTarget then
        boxCol, fillCol, outlineCol = espC("target"), espC("target"), espC("target")
    end

    -- billboard text
    if o.nameLbl then
        -- crates keep their type colour on the name (set by the refresh);
        -- every other label uses its own picker / the dynamic base.
        if opt.keepNameColor then
            if CFG.espRainbow then o.nameLbl.TextColor3 = rainbowColor(seed) end
        else o.nameLbl.TextColor3 = col("Name") end
        o.nameLbl.TextTransparency = t
    end
    if o.distLbl then o.distLbl.TextColor3 = col("Distance"); o.distLbl.TextTransparency = t end
    if o.infoLbl then
        -- VIS / WALL tag always carries the dynamic green/red colour
        o.infoLbl.TextColor3 = opt.checkVisible and opt.visColor or col("Info")
        o.infoLbl.TextTransparency = t
    end
    if o.stateLbl then
        o.stateLbl.TextColor3 = opt.opened and espC("crateOpened") or col("State")
        o.stateLbl.TextTransparency = t
    end

    -- chams
    if o.highlight then
        o.highlight.FillColor = fillCol
        o.highlight.OutlineColor = outlineCol
        o.highlight.FillTransparency = CFG.espShowFill and math.clamp(0.7 + t, 0, 1) or 1
        o.highlight.OutlineTransparency = CFG.espShowOutline and math.clamp(t, 0, 1) or 1
    end

    -- box: reuse the 4 prebuilt lines for full boxes, lazily create the
    -- 8 corner segments (or a crate's own 4 lines) when needed
    local prebuilt = o.lines and { "top", "bottom", "left", "right" } or nil
    if CFG.espShowBox and g.onScreen then
        if prebuilt and not CFG.espCornerBox then
            for _, k in ipairs(prebuilt) do
                local l = o.lines[k]
                l.Color = boxCol; l.Transparency = t; l.Thickness = thick
            end
        else
            if prebuilt then for _, k in ipairs(prebuilt) do o.lines[k].Visible = false end end
            for i, s in ipairs(boxSegments(g, CFG.espCornerBox)) do
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
    if opt.checkVisible and CFG.espShowBox and g.onScreen then
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
    if g.onScreen and CFG.espShowBox then
        local d = getDraw(o, "visdot", "Circle")
        if d then
            d.Position = Vector2.new(g.x - 6, g.y - 6); d.Radius = 3
            d.Color = opt.visColor; d.Transparency = t; d.Visible = true
        end
    end

    -- bones + head dot
    if opt.model and (CFG.espShowSkeleton or CFG.espShowHeadDot) then
        if CFG.espShowSkeleton then
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
        end
        if CFG.espShowHeadDot then
            local h = findPart(opt.model, { "Head" })
            if h then
                local v, ok = cam:WorldToViewportPoint(h.Position)
                local d = (ok and v.Z > 0) and getDraw(o, "headdot", "Circle") or nil
                if d then
                    d.Position = Vector2.new(v.X, v.Y); d.Radius = 4
                    d.Color = col("HeadDot"); d.Transparency = t; d.Visible = true
                end
            end
        end
    end

    -- tracer + off-screen arrow
    local px, onScr = screenPoint(cam, g.raw, g.ok)
    if CFG.espShowTracer then
        local l = getDraw(o, "tracer", "Line")
        if l then
            l.From = opt.origin; l.To = px
            l.Color = col("Tracer"); l.Transparency = t
            l.Thickness = thick; l.Visible = true
        end
    end
    if CFG.espShowOffscreen and not onScr then
        local tri = getDraw(o, "arrow", "Triangle")
        if tri then
            -- a few executors expose Triangle without PointA/B/C; fail soft
            pcall(function()
                local vp = cam.ViewportSize
                local a = math.atan2(px.Y - vp.Y / 2, px.X - vp.X / 2)
                local r = 9
                tri.PointA = px + Vector2.new(math.cos(a), math.sin(a)) * r
                tri.PointB = px + Vector2.new(math.cos(a + 2.4), math.sin(a + 2.4)) * r
                tri.PointC = px + Vector2.new(math.cos(a - 2.4), math.sin(a - 2.4)) * r
                tri.Color = col("Offscreen"); tri.Transparency = t; tri.Visible = true
            end)
        end
    end
end
