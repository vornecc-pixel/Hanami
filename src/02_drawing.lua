-- ==================================================================
-- Hanami / 02_drawing.lua — Drawing compatibility layer
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- WHY THIS EXISTS
-- FOV circle, ESP boxes, skeleton, head dots, tracers and off-screen
-- arrows are all `Drawing` objects. Many executors expose only PART of
-- that API: `Drawing.new("Line")` works but `Drawing.new("Circle")`
-- returns an object whose Radius / NumSides / Filled cannot be written.
-- The old code probed only "Line" once, so a broken Circle silently
-- killed the FOV circle (and could abort the whole chunk at load time).
--
-- FIXES:
--  * capability is probed PER KIND, against every property that kind
--    actually uses, not just "Line";
--  * a failed property write at runtime can invalidate that kind and
--    force the GUI fallback (SA.InvalidateDrawKind);
--  * `CFG.forceGuiDrawing` lets the user skip the native API entirely;
--  * the ScreenGui parent is searched in the most reliable order
--    (gethui -> CoreGui -> PlayerGui) and re-tried on every call, so a
--    GUI that becomes available later is picked up;
--  * `SA.DrawDiag()` reports exactly what is available.
-- ────────────────────────────────────────────────────────────────────

local drawGui       = _G.__saDrawGui
local nativeOK      = {}      -- kind -> true / false (lazy capability cache)
local proxyCount    = 0
local drawLastError = "none"
local drawWriteFailures, drawLastWriteError = 0, "none"

local PROPS = {
    Line     = { "Visible", "Color", "Transparency", "Thickness", "From", "To" },
    Circle   = { "Visible", "Color", "Transparency", "Thickness", "Filled",
                 "NumSides", "Radius", "Position" },
    Triangle = { "Visible", "Color", "Transparency", "Thickness", "Filled",
                 "PointA", "PointB", "PointC" },
}
local TESTVAL = {
    Visible = false, Color = Color3.new(1, 1, 1), Transparency = 0.5,
    Thickness = 1, Filled = true, NumSides = 24, Radius = 10,
    Position = Vector2.new(0, 0), From = Vector2.new(0, 0),
    To = Vector2.new(10, 10), PointA = Vector2.new(0, 0),
    PointB = Vector2.new(10, 0), PointC = Vector2.new(5, 10),
}

local function nativeAvailable(kind, ignoreForce)
    if not ignoreForce and CFG and CFG.forceGuiDrawing then return false end
    if nativeOK[kind] ~= nil then return nativeOK[kind] end
    local ok, obj = pcall(function() return Drawing.new(kind) end)
    if not ok or not obj then
        nativeOK[kind] = false
        drawLastError = "Drawing.new(" .. kind .. ") failed"
        return false
    end
    local good, why = true, nil
    for _, p in ipairs(PROPS[kind] or {}) do
        local wrote = pcall(function() obj[p] = TESTVAL[p] end)
        if not wrote then good, why = false, p; break end
    end
    pcall(function() if obj.Remove then obj:Remove() end end)
    nativeOK[kind] = good
    if not good then drawLastError = "native " .. kind .. " cannot write " .. tostring(why) end
    return good
end

local function getDrawGui()
    -- A destroyed / unparented overlay from a previous run must be replaced.
    if drawGui and drawGui.Parent then return drawGui end
    drawGui = nil

    local parents = {}
    -- PlayerGui FIRST: it is the standard Roblox container and is
    -- guaranteed to render. CoreGui often accepts a child from an
    -- executor but hides it behind CoreGui content (another reason the
    -- FOV circle "didn't show up"). gethui() is the last resort.
    pcall(function()
        local pg = lp and (lp:FindFirstChildOfClass("PlayerGui")
                          or lp:FindFirstChild("PlayerGui"))
        if pg then table.insert(parents, pg) end
    end)
    pcall(function() table.insert(parents, game:GetService("CoreGui")) end)
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
                gui.Enabled = true
                gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
                gui.Parent = parent
                return gui
            end)
            if ok and sg then
                drawGui = sg
                _G.__saDrawGui = sg
                pcall(function()
                    drawLastError = "overlay parent: " .. tostring(parent:GetFullName())
                end)
                return drawGui
            end
        end
    end
    drawLastError = "no usable ScreenGui parent (gethui / CoreGui / PlayerGui)"
    return nil
end

-- Re-executing the loader must not reuse a stale overlay: an older build
-- may have parented it to CoreGui where the executor hides it. Destroy it
-- and let getDrawGui() create a fresh one with the new parent order.
if _G.__saDrawGui then
    pcall(function() _G.__saDrawGui:Destroy() end)
    _G.__saDrawGui = nil
    drawGui = nil
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

    local stroke
    if kind == "Circle" then
        local corner = Instance.new("UICorner")
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
            frame.Rotation = math.deg(SA.Atan2(d.Y, d.X))
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
                return function()
                    pcall(function() frame:Destroy() end)
                    proxyCount = math.max(proxyCount - 1, 0)
                end
            end
            if k == "Backend" then return "ScreenGui" end
            return st[k]
        end,
        __newindex = function(_, k, v)
            -- Most properties (colour, thickness, visible) are rewritten
            -- with the same value every frame. Skip the GUI sync for those
            -- so the fallback backend doesn't do thousands of redundant
            -- Instance writes per frame and re-introduce a stutter.
            if st[k] == v then return end
            st[k] = v
            local okSync, errSync = pcall(sync)
            if not okSync then
                drawWriteFailures = drawWriteFailures + 1
                drawLastWriteError = tostring(errSync)
            end
        end,
    })
    proxyCount = proxyCount + 1
    sync()
    return proxy
