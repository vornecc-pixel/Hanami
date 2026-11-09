-- ==================================================================
-- Hanami / 15_esp_npcs_refresh.lua — NPC ESP per-frame refresh
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================

local function refreshNpcESP()
    local cam = ws.CurrentCamera
    if not cam then return end
    for model, o in pairs(npcObjects) do
        local hum  = model.Parent and model:FindFirstChildOfClass("Humanoid")
        local hrp  = model.Parent and (model:FindFirstChild("HumanoidRootPart")
            or model:FindFirstChild("Head"))
        local head = model.Parent and (model:FindFirstChild("Head") or hrp)
        if not (model.Parent and hum and hum.Health > 0 and hrp and head) then
            clearNpc(model)
        else
            local dist = 0
            if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
                dist = (lp.Character.HumanoidRootPart.Position - hrp.Position).Magnitude
            end
            if dist > CFG.npcMaxDist then
                o.bb.Enabled = false; o.highlight.Enabled = false
                for _, l in pairs(o.lines) do l.Visible = false end
            else
                -- GREEN = clear line of sight, RED = behind a wall
                local visible = CFG.npcVisibleCheck and SA.IsVisible(model, hrp.Position)
                local col = CFG.npcVisibleCheck
                    and (visible and ESP_COLORS.npcVisible or ESP_COLORS.npcHidden) or ESP_COLORS.npcFlat

                o.bb.Enabled = true; o.highlight.Enabled = true
                o.highlight.FillColor = col
                o.nameLbl.Visible = CFG.npcShowName
                o.nameLbl.Text = "[NPC] " .. model.Name
                o.nameLbl.TextColor3 = col
                if CFG.npcShowDist then
                    o.distLbl.Visible = true
                    o.distLbl.Text = string.format("[%dm]", math.floor(dist / (SA.STUDS_PER_METER or 3.571)))
                else o.distLbl.Visible = false end

                -- Structured text shared with the player layout: weapon
                -- below the box, VIS/WALL + state + HP at the corner.
                local info = SA.ScanEntity(model, hum)
                local hpText = string.format("HP: %d%%",
                    math.floor(100 * math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)))
                local tags = {}
                if CFG.npcVisibleCheck then
                    tags[#tags + 1] = { text = visible and "VIS" or "WALL", kind = "vis" }
                end
                if CFG.npcShowState then
                    tags[#tags + 1] = { text = "S: " .. tostring(info.state), kind = "state" }
                end
                if CFG.espShowHealthText then
                    tags[#tags + 1] = { text = hpText, kind = "hp" }
                end
                o.tx = {
                    name   = CFG.npcShowName and ("[NPC] " .. model.Name) or nil,
                    dist   = CFG.npcShowDist and string.format("%dm", math.floor(dist / (SA.STUDS_PER_METER or 3.571))) or nil,
                    weapon = CFG.npcShowTool and tostring(info.tool) or nil,
                    tags   = tags,
                }

                local bits = {}
                if CFG.npcShowTool  then table.insert(bits, "W: " .. info.tool)  end
                if CFG.npcShowState then table.insert(bits, "S: " .. info.state) end
                if CFG.npcVisibleCheck then
                    table.insert(bits, visible and "VIS" or "WALL")
                end
                if CFG.espShowHealthText then table.insert(bits, hpText) end
                o.infoLbl.Text = table.concat(bits, " | ")
                o.infoLbl.TextColor3 = col
                o.infoLbl.Visible = #bits > 0

                local hrpPos, onScreen = cam:WorldToViewportPoint(hrp.Position)
                local headPos = cam:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
                local legPos  = cam:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
                if onScreen then
                    local height = math.abs(headPos.Y - legPos.Y)
                    local width  = height / 2
                    local x = hrpPos.X - width / 2
                    local y = headPos.Y
                    o.lines.top.From = Vector2.new(x, y); o.lines.top.To = Vector2.new(x + width, y)
                    o.lines.bottom.From = Vector2.new(x, y + height); o.lines.bottom.To = Vector2.new(x + width, y + height)
                    o.lines.left.From = Vector2.new(x, y); o.lines.left.To = Vector2.new(x, y + height)
                    o.lines.right.From = Vector2.new(x + width, y); o.lines.right.To = Vector2.new(x + width, y + height)
                    for _, l in pairs({ o.lines.top, o.lines.bottom, o.lines.left, o.lines.right }) do
                        l.Color = col; l.Visible = true
                    end
                    if CFG.npcShowHealth then
                        local hx = x - 4
                        local ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                        o.lines.hpBg.From = Vector2.new(hx, y); o.lines.hpBg.To = Vector2.new(hx, y + height)
                        o.lines.hpBg.Color = Color3.fromRGB(20, 20, 20); o.lines.hpBg.Visible = true
                        o.lines.hpFill.From = Vector2.new(hx, y + (height - height * ratio))
                        o.lines.hpFill.To = Vector2.new(hx, y + height)
                        o.lines.hpFill.Color = ratio > 0.5 and Color3.fromRGB(60, 255, 100)
                            or Color3.fromRGB(255, 220, 60):Lerp(Color3.fromRGB(255, 60, 60), 1 - ratio * 2)
                        o.lines.hpFill.Visible = true
                    else o.lines.hpBg.Visible = false; o.lines.hpFill.Visible = false end
                else for _, l in pairs(o.lines) do l.Visible = false end end
            end
        end
    end
end
