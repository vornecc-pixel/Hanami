-- ==================================================================
-- Hanami / 15_esp_npcs_refresh.lua — NPC ESP per-frame refresh
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================

local function npcRefreshRig(o, model)
    local hum, hrp, head = o.hum, o.root, o.head
    if model.Parent and hum and hrp and hrp.Parent and head and head.Parent then
        return hum, hrp, head
    end
    hum  = model.Parent and model:FindFirstChildOfClass("Humanoid")
    hrp  = model.Parent and (model:FindFirstChild("HumanoidRootPart")
        or model:FindFirstChild("Head"))
    head = model.Parent and (model:FindFirstChild("Head") or hrp)
    o.hum, o.root, o.head = hum, hrp, head
    return hum, hrp, head
end

-- Split the per-NPC work in two, like the player pipeline:
--   * the CHEAP branch (every refresh): rig validity, distance, LOS colour,
--     legacy line / BillboardGui visibility and the visibility flag;
--   * the EXPENSIVE branch (throttled to the ESP data interval): the
--     SA.ScanEntity tag read (tool + state + attributes) and the full
--     screen-space text rebuild.
-- refreshNpcESP() used to run BOTH for every NPC on every data refresh,
-- and then the FX pass re-drew the same NPC again on the same frame. That
-- duplicate work is the "NPC ESP is not smooth" report: with a dozen
-- guards the scan/text rebuild dominated the frame while the player ESP
-- only paid it once per interval.
local lastNpcFullRefresh = -1
local function npcFullDue()
    local frame = SA.EspFxFrame or 0
    local interval = 6
    if type(SA.EspDataIntervalFrames) == "function" then
        interval = math.max(SA.EspDataIntervalFrames(), 1)
    end
    if frame < (lastNpcFullRefresh or 0) then lastNpcFullRefresh = -1 end
    if (frame - (lastNpcFullRefresh or -1)) >= interval then
        lastNpcFullRefresh = frame
        return true
    end
    return false
end

local function refreshNpcESP()
    local cam = ws.CurrentCamera
    if not cam then return end
    local full = npcFullDue()
    for model, o in pairs(npcObjects) do
        local hum, hrp, head = npcRefreshRig(o, model)
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
                o.linesUsed = nil
                o.geomKey, o.geomCache, o.geomAnchor = nil, nil, nil
            else
                -- GREEN = clear line of sight, RED = behind a wall
                local visible = CFG.npcVisibleCheck and SA.IsVisible(model, hrp.Position)
                o.vis = visible
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

                -- Cheap branch ends here every frame: the FX pass owns
                -- the actual drawing, and the legacy lines above are
                -- hidden by it. Only the throttled pass rebuilds text.
                if not full and o.tx then
                    o.txVis = visible
                else
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

                end
                local g = SA.EspGeom(o, cam, hrp.Position, head.Position, "npc")
                if g and g.onScreen then
                    local x, y, w, h = g.x, g.y, g.w, g.h
                    o.lines.top.From = Vector2.new(x, y); o.lines.top.To = Vector2.new(x + w, y)
                    o.lines.bottom.From = Vector2.new(x, y + h); o.lines.bottom.To = Vector2.new(x + w, y + h)
                    o.lines.left.From = Vector2.new(x, y); o.lines.left.To = Vector2.new(x, y + h)
                    o.lines.right.From = Vector2.new(x + w, y); o.lines.right.To = Vector2.new(x + w, y + h)
                    for _, l in pairs({ o.lines.top, o.lines.bottom, o.lines.left, o.lines.right }) do
                        l.Color = col; l.Visible = true
                    end
                    if CFG.npcShowHealth then
                        local hx = x - 4
                        local ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                        o.lines.hpBg.From = Vector2.new(hx, y); o.lines.hpBg.To = Vector2.new(hx, y + h)
                        o.lines.hpBg.Color = Color3.fromRGB(20, 20, 20); o.lines.hpBg.Visible = true
                        o.lines.hpFill.From = Vector2.new(hx, y + (h - h * ratio))
                        o.lines.hpFill.To = Vector2.new(hx, y + h)
                        o.lines.hpFill.Color = ratio > 0.5 and Color3.fromRGB(60, 255, 100)
                            or Color3.fromRGB(255, 220, 60):Lerp(Color3.fromRGB(255, 60, 60), 1 - ratio * 2)
                        o.lines.hpFill.Visible = true
                    else o.lines.hpBg.Visible = false; o.lines.hpFill.Visible = false end
                else for _, l in pairs(o.lines) do l.Visible = false end end
            end
        end
    end
end
