-- ==================================================================
-- Hanami / 17_z_crate_fov.lua — Crate FOV membership (crate-owned)
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
--
-- Lives in its own part so the crate classifier does not push
-- 18_esp_fx_frame.lua over the Luau 200-register budget. It depends only
-- on ws / SA.AimPoint() / SA.FovRadius(), all of which are defined long
-- before this part runs.
-- ==================================================================

-- ── CRATE FOV CLASSIFICATION (crate-owned state) ────────────────────
-- Decides "is this crate inside the aim circle" from the crate's OWN
-- cached projection, never from the player FOV snapshot, and stores the
-- answer on the object with hysteresis:
--   * a crate already inside stays inside until it passes radius * 1.18,
--     so a projection that jitters by a pixel on the circle edge cannot
--     strobe the label / dot every frame;
--   * a crate outside enters at the exact radius.
-- The result is o.crateInside / o.crateOnScreen, read by the styling
-- branch, the refresh pass (Highlight ownership) and the counters.
-- Nothing here touches player objects, so enabling this mode cannot
-- change player ESP state.
local CRATE_FOV_RELEASE = 1.18
local function crateFovClassify(o, g)
    if not o or not g then return false, false end
    local raw = g.raw
    local vp = (ws.CurrentCamera and ws.CurrentCamera.ViewportSize)
        or Vector2.new(1280, 720)
    local margin = 34
    local inFront = g.ok == true and raw and (tonumber(raw.Z) or 0) > 0
    local onScreen = inFront == true and raw ~= nil
        and raw.X >= -margin and raw.X <= vp.X + margin
        and raw.Y >= -margin and raw.Y <= vp.Y + margin
    if not onScreen then
        if o.crateInside == true and o.highlight then
            pcall(function() o.highlight.Enabled = false end)
        end
        o.crateInside, o.crateOnScreen = false, false
        return false, false
    end
    local center = SA.AimPoint()
    local radius = math.max(tonumber(SA.FovRadius()) or 0, 1)
    if o.crateInside == true then radius = radius * CRATE_FOV_RELEASE end
    local dx, dy = raw.X - center.X, raw.Y - center.Y
    local inside = (dx * dx + dy * dy) <= radius * radius
    if o.crateInside == true and not inside and o.highlight then
        pcall(function() o.highlight.Enabled = false end)
    end
    o.crateInside, o.crateOnScreen = inside, true
    return inside, true
end
SA.CrateFovClassify = crateFovClassify

-- Crate-only version of the sweep. Same recycled-draw cleanup, applied to
-- crateObjects ONLY, so a crate setting can never reset a player object.
function SA.EspCrateSweep()
    local n = 0
    for _, o in pairs(crateObjects or {}) do
        if o then
            pcall(function()
                if type(hideFx) == "function" then hideFx(o) end
                startFxFrame(o)
            end)
            o.geomKey, o.geomCache, o.geomAnchor = nil, nil, nil
            o.geomForceFresh = true
            -- Re-classify the circle membership from scratch.
            o.crateInside, o.crateOnScreen = nil, nil
            n = n + 1
        end
    end
    SA.EspPerf.crateSweeps = (SA.EspPerf.crateSweeps or 0) + 1
    SA.EspLastCrateSweep = { objects = n, frame = SA.EspFxFrame or 0 }
    return n
end

-- State probe lives with the classifier it describes.
function SA.CrateFovState()
    local c = SA.CrateFovCount or {}
    -- How many times a crate crossed the circle. A healthy crate FOV mode
    -- changes this only when the player actually turns / moves; a number
    -- that climbs every frame is the "labels keep flipping" strobe.
    local transitions = 0
    if type(SA.CrateFovTransitions) == "function" then
        transitions = SA.CrateFovTransitions()
    end
    -- playerEsp / playerHiddenPass are exposed here on purpose: the
    -- reported symptom was "turning this on disables my player ESP", so
    -- the state probe must be able to prove that it does not.
    return {
        enabled = CFG.crateFovAware == true,
        crateEsp = CFG.crateEnabled == true,
        radius = SA.FovRadius and SA.FovRadius() or nil,
        center = SA.AimPoint and SA.AimPoint() or nil,
        inside = c.inside or 0,
        outside = c.outside or 0,
        dots = c.dots or 0,
        highlights = c.highlights or 0,
        transitions = transitions,
        playerEsp = CFG.espEnabled == true,
        playerHiddenPass = (SA.EspHiddenPass or {}).players == true,
        styleSweeps = SA.EspPerf and SA.EspPerf.styleSweeps or 0,
        crateSweeps = SA.EspPerf and SA.EspPerf.crateSweeps or 0,
    }
end

