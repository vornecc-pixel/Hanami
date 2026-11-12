-- ==================================================================
-- Hanami / 12_esp_players.lua — Player ESP objects, box, health bar
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- PLAYER ESP — "some players show, some don't" fix
--
--   * espObjects now survives a re-execute through _G and is PURGED on
--     load, so ghost BillboardGuis / lines left by an older run can't
--     impersonate live players while the new chunk builds fresh ones.
--   * SA.PlayerRig() tolerates R6, R15, streaming and custom rigs
--     instead of demanding "Head" + "HumanoidRootPart" by exact name.
--   * buildESP() no longer refuses a dead / mid-load player outright —
--     the refresh hides it instead, so the build queue stops churning.
--   * every object records the character it was built for, so a respawn
--     or a manual character swap is detected and rebuilt (see 13 / 19).
--   * buildESP() returns true only when an object was actually created;
--     19_render_loop.lua counts successes, never failed attempts.
-- ────────────────────────────────────────────────────────────────────

local espObjects = _G.__saEspObjects or {}
_G.__saEspObjects = espObjects

local function removeDrawing(d)
    if SA.DrawRemove then
        SA.DrawRemove(d)
        return
    end
    if (typeof(d) == "userdata" or type(d) == "table") and d.Remove then
        pcall(d.Remove, d)
    end
end

-- Resolve root / head / humanoid with fallbacks. A streamed character may
-- have its Head arrive a few frames after HumanoidRootPart, and custom
-- rigs rename both. Dropping those players at BUILD time is what made
-- them invisible forever in the old build queue.
function SA.PlayerRig(model)
    if not model then return nil, nil, nil end
    local root, head, hum = nil, nil, nil
    local ok = pcall(function()
        hum = model:FindFirstChildOfClass("Humanoid")
        if not hum then
            local h = model:FindFirstChild("Humanoid")
            if h and h:IsA("Humanoid") then hum = h end
        end
        local function part(name)
            local c = model:FindFirstChild(name)
            if c and c:IsA("BasePart") then return c end
            return nil
        end
        root = part("HumanoidRootPart") or part("RootPart")
            or part("UpperTorso") or part("Torso") or part("Hrp")
        if not root then
            pcall(function()
                local p = model.PrimaryPart
                if p and p:IsA("BasePart") then root = p end
            end)
        end
        if not root then
            for _, c in ipairs(model:GetChildren()) do
                if c:IsA("BasePart") then root = c; break end
            end
        end
        head = part("Head") or part("HeadPart") or root
    end)
    if not ok then return nil, nil, nil end
    return root, head, hum
end

local function destroyEspObject(o)
    if not o then return end
    if o.lines then for _, d in pairs(o.lines) do removeDrawing(d) end end
    if SA.DisposeEspFx then pcall(SA.DisposeEspFx, o)
    elseif o.fx then for _, d in pairs(o.fx) do removeDrawing(d) end end
    if o.bb then pcall(function() o.bb:Destroy() end) end
    if o.highlight then pcall(function() o.highlight:Destroy() end) end
end

local function clearESP(plr)
    local o = espObjects[plr]
    if not o then return end
    espObjects[plr] = nil
    destroyEspObject(o)
end

-- Re-execution cleanup. This runs BEFORE 18_esp_fx_colours.lua defines
-- SA.DisposeEspFx, so destroyEspObject() removes o.fx directly too.
do
    for plr in pairs(espObjects) do clearESP(plr) end
end

-- A HUD/ESP re-execute can leave a world-anchored BillboardGui from an
-- older chunk that is no longer present in espObjects. Purge those named
-- ghosts before attaching the fresh one; otherwise a second green name tag
-- can appear when the target enters the FOV circle.
local function purgeGhostEsp(char, head)
    for _, root in ipairs({ char, head }) do
        if root then
            pcall(function()
                for _, c in ipairs(root:GetChildren()) do
                    if c and (c.Name == "HanamiPlayerGui"
                        or c.Name == "HanamiPlayerHighlight") then
                        pcall(function() c:Destroy() end)
                    end
                end
            end)
        end
    end
end

