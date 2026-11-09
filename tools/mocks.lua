-- ==================================================================
-- Hanami / tools/mocks.lua — committed Fengari mock environment
-- Nothing here is shipped to the executor. It models just enough of
-- Roblox + Atlanta for `npm test` to execute dist/Hanami.lua end to end.
-- ==================================================================

-- ── globals / counters ──────────────────────────────────────────────
callback_errors = 0
event_errors = 0
mock_clock = 0

local function wrap_callback(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then
            callback_errors = callback_errors + 1
            print("[mock] callback error: " .. tostring(err))
        end
    end
end

function typeof(v)
    local t = type(v)
    if t == "table" then
        return rawget(v, "__kind") or "table"
    end
    return t
end

function warn(...)
    print("[warn]", ...)
end

math.clamp = math.clamp or function(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

function tick()
    mock_clock = mock_clock + 0.016
    return mock_clock
end

-- Bust the 120 ms SA.IsVisible cache between wall-check test phases.
function mock_advance_time(dt)
    mock_clock = mock_clock + (dt or 0.2)
end

mock_spawned, mock_deferred = {}, {}
task = {
    wait = function(seconds) return seconds or 0.016 end,
    -- Roblox yields here; Fengari cannot. Record the tasks so tests can
    -- assert they were installed, but never run their infinite loops.
    defer = function(fn) mock_deferred[#mock_deferred + 1] = fn end,
    spawn = function(fn) mock_spawned[#mock_spawned + 1] = fn end,
}
function wait(seconds) return seconds or 0.016 end

-- ── simple datatypes ────────────────────────────────────────────────
local function enum_item(kind, name)
    local e = { __kind = "EnumItem", Name = name, Value = 0 }
    setmetatable(e, {
        __tostring = function() return "Enum." .. kind .. "." .. name end,
    })
    return e
end

local function enum_kind(kind, fixed)
    local cache = {}
    return setmetatable({}, {
        __index = function(_, name)
            if fixed and fixed[name] == false then return nil end
            if not cache[name] then cache[name] = enum_item(kind, name) end
            return cache[name]
        end,
    })
end

Enum = setmetatable({}, {
    __index = function(t, kind)
        local fixed = nil
        if kind == "Font" then
            fixed = { Tahoma = false }
        end
        local e = enum_kind(kind, fixed)
        if kind == "Font" then
            e.ArialBold = e.ArialBold -- cache a real item
        end
        if kind == "RenderPriority" then
            local camera = e.Camera
            camera.Value = 200
        end
        t[kind] = e
        return e
    end,
})

Font = {
    fromName = function() return nil end,
    new = function() return { __kind = "Font" } end,
}

local function vec_meta(kind, ctor)
    local mt = {}
    mt.__index = function(t, k)
        if k == "X" or k == "Y" or k == "Z" then return rawget(t, k) or 0 end
        if k == "Magnitude" then
            local x = rawget(t, "X") or 0
            local y = rawget(t, "Y") or 0
            local z = rawget(t, "Z") or 0
            return math.sqrt(x * x + y * y + z * z)
        end
        if k == "Unit" then
            local m = t.Magnitude
            if m < 1e-9 then return ctor(0, 0, 0) end
            return ctor(t.X / m, t.Y / m, t.Z / m)
        end
        if k == "Lerp" then
            return function(a, b, alpha)
                return ctor(a.X + (b.X - a.X) * alpha,
                    a.Y + (b.Y - a.Y) * alpha, a.Z + (b.Z - a.Z) * alpha)
            end
        end
        if k == "Dot" then
            return function(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
        end
        if k == "Cross" then
            return function(a, b)
                return ctor(a.Y * b.Z - a.Z * b.Y,
                    a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
            end
        end
        return nil
    end
    mt.__add = function(a, b) return ctor(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
    mt.__sub = function(a, b) return ctor(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
    mt.__mul = function(a, b)
        if type(a) == "number" then return ctor(a * b.X, a * b.Y, a * b.Z) end
        if type(b) == "number" then return ctor(a.X * b, a.Y * b, a.Z * b) end
        return a
    end
    mt.__div = function(a, b)
        if type(b) == "number" then return ctor(a.X / b, a.Y / b, a.Z / b) end
        return a
    end
    mt.__unm = function(a) return ctor(-a.X, -a.Y, -a.Z) end
    mt.__tostring = function(t)
        return string.format("%s(%.3f, %.3f, %.3f)", kind, t.X, t.Y, t.Z)
    end
    return mt
end

local V3_META, V2_META
local function v3(x, y, z)
    return setmetatable({ __kind = "Vector3", X = x or 0, Y = y or 0, Z = z or 0 },
        V3_META)
end
local function v2(x, y)
    return setmetatable({ __kind = "Vector2", X = x or 0, Y = y or 0 },
        V2_META)
end
V3_META = vec_meta("Vector3", v3)
V2_META = vec_meta("Vector2", v2)

Vector3 = { new = v3 }
Vector3.zero = Vector3.new(0, 0, 0)
Vector2 = { new = v2 }
Vector2.zero = Vector2.new(0, 0)

UDim = {
    new = function(scale, offset)
        return setmetatable({ __kind = "UDim", Scale = scale or 0, Offset = offset or 0 }, {
            __tostring = function() return "UDim" end,
        })
    end,
}
UDim2 = {
    new = function(xs, xo, ys, yo)
        if type(xs) == "number" and type(xo) == "number" then
            return { __kind = "UDim2", X = UDim.new(xs, xo), Y = UDim.new(ys or 0, yo or 0) }
        end
        return { __kind = "UDim2", X = UDim.new(0, 0), Y = UDim.new(0, 0) }
    end,
    fromOffset = function(x, y) return UDim2.new(0, x or 0, 0, y or 0) end,
}

local COLOR_META = {}
COLOR_META.__index = function(t, k)
    if k == "Lerp" then
        return function(a, b, alpha)
            return Color3.new(a.R + (b.R - a.R) * alpha,
                a.G + (b.G - a.G) * alpha, a.B + (b.B - a.B) * alpha)
        end
    end
    if k == "ToHex" then
        return function()
            return string.format("#%02X%02X%02X",
                math.floor((t.R or 0) * 255 + 0.5),
                math.floor((t.G or 0) * 255 + 0.5),
                math.floor((t.B or 0) * 255 + 0.5))
        end
    end
    return rawget(t, k)
end
COLOR_META.__tostring = function(t)
    return string.format("Color3(%.3f, %.3f, %.3f)", t.R or 0, t.G or 0, t.B or 0)
end

Color3 = {
    new = function(r, g, b)
        return setmetatable({ __kind = "Color3", R = r or 0, G = g or 0, B = b or 0 }, COLOR_META)
    end,
    fromRGB = function(r, g, b)
        return Color3.new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255)
    end,
    fromHSV = function(h, sat, val)
        -- Hue is irrelevant to the assertions; keep a deterministic value.
        return Color3.new(val or 1, val or 1, val or 1)
    end,
}

local function hex_color(s)
    local r, g, b = tostring(s):match("#?(%x%x)(%x%x)(%x%x)")
    if not r then return Color3.new(1, 1, 1) end
    return Color3.fromRGB(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16))
end

local CF_META = {}
CF_META.__index = function(t, k)
    if k == "Position" then return rawget(t, "pos") or Vector3.zero end
    if k == "RightVector" then return Vector3.new(1, 0, 0) end
    if k == "UpVector" then return Vector3.new(0, 1, 0) end
    if k == "LookVector" then return Vector3.new(0, 0, -1) end
    if k == "ToObjectSpace" then
        return function(self, other)
            return CFrame.new(other.Position.X - self.Position.X,
                other.Position.Y - self.Position.Y,
                other.Position.Z - self.Position.Z)
        end
    end
    if k == "ToEulerAnglesXYZ" then
        return function() return 0, 0, 0 end
    end
    return rawget(t, k)
end
CF_META.__tostring = function() return "CFrame" end

CFrame = {
    new = function(x, y, z)
        return setmetatable({ __kind = "CFrame", pos = Vector3.new(x or 0, y or 0, z or 0) }, CF_META)
    end,
    lookAt = function(origin, target)
        return setmetatable({ __kind = "CFrame", pos = origin or Vector3.zero }, CF_META)
    end,
}

RaycastParams = {
    new = function()
        return { __kind = "RaycastParams", FilterType = nil, IgnoreWater = false,
                 FilterDescendantsInstances = {} }
    end,
}

-- ── JSON (profile round-trip) ───────────────────────────────────────
local function json_escape(s)
    s = tostring(s)
    s = s:gsub('[\\"/%c]', function(c)
        if c == "\\" then return "\\\\" end
        if c == '"' then return '\\"' end
        if c == "\n" then return "\\n" end
        if c == "\r" then return "\\r" end
        if c == "\t" then return "\\t" end
        return string.format("\\u%04x", string.byte(c))
    end)
    return '"' .. s .. '"'
end

local function is_array(t)
    local n = 0
    for k in pairs(t) do
        if type(k) ~= "number" then return false end
        if k > n then n = k end
    end
    for i = 1, n do if t[i] == nil then return false end end
    return true, n
end

local function json_encode(v)
    local t = type(v)
    if t == "nil" then return "null" end
    if t == "boolean" then return v and "true" or "false" end
    if t == "number" then return tostring(v) end
    if t == "string" then return json_escape(v) end
    if t ~= "table" then return json_escape(tostring(v)) end
    local arr, n = is_array(v)
    local parts = {}
    if arr then
        for i = 1, n do parts[i] = json_encode(v[i]) end
        return "[" .. table.concat(parts, ",") .. "]"
    end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    for _, k in ipairs(keys) do
        parts[#parts + 1] = json_escape(k) .. ":" .. json_encode(v[k])
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

local function json_decode(str)
    local pos, len = 1, #str
    local function skip()
        while pos <= len and str:sub(pos, pos):match("%s") do pos = pos + 1 end
    end
    local function parse_string()
        pos = pos + 1
        local out = {}
        while pos <= len do
            local c = str:sub(pos, pos)
            if c == '"' then pos = pos + 1; return table.concat(out) end
            if c == "\\" then
                pos = pos + 1
                local e = str:sub(pos, pos)
                if e == "n" then out[#out + 1] = "\n"
                elseif e == "r" then out[#out + 1] = "\r"
                elseif e == "t" then out[#out + 1] = "\t"
                elseif e == "u" then
                    local h = str:sub(pos + 1, pos + 4)
                    out[#out + 1] = string.char(tonumber(h, 16) or 0)
                    pos = pos + 4
                else out[#out + 1] = e end
                pos = pos + 1
            else
                out[#out + 1] = c
                pos = pos + 1
            end
        end
        error("unterminated JSON string")
    end
    local function parse_value()
        skip()
        local c = str:sub(pos, pos)
        if c == '"' then return parse_string() end
        if c == "{" then
            pos = pos + 1
            local obj = {}
            skip()
            if str:sub(pos, pos) == "}" then pos = pos + 1; return obj end
            while true do
                skip()
                local k = parse_string()
                skip()
                pos = pos + 1 -- ':'
                obj[k] = parse_value()
                skip()
                local d = str:sub(pos, pos)
                pos = pos + 1
                if d == "}" then break end
            end
            return obj
        end
        if c == "[" then
            pos = pos + 1
            local arr = {}
            skip()
            if str:sub(pos, pos) == "]" then pos = pos + 1; return arr end
            while true do
                arr[#arr + 1] = parse_value()
                skip()
                local d = str:sub(pos, pos)
                pos = pos + 1
                if d == "]" then break end
            end
            return arr
        end
        if str:sub(pos, pos + 3) == "true" then pos = pos + 4; return true end
        if str:sub(pos, pos + 4) == "false" then pos = pos + 5; return false end
        if str:sub(pos, pos + 3) == "null" then pos = pos + 4; return nil end
        local num = str:match("^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
        if num then pos = pos + #num; return tonumber(num) end
        error("bad JSON at " .. pos .. ": " .. str:sub(pos, pos + 20))
    end
    return parse_value()
end

http_service = {
    JSONEncode = function(_, v) return json_encode(v) end,
    JSONDecode = function(_, s) return json_decode(s) end,
}

-- ── virtual filesystem / executor globals ──────────────────────────
local vfs_files, vfs_dirs = {}, {}
function makefolder(path) vfs_dirs[tostring(path)] = true end
function writefile(path, data) vfs_files[tostring(path)] = tostring(data) end
function readfile(path)
    local v = vfs_files[tostring(path)]
    if v == nil then error("file not found: " .. tostring(path)) end
    return v
end
function delfile(path) vfs_files[tostring(path)] = nil end
function listfiles(path)
    path = tostring(path)
    local out = {}
    for f in pairs(vfs_files) do
        if f:sub(1, #path + 1) == path .. "/" then out[#out + 1] = f end
    end
    table.sort(out)
    return out
end
local clipboard = ""
function setclipboard(s) clipboard = tostring(s) end
function getclipboard() return clipboard end
function getgenv() return _G end
function gethui() return game:GetService("CoreGui") end
function setreadonly(t) return t end
function hookfunction(fn) return fn end
function getconnections(ev)
    if not ev or not ev._connections then return {} end
    -- Executors return a snapshot; disconnecting one entry must not mutate
    -- the array the caller is iterating.
    local out = {}
    for i, c in ipairs(ev._connections) do out[i] = c end
    return out
end
function getgc()
    return {
        { GUNS = {
            assault_rifle = { speed = 1400 },
            proto_railgun = { name = "Proto Railgun", speed = 2100, mag = 5,
                              rate = 0.4, range = 1200, spread = 1,
                              adsSpread = 0.1, moveSpread = 1, reload = 3,
                              pellets = 1, damageMult = 1, s2Damage = 80 },
        } },
    }
end

Drawing = {
    new = function(kind)
        local d = { __kind = "Drawing", Kind = kind, Visible = false,
                    Remove = function(self) self.__removed = true end }
        return d
    end,
}

-- ── events / instances ──────────────────────────────────────────────
local function new_event()
    local ev = { _connections = {} }
    function ev:Connect(fn)
        -- Executor connection objects expose .Function; keep the internal
        -- aliases too so both reorder paths can read the callback.
        local c = { Connected = true, _event = self, _fn = fn,
                    Function = fn, fn = fn, func = fn }
        function c:Disconnect()
            if not self.Connected then return end
            self.Connected = false
            for i, x in ipairs(self._event._connections) do
                if x == self then table.remove(self._event._connections, i); break end
            end
        end
        self._connections[#self._connections + 1] = c
        return c
    end
    function ev:Fire(...)
        local snapshot = {}
        for i, c in ipairs(self._connections) do snapshot[i] = c end
        for _, c in ipairs(snapshot) do
            if c.Connected then
                local ok, err = pcall(c._fn, ...)
                if not ok then
                    event_errors = event_errors + 1
                    print("[mock] event error: " .. tostring(err))
                end
            end
        end
    end
    function ev:Wait() return nil end
    return ev
end

local ISA = {
    Part = { BasePart = true, Part = true },
    Model = { Model = true }, Humanoid = { Humanoid = true },
    Tool = { Tool = true }, Accessory = { Accessory = true },
    TextLabel = { TextLabel = true },
    TextButton = { TextButton = true, TextLabel = true },
    Frame = { Frame = true }, ScreenGui = { ScreenGui = true },
    Camera = { Camera = true }, ViewportFrame = { ViewportFrame = true },
    BillboardGui = { BillboardGui = true }, Highlight = { Highlight = true },
    UIStroke = { UIStroke = true }, UICorner = { UICorner = true },
    UIListLayout = { UIListLayout = true }, UIPadding = { UIPadding = true },
    UIGradient = { UIGradient = true }, PlayerGui = { PlayerGui = true },
    CoreGui = { CoreGui = true }, StringValue = { StringValue = true },
    IntValue = { IntValue = true }, ObjectValue = { ObjectValue = true },
    Workspace = { Workspace = true }, Players = { Players = true },
    RunService = { RunService = true }, UserInputService = { UserInputService = true },
    Stats = { Stats = true }, HttpService = { HttpService = true },
}

local INST_META = {}
INST_META.__index = function(t, k)
    if k == "Size" then
        local props = rawget(t, "_props")
        return props and props.Size or nil
    end
    if k == "IsA" then
        return function(self, cls)
            local map = ISA[self.ClassName]
            return map and map[cls] == true or self.ClassName == cls
        end
    end
    if k == "FindFirstChild" then
        return function(self, name)
            for _, c in ipairs(self.children or {}) do
                if c.Name == name then return c end
            end
            return nil
        end
    end
    if k == "FindFirstChildOfClass" then
        return function(self, cls)
            for _, c in ipairs(self.children or {}) do
                if c.IsA and c:IsA(cls) then return c end
            end
            return nil
        end
    end
    if k == "FindFirstAncestorOfClass" then
        return function(self, cls)
            local p = self.Parent
            while p do
                if p.IsA and p:IsA(cls) then return p end
                p = p.Parent
            end
            return nil
        end
    end
    if k == "GetChildren" then
        return function(self) return self.children or {} end
    end
    if k == "FindFirstChildWhichIsA" then
        return function(self, cls, recursive)
            local function scan(node)
                for _, c in ipairs(node.children or {}) do
                    if c.IsA and c:IsA(cls) then return c end
                    if recursive then
                        local found = scan(c)
                        if found then return found end
                    end
                end
                return nil
            end
            return scan(self)
        end
    end
    if k == "GetDescendants" then
        return function(self)
            local out = {}
            local function walk(n)
                for _, c in ipairs(n.children or {}) do
                    out[#out + 1] = c
                    walk(c)
                end
            end
            walk(self)
            return out
        end
    end
    if k == "Destroy" then
        return function(self)
            self.__destroyed = true
            if self.Parent then
                for i, c in ipairs(self.Parent.children or {}) do
                    if c == self then table.remove(self.Parent.children, i); break end
                end
            end
            self.Parent = nil
        end
    end
    if k == "Clone" then
        return function(self)
            local function cp(n)
                local o = Instance.new(n.ClassName)
                for kk, vv in pairs(n) do
                    if kk == "_props" then
                        o._props = {}
                        for pk, pv in pairs(vv) do o._props[pk] = pv end
                    elseif kk ~= "children" and kk ~= "Parent" and kk ~= "events" then
                        o[kk] = vv
                    end
                end
                for _, c in ipairs(n.children or {}) do
                    local cc = cp(c)
                    cc.Parent = o
                end
                return o
            end
            return cp(self)
        end
    end
    if k == "GetFullName" then
        return function(self) return self.Name or self.ClassName end
    end
    if k == "GetAttribute" then
        return function(self, name) return (self.attributes or {})[name] end
    end
    if k == "SetAttribute" then
        return function(self, name, v) self.attributes[name] = v end
    end
    if k == "GetAttributes" then
        return function(self)
            local out = {}
            for kk, vv in pairs(self.attributes or {}) do out[kk] = vv end
            return out
        end
    end
    if k == "PivotTo" then return function() end end
    if k == "SetPrimaryPartCFrame" then return function() end end
    if k == "GetPivot" then return function(self) return CFrame.new(0, 0, 0) end end
    if k == "WorldToViewportPoint" then
        return function(self, p)
            local x = 640 + (p and p.X or 0) * 0.1
            local y = 360 - (p and p.Y or 0) * 10
            return Vector3.new(x, y, 1), true
        end
    end
    if k == "Raycast" then
        return function(_, origin, dir, params)
            if not MOCK_MANIP_BLOCKED or not MOCK_MANIP_WALL then return nil end
            local filters = params and params.FilterDescendantsInstances or {}
            for _, f in ipairs(filters) do
                if f == MOCK_MANIP_WALL then return nil end
            end
            return {
                Instance = MOCK_MANIP_WALL,
                Normal = Vector3.new(0, 0, -1),
                Position = origin + dir * 0.5,
                Distance = 0.5,
            }
        end
    end
    if k == "GetState" then
        return function() return Enum.HumanoidStateType.Running end
    end
    if k == "GetPropertyChangedSignal" then
        return function(self, prop)
            self._propSignals = self._propSignals or {}
            if not self._propSignals[prop] then
                self._propSignals[prop] = new_event()
            end
            return self._propSignals[prop]
        end
    end
    if k == "Activate" then
        return function()
            if MOCK_TOOL_ACTIVATE_FAIL then
                error("mock tool activation failed")
            end
            MOCK_FIRE_TOOL = (MOCK_FIRE_TOOL or 0) + 1
            return true
        end
    end
    if k == "GetNetworkPing" then return function() return 0.05 end end
    if k == "GetMouseLocation" then return function() return Vector2.new(640, 360) end end
    if k == "IsMouseButtonPressed" then return function() return false end end
    if k == "GetValue" then return function() return 50 end end
    if k == "Connect" then
        return function(self, fn)
            if not self._event then self._event = new_event() end
            return self._event:Connect(fn)
        end
    end
    if k == "Fire" then
        return function(self, ...)
            if not self._event then self._event = new_event() end
            return self._event:Fire(...)
        end
    end
    if k == "Wait" then
        return function(self)
            if not self._event then self._event = new_event() end
            return self._event:Wait()
        end
    end
    -- Roblox resolves `model.HumanoidRootPart` to a named child. Many
    -- Hanami refresh paths use that shorthand after a FindFirstChild check.
    for _, c in ipairs(t.children or {}) do
        if c.Name == k then return c end
    end
    return rawget(t, k)
end
INST_META.__newindex = function(t, k, v)
    if k == "Size" then
        local props = rawget(t, "_props")
        if not props then props = {}; rawset(t, "_props", props) end
        props.Size = v
        local sigs = rawget(t, "_propSignals")
        if sigs and sigs.Size then sigs.Size:Fire() end
        return
    end
    if k == "Parent" then
        local old = rawget(t, "Parent")
        if old and old.children then
            for i, c in ipairs(old.children) do
                if c == t then table.remove(old.children, i); break end
            end
        end
        rawset(t, "Parent", v)
        if v and v.children then v.children[#v.children + 1] = t end
        return
    end
    rawset(t, k, v)
end
INST_META.__tostring = function(t) return tostring(t.Name or t.ClassName) end

Instance = {}
function Instance.new(class)
    local o = setmetatable({
        __kind = "Instance", ClassName = class, Name = "",
        Parent = nil, children = {}, attributes = {},
        Archivable = true, Transparency = 0, Color = Color3.new(1, 1, 1),
        Health = 100, MaxHealth = 100, Visible = true,
        Position = Vector3.new(0, 0, 0), CFrame = CFrame.new(0, 3, 0),
        ViewportSize = Vector2.new(1280, 720),
    }, INST_META)
    o._props = { Size = UDim2.new(0, 0, 0, 0) }
    for _, ev in ipairs({ "MouseButton2Click", "MouseButton1Down", "MouseButton1Click",
                          "InputBegan", "InputEnded", "Activated", "CharacterAdded",
                          "ChildAdded", "ChildRemoved", "DescendantAdded",
                          "DescendantRemoving", "PlayerAdded", "PlayerRemoving",
                          "RenderStepped", "Heartbeat", "AncestryChanged" }) do
        o[ev] = new_event()
    end
    if class == "Part" or class == "MeshPart" or class == "UnionOperation" then
        o.Size = Vector3.new(2, 1, 1)
        o.CanCollide = true
        o.CanQuery = true
        o.CanTouch = true
        o.LocalTransparencyModifier = 0
    end
    return o
end

-- ── services / data model ───────────────────────────────────────────
local services = {}
local function service(name)
    if services[name] then return services[name] end
    local s = Instance.new(name)
    s.Name = name
    services[name] = s
    return s
end

local CoreGui = service("CoreGui")
local Players = service("Players")
local RunService = service("RunService")
local UserInputService = service("UserInputService")
local WorkspaceService = service("Workspace")
MOCK_MANIP_BLOCKED = false
MOCK_FIRE_TOOL = 0
MOCK_FIRE_MOUSE = 0
MOCK_FIRE_MOUSE_RELEASES = 0
MOCK_FIRE_MOUSE_CLICKS = 0
MOCK_MOUSE_FAIL = false
MOCK_TOOL_ACTIVATE_FAIL = false
function mouse1click()
    if MOCK_MOUSE_FAIL then error("mock mouse1click failed") end
    MOCK_FIRE_MOUSE_CLICKS = MOCK_FIRE_MOUSE_CLICKS + 1
end
function mouse1press()
    if MOCK_MOUSE_FAIL then error("mock mouse1press failed") end
    MOCK_FIRE_MOUSE = MOCK_FIRE_MOUSE + 1
end
function mouse1release()
    if MOCK_MOUSE_FAIL then error("mock mouse1release failed") end
    MOCK_FIRE_MOUSE_RELEASES = MOCK_FIRE_MOUSE_RELEASES + 1
end
MOCK_MANIP_WALL = Instance.new("Part")
MOCK_MANIP_WALL.Name = "MockManipWall"
MOCK_MANIP_WALL.CanQuery = true
MOCK_MANIP_WALL.Parent = WorkspaceService
local StatsService = service("Stats")
service("HttpService")

function RunService:BindToRenderStep(name, priority, fn)
    self._binds = self._binds or {}
    self._binds[name] = fn
end
function RunService:UnbindFromRenderStep(name)
    if self._binds then self._binds[name] = nil end
end
mock_frame_count = 0
function mock_frame(dt)
    dt = dt or 0.016
    mock_frame_count = mock_frame_count + 1
    RunService.RenderStepped:Fire(dt)
    for _, fn in pairs(RunService._binds or {}) do
        local ok, err = pcall(fn, dt)
        if not ok then
            callback_errors = callback_errors + 1
            print("[mock] render-step error: " .. tostring(err))
        end
    end
end
local statsNetwork = Instance.new("Folder")
statsNetwork.Name = "Network"
statsNetwork.Parent = StatsService
local statsItem = Instance.new("Folder")
statsItem.Name = "ServerStatsItem"
statsItem.Parent = statsNetwork
local pingItem = Instance.new("IntValue")
pingItem.Name = "Data Ping"
pingItem.Value = 50
pingItem.Parent = statsItem

local function make_character(name, x, toolName)
    local char = Instance.new("Model")
    char.Name = name
    char.Parent = WorkspaceService
    local hrp = Instance.new("Part")
    hrp.Name = "HumanoidRootPart"
    hrp.Position = Vector3.new(x or 0, 0, 0)
    hrp.Parent = char
    local head = Instance.new("Part")
    head.Name = "Head"
    head.Position = Vector3.new(x or 0, 1.5, 0)
    head.Parent = char
    for _, partName in ipairs({ "UpperTorso", "LowerTorso", "Left Arm",
                                "Right Arm", "Left Leg", "Right Leg" }) do
        local body = Instance.new("Part")
        body.Name = partName
        body.Position = Vector3.new(x or 0, 1, 0)
        body.Parent = char
    end
    local hum = Instance.new("Humanoid")
    hum.Name = "Humanoid"
    hum.Parent = char
    if toolName then
        local tool = Instance.new("Tool")
        tool.Name = toolName
        tool.Parent = char
    end
    char.PrimaryPart = hrp
    return char
end

local myChar = make_character("LocalCharacter", 0, "AssaultRifle")
local otherChar = make_character("NearestGuyCharacter", 10, "AssaultRifle")
local farChar = make_character("FarGuyCharacter", 30, "Pistol")
local npcChar = make_character("Guard", 20, "AssaultRifle")
npcChar.Parent = WorkspaceService

local crateModel = Instance.new("Model")
crateModel.Name = "MilitaryCrate"
crateModel.Parent = WorkspaceService
local cratePart = Instance.new("Part")
cratePart.Name = "Anchor"
cratePart.Position = Vector3.new(5, 1, 0)
cratePart.Parent = crateModel
crateModel.PrimaryPart = cratePart

-- Forego the long-lived scan loop: expose one real NPC and one real crate.
_G.__saNpcList = { npcChar }
_G.__saCrateList = { crateModel }

local localPlayer = Instance.new("Model")
localPlayer.Name = "LocalPlayer"
localPlayer.DisplayName = "LocalDisplay"
localPlayer.UserId = 1
localPlayer.Character = myChar
localPlayer.Parent = Players
local playerGui = Instance.new("PlayerGui")
playerGui.Name = "PlayerGui"
playerGui.Parent = localPlayer

local otherPlayer = Instance.new("Model")
otherPlayer.Name = "NearestGuy"
otherPlayer.DisplayName = "NearestGuyDisplay"
otherPlayer.UserId = 2
otherPlayer.Character = otherChar
otherPlayer.Parent = Players

local farPlayer = Instance.new("Model")
farPlayer.Name = "FarGuy"
farPlayer.DisplayName = "FarGuyDisplay"
farPlayer.UserId = 3
farPlayer.Character = farChar
farPlayer.Parent = Players

-- Optional Team objects for the hitbox expander teamCheck tests. Left
-- unassigned by default so the rest of the suite sees plr.Team == nil.
MOCK_TEAM_RED = { Name = "Red" }
MOCK_TEAM_BLUE = { Name = "Blue" }

-- One R15-style hat accessory whose Handle must be silenced + restored.
MOCK_HITBOX_ACCESSORY = Instance.new("Accessory")
MOCK_HITBOX_ACCESSORY.Name = "Hat"
MOCK_HITBOX_HANDLE = Instance.new("Part")
MOCK_HITBOX_HANDLE.Name = "Handle"
MOCK_HITBOX_HANDLE.CanQuery = true
MOCK_HITBOX_HANDLE.Parent = MOCK_HITBOX_ACCESSORY
MOCK_HITBOX_ACCESSORY.Parent = otherChar

-- Reset the mock rig between hitbox test cycles / after full unload.
function mock_hitbox_reset()
    local plrs = Players:GetPlayers()
    for i = 2, #plrs do
        local char = plrs[i].Character
        if char then
            for _, name in ipairs({ "Head", "UpperTorso", "LowerTorso" }) do
                local part = char:FindFirstChild(name)
                if part then
                    part.Size = Vector3.new(2, 1, 1)
                    part.CanCollide = true
                    part.CanTouch = true
                    part.CanQuery = true
                    part.LocalTransparencyModifier = 0
                end
            end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum.Health = 100 end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then hrp.Position = Vector3.new(i == 2 and 10 or 30, 0, 0) end
        end
        plrs[i].Team = nil
    end
    plrs[1].Team = nil
    MOCK_HITBOX_HANDLE.CanQuery = true
    if plrs[1].SetAttribute then plrs[1]:SetAttribute("FustMates", nil) end
end

Players.LocalPlayer = localPlayer
function Players:GetPlayers() return { localPlayer, otherPlayer, farPlayer } end
function Players:GetPlayerFromCharacter(char)
    if char == myChar then return localPlayer end
    if char == otherChar then return otherPlayer end
    if char == farChar then return farPlayer end
    return nil
end

local camera = Instance.new("Camera")
camera.Name = "Camera"
camera.CFrame = CFrame.new(0, 3, 0)
camera.ViewportSize = Vector2.new(1280, 720)
camera.Parent = WorkspaceService
WorkspaceService.CurrentCamera = camera

game = {
    GetService = function(_, name) return service(name) end,
    HttpGet = function(_, url)
        mock_httpget_url = url
        return "return library, themes"
    end,
}
-- The real Atlanta source is fetched by the game client; the mock runtime
-- already owns its `library` / `themes` globals, so return those directly.
function loadstring(source, chunkName)
    mock_library_source = source
    return function() return library, themes end
end
workspace = WorkspaceService
Workspace = WorkspaceService
CoreGui = CoreGui
Players = Players
RunService = RunService
UserInputService = UserInputService

local themePreset = setmetatable({
    text = Color3.fromRGB(230, 230, 230),
    outline = Color3.fromRGB(30, 30, 40),
}, {
    -- Luau allows `for k, v in table do`; Lua 5.3 / Fengari needs an
    -- iterator. A callable table keeps both forms working.
    __call = function(t, _, key) return next(t, key) end,
})
themes = { preset = themePreset }
config_holder = { refresh_options = function() end }

-- ── Atlanta library mock ────────────────────────────────────────────
library = {
    directory = "Atlanta",
    flags = {}, config_flags = {}, visible_flags = {},
    connections = {}, guis = {}, buttons = {},
    font = { __kind = "Font" },
    current_element_open = nil,
    cache = { Enabled = false },
}
library.keybind_list_frame = Instance.new("Frame")
library.keybind_list_frame.Name = "KeybindListFrame"
library.keybind_list_frame.Parent = CoreGui
library.keybind_list = Instance.new("Frame")
library.keybind_list.Name = "KeybindList"
library.keybind_list.Parent = library.keybind_list_frame
library.right_holder = Instance.new("Frame")
library.right_holder.Name = "LibraryRightHolder"
library.right_holder.Parent = CoreGui

function library:create(class, props, ...)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do inst[k] = v end
    if class == "ScreenGui" then self.guis[#self.guis + 1] = inst end
    return inst
end
function library:hoverify() end
function library:apply_theme() end
function library:tween() end
function library:update_theme() end
function library:panel() return { items = {} } end
function library:connection(event, fn)
    local c = event:Connect(fn)
    self.connections[#self.connections + 1] = c
    return c
end
function library:convert_enum(s)
    if type(s) ~= "string" or s == "none" then return s end
    local kind, name = s:match("Enum%.([%w_]+)%.([%w_]+)$")
    if kind and name then return Enum[kind][name] end
    return "none"
end
function library:config_list_update()
    pcall(function()
        local list = {}
        for _, f in ipairs(listfiles(self.directory .. "/configs")) do
            list[#list + 1] = tostring(f):match("([^/\\]+)%.cfg$")
        end
        if config_holder and config_holder.refresh_options then
            config_holder.refresh_options(list)
        end
    end)
end
function library:get_config()
    local Config = {}
    for flag, v in pairs(self.flags) do
        if type(v) == "table" and v.key ~= nil then
            Config[flag] = { active = v.active, mode = v.mode, key = tostring(v.key) }
        elseif type(v) == "table" and v.Transparency ~= nil and v.Color ~= nil then
            Config[flag] = { Transparency = v.Transparency, Color = v.Color:ToHex() }
        else
            Config[flag] = v
        end
    end
    return http_service:JSONEncode(Config)
end
function library:load_config(data)
    local cfg = http_service:JSONDecode(data)
    if type(cfg) ~= "table" then error("bad config") end
    for flag, v in pairs(cfg) do
        local setter = self.config_flags[flag]
        if setter then
            local ok, err
            if type(v) == "table" and v.Transparency ~= nil and v.Color ~= nil then
                ok, err = pcall(setter, hex_color(v.Color), v.Transparency)
            elseif type(v) == "table" and (v.active ~= nil or v.mode ~= nil or v.key ~= nil) then
                ok, err = pcall(setter, v)
            else
                ok, err = pcall(setter, v)
            end
            if not ok then
                callback_errors = callback_errors + 1
                print("[mock] load_config error " .. tostring(flag) .. ": " .. tostring(err))
            end
        end
    end
end

-- widget factory: every returned object inherits library methods
local function widget(extra)
    return setmetatable(extra or {}, { __index = library })
end

local function make_section(name)
    local sec = widget({ name = name })
    sec.holder = Instance.new("Frame")
    sec.holder.Name = name .. "Holder"
    sec.holder.Parent = CoreGui
    sec.right_holder = Instance.new("Frame")
    sec.right_holder.Name = name .. "RightHolder"
    sec.right_holder.Parent = sec.holder
    sec.current_holder = nil

    function sec:label(opts)
        local cfg = widget({ name = opts.text or opts.name or "Label" })
        local lbl = library:create("TextLabel", {
            Parent = self.holder, Text = cfg.name, Visible = true,
            Active = false, Size = UDim2.new(1, -8, 0, 12),
        })
        cfg.right_holder = library:create("Frame", { Parent = lbl, Name = "right_holder" })
        cfg.inst = lbl
        function cfg.set(text) lbl.Text = tostring(text) end
        -- ESP -> Colours attaches a picker directly to a label widget.
        function cfg.colorpicker(_, opts)
            return sec.colorpicker(sec, opts)
        end
        return cfg
    end

    function sec:toggle(opts)
        local cfg = widget({
            flag = opts.flag or "flag", enabled = opts.enabled == true,
            default = opts.default, callback = wrap_callback(opts.callback or function() end),
        })
        cfg.right_holder = Instance.new("Frame")
        cfg.right_holder.Parent = self.holder
        function cfg.set(v)
            v = v == true
            cfg.enabled = v
            library.flags[cfg.flag] = v
            cfg.callback(v)
        end
        library.config_flags[cfg.flag] = cfg.set
        library.visible_flags[cfg.flag] = function() end
        if cfg.default ~= nil then cfg.set(cfg.default) end
        return cfg
    end

    local function simple(opts, kind)
        local section = sec    -- the enclosing section object
        local cfg = widget({
            flag = opts.flag or "flag", default = opts.default,
            callback = wrap_callback(opts.callback or function() end),
        })
        cfg.right_holder = Instance.new("Frame")
        cfg.right_holder.Parent = section.holder
        function cfg.set(v)
            library.flags[cfg.flag] = v
            cfg.value = v
            cfg.callback(v)
        end
        library.config_flags[cfg.flag] = cfg.set
        library.visible_flags[cfg.flag] = function() end
        if cfg.default ~= nil then cfg.set(cfg.default) end
        return cfg
    end

    function sec:slider(opts) return simple(opts, "slider") end
    function sec:dropdown(opts) return simple(opts, "dropdown") end
    function sec:textbox(opts) return simple(opts, "textbox") end

    function sec:colorpicker(opts)
        local cfg = widget({
            flag = opts.flag or "flag", default = opts.color,
            callback = wrap_callback(opts.callback or function() end),
        })
        function cfg.set(c, t)
            c = c or Color3.new(1, 1, 1)
            t = t or 1
            library.flags[cfg.flag] = { Color = c, Transparency = t }
            cfg.callback(c)
        end
        library.config_flags[cfg.flag] = cfg.set
        library.visible_flags[cfg.flag] = function() end
        if cfg.default ~= nil then cfg.set(cfg.default, 1) end
        return cfg
    end

    function sec:button_holder(opts)
        self.current_holder = Instance.new("Frame")
        self.current_holder.Name = "ButtonHolder"
        self.current_holder.Parent = self.holder
        return widget({ holder = self.current_holder })
    end
    function sec:button(opts)
        local cfg = widget({ name = opts.name or "Button",
                             callback = wrap_callback(opts.callback or function() end) })
        library.buttons[cfg.name] = cfg.callback
        return cfg
    end
    function sec:list(opts)
        return widget({ flag = opts.flag, refresh_options = function() end })
    end
    function sec:esp_preview() return widget({}) end
    return sec
end

local function make_column(tab)
    local col = widget({ tab = tab })
    function col:section(opts) return make_section(opts.name or "Section") end
    function col:multi_section(opts)
        local out = {}
        for _, n in ipairs(opts.names or {}) do out[#out + 1] = make_section(n) end
        return table.unpack(out)
    end
    return col
end

local function make_tab(name)
    local tab = widget({ name = name, opened = false })
    function tab:column() return make_column(self) end
    -- Hanami calls Aiming.open_tab() with a dot, so accept both forms.
    function tab:open_tab() (self or tab).opened = true end
    return tab
end

local function libraryWindow(self, opts)
    opts = opts or {}
    local win = widget({ name = opts.name or "Hanami", opened = true })
    -- `library.window` must be published as the current window object for
    -- the built-in UI Bind, but re-executing calls library:window() again.
    -- Make the published object callable so both uses work.
    setmetatable(win, {
        __index = library,
        __call = function(_, s, o) return libraryWindow(s, o) end,
    })
    win.sgui = library:create("ScreenGui", {
        Name = "HanamiWindow", Parent = CoreGui, Enabled = true,
        DisplayOrder = 100,
    })
    local panel = library:create("Frame", {
        Name = "MainPanel", Parent = win.sgui,
        Size = UDim2.new(0, 750, 0, 782), Position = UDim2.new(0, 20, 0, 20),
    })
    local espHolder = library:create("Frame", {
        Name = "EspPreviewHolder", Parent = win.sgui,
        Size = UDim2.new(0, 300, 0, 325), Position = UDim2.new(0, 780, 0, 20),
    })
    win.esp_section = make_section("ESP Preview")
    win.esp_section.holder = espHolder
    function win.set_menu_visibility(v)
        win.opened = v == true
        for _, g in ipairs(library.guis) do
            if g and g.Enabled ~= nil then g.Enabled = win.opened end
        end
    end
    function win:tab(opts) return make_tab(opts.name or "Tab") end
    library.window = win   -- MUST exist before the built-in UI Bind
    -- Atlanta's unnamed Insert UI Bind. Hanami rewrites it to RightShift.
    self:keybind({ callback = win.set_menu_visibility, key = Enum.KeyCode.Insert })
    return win
end
library.window = libraryWindow

-- ── stock keybind, close enough for profile / mode / None tests ─────
function library.keybind(self, opts)
    opts = opts or {}
    local cfg = widget({
        flag = opts.flag or "flag", name = opts.name,
        callback = wrap_callback(opts.callback or function() end),
        key = opts.key or "none", mode = opts.mode or "toggle",
        active = opts.default == true, ignore_key = opts.ignore_key,
        hold_instances = {}, open = false, binding = nil,
        key_name = tostring(opts.key or "none"),
    })
    local listLbl = library:create("TextLabel", {
        Parent = library.keybind_list, Text = "", Visible = false,
        Active = false, Name = "KeybindRow",
    })
    local button = library:create("TextButton", {
        Parent = self.right_holder or library.right_holder,
        Size = UDim2.new(0, 24, 0, 14), Text = "", Name = "KeybindButton",
    })
    local keyText = library:create("TextLabel", {
        Parent = button, Text = string.lower(tostring(cfg.key)), Name = "KeyText",
    })
    local selector = library:create("Frame", {
        Parent = library.window.sgui, Visible = false, Name = "KeybindSelector",
    })
    for _, modeName in ipairs({ "toggle", "hold", "always" }) do
        library:create("TextButton", {
            Parent = selector, Text = modeName, Name = modeName .. "Button",
        })
    end

    library.flags[cfg.flag] = { mode = cfg.mode, key = cfg.key, active = cfg.active }
    library.config_flags[cfg.flag] = nil -- wrapper overwrites this
    library.visible_flags[cfg.flag] = function() end

    function cfg.set_element_visible(v) button.Visible = v == true end
    function cfg.set_visible(v) selector.Visible = v == true end
    function cfg.set_mode(mode)
        cfg.mode = mode
        if mode == "always" then cfg.set(true)
        elseif mode == "hold" then cfg.set(false) end
        library.flags[cfg.flag].mode = mode
    end

    function cfg.set(input)
        if type(input) == "boolean" then
            local cached = input
            if cfg.mode == "always" then cached = true end
            cfg.active = cached
            library.flags[cfg.flag].active = cached
            cfg.callback(cached)
        elseif tostring(input):find("Enum") then
            input = (input.Name == "Escape") and "none" or input
            cfg.key = input or "none"
            cfg.key_name = tostring(cfg.key):gsub("Enum.", "")
            library.flags[cfg.flag].mode = cfg.mode
            library.flags[cfg.flag].key = cfg.key
            keyText.Text = string.lower(cfg.key_name)
            cfg.callback(cfg.active or false)
        elseif input == "toggle" or input == "hold" or input == "always" then
            cfg.set_mode(input)
            if input == "always" then cfg.active = true end
            cfg.callback(cfg.active or false)
        elseif type(input) == "table" then
            input.key = type(input.key) == "string" and input.key ~= "none"
                and library:convert_enum(input.key) or input.key
            input.key = input.key == Enum.KeyCode.Escape and "none" or input.key
            cfg.key = input.key or "none"
            cfg.mode = input.mode or "toggle"
            if input.active ~= nil then cfg.active = input.active end
            cfg.key_name = tostring(cfg.key):gsub("Enum.", "")
            keyText.Text = string.lower(cfg.key_name)
            -- NO callback here: this is exactly what load_config relies on.
            library.flags[cfg.flag] = { mode = cfg.mode, key = cfg.key,
                                        active = cfg.active }
        end
        if cfg.name then
            listLbl.Text = string.format("[ %s ] %s - %s",
                string.upper(cfg.mode:sub(1, 1)) .. cfg.mode:sub(2),
                cfg.name, tostring(cfg.key_name))
            listLbl.Visible = cfg.active
        end
        return cfg
    end

    button.MouseButton2Click:Connect(function()
        cfg.open = not cfg.open
        cfg.set_visible(cfg.open)
    end)
    button.MouseButton1Down:Connect(function()
        cfg.binding = library:connection(UserInputService.InputBegan, function(input)
            local selected = input.UserInputType == Enum.UserInputType.Keyboard
                and input.KeyCode or input.UserInputType
            cfg.set(selected)
            cfg.binding:Disconnect()
            cfg.binding = nil
        end)
    end)
    library:connection(UserInputService.InputBegan, function(input, game_event)
        if game_event then return end
        local selected = input.UserInputType == Enum.UserInputType.Keyboard
            and input.KeyCode or input.UserInputType
        if selected == cfg.key then
            if cfg.mode == "toggle" then
                cfg.active = not cfg.active
                cfg.set(cfg.active)
            elseif cfg.mode == "hold" then
                cfg.set(true)
            end
        end
    end)
    library:connection(UserInputService.InputEnded, function(input, game_event)
        if game_event then return end
        local selected = input.UserInputType == Enum.UserInputType.Keyboard
            and input.KeyCode or input.UserInputType
        if selected == cfg.key and cfg.mode == "hold" then cfg.set(false) end
    end)

    cfg.set({ mode = cfg.mode, active = cfg.active, key = cfg.key })
    cfg.inst, cfg.listLbl = button, listLbl
    return cfg
end

print("[runtime] mocks loaded")
