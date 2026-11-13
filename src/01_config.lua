-- ==================================================================
-- Hanami / 01_config.lua — Services, config defaults, backfill, shared state
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================

-- ==================================================================
-- @abusegpt — Silent Aim + Wall Pen + ESP + Crate ESP + Gun Mods
-- Pure renderstep + raycast. No metatable writes on silent aim.
-- Gun mods use rawget/rawset + setreadonly (GC scan).
-- ==================================================================

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local Workspace         = game:GetService("Workspace")
local lp                = Players.LocalPlayer
local ws                = workspace

-- ────────────────────────────────────────────────────────────────────
-- SHARED STATE
-- A plain table so early parts can call helpers assigned by later parts
-- (no forward-local problem), while `_G` keeps it across re-executes.
-- ────────────────────────────────────────────────────────────────────

local SA = _G.__saShared or {}
_G.__saShared = SA
SA.Target = SA.Target or {}   -- current aim-preview target, written by 11_snapline
SA.Alive  = true              -- set false by "Unload Everything" to stop scanners
-- A loader re-execute is a NEW instance: clear the one-shot unload guard
-- and any self-check report from the previous generation.
SA.Unloaded = false
SA.LastSelfCheck = nil
SA.LastUnload = nil
-- Luau keeps math.atan2(y, x); standard Lua 5.3 (and Fengari) removed it
-- in favour of the two-argument math.atan(y, x). One shared alias keeps
-- the GUI drawing fallback working in both runtimes.
SA.Atan2 = math.atan2 or math.atan

-- ── ONE per-frame clock ──────────────────────────────────────────────
-- Every ESP / aim / snapline tick must agree on "now". Calling tick()
-- inside each per-entity branch (SA.IsVisible, SA.ScanEntity, the FX
-- pass, the snapline, saRefreshAimTarget) made the SAME frame look like a
-- different tick() to every consumer: the 20 Hz aim refresh, the 120 ms
-- LOS cache and the 250 ms scan cache each expired at a different point
-- inside one frame, so a target could be "fresh" for the box and "stale"
-- for the name in the same pass. A single stamp per RenderStepped frame
-- removes that jitter and is strictly increasing, so `now - last` can
-- never go negative (which used to re-pick the target twice per frame).
-- SA.FrameClock() returns the cached stamp; SA.FrameClockTick() advances
-- it (once per render callback through bindRender()).
local saFrameClock, saFrameClockStamp = nil, nil
function SA.FrameClock()
    if saFrameClock == nil then saFrameClock = tick() end
    return saFrameClock
end
function SA.FrameClockTick()
    local real = tick()
    if saFrameClockStamp == nil or real <= saFrameClockStamp then
        -- The clock did not advance (same millisecond, or a fixed mock
        -- clock): keep a strictly increasing stamp so every TTL test
        -- behaves like a real frame instead of dividing by zero time.
        if saFrameClockStamp == nil then saFrameClockStamp = real
        else saFrameClockStamp = saFrameClockStamp + 0.0001 end
    else
        saFrameClockStamp = real
    end
    saFrameClock = saFrameClockStamp
    return saFrameClock
end
function SA.FrameClockReset()
    saFrameClock, saFrameClockStamp = nil, nil
    return true
end

-- The ESP labels and the nearest-player HUD both convert Roblox studs to
-- metres with the same factor (1 m ≈ 3.571 studs).
SA.STUDS_PER_METER = 3.571
-- Re-executing the loader bumps the generation: old scanner loops exit and
-- the new chunk starts exactly one replacement loop.
SA.Generation = (SA.Generation or 0) + 1

-- Direct service / RenderStepped connections are NOT in Atlanta's
-- library.connections, so the library's "Unload Menu" never stopped them.
-- Keep a generation-scoped registry and disconnect it on re-execute AND
-- on either full-unload path below.
local saConns = _G.__saConnections or {}
_G.__saConnections = saConns
SA.TrackedConnections = saConns
local saDisconnected = 0

