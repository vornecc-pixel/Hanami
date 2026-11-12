-- ==================================================================
-- Hanami / 26_armor_console_ui.lua
-- The ARMOR CONSOLE panel: a narrow VERTICAL list, styled after the
-- reference layout -- one separate card per armour piece, each with the
-- real 3D item icon on the left, the item name, its slot, and a green
-- +X% protection value. Players are grouped with a small header showing
-- their per-region totals.
--
-- Rows are pooled and rewritten, never destroyed per scan. Icons are
-- cloned into a ViewportFrame only when the item on that row changes.
-- ==================================================================

if SA.ArmorConsoleDispose then pcall(SA.ArmorConsoleDispose) end

local savedPos = _G.__saArmorConsolePos
local ac = {
    dragged = savedPos ~= nil,
    posX = savedPos and tonumber(savedPos.x) or nil,
    posY = savedPos and tonumber(savedPos.y) or nil,
    cards = {},
    scans = 0,
    redraws = 0,
    skipped = 0,
    errors = 0,
    lastError = nil,
    lastSignature = nil,
    countInFov = 0,
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
    for _, key in ipairs({ "conn", "dragBegan", "dragChanged", "dragEnded",
        "resizeBegan", "resizeChanged" }) do
        local c = ac[key]
        if c then pcall(function() c:Disconnect() end) end
    end
    if ac.gui then pcall(function() ac.gui:Destroy() end) end
    ac.gui, ac.frame, ac.header, ac.scroll, ac.grip = nil, nil, nil, nil, nil
    ac.subtitle, ac.empty = nil, nil
    ac.cards = {}
    ac.shown, ac.targets, ac.countInFov = 0, nil, 0
    ac.lastSignature, ac.layoutKey = nil, nil
    ac.layoutW, ac.layoutH = nil, nil
    -- A dispose must not leave the 1s build throttle armed.
    ac.lastBuild = nil
    ac.built, ac.visible, ac.dragging = false, false, false
    ac.reason = "disposed"
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

-- ── LAYOUT ──────────────────────────────────────────────────────────
local acApplyLayout = function(force)
    if not ac.frame then return end
    local scale = tonumber(CFG.armorConsoleScale) or 1
    local corner = CFG.armorConsoleCorner or "Top Left"
    local transparency = math.clamp(
        (tonumber(CFG.armorConsoleTransparency) or 12) / 100, 0, 0.95)
    local vp = SA.ViewportSize()
    local key = table.concat({ scale, corner, transparency,
        ac.dragged and 1 or 0, vp.X, vp.Y }, "|")
    if not force and ac.layoutKey == key then return end
    ac.layoutKey = key

    -- A NARROW vertical column, not a wide square block. The saved
    -- CFG size wins (the resize grip writes it), clamped to the screen.
    local w = math.clamp(tonumber(CFG.armorConsoleWidth) or 300,
        220, math.min(520, math.floor(vp.X - 24)))
    local h = math.clamp(tonumber(CFG.armorConsoleHeight) or 560,
        200, math.floor(vp.Y - 24))
    ac.layoutW, ac.layoutH = w, h

    local cardH = math.floor(SA.ARMOR_CARD_H * scale)
    local iconW = math.floor(SA.ARMOR_ICON_W * scale)
    local groupH = math.floor(SA.ARMOR_GROUP_H * scale)
    local pad = math.floor(SA.ARMOR_PAD * scale)
    local headerH = math.floor(SA.ARMOR_HEADER_H * scale)

    pcall(function()
        ac.frame.Size = UDim2.fromOffset(w, h)
        ac.frame.BackgroundTransparency = transparency
        ac.header.Size = UDim2.fromOffset(w, headerH)
        ac.header.TextSize = math.max(8, math.floor(11 * scale))
        ac.scroll.Position = UDim2.fromOffset(0, headerH)
        ac.scroll.Size = UDim2.fromOffset(w, h - headerH)
        ac.scroll.ScrollBarThickness = math.max(2, math.floor(4 * scale))
        local gripSize = math.max(10, math.floor(16 * scale))
        ac.grip.Position = UDim2.fromOffset(w - gripSize, h - gripSize)
        ac.grip.Size = UDim2.fromOffset(gripSize, gripSize)
        ac.grip.TextSize = math.max(8, math.floor(12 * scale))
    end)

    for index, group in ipairs(ac.groups) do
        pcall(function()
            group.root.Size = UDim2.fromOffset(w - pad * 2 - 6, groupH - 4)
            group.name.Position = UDim2.fromOffset(pad, math.floor(4 * scale))
            group.name.Size = UDim2.fromOffset(w - pad * 3 - 6,
                math.floor(17 * scale))
            group.name.TextSize = math.max(8, math.floor(SA.ARMOR_FONT_MAIN * scale))
            group.totals.Position = UDim2.fromOffset(pad, math.floor(19 * scale))
            group.totals.Size = UDim2.fromOffset(w - pad * 3 - 6,
                math.floor(15 * scale))
            group.totals.TextSize = math.max(6, math.floor(SA.ARMOR_FONT_SUB * scale))
            group.empty.Position = UDim2.fromOffset(pad, math.floor(19 * scale))
            group.empty.Size = UDim2.fromOffset(w - pad * 3 - 6,
                math.floor(15 * scale))
            group.empty.TextSize = math.max(6, math.floor(SA.ARMOR_FONT_SUB * scale))
        end)
    end

    for _, card in ipairs(ac.cards) do
        pcall(function()
            card.root.Size = UDim2.fromOffset(w - pad * 2 - 6, cardH - 4)
            card.viewport.Position = UDim2.fromOffset(math.floor(4 * scale),
                math.floor(4 * scale))
            card.viewport.Size = UDim2.fromOffset(iconW,
                cardH - math.floor(12 * scale))
            card.chip.Position = card.viewport.Position
            card.chip.Size = card.viewport.Size
            card.chip.TextSize = math.max(7, math.floor(12 * scale))
            local textX = iconW + math.floor(10 * scale)
            local textW = w - pad * 2 - 6 - textX - math.floor(8 * scale)
            card.name.Position = UDim2.fromOffset(textX,
                math.floor(10 * scale))
            card.name.Size = UDim2.fromOffset(textW,
                math.floor(18 * scale))
            card.name.TextSize = math.max(8, math.floor(SA.ARMOR_FONT_MAIN * scale))
            card.slot.Position = UDim2.fromOffset(textX,
                math.floor(29 * scale))
            card.slot.Size = UDim2.fromOffset(textW,
                math.floor(14 * scale))
            card.slot.TextSize = math.max(6, math.floor(SA.ARMOR_FONT_SUB * scale))
            card.value.Position = UDim2.fromOffset(textX,
                math.floor(44 * scale))
            card.value.Size = UDim2.fromOffset(textW,
                math.floor(18 * scale))
            card.value.TextSize = math.max(8, math.floor(SA.ARMOR_FONT_VALUE * scale))
        end)
    end

    if ac.dragged and ac.posX and ac.posY then
        local x, y = acClamp(ac.posX, ac.posY, w, h)
        acWritePosition(x, y)
    else
        local x, y = acCornerPosition(corner, w, h, scale)
        acWritePosition(x, y)
    end
end

-- ── DRAG ────────────────────────────────────────────────────────────
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
            x, y = acClamp(x, y, ac.layoutW or 300, ac.layoutH or 560)
            acPersistPosition(x, y)
        end)
    end)
    pcall(function()
        ac.dragEnded = SA.Connect(UserInputService.InputEnded, function(input)
            if acDragInput(input) then
                ac.dragging = false
                ac.resizing = false
            end
        end)
    end)
    -- Resize grip: same pointer movement, writes the panel size instead.
    if ac.grip then
        pcall(function()
            ac.resizeBegan = SA.Connect(ac.grip.InputBegan, function(input)
                if not acDragInput(input) then return end
                local x, y = acInputPoint(input)
                ac.resizing = true
                ac.resizeStart = Vector2.new(x, y)
                ac.resizeOrigin = Vector2.new(ac.layoutW or 300,
                                              ac.layoutH or 560)
            end)
        end)
    end
    pcall(function()
        ac.resizeChanged = SA.Connect(UserInputService.InputChanged,
            function(input)
                if not ac.resizing or not input then return end
                if input.UserInputType ~= Enum.UserInputType.MouseMovement
                    and input.UserInputType ~= Enum.UserInputType.Touch then
                    return
                end
                local px, py = acInputPoint(input)
                local start = ac.resizeStart or Vector2.new(px, py)
                local origin = ac.resizeOrigin or Vector2.new(300, 560)
                local vp = SA.ViewportSize()
                local w = math.clamp(origin.X + px - start.X, 220,
                    math.min(520, (tonumber(vp.X) or 1280) - 24))
                local h = math.clamp(origin.Y + py - start.Y, 200,
                    (tonumber(vp.Y) or 720) - 24)
                CFG.armorConsoleWidth, CFG.armorConsoleHeight = w, h
                ac.layoutKey = nil
                acApplyLayout(true)
            end)
    end)
