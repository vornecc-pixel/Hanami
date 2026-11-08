-- ==================================================================
-- Hanami / 13_esp_players_refresh.lua — Player ESP refresh + enable/disable
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- PLAYER ESP REFRESH
-- One bad player used to abort this whole loop: an unguarded Raycast,
-- a missing part or a failed Drawing write would throw and every player
-- after it in pairs(espObjects) simply stopped updating for the frame.
-- Each player is now refreshed inside its own pcall, so a problem with
-- one character can never hide the rest of the server.
-- ────────────────────────────────────────────────────────────────────

local function hidePlayerEsp(o)
    if not o then return end
    pcall(function() if o.bb then o.bb.Enabled = false end end)
    pcall(function() if o.highlight then o.highlight.Enabled = false end end)
    if o.lines then
        for _, l in pairs(o.lines) do pcall(function() l.Visible = false end) end
    end
    if type(hideFx) == "function" then pcall(hideFx, o) end
end

local function refreshOnePlayer(plr, o, cam)
    if not plr.Parent then clearESP(plr); return end
    local char = plr.Character
    if not char then clearESP(plr); return end

    -- Respawn / manual character swap / streaming rebuild. The objects
    -- are parented to the OLD character, so they can never come back on
    -- their own. Dropping them lets the render loop rebuild on the new one.
    if o.char and o.char ~= char then clearESP(plr); return end
    if o.bb and not o.bb.Parent then clearESP(plr); return end
    if o.highlight and not o.highlight.Parent then clearESP(plr); return end

    local hrp, head, hum = SA.PlayerRig(char)
    if not (hrp and head and hum) then hidePlayerEsp(o); return end
    if hum.Health <= 0 then hidePlayerEsp(o); return end

    local dist = 0
    local myRoot = SA.PlayerRig(lp.Character)
    if myRoot then dist = (myRoot.Position - hrp.Position).Magnitude end

    if dist > CFG.espMaxDist then
        hidePlayerEsp(o); return
    end

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
    if onScreen and hrpPos.Z > 0 then
        local headPos = cam:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
        local legPos  = cam:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
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
    else
        for _, l in pairs(o.lines) do l.Visible = false end
    end
end

local espErrAt, espErrCount = 0, 0

local function refreshESP()
    local cam = ws.CurrentCamera
    if not cam then return end
    for plr, o in pairs(espObjects) do
        local ok, err = pcall(refreshOnePlayer, plr, o, cam)
        if not ok then
            -- isolate this player, keep the rest of the server updating
            pcall(hidePlayerEsp, o)
            espErrCount = espErrCount + 1
            local now = tick()
            if now - espErrAt > 5 then
                espErrAt = now
                warn("[esp] player refresh error (" .. espErrCount .. " total): " .. tostring(err))
            end
        end
    end
end

local function enableESP()
    CFG.espEnabled = true
    -- hook everyone already in the server, not just future joiners
    if type(hookPlayer) == "function" then
        for _, p in ipairs(Players:GetPlayers()) do hookPlayer(p) end
    end
end
local function disableESP()
    CFG.espEnabled = false
    local snap = {}
    for plr in pairs(espObjects) do table.insert(snap, plr) end
    for _, plr in ipairs(snap) do clearESP(plr) end
end

-- ── Character lifecycle ───────────────────────────────────────────────
-- The old code connected CharacterAdded ONLY inside PlayerAdded, so every
-- player already in the server when Hanami loaded had NO respawn handler.
-- After one death their ESP objects stayed attached to the removed
-- character and never came back. Hook existing players too, and reuse the
-- connections across re-executes instead of stacking them.
local charHooks = _G.__saPlayerCharHooks or setmetatable({}, { __mode = "k" })
_G.__saPlayerCharHooks = charHooks

local function hookPlayer(p)
    if p == lp or charHooks[p] then return end
    local ok, conn = pcall(function()
        return p.CharacterAdded:Connect(function()
            -- No fixed delay: just drop the stale object. The render loop
            -- rebuilds as soon as the new character has usable parts.
            if SA.Alive and CFG.espEnabled then clearESP(p) end
        end)
    end)
    if ok then charHooks[p] = conn end
end

for _, p in ipairs(Players:GetPlayers()) do hookPlayer(p) end

-- Replace (do not stack) the service-level connections on re-execute.
if _G.__saPlayerAddedConn then pcall(function() _G.__saPlayerAddedConn:Disconnect() end) end
if _G.__saPlayerRemovingConn then pcall(function() _G.__saPlayerRemovingConn:Disconnect() end) end
_G.__saPlayerAddedConn = Players.PlayerAdded:Connect(hookPlayer)
_G.__saPlayerRemovingConn = Players.PlayerRemoving:Connect(function(p)
    clearESP(p)
    charHooks[p] = nil
end)
