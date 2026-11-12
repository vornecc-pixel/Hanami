-- ==================================================================
-- Hanami / 18_esp_fx_colours.lua — ESP palette helpers + lazy Drawing helpers
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- One styling pipeline for PLAYERS, NPCs and CRATES. Every colour comes
-- from ESP_COLORS (01_config.lua) and every key has a white colourpicker
-- chained INLINE onto the control it styles. New visuals are created lazily, so a feature
-- that is switched off costs zero Drawing objects.
--
-- New features: corner boxes, chams fill/outline, skeleton, head dot,
-- tracers, off-screen arrows, visibility dot, per-element colours,
-- rainbow cycle, distance fade, per-NPC-type colours, target highlight.
-- ────────────────────────────────────────────────────────────────────

local function espC(key)
    return ESP_COLORS[key] or Color3.new(1, 1, 1)
end

local rainbowFrame, rainbowClock = -1, 0
local function rainbowColor(seed)
    local frame = SA.EspFxFrame or 0
    if rainbowFrame ~= frame then
        rainbowFrame = frame
        rainbowClock = tick() * math.max(CFG.espRainbowSpeed or 2, 0.1) * 0.12
    end
    return Color3.fromHSV((rainbowClock + (seed or 0)) % 1, 0.85, 1)
end

-- base = dynamic visibility / crate-type colour (used by default)
-- per-element mode = each widget uses its own picked colour
-- rainbow mode = everything cycles (target highlight still overrides)
local function pick(key, base, seed)
    if CFG.espRainbow then return rainbowColor(seed) end
    if CFG.espPerElementColors then return espC(key) end
    return base
end

local function fadeAmount(dist, maxDist)
    if not CFG.espFade then return 0 end
    local start = maxDist * math.clamp((CFG.espFadeStart or 60) / 100, 0, 1)
    local span = math.max(maxDist - start, 1)
    return math.clamp((dist - start) / span, 0, 0.85)
end

-- Per-frame draw usage marks. The old FX pass hid EVERY pooled draw and
-- prebuilt line at the start of each entity, then re-showed the same ones.
-- That produced a hide -> show write pair per draw per frame. Now a draw is
-- hidden only when it was not used in the current ApplyEspFx frame.
local function fxFrame()
    return SA.EspFxFrame or 0
end

local function markFx(o, key)
    if not o then return end
    local used = o.fxUsed
    if not used then used = {}; o.fxUsed = used end
    used[key] = fxFrame()
end

local function markLegacyLine(o, key)
    if not o then return end
    local used = o.linesUsed
    if not used then used = {}; o.linesUsed = used end
    used[key] = fxFrame()
end

local function markHighlight(o)
    if o then o.highlightFrame = fxFrame() end
end

local function startFxFrame(o)
    if o then o.fxFrame = fxFrame() end
end

local function getDraw(o, key, kind)
    if not o.fx then o.fx = {} end
    markFx(o, key)
    local d = o.fx[key]
    if not d then
        d = SA.DrawPoolTake and SA.DrawPoolTake(kind) or nil
        if not d then
            local ok, obj = pcall(function() return SA.NewDraw(kind) end)
            if not ok or not obj then return nil end
            d = obj
            pcall(function() d.__saPoolKind = kind end)
        end
        o.fx[key] = d
        d.Visible = false
        if kind == "Line" then d.Thickness = math.max(CFG.espBoxThickness or 1, 1) end
        if kind == "Circle" then d.NumSides = 24; d.Filled = true; d.Thickness = 1 end
        if kind == "Triangle" then d.Filled = true end
    end
    return d
end

local function instCache(o)
    if not o then return nil end
    if not o.instApplied then o.instApplied = {} end
    return o.instApplied
end

-- The world-anchored BillboardGui is a legacy text source. The screen-space
-- FX pass writes its own name/distance/tags, so every legacy label and the
-- BillboardGui itself must be hidden. Verify the LIVE property after the
-- cached write: the throttled refresh can set Visible/Enabled directly, and
-- an executor that rejects one cached write must not leave a duplicate
-- world-anchored name tag behind.
local function hideInstVisible(cache, inst, prop)
    if not inst then return end
    pcall(function()
        if SA.ApplyInstProp then SA.ApplyInstProp(cache, inst, prop, false) end
        if inst[prop] ~= false then inst[prop] = false end
    end)
end