end

-- A GUI parent may not exist yet (very early execution, protected CoreGui).
-- Returning nil made callers such as buildESP() crash on `d.Thickness = 1`
-- inside a RenderStepped callback. A harmless no-op proxy keeps every
-- caller alive; the FOV circle retries until a real backend is available.
local function noopDraw()
    local st = { Backend = "none", Visible = false }
    return setmetatable({}, {
        __index = function(_, k)
            if k == "Remove" then return function() end end
            return st[k]
        end,
        __newindex = function(_, k, v) st[k] = v end,
    })
end

-- ────────────────────────────────────────────────────────────────────
-- SCREEN-SPACE TEXT ("Text" draw kind)
-- ESP text used to live in a BillboardGui stacked above the head, so the
-- weapon / state / VIS line could only ever sit at the top. A real
-- TextLabel in the shared ScreenGui overlay can be anchored to the exact
-- box geometry: name above, weapon BELOW, flags beside the corner.
--
-- Native Drawing.new("Text") is deliberately NOT used: its font enum only
-- exposes UI/System/Plex/Monospace and cannot render a Tahoma FontFace.
-- The GUI path also works on every executor the Line/Circle fallback does.
-- ────────────────────────────────────────────────────────────────────
local function textDraw()
    local gui = getDrawGui()
    if not gui then return nil end

    local ok, lbl = pcall(function()
        local t = Instance.new("TextLabel")
        t.Name = "HanamiText"
        t.BackgroundTransparency = 1
        t.BackgroundColor3 = Color3.fromRGB(10, 12, 16)
        t.BorderSizePixel = 0
        t.Text = ""
        t.TextColor3 = Color3.new(1, 1, 1)
        t.TextSize = 12
        t.Font = SA.ESP_FONT or Enum.Font.ArialBold
        if SA.ESP_FONT_FACE then t.FontFace = SA.ESP_FONT_FACE end
        t.TextStrokeColor3 = Color3.new(0, 0, 0)
        t.TextStrokeTransparency = 0
        t.TextXAlignment = Enum.TextXAlignment.Center
        t.TextYAlignment = Enum.TextYAlignment.Center
        t.TextWrapped = false
        t.Visible = false
        t.Active = false
        t.Selectable = false
        t.ZIndex = 2
        -- Round the optional dark backdrop into a badge. Older clients
        -- without UICorner simply keep square labels.
        pcall(function()
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0.3, 0)
            corner.Parent = t
        end)
        t.Parent = gui
        return t
    end)
    if not ok or not lbl then return nil end

    local st = {
        Visible = false, Text = "", Color = Color3.new(1, 1, 1),
        Transparency = 0, TextSize = 12, ZIndex = 2,
        Size = Vector2.new(220, 16), Position = Vector2.new(0, 0),
        Anchor = Vector2.new(0.5, 0.5), Align = "Center",
        Outline = true, Backdrop = false,
    }

    local function sync()
        lbl.Visible = st.Visible == true
        lbl.Text = st.Text or ""
        lbl.TextColor3 = st.Color
        lbl.TextTransparency = math.clamp(st.Transparency or 0, 0, 1)
        lbl.TextSize = math.clamp(st.TextSize or 12, 6, 40)
        lbl.TextStrokeTransparency = st.Outline and 0 or 1
        lbl.ZIndex = st.ZIndex or 2
        lbl.Size = UDim2.fromOffset(st.Size.X, st.Size.Y)
        lbl.Position = UDim2.fromOffset(st.Position.X, st.Position.Y)
        pcall(function() lbl.AnchorPoint = st.Anchor end)
        pcall(function()
            local a = st.Align
            lbl.TextXAlignment = (a == "Left" and Enum.TextXAlignment.Left)
                or (a == "Right" and Enum.TextXAlignment.Right)
                or Enum.TextXAlignment.Center
        end)
        pcall(function()
            lbl.BackgroundTransparency = st.Backdrop and 0.55 or 1
        end)
    end

    local proxy = {}
    setmetatable(proxy, {
        __index = function(_, k)
            if k == "Remove" then
                return function()
                    pcall(function() lbl:Destroy() end)
                    proxyCount = math.max(proxyCount - 1, 0)
                end
            end
            if k == "Backend" then return "ScreenGui" end
            return st[k]
        end,
        __newindex = function(_, k, v)
            if st[k] == v then return end
            st[k] = v
            local okSync, errSync = pcall(sync)
            if not okSync then
                drawWriteFailures = drawWriteFailures + 1
                drawLastWriteError = tostring(errSync)
            end
        end,
    })
    proxyCount = proxyCount + 1
    sync()
    return proxy
