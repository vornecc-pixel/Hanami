-- ==================================================================
-- Hanami / 26_armor_viewer_ui.lua — Armor Viewer panel + render tick
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
--
-- Data layer (protection table, FustWear analysis, FOV / nearest
-- crosshair ordering, icon lookup) lives in 26_armor_viewer.lua.
-- This part only owns the window, the row pool and the scan tick.
-- ==================================================================

-- ── GUI ─────────────────────────────────────────────────────────────
local armorScreen, armorMain, armorScroll, armorListLayout = nil, nil, nil, nil
local armorStamp, armorTitle, armorResize = nil, nil, nil
local armorRowPool, armorRowLive = {}, 0
local armorBuilt = false
local armorVisible = false

-- Internal counters live in one table; SA.ArmorViewerState() is the
-- read-only accessor other parts (and the tests) call.
local armorState = {
    scans = 0, rows = 0, errors = 0,
    lastCount = 0, lastInFov = 0, lastError = nil,
}

local ARMOR_COL = {
    bg      = Color3.fromRGB(18, 19, 23),
    card    = Color3.fromRGB(30, 31, 37),
    header  = Color3.fromRGB(24, 25, 30),
    stroke  = Color3.fromRGB(50, 52, 60),
    text    = Color3.fromRGB(232, 232, 236),
    dim     = Color3.fromRGB(152, 154, 162),
    good    = Color3.fromRGB(120, 200, 140),
    bad     = Color3.fromRGB(190, 96, 96),
    fov     = Color3.fromRGB(120, 190, 255),
    accent  = Color3.fromRGB(170, 200, 220),
}

local function armorPx(n) return UDim.new(0, n) end

-- Row objects are RECYCLED. The reference viewer destroyed and rebuilt
-- every frame's GUI on each 5 s scan, which is a lot of instance churn
-- for a panel that changes rarely. Here a scan only rewrites text and
-- shows / hides rows from a pool.
local function armorNewRow()
    local row = Instance.new("Frame")
    row.BackgroundColor3 = ARMOR_COL.header
    row.BorderSizePixel = 0
    row.Visible = false
    row.Parent = armorScroll
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = row
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.new(0, 10, 0, 0)
    label.Size = UDim2.new(1, -20, 1, 0)
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.TextColor3 = ARMOR_COL.text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextTruncate = Enum.TextTruncate.AtEnd
    label.Parent = row
    return row
end

local function armorTakeRow()
    armorRowLive = armorRowLive + 1
    local row = armorRowPool[armorRowLive]
    if not row then
        row = armorNewRow()
        armorRowPool[armorRowLive] = row
    end
    row.Visible = true
    row.LayoutOrder = armorRowLive
    return row
end

local function armorHideRowsFrom(n)
    for i = n, #armorRowPool do
        local row = armorRowPool[i]
        if row and row.Visible then row.Visible = false end
    end
end

-- A resizable, draggable window. The reference viewer was a fixed 340 px
-- column; this one remembers its own geometry in CFG so a saved profile
-- restores it, and the bottom-right grip resizes it.
local function armorClampOnScreen()
    local vp = SA.ViewportSize and SA.ViewportSize() or Vector2.new(1280, 720)
    -- The same bounds 01_config enforces on a saved profile, further
    -- limited by the viewport so the window always fits the screen.
    local w = math.clamp(tonumber(CFG.armorWindowW) or 360, 280,
        math.max(280, math.min(720, vp.X - 16)))
    local h = math.clamp(tonumber(CFG.armorWindowH) or 470, 240,
        math.max(240, math.min(900, vp.Y - 16)))
    local x = math.clamp(tonumber(CFG.armorWindowX) or 260, -w + 80, vp.X - 80)
    local y = math.clamp(tonumber(CFG.armorWindowY) or 120, 0, vp.Y - 60)
    CFG.armorWindowW, CFG.armorWindowH = w, h
    CFG.armorWindowX, CFG.armorWindowY = x, y
    return x, y, w, h
end

local function armorApplyGeometry()
    if not armorMain then return end
    local x, y, w, h = armorClampOnScreen()
    armorMain.Position = UDim2.new(0, x, 0, y)
    armorMain.Size = UDim2.new(0, w, 0, h)
end

