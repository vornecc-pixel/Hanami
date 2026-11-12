-- ==================================================================
-- Hanami / 03_entity_scan.lua — NPC registry + LOS visibility check
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- NPC REGISTRY
-- Feeds the shared incremental walker in 02_workspace_scan.lua. No
-- GetDescendants() and no per-frame work: the walker yields every 120
-- nodes, so a big map never freezes a frame.
-- ────────────────────────────────────────────────────────────────────

local npcList = _G.__saNpcList or {}
_G.__saNpcList = npcList

local function validNpc(d)
    if not d or not d:IsA("Model") then return false end
    if not isNpc(d) then return false end
    if not d:FindFirstChildOfClass("Humanoid") then return false end
    if not (d:FindFirstChild("Head") or d:FindFirstChild("HumanoidRootPart")) then
        return false
    end
    return Players:GetPlayerFromCharacter(d) == nil  -- never tag a real player
end

local function commitNpcs(found)
    for i = #npcList, 1, -1 do npcList[i] = nil end
    for _, m in ipairs(found) do npcList[#npcList + 1] = m end
end

SA.RegisterScanHandler("npcs", validNpc, commitNpcs)

function SA.GetNpcs()
    local out = {}
    for _, m in ipairs(npcList) do
        if m.Parent and m:FindFirstChildOfClass("Humanoid") then
            out[#out + 1] = m
        end
    end
    return out
end

-- The render loop walks this live list directly instead of allocating a
-- filtered copy every frame. Invalid entries are skipped by buildBatch().
function SA.NpcListRaw() return npcList end

-- Rescan buttons just ask the shared walker for an early pass; no
-- synchronous full-workspace scan can stall the client here.
function SA.RefreshNpcs()
    SA.RequestScan()
    return SA.GetNpcs()
end

if not _G.__saNpcEvents then
    _G.__saNpcEvents = true
    SA.Connect(ws.DescendantAdded, function(d)
        if NPC_NAMES[d.Name] then SA.RequestScan() end
    end)
    SA.Connect(ws.DescendantRemoving, function(d)
        if NPC_NAMES[d.Name] then SA.RequestScan() end
    end)
end

-- ────────────────────────────────────────────────────────────────────
-- VISIBILITY (LOS)
-- Cached ~120 ms per model so a 30-player server costs ~30 raycasts per
-- 0.12 s instead of 30 raycasts every single frame.
-- ────────────────────────────────────────────────────────────────────

local visParams = RaycastParams.new()
visParams.FilterType = Enum.RaycastFilterType.Exclude
visParams.IgnoreWater = true
local visCache = setmetatable({}, { __mode = "k" })
local VIS_TTL = 0.12

function SA.IsVisible(model, pos)
    if not model or not pos then return false end
    local now = tick()
    local e = visCache[model]
    if e and (now - e.t) < VIS_TTL then return e.vis end
    local cam = ws.CurrentCamera
    if not cam then return true end
    -- A single LOS failure must not abort the whole ESP refresh loop.
    -- Zero-length rays are degenerate; treat them as "visible".
    local ok, vis = pcall(function()
        local filter = {}
        if lp.Character then table.insert(filter, lp.Character) end
        table.insert(filter, model)
        visParams.FilterDescendantsInstances = filter
        local origin = cam.CFrame.Position
        local dir = pos - origin
        local mag = dir.Magnitude
        if mag < 0.001 then return true end
        local hit = ws:Raycast(origin, dir, visParams)
        return (hit == nil) or (hit.Distance >= mag - 0.5)
    end)
    if not ok then return true end
    visCache[model] = { t = now, vis = vis }
    return vis
end

-- ── NEAREST PLAYER PROFILE CARD ─────────────────────────────────────
-- Kept in this low-register part so the joined Luau chunk stays under the
-- 200-register limit. All UI controls remain in 24_ui_visual.lua.
-- ── NEAREST PLAYER HUD (visible while the menu is hidden) ───────────
-- When the Atlanta menu is minimised / toggled off with RightShift, a small
-- companion profile card shows the closest OTHER player: Roblox headshot,
-- display / account name, distance, health, VIS / team state, weapon name
-- and a separate EQUIPPED / HOLSTERED / UNKNOWN chip. It is deliberately
-- NOT part of library.guis, so set_menu_visibility(false) cannot disable it.
-- The header is a real pointer-drag handle; Frame.Draggable is only kept as
-- a legacy fallback because Roblox deprecated that property years ago.
if SA.NearestWindowDispose then pcall(SA.NearestWindowDispose) end
local savedPos = _G.__saNearestWindowPos
local saNearest = {
    dragged = savedPos ~= nil,
    posX = savedPos and tonumber(savedPos.x) or nil,
    posY = savedPos and tonumber(savedPos.y) or nil,
}
_G.__saNearestWindow = saNearest

local function saNearestParent()
    local parent = nil
    pcall(function()
        if typeof(gethui) == "function" then parent = gethui() end
    end)
    if not parent then
        pcall(function() parent = lp:FindFirstChildOfClass("PlayerGui") end)
    end
    if not parent then
        pcall(function() parent = game:GetService("CoreGui") end)
    end
    return parent
end

function SA.NearestWindowDispose()
    for _, key in ipairs({ "conn", "dragBegan", "dragChanged", "dragEnded" }) do
        local c = saNearest[key]
        if c then pcall(function() c:Disconnect() end) end
    end
    if saNearest.gui then pcall(function() saNearest.gui:Destroy() end) end
    saNearest.gui, saNearest.frame, saNearest.header = nil, nil, nil
    saNearest.avatar, saNearest.initials, saNearest.nameLbl = nil, nil, nil
    saNearest.metaLbl, saNearest.weaponLbl, saNearest.stateLbl = nil, nil, nil
    saNearest.label, saNearest.conn = nil, nil
    saNearest.dragBegan, saNearest.dragChanged, saNearest.dragEnded = nil, nil, nil
    saNearest.built, saNearest.visible, saNearest.dragging = false, false, false
    saNearest.avatarUserId, saNearest.avatarImage = nil, nil
    saNearest.avatarPending, saNearest.avatarFailed = false, false
    saNearest.reason = "disposed"
end

local function saNearestRect(inst, x, y, w, h)
    if not inst then return end
    pcall(function()
        inst.Position = UDim2.fromOffset(x, y)
        inst.Size = UDim2.fromOffset(w, h)
    end)
end

local function saNearestTextSize(inst, size)
    if not inst then return end
    pcall(function() inst.TextSize = math.max(6, math.floor(size)) end)
end

local function saNearestClamp(x, y, w, h)
    local vp = SA.ViewportSize()
    local maxX = math.max(0, (tonumber(vp.X) or 1280) - w)
    local maxY = math.max(0, (tonumber(vp.Y) or 720) - h)
    return math.clamp(x, 0, maxX), math.clamp(y, 0, maxY)
end

local function saNearestWritePosition(x, y)
    saNearest.posX, saNearest.posY = x, y
    if saNearest.frame then
        pcall(function() saNearest.frame.Position = UDim2.fromOffset(x, y) end)
    end
end

local function saNearestPersistPosition(x, y)
    saNearest.dragged = true
    _G.__saNearestWindowPos = { x = x, y = y }
    saNearestWritePosition(x, y)
end

local function saNearestCornerPosition(corner, w, h, scale)
    local vp = SA.ViewportSize()
    local m = math.max(4, math.floor(12 * scale))
    local x, y = m, m
    if corner == "Top Right" or corner == "Bottom Right" then
        x = math.max(0, (tonumber(vp.X) or 1280) - w - m)
    end
    if corner == "Bottom Left" or corner == "Bottom Right" then
        y = math.max(0, (tonumber(vp.Y) or 720) - h - m)
    end
    return x, y
end

local function saNearestApplyLayout(force)
    if not saNearest.frame then return end
    local scale = tonumber(CFG.nearestScale) or 1
    local n = math.floor(tonumber(CFG.nearestTopN) or 1)
    local extra = (CFG.showNoTargetReason and 1 or 0)
        + (CFG.perfShowFps and 1 or 0)
    local corner = CFG.nearestCorner or "Top Left"
    local transparency = math.clamp((tonumber(CFG.nearestTransparency) or 12) / 100, 0, 0.95)
    local vp = SA.ViewportSize()
    local key = table.concat({ scale, n, extra, corner, transparency,
        saNearest.dragged and 1 or 0, vp.X, vp.Y }, "|")
    if not force and saNearest.layoutKey == key then return end
    saNearest.layoutKey = key
    local w = math.floor(320 * scale)
    local h = math.floor((112 + 15 * (n + 1 + extra)) * scale)
    local contentW = math.max(40, w - math.floor(84 * scale))
    local labelH = math.max(16, h - math.floor(110 * scale))
    local avatarSize = math.floor(56 * scale)
    local headerH = math.floor(26 * scale)
    local margin = math.floor(10 * scale)
    local profileX = math.floor(74 * scale)
    saNearest.layoutW, saNearest.layoutH = w, h
    pcall(function()
        saNearest.frame.Size = UDim2.fromOffset(w, h)
        saNearest.frame.BackgroundTransparency = transparency
        saNearest.header.Size = UDim2.fromOffset(w, headerH)
        saNearest.header.TextSize = math.floor(11 * scale)
        saNearestRect(saNearest.avatar, margin, math.floor(34 * scale),
            avatarSize, avatarSize)
        saNearestTextSize(saNearest.initials, 20 * scale)
        saNearestRect(saNearest.nameLbl, profileX, math.floor(32 * scale),
            contentW, math.floor(18 * scale))
        saNearestTextSize(saNearest.nameLbl, 13 * scale)
        saNearestRect(saNearest.metaLbl, profileX, math.floor(50 * scale),
            contentW, math.floor(16 * scale))
        saNearestTextSize(saNearest.metaLbl, 10 * scale)
        saNearestRect(saNearest.weaponLbl, profileX, math.floor(68 * scale),
            contentW, math.floor(16 * scale))
        saNearestTextSize(saNearest.weaponLbl, 10 * scale)
        saNearestRect(saNearest.stateLbl, profileX, math.floor(86 * scale),
            math.floor(92 * scale), math.floor(16 * scale))
        saNearestTextSize(saNearest.stateLbl, 9 * scale)
        saNearestRect(saNearest.label, margin, math.floor(104 * scale),
            math.max(40, w - margin * 2), labelH)
        saNearestTextSize(saNearest.label, 11 * scale)
    end)
    if saNearest.dragged and saNearest.posX and saNearest.posY then
        local x, y = saNearestClamp(saNearest.posX, saNearest.posY, w, h)
        saNearestWritePosition(x, y)
    else
        local x, y = saNearestCornerPosition(corner, w, h, scale)
        saNearestWritePosition(x, y)
    end
end

local function saNearestDragInput(input)
    return input and (input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch)
end

local function saNearestInputPoint(input)
    local p = input and input.Position or nil
    if p and tonumber(p.X) and tonumber(p.Y) then
        return tonumber(p.X), tonumber(p.Y)
    end
    local ok, aim = pcall(function() return SA.AimPoint() end)
    if ok and aim then return aim.X, aim.Y end
    return 0, 0
end

local function saNearestAttachDrag()
    if not saNearest.header then return end
    pcall(function()
        saNearest.dragBegan = SA.Connect(saNearest.header.InputBegan, function(input)
            if not saNearestDragInput(input) then return end
            local x, y = saNearestInputPoint(input)
            saNearest.dragging = true
            saNearest.dragStart = Vector2.new(x, y)
            saNearest.dragOrigin = Vector2.new(saNearest.posX or 12,
                                               saNearest.posY or 12)
        end)
    end)
    pcall(function()
        saNearest.dragChanged = SA.Connect(UserInputService.InputChanged, function(input)
            if not saNearest.dragging or not input then return end
            if input.UserInputType ~= Enum.UserInputType.MouseMovement
                and input.UserInputType ~= Enum.UserInputType.Touch then return end
            local px, py = saNearestInputPoint(input)
            local start = saNearest.dragStart or Vector2.new(px, py)
            local origin = saNearest.dragOrigin or Vector2.new(12, 12)
            local x = origin.X + px - start.X
            local y = origin.Y + py - start.Y
            local w = saNearest.layoutW or 320
            local h = saNearest.layoutH or 142
            x, y = saNearestClamp(x, y, w, h)
            saNearestPersistPosition(x, y)
        end)
    end)
    pcall(function()
        saNearest.dragEnded = SA.Connect(UserInputService.InputEnded, function(input)
            if saNearestDragInput(input) then saNearest.dragging = false end
        end)
    end)
end

local function saNearestBuild()
    local parent = saNearestParent()
    if not parent then
        saNearest.reason = "no PlayerGui / CoreGui / gethui parent"
        return false
    end
    local ok, err = pcall(function()
        local gui = Instance.new("ScreenGui")
        gui.Name = "HanamiNearestPlayer"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.DisplayOrder = 997
        gui.Enabled = false
        gui.Parent = parent

        local frame = Instance.new("Frame")
        frame.Name = "Panel"
        frame.Size = UDim2.fromOffset(320, 142)
        frame.BackgroundColor3 = Color3.fromRGB(16, 18, 26)
        frame.BackgroundTransparency = 0.12
        frame.BorderSizePixel = 0
        frame.Active = true
        frame.Parent = gui
        pcall(function() frame.Draggable = true end)
        pcall(function()
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0.04, 0)
            corner.Parent = frame
        end)
        pcall(function()
            local stroke = Instance.new("UIStroke")
            stroke.Color = Color3.fromRGB(90, 110, 160)
            stroke.Thickness = 1
            stroke.Transparency = 0.25
            stroke.Parent = frame
        end)

        local header = Instance.new("TextButton")
        header.Name = "DragHandle"
        header.BackgroundColor3 = Color3.fromRGB(24, 28, 42)
        header.BackgroundTransparency = 0.08
        header.BorderSizePixel = 0
        header.Text = "NEAREST PLAYER  ·  DRAG TO MOVE"
        header.TextColor3 = Color3.fromRGB(220, 230, 255)
        header.TextXAlignment = Enum.TextXAlignment.Left
        header.TextYAlignment = Enum.TextYAlignment.Center
        header.TextSize = 11
        header.Active = true
        header.Selectable = false
        header.AutoButtonColor = false
        header.Parent = frame
        pcall(function() SA.ApplyEspFont(header) end)

        local avatar = Instance.new("ImageLabel")
        avatar.Name = "Avatar"
        avatar.BackgroundColor3 = Color3.fromRGB(35, 40, 58)
        avatar.BorderSizePixel = 0
        avatar.Image = ""
        avatar.Parent = frame
        pcall(function() avatar.ScaleType = Enum.ImageScaleType.Crop end)
        pcall(function()
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0.5, 0)
            corner.Parent = avatar
        end)
        pcall(function()
            local stroke = Instance.new("UIStroke")
            stroke.Color = Color3.fromRGB(120, 145, 210)
            stroke.Thickness = 1
            stroke.Transparency = 0.35
            stroke.Parent = avatar
        end)

        local initials = Instance.new("TextLabel")
        initials.Name = "AvatarInitials"
        initials.Size = UDim2.new(1, 0, 1, 0)
        initials.BackgroundTransparency = 1
        initials.Text = "?"
        initials.TextColor3 = Color3.fromRGB(235, 240, 255)
        initials.TextXAlignment = Enum.TextXAlignment.Center
        initials.TextYAlignment = Enum.TextYAlignment.Center
        initials.TextSize = 20
        initials.Visible = true
        initials.Parent = avatar
        pcall(function() SA.ApplyEspFont(initials) end)

        local function profileLabel(name, text, size, colour)
            local lbl = Instance.new("TextLabel")
            lbl.Name = name
            lbl.BackgroundTransparency = 1
            lbl.Text = text
            lbl.TextColor3 = colour
            lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
            lbl.TextStrokeTransparency = 0
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.TextYAlignment = Enum.TextYAlignment.Center
            lbl.TextSize = size
            lbl.Parent = frame
            pcall(function() lbl.TextTruncate = Enum.TextTruncate.AtEnd end)
            pcall(function() SA.ApplyEspFont(lbl) end)
            return lbl
        end
        local nameLbl = profileLabel("ProfileName", "No nearest player", 13,
            Color3.fromRGB(245, 248, 255))
        local metaLbl = profileLabel("ProfileMeta", "waiting…", 10,
            Color3.fromRGB(180, 195, 225))
        local weaponLbl = profileLabel("WeaponName", "Weapon: None", 10,
            Color3.fromRGB(220, 230, 255))
        local stateLbl = profileLabel("WeaponState", "UNKNOWN", 9,
            Color3.fromRGB(255, 255, 255))
        stateLbl.BackgroundTransparency = 0.12
        stateLbl.BackgroundColor3 = Color3.fromRGB(75, 80, 95)
        stateLbl.TextXAlignment = Enum.TextXAlignment.Center
        pcall(function()
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0.25, 0)
            corner.Parent = stateLbl
        end)

        local label = Instance.new("TextLabel")
        label.Name = "NearestText"
        label.BackgroundTransparency = 1
        label.Text = "NEAREST PLAYERS  ·  1 m ≈ 3.571 studs"
        label.TextColor3 = Color3.fromRGB(230, 235, 255)
        label.TextStrokeColor3 = Color3.new(0, 0, 0)
        label.TextStrokeTransparency = 0
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextYAlignment = Enum.TextYAlignment.Top
        label.TextWrapped = true
        label.TextSize = 11
        label.Parent = frame
        pcall(function() label.TextTruncate = Enum.TextTruncate.AtEnd end)
        pcall(function() SA.ApplyEspFont(label) end)

        saNearest.gui, saNearest.frame, saNearest.header = gui, frame, header
        saNearest.avatar, saNearest.initials = avatar, initials
        saNearest.nameLbl, saNearest.metaLbl = nameLbl, metaLbl
        saNearest.weaponLbl, saNearest.stateLbl = weaponLbl, stateLbl
        saNearest.label = label
        saNearest.built, saNearest.reason = true, "built"
        saNearestApplyLayout(true)
        saNearestAttachDrag()
    end)
    if not ok then
        saNearest.reason = "build failed: " .. tostring(err)
        saNearest.built = false
        return false
    end
    return true