local function hideEspBillboard(o)
    if not o then return end
    local cache = instCache(o)
    local labels = { o.nameLbl, o.distLbl, o.infoLbl, o.stateLbl }
    for _, lbl in ipairs(labels) do
        hideInstVisible(cache, lbl, "Visible")
    end
    if o.bb then
        hideInstVisible(cache, o.bb, "Enabled")
        pcall(function()
            if SA.ApplyInstProp then
                SA.ApplyInstProp(cache, o.bb, "Size", UDim2.fromOffset(220, 1))
                SA.ApplyInstProp(cache, o.bb, "StudsOffset", Vector3.new(0, 0, 0))
            else
                o.bb.Size = UDim2.fromOffset(220, 1)
                o.bb.StudsOffset = Vector3.new(0, 0, 0)
            end
        end)
    end
end
SA.HideEspBillboard = hideEspBillboard

-- Called ONCE on a FOV / viewport / draw-signature transition, not every
-- frame. A stale duplicate espObjects slot or a ghost HanamiPlayerGui from
-- an older chunk can otherwise keep a second label pinned to the FOV edge
-- while the live target is already inside the circle.
SA.EspDuplicateCleanup = SA.EspDuplicateCleanup or {
    objects = 0, ghosts = 0, labels = 0,
}
function SA.EspHideDuplicateOverlays(current, model)
    if not model then return end
    local st = SA.EspDuplicateCleanup
    pcall(hideEspBillboard, current)
    for _, o in pairs(espObjects or {}) do
        if o and o ~= current and o.char == model then
            pcall(hideFx, o)
            st.objects = st.objects + 1
        end
    end
    local roots = { model }
    pcall(function()
        local head = model:FindFirstChild("Head") or model:FindFirstChild("HeadPart")
        if head then roots[#roots + 1] = head end
    end)
    for _, root in ipairs(roots) do
        pcall(function()
            for _, c in ipairs(root:GetChildren()) do
                if c and c.Name == "HanamiPlayerGui"
                    and c:IsA("BillboardGui") then
                    pcall(function() c.Enabled = false end)
                    st.ghosts = st.ghosts + 1
                    pcall(function()
                        for _, lbl in ipairs(c:GetChildren()) do
                            if lbl:IsA("TextLabel") and lbl.Visible ~= false then
                                lbl.Visible = false
                                st.labels = st.labels + 1
                            end
                        end
                    end)
                end
            end
        end)
    end
end
function SA.EspDuplicateCleanupState()
    local st = SA.EspDuplicateCleanup or {}
    return {
        objects = st.objects or 0, ghosts = st.ghosts or 0,
        labels = st.labels or 0,
    }
end

local function hideLegacyFx(o)
    if not o then return end
    local cache = instCache(o)
    if o.lines then
        for _, d in pairs(o.lines) do
            if SA.ApplyInstProp then
                pcall(SA.ApplyInstProp, cache, d, "Visible", false)
            else
                pcall(function() d.Visible = false end)
            end
        end
    end
    if o.highlight then
        if SA.ApplyInstProp then
            pcall(SA.ApplyInstProp, cache, o.highlight, "Enabled", false)
        else
            pcall(function() o.highlight.Enabled = false end)
        end
    end
    hideEspBillboard(o)
end

local function hideFx(o)
    if not o then return end
    o.fxFrame = fxFrame() - 1
    o.highlightFrame = fxFrame() - 1
    if o.fx then
        for _, d in pairs(o.fx) do
            pcall(function() d.Visible = false end)
        end
    end
    hideLegacyFx(o)
end

local function hideUnusedFx(o)
    if not o then return end
    local frame = o.fxFrame or fxFrame()
    local cache = instCache(o)
    local used = o.fxUsed or {}
    if o.fx then
        for key, d in pairs(o.fx) do
            if used[key] ~= frame then
                pcall(function()
                    if d.Visible ~= false then d.Visible = false end
                end)
            end
        end
    end
    local lused = o.linesUsed or {}
    if o.lines then
        for key, d in pairs(o.lines) do
            if lused[key] ~= frame and SA.ApplyInstProp then
                pcall(SA.ApplyInstProp, cache, d, "Visible", false)
            end
        end
    end
    if o.highlight and o.highlightFrame ~= frame and SA.ApplyInstProp then
        pcall(SA.ApplyInstProp, cache, o.highlight, "Enabled", false)
    end
end

function SA.DisposeEspFx(o)
    if not o or not o.fx then return end
    for _, d in pairs(o.fx) do
        if SA.RecycleDraw then pcall(SA.RecycleDraw, d) else removeDrawing(d) end
    end
    o.fx = nil
    o.fxUsed = nil
    o.linesUsed = nil
    o.fxFrame = nil
    o.highlightFrame = nil
    o.instApplied = nil
    o.geomKey = nil
    o.geomCache = nil
    o.geomAnchor = nil
end

local function findPart(model, names)
    if not model then return nil end
    for _, n in ipairs(names) do
        local p = model:FindFirstChild(n)
        if p and p:IsA("BasePart") then return p end
    end
    return nil
end

-- R6 and R15 friendly bone list (each side has name fallbacks)
local SKELETON = {
    { { "Head" }, { "UpperTorso", "Torso" } },
    { { "UpperTorso", "Torso" }, { "HumanoidRootPart", "LowerTorso" } },
    { { "UpperTorso", "Torso" }, { "LeftUpperArm", "Left Arm" } },
    { { "UpperTorso", "Torso" }, { "RightUpperArm", "Right Arm" } },
    { { "HumanoidRootPart", "LowerTorso" }, { "LeftUpperLeg", "Left Leg" } },
    { { "HumanoidRootPart", "LowerTorso" }, { "RightUpperLeg", "Right Leg" } },
}

local function tracerOrigin(cam)
    local vp = cam.ViewportSize
    local mode = CFG.espTracerOrigin or "Bottom"
    if mode == "Mouse" then return SA.AimPoint() end
    if mode == "Center" then return Vector2.new(vp.X / 2, vp.Y / 2) end
    return Vector2.new(vp.X / 2, vp.Y - 8)
end

-- Returns a usable on-screen pixel and whether the target is actually in
-- view. Off-screen targets are clamped to a border margin so arrows and
-- tracers still point at them.
local function screenPoint(cam, v3, ok)
    local vp = cam.ViewportSize or Vector2.new(1280, 720)
    local m = 34
    -- WorldToViewportPoint's boolean does not always encode viewport bounds.
    -- Explicit bounds stop in-front-but-off-screen targets from being styled
    -- as on-screen, which was the "ESP freezes when I turn too far" bug.
    local inView = ok == true and v3.Z > 0
        and v3.X >= -m and v3.X <= vp.X + m
        and v3.Y >= -m and v3.Y <= vp.Y + m
    if inView then return Vector2.new(v3.X, v3.Y), true end
    local cx, cy = vp.X / 2, vp.Y / 2
    local dx, dy = v3.X - cx, v3.Y - cy
    if v3.Z < 0 then dx, dy = -dx, -dy end
    if math.abs(dx) < 0.0001 and math.abs(dy) < 0.0001 then dy = 1 end
    local sx = math.abs(dx) / math.max(vp.X / 2 - m, 1)
    local sy = math.abs(dy) / math.max(vp.Y / 2 - m, 1)
    local k = 1 / math.max(sx, sy, 0.0001)
    return Vector2.new(cx + dx * k, cy + dy * k), false
end

-- FOV state must be computed from the real WorldToViewportPoint result.
-- The old code used screenPoint()'s border-clamped pixel for BOTH the arrow
-- and the inside/outside test, so a target entering the circle inherited the
-- clamped edge direction and its box/name stayed "stuck outside" until the
-- camera turned away. Arrows/tracers still use the clamped/edge anchor.
local function espFovSnapshot(cam, g, fovCenter, fovRadius)
    local vp = cam.ViewportSize or Vector2.new(1280, 720)
    local center = fovCenter or SA.AimPoint()
    local radius = math.max(tonumber(fovRadius) or SA.FovRadius(), 20)
    local raw = g and g.raw
    local fallback = raw or Vector3.new(vp.X / 2, vp.Y / 2, 1)
    local clamped, clampedOn = screenPoint(cam, fallback, g and g.ok)
    local inFront = g and g.ok == true and raw
        and (tonumber(raw.Z) or 0) > 0
    local point = inFront and Vector2.new(raw.X, raw.Y) or clamped
    local onScreen = inFront and (g.onScreen == true or clampedOn) or false
    local dir = point - center
    if dir.Magnitude < 0.001 then dir = Vector2.new(0, 1) end
    local inside = onScreen and (dir.Magnitude <= radius)
    return {
        point = point, clamped = clamped, dir = dir,
        center = center, radius = radius, onScreen = onScreen,
        inside = inside, outside = not inside,
        edge = center + dir.Unit * radius,
    }
end
SA.EspFovSnapshot = espFovSnapshot

local function boxSegments(g, corner)
    local x, y, w, h = g.x, g.y, g.w, g.h
    if not corner then
        return {
            { x, y, x + w, y }, { x, y + h, x + w, y + h },
            { x, y, x, y + h }, { x + w, y, x + w, y + h },
        }
    end
    local s = math.max(math.min(w, h) * 0.3, 8)
    return {
        { x, y, x + s, y }, { x, y, x, y + s },
        { x + w, y, x + w - s, y }, { x + w, y, x + w, y + s },
        { x, y + h, x + s, y + h }, { x, y + h, x, y + h - s },
        { x + w, y + h, x + w - s, y + h }, { x + w, y + h, x + w, y + h - s },
    }
end
