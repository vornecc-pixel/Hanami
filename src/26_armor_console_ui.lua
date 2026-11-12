-- ==================================================================
-- Hanami / 26_armor_console_ui.lua
-- The ARMOR CONSOLE panel: a frameless, draggable companion HUD in the
-- same style as the Nearest Player card. It shows only while the menu is
-- minimised, so it never fights the menu for screen space.
--
-- Rows are pooled: a scan rewrites existing labels, it does not destroy
-- and rebuild Instances. The panel is rebuilt only if it is missing.
-- ==================================================================

if SA.ArmorConsoleDispose then pcall(SA.ArmorConsoleDispose) end

local savedPos = _G.__saArmorConsolePos
local ac = {
    dragged = savedPos ~= nil,
    posX = savedPos and tonumber(savedPos.x) or nil,
    posY = savedPos and tonumber(savedPos.y) or nil,
    rows = {},
    scans = 0,
    redraws = 0,
    skipped = 0,
    errors = 0,
    lastError = nil,
    lastSignature = nil,
}
_G.__saArmorConsole = ac

local acParent = function()
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

function SA.ArmorConsoleDispose()
    for _, key in ipairs({ "conn", "dragBegan", "dragChanged", "dragEnded" }) do
        local c = ac[key]
        if c then pcall(function() c:Disconnect() end) end
    end
    if ac.gui then pcall(function() ac.gui:Destroy() end) end
    ac.gui, ac.frame, ac.header = nil, nil, nil
    ac.title, ac.subtitle, ac.body = nil, nil, nil
    ac.rows = {}
    ac.shown, ac.targets, ac.countInFov = 0, nil, 0
    ac.lastSignature, ac.layoutKey, ac.layoutW, ac.layoutH = nil, nil, nil, nil
    -- A dispose must not leave the 1s build throttle armed: the rebuild
    -- should happen on the very next tick, not a second later.
    ac.lastBuild = nil
    ac.built, ac.visible, ac.dragging = false, false, false
    ac.conn, ac.dragBegan, ac.dragChanged, ac.dragEnded = nil, nil, nil
    ac.layoutKey = nil
    ac.lastSignature = nil
    ac.reason = "disposed"
end

local acRect = function(inst, x, y, w, h)
    if not inst then return end
    pcall(function()
        inst.Position = UDim2.fromOffset(x, y)
        inst.Size = UDim2.fromOffset(w, h)
    end)
end

local acClamp = function(x, y, w, h)
    local vp = SA.ViewportSize()
    local maxX = math.max(0, (tonumber(vp.X) or 1280) - w)
    local maxY = math.max(0, (tonumber(vp.Y) or 720) - h)
    return math.clamp(x, 0, maxX), math.clamp(y, 0, maxY)
end

local acWritePosition = function(x, y)
    ac.posX, ac.posY = x, y
    if ac.frame then
        pcall(function() ac.frame.Position = UDim2.fromOffset(x, y) end)
    end
end

local acPersistPosition = function(x, y)
    ac.dragged = true
    _G.__saArmorConsolePos = { x = x, y = y }
    acWritePosition(x, y)
end

local acCornerPosition = function(corner, w, h, scale)
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

-- Row geometry is a pure function of the scale, so the layout pass can
-- reposition pooled rows without rebuilding anything.
local acRowHeight = function(scale) return math.floor(30 * scale) end

