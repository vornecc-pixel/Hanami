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
                -- explicit parentheses: `opened and showOpened or not opened`
                -- silently hid every opened crate when the toggle was off
                local stateOk = opened and CFG.crateShowOpened or (not opened)
                local show = allowed and stateOk and pos ~= nil and dist <= CFG.crateMaxDist

                if not show then
                    o.bb.Enabled = false; o.highlight.Enabled = false
                else
                    o.visible, o.pos, o.dist, o.kind, o.opened = true, pos, dist, kind, opened
                    local base = opened and ESP_COLORS.crateOpened
                        or (kind == "Military" and ESP_COLORS.crateMilitary
                        or (kind == "Elite" and ESP_COLORS.crateElite or ESP_COLORS.crateLoot))
                    o.bb.Enabled = true; o.highlight.Enabled = true
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
    SA.RefreshCrates()   -- forces an immediate full Workspace classification
end

local function disableCrateESP()
    CFG.crateEnabled = false
    local snap = {}
    for m in pairs(crateObjects) do table.insert(snap, m) end
    for _, m in ipairs(snap) do clearCrate(m) end
end

-- Debounced rescan for streamed-in containers. The render loop also reads
-- SA.GetCrates() every frame, so a model whose parts arrive late is retried
-- automatically instead of being dropped forever.
local crateScanPending = false
local function requestCrateScan()
    if crateScanPending then return end
    crateScanPending = true
    task.spawn(function()
        task.wait(0.25)
        crateScanPending = false
        if CFG.crateEnabled then pcall(SA.RefreshCrates) end
    end)
end

Workspace.DescendantAdded:Connect(function(d)
    if crateKind(d) then requestCrateScan() end
end)
Workspace.DescendantRemoving:Connect(function(d)
    if crateObjects[d] then clearCrate(d) end
end)
