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

    -- Held outside the pcall so a partial failure can be cleaned up
    -- instead of leaking orphaned Instances into the character.
    local bb, hl, lines = nil, nil, nil
    local ok = pcall(function()
        bb = Instance.new("BillboardGui")
        bb.Name = "HanamiPlayerGui"
        bb.Size = UDim2.fromOffset(220, 56)
        bb.StudsOffset = Vector3.new(0, 2.5, 0)
        bb.AlwaysOnTop = true
        bb.Adornee = head
        bb.Parent = head

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size = UDim2.new(1, 0, 0, 14)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Font = Enum.Font.GothamBold
        nameLbl.TextSize = 11
        nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLbl.TextStrokeTransparency = 0
        nameLbl.Parent = bb

        local distLbl = Instance.new("TextLabel")
        distLbl.Size = UDim2.new(1, 0, 0, 12)
        distLbl.Position = UDim2.new(0, 0, 0, 14)
        distLbl.BackgroundTransparency = 1
        distLbl.Font = Enum.Font.GothamMedium
        distLbl.TextSize = 11
        distLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
        distLbl.TextStrokeTransparency = 0
        distLbl.Parent = bb

        -- weapon / state / VIS-WALL line (filled by 13_esp_players_refresh)
        local infoLbl = Instance.new("TextLabel")
        infoLbl.Size = UDim2.new(1, 0, 0, 12)
        infoLbl.Position = UDim2.new(0, 0, 0, 28)
        infoLbl.BackgroundTransparency = 1
        infoLbl.Font = Enum.Font.GothamMedium
        infoLbl.TextSize = 10
        infoLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
        infoLbl.TextStrokeTransparency = 0
        infoLbl.Visible = false
        infoLbl.Parent = bb

        hl = Instance.new("Highlight")
        hl.Name = "HanamiPlayerHighlight"
        hl.Adornee = char
        hl.FillTransparency = 0.3
        hl.OutlineTransparency = 1
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent = char

        lines = {
            top = SA.NewDraw("Line"), bottom = SA.NewDraw("Line"),
            left = SA.NewDraw("Line"), right = SA.NewDraw("Line"),
            hpBg = SA.NewDraw("Line"), hpFill = SA.NewDraw("Line"),
        }
        -- A failed property write on one Drawing backend must not abort
        -- the build and leave a half-created player in the queue.
        for _, l in pairs(lines) do
            pcall(function() l.Thickness = 1; l.Visible = false end)
        end
        pcall(function() lines.hpBg.Thickness = 2; lines.hpFill.Thickness = 2 end)

        espObjects[plr] = {
            bb = bb, nameLbl = nameLbl, distLbl = distLbl, infoLbl = infoLbl,
            highlight = hl, lines = lines,
            char = char, root = hrp, head = head, hum = hum,
        }
    end)
    if not ok then
        -- Never leave a half-built character stranded in the DataModel.
        pcall(function() if bb then bb:Destroy() end end)
        pcall(function() if hl then hl:Destroy() end end)
        if lines then for _, l in pairs(lines) do removeDrawing(l) end end
        espObjects[plr] = nil
        return false
    end
    return espObjects[plr] ~= nil
end

-- Console diagnostic: one line per player with the exact reason it has
-- no ESP. Bound to ESP -> Player -> "Print Player ESP State".
function SA.PlayerEspDiag()
    local total, built = 0, 0
    print("════════════ PLAYER ESP DIAG ════════════")
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= lp then
            total = total + 1
            local o = espObjects[p]
            local char = p.Character
            local root, head, hum = SA.PlayerRig(char)
            local dead, bbGone = false, false
            if hum then pcall(function() dead = hum.Health <= 0 end) end
            if o then pcall(function() bbGone = o.bb ~= nil and o.bb.Parent == nil end) end
            local why
            if not char then why = "NO CHARACTER (not loaded / left)"
            elseif not root then why = "NO ROOT PART (custom or streamed rig)"
            elseif not head then why = "NO HEAD PART"
            elseif not hum then why = "NO HUMANOID"
            elseif dead then why = "DEAD (hidden by refresh)"
            elseif not o then why = "NOT BUILT (waiting for build slot)"
            elseif o.char ~= char then why = "STALE (character changed)"
            elseif bbGone then why = "STALE GUI (destroyed)"
            else why = "BUILT"; built = built + 1 end
            print(string.format("  %-20s | %s", p.Name, why))
        end
    end
    local backend = "?"
    pcall(function() backend = SA.DrawBackend() end)
    print(string.format("════════════ %d/%d built | backend %s | espEnabled %s ════════════",
        built, total, backend, tostring(CFG.espEnabled)))
end