local acApplyLayout = function(force)
    if not ac.frame then return end
    local scale = tonumber(CFG.armorConsoleScale) or 1
    local shown = math.max(1, math.floor(tonumber(CFG.armorConsoleMaxPlayers) or 3))
    local corner = CFG.armorConsoleCorner or "Top Left"
    local transparency = math.clamp(
        (tonumber(CFG.armorConsoleTransparency) or 12) / 100, 0, 0.95)
    local vp = SA.ViewportSize()
    local key = table.concat({ scale, shown, corner, transparency,
        ac.dragged and 1 or 0, vp.X, vp.Y }, "|")
    if not force and ac.layoutKey == key then return end
    ac.layoutKey = key

    local rowH = acRowHeight(scale)
    local headH = math.floor(26 * scale)
    local pad = math.floor(10 * scale)
    -- Header + subtitle + (rows for each shown player) + footer note.
    local w = math.floor(340 * scale)
    local h = headH + pad + (rowH * shown) + math.floor(18 * scale) + pad
    ac.layoutW, ac.layoutH = w, h

    pcall(function()
        ac.frame.Size = UDim2.fromOffset(w, h)
        ac.frame.BackgroundTransparency = transparency
        ac.header.Size = UDim2.fromOffset(w, headH)
        ac.header.TextSize = math.max(8, math.floor(11 * scale))
        ac.subtitle.TextSize = math.max(6, math.floor(9 * scale))
        acRect(ac.subtitle, pad, headH + math.floor(2 * scale),
            math.max(40, w - pad * 2), math.floor(14 * scale))
        for index, row in ipairs(ac.rows) do
            local y = headH + pad + (index - 1) * rowH
            acRect(row.frame, pad, y, math.max(40, w - pad * 2), rowH - 2)
            acRect(row.chip, 0, 0, math.floor(30 * scale), math.floor(20 * scale))
            pcall(function()
                row.chip.TextSize = math.max(6, math.floor(9 * scale))
            end)
            acRect(row.name, math.floor(34 * scale), 0,
                math.max(30, w - pad * 2 - math.floor(120 * scale)),
                math.floor(20 * scale))
            pcall(function()
                row.name.TextSize = math.max(6, math.floor(10 * scale))
            end)
            acRect(row.region, math.max(30, w - pad * 2 - math.floor(112 * scale)),
                0, math.floor(52 * scale), math.floor(20 * scale))
            pcall(function()
                row.region.TextSize = math.max(6, math.floor(8 * scale))
            end)
            acRect(row.total, math.max(30, w - pad * 2 - math.floor(58 * scale)),
                0, math.floor(56 * scale), math.floor(20 * scale))
            pcall(function()
                row.total.TextSize = math.max(6, math.floor(9 * scale))
            end)
        end
    end)

    if ac.dragged and ac.posX and ac.posY then
        local x, y = acClamp(ac.posX, ac.posY, w, h)
        acWritePosition(x, y)
    else
        local x, y = acCornerPosition(corner, w, h, scale)
        acWritePosition(x, y)
    end
end

local acDragInput = function(input)
    return input and (input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch)
end

local acInputPoint = function(input)
    local p = input and input.Position or nil
    if p and tonumber(p.X) and tonumber(p.Y) then
        return tonumber(p.X), tonumber(p.Y)
    end
    local ok, aim = pcall(function() return SA.AimPoint() end)
    if ok and aim then return aim.X, aim.Y end
    return 0, 0
end

local acAttachDrag = function()
    if not ac.header then return end
    pcall(function()
        ac.dragBegan = SA.Connect(ac.header.InputBegan, function(input)
            if not acDragInput(input) then return end
            local x, y = acInputPoint(input)
            ac.dragging = true
            ac.dragStart = Vector2.new(x, y)
            ac.dragOrigin = Vector2.new(ac.posX or 12, ac.posY or 12)
        end)
    end)
    pcall(function()
        ac.dragChanged = SA.Connect(UserInputService.InputChanged, function(input)
            if not ac.dragging or not input then return end
            if input.UserInputType ~= Enum.UserInputType.MouseMovement
                and input.UserInputType ~= Enum.UserInputType.Touch then return end
            local px, py = acInputPoint(input)
            local start = ac.dragStart or Vector2.new(px, py)
            local origin = ac.dragOrigin or Vector2.new(12, 12)
            local x = origin.X + px - start.X
            local y = origin.Y + py - start.Y
            x, y = acClamp(x, y, ac.layoutW or 340, ac.layoutH or 150)
            acPersistPosition(x, y)
        end)
    end)
    pcall(function()
        ac.dragEnded = SA.Connect(UserInputService.InputEnded, function(input)
            if acDragInput(input) then ac.dragging = false end
        end)
    end)