end

local function saNearestPlayers()
    local myRoot = SA.PlayerRig(lp.Character)
    local myPos = myRoot and myRoot.Position or nil
    if not myPos then
        pcall(function() myPos = ws.CurrentCamera.CFrame.Position end)
    end
    if not myPos then return nil, "no local position" end
    local ok, players = pcall(function() return Players:GetPlayers() end)
    if not ok or not players then return nil, "Players:GetPlayers failed" end
    local rows = {}
    for _, plr in ipairs(players) do
        if plr ~= lp then
            local char = plr.Character
            local root = char and SA.PlayerRig(char) or nil
            local hum = char and char:FindFirstChildOfClass("Humanoid") or nil
            if root and root.Position then
                local okD, d = pcall(function()
                    return (myPos - root.Position).Magnitude
                end)
                if okD and d then
                    local wpn = { tool = "None", state = "Unknown", chip = "UNKNOWN" }
                    pcall(function() wpn = SA.GetWeaponStatus(char) end)
                    local hp = 100
                    pcall(function()
                        hp = math.floor(100 * hum.Health
                            / math.max(hum.MaxHealth, 1) + 0.5)
                    end)
                    local mate = false
                    pcall(function() mate = SA.IsTeammate(plr) end)
                    local vis = true
                    pcall(function() vis = SA.IsVisible(char, root.Position) end)
                    rows[#rows + 1] = { plr = plr, char = char,
                        dist = d, tool = tostring(wpn.tool or "None"), wpn = wpn,
                        hp = hp, mate = mate, vis = vis }
                end
            end
        end
    end
    table.sort(rows, function(a, b) return a.dist < b.dist end)
    if #rows == 0 then return nil, "no other player with a rig" end
    return rows, "ok"