local function armorBuild()
    if armorBuilt then return true end
    local ok = pcall(function()
        local pg = lp:FindFirstChild("PlayerGui")
            or lp:WaitForChild("PlayerGui", 3)
        if not pg then error("PlayerGui unavailable") end
        local old = pg:FindFirstChild("HanamiArmorViewer")
        if old then old:Destroy() end

        local screen = Instance.new("ScreenGui")
        screen.Name = "HanamiArmorViewer"
        screen.ResetOnSpawn = false
        screen.IgnoreGuiInset = true
        screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        -- Below the main menu window so the panel never covers it.
        screen.DisplayOrder = 40
        screen.Parent = pg
        armorScreen = screen

        local main = Instance.new("Frame")
        main.Name = "Main"
        main.BackgroundColor3 = ARMOR_COL.bg
        main.BackgroundTransparency = 0.08
        main.BorderSizePixel = 0
        main.Parent = screen
        armorMain = main

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = main
        local stroke = Instance.new("UIStroke")
        stroke.Color = ARMOR_COL.stroke
        stroke.Thickness = 1
        stroke.Parent = main

        local title = Instance.new("TextLabel")
        title.BackgroundTransparency = 1
        title.Position = UDim2.new(0, 10, 0, 6)
        title.Size = UDim2.new(1, -60, 0, 20)
        title.Font = Enum.Font.GothamBold
        title.TextSize = 13
        title.TextColor3 = ARMOR_COL.text
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Text = "Armor Viewer"
        title.Parent = main
        armorTitle = title

        local stamp = Instance.new("TextLabel")
        stamp.BackgroundTransparency = 1
        stamp.Position = UDim2.new(0, 10, 0, 26)
        stamp.Size = UDim2.new(1, -60, 0, 14)
        stamp.Font = Enum.Font.Gotham
        stamp.TextSize = 10
        stamp.TextColor3 = ARMOR_COL.dim
        stamp.TextXAlignment = Enum.TextXAlignment.Left
        stamp.Text = ""
        stamp.Parent = main
        armorStamp = stamp

        -- Close button.
        local close = Instance.new("TextButton")
        close.BackgroundColor3 = ARMOR_COL.card
        close.BorderSizePixel = 0
        close.Position = UDim2.new(1, -50, 0, 6)
        close.Size = UDim2.new(0, 18, 0, 18)
        close.Font = Enum.Font.GothamBold
        close.TextSize = 12
        close.TextColor3 = ARMOR_COL.dim
        close.Text = "x"
        close.Parent = main
        local closeCorner = Instance.new("UICorner")
        closeCorner.CornerRadius = UDim.new(0, 4)
        closeCorner.Parent = close
        close.MouseButton1Click:Connect(function()
            CFG.armorViewer = false
            armorVisible = false
            if main then main.Visible = false end
        end)

        local scroll = Instance.new("ScrollingFrame")
        scroll.BackgroundTransparency = 1
        scroll.BorderSizePixel = 0
        scroll.Position = UDim2.new(0, 8, 0, 44)
        scroll.Size = UDim2.new(1, -16, 1, -56)
        scroll.ScrollBarThickness = 4
        scroll.ScrollBarImageColor3 = ARMOR_COL.stroke
        scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        scroll.Parent = main
        armorScroll = scroll

        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 4)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = scroll
        armorListLayout = layout

        local pad = Instance.new("UIPadding")
        pad.PaddingTop = UDim.new(0, 4)
        pad.PaddingBottom = UDim.new(0, 4)
        pad.Parent = scroll

        -- Resize grip (bottom-right).
        local grip = Instance.new("TextButton")
        grip.BackgroundTransparency = 1
        grip.Position = UDim2.new(1, -18, 1, -18)
        grip.Size = UDim2.new(0, 18, 0, 18)
        grip.Text = "//"
        grip.Font = Enum.Font.Code
        grip.TextSize = 11
        grip.TextColor3 = ARMOR_COL.dim
        grip.Parent = main
        armorResize = grip

        -- ── drag ──
        local dragging, dragStart, startPos = false, nil, nil
        main.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = Vector2.new(CFG.armorWindowX, CFG.armorWindowY)
            end
        end)
        main.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
                -- Persist the drop position.
                if CFG.armorLockPos == true or true then
                    armorApplyGeometry()
                end
            end
        end)
        -- UIS is not required to move the window: the movement is applied
        -- from InputChanged so a touch drag works too.
        main.InputChanged:Connect(function(input)
            if not dragging then return end
            if input.UserInputType ~= Enum.UserInputType.MouseMovement
                and input.UserInputType ~= Enum.UserInputType.Touch then return end
            local delta = input.Position - dragStart
            CFG.armorWindowX = startPos.X + delta.X
            CFG.armorWindowY = startPos.Y + delta.Y
            armorApplyGeometry()
        end)

        -- ── resize ──
        local resizing, resizeStart, startSize = false, nil, nil
        grip.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                resizing = true
                resizeStart = input.Position
                startSize = Vector2.new(CFG.armorWindowW, CFG.armorWindowH)
            end
        end)
        grip.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                resizing = false
                armorApplyGeometry()
            end
        end)
        grip.InputChanged:Connect(function(input)
            if not resizing then return end
            if input.UserInputType ~= Enum.UserInputType.MouseMovement
                and input.UserInputType ~= Enum.UserInputType.Touch then return end
            local delta = input.Position - resizeStart
            CFG.armorWindowW = startSize.X + delta.X
            CFG.armorWindowH = startSize.Y + delta.Y
            armorApplyGeometry()
        end)
    end)
    if not ok then
        armorState.lastError = "build failed"
        return false
    end
    armorBuilt = true
    armorApplyGeometry()
    return true
