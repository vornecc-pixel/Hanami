-- ==================================================================
-- Hanami / 13_esp_players_refresh.lua — Player ESP refresh + enable/disable
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================

local function refreshESP()
    local cam = ws.CurrentCamera
    if not cam then return end
    for plr, o in pairs(espObjects) do
        local char = plr.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        local head = char and char:FindFirstChild("Head")
        if not (char and hum and hum.Health > 0 and hrp and head) then
            clearESP(plr)
        else
            local dist = 0
            if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
                dist = (lp.Character.HumanoidRootPart.Position - hrp.Position).Magnitude
            end
            if dist > CFG.espMaxDist then
                o.bb.Enabled = false; o.highlight.Enabled = false
                for _, l in pairs(o.lines) do l.Visible = false end
            else
                -- GREEN = clear line of sight, RED = behind a wall
                local visible = CFG.espVisibleCheck and SA.IsVisible(char, hrp.Position)
                local col = CFG.espVisibleCheck
                    and (visible and ESP_COLORS.playerVisible or ESP_COLORS.playerHidden) or ESP_COLORS.playerFlat

                o.bb.Enabled = true; o.highlight.Enabled = true
                o.highlight.FillColor = col
                o.nameLbl.Visible = CFG.espShowName
                o.nameLbl.Text = plr.Name
                o.nameLbl.TextColor3 = col
                if CFG.espShowDist then
                    o.distLbl.Visible = true
                    o.distLbl.Text = string.format("[%dm]", math.floor(dist / 3.571))
                else o.distLbl.Visible = false end

                local bits = {}
                if CFG.espShowTool or CFG.espShowState then
                    local info = SA.ScanEntity(char, hum)
                    if CFG.espShowTool  then table.insert(bits, "W: " .. info.tool)  end
                    if CFG.espShowState then table.insert(bits, "S: " .. info.state) end
                end
                if CFG.espVisibleCheck then
                    table.insert(bits, visible and "VIS" or "WALL")
                end
                if CFG.espShowHealthText then
                    table.insert(bits, string.format("HP: %d%%",
                        math.floor(100 * math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1))))
                end
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
                    if CFG.espShowHealth then
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

local function enableESP()
    CFG.espEnabled = true
    -- the render loop builds at most MAX_BUILDS objects per frame; building
    -- every player in one callback used to freeze the frame on toggle
end
local function disableESP()
    CFG.espEnabled = false
    local snap = {}
    for plr in pairs(espObjects) do table.insert(snap, plr) end
    for _, plr in ipairs(snap) do clearESP(plr) end
end

Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function()
        task.wait(0.5)
        if CFG.espEnabled then buildESP(p) end
    end)
end)
Players.PlayerRemoving:Connect(function(p) clearESP(p) end)