end

-- One pooled row: chip icon + name + region badge + total.
local acMakeRow = function(parent, frame)
    local ok, row = pcall(function()
        local holder = Instance.new("Frame")
        holder.Name = "Row"
        holder.BackgroundTransparency = 1
        holder.BorderSizePixel = 0
        holder.Parent = frame

        local chip = Instance.new("TextLabel")
        chip.Name = "Chip"
        chip.BackgroundColor3 = Color3.fromRGB(60, 70, 95)
        chip.BackgroundTransparency = 0.1
        chip.BorderSizePixel = 0
        chip.Text = "?"
        chip.TextColor3 = Color3.fromRGB(245, 248, 255)
        chip.TextXAlignment = Enum.TextXAlignment.Center
        chip.TextYAlignment = Enum.TextYAlignment.Center
        chip.TextSize = 9
        chip.Parent = holder
        pcall(function()
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0.22, 0)
            corner.Parent = chip
        end)
        pcall(function() SA.ApplyEspFont(chip) end)

        local name = Instance.new("TextLabel")
        name.Name = "Name"
        name.BackgroundTransparency = 1
        name.Text = ""
        name.TextColor3 = Color3.fromRGB(240, 245, 255)
        name.TextStrokeColor3 = Color3.new(0, 0, 0)
        name.TextStrokeTransparency = 0
        name.TextXAlignment = Enum.TextXAlignment.Left
        name.TextYAlignment = Enum.TextYAlignment.Center
        name.TextSize = 10
        name.Parent = holder
        pcall(function() name.TextTruncate = Enum.TextTruncate.AtEnd end)
        pcall(function() SA.ApplyEspFont(name) end)

        local region = Instance.new("TextLabel")
        region.Name = "Region"
        region.BackgroundTransparency = 1
        region.Text = ""
        region.TextColor3 = Color3.fromRGB(175, 195, 230)
        region.TextXAlignment = Enum.TextXAlignment.Center
        region.TextYAlignment = Enum.TextYAlignment.Center
        region.TextSize = 8
        region.Parent = holder
        pcall(function() SA.ApplyEspFont(region) end)

        local total = Instance.new("TextLabel")
        total.Name = "Total"
        total.BackgroundTransparency = 1
        total.Text = ""
        total.TextColor3 = Color3.fromRGB(255, 225, 150)
        total.TextXAlignment = Enum.TextXAlignment.Right
        total.TextYAlignment = Enum.TextYAlignment.Center
        total.TextSize = 9
        total.Parent = holder
        pcall(function() SA.ApplyEspFont(total) end)

        return { frame = holder, chip = chip, name = name,
                 region = region, total = total }
    end)
    if not ok then return nil end
    return row
end

