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

    -- ── ONE TEXT-SIZE SLIDER FOR EVERY ESP LABEL ──────────────────────
    -- name, distance, tool / state, VIS tag and health % all scale
    -- together; rows are re-stacked so nothing overlaps at large sizes.
    local ts = math.clamp(CFG.espTextSize or 11, 6, 30)
    local rowH = math.floor(ts + 2)
    local order = o.stateLbl
        and { o.nameLbl, o.stateLbl, o.distLbl }
        or  { o.nameLbl, o.distLbl, o.infoLbl }
    local rows = 0
    for _, lbl in ipairs(order) do
        if lbl then
            lbl.TextSize = ts
            lbl.Size = UDim2.new(1, 0, 0, rowH)
            lbl.TextStrokeTransparency = CFG.espTextOutline and 0 or 1
            if lbl.Visible then
                lbl.Position = UDim2.new(0, 0, 0, rows * rowH)
                rows = rows + 1
            end
        end
    end
    o.bb.Size = UDim2.fromOffset(220, math.max(rows, 1) * rowH)
    o.bb.StudsOffset = Vector3.new(0, 2 + ts * 0.12, 0)

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
    -- (radius = CFG.fov, centre = the same mouse point as the FOV circle),
    -- and it is also shown for targets that are on-screen but outside the
    -- aim cone. Change the FOV radius and the arrows move with it.
    local px, onScr = screenPoint(cam, g.raw, g.ok)
    local fovC = opt.fovCenter or Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
    local fovR = math.max(opt.fovRadius or 150, 20)
    local dir = px - fovC
    if dir.Magnitude < 0.001 then dir = Vector2.new(0, 1) end
    local outsideFov = dir.Magnitude > fovR

    if CFG.espShowTracer then
        local l = getDraw(o, "tracer", "Line")
        if l then
            l.From = opt.origin
            l.To = (CFG.espArrowFOV and not onScr) and (fovC + dir.Unit * fovR) or px
            l.Color = col("Tracer"); l.Transparency = t
            l.Thickness = thick; l.Visible = true
        end
    end

    if CFG.espShowOffscreen and (not onScr or (CFG.espArrowFOV and outsideFov)) then
        local tri = getDraw(o, "arrow", "Triangle")
        if tri then
            pcall(function()
                local anchorAt = CFG.espArrowFOV and (fovC + dir.Unit * fovR) or px
                local a = math.atan2(dir.Y, dir.X)
                local r = math.clamp(fovR * 0.035, 7, 16)  -- scales with the FOV
                tri.PointA = anchorAt + Vector2.new(math.cos(a), math.sin(a)) * r
                tri.PointB = anchorAt + Vector2.new(math.cos(a + 2.4), math.sin(a + 2.4)) * r
                tri.PointC = anchorAt + Vector2.new(math.cos(a - 2.4), math.sin(a - 2.4)) * r
                tri.Color = col("Offscreen"); tri.Transparency = t; tri.Visible = true
            end)
        end
    end
end
