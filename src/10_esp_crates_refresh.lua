-- ==================================================================
-- Hanami / 10_esp_crates_refresh.lua — Crate ESP refresh, scanning, events
-- Loaded in order by loader.lua. Parts are joined into ONE chunk
-- before running, so every `local` is shared just like the original.
-- ==================================================================

local function refreshCrateESP()
    for model, o in pairs(crateObjects) do
        if not model.Parent then clearCrate(model)
        else
            local crateKind = CRATE_NAMES[model.Name]
            if not crateKind then clearCrate(model)
            else
                local allowedType = (crateKind == "Military" and CFG.crateShowMilitary)
                                 or (crateKind == "Elite"    and CFG.crateShowElite)
                local pos = cratePivotPos(model)
                local dist = 0
                if pos and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
                    dist = (lp.Character.HumanoidRootPart.Position - pos).Magnitude
                end
                local opened  = isCrateOpened(model)
                local stateOk = opened and CFG.crateShowOpened or not opened
                local visible = allowedType and stateOk and dist <= CFG.crateMaxDist
                if not visible then
                    o.bb.Enabled = false; o.highlight.Enabled = false
                else
                    o.bb.Enabled = true; o.highlight.Enabled = true
                    local baseColor = opened and crateColorOpened
                        or (crateKind == "Military" and crateColorMilitary or crateColorElite)
                    o.highlight.FillColor = baseColor
                    o.highlight.OutlineColor = baseColor
                    o.nameLbl.TextColor3 = baseColor
                    o.nameLbl.Text = crateKind .. " Crate"
                    o.stateLbl.Text = opened and "[ OPENED ]" or "[ UNOPENED ]"
                    o.stateLbl.TextColor3 = opened
                        and Color3.fromRGB(200, 200, 200) or Color3.fromRGB(60, 255, 120)
                    o.distLbl.Text = string.format("[%dm]", math.floor(dist / 3.571))
                end
            end
        end
    end
end

local function enableCrateESP()
    CFG.crateEnabled = true
    for _, d in ipairs(Workspace:GetDescendants()) do
        if CRATE_NAMES[d.Name] then buildCrate(d) end
    end
end
local function disableCrateESP()
    CFG.crateEnabled = false
    local snap = {}
    for m in pairs(crateObjects) do table.insert(snap, m) end
    for _, m in ipairs(snap) do clearCrate(m) end
end

Workspace.DescendantAdded:Connect(function(d)
    if CFG.crateEnabled and CRATE_NAMES[d.Name] then
        task.wait(0.1)
        if d.Parent then buildCrate(d) end
    end
end)
Workspace.DescendantRemoving:Connect(function(d)
    if crateObjects[d] then clearCrate(d) end
end)

