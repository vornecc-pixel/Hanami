-- ==================================================================
-- Hanami / 02_drawing.lua — Drawing compatibility layer
-- Loaded in order by loader.lua. Parts are joined into ONE chunk
-- before running, so every `local` is shared just like the original.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- WHY THIS EXISTS
-- FOV circle, ESP boxes, skeleton, head dots, tracers and off-screen
-- arrows are all `Drawing` objects. Many executors expose only part of
-- that API (or none at all): `Drawing.new` fails inside a pcall and every
-- visual silently disappears, while BillboardGui text still renders.
--
-- SA.NewDraw(kind) probes the native API once. If it is missing or
-- incomplete, it returns a proxy backed by real Roblox GUI Frames in a
-- ScreenGui, implementing the exact same property interface:
--   Line     : Visible Color Transparency Thickness From To
--   Circle   : Visible Color Transparency Thickness Filled NumSides Radius Position
--   Triangle : Visible Color Transparency Filled PointA PointB PointC
--   all      : Remove()
-- ────────────────────────────────────────────────────────────────────

local drawNative = false
local drawGui = _G.__saDrawGui

local function probeNative()
    local ok, newFn = pcall(function() return Drawing and Drawing.new end)
    if not ok or not newFn then return false end
    local made, obj = pcall(function() return Drawing.new("Line") end)
    if not made or not obj then return false end
    local writable = pcall(function()
        obj.Visible = false
        obj.Color = Color3.new(1, 1, 1)
        obj.Transparency = 0.5
        obj.Thickness = 1
        obj.From = Vector2.new(0, 0)
        obj.To = Vector2.new(10, 10)
    end)
    pcall(function() if obj.Remove then obj:Remove() end end)
    return writable
end

drawNative = probeNative()

local function getDrawGui()
    if drawGui and drawGui.Parent then return drawGui end
    local parents = {}
    pcall(function() table.insert(parents, game:GetService("CoreGui")) end)
    pcall(function() table.insert(parents, lp:FindFirstChild("PlayerGui")) end)
    if typeof(gethui) == "function" then
        pcall(function() table.insert(parents, gethui()) end)
    end
    for _, parent in ipairs(parents) do
        if parent then
            local ok, sg = pcall(function()
                local old = parent:FindFirstChild("HanamiOverlay")
                if old then old:Destroy() end
                local gui = Instance.new("ScreenGui")
                gui.Name = "HanamiOverlay"
                gui.ResetOnSpawn = false
                gui.IgnoreGuiInset = true
                gui.DisplayOrder = 999
                gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
                gui.Parent = parent
                return gui
            end)
            if ok and sg then
                drawGui = sg
                _G.__saDrawGui = sg
                return drawGui
            end
        end
    end
    return nil
end

-- Discard a stale overlay from a previous run if this run uses native.
if drawNative and _G.__saDrawGui then
    pcall(function() _G.__saDrawGui:Destroy(); _G.__saDrawGui = nil end)
end

local function fallbackDraw(kind)
    local gui = getDrawGui()
    if not gui then return nil end

    local frame = Instance.new("Frame")
    frame.Name = "Hanami" .. kind
    frame.BorderSizePixel = 0
    frame.BackgroundColor3 = Color3.new(1, 1, 1)
    frame.BackgroundTransparency = 0
    frame.Visible = false
    frame.Active = false
    frame.Selectable = false
    frame.ZIndex = 1
    frame.Parent = gui

    local corner, stroke
    if kind == "Circle" then
        corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0.5, 0)
        corner.Parent = frame
        stroke = Instance.new("UIStroke")
        stroke.Thickness = 1
        stroke.Parent = frame
    end

    local st = {
        Visible = false, Color = Color3.new(1, 1, 1), Transparency = 0,
        Thickness = 1, ZIndex = 1, NumSides = 24, Filled = true,
        From = Vector2.new(0, 0), To = Vector2.new(0, 0),
        Position = Vector2.new(0, 0), Radius = 10,
        PointA = Vector2.new(0, 0), PointB = Vector2.new(0, 0),
        PointC = Vector2.new(0, 0),
    }

    local function sync()
        frame.Visible = st.Visible == true
        frame.BackgroundColor3 = st.Color
        frame.ZIndex = st.ZIndex or 1
        local a = math.clamp(st.Transparency or 0, 0, 1)
        if kind == "Line" then
            local d = st.To - st.From
            local len = math.max(d.Magnitude, 0.01)
            frame.AnchorPoint = Vector2.new(0.5, 0.5)
            frame.Size = UDim2.fromOffset(len, math.max(st.Thickness or 1, 1))
            frame.Position = UDim2.fromOffset((st.From.X + st.To.X) / 2,
                                              (st.From.Y + st.To.Y) / 2)
            frame.Rotation = math.deg(math.atan2(d.Y, d.X))
            frame.BackgroundTransparency = a
        elseif kind == "Circle" then
            local r = math.max(st.Radius or 1, 1)
            frame.AnchorPoint = Vector2.new(0.5, 0.5)
            frame.Size = UDim2.fromOffset(r * 2, r * 2)
            frame.Position = UDim2.fromOffset(st.Position.X, st.Position.Y)
            frame.Rotation = 0
            stroke.Enabled = not st.Filled
            if st.Filled then
                frame.BackgroundTransparency = a
            else
                frame.BackgroundTransparency = 1
                stroke.Color = st.Color
                stroke.Thickness = math.max(st.Thickness or 1, 1)
                stroke.Transparency = a
            end
        elseif kind == "Triangle" then
            -- rotated square (diamond) so arrows are visible on executors
            -- that have no Triangle primitive
            local cx = (st.PointA.X + st.PointB.X + st.PointC.X) / 3
            local cy = (st.PointA.Y + st.PointB.Y + st.PointC.Y) / 3
            local size = math.max((st.PointA - st.PointB).Magnitude, 6)
            frame.AnchorPoint = Vector2.new(0.5, 0.5)
            frame.Size = UDim2.fromOffset(size, size)
            frame.Position = UDim2.fromOffset(cx, cy)
            frame.Rotation = 45
            frame.BackgroundTransparency = st.Filled and a or 1
        else
            frame.BackgroundTransparency = a
        end
    end

    local proxy = {}
    setmetatable(proxy, {
        __index = function(_, k)
            if k == "Remove" then
                return function() pcall(function() frame:Destroy() end) end
            end
            return st[k]
        end,
        __newindex = function(_, k, v)
            -- Most properties (colour, thickness, visible) are rewritten
            -- with the same value every frame. Skip the GUI sync for those
            -- so the fallback backend doesn't do thousands of redundant
            -- Instance writes per frame and re-introduce a stutter.
            if st[k] == v then return end
            st[k] = v
            pcall(sync)
        end,
    })
    sync()
    return proxy
end

function SA.NewDraw(kind)
    if drawNative then
        local ok, obj = pcall(function() return Drawing.new(kind) end)
        if ok and obj then
            local usable = true
            if kind == "Triangle" then
                usable = pcall(function() obj.PointA = Vector2.new(0, 0) end)
            end
            if usable then return obj end
            pcall(function() if obj.Remove then obj:Remove() end end)
            drawNative = false   -- downgrade this session to the GUI backend
        else
            drawNative = false
        end
    end
    return fallbackDraw(kind)
end

function SA.DrawBackend()
    return drawNative and "Drawing" or (drawGui and "ScreenGui" or "unavailable")
end