end

-- ── Rendering the list ──────────────────────────────────────────────
local function armorRender(targets)
    if not armorBuilt then return end
    armorRowLive = 0
    local shown = 0
    for _, t in ipairs(targets) do
        local worn, regions = SA.ArmorAnalyze(t.char)
        if not CFG.armorOnlyInFov or t.inFov then
            -- header row
            local header = armorTakeRow()
            header.BackgroundColor3 = ARMOR_COL.header
            header.Size = UDim2.new(1, 0, 0, 34)
            local hl = header:FindFirstChildOfClass("TextLabel")
            if hl then
                hl.RichText = true
                local bits = {}
                bits[#bits + 1] = "<b>" .. tostring(t.name) .. "</b>"
                if t.inFov then
                    bits[#bits + 1] = '<font color="#78BEFF">[FOV]</font>'
                end
                if t.behind then
                    bits[#bits + 1] = '<font color="#BE6060">[BEHIND]</font>'
                end
                bits[#bits + 1] = string.format("%dm", math.floor(t.dist / 3.571))
                hl.Text = table.concat(bits, "  ")
                hl.TextSize = 12
                hl.TextColor3 = ARMOR_COL.text
            end
            shown = shown + 1

            if CFG.armorShowTotals == true then
                local totals = armorTakeRow()
                totals.BackgroundColor3 = ARMOR_COL.card
                totals.Size = UDim2.new(1, 0, 0, 20)
                local tl = totals:FindFirstChildOfClass("TextLabel")
                if tl then
                    tl.RichText = true
                    tl.Font = Enum.Font.Code
                    tl.TextSize = 10
                    tl.TextColor3 = ARMOR_COL.accent
                    local parts = {}
                    for _, r in ipairs(ARMOR_REGIONS) do
                        parts[#parts + 1] = string.format("%s:%d%%",
                            r:sub(1, 1), regions[r] or 0)
                    end
                    tl.Text = table.concat(parts, "   ")
                end
                shown = shown + 1
            end

            if #worn == 0 then
                local none = armorTakeRow()
                none.BackgroundColor3 = ARMOR_COL.card
                none.Size = UDim2.new(1, 0, 0, 18)
                local nl = none:FindFirstChildOfClass("TextLabel")
                if nl then
                    nl.Text = "    no gear"
                    nl.TextSize = 11
                    nl.TextColor3 = ARMOR_COL.dim
                end
                shown = shown + 1
            else
                for _, item in ipairs(worn) do
                    local row = armorTakeRow()
                    row.BackgroundColor3 = ARMOR_COL.card
                    row.Size = UDim2.new(1, 0, 0, 22)
                    local lbl = row:FindFirstChildOfClass("TextLabel")
                    if lbl then
                        local icon = ""
                        if CFG.armorShowIcons == true then
                            icon = armorIconAbbr(item.id) .. "  "
                        end
                        lbl.RichText = true
                        lbl.TextSize = 11
                        lbl.TextColor3 = ARMOR_COL.text
                        local protText
                        if item.known then
                            protText = string.format(
                                '<font color="#78C88C">+%d%%</font>', item.prot)
                        else
                            protText = '<font color="#BE6060">??</font>'
                        end
                        lbl.Text = string.format("%s%s   %s   %s",
                            icon, item.id,
                            item.region or "?",
                            protText)
                    end
                    shown = shown + 1
                end
            end
        end
    end
    if shown == 0 then
        local empty = armorTakeRow()
        empty.BackgroundColor3 = ARMOR_COL.card
        empty.Size = UDim2.new(1, 0, 0, 22)
        local el = empty:FindFirstChildOfClass("TextLabel")
        if el then
            el.Text = CFG.armorOnlyInFov
                and "  nothing in the FOV circle"
                or "  no players with gear in range"
            el.TextColor3 = ARMOR_COL.dim
            el.TextSize = 11
        end
    end
    armorHideRowsFrom(armorRowLive + 1)
end

-- ── Scan state ──────────────────────────────────────────────────────
function SA.ArmorViewerState()
    local st = armorState
    return {
        enabled = CFG.armorViewer == true,
        built = armorBuilt,
        visible = armorVisible,
        scans = st.scans,
        players = st.lastCount,
        inFov = st.lastInFov,
        rows = st.rows,
        errors = st.errors,
        lastError = st.lastError,
        sortMode = CFG.armorSortMode,
        onlyInFov = CFG.armorOnlyInFov == true,
        window = {
            x = CFG.armorWindowX, y = CFG.armorWindowY,
            w = CFG.armorWindowW, h = CFG.armorWindowH,
        },
    }
end

-- Force one refresh now (the UI button and tests use this).
function SA.ArmorViewerRefresh()
    if not armorBuilt then
        if not armorBuild() then return false end
    end
    local st = armorState
    local ok, err = pcall(function()
        local targets = SA.ArmorTargets()
        local inFov = 0
        for _, t in ipairs(targets) do
            if t.inFov then inFov = inFov + 1 end
        end
        -- "Most Armor" needs the total, which costs one analyse pass; do
        -- it once here instead of sorting on a value nobody computed.
        if (CFG.armorSortMode or "") == "Most Armor" then
            for _, t in ipairs(targets) do
                local _, regions = SA.ArmorAnalyze(t.char)
                t.sortValue = SA.ArmorTotal(regions)
            end
            table.sort(targets, function(a, b)
                if a.inFov ~= b.inFov then return a.inFov end
                return (a.sortValue or 0) > (b.sortValue or 0)
            end)
        end
        armorRender(targets)
        st.scans = st.scans + 1
        st.lastCount = #targets
        st.lastInFov = inFov
        st.rows = armorRowLive
        if armorStamp then
            armorStamp.Text = string.format(
                "%d player%s · %d in FOV · %s",
                #targets, #targets == 1 and "" or "s", inFov,
                os.date("%X"))
        end
        if armorTitle then
            armorTitle.Text = CFG.armorOnlyInFov
                and "Armor Viewer — FOV only"
                or "Armor Viewer"
        end
    end)
    if not ok then
        st.errors = st.errors + 1
        st.lastError = tostring(err)
        return false
    end
    return true
end

-- Re-apply the saved geometry (the "Reset Window Position" button and a
-- profile load both land here).
function SA.ArmorViewerResetGeometry()
    if not armorBuilt then return false end
    pcall(armorApplyGeometry)
    return true
end

function SA.ArmorViewerDispose()
    if armorScreen then
        pcall(function() armorScreen:Destroy() end)
    end
    armorScreen, armorMain, armorScroll, armorListLayout = nil, nil, nil, nil
    armorStamp, armorTitle, armorResize = nil, nil, nil
    armorRowPool, armorRowLive = {}, 0
    armorBuilt, armorVisible = false, false
    return true
end

-- ── The render tick ─────────────────────────────────────────────────
-- Bound once. It does NOTHING until the toggle is on (an early return
-- before any work), and the panel itself is rebuilt from CFG state each
-- scan so a saved profile / quick action restores it.
local armorTicker = 0
local armorLastScan = 0

bindRender(function(dt)
    if CFG.armorViewer ~= true then
        if armorVisible then
            armorVisible = false
            if armorMain then armorMain.Visible = false end
        end
        return
    end
    armorTicker = armorTicker + 1
    local fresh = false
    if not armorBuilt then
        -- Cold start: build AND populate on the first frame the toggle is
        -- seen, never wait out the scan interval (the same lesson as the
        -- ESP build guard). An empty panel for two seconds reads as broken.
        if not armorBuild() then return end
        fresh = true
    end
    armorVisible = true
    if armorMain and not armorMain.Visible then armorMain.Visible = true end
    -- Scan at most once per CFG.armorScanSec; the panel is cheap to keep
    -- on screen but the scan walks every character's FustWear folder.
    local intervalFrames = math.max(
        math.floor((tonumber(CFG.armorScanSec) or 2) * 60), 1)
    if fresh or (armorTicker - armorLastScan) >= intervalFrames then
        armorLastScan = armorTicker
        pcall(SA.ArmorViewerRefresh)
    end
end)
