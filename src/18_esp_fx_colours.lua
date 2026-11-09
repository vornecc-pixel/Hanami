-- ==================================================================
-- Hanami / 18_esp_fx_colours.lua — ESP palette helpers + lazy Drawing helpers
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- One styling pipeline for PLAYERS, NPCs and CRATES. Every colour comes
-- from ESP_COLORS (01_config.lua) and every key has a colourpicker in the
-- ESP -> Colours mini-tabs. New visuals are created lazily, so a feature
-- that is switched off costs zero Drawing objects.
--
-- New features: corner boxes, chams fill/outline, skeleton, head dot,
-- tracers, off-screen arrows, visibility dot, per-element colours,
-- rainbow cycle, distance fade, per-NPC-type colours, target highlight.
-- ────────────────────────────────────────────────────────────────────

local function espC(key)
    return ESP_COLORS[key] or Color3.new(1, 1, 1)
end

local function rainbowColor(seed)
    local t = tick() * math.max(CFG.espRainbowSpeed or 2, 0.1) * 0.12 + (seed or 0)
    return Color3.fromHSV(t % 1, 0.85, 1)
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

local function getDraw(o, key, kind)
    if not o.fx then o.fx = {} end
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

local function hideLegacyFx(o)
    if not o then return end
    if o.lines then
        for _, d in pairs(o.lines) do pcall(function() d.Visible = false end) end
    end
    if o.highlight then pcall(function() o.highlight.Enabled = false end) end
end

local function hideFx(o)
    if not o then return end
    if o.fx then for _, d in pairs(o.fx) do d.Visible = false end end
    hideLegacyFx(o)
end

function SA.DisposeEspFx(o)
    if not o or not o.fx then return end
    for _, d in pairs(o.fx) do
        if SA.RecycleDraw then pcall(SA.RecycleDraw, d) else removeDrawing(d) end
    end
    o.fx = nil
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
    if ok and v3.Z > 0 then return Vector2.new(v3.X, v3.Y), true end
    local vp = cam.ViewportSize
    local cx, cy = vp.X / 2, vp.Y / 2
    local dx, dy = v3.X - cx, v3.Y - cy
    if v3.Z < 0 then dx, dy = -dx, -dy end
    if math.abs(dx) < 0.0001 and math.abs(dy) < 0.0001 then dy = 1 end
    local m = 34
    local sx = math.abs(dx) / math.max(vp.X / 2 - m, 1)
    local sy = math.abs(dy) / math.max(vp.Y / 2 - m, 1)
    local k = 1 / math.max(sx, sy, 0.0001)
    return Vector2.new(cx + dx * k, cy + dy * k), false
end

local function boxSegments(g, corner)
    local x, y, w, h = g.x, g.y, g.w, g.h
    if not corner then
        return {
            { x, y, x + w, y }, { x, y + h, x + w, y + h },
            { x, y, x, y + h }, { x + w, y, x + w, y + h },
        }
    end
    local s = math.min(w, h) * 0.3
    return {
        { x, y, x + s, y }, { x, y, x, y + s },
        { x + w, y, x + w - s, y }, { x + w, y, x + w, y + s },
        { x, y + h, x + s, y + h }, { x, y + h, x, y + h - s },
        { x + w, y + h, x + w - s, y + h }, { x + w, y + h, x + w, y + h - s },
    }
end