local acBuild = function()
    local parent = acParent()
    if not parent then
        ac.reason = "no PlayerGui / CoreGui / gethui parent"
        return false
    end
    local ok, err = pcall(function()
        local gui = Instance.new("ScreenGui")
        gui.Name = "HanamiArmorConsole"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.DisplayOrder = 996          -- just under the nearest card
        gui.Enabled = false
        gui.Parent = parent

        -- Frameless panel: no BackgroundFrame, matching the nearest card.
        local frame = Instance.new("Frame")
        frame.Name = "Panel"
        frame.Size = UDim2.fromOffset(340, 150)
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
        header.Text = "ARMOR  ·  DRAG TO MOVE"
        header.TextColor3 = Color3.fromRGB(220, 230, 255)
        header.TextXAlignment = Enum.TextXAlignment.Left
        header.TextYAlignment = Enum.TextYAlignment.Center
        header.TextSize = 11
        header.Active = true
        header.Selectable = false
        header.AutoButtonColor = false
        header.Parent = frame
        pcall(function() SA.ApplyEspFont(header) end)

        local subtitle = Instance.new("TextLabel")
        subtitle.Name = "Subtitle"
        subtitle.BackgroundTransparency = 1
        subtitle.Text = "scanning…"
        subtitle.TextColor3 = Color3.fromRGB(175, 190, 220)
        subtitle.TextXAlignment = Enum.TextXAlignment.Left
        subtitle.TextYAlignment = Enum.TextYAlignment.Center
        subtitle.TextSize = 9
        subtitle.Parent = frame
        pcall(function() SA.ApplyEspFont(subtitle) end)

        ac.gui, ac.frame, ac.header = gui, frame, header
        ac.title, ac.subtitle = header, subtitle

        -- Pool enough rows for the maximum the UI allows (5).
        for _ = 1, 5 do
            local row = acMakeRow(frame, frame)
            if row then ac.rows[#ac.rows + 1] = row end
        end
        ac.built, ac.reason = true, "built"
        acApplyLayout(true)
        acAttachDrag()
    end)
    if not ok then
        ac.reason = "build failed: " .. tostring(err)
        ac.built = false
        return false
    end
    return true
end

-- Region summary string for one player.
local acRegionText = function(regions)
    return string.format("H %d · T %d · L %d · F %d",
        tonumber(regions.Head) or 0, tonumber(regions.Torso) or 0,
        tonumber(regions.Legs) or 0, tonumber(regions.Feet) or 0)
end

-- A stable string for one target. When it has not changed there is
-- nothing to redraw -- this is what replaces the reference script's
-- 0.25 s console spam.
local acSignature = function(target)
    local parts = { target.name }
    for _, item in ipairs(target.worn or {}) do
        parts[#parts + 1] = item.id .. ":" .. tostring(item.prot)
    end
    local r = target.regions or {}
    parts[#parts + 1] = table.concat({
        tonumber(r.Head) or 0, tonumber(r.Torso) or 0,
        tonumber(r.Legs) or 0, tonumber(r.Feet) or 0 }, ",")
    parts[#parts + 1] = target.inFov and "1" or "0"
    return table.concat(parts, "|")
end

local acRedraw = function(force)
    local targets = nil
    local ok, err = pcall(function() targets = SA.ArmorTargets() end)
    if not ok then
        ac.errors = ac.errors + 1
        ac.lastError = tostring(err)
        return false
    end
    targets = targets or {}
    ac.scans = ac.scans + 1
    ac.targets = targets
    -- No rows pooled yet (the panel is not built): remember nothing and
    -- latch nothing, otherwise the signature matches on the next tick and
    -- the HUD stays empty until the player's armour happens to change.
    if #ac.rows == 0 then
        ac.pendingRedraw = true
        return false
    end

    local signatures = {}
    for index = 1, #targets do
        signatures[index] = acSignature(targets[index])
    end
    local signature = table.concat(signatures, "#")
        .. "|" .. tostring(CFG.armorConsoleShowTotals == true)
        .. "|" .. tostring(CFG.armorConsoleFov == true)
    if not force and signature == ac.lastSignature then
        ac.skipped = ac.skipped + 1
        return true
    end
    ac.lastSignature = signature
    ac.redraws = ac.redraws + 1
    -- Reset only when rows are actually rewritten: resetting before the
    -- unchanged-signature early return zeroed the reported row count on
    -- every skipped scan, so the HUD looked empty even when it was full.
    ac.shown = 0

    local inFov = 0
    for _, target in ipairs(targets) do
        if target.inFov then inFov = inFov + 1 end
    end
    ac.countInFov = inFov

    local limit = math.max(1, math.min(5,
        math.floor(tonumber(CFG.armorConsoleMaxPlayers) or 3)))
    local count = math.min(limit, #targets)
    for index, row in ipairs(ac.rows) do
        if index <= count then
            local target = targets[index]
            row.frame.Visible = true
            local okRow, rowErr = pcall(function()
                -- Chip icon: the catalog abbreviation over its own colour.
                row.chip.Text = SA.ArmorIconAbbr(
                    target.worn and target.worn[1] and target.worn[1].id
                    or target.name)
                row.chip.BackgroundColor3 = target.inFov
                    and Color3.fromRGB(40, 120, 80)
                    or Color3.fromRGB(60, 70, 95)
                row.chip.Text = string.upper(row.chip.Text):sub(1, 4)
                row.name.Text = string.format("%s  %.1fm%s",
                    target.name,
                    (tonumber(target.dist) or 0) / (SA.STUDS_PER_METER or 3.571),
                    target.behind and "  (behind)" or "")
                row.region.Text = acRegionText(target.regions or {})
                if CFG.armorConsoleShowTotals == true then
                    row.total.Text = tostring(target.total or 0) .. "%"
                else
                    row.total.Text = target.inFov and "FOV" or ""
                end
            end)
            if not okRow then
                ac.errors = ac.errors + 1
                ac.lastError = "row: " .. tostring(rowErr)
            end
            ac.shown = ac.shown + 1
        else
            row.frame.Visible = false
        end
    end

    pcall(function()
        ac.subtitle.Text = string.format(
            "%d awake player%s  ·  %d in FOV  ·  %s",
            #targets, #targets == 1 and "" or "s", ac.countInFov or 0,
            CFG.armorConsoleSort or "Nearest")
    end)
    acApplyLayout()
    return true
end

local acTick = function(_, force)
    if not SA.Alive then return end
    local enabled = CFG.armorConsole == true
    local menuOpen = window and window.opened or false
    local show = enabled and menuOpen == false

    local builtNow = false
    if not ac.gui and (force or (tick() - (ac.lastBuild or 0) > 1)) then
        ac.lastBuild = tick()
        builtNow = acBuild() == true
        if builtNow then ac.pendingRedraw = true end
    end
    acApplyLayout()
    if ac.gui then ac.gui.Enabled = show end
    ac.enabled, ac.menuOpen, ac.visible = enabled, menuOpen, show
    if not enabled then
        ac.reason = "disabled"
        ac.lastSignature = nil
        return
    end

    local now = tick()
    local interval = math.max(tonumber(CFG.armorConsoleScanSec) or 0.5, 0.25)
    if not force and now - (ac.lastUpdate or 0) < interval then return end
    ac.lastUpdate = now
    pcall(acRedraw, force or ac.pendingRedraw == true)
    ac.pendingRedraw = false
end

-- ── PUBLIC API ──────────────────────────────────────────────────────
function SA.ArmorConsoleRefresh()
    ac.lastSignature = nil
    return acRedraw(true)
end

function SA.ArmorConsoleSet(on)
    on = on == true
    CFG.armorConsole = on
    pcall(setFlag, "armorConsole", on)
    acTick(0, true)
end

function SA.ArmorConsoleResetPosition()
    ac.dragged, ac.dragging = false, false
    ac.posX, ac.posY = nil, nil
    ac.layoutKey = nil
    _G.__saArmorConsolePos = nil
    acApplyLayout(true)
    acTick(0, true)
    return true
end

function SA.ArmorConsoleState()
    local inFov = 0
    for _, target in ipairs(ac.targets or {}) do
        if target.inFov then inFov = inFov + 1 end
    end
    return {
        built = ac.built == true,
        visible = ac.visible == true,
        enabled = ac.enabled == true,
        menuOpen = ac.menuOpen == true,
        scans = ac.scans,
        redraws = ac.redraws,
        skipped = ac.skipped,
        errors = ac.errors,
        lastError = ac.lastError,
        rows = ac.shown or 0,
        pooled = #ac.rows,
        players = #(ac.targets or {}),
        inFov = inFov,
        reason = ac.reason or "idle",
        position = { x = ac.posX, y = ac.posY },
        width = ac.layoutW, height = ac.layoutH,
    }
end

bindRender(function(dt) acTick(dt, false) end)