end

local function saNearestDisplay(plr)
    local display = plr.Name
    pcall(function()
        if plr.DisplayName and plr.DisplayName ~= "" then
            display = string.format("%s (@%s)", tostring(plr.DisplayName),
                                    tostring(plr.Name))
        end
    end)
    return display
end

SA.NearestDisplay = saNearestDisplay

local function saNearestInitials(plr)
    local text = "?"
    pcall(function()
        text = tostring((plr.DisplayName and plr.DisplayName ~= "")
            and plr.DisplayName or plr.Name or "?")
    end)
    text = text:gsub("^%s+", "")
    if text == "" then text = "?" end
    return string.upper(text:sub(1, 2))
end

local function saNearestDefer(fn)
    local spawned = false
    pcall(function()
        if type(task) == "table" and type(task.spawn) == "function" then
            task.spawn(fn)
            spawned = true
        end
    end)
    if not spawned then
        pcall(function()
            if type(coroutine) == "table" and type(coroutine.wrap) == "function" then
                coroutine.wrap(fn)()
            else
                fn()
            end
        end)
    end
end

local function saNearestRequestAvatar(plr)
    if not saNearest.avatar or not plr then return end
    local uid = 0
    pcall(function() uid = tonumber(plr.UserId) or 0 end)
    saNearest.lastUserId = uid
    if uid <= 0 then
        saNearest.avatarImage, saNearest.avatarFailed = nil, true
        pcall(function()
            saNearest.avatar.Image = ""
            saNearest.initials.Text = saNearestInitials(plr)
            saNearest.initials.Visible = true
        end)
        return
    end
    if saNearest.avatarUserId == uid
        and (saNearest.avatarImage or saNearest.avatarFailed) then return end
    saNearest.avatarUserId = uid
    saNearest.avatarImage, saNearest.avatarFailed = nil, false
    saNearest.avatarPending = true
    saNearest.avatarSeq = (saNearest.avatarSeq or 0) + 1
    local seq = saNearest.avatarSeq
    pcall(function()
        saNearest.avatar.Image = ""
        saNearest.initials.Text = saNearestInitials(plr)
        saNearest.initials.Visible = true
    end)
    saNearestDefer(function()
        local ok, image = pcall(function()
            return Players:GetUserThumbnailAsync(uid,
                Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
        end)
        if seq ~= saNearest.avatarSeq then return end
        saNearest.avatarPending = false
        if ok and image and tostring(image) ~= "" then
            saNearest.avatarImage = tostring(image)
            pcall(function()
                saNearest.avatar.Image = saNearest.avatarImage
                saNearest.initials.Visible = false
            end)
        else
            saNearest.avatarFailed = true
            pcall(function()
                saNearest.avatar.Image = ""
                saNearest.initials.Visible = true
            end)
        end
    end)
end

local function saNearestProfile(top)
    local plr = top.plr
    local wpn = top.wpn or { tool = top.tool, state = "Unknown", chip = "UNKNOWN" }
    local state = tostring(wpn.state or "Unknown")
    local profile = saNearestDisplay(plr)
    saNearest.lastProfile = profile
    saNearest.lastUsername = tostring(plr.Name or "?")
    saNearest.lastWeaponState = state
    saNearest.lastWeaponName = tostring(wpn.tool or "None")
    local bits = { string.format("%.1f m", top.dist / (SA.STUDS_PER_METER or 3.571)) }
    if CFG.nearestShowHealth == true then
        bits[#bits + 1] = tostring(top.hp) .. "% HP"
    end
    if CFG.nearestShowState == true then
        bits[#bits + 1] = top.vis and "VIS" or "WALL"
    end
    if CFG.nearestShowTeam == true then
        bits[#bits + 1] = top.mate and "MATE" or "ENEMY"
    end
    bits[#bits + 1] = "ID " .. tostring(saNearest.lastUserId or "?")
    pcall(function()
        saNearest.nameLbl.Text = profile
        saNearest.metaLbl.Text = table.concat(bits, "  ·  ")
        saNearest.weaponLbl.Text = "Weapon: " .. saNearest.lastWeaponName
        saNearest.stateLbl.Text = tostring(wpn.chip or string.upper(state))
        saNearest.stateLbl.BackgroundColor3 =
            state == "Equipped" and Color3.fromRGB(34, 106, 70)
            or (state == "Holstered" and Color3.fromRGB(112, 86, 30)
                or Color3.fromRGB(75, 80, 95))
    end)
    saNearestRequestAvatar(plr)
end

local function saNearestNoProfile(reason)
    saNearest.lastProfile, saNearest.lastUsername = nil, nil
    saNearest.lastUserId, saNearest.lastWeaponState = nil, nil
    saNearest.lastWeaponName, saNearest.avatarUserId = nil, nil
    saNearest.avatarImage, saNearest.avatarFailed = nil, false
    pcall(function()
        saNearest.nameLbl.Text = "No nearest player"
        saNearest.metaLbl.Text = tostring(reason)
        saNearest.weaponLbl.Text = "Weapon: None"
        saNearest.stateLbl.Text = "UNKNOWN"
        saNearest.stateLbl.BackgroundColor3 = Color3.fromRGB(75, 80, 95)
        saNearest.avatar.Image = ""
        saNearest.initials.Text = "?"
        saNearest.initials.Visible = true
    end)
end

local function saNearestTick(_, force)
    if not SA.Alive then return end
    local enabled = CFG.nearestWindow == true
    local menuOpen = window and window.opened
    local show = enabled and menuOpen == false
    if not saNearest.gui and (force or (tick() - (saNearest.lastBuild or 0) > 1)) then
        saNearest.lastBuild = tick()
        saNearestBuild()
    end
    saNearestApplyLayout()
    if saNearest.gui then saNearest.gui.Enabled = show end
    saNearest.enabled, saNearest.menuOpen, saNearest.visible = enabled, menuOpen, show
    if not enabled then
        saNearest.reason = "disabled"
        return
    end
    local now = tick()
    if not force and now - (saNearest.lastUpdate or 0) < 0.1 then return end
    saNearest.lastUpdate = now
    local rows, reason = saNearestPlayers()
    saNearest.lastReason = reason
    if not rows then
        saNearest.lastName, saNearest.lastDist = nil, nil
        saNearest.lastMeters, saNearest.lastTool = nil, nil
        saNearest.rows = nil
        saNearestNoProfile(reason)
        if saNearest.label then
            saNearest.label.Text = table.concat({
                "NEAREST PLAYERS  ·  1 m ≈ 3.571 studs", "—", tostring(reason),
            }, "\n")
        end
        return
    end
    local top = rows[1]
    saNearest.lastName = saNearestDisplay(top.plr)
    saNearest.lastDist, saNearest.lastMeters = top.dist,
        top.dist / (SA.STUDS_PER_METER or 3.571)
    saNearest.lastTool = top.tool
    saNearest.rows = rows
    saNearestProfile(top)
    local n = math.min(math.floor(tonumber(CFG.nearestTopN) or 1), #rows)
    local lines = { "NEAREST PLAYERS  ·  1 m ≈ 3.571 studs" }
    for i = 1, n do
        local r = rows[i]
        local bits = { string.format("%d. %s  %.1f m", i,
            saNearestDisplay(r.plr),
            r.dist / (SA.STUDS_PER_METER or 3.571)) }
        if CFG.nearestShowHealth == true then
            bits[#bits + 1] = tostring(r.hp) .. "%"
        end
        if CFG.nearestShowState == true then
            bits[#bits + 1] = r.vis and "VIS" or "WALL"
        end
        if CFG.nearestShowTeam == true then
            bits[#bits + 1] = r.mate and "MATE" or "ENEMY"
        end
        local wpn = r.wpn or { tool = r.tool, state = "Unknown" }
        bits[#bits + 1] = "[ " .. r.tool .. " / " .. tostring(wpn.state or "Unknown") .. " ]"
        lines[#lines + 1] = table.concat(bits, "  ·  ")
    end
    if CFG.showNoTargetReason then
        pcall(function()
            lines[#lines + 1] = "aim: " .. SA.NoTargetReason()
        end)
    end
    if CFG.perfShowFps then
        pcall(function()
            local st = SA.PerfState()
            lines[#lines + 1] = string.format("fps %.0f  ·  %d players / %d npcs / %d crates",
                st.fps or 0, st.visible and st.visible.players or 0,
                st.visible and st.visible.npcs or 0,
                st.visible and st.visible.crates or 0)
        end)
    end
    if saNearest.label then saNearest.label.Text = table.concat(lines, "\n") end
end

function SA.NearestWindowRefresh()
    saNearest.avatarUserId, saNearest.avatarImage = nil, nil
    saNearest.avatarPending, saNearest.avatarFailed = false, false
    saNearest.avatarSeq = (saNearest.avatarSeq or 0) + 1
    saNearestTick(0, true)
end
function SA.NearestWindowSet(on)
    on = on == true
    CFG.nearestWindow = on
    pcall(setFlag, "nearestWindow", on)
    saNearestTick(0, true)
end
function SA.NearestWindowResetPosition()
    saNearest.dragged, saNearest.dragging = false, false
    saNearest.posX, saNearest.posY = nil, nil
    saNearest.layoutKey = nil
    _G.__saNearestWindowPos = nil
    saNearestApplyLayout(true)
    saNearestTick(0, true)
    return true
end
function SA.NearestWindowState()
    local nearestRow = saNearest.rows and saNearest.rows[1] or nil
    local wpn = nearestRow and nearestRow.wpn or nil
    local avatarState = saNearest.avatarImage and "loaded"
        or (saNearest.avatarFailed and "fallback"
            or (saNearest.avatarPending and "loading" or "unavailable"))
    return {
        enabled = CFG.nearestWindow == true,
        built = saNearest.built == true,
        visible = saNearest.visible == true,
        menuOpen = window and window.opened,
        nearest = saNearest.lastName,
        profile = saNearest.lastProfile,
        username = saNearest.lastUsername,
        userId = saNearest.lastUserId,
        studs = saNearest.lastDist,
        meters = saNearest.lastMeters,
        tool = saNearest.lastTool,
        weapon = saNearest.lastWeaponName or saNearest.lastTool,
        weaponState = (wpn and wpn.state) or saNearest.lastWeaponState,
        weaponChip = wpn and wpn.chip or nil,
        avatar = saNearest.avatarImage or "",
        avatarState = avatarState,
        avatarFallback = saNearest.avatarFailed == true,
        avatarInitials = saNearest.initials and saNearest.initials.Text or nil,
        dragHandle = saNearest.header ~= nil,
        dragConnected = saNearest.dragBegan ~= nil,
        dragged = saNearest.dragged == true,
        position = { x = saNearest.posX or 12, y = saNearest.posY or 12 },
        reason = (saNearest.built and (saNearest.lastReason or "ok"))
            or saNearest.reason or "unknown",
        lastUpdate = saNearest.lastUpdate or 0,
        topN = CFG.nearestTopN,
        rows = saNearest.rows and #saNearest.rows or 0,
        corner = CFG.nearestCorner,
        scale = CFG.nearestScale,
        health = nearestRow and nearestRow.hp or nil,
        visibleState = nearestRow and (nearestRow.vis and "VIS" or "WALL") or nil,
        teammate = nearestRow and nearestRow.mate or false,
    }
end

saNearestBuild()
saNearestTick(0, true)
saNearest.conn = bindRender(function(dt) saNearestTick(dt) end)