local function buildESP(plr)
    if plr == lp then return false end
    local char = plr.Character
    -- An orphaned character (mid-respawn) has no parent in the DataModel:
    -- anything parented to it would be invisible anyway. The render loop
    -- retries after CharacterAdded swaps in the new model.
    if not char or not char.Parent then return false end
    local hrp, head, hum = SA.PlayerRig(char)
    if not hrp or not head or not hum then return false end
    clearESP(plr)
    purgeGhostEsp(char, head)

    -- Held outside the pcall so a partial failure can be cleaned up
    -- instead of leaking orphaned Instances into the character.
    --
    -- EVERY optional piece is built in its OWN pcall. The old build wrapped
    -- the BillboardGui, three labels, the Highlight, six Lines and the
    -- object registration in ONE pcall, so a single unsupported property
    -- anywhere (Highlight.DepthMode on an older client, a TextLabel write a
    -- strict executor rejects) aborted the whole thing: no object was ever
    -- registered, and the render loop retried the same doomed build forever.
    -- NPC ESP and crate ESP use separate builders, which is exactly why
    -- players alone were dead while the other ESPs worked.
    local bb, nameLbl, distLbl, infoLbl, hl, lines = nil, nil, nil, nil, nil, nil

    -- 1. Legacy BillboardGui -- a FALLBACK for text only. The screen-space
    --    FX pass draws the real name / distance / tags and needs no
    --    Instance text at all, so a failure here costs nothing visible.
    pcall(function()
        local g = Instance.new("BillboardGui")
        g.Name = "HanamiPlayerGui"
        g.Size = UDim2.fromOffset(220, 56)
        g.StudsOffset = Vector3.new(0, 2.5, 0)
        g.AlwaysOnTop = true
        g.Adornee = head
        g.Parent = head
        bb = g

        local function addLabel(name, y, size, colour, forceHidden)
            local lbl
            pcall(function()
                local t = Instance.new("TextLabel")
                t.Size = UDim2.new(1, 0, 0, size)
                t.Position = UDim2.new(0, 0, 0, y)
                t.BackgroundTransparency = 1
                pcall(function() SA.ApplyEspFont(t) end)
                t.TextSize = (size >= 14) and 11 or 10
                t.TextColor3 = colour
                pcall(function() t.TextStrokeTransparency = 0 end)
                if forceHidden then t.Visible = false end
                t.Parent = g
                lbl = t
            end)
            return lbl
        end
        nameLbl = addLabel("Name", 0, 14, Color3.fromRGB(255, 255, 255), false)
        distLbl = addLabel("Dist", 14, 12, Color3.fromRGB(200, 200, 200), false)
        infoLbl = addLabel("Info", 28, 12, Color3.fromRGB(200, 200, 200), true)
    end)
    -- A half-built BillboardGui is worse than none: drop it if its labels
    -- did not survive, because the refresh writes to all three.
    if bb and not (nameLbl and distLbl and infoLbl) then
        pcall(function() bb:Destroy() end)
        bb, nameLbl, distLbl, infoLbl = nil, nil, nil, nil
    end

    -- 2. Cham -- purely cosmetic, fully optional.
    pcall(function()
        local h = Instance.new("Highlight")
        h.Name = "HanamiPlayerHighlight"
        h.Adornee = char
        h.FillTransparency = 0.3
        h.OutlineTransparency = 1
        -- DepthMode does not exist on older clients; the cham still works.
        pcall(function() h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop end)
        h.Parent = char
        hl = h
    end)

    -- 3. Legacy box lines -- replaced by the FX pass whenever it is alive.
    lines = {}
    for _, key in ipairs({ "top", "bottom", "left", "right",
                           "hpBg", "hpFill" }) do
        local okLine, d = pcall(function() return SA.NewDraw("Line") end)
        lines[key] = (okLine and d) or nil
        if lines[key] then
            pcall(function() lines[key].Thickness = 1; lines[key].Visible = false end)
        end
    end
    pcall(function()
        if lines.hpBg then lines.hpBg.Thickness = 2 end
        if lines.hpFill then lines.hpFill.Thickness = 2 end
    end)
    -- Keep the table non-empty even when every Line failed, so the refresh
    -- loops (which iterate o.lines) stay cheap instead of erroring.
    if not (lines.top or lines.bottom or lines.left or lines.right) then
        lines = nil
    end

    -- 4. Register UNCONDITIONALLY. The object is what the FX pass and the
    --    refresh loop iterate; every optional part above may be nil.
    espObjects[plr] = {
        bb = bb, nameLbl = nameLbl, distLbl = distLbl, infoLbl = infoLbl,
        highlight = hl, lines = lines,
        char = char, root = hrp, head = head, hum = hum,
    }
    return espObjects[plr] ~= nil
end
