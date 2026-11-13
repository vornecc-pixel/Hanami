-- ==================================================================
-- Hanami / 17_esp_crates_refresh.lua — Crate ESP refresh + enable/disable
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================

-- ── CRATE FOV STATE (crate-owned, never the player pipeline) ─────────
-- The crate FOV mode must not borrow the PLAYER draw pipeline's circle
-- test. It used to: the crate branch ran SA.EspFovSnapshot() with the
-- player's centre / radius inside the shared styling pass, so the crate
-- mode was coupled to the player-side FOV state and toggling it rewrote
-- shared state the player objects also read. Membership is now OWNED by
-- the crate object (`o.crateInside`) and computed from the crate's own
-- cached projection, with a release margin so an edge crate cannot
-- strobe between frames.
--
-- Only the TRANSITION bookkeeping lives here: the Highlight is released
-- once when a crate leaves the circle, and the pooled edge dot is cleared
-- on the crossing. The per-frame test itself is SA.CrateFovClassify().
local crateFovTransitions = 0

local function setCrateFovState(o, inside, onScreen)
    local prev = o.crateInside
    local prevScreen = o.crateOnScreen
    if prev == inside and prevScreen == onScreen then return end
    o.crateInside, o.crateOnScreen = inside, onScreen
    if prev == nil then return end          -- first pass: no transition
    crateFovTransitions = crateFovTransitions + 1
    if not inside and o.highlight then
        pcall(function() o.highlight.Enabled = false end)
    end
end

local function refreshCrateESP()
    local myRoot = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
    local myPos = myRoot and myRoot.Position or nil
    local fovOn = CFG.crateFovAware == true

    for model, o in pairs(crateObjects) do
        o.visible = false
        if not model.Parent then clearCrate(model)
        else
            local kind = SA.CrateKind(model)
            if not kind then clearCrate(model)
            else
                local allowed = (kind == "Military" and CFG.crateShowMilitary)
                    or (kind == "Elite" and CFG.crateShowElite)
                    or (kind == "Loot" and CFG.crateShowLoot)
                local pos = cratePivotPos(model)
                local dist = (myPos and pos) and (myPos - pos).Magnitude or 0
                local opened = isCrateOpened(model)
                -- explicit if instead of `a and b or c` so the state filter
                -- can never be misread or flipped by Lua precedence
                local stateOk = true
                if opened and not CFG.crateShowOpened then stateOk = false end
                local show = allowed and stateOk and pos ~= nil and dist <= CFG.crateMaxDist

                -- Crate FOV membership is OWNED by the crate object and
                -- classified from its own cached projection every styling
                -- frame (SA.CrateFovClassify). Nothing is projected again
                -- here; this pass only reacts to the resulting state.
                local inside = o.crateInside == true
                if fovOn then
                    setCrateFovState(o, inside, o.crateOnScreen == true)
                else
                    o.crateInside, o.crateOnScreen = nil, nil
                end

                if not show then
                    o.bb.Enabled = false; o.highlight.Enabled = false
                else
                    o.visible, o.pos, o.dist, o.kind, o.opened = true, pos, dist, kind, opened
                    local base = opened and ESP_COLORS.crateOpened
                        or (kind == "Military" and ESP_COLORS.crateMilitary
                        or (kind == "Elite" and ESP_COLORS.crateElite or ESP_COLORS.crateLoot))
                    o.bb.Enabled = true
                    -- In FOV-aware mode the Highlight is the in-circle
                    -- marker only; the styling pass draws the outline.
                    if fovOn then
                        o.highlight.Enabled = inside
                    else
                        o.highlight.Enabled = CFG.crateHighlight
                    end
                    o.highlight.FillColor = base
                    o.highlight.OutlineColor = base
                    o.nameLbl.TextColor3 = base
                    o.nameLbl.Text = CRATE_KIND_LABEL[kind]
                    o.stateLbl.Text = opened and "[ OPENED ]" or "[ UNOPENED ]"
                    o.stateLbl.TextColor3 = opened and ESP_COLORS.crateOpened or ESP_COLORS.crateState
                    o.distLbl.Text = string.format("[%dm]", math.floor(dist / (SA.STUDS_PER_METER or 3.571)))
                    -- Shared screen-space layout: kind above, distance at
                    -- the left corner, OPENED / UNOPENED at the right.
                    o.tx = {
                        name = CRATE_KIND_LABEL[kind],
                        dist = string.format("%dm", math.floor(dist / (SA.STUDS_PER_METER or 3.571))),
                        tags = { { text = opened and "OPENED" or "UNOPENED", kind = "state" } },
                    }
                end
            end
        end
    end
end

local function enableCrateESP()
    CFG.crateEnabled = true
    SA.RefreshCrates()   -- queues an early incremental walker pass
end

function SA.CrateFovTransitions()
    return crateFovTransitions
end

local function disableCrateESP()
    CFG.crateEnabled = false
    local snap = {}
    for m in pairs(crateObjects) do table.insert(snap, m) end
    for _, m in ipairs(snap) do clearCrate(m) end
end

-- Streamed-in containers ask for one shared walker pass. The render loop
-- reads SA.GetCrates() every frame, so a model whose parts arrive late is
-- retried automatically instead of being dropped forever.
-- Cheap pre-filter: only container-like instances can be crates, so the
-- per-descendant event never calls the classifier on every leaf part.
-- Re-executing the loader replaces these two connections instead of
-- stacking another pair (they capture the current crateObjects table).
if _G.__saCrateEvents then
    for _, c in ipairs(_G.__saCrateEvents) do pcall(function() c:Disconnect() end) end
end
_G.__saCrateEvents = {
    SA.Connect(Workspace.DescendantAdded, function(d)
        if CFG.crateEnabled and (d:IsA("Model") or d:IsA("BasePart")) then
            if crateKind(d) then SA.RequestScan() end
        end
    end),
    SA.Connect(Workspace.DescendantRemoving, function(d)
        if crateObjects[d] then clearCrate(d) end
    end),
}