end

-- ── BETTER: drawing pool (Performance Mode) ─────────────────────────
-- Toggling ESP features used to Destroy + Instance.new a ScreenGui proxy
-- for every element of every entity. With Performance Mode ON, freed
-- GUI proxies are hidden and reused instead. Native Drawing userdata
-- cannot be tagged, so those still go through the normal Remove path.
SA.DrawPool = SA.DrawPool or {}
local DRAW_POOL_CAP = 64

function SA.DrawPoolTake(kind)
    local bucket = SA.DrawPool[kind]
    if not bucket or #bucket == 0 then return nil end
    local d = table.remove(bucket)
    if type(d) ~= "table" then return nil end
    pcall(function() d.Visible = false end)
    return d
end

function SA.RecycleDraw(d)
    if CFG.perfMode ~= true or type(d) ~= "table" then
        pcall(removeDrawing, d)
        return false
    end
    local kind = d.__saPoolKind
    if not kind then pcall(removeDrawing, d); return false end
    pcall(function() d.Visible = false end)
    local bucket = SA.DrawPool[kind] or {}
    if #bucket >= DRAW_POOL_CAP then
        pcall(removeDrawing, d)
        return false
    end
    bucket[#bucket + 1] = d
    SA.DrawPool[kind] = bucket
    return true
end

function SA.DrawPoolStats()
    local total, kinds = 0, {}
    for k, b in pairs(SA.DrawPool) do
        total = total + #b
        kinds[#kinds + 1] = k .. ":" .. #b
    end
    table.sort(kinds)
    return { total = total, byKind = table.concat(kinds, ","),
             enabled = CFG.perfMode == true }
end

function SA.NewDraw(kind)
    -- Text is GUI-only (see textDraw above); never probe a native Text
    -- object, because its font enum cannot express Tahoma.
    if kind == "Text" then
        return textDraw() or noopDraw()
    end
    local guiFirst = (CFG and CFG.forceGuiDrawing) == true or nativeOK[kind] == false

    -- Preferred backend: ScreenGui (forced, or native already proven bad).
    if guiFirst then
        local g = fallbackDraw(kind)
        if g then return g end
        -- No GUI parent exists on this executor at all -> try native below
        -- instead of returning a dead no-op object.
    end

    -- `ignoreForce` lets native be a LAST RESORT when the GUI parent is
    -- missing, so "Force ScreenGui Drawing" can never make everything
    -- disappear on an executor that only supports Drawing.
    if nativeAvailable(kind, guiFirst) then
        local ok, obj = pcall(function() return Drawing.new(kind) end)
        if ok and obj then return obj end
        nativeOK[kind] = false
        drawLastError = "Drawing.new(" .. kind .. ") failed at runtime"
    end

    if not guiFirst then
        local g = fallbackDraw(kind)
        if g then return g end
    end
    return noopDraw()
end

-- Called when a native object's property write fails at runtime: force
-- that kind (and everything else, for consistency) onto the GUI backend.
function SA.InvalidateDrawKind(kind)
    if kind then nativeOK[kind] = false end
    drawWriteFailures = drawWriteFailures + 1
    drawLastWriteError = drawLastError
    drawLastError = "runtime write on native " .. tostring(kind) .. " failed -> GUI fallback"
end

function SA.DrawBackend()
    if CFG and CFG.forceGuiDrawing then
        return (drawGui and drawGui.Parent) and "ScreenGui (forced)"
            or "ScreenGui (forced, NO PARENT YET)"
    end
    if drawGui and drawGui.Parent then return "ScreenGui" end
    local any = false
    for _, v in pairs(nativeOK) do if v then any = true end end
    return any and "Drawing" or "unavailable / lazy"
end

function SA.DrawWriteFailures()
    return { count = drawWriteFailures, last = drawLastWriteError,
             backend = SA.DrawBackend() }
end

function SA.DrawDiag()
    local kinds = {}
    for _, k in ipairs({ "Line", "Circle", "Triangle" }) do
        kinds[#kinds + 1] = k .. "=" .. (CFG.forceGuiDrawing
            and "skipped(forced GUI)" or tostring(nativeAvailable(k)))
    end
    return table.concat({
        "backend=" .. SA.DrawBackend(),
        "native: " .. table.concat(kinds, ", "),
        "font=" .. tostring(SA.ESP_FONT_NAME),
        "Text=ScreenGui (Tahoma FontFace when available)",
        "overlay=" .. (drawGui and drawGui.Parent and drawGui:GetFullName() or "NONE"),
        "proxies=" .. tostring(proxyCount),
        "writeFailures=" .. tostring(drawWriteFailures),
        "lastWrite=" .. drawLastWriteError,
        "last=" .. drawLastError,
    }, " | ")
end