function SA.TrackConnection(conn)
    if conn ~= nil then saConns[#saConns + 1] = conn end
    return conn
end

function SA.Connect(signal, fn)
    local ok, conn = pcall(function() return signal:Connect(fn) end)
    if not ok then return nil end
    return SA.TrackConnection(conn)
end

function SA.DisconnectConnections()
    local n = 0
    for i = #saConns, 1, -1 do
        local c = saConns[i]
        saConns[i] = nil
        if c then
            pcall(function() c:Disconnect() end)
            n = n + 1
        end
    end
    saDisconnected = saDisconnected + n
    return n
end

function SA.ConnectionState()
    return { tracked = #saConns, disconnected = saDisconnected }
end

-- A loader re-execute replaces every direct event hook instead of stacking it.
SA.DisconnectConnections()

-- Every RenderStepped loop binds through this helper. Re-executing the
-- loader bumps Generation, so loops from the previous run disconnect
-- themselves instead of piling up duplicate work (a common cause of a
-- stutter that gets worse the more times you run the script).
local function bindRender(fn)
    local gen = SA.Generation
    local conn
    conn = SA.Connect(RunService.RenderStepped, function(...)
        if (SA.Generation or 0) ~= gen then
            pcall(function() conn:Disconnect() end)
            return
        end
        -- ONE clock stamp for every consumer in this frame (aim refresh,
        -- LOS cache, scan cache, FOV snapshot, snapline). Without it the
        -- same frame produced several different tick() values, so the
        -- throttled caches expired mid-pass and target picking ran more
        -- than once per frame.
        SA.FrameClockTick()
        fn(...)
        -- Coalesce all ScreenGui proxy writes made by this render callback
        -- into ONE sync per dirty draw (02_drawing.lua). The native
        -- Drawing backend writes its own properties directly and needs no
        -- flush, so this is a no-op when no GUI proxy was touched.
        if SA.DrawSyncFlush then pcall(SA.DrawSyncFlush) end
    end)
    return conn
end

-- ────────────────────────────────────────────────────────────────────
-- EVENT-DRIVEN FONT + ATLANTA THEME REGISTRY
-- Ten built-in / script-community font picks and ten full Atlanta theme
-- presets are resolved only on a dropdown change or once at startup.
-- Nothing here runs in RenderStepped: live font changes walk existing
-- text instances once, then every ESP label is refreshed from a weak
-- registry. Theme changes call Atlanta's update_theme once per colour key.
-- ────────────────────────────────────────────────────────────────────
function SA.EspFontRegistryReset()
    SA.__saEspFontLabels = setmetatable({}, { __mode = "k" })
    SA.__saFontStatusLabels = setmetatable({}, { __mode = "k" })
end
SA.EspFontRegistryReset()
SA.__saThemeApplyCount, SA.__saFontApplyCount = 0, 0
SA.__saThemeApplied, SA.__saFontApplied = nil, nil
SA.__saThemeLastApplied, SA.__saFontMenuInstances = 0, 0

SA.UI_FONTS = {
    { name = "Tahoma",           enum = "ArialBold",      family = "Tahoma" },
    { name = "Arial Bold",       enum = "ArialBold",      family = "Arial" },
    { name = "Arial",            enum = "Arial",          family = "Arial" },
    { name = "Gotham Bold",      enum = "GothamBold",     family = "GothamSSm" },
    { name = "Gotham",           enum = "Gotham",         family = "GothamSSm" },
    { name = "Source Sans Bold", enum = "SourceSansBold", family = "SourceSansPro" },
    { name = "Source Sans Pro",  enum = "SourceSans",     family = "SourceSansPro" },
    { name = "Roboto Mono",      enum = "RobotoMono",     family = "RobotoMono" },
    { name = "Ubuntu",           enum = "Ubuntu",         family = "Ubuntu" },
    { name = "Code",             enum = "Code",           family = "Code" },
}
SA.UI_FONT_NAMES, SA.UI_FONT_BY_NAME = {}, {}
for _, entry in ipairs(SA.UI_FONTS) do
    SA.UI_FONT_NAMES[#SA.UI_FONT_NAMES + 1] = entry.name
    SA.UI_FONT_BY_NAME[entry.name] = entry
end

SA.UI_THEME_KEYS = { "outline", "inline", "accent", "contrast",
    "high_contrast", "low_contrast", "text", "text_outline", "glow" }
SA.UI_THEME_NAMES = { "Atlanta", "Midnight", "Sakura", "Ocean",
    "Cyberpunk", "Crimson", "Forest", "Violet", "Mono", "Sunset" }
SA.UI_THEMES = {
    ["Atlanta"] = {
        outline = { 10, 10, 10 }, inline = { 45, 45, 45 },
        accent = { 96, 120, 190 }, contrast = { 20, 20, 20 },
        high_contrast = { 20, 20, 20 }, low_contrast = { 30, 30, 30 },
        text = { 180, 180, 180 }, text_outline = { 0, 0, 0 },
        glow = { 96, 120, 190 },
    },
    ["Midnight"] = {
        outline = { 5, 8, 18 }, inline = { 18, 27, 48 },
        accent = { 72, 130, 255 }, contrast = { 8, 12, 24 },
        high_contrast = { 10, 15, 30 }, low_contrast = { 16, 24, 42 },
        text = { 220, 230, 255 }, text_outline = { 0, 0, 0 },
        glow = { 64, 110, 220 },
    },
    ["Sakura"] = {
        outline = { 35, 12, 24 }, inline = { 70, 28, 50 },
        accent = { 255, 110, 170 }, contrast = { 28, 10, 20 },
        high_contrast = { 42, 14, 28 }, low_contrast = { 58, 20, 40 },
        text = { 255, 225, 238 }, text_outline = { 20, 0, 10 },
        glow = { 255, 95, 155 },
    },
    ["Ocean"] = {
        outline = { 4, 18, 28 }, inline = { 12, 48, 66 },
        accent = { 40, 190, 210 }, contrast = { 6, 24, 35 },
        high_contrast = { 8, 32, 48 }, low_contrast = { 14, 42, 58 },
        text = { 215, 245, 250 }, text_outline = { 0, 10, 15 },
        glow = { 35, 170, 210 },
    },
    ["Cyberpunk"] = {
        outline = { 8, 5, 20 }, inline = { 30, 12, 55 },
        accent = { 255, 60, 210 }, contrast = { 12, 8, 28 },
        high_contrast = { 18, 10, 38 }, low_contrast = { 26, 16, 48 },
        text = { 230, 220, 255 }, text_outline = { 0, 0, 0 },
        glow = { 0, 230, 255 },
    },
    ["Crimson"] = {
        outline = { 22, 5, 8 }, inline = { 60, 14, 18 },
        accent = { 230, 45, 55 }, contrast = { 18, 4, 6 },
        high_contrast = { 30, 8, 10 }, low_contrast = { 42, 10, 14 },
        text = { 255, 225, 225 }, text_outline = { 10, 0, 0 },
        glow = { 255, 70, 60 },
    },
    ["Forest"] = {
        outline = { 6, 18, 10 }, inline = { 18, 48, 28 },
        accent = { 80, 200, 110 }, contrast = { 8, 22, 12 },
        high_contrast = { 10, 30, 16 }, low_contrast = { 14, 38, 22 },
        text = { 225, 250, 230 }, text_outline = { 0, 10, 0 },
        glow = { 65, 190, 105 },
    },
    ["Violet"] = {
        outline = { 14, 8, 26 }, inline = { 40, 24, 70 },
        accent = { 160, 110, 255 }, contrast = { 18, 10, 32 },
        high_contrast = { 24, 14, 44 }, low_contrast = { 32, 20, 56 },
        text = { 238, 228, 255 }, text_outline = { 5, 0, 10 },
        glow = { 145, 90, 255 },
    },
    ["Mono"] = {
        outline = { 8, 8, 8 }, inline = { 38, 38, 38 },
        accent = { 190, 190, 190 }, contrast = { 12, 12, 12 },
        high_contrast = { 18, 18, 18 }, low_contrast = { 28, 28, 28 },
        text = { 235, 235, 235 }, text_outline = { 0, 0, 0 },
        glow = { 160, 160, 160 },
    },
    ["Sunset"] = {
        outline = { 28, 12, 8 }, inline = { 72, 34, 22 },
        accent = { 255, 145, 60 }, contrast = { 24, 10, 8 },
        high_contrast = { 36, 16, 12 }, low_contrast = { 50, 22, 16 },
        text = { 255, 238, 215 }, text_outline = { 12, 4, 0 },
        glow = { 255, 95, 70 },
    },
}
SA.UI_THEME_BY_NAME = SA.UI_THEMES

function SA.FontEnum(name)
    local item = nil
    pcall(function() item = Enum.Font[name] end)
    if not item then pcall(function() item = Enum.Font.ArialBold end) end
    return item
end

function SA.FontFace(entry, enumItem)
    local face = nil
    if type(Font) ~= "table" then return nil end
    if entry.family == "Tahoma" then
        if type(Font.fromName) == "function" then
            pcall(function()
                face = Font.fromName("Tahoma", Enum.FontWeight.Regular,
                    Enum.FontStyle.Normal)
            end)
        end
        if not face and type(Font.new) == "function" then
            pcall(function()
                face = Font.new("rbxasset://fonts/families/Tahoma.json",
                    Enum.FontWeight.Regular, Enum.FontStyle.Normal)
            end)
        end
    end
    if not face and type(Font.fromEnum) == "function" then
        pcall(function() face = Font.fromEnum(enumItem) end)
    end
    if not face and type(Font.fromName) == "function" then
        pcall(function()
            face = Font.fromName(entry.family, Enum.FontWeight.Regular,
                Enum.FontStyle.Normal)
        end)
    end
    if not face and type(Font.new) == "function" then
        pcall(function()
            face = Font.new("rbxasset://fonts/families/" .. entry.family .. ".json",
                Enum.FontWeight.Regular, Enum.FontStyle.Normal)
        end)
    end
    return face
end

function SA.ResolveFont(name)
    local wanted = tostring(name or "Source Sans Pro")
    local entry = SA.UI_FONT_BY_NAME[wanted] or SA.UI_FONT_BY_NAME["Source Sans Pro"]
    local enumItem = SA.FontEnum(entry.enum)
    return {
        name = entry.name, display = entry.name, family = entry.family,
        enumName = entry.enum, enum = enumItem,
        face = SA.FontFace(entry, enumItem),
    }
end

SA.ESP_FONT      = SA.FontEnum("SourceSans")
SA.ESP_FONT_FACE = nil
SA.ESP_FONT_NAME = "Source Sans Pro"

function SA.ApplyEspFont(lbl)
    if not lbl then return end
    SA.__saEspFontLabels[lbl] = true
    pcall(function() lbl.Font = SA.ESP_FONT end)
    if SA.ESP_FONT_FACE then
        -- FontFace wins over the legacy Font property when it loads; if
        -- the family is unavailable the pcall keeps the enum fallback.
        pcall(function() lbl.FontFace = SA.ESP_FONT_FACE end)
    end
end

function SA.ApplyEspFontAll()
    local n = 0
    for lbl in pairs(SA.__saEspFontLabels or {}) do
        pcall(function() SA.ApplyEspFont(lbl) end)
        n = n + 1
    end
    return n
end

function SA.RegisterFontStatusLabel(obj)
    if not obj then return end
    SA.__saFontStatusLabels[obj] = true
    pcall(function() obj.set("Font: " .. tostring(SA.ESP_FONT_NAME)) end)
end

function SA.UpdateFontStatusLabels()
    local n = 0
    for obj in pairs(SA.__saFontStatusLabels or {}) do
        pcall(function() obj.set("Font: " .. tostring(SA.ESP_FONT_NAME)) end)
        n = n + 1
    end
    return n
end

local function saApplyFontInstance(inst, resolved, seen)
    if not inst or seen[inst] then return end
    seen[inst] = true
    local isText = false
    pcall(function()
        isText = inst:IsA("TextLabel") or inst:IsA("TextButton")
            or inst:IsA("TextBox")
    end)
    if not isText then return end
    pcall(function() inst.Font = resolved.enum end)
    if resolved.face then pcall(function() inst.FontFace = resolved.face end) end
end

function SA.ApplyFont(name)
    local resolved = SA.ResolveFont(name)
    if type(CFG) == "table" then CFG.uiFont = resolved.name end
    SA.ESP_FONT, SA.ESP_FONT_FACE = resolved.enum, resolved.face
    SA.ESP_FONT_NAME = resolved.display
    local seen, menuInstances = {}, 0
    if type(library) == "table" then
        if resolved.face then library.font = resolved.face end
        for _, gui in ipairs(library.guis or {}) do
            pcall(function()
                saApplyFontInstance(gui, resolved, seen)
                for _, child in ipairs(gui:GetDescendants()) do
                    saApplyFontInstance(child, resolved, seen)
                    menuInstances = menuInstances + 1
                end
            end)
        end
        for _, inst in ipairs(library.instances or {}) do
            saApplyFontInstance(inst, resolved, seen)
        end
    end
    SA.__saFontMenuInstances = menuInstances
    SA.ApplyEspFontAll()
    SA.UpdateFontStatusLabels()
    SA.__saFontApplied = resolved.name
    SA.__saFontApplyCount = (SA.__saFontApplyCount or 0) + 1
    return true, resolved.name
end

function SA.FontState()
    return {
        name = SA.__saFontApplied, display = SA.ESP_FONT_NAME,
        family = (SA.ResolveFont(SA.__saFontApplied)).family,
        enumName = (SA.ResolveFont(SA.__saFontApplied)).enumName,
        face = SA.ESP_FONT_FACE, menuInstances = SA.__saFontMenuInstances,
        espLabels = SA.ApplyEspFontAll(), statusLabels = SA.UpdateFontStatusLabels(),
        picks = #SA.UI_FONT_NAMES, applyCount = SA.__saFontApplyCount or 0,
    }
end

function SA.ApplyTheme(name)
    local wanted = tostring(name or "Atlanta")
    if not SA.UI_THEME_BY_NAME[wanted] then wanted = "Atlanta" end
    local preset = SA.UI_THEME_BY_NAME[wanted]
    if type(CFG) == "table" then CFG.uiTheme = wanted end
    if type(themes) ~= "table" or type(library) ~= "table"
        or type(library.update_theme) ~= "function" then
        return false, 0
    end
    local applied = 0
    for _, key in ipairs(SA.UI_THEME_KEYS) do
        local rgb = preset[key]
        if rgb then
            local color = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
            local good = pcall(function() library:update_theme(key, color) end)
            if good then applied = applied + 1 end
        end
    end
    SA.__saThemeApplied = wanted
    SA.__saThemeApplyCount = (SA.__saThemeApplyCount or 0) + 1
    SA.__saThemeLastApplied = applied
    return applied == #SA.UI_THEME_KEYS, applied
end

function SA.ThemeState()
    return {
        name = SA.__saThemeApplied, presets = #SA.UI_THEME_NAMES,
        keys = #SA.UI_THEME_KEYS, applied = SA.__saThemeLastApplied or 0,
        applyCount = SA.__saThemeApplyCount or 0,
        colors = (type(themes) == "table") and themes.preset or {},
    }
end

-- ────────────────────────────────────────────────────────────────────
-- UNIFIED ESP PALETTE — EVERY INLINE PICKER SHIPS WHITE
-- One table for EVERY drawn element. Every key has its own picker
-- chained INLINE onto the toggle / slider / dropdown it belongs to;
-- there is no separate Colours tab or mini-tab. The table survives
-- re-execution via _G. One-time migration clears older saved palettes.
-- --------------------------------------------------------------------
local ESP_DEFAULT_COLORS = {
    -- dynamic visibility (white until the user picks a colour)
    playerVisible        = Color3.fromRGB(255, 255, 255),
    playerHidden         = Color3.fromRGB(255, 255, 255),
    playerFlat           = Color3.fromRGB(255, 255, 255),
    npcVisible           = Color3.fromRGB(255, 255, 255),
    npcHidden            = Color3.fromRGB(255, 255, 255),
    npcFlat              = Color3.fromRGB(255, 255, 255),

    -- per-NPC-archetype colours (all white by default)
    npcGuard             = Color3.fromRGB(255, 255, 255),
    npcScavenger         = Color3.fromRGB(255, 255, 255),
    npcSoldier           = Color3.fromRGB(255, 255, 255),

    -- player per-element
    playerName           = Color3.fromRGB(255, 255, 255),
    playerDistance       = Color3.fromRGB(255, 255, 255),
    playerInfo           = Color3.fromRGB(255, 255, 255),
    playerBox            = Color3.fromRGB(255, 255, 255),
    playerFill           = Color3.fromRGB(255, 255, 255),
    playerOutline        = Color3.fromRGB(255, 255, 255),
    playerHealthHigh     = Color3.fromRGB(255, 255, 255),
    playerHealthLow      = Color3.fromRGB(255, 255, 255),
    playerSkeleton       = Color3.fromRGB(255, 255, 255),
    playerHeadDot        = Color3.fromRGB(255, 255, 255),
    playerTracer         = Color3.fromRGB(255, 255, 255),
    playerOffscreen      = Color3.fromRGB(255, 255, 255),
    playerVisDot         = Color3.fromRGB(255, 255, 255),

    -- npc per-element
    npcName              = Color3.fromRGB(255, 255, 255),
    npcDistance          = Color3.fromRGB(255, 255, 255),
    npcInfo              = Color3.fromRGB(255, 255, 255),
    npcBox               = Color3.fromRGB(255, 255, 255),
    npcFill              = Color3.fromRGB(255, 255, 255),
    npcOutline           = Color3.fromRGB(255, 255, 255),
    npcHealthHigh        = Color3.fromRGB(255, 255, 255),
    npcHealthLow         = Color3.fromRGB(255, 255, 255),
    npcSkeleton          = Color3.fromRGB(255, 255, 255),
    npcHeadDot           = Color3.fromRGB(255, 255, 255),
    npcTracer            = Color3.fromRGB(255, 255, 255),
    npcOffscreen         = Color3.fromRGB(255, 255, 255),

    -- crates
    crateMilitary        = Color3.fromRGB(255, 255, 255),
    crateElite           = Color3.fromRGB(255, 255, 255),
    crateLoot            = Color3.fromRGB(255, 255, 255),
    crateOpened          = Color3.fromRGB(255, 255, 255),
    crateState           = Color3.fromRGB(255, 255, 255),
    crateDistance        = Color3.fromRGB(255, 255, 255),
    crateTracer          = Color3.fromRGB(255, 255, 255),
    crateOffscreen       = Color3.fromRGB(255, 255, 255),

    -- global overlays (snapline / FOV / lead / current target; all white by default)
    snapVisible          = Color3.fromRGB(255, 255, 255),
    snapHidden           = Color3.fromRGB(255, 255, 255),
    lead                 = Color3.fromRGB(255, 255, 255),
    fov                  = Color3.fromRGB(255, 255, 255),
    fovManip             = Color3.fromRGB(255, 255, 255),
    target               = Color3.fromRGB(255, 255, 255),
    -- hand / weapon chams (local character cosmetics; white defaults,
    -- overridable by the inline colour pickers like every other colour)
    handChamsColor       = Color3.fromRGB(255, 255, 255),
    weaponChamsColor     = Color3.fromRGB(255, 255, 255),

    -- staff / admin ESP tag (read-only role detector)
    staffTag             = Color3.fromRGB(255, 255, 255),
    adminTag             = Color3.fromRGB(255, 255, 255),
}

-- Every cham style either slot can use. 5 simple looks, then the 10
-- palette engines and the 5 procedural engines ported from the
-- "FUST Viewmodel FX Studio" snippet. Declared here (not in the chams
-- part) because the load-time clamp below validates a saved style
-- against this exact list -- one source of truth for the dropdown, the
-- clamp and the render engine.
SA.CHAM_STYLES = {
    "Corrupted", "Solid", "Neon", "Wireframe", "Ghost",
    "Quantum_Void", "Solar_Flare", "Cyber_Synthwave", "Bio_Toxic",
    "Chrono_Shift", "Deep_Frost", "Blood_Moon", "Electric_Arc",
    "Prismatic_RGB", "Matrix_Overload",
    "Matrix_Glitch", "Cosmic_Nebula",
    "Cyber_Wave", "Biohazard_Slime", "Supernova_Flux",
}
SA.CHAM_STYLE_SET = {}
for _, chamStyleName in ipairs(SA.CHAM_STYLES) do
    SA.CHAM_STYLE_SET[chamStyleName] = true
end
local ESP_COLORS = _G.__saEspColors or {}
for k, v in pairs(ESP_DEFAULT_COLORS) do
    if typeof(ESP_COLORS[k]) ~= "Color3" then ESP_COLORS[k] = v end
end
_G.__saEspColors = ESP_COLORS
-- Ship every inline picker white even when an older run left a semantic
-- green / red / crate palette in _G. One migration only, so a user's
-- later colour choices survive re-execution and profiles keep working.
if _G.__saWhiteColorFix ~= 1 then
    for k, v in pairs(ESP_DEFAULT_COLORS) do ESP_COLORS[k] = v end
    _G.__saWhiteColorFix = 1
end

-- ── SAVED COLOUR PICKERS ────────────────────────────────────────────
-- Atlanta's native config already round-trips hn_col_* flags, but some
-- library builds omit colourpickers from get_config()/load_config(). These
-- helpers embed all 48 picked colours in the profile JSON and a sidecar.
-- They live here to keep 25_ui_misc.lua inside Luau's local-register cap.
function SA.EspJson()
    if SA.__espJson then return SA.__espJson end
    local svc = nil
    pcall(function()
        if type(http_service) == "table"
            and type(http_service.JSONEncode) == "function" then
            svc = http_service
        else
            svc = game:GetService("HttpService")
        end
    end)
    if svc and type(svc.JSONEncode) == "function"
        and type(svc.JSONDecode) == "function" then
        SA.__espJson = svc
    end
    return SA.__espJson
end
function SA.EspColorHex(c)
    -- Roblox Color3 is userdata; the Fengari mock uses a tagged table.
    if typeof(c) == "Color3" or type(c) == "table" then
        local ok, hex = pcall(function() return c:ToHex() end)
        if ok and type(hex) == "string" and hex ~= "" then
            if hex:sub(1, 1) ~= "#" then return "#" .. hex end
            return hex
        end
        return string.format("#%02X%02X%02X",
            math.floor((c.R or 0) * 255 + 0.5),
            math.floor((c.G or 0) * 255 + 0.5),
            math.floor((c.B or 0) * 255 + 0.5))
    end
    return "#FFFFFF"
end
function SA.EspColorFromHex(hex)
    local r, g, b = tostring(hex or ""):match("#?(%x%x)(%x%x)(%x%x)")
    if not r then return nil end
    return Color3.fromRGB(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16))
end
-- A colourpicker row is a PAIR: Colour AND Transparency. The old snapshot
-- stored only the hex string, and restore forced transparency back to 1,
-- so every saved picker came back opaque. The snapshot now carries both:
--   "#RRGGBB@<transparency>"   current format
--   "#RRGGBB"                  older profile; transparency stays untouched
-- The `@` separator is not a hex digit, so an old value still parses.
function SA.EspColorTransparency(k)
    local flag = library and library.flags and library.flags["hn_col_" .. k]
    if type(flag) == "table" and type(flag.Transparency) == "number" then
        return math.clamp(flag.Transparency, 0, 1)
    end
    return nil
end
function SA.EspColorValue(k)
    local hex = SA.EspColorHex(ESP_COLORS[k] or ESP_DEFAULT_COLORS[k])
    local alpha = SA.EspColorTransparency(k)
    if alpha == nil then return hex end
    return string.format("%s@%s", hex,
        tostring(math.floor(alpha * 1000 + 0.5) / 1000))
end
function SA.EspColorParseValue(value)
    local hex, alpha = tostring(value or ""):match("^(#[0-9A-Fa-f]+)%s*@%s*([%d%.]+)$")
    if hex then
        local a = tonumber(alpha)
        if a and a >= 0 and a <= 1 then return hex, a end
    end
    local only = tostring(value or ""):match("^(#[0-9A-Fa-f]+)$")
    if only then return only, nil end
    return nil, nil
end
function SA.EspColorSnapshot()
    local out = {}
    for k in pairs(ESP_DEFAULT_COLORS or {}) do
        out[k] = SA.EspColorValue(k)
    end
    return out
end
function SA.EspColorCount()
    local n = 0
    for _ in pairs(ESP_DEFAULT_COLORS or {}) do n = n + 1 end
    return n
end
function SA.EspColorRestore(saved)
    if type(saved) ~= "table" then return 0 end
    local n = 0
    for k, value in pairs(saved) do
        if ESP_DEFAULT_COLORS[k] ~= nil then
            local hex, alpha = SA.EspColorParseValue(value)
            local c = SA.EspColorFromHex(hex)
            if c then
                ESP_COLORS[k] = c
                local setter = library.config_flags["hn_col_" .. k]
                -- A profile saved before transparency was stored keeps
                -- whatever the picker currently has instead of being
                -- forced back to fully opaque.
                if alpha == nil then alpha = SA.EspColorTransparency(k) or 1 end
                if setter then pcall(setter, c, alpha) end
                n = n + 1
            end
        end
    end
    return n
end
function SA.EspColorText()
    local rows = {}
    for k, hex in pairs(SA.EspColorSnapshot()) do
        rows[#rows + 1] = k .. "=" .. tostring(hex)
    end
    table.sort(rows)
    return table.concat(rows, "\n")
end
function SA.EspColorFromText(text)
    local out = {}
    for line in tostring(text or ""):gmatch("[^\r\n]+") do
        -- Accept both "#RRGGBB" and "#RRGGBB@0.35" so sidecars written by
        -- an older build still load.
        local k, value = line:match(
            "^%s*([A-Za-z0-9_]+)%s*=%s*(#[0-9A-Fa-f]+[%s@%d%.]*)%s*$")
        if k and value then out[k] = (value:gsub("%s+$", "")) end
    end
    return out
end
function SA.EspColorEncode(data)
    local js = SA.EspJson()
    if not js or type(data) ~= "string" then return data end
    local ok, cfg = pcall(function() return js:JSONDecode(data) end)
    if not ok or type(cfg) ~= "table" then return data end
    cfg.__saEspColors = SA.EspColorSnapshot()
    local okEnc, enc = pcall(function() return js:JSONEncode(cfg) end)
    if okEnc and type(enc) == "string" then return enc end
    return data
end
function SA.EspColorDecode(data)
    local js = SA.EspJson()
    if js and type(data) == "string" then
        local ok, cfg = pcall(function() return js:JSONDecode(data) end)
        if ok and type(cfg) == "table" then
            if type(cfg.__saEspColors) == "table" then
                return SA.EspColorRestore(cfg.__saEspColors)
            end
        end
    end
    return 0
end

-- ── INLINE COLOURPICKER BINDINGS ───────────────────────────────────
-- These are the ONLY colourpicker rows. bindToggle / bindSlider /
-- bindDropdown chain the picker(s) onto the widget they are styling,
-- in the SAME section and tab as that control. Never a separate tab.
SA.INLINE_COLOR_BINDINGS = {
    espVisibleCheck = {
        { "VIS", "playerVisible" }, { "WALL", "playerHidden" },
        { "Flat", "playerFlat" }, { "Dot", "playerVisDot" },
    },
    espShowName = { { "Name", "playerName" } },
    espShowDist = { { "Distance", "playerDistance" } },
    espShowTool = { { "Weapon", "playerInfo" } },
    espShowHealth = {
        { "HP high", "playerHealthHigh" }, { "HP low", "playerHealthLow" },
    },
    espShowBox = { { "Player box", "playerBox" }, { "NPC box", "npcBox" } },
    espShowFill = { { "Player fill", "playerFill" }, { "NPC fill", "npcFill" } },
    espShowOutline = {
        { "Player outline", "playerOutline" }, { "NPC outline", "npcOutline" },
    },
    espShowSkeleton = {
        { "Player skeleton", "playerSkeleton" }, { "NPC skeleton", "npcSkeleton" },
    },
    espShowHeadDot = {
        { "Player head", "playerHeadDot" }, { "NPC head", "npcHeadDot" },
    },
    espShowTracer = {
        { "Player tracer", "playerTracer" }, { "NPC tracer", "npcTracer" },
    },
    espShowOffscreen = {
        { "Player arrow", "playerOffscreen" }, { "NPC arrow", "npcOffscreen" },
    },
    espHighlightTarget = { { "Target", "target" } },
    npcVisibleCheck = {
        { "VIS", "npcVisible" }, { "WALL", "npcHidden" }, { "Flat", "npcFlat" },
    },
    npcUseTypeColors = {
        { "Guard", "npcGuard" }, { "Scavenger", "npcScavenger" },
        { "Soldier", "npcSoldier" },
    },
    npcShowName = { { "Name", "npcName" } },
    npcShowDist = { { "Distance", "npcDistance" } },
    npcShowTool = { { "Weapon", "npcInfo" } },
    npcShowHealth = {
        { "HP high", "npcHealthHigh" }, { "HP low", "npcHealthLow" },
    },
    crateShowMilitary = { { "Military", "crateMilitary" } },
    crateShowElite = { { "Elite", "crateElite" } },
    crateShowLoot = { { "Loot", "crateLoot" } },
    crateShowOpened = { { "Opened", "crateOpened" } },
    crateInvertState = { { "State", "crateState" } },
    crateMaxDist = { { "Distance", "crateDistance" } },
    crateFovAware = {
        { "Tracer", "crateTracer" }, { "Arrow", "crateOffscreen" },
    },
    showFov = { { "FOV", "fov" }, { "Wall pen", "fovManip" } },
    snapLineEnabled = {
        { "Snap VIS", "snapVisible" }, { "Snap WALL", "snapHidden" },
    },
    snapShowLead = { { "Lead", "lead" } },
    -- Hand / weapon cham tints are independent pickers on their own
    -- toggle, exactly like every other colour in the script.
    handChams = { { "Hand", "handChamsColor" } },
    weaponChams = { { "Weapon", "weaponChamsColor" } },
    espStaffDetect = {
        { "Staff tag", "staffTag" }, { "Admin tag", "adminTag" },
    },
}
SA.INLINE_COLOR_OWNER = {}
for controlKey, rows in pairs(SA.INLINE_COLOR_BINDINGS) do
    for _, row in ipairs(rows) do
        SA.INLINE_COLOR_OWNER[row[2]] = controlKey
    end
end

-- ────────────────────────────────────────────────────────────────────
-- CONFIG
-- ────────────────────────────────────────────────────────────────────

local SA_CFG_SHIPPED = {
    masterEnabled = false,

    -- targeting
    fov        = 220,
    -- FOV measurement. "Pixels" is the long-standing screen circle
    -- (CFG.fov = pixel radius around SA.AimPoint()). "Degrees" measures
    -- the angle between the camera look vector and the direction to the
    -- target, so the SAME setting means the same thing on 1080p and 4K.
    -- fovHitbox widens BOTH modes from one bone to the target's whole
    -- head-to-root segment, so a box that is visibly inside the circle
    -- is not missed because its head bone sits a few pixels outside.
    fovMode    = "Pixels",
    fovDegrees = 35,
    fovHitbox  = false,
    -- How the FOV circle itself is DRAWN. Every style is built from the
    -- primitives an executor actually has (Line / Circle / Triangle), so
    -- none of them can fail to render on a partial Drawing API.
    --   Circle   - native circle (ScreenGui ring fallback)
    --   Segments - polygon of Line segments (works with Line only)
    --   Corners  - four corner arcs
    --   Dots     - dotted ring
    --   Double   - two concentric circles (inner ring at 50%)
    --   Dashes   - dashed ring
    --   Cross    - centre crosshair + circle
    --   Pulse    - circle whose radius breathes
    fovStyle   = "Circle",
    fovSegments = 64,
    distance   = 0,
    wallCheck  = false,
    teamCheck  = false,
    hitChance  = 100,
    targetNpcs = false,
    targetBone = "Head",
    forceHead = false,           -- silent aim always resolves Head when present

    -- gun silent aim
    gunEnabled     = false,
    gunShotOnly    = false,
    gunCooldown    = 0,

    -- Fust bow: ballistic silent aim + peek-origin wallbang (default OFF).
    -- hookfunction is installed once on Fust Remotes.Shoot.FireServer, but
    -- the intercept is gated by fustBowEnabled and only rewrites bow shots.
    fustBowEnabled      = false,
    fustBowFov          = 400,
    fustBowTargetPart   = "Head",
    fustBowManipulation = false,
    fustBowManipPeek    = 4,
    fustBowManipMaxDist = 60,
    fustBowOriginRadius = 12,

    -- triggerbot / auto fire (guns only; both OFF by default)
    triggerbot       = false,
    autoFire         = false,
    triggerHeadOnly  = false,
    triggerRandomPart= false,
    triggerPart      = "Head",
    triggerUseManip  = false,
    fireWallCheck    = false,   -- dedicated fire-assist VIS gate (default OFF)

    -- ballistics / prediction
    prediction           = false,
    predictionGravity    = false,
    predictionAmmo       = false,
    predictionIterations = 4,
    predictionAutoPing   = false,   -- read live ping, no manual guessing
    predictionPingScale  = 1,      -- multiplier on the measured ping
    predictionLatency    = 0,      -- extra manual offset on top of auto ping
    gunBulletSpeed       = 0,     -- 0 = exact speed from 07_gun_specs.lua
    gunAmmoOverride      = "Auto",
    saturday2Mode        = false,
    muzzleBoost          = false,   -- manual fallback for muzzle_boost

    -- attachment auto tune (08_attachments.lua)
    attachmentAutoTune      = false,   -- detect + fold attachments into prediction
    attachmentAds           = false,  -- force ADS spread (else RMB is read)
    attachmentAimTune       = false,   -- sights/grip add aim-time lead
    attachmentAimScale      = 1,      -- 0 disables the aim-time lead
    attachmentSilencerSpeed = 0.85,   -- ESTIMATE: "slower bullets"
    attOverrideSight        = "Auto", -- Auto / None / <attachment id>
    attOverrideMuzzle       = "Auto",
    attOverrideUnder        = "Auto",
    attOverrideMag          = "Auto",

    -- fov visual (the FOV circle is THE reference point for aiming).
    -- The shipped literal stays OFF; SA.FOV_STARTUP below turns the circle
    -- ON at load so the reference point is actually visible.
    showFov         = false,
    fovFilled       = false,
    fovTransparency = 1,
    fovThickness    = 3,
    fovCenterMode   = "Mouse",     -- always the mouse / crosshair reference
    forceGuiDrawing = false,        -- ScreenGui backend always works; native Drawing often doesn't

    -- manipulation — CLASSIC six-slider set (8 peek dirs + shared ray params)
    -- Ranges are deliberately tight: 0-300 studs, base peek 4-6 only.
    -- Every slider below has a real effect in 05_manipulation.lua.
    manipulation      = false,
    manipNpcs         = false,   -- wall-peek / CanQuery also for NPC targets
    manipDist         = 30,     -- studs, slider 0..300
    manipPeek         = 4,      -- base peek, slider 4..6
    manipMaxParts     = 3,      -- slider 0..8
    manipBudget       = 40,     -- rays / frame, slider 8..128
    manipHysteresis   = 3,      -- frames, slider 0..12
    manipMaxPeekDelta = 6,      -- slider 2..12 (genuinely caps the peek)

    -- silent aim v7.7 (tap-fire reorder; GUNS ONLY — bows are skipped)
    saTapReorder = false,        -- Fix A (InputBegan) + Fix B (Tool.Activated)
    saTapWindow  = 0.35,        -- PATCH: widened from 0.2

    -- player esp
    espEnabled      = false,
    espShowName     = false,
    espShowDist     = false,
    espShowHealth   = false,
    espMaxDist      = 2000,
    espVisibleCheck = false,
    espShowTool     = false,
    espShowState    = false,

    -- npc esp (Guard / Scavenger / Soldier)
    npcEspEnabled   = false,
    npcShowName     = false,
    npcShowDist     = false,
    npcShowHealth   = false,
    npcShowTool     = false,
    npcShowState    = false,
    npcVisibleCheck = false,
    npcMaxDist      = 2000,

    -- aim preview / snapline (size is a separate 1-10 control)
    snapLineEnabled   = false,
    snapLineOrigin    = "FOV Reference",
    snapLineThickness = 3,
    snapShowLead      = false,


    -- HAND / WEAPON CHAMS. Two independent features with the same option
    -- set. Neither reads the other's flags, so styling the hands never
    -- changes the weapon.
    handChams          = false,
    handChamsStyle     = "Corrupted",
    handChamsIntensity = 1,
    handChamsAura      = false,
    handChamsSpikes    = false,
    weaponChams        = false,
    weaponChamsStyle   = "Corrupted",
    weaponChamsIntensity = 1,
    weaponChamsAura    = false,
    weaponChamsSpikes  = false,

    -- crate esp
    crateEnabled       = false,
    crateFovAware      = false,  -- dot outside FOV; name + distance + outline highlight inside
    crateShowMilitary  = false,
    crateShowElite     = false,
    crateShowLoot      = false,
    crateShowOpened    = false,
    crateLooseDetect   = false,
    crateHighlight     = false,    -- off by default: no stray chams on scenery
    crateInvertState   = false,    -- flip if the game's opened/closed signal is inverted
    crateLidDetect     = false,    -- lid-angle guess is unreliable; opt-in only
    crateMaxDist       = 3000,

    -- esp visual features (shared by players, NPCs and crates)
    -- Every feature starts OFF. CLEAN MODE is an explicit opt-in: no dark
    -- tag pills / chams fill, only thin outlines plus text stroke. Turn it
    -- ON for that look; effective values still live in 18_esp_fx_draw.lua.
    espCleanMode        = false,
    espPerElementColors = false,
    espShowBox          = false,
    espCornerBox        = false,
    espShowFill         = false,
    espShowOutline      = false,
    espShowSkeleton     = false,
    espShowHeadDot      = false,
    espShowTracer       = false,
    espShowOffscreen    = false,
    espHighlightTarget  = false,
    espRainbow          = false,
    espRainbowSpeed     = 2,
    espFade             = false,
    espFadeStart        = 60,
    espBoxThickness     = 1,
    espTracerOrigin     = "Bottom",
    espArrowFOV         = false,    -- arrows sit on the FOV circle edge
    espTextSize         = 11,      -- one slider for ALL ESP text
    espShowHealthText   = false,
    espTextOutline      = false,
    -- New ESP text layout (Tahoma, weapon below the box, tags at corner)
    espTagSide          = false,    -- VIS/WALL, state, HP beside top-right corner
    espTagBackdrop      = false,   -- dark pill behind each side tag (OFF in clean mode)
    npcUseTypeColors    = false,

    -- ESP preview panel (Atlanta's floating "ESP Preview" window)
    espPreview       = false,
    espPreviewSpin   = false,
    espPreviewSpeed  = 25,         -- degrees / second
    -- The preview mirrors EITHER the Player or the NPC ESP pipeline
    -- (flags, palette, archetype colours, feature set). "Simulate Aim
    -- Target" paints it with the global target colour.
    espPreviewKind   = "Player",   -- "Player" / "NPC"
    espPreviewTarget = false,
    -- Small HUD that appears when the Atlanta menu is hidden / minimised.
    -- Reports the nearest player, their distance in metres and held tool.
    nearestWindow    = false,
    showPlayerWarning = false,  -- crosshair warning when any player is within 100 m
    -- READ-ONLY detectors (no warnings, no aim / gun changes, no writes).
    espStaffDetect    = false,  -- ESP role tag: STAFF / ADMIN / NONE + AdminESP
    unknownHumanoidScan = false,-- Misc: unknown humanoid count + name list

    -- V16.46-style gun mods (client-local named fields + visual probes)
    gmEnabled               = false,
    gunNoSpread             = false,
    gunShotProbe            = false,
    gunInspectDefs          = false,
    gunInspectScripts       = false,
    gunInspectGunControl    = false,
    gunInspectLiveGun       = false,
    gunNoRecoil             = false,
    gunCameraKickFilter     = false,
    gunFireRate             = false,
    gunFireRateMultiplier   = 1.5,
    gunInfiniteAmmo         = false,
    gunMoveShoot            = false,
    displayBrightnessEnabled = false,
    displayBrightness       = 0.2,

    -- Hitbox Expander v2 (silent, self-healing, R6/R15)
    hitboxEnabled   = false,
    hitboxTarget    = "Both",     -- Head / Torso / Both
    hitboxMode      = "fixed",    -- fixed (studs) / multiply (x original)
    hitboxScale     = 8,
    hitboxCap       = 8,          -- multiply-mode safety cap
    hitboxMaxDist   = 300,        -- 0 = unlimited
    hitboxTeamCheck = false,
    hitboxAliveOnly = false,
    hitboxVisible   = false,      -- client-only tint
    hitboxNpcs      = false,       -- expand live NPC registry models too

    -- bow mods (GC scan; NOT part of silent aim / manipulation)
    -- Only two features: instant (max) charge and no shot cooldown.
    bowModsEnabled   = false,
    bowInstantCharge = false,
    bowNoCooldown    = false,

    -- ── BETTER: profiles, keybinds, HUD, declutter, aim, preview, perf ──
    configProfile = "default", configName = "default", autoLoadConfig = false,
    keybindMode = "toggle",
    keybindSelected = "hn_menu_bind",
    nearestTopN = 1, nearestShowHealth = false, nearestShowState = false,
    nearestShowTeam = false, nearestCorner = "Top Left", nearestScale = 1,
    nearestTransparency = 12, showNoTargetReason = false,
    -- ARMOR CONSOLE (Fust gear HUD). Off by default like every feature.
    armorConsole       = false,
    armorConsoleFov    = false,
    armorConsoleShowTotals = false,
    armorConsoleMaxDist = 0,
    armorConsoleScanSec = 0.5,
    armorConsoleSort   = "Nearest",
    armorConsoleCorner = "Top Left",
    armorConsoleScale  = 1,
    armorConsoleTransparency = 12,
    armorConsoleMaxPlayers = 3,
    armorConsoleWidth  = 300,
    armorConsoleHeight = 560,
    showManipPopup = false, showPlayerWarning = false,
    forceHead = false, triggerbot = false, autoFire = false,
    triggerHeadOnly = false, triggerRandomPart = false,
    triggerPart = "Head", triggerUseManip = false, fireWallCheck = false,
    espOnlyNearest = false, espNearestCount = 5, espOnlyAimTarget = false,
    espTeamMode = "All", espShowLiveCount = false,
    targetPriority = "Crosshair", fovPreset = "Custom", targetBoneMode = "Global",
    espPreviewSource = "Local Character", espPreviewCompare = false,
    perfMode = false, perfEspRebuildMs = 100, perfMaxEntities = 40,
    espDataRefreshMs = 100, perfShowFps = false,
    gunOverrideString = "",
    uiTheme = "Atlanta", uiFont = "Source Sans Pro",
}
local saFreshStartup = _G.__saCFG == nil
local CFG = _G.__saCFG or SA_CFG_SHIPPED
_G.__saCFG = CFG
-- Snapshot the SHIPPED literal, not the live CFG (which may be a saved
-- profile from an earlier run). "Reset to defaults" needs the originals.
SA.CFG_DEFAULTS = {}
for k, v in pairs(SA_CFG_SHIPPED) do SA.CFG_DEFAULTS[k] = v end

-- ESP-ONLY best preset. Every other family (silent aim, gun mods, Visual,
-- Misc, FOV circle, snapline, HUD, brightness, hitbox, bows, auto fire)
-- keeps the old fully OFF startup. Applied on a fresh session before the
-- Atlanta widgets are built; a normal re-execute preserves user changes.
SA.BEST_ESP_STARTUP = {
    -- Player / NPC ESP
    espEnabled = true, espMaxDist = 2000, espVisibleCheck = true,
    espShowName = true, espShowDist = true, espShowHealth = true,
    espShowTool = true, espShowState = true,
    npcEspEnabled = true, npcMaxDist = 2000, npcVisibleCheck = true,
    npcShowName = true, npcShowDist = true, npcShowHealth = true,
    npcShowTool = true, npcShowState = true, npcUseTypeColors = true,
    -- Readable corners + thin outlines; no chams blob, pills or arrows
    espCleanMode = false, espPerElementColors = true,
    espShowBox = true, espCornerBox = true, espShowFill = false,
    espShowOutline = true, espShowSkeleton = false, espShowHeadDot = true,
    espShowTracer = false, espShowOffscreen = false,
    espArrowFOV = false, espHighlightTarget = true,
    espRainbow = false, espFade = false, espFadeStart = 60,
    espBoxThickness = 1, espTracerOrigin = "Bottom",
    espShowHealthText = true, espTextSize = 11, espTextOutline = true,
    espTagSide = true, espTagBackdrop = false,
    -- Preview + decluttering
    espPreview = true, espPreviewSpin = false, espPreviewSpeed = 25,
    espPreviewKind = "Player", espPreviewSource = "Local Character",
    espPreviewCompare = false, espPreviewTarget = false,
    espOnlyNearest = false, espNearestCount = 5,
    espOnlyAimTarget = false, espTeamMode = "All",
    espShowLiveCount = true, espDataRefreshMs = 100,
}
for k, v in pairs(SA.BEST_ESP_STARTUP) do SA.CFG_DEFAULTS[k] = v end
if saFreshStartup then
    for k, v in pairs(SA.BEST_ESP_STARTUP) do CFG[k] = v end
end

-- The FOV circle is the ONE non-ESP startup exception. It is ON, solid
-- (1% transparent) and 3px thick; every other non-ESP feature
-- keeps the old OFF startup. ResetToDefaults() preserves this split, and
-- FullUnload() clears the fresh-session marker for the next load.
SA.FOV_STARTUP = {
    showFov = true, fov = 220, fovFilled = false,
    fovTransparency = 1, fovThickness = 3,
    fovCenterMode = "Mouse", forceGuiDrawing = false,
    snapLineOrigin = "FOV Reference", snapLineThickness = 3,
}
for k, v in pairs(SA.FOV_STARTUP) do SA.CFG_DEFAULTS[k] = v end
if saFreshStartup then
    for k, v in pairs(SA.FOV_STARTUP) do CFG[k] = v end
end

-- backfill (keeps settings from older versions usable)
for k, v in pairs({
    manipulation = false, manipNpcs = false,
    manipDist = 30, manipPeek = 4,
    manipMaxParts = 3, manipBudget = 40, manipHysteresis = 3, manipMaxPeekDelta = 6,
    saTapReorder = false, saTapWindow = 0.35,
    fustBowEnabled = false, fustBowFov = 400,
    fustBowTargetPart = "Head", fustBowManipulation = false,
    fustBowManipPeek = 4, fustBowManipMaxDist = 60,
    fustBowOriginRadius = 12,
    espEnabled = false, espShowName = false, espShowDist = false,
    espShowHealth = false, espMaxDist = 2000,
    espVisibleCheck = false, espShowTool = false, espShowState = false,
    npcEspEnabled = false, npcShowName = false, npcShowDist = false,
    npcShowHealth = false, npcShowTool = false, npcShowState = false,
    npcVisibleCheck = false, npcMaxDist = 2000,
    snapLineEnabled = false, snapLineOrigin = "FOV Reference",
    snapLineThickness = 3,
    snapShowLead = false,
    prediction = false, predictionGravity = false, predictionAmmo = false,
    predictionIterations = 4, predictionAutoPing = false, predictionPingScale = 1,
    predictionLatency = 0, gunBulletSpeed = 0,
    gunAmmoOverride = "Auto", saturday2Mode = false, muzzleBoost = false,
    attachmentAutoTune = false, attachmentAds = false, attachmentAimTune = false,
    attachmentAimScale = 1, attachmentSilencerSpeed = 0.85,
    attOverrideSight = "Auto", attOverrideMuzzle = "Auto",
    attOverrideUnder = "Auto", attOverrideMag = "Auto",
    crateEnabled = false, crateFovAware = false,
    crateShowMilitary = false, crateShowElite = false,
    crateShowLoot = false, crateShowOpened = false, crateLooseDetect = false,
    handChams = false, handChamsStyle = "Corrupted",
    handChamsIntensity = 1, handChamsAura = false, handChamsSpikes = false,
    weaponChams = false, weaponChamsStyle = "Corrupted",
    weaponChamsIntensity = 1, weaponChamsAura = false, weaponChamsSpikes = false,
    crateHighlight = false, crateInvertState = false, crateLidDetect = false,
    crateMaxDist = 3000,
    showFov = false, fovFilled = false, fovTransparency = 1, fovThickness = 3,
    fovCenterMode = "Mouse", forceGuiDrawing = false,
    fovMode = "Pixels", fovDegrees = 35, fovHitbox = false,
    fovStyle = "Circle", fovSegments = 64,
    espCleanMode = false,
    espPerElementColors = false, espShowBox = false, espCornerBox = false,
    espShowFill = false, espShowOutline = false, espShowSkeleton = false,
    espShowHeadDot = false, espShowTracer = false, espShowOffscreen = false,
    espHighlightTarget = false, espRainbow = false, espRainbowSpeed = 2,
    espFade = false, espFadeStart = 60, espBoxThickness = 1,
    espTracerOrigin = "Bottom", espArrowFOV = false, espTextSize = 11,
    espShowHealthText = false, espTextOutline = false,
    espTagSide = false, espTagBackdrop = false,
    espPreview = false, espPreviewSpin = false, espPreviewSpeed = 25,
    espPreviewKind = "Player", espPreviewTarget = false,
    nearestWindow = false,
    espStaffDetect = false, unknownHumanoidScan = false,
    npcUseTypeColors = false,
    gmEnabled = false,
    gunNoSpread = false, gunShotProbe = false,
    gunInspectDefs = false, gunInspectScripts = false,
    gunInspectGunControl = false, gunInspectLiveGun = false,
    gunNoRecoil = false, gunCameraKickFilter = false,
    gunFireRate = false, gunFireRateMultiplier = 1.5,
    gunInfiniteAmmo = false, gunMoveShoot = false,
    displayBrightnessEnabled = false, displayBrightness = 0.2,
    hitboxEnabled = false, hitboxTarget = "Both", hitboxMode = "fixed",
    hitboxScale = 8, hitboxCap = 8, hitboxMaxDist = 300,
    hitboxTeamCheck = false, hitboxAliveOnly = false, hitboxVisible = false,
    hitboxNpcs = false,
    bowModsEnabled = false, bowInstantCharge = false, bowNoCooldown = false,
    configProfile = "default", configName = "default", autoLoadConfig = false,
    keybindMode = "toggle",
    keybindSelected = "hn_menu_bind",
    nearestTopN = 1, nearestShowHealth = false, nearestShowState = false,
    nearestShowTeam = false, nearestCorner = "Top Left", nearestScale = 1,
    nearestTransparency = 12, showNoTargetReason = false,
    armorConsole = false, armorConsoleFov = false,
    armorConsoleShowTotals = false, armorConsoleMaxDist = 0,
    armorConsoleScanSec = 0.5, armorConsoleSort = "Nearest",
    armorConsoleCorner = "Top Left", armorConsoleScale = 1,
    armorConsoleTransparency = 12, armorConsoleMaxPlayers = 3,
    armorConsoleWidth = 300, armorConsoleHeight = 560,
    showManipPopup = false, showPlayerWarning = false,
    forceHead = false, triggerbot = false, autoFire = false,
    triggerHeadOnly = false, triggerRandomPart = false,
    triggerPart = "Head", triggerUseManip = false, fireWallCheck = false,
    espOnlyNearest = false, espNearestCount = 5, espOnlyAimTarget = false,
    espTeamMode = "All", espShowLiveCount = false,
    targetPriority = "Crosshair", fovPreset = "Custom", targetBoneMode = "Global",
    espPreviewSource = "Local Character", espPreviewCompare = false,
    perfMode = false, perfEspRebuildMs = 100, perfMaxEntities = 40,
    espDataRefreshMs = 100, perfShowFps = false,
    gunOverrideString = "",
    uiTheme = "Atlanta", uiFont = "Source Sans Pro",
}) do if CFG[k] == nil then CFG[k] = v end end
-- Older saved configs never had the snapshot either.
if type(SA.CFG_DEFAULTS) ~= "table" then
    SA.CFG_DEFAULTS = {}
    for k, v in pairs(CFG) do SA.CFG_DEFAULTS[k] = v end
end

-- One-time migration for configs saved by older builds. Those forced a
-- faint 50%-transparent circle and a legacy snapline origin; reset them to
-- the visible FOV reference startup ONCE. Saved user tweaks after this
-- point are preserved. FOV is the only non-ESP startup exception.
if _G.__saFovFix ~= 5 then
    for k, v in pairs(SA.FOV_STARTUP) do CFG[k] = v end
    CFG.saTapReorder = false
    _G.__saFovFix = 5
end

-- One-time migration back to the CLASSIC manipulation slider set. v7.7
-- pushed every value outside the useful 0-300 / 4-6 window and added an
-- "Adaptive Peek Cap" that silently turned Max Peek Delta into a no-op.
-- Only replace values still equal to a known v7.7 default, so a profile
-- the user tuned by hand is never clobbered.
if _G.__saManipFix ~= 3 then
    local v77Dist  = { [1000] = true, [850] = true }
    local v77Peek  = { [20] = true }
    local v77Parts = { [48] = true, [20] = true }
    local v77Budg  = { [96] = true, [48] = true }
    local v77Delta = { [40] = true, [20] = true }
    if v77Dist[CFG.manipDist]                 then CFG.manipDist = 75 end
    if v77Peek[CFG.manipPeek]                 then CFG.manipPeek = 4 end
    if v77Parts[CFG.manipMaxParts]            then CFG.manipMaxParts = 3 end
    if v77Budg[CFG.manipBudget]               then CFG.manipBudget = 64 end
    if v77Delta[CFG.manipMaxPeekDelta]        then CFG.manipMaxPeekDelta = 6 end
    CFG.manipMaxPeek = nil                    -- retire the adaptive cap
    if CFG.saTapReorder == nil                then CFG.saTapReorder = false end
    if CFG.saTapWindow == nil                 then CFG.saTapWindow = 0.35 end
    -- Bows are no longer aimed; drop the retired flag from saved profiles.
    CFG.saBowHook = nil
    _G.__saManipFix = 3
end

-- Clamp on EVERY load: saved profiles, preset imports and manual edits
-- must all land inside the slider ranges or the controls lie about what
-- they do. `manipMaxPeek` is removed from saved configs entirely.
local function saClampNum(v, lo, hi, def)
    local n = tonumber(v)
    if not n then return def end
    return math.clamp(n, lo, hi)
end
CFG.manipDist         = saClampNum(CFG.manipDist, 0, 300, 30)
CFG.manipPeek         = saClampNum(CFG.manipPeek, 4, 6, 4)
CFG.manipMaxParts     = saClampNum(CFG.manipMaxParts, 0, 8, 3)
CFG.manipBudget       = saClampNum(CFG.manipBudget, 8, 128, 40)
CFG.manipHysteresis   = saClampNum(CFG.manipHysteresis, 0, 12, 3)
CFG.manipMaxPeekDelta = saClampNum(CFG.manipMaxPeekDelta, 2, 12, 6)
CFG.manipMaxPeek      = nil
-- Preview mirror inputs must also land inside their widget ranges; an
-- out-of-range / bogus saved value would otherwise make the Player/NPC
-- switch silently fall into the wrong pipeline forever.
CFG.espPreviewSpeed  = saClampNum(CFG.espPreviewSpeed, 0, 90, 25)
CFG.espPreviewKind   = (CFG.espPreviewKind == "NPC") and "NPC" or "Player"
CFG.espPreviewTarget = CFG.espPreviewTarget == true
CFG.nearestWindow    = CFG.nearestWindow == true  -- HUD defaults OFF

-- FOV reference + visible circle + separate customizable snapline size.
-- Clamp on EVERY load so a stale saved profile cannot hide the circle,
-- put it back to 50% transparency, or put the slider outside its range.
CFG.showFov           = CFG.showFov == true
CFG.fovTransparency   = saClampNum(CFG.fovTransparency, 0, 100, 1)
CFG.fovThickness      = saClampNum(CFG.fovThickness, 1, 5, 3)
CFG.fovCenterMode     = "Mouse"
-- New FOV measurement keys are normalised on EVERY load. Pixel mode keeps
-- the existing 30-500 slider range; degrees are clamped to a cone that
-- can actually be drawn (1-89 deg, the 90 deg half-angle is the edge of
-- the frustum), and the hitbox widening is a plain boolean.
CFG.fovMode           = ({ Pixels=true, Degrees=true })[CFG.fovMode]
                        and CFG.fovMode or "Pixels"
CFG.fovDegrees        = saClampNum(CFG.fovDegrees, 1, 89, 35)
CFG.fovHitbox         = CFG.fovHitbox == true
CFG.fovStyle          = ({ Circle=true, Segments=true, Corners=true,
                           Dots=true, Double=true, Dashes=true, Cross=true,
                           Pulse=true })[CFG.fovStyle]
                        and CFG.fovStyle or "Circle"
CFG.fovSegments       = saClampNum(CFG.fovSegments, 8, 128, 64)
CFG.snapLineEnabled   = CFG.snapLineEnabled == true
CFG.snapLineOrigin    = "FOV Reference"
CFG.snapLineThickness = saClampNum(CFG.snapLineThickness, 1, 10, 3)


-- Clamp every new BETTER input too: a stale / hand-edited saved profile
-- must never put a dropdown outside its items or a slider outside range.
CFG.configProfile      = tostring(CFG.configProfile or "default")
CFG.configName         = tostring(CFG.configName or "default")
CFG.autoLoadConfig     = CFG.autoLoadConfig == true
CFG.keybindMode        = ({ toggle=true, hold=true, always=true })[CFG.keybindMode]
                         and CFG.keybindMode or "toggle"
CFG.keybindSelected    = tostring(CFG.keybindSelected or "hn_menu_bind")
CFG.nearestTopN        = saClampNum(CFG.nearestTopN, 1, 5, 1)
CFG.nearestShowHealth  = CFG.nearestShowHealth == true
CFG.nearestShowState   = CFG.nearestShowState == true
CFG.nearestShowTeam    = CFG.nearestShowTeam == true
CFG.nearestCorner      = ({ ["Top Left"]=true, ["Top Right"]=true,
                            ["Bottom Left"]=true, ["Bottom Right"]=true
                         })[CFG.nearestCorner] and CFG.nearestCorner or "Top Left"
CFG.nearestScale       = saClampNum(CFG.nearestScale, 0.6, 1.8, 1)
CFG.nearestTransparency= saClampNum(CFG.nearestTransparency, 0, 80, 12)

-- ARMOR CONSOLE
CFG.armorConsole            = CFG.armorConsole == true
CFG.armorConsoleFov         = CFG.armorConsoleFov == true
CFG.armorConsoleShowTotals  = CFG.armorConsoleShowTotals == true
CFG.armorConsoleMaxDist     = saClampNum(CFG.armorConsoleMaxDist, 0, 5000, 0)
CFG.armorConsoleScanSec     = saClampNum(CFG.armorConsoleScanSec, 0.25, 5, 0.5)
CFG.armorConsoleSort        = ({ Nearest=true, Distance=true, Name=true,
                                 ["Most Armor"]=true })[CFG.armorConsoleSort]
                              and CFG.armorConsoleSort or "Nearest"
CFG.armorConsoleCorner      = ({ ["Top Left"]=true, ["Top Right"]=true,
                                 ["Bottom Left"]=true, ["Bottom Right"]=true,
                               })[CFG.armorConsoleCorner]
                              and CFG.armorConsoleCorner or "Top Left"
CFG.armorConsoleScale       = saClampNum(CFG.armorConsoleScale, 0.6, 1.8, 1)
CFG.armorConsoleTransparency= saClampNum(CFG.armorConsoleTransparency, 0, 80, 12)
CFG.armorConsoleMaxPlayers  = saClampNum(CFG.armorConsoleMaxPlayers, 1, 5, 3)

-- HAND / WEAPON CHAMS
CFG.handChams            = CFG.handChams == true
CFG.weaponChams          = CFG.weaponChams == true
CFG.handChamsAura        = CFG.handChamsAura == true
CFG.weaponChamsAura      = CFG.weaponChamsAura == true
CFG.handChamsSpikes      = CFG.handChamsSpikes == true
CFG.weaponChamsSpikes    = CFG.weaponChamsSpikes == true
CFG.handChamsIntensity   = saClampNum(CFG.handChamsIntensity, 0.2, 2, 1)
CFG.weaponChamsIntensity = saClampNum(CFG.weaponChamsIntensity, 0.2, 2, 1)
-- Every style SA.CHAM_STYLES declares (the 5 simple ones plus the 15
-- themed engines ported from the FX studio). A saved profile naming a
-- style that no longer exists falls back to Corrupted instead of leaving
-- the dropdown showing a value the engine cannot render.
CFG.handChamsStyle       = SA.CHAM_STYLE_SET[CFG.handChamsStyle]
                           and CFG.handChamsStyle or "Corrupted"
CFG.weaponChamsStyle     = SA.CHAM_STYLE_SET[CFG.weaponChamsStyle]
                           and CFG.weaponChamsStyle or "Corrupted"
CFG.armorConsoleWidth       = saClampNum(CFG.armorConsoleWidth, 220, 520, 300)
CFG.armorConsoleHeight      = saClampNum(CFG.armorConsoleHeight, 200, 1200, 560)
CFG.showNoTargetReason = CFG.showNoTargetReason == true
CFG.showManipPopup    = CFG.showManipPopup == true
CFG.espCleanMode      = CFG.espCleanMode == true
CFG.manipNpcs         = CFG.manipNpcs == true
CFG.crateFovAware     = CFG.crateFovAware == true
CFG.showPlayerWarning = CFG.showPlayerWarning == true
CFG.espStaffDetect    = CFG.espStaffDetect == true
CFG.unknownHumanoidScan = CFG.unknownHumanoidScan == true
CFG.forceHead         = CFG.forceHead == true
CFG.triggerbot        = CFG.triggerbot == true
CFG.autoFire          = CFG.autoFire == true
CFG.triggerHeadOnly   = CFG.triggerHeadOnly == true
CFG.triggerRandomPart = CFG.triggerRandomPart == true
CFG.triggerUseManip   = CFG.triggerUseManip == true
CFG.fireWallCheck     = CFG.fireWallCheck == true
CFG.triggerPart       = ({ Head=true, Hrp=true, UpperTorso=true,
                            LowerTorso=true, LeftArm=true, RightArm=true,
                            LeftLeg=true, RightLeg=true, Random=true })
                         [CFG.triggerPart] and CFG.triggerPart or "Head"
CFG.espOnlyNearest     = CFG.espOnlyNearest == true
CFG.espNearestCount    = saClampNum(CFG.espNearestCount, 1, 20, 5)
CFG.espOnlyAimTarget   = CFG.espOnlyAimTarget == true
CFG.espTeamMode        = ({ All=true, ["Teammates Only"]=true,
                            ["Exclude Teammates"]=true })[CFG.espTeamMode]
                         and CFG.espTeamMode or "All"
CFG.espShowLiveCount   = CFG.espShowLiveCount == true
CFG.targetPriority     = ({ Crosshair=true, Nearest=true, ["Lowest HP"]=true,
                            Pinned=true })[CFG.targetPriority]
                         and CFG.targetPriority or "Crosshair"
CFG.fovPreset          = ({ Custom=true, Legit=true, Blatant=true, Sniper=true })
                         [CFG.fovPreset] and CFG.fovPreset or "Custom"
CFG.targetBoneMode     = ({ Global=true, ["Head for snipers"]=true,
                            ["Hrp for shotguns"]=true })[CFG.targetBoneMode]
                         and CFG.targetBoneMode or "Global"
CFG.espPreviewSource   = ({ ["Local Character"]=true, ["Nearest Player"]=true,
                            ["Nearest NPC"]=true, ["Aim Target"]=true })
                         [CFG.espPreviewSource] and CFG.espPreviewSource
                         or "Local Character"
CFG.espPreviewCompare  = CFG.espPreviewCompare == true
CFG.perfMode           = CFG.perfMode == true
CFG.perfEspRebuildMs   = saClampNum(CFG.perfEspRebuildMs, 16, 500, 100)
CFG.perfMaxEntities    = saClampNum(CFG.perfMaxEntities, 5, 100, 40)
CFG.espDataRefreshMs   = saClampNum(CFG.espDataRefreshMs, 16, 500, 100)
CFG.perfShowFps        = CFG.perfShowFps == true
CFG.gunOverrideString  = tostring(CFG.gunOverrideString or "")
local validThemeNames, validFontNames = {}, {}
for _, n in ipairs(SA.UI_THEME_NAMES) do validThemeNames[n] = true end
for _, n in ipairs(SA.UI_FONT_NAMES) do validFontNames[n] = true end
CFG.uiTheme            = validThemeNames[CFG.uiTheme] and CFG.uiTheme or "Atlanta"
CFG.uiFont             = validFontNames[CFG.uiFont] and CFG.uiFont or "Source Sans Pro"
CFG.hitboxEnabled      = CFG.hitboxEnabled == true
CFG.hitboxTarget       = ({ Head=true, Torso=true, Both=true })
                         [CFG.hitboxTarget] and CFG.hitboxTarget or "Both"
CFG.hitboxMode         = ({ fixed=true, multiply=true })
                         [CFG.hitboxMode] and CFG.hitboxMode or "fixed"
CFG.hitboxScale        = saClampNum(CFG.hitboxScale, 1, 30, 8)
CFG.hitboxCap          = saClampNum(CFG.hitboxCap, 1, 30, 8)
CFG.hitboxMaxDist      = saClampNum(CFG.hitboxMaxDist, 0, 2000, 300)
CFG.hitboxTeamCheck    = CFG.hitboxTeamCheck == true
CFG.hitboxAliveOnly    = CFG.hitboxAliveOnly == true
CFG.hitboxVisible      = CFG.hitboxVisible == true
CFG.hitboxNpcs         = CFG.hitboxNpcs == true
CFG.fustBowEnabled      = CFG.fustBowEnabled == true
CFG.fustBowFov          = saClampNum(CFG.fustBowFov, 50, 800, 400)
CFG.fustBowTargetPart   = ({ Head=true, HumanoidRootPart=true,
                              UpperTorso=true })[CFG.fustBowTargetPart]
                          and CFG.fustBowTargetPart or "Head"
CFG.fustBowManipulation = CFG.fustBowManipulation == true
CFG.fustBowManipPeek    = saClampNum(CFG.fustBowManipPeek, 0, 12, 4)
CFG.fustBowManipMaxDist = saClampNum(CFG.fustBowManipMaxDist, 0, 200, 60)
CFG.fustBowOriginRadius = saClampNum(CFG.fustBowOriginRadius, 1, 40, 12)

CFG.gmEnabled                 = CFG.gmEnabled == true
CFG.gunNoSpread               = CFG.gunNoSpread == true
CFG.gunShotProbe              = CFG.gunShotProbe == true
CFG.gunInspectDefs            = CFG.gunInspectDefs == true
CFG.gunInspectScripts         = CFG.gunInspectScripts == true
CFG.gunInspectGunControl      = CFG.gunInspectGunControl == true
CFG.gunInspectLiveGun         = CFG.gunInspectLiveGun == true
CFG.gunNoRecoil               = CFG.gunNoRecoil == true
CFG.gunCameraKickFilter       = CFG.gunCameraKickFilter == true
CFG.gunFireRate               = CFG.gunFireRate == true
CFG.gunFireRateMultiplier     = saClampNum(CFG.gunFireRateMultiplier, 1, 3, 1.5)
CFG.gunInfiniteAmmo           = CFG.gunInfiniteAmmo == true
CFG.gunMoveShoot              = CFG.gunMoveShoot == true
CFG.displayBrightnessEnabled  = CFG.displayBrightnessEnabled == true
CFG.displayBrightness         = saClampNum(CFG.displayBrightness, 0, 0.5, 0.2)

-- The old hardcoded GUN_SPEEDS / GUN_DEFAULT_SPEED table is gone.
-- Exact per-gun projectile speeds, ammo damage, gravity, life and range
-- live in 07_gun_specs.lua; 08_prediction.lua does the intercept solve.
