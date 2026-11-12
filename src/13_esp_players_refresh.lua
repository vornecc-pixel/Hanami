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

-- Reuse the rig references saved by buildESP(). SA.PlayerRig() walks the
-- character with several FindFirstChild / IsA calls; running it twice per
-- entity per frame was pure overhead after the objects were built.
local function refreshPlayerRig(o, char)
    local root, head, hum = o.root, o.head, o.hum
    if o.char == char and root and root.Parent and head and head.Parent and hum then
        return root, head, hum
    end
    root, head, hum = SA.PlayerRig(char)
    o.root, o.head, o.hum = root, head, hum
    return root, head, hum
end

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
    -- The legacy BillboardGui / Highlight are OPTIONAL now: a build that
    -- dropped them (unsupported property on this client) must NOT be
    -- treated as stale, or the object would be cleared and rebuilt in an
    -- endless loop. Only a fallback that still EXISTS but lost its parent
    -- means the rig went away.
    if o.bb and not o.bb.Parent then clearESP(plr); return end
    if o.highlight and not o.highlight.Parent then clearESP(plr); return end

    -- Watch this rig for death / stream-out once (cheap: one guard read).
    if watchCharacter then watchCharacter(plr, char, o) end
    local hrp, head, hum = refreshPlayerRig(o, char)
    if not (hrp and head and hum) then hidePlayerEsp(o); return end
    -- Dead in any way (Health 0, Died fired, humanoid gone): hide the whole
    -- overlay immediately instead of leaving a box on the corpse.
    if (tonumber(hum.Health) or 0) <= 0 then hidePlayerEsp(o); return end

    local dist = 0
    local myRoot = SA.PlayerRig(lp.Character)
    if myRoot then dist = (myRoot.Position - hrp.Position).Magnitude end

    if dist > CFG.espMaxDist then
        -- Teleport / stream-out out of range: drop the cached projection
        -- so a return cannot reuse the old screen position.
        o.geomKey, o.geomCache, o.geomAnchor = nil, nil, nil
        hidePlayerEsp(o); return
    end

    -- GREEN = clear line of sight, RED = behind a wall
    local visible = CFG.espVisibleCheck and SA.IsVisible(char, hrp.Position)
    o.vis = visible
    local col = CFG.espVisibleCheck
        and (visible and ESP_COLORS.playerVisible or ESP_COLORS.playerHidden) or ESP_COLORS.playerFlat

    -- The unified screen-space FX pass owns every name / distance / tag AND
    -- the Highlight. This refresh used to write the same instances again
    -- (Visible / Enabled / FillColor / 4 box lines) at every data interval,
    -- so two writers fought over one instance every few frames — a hidden
    -- legacy label could flash for one frame, and every write was billed
    -- twice against the per-property instance cache. Text is kept (it is
    -- the documented fallback when no screen-space draw exists) but the
    -- legacy labels are never SHOWN while the FX pass is alive.
    local screenSpace = type(SA.HideEspBillboard) == "function"
    -- Every legacy widget may be missing on this client (see buildESP):
    -- the screen-space FX pass is the real renderer, so nil-safe writes
    -- keep the player alive instead of erroring the refresh out.
    if o.bb then o.bb.Enabled = not screenSpace end
    if o.nameLbl then
        o.nameLbl.Text = plr.Name
        o.nameLbl.TextColor3 = col
        o.nameLbl.Visible = (not screenSpace) and CFG.espShowName == true
    end
    if o.distLbl then
        o.distLbl.Text = string.format("[%dm]",
            math.floor(dist / (SA.STUDS_PER_METER or 3.571)))
        o.distLbl.Visible = (not screenSpace) and CFG.espShowDist == true
    end

    -- ── Structured text for the new screen-space Tahoma layout ───────
    -- 18_esp_fx_draw.lua anchors these strings to the box: name above,
    -- distance at the top-LEFT corner, weapon BELOW the box, and the
    -- VIS/WALL + state + HP tags at the top-RIGHT corner. The old
    -- BillboardGui labels are still filled (fallback / legacy state)
    -- but are hidden by the FX pass so no text is drawn twice.
    local info = SA.ScanEntity(char, hum)   -- cached ~0.25 s, safe per frame
    local hpPct = math.floor(100 * math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1))
    local hpText = string.format("HP: %d%%", hpPct)
    local tags = {}
    if CFG.espVisibleCheck then
        tags[#tags + 1] = { text = visible and "VIS" or "WALL", kind = "vis" }
    end
    if CFG.espShowState then
        tags[#tags + 1] = { text = "S: " .. tostring(info.state), kind = "state" }
    end
    if CFG.espShowHealthText then
        tags[#tags + 1] = { text = hpText, kind = "hp" }
    end
    -- Read-only staff / admin role tag. "NONE" is shown for ordinary
    -- players so the toggle answers "admin or not" for every slot; the
    -- AdminESP suffix is the separate replicated flag. Nothing here warns,
    -- notifies, writes an attribute or touches aim / gun state.
    if CFG.espStaffDetect then
        -- THREE consecutive positive scans are required before a role is
        -- shown (04_entity_info.lua). A character that is still streaming
        -- in, a half-replicated rig or one unlucky read can no longer tag
        -- an ordinary player as staff ("INVIS" in the reported build).
        local role = SA.GetStaffRoleConfirmed
            and SA.GetStaffRoleConfirmed(plr, char)
            or SA.GetStaffRole(plr, char)
        local text = role.role
        if role.role == "NONE" and role.pending then
            text = "SCAN"
        elseif role.role == "NONE" and (role.streak or 0) > 0 then
            text = "SCAN " .. tostring(role.streak) .. "/"
                .. tostring(SA.STAFF_CONFIRM_SCANS or 3)
        end
        if role.adminFlag then text = text .. " · ADMINESP" end
        tags[#tags + 1] = { text = text, kind = "staff",
            admin = role.admin == true }
    end
    o.tx = {
        name   = CFG.espShowName and plr.Name or nil,
        dist   = CFG.espShowDist and string.format("%dm", math.floor(dist / (SA.STUDS_PER_METER or 3.571))) or nil,
        weapon = CFG.espShowTool and tostring(info.tool) or nil,
        tags   = tags,
    }

    local bits = {}
    if CFG.espShowTool  then table.insert(bits, "W: " .. info.tool)  end
    if CFG.espShowState then table.insert(bits, "S: " .. info.state) end
    if CFG.espVisibleCheck then
        table.insert(bits, visible and "VIS" or "WALL")
    end
    if CFG.espShowHealthText then table.insert(bits, hpText) end
    if o.infoLbl then
        o.infoLbl.Text = table.concat(bits, " | ")
        o.infoLbl.TextColor3 = col
        o.infoLbl.Visible = #bits > 0
    end

    -- Legacy box geometry is only a fallback; the FX pass owns the box
    -- whenever it is alive. Nil-safe because the line pool is optional.
    if o.lines then
        local g = SA.EspGeom(o, cam, hrp.Position, head.Position, "player")
        if g and g.onScreen and (o.lines.top and o.lines.bottom
            and o.lines.left and o.lines.right) then
            local x, y, w, h = g.x, g.y, g.w, g.h
            o.lines.top.From = Vector2.new(x, y); o.lines.top.To = Vector2.new(x + w, y)
            o.lines.bottom.From = Vector2.new(x, y + h); o.lines.bottom.To = Vector2.new(x + w, y + h)
            o.lines.left.From = Vector2.new(x, y); o.lines.left.To = Vector2.new(x, y + h)
            o.lines.right.From = Vector2.new(x + w, y); o.lines.right.To = Vector2.new(x + w, y + h)
        elseif not screenSpace then
            for _, l in pairs(o.lines) do l.Visible = false end
        end
    end
end

local espErrCount = 0

local function refreshESP()
    local cam = ws.CurrentCamera
    if not cam then return end
    for plr, o in pairs(espObjects) do
        local ok, err = pcall(refreshOnePlayer, plr, o, cam)
        if not ok then
            -- isolate this player, keep the rest of the server updating
            pcall(hidePlayerEsp, o)
            espErrCount = espErrCount + 1
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
local charRemoveHooks = _G.__saPlayerCharRemoveHooks
    or setmetatable({}, { __mode = "k" })
_G.__saPlayerCharRemoveHooks = charRemoveHooks

-- Per-character cleanup. A death / stream-out / rig removal must hide the
-- drawings IMMEDIATELY, not on the next throttled data refresh: that delay
-- is what left a ghost box on a corpse or a frozen name where a streamed
-- player used to be. `hard` also disposes the pooled draws, because they
-- belong to the character that is going away.
local function hideCharEsp(p, o, why)
    if not o then return end
    pcall(hidePlayerEsp, o)
    o.fxUsed, o.linesUsed, o.instApplied = nil, nil, nil
    o.espFovState, o.fovKey = nil, nil
    o.geomKey, o.geomCache, o.geomAnchor, o.geomFresh = nil, nil, nil, nil
    o.vis = nil
    local st = SA.EspGhostCleanup
    if st then
        st.hidden = (st.hidden or 0) + 1
        st.lastReason = tostring(why or "hidden")
    end
end

-- Watch ONE character for the three "stale ESP" events: Humanoid death,
-- the rig losing its Parent (stream-out / CharacterRemoving) and the
-- Humanoid being destroyed (respawn mid-frame).
local function watchCharacter(p, char, o)
    if not char or char == o.watchedChar then return end
    o.watchedChar = char
    local hum = char:FindFirstChildOfClass("Humanoid")
    o.watchedHum = hum
    if hum then
        SA.Connect(hum.Died, function()
            if SA.Alive then hideCharEsp(p, o, "died") end
        end)
        SA.Connect(hum.HealthChanged, function(hp)
            if SA.Alive and (tonumber(hp) or 1) <= 0 then
                hideCharEsp(p, o, "health 0")
            end
        end)
    end
    SA.Connect(char.AncestryChanged, function(_, parent)
        if SA.Alive and parent == nil then hideCharEsp(p, o, "streamed out") end
    end)
end

local function hookPlayer(p)
    if p == lp or charHooks[p] then return end
    local ok, conn = pcall(function()
        return SA.Connect(p.CharacterAdded, function()
            -- No fixed delay: just drop the stale object. The render loop
            -- rebuilds as soon as the new character has usable parts.
            if SA.Alive and CFG.espEnabled then clearESP(p) end
        end)
    end)
    if ok then charHooks[p] = conn end
    if not charRemoveHooks[p] then
        local ok2, conn2 = pcall(function()
            return SA.Connect(p.CharacterRemoving, function()
                -- Respawn started: remove the drawings before the rig goes.
                local o = espObjects[p]
                if o then hideCharEsp(p, o, "character removing") end
                if SA.Alive and CFG.espEnabled then clearESP(p) end
            end)
        end)
        if ok2 then charRemoveHooks[p] = conn2 end
    end
end

for _, p in ipairs(Players:GetPlayers()) do hookPlayer(p) end

-- Replace (do not stack) the service-level connections on re-execute.
if _G.__saPlayerAddedConn then pcall(function() _G.__saPlayerAddedConn:Disconnect() end) end
if _G.__saPlayerRemovingConn then pcall(function() _G.__saPlayerRemovingConn:Disconnect() end) end
_G.__saPlayerAddedConn = SA.Connect(Players.PlayerAdded, hookPlayer)
_G.__saPlayerRemovingConn = SA.Connect(Players.PlayerRemoving, function(p)
    clearESP(p)
    charHooks[p] = nil
    charRemoveHooks[p] = nil
end)
