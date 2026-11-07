-- ==================================================================
-- Hanami / 17_esp_crates_refresh.lua — Crate ESP refresh + enable/disable
-- Loaded in order by loader.lua. Parts are joined into ONE chunk
-- before running, so every `local` is shared just like the original.
-- ==================================================================

local function refreshCrateESP()
    local myRoot = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
    local myPos = myRoot and myRoot.Position or nil

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

                if not show then
                    o.bb.Enabled = false; o.highlight.Enabled = false
                else
                    o.visible, o.pos, o.dist, o.kind, o.opened = true, pos, dist, kind, opened
                    local base = opened and ESP_COLORS.crateOpened
                        or (kind == "Military" and ESP_COLORS.crateMilitary
                        or (kind == "Elite" and ESP_COLORS.crateElite or ESP_COLORS.crateLoot))
                    o.bb.Enabled = true
                    o.highlight.Enabled = CFG.crateHighlight
                    o.highlight.FillColor = base
                    o.highlight.OutlineColor = base
                    o.nameLbl.TextColor3 = base
                    o.nameLbl.Text = CRATE_KIND_LABEL[kind]
                    o.stateLbl.Text = opened and "[ OPENED ]" or "[ UNOPENED ]"
                    o.stateLbl.TextColor3 = opened and ESP_COLORS.crateOpened or ESP_COLORS.crateState
                    o.distLbl.Text = string.format("[%dm]", math.floor(dist / 3.571))
                end
            end
        end
    end
end

local function enableCrateESP()
    CFG.crateEnabled = true
    SA.RefreshCrates()   -- queues an early incremental walker pass
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
    Workspace.DescendantAdded:Connect(function(d)
        if CFG.crateEnabled and (d:IsA("Model") or d:IsA("BasePart")) then
            if crateKind(d) then SA.RequestScan() end
        end
    end),
    Workspace.DescendantRemoving:Connect(function(d)
        if crateObjects[d] then clearCrate(d) end
    end),
}