end

-- ── BUILD ───────────────────────────────────────────────────────────
-- One pool of cards big enough for the worst case: max players x 4 slots.
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
        gui.DisplayOrder = 996
        gui.Enabled = false
        gui.Parent = parent

        local frame = Instance.new("Frame")
        frame.Name = "Panel"
        frame.Size = UDim2.fromOffset(300, 560)
        frame.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
        frame.BackgroundTransparency = 0.12
        frame.BorderSizePixel = 0
        frame.Active = true
        frame.Parent = gui
        pcall(function() frame.Draggable = true end)
        pcall(function()
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 8)
            corner.Parent = frame
        end)
        pcall(function()
            local stroke = Instance.new("UIStroke")
            stroke.Color = Color3.fromRGB(70, 80, 110)
            stroke.Thickness = 1
            stroke.Transparency = 0.35
            stroke.Parent = frame
        end)

        local header = Instance.new("TextButton")
        header.Name = "DragHandle"
        header.BackgroundColor3 = Color3.fromRGB(28, 31, 44)
        header.BackgroundTransparency = 0.05
        header.BorderSizePixel = 0
        header.Text = "ARMOR CONSOLE  ·  DRAG TO MOVE"
        header.TextColor3 = Color3.fromRGB(225, 233, 255)
        header.TextXAlignment = Enum.TextXAlignment.Left
        header.TextYAlignment = Enum.TextYAlignment.Center
        header.TextSize = 11
        header.Active = true
        header.Selectable = false
        header.AutoButtonColor = false
        header.Parent = frame
        pcall(function() SA.ApplyEspFont(header) end)
        pcall(function()
            local pad = Instance.new("UIPadding")
            pad.PaddingLeft = UDim.new(0, 8)
            pad.Parent = header
        end)

        -- Scrolling column: the list can grow past the panel height.
        local scroll = Instance.new("ScrollingFrame")
        scroll.Name = "Cards"
        scroll.BackgroundTransparency = 1
        scroll.BorderSizePixel = 0
        scroll.ScrollBarThickness = 4
        scroll.ScrollBarImageColor3 = Color3.fromRGB(90, 104, 140)
        scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        scroll.Position = UDim2.fromOffset(0, SA.ARMOR_HEADER_H)
        scroll.Size = UDim2.fromOffset(300, 534)
        scroll.Parent = frame
        pcall(function() scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y end)
        pcall(function()
            local list = Instance.new("UIListLayout")
            list.Padding = UDim.new(0, 6)
            list.SortOrder = Enum.SortOrder.LayoutOrder
            list.Parent = scroll
        end)
        pcall(function()
            local pad = Instance.new("UIPadding")
            pad.PaddingLeft = UDim.new(0, 8)
            pad.PaddingRight = UDim.new(0, 8)
            pad.PaddingTop = UDim.new(0, 8)
            pad.Parent = scroll
        end)

        -- Bottom-right resize grip, so the list height is adjustable
        -- without leaving the game.
        local grip = Instance.new("TextButton")
        grip.Name = "ResizeGrip"
        grip.BackgroundTransparency = 1
        grip.BorderSizePixel = 0
        grip.Text = "//"
        grip.TextColor3 = Color3.fromRGB(120, 134, 168)
        grip.TextSize = 12
        grip.Active = true
        grip.Selectable = false
        grip.AutoButtonColor = false
        grip.Parent = frame
        pcall(function() SA.ApplyEspFont(grip) end)

        ac.gui, ac.frame, ac.header, ac.scroll = gui, frame, header, scroll
        ac.grip = grip

        -- Pool: 5 players x 4 armour slots, plus 5 group headers.
        ac.groups = {}
        for _ = 1, 5 do
            local group = SA.ArmorConsoleMakeGroup(scroll)
            if group then ac.groups[#ac.groups + 1] = group end
        end
        ac.cards = {}
        for _ = 1, 20 do
            local card = SA.ArmorConsoleMakeCard(scroll)
            if card then ac.cards[#ac.cards + 1] = card end
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

-- ── RENDER ──────────────────────────────────────────────────────────
local acRegionText = function(regions)
    return string.format("H: %d%%   T: %d%%   L: %d%%   F: %d%%",
        tonumber(regions.Head) or 0, tonumber(regions.Torso) or 0,
        tonumber(regions.Legs) or 0, tonumber(regions.Feet) or 0)
end

-- Slot label shown under the item name, matching the reference card.
local acSlotLabel = function(region)
    if region == "Head" then return "Head slot" end
    if region == "Torso" then return "Torso slot" end
    if region == "Legs" then return "Legs slot" end
    if region == "Feet" then return "Feet slot" end
    return "Unknown slot"
end

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
    -- No cards pooled yet (the panel is not built): remember nothing and
    -- latch nothing, otherwise the signature matches next tick and the
    -- HUD stays empty until someone's armour changes.
    if #ac.cards == 0 then
        ac.pendingRedraw = true
        return false
    end

    local signatures = {}
    for index = 1, #targets do
        signatures[index] = acSignature(targets[index])
    end
    local signature = table.concat(signatures, "#")
        .. "|" .. tostring(CFG.armorConsoleFov == true)
        .. "|" .. tostring(CFG.armorConsoleMaxPlayers)
    if not force and signature == ac.lastSignature then
        ac.skipped = ac.skipped + 1
        return true
    end
    ac.lastSignature = signature
    ac.redraws = ac.redraws + 1

    local inFov = 0
    for _, target in ipairs(targets) do
        if target.inFov then inFov = inFov + 1 end
    end
    ac.countInFov = inFov

    local limit = math.max(1, math.min(5,
        math.floor(tonumber(CFG.armorConsoleMaxPlayers) or 3)))
    local count = math.min(limit, #targets)
    local cardIndex, groupIndex = 0, 0
    ac.shown = 0

    for index = 1, count do
        local target = targets[index]
        -- player header
        groupIndex = groupIndex + 1
        local group = ac.groups[groupIndex]
        if group then
            pcall(function()
                group.root.Visible = true
                group.root.LayoutOrder = index * 100
                group.name.Text = string.format("%s   %.1fm%s",
                    target.name,
                    (tonumber(target.dist) or 0) / (SA.STUDS_PER_METER or 3.571),
                    target.behind and "  (behind)" or "")
                group.totals.Text = acRegionText(target.regions or {})
                -- A player wearing nothing still gets a header plus the
                -- "no items" line, matching the reference layout.
                local none = #(target.worn or {}) == 0
                group.empty.Visible = none
                group.totals.Visible = not none
            end)
        end

        -- one separate card per armour piece
        local worn = target.worn or {}
        for pieceIndex, item in ipairs(worn) do
            cardIndex = cardIndex + 1
            local card = ac.cards[cardIndex]
            if card then
                pcall(function()
                    card.root.Visible = true
                    card.root.LayoutOrder = index * 100 + pieceIndex
                    card.name.Text = tostring(item.id)
                    card.slot.Text = acSlotLabel(item.region)
                    if item.prot > 0 then
                        card.value.Text = string.format("+%d%%", item.prot)
                        card.value.TextColor3 = Color3.fromRGB(110, 226, 130)
                    else
                        card.value.Text = "??%"
                        card.value.TextColor3 = Color3.fromRGB(230, 190, 90)
                    end
                    card.chip.Text = item.abbr or "?"
                    -- Tint marks an unknown item at a glance.
                    card.chip.BackgroundColor3 = item.known == false
                        and Color3.fromRGB(78, 62, 40)
                        or Color3.fromRGB(52, 58, 76)
                    SA.ArmorConsoleBuildIcon(card, item.source, item.id)
                end)
                ac.shown = ac.shown + 1
            end
        end
    end

    -- Hide everything the pool did not use this pass.
    for index = cardIndex + 1, #ac.cards do
        pcall(function() ac.cards[index].root.Visible = false end)
    end
    for index = groupIndex + 1, #ac.groups do
        pcall(function() ac.groups[index].root.Visible = false end)
    end

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
        cards = ac.shown or 0,
        rows = ac.shown or 0,
        pooled = #ac.cards,
        groups = #(ac.groups or {}),
        players = #(ac.targets or {}),
        inFov = inFov,
        reason = ac.reason or "idle",
        position = { x = ac.posX, y = ac.posY },
        width = ac.layoutW, height = ac.layoutH,
    }
end

bindRender(function(dt) acTick(dt, false) end)
