-- ==================================================================
-- Hanami / 24_ui_visual.lua — Visual tab (FOV, HUD, performance, keybinds)
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================

-- ── VISUAL : FOV + Snapline ─────────────────────────────────────────
local fovCol = VisualTab:column()
local fovSec = fovCol:section({ name = "FOV Circle / Snapline" })

bindToggle(fovSec, "Show FOV Circle", "showFov",
    "The circle IS the aim reference point: silent aim, snapline, tracers and arrows all use the same centre + radius")
bindToggle(fovSec, "Filled", "fovFilled")
-- Every FOV drawing method. All of them use the same centre + radius as
-- aim, and each degrades to Line-only primitives if Circle is missing.
bindDropdown(fovSec, "FOV Drawing Style", "fovStyle",
    { "Circle", "Segments", "Corners", "Dots", "Double", "Dashes",
      "Cross", "Pulse" })
fovSec:label({ name = "Circle/Pulse = native ring. Segments/Corners/Dots/Dashes = Line-only, executor-safe" })
bindSlider(fovSec, "Ring Segments", "fovSegments", 8, 128, 1, "")
bindDropdown(fovSec, "FOV Reference", "fovCenterMode", { "Mouse" })
fovSec:label({ name = "Reference = crosshair; invalid mouse -> screen centre" })
bindToggle(fovSec, "Force ScreenGui Drawing", "forceGuiDrawing",
    "OFF by default = try native Drawing first, then reliable Roblox GUI frames. Turn ON to force ScreenGui")
fovSec:label({ name = "FOV / snapline / lead colour pickers are inline on their own toggles" })
-- Two ways to measure the same circle. Pixels keeps the historic
-- screen-space radius; Degrees measures the camera angle and derives the
-- pixel radius from the live FieldOfView, so one setting behaves the same
-- on every resolution. The circle, aim cone, tracers and arrows all read
-- SA.FovRadius(), which already honours the mode.
bindDropdown(fovSec, "FOV Mode", "fovMode", { "Pixels", "Degrees" })
bindSlider(fovSec, "Aim / Circle Radius (px)", "fov", 30, 500, 1, "px")
fovSec:label({ name = "Pixels mode radius. Degrees mode ignores this slider" })
bindSlider(fovSec, "Aim / Circle Angle (deg)", "fovDegrees", 1, 89, 1, "deg")
fovSec:label({ name = "Degrees mode half-angle; pixel radius = (vh/2) * tan(deg) / tan(FOV/2)" })
bindToggle(fovSec, "Include Hitbox in FOV", "fovHitbox",
    "ON = test the whole head-to-root segment, not just one bone. A box visibly inside the circle counts even if its head bone is a few px outside")
bindSlider(fovSec, "Transparency (%)", "fovTransparency", 0, 100, 1, "%")
fovSec:label({ name = "Transparency 0% = solid, 100% = nearly invisible" })
bindSlider(fovSec, "Thickness", "fovThickness", 1, 5, 1, "")

bindToggle(fovSec, "Snapline (aim preview)", "snapLineEnabled",
    "Line from the FOV centre to the exact target silent aim would pick. Works with just this toggle ON; GREEN = clear, RED = blocked")
bindDropdown(fovSec, "Line Origin", "snapLineOrigin", { "FOV Reference" })
bindSlider(fovSec, "Snapline Size / Thickness", "snapLineThickness", 1, 10, 1, "")
bindToggle(fovSec, "Show Lead Marker", "snapShowLead",
    "Ring = the exact point the ballistic solver will aim at (moving targets / bullet drop)")

-- ── VISUAL : Hand / Weapon Chams ──────────────────────────────────
-- Two SEPARATE features. Each block writes only its own flags, so styling
-- the hands can never change the weapon and vice versa. They share the
-- same option set on purpose, not a shared config.
local chamCol = VisualTab:column()
local handChamSec, weaponChamSec = chamCol:multi_section({
    names = { "Hand Chams", "Weapon Chams" },
})

bindToggle(handChamSec, "Hand Chams", "handChams",
    "Your own hands / arms only. Independent of Weapon Chams")
-- Every style SA.CHAM_STYLES exports, so the dropdown and the engine can
-- never drift apart. 5 simple + 10 palette themes + 5 procedural themes.
local CHAM_STYLE_ITEMS = {}
for _, styleName in ipairs(SA.CHAM_STYLES) do
    CHAM_STYLE_ITEMS[#CHAM_STYLE_ITEMS + 1] = styleName
end
bindDropdown(handChamSec, "Style", "handChamsStyle", CHAM_STYLE_ITEMS)
bindSlider(handChamSec, "Intensity", "handChamsIntensity", 0.2, 2, 0.1, "x")
bindToggle(handChamSec, "Runic Aura", "handChamsAura",
    "Floating glyph BillboardGui above each hand")
bindToggle(handChamSec, "Wireframe Spikes", "handChamsSpikes",
    "Red SelectionBox wireframe around each hand")
addButton(handChamSec, "Disable Hand Chams", function()
    SA.ChamsSet("hand", false)
end)

bindToggle(weaponChamSec, "Weapon Chams", "weaponChams",
    "The equipped tool's parts only. Independent of Hand Chams")
bindDropdown(weaponChamSec, "Style", "weaponChamsStyle", CHAM_STYLE_ITEMS)
bindSlider(weaponChamSec, "Intensity", "weaponChamsIntensity", 0.2, 2, 0.1, "x")
bindToggle(weaponChamSec, "Runic Aura", "weaponChamsAura",
    "Floating glyph BillboardGui above each weapon part")
bindToggle(weaponChamSec, "Wireframe Spikes", "weaponChamsSpikes",
    "Red SelectionBox wireframe around each weapon part")
addButton(weaponChamSec, "Disable Weapon Chams", function()
    SA.ChamsSet("weapon", false)
end)
weaponChamSec:label({ name = "Hand and weapon settings are independent: each keeps its own style, intensity, aura and spikes" })

-- ── VISUAL : Utilities ────────────────────────────────────────────
local utilCol = VisualTab:column()
local utilSec = utilCol:section({ name = "Utilities" })

-- One Visual -> Theme dropdown applies ALL Atlanta theme colours at once;
-- one Visual -> Font dropdown restyles the menu and every live ESP label.
-- Both are event-driven only: no per-frame work and no second render loop.
local styleSec = utilCol:section({ name = "Theme / Font" })
local themeDropdown = styleSec:dropdown({
    name = "Theme", flag = "hn_uiTheme", items = SA.UI_THEME_NAMES,
    default = CFG.uiTheme,
    callback = function(v) CFG.uiTheme = v; SA.ApplyTheme(v) end,
})
local fontDropdown = styleSec:dropdown({
    name = "Font", flag = "hn_uiFont", items = SA.UI_FONT_NAMES,
    default = CFG.uiFont,
    callback = function(v) CFG.uiFont = v; SA.ApplyFont(v) end,
})
styleSec:label({ name = "Theme + font apply once per change, never per frame" })
pcall(SA.ApplyTheme, CFG.uiTheme)
pcall(SA.ApplyFont, CFG.uiFont)

-- V16.46 local post-processing brightness: one ColorCorrectionEffect under
-- Lighting, clamped 0–0.5 and destroyed on disable / unload.
SA.GunBindToggle(utilSec, "Local Brightness", "displayBrightnessEnabled",
    "Local ColorCorrectionEffect only; no Lighting globals, no character or weapon changes")
SA.GunBindSlider(utilSec, "Brightness", "displayBrightness",
    0, 0.5, 0.05, "")
utilSec:label({ name = "Brightness is local post-processing, not world lighting" })

addButton(utilSec, "Retry Tap Hooks", function()
    SA.InstallTapReorder()
end)
addButton(utilSec, "Sync Gun Defs (GC)", function()
    SA.SyncGunDefs()
end)

-- ── BETTER : HUD + Performance controls ─────────────────────────────
local hudCol = VisualTab:column()
local hudSec, perfSec = hudCol:multi_section({
    names = { "Nearest HUD", "Performance Mode" },
})
bindToggle(hudSec, "Nearest Player HUD", "nearestWindow",
    "Draggable profile card: Roblox headshot, display / account name, distance, HP, VIS / team, weapon name and Equipped / Holstered / Unknown state while the menu is hidden")
hudSec:label({ name = "Drag the header to move it · 1 m ≈ 3.571 studs (same as ESP distance)" })
addButton(hudSec, "Refresh Nearest HUD", function() SA.NearestWindowRefresh() end)
addButton(hudSec, "Reset HUD Position", function() SA.NearestWindowResetPosition() end)
bindSlider(hudSec, "Top-N Players", "nearestTopN", 1, 5, 1, "")
bindToggle(hudSec, "Show HP %", "nearestShowHealth")
bindToggle(hudSec, "Show VIS / WALL", "nearestShowState")
bindToggle(hudSec, "Show Team", "nearestShowTeam")
bindDropdown(hudSec, "Corner", "nearestCorner", {
    "Top Left", "Top Right", "Bottom Left", "Bottom Right",
})
bindSlider(hudSec, "HUD Scale", "nearestScale", 0.6, 1.8, 0.1, "x")
bindSlider(hudSec, "HUD Transparency (%)", "nearestTransparency", 0, 80, 1, "%")
bindToggle(hudSec, "Live 'Why No Target?' Line", "showNoTargetReason",
    "Shows the exact reason aim has no target (FOV, walls, master off, hit chance, pinned target)")
bindToggle(hudSec, "Manip Crosshair Popup", "showManipPopup",
    "Small READY / BLOCKED badge above the crosshair; read-only probe, never changes CanQuery or spends the ray budget")
addButton(hudSec, "Refresh Manip Popup", function() SA.ManipPopupRefresh() end)
bindToggle(hudSec, "100m Player Warning", "showPlayerWarning",
    "Red crosshair badge when any other player is within 100 metres; fixed threshold, no team filter")
addButton(hudSec, "Refresh Player Warning", function() SA.PlayerWarningRefresh() end)
addButton(hudSec, "Lock Nearest as Aim Target", function()
    local name = SA.PinNearestTarget()
    if name then setFlag("targetPriority", "Pinned") end
end)

-- ── ARMOR CONSOLE (Fust gear HUD) ──────────────────────────────────
-- Same behaviour as the Nearest HUD: only visible while the menu is
-- minimised, drag the header to move it, corner + scale + transparency.
local armorSec = hudCol:section({ name = "Armor Console" })
bindToggle(armorSec, "Armor Console HUD", "armorConsole",
    "Shows each awake player's Fust gear and per-region protection while the menu is hidden")
armorSec:label({ name = "Drag the header to move it · drag the // grip to resize · one card per armour piece with the real 3D icon" })
bindToggle(armorSec, "Only Players In FOV", "armorConsoleFov",
    "List only players inside the aim circle (same reference the circle draws with)")
bindToggle(armorSec, "Show Protection Totals", "armorConsoleShowTotals",
    "Per-region percentage on each row; otherwise the FOV badge")
bindDropdown(armorSec, "Sort By", "armorConsoleSort",
    { "Nearest", "Distance", "Name", "Most Armor" })
bindSlider(armorSec, "Max Distance", "armorConsoleMaxDist", 0, 5000, 50, " studs (0 = all)")
bindSlider(armorSec, "Scan Interval", "armorConsoleScanSec", 0.25, 5, 0.25, " s")
bindSlider(armorSec, "Players Shown", "armorConsoleMaxPlayers", 1, 5, 1, "")
bindDropdown(armorSec, "Corner", "armorConsoleCorner", {
    "Top Left", "Top Right", "Bottom Left", "Bottom Right",
})
bindSlider(armorSec, "HUD Scale", "armorConsoleScale", 0.6, 1.8, 0.1, "x")
bindSlider(armorSec, "Panel Width", "armorConsoleWidth", 220, 520, 10, " px")
bindSlider(armorSec, "Panel Height", "armorConsoleHeight", 200, 900, 10, " px")
bindSlider(armorSec, "HUD Transparency (%)", "armorConsoleTransparency", 0, 80, 1, "%")
addButton(armorSec, "Refresh Armor Console", function()
    pcall(SA.ArmorConsoleRefresh)
end)
addButton(armorSec, "Reset Console Position", function()
    pcall(SA.ArmorConsoleResetPosition)
end)

bindToggle(perfSec, "Performance Mode", "perfMode",
    "Adaptive ESP rebuild pacing, drawing reuse, entity cap per frame and FPS counter")
bindSlider(perfSec, "ESP Text Refresh (ms @60fps)", "espDataRefreshMs", 16, 500, 1, "ms")
bindSlider(perfSec, "Rebuild Interval (ms @60fps)", "perfEspRebuildMs", 16, 500, 1, "ms")
bindSlider(perfSec, "Max ESP Entities / Frame", "perfMaxEntities", 5, 100, 1, "")
bindToggle(perfSec, "FPS Counter in HUD", "perfShowFps")

-- A tiny always-on-top FPS / entity overlay, independent of the Atlanta
-- menu. It only updates at ~5 Hz so it never costs a frame of styling.
-- Re-executing must remove the previous generation's GUI / bind first.
if SA.DisposePerfOverlay then pcall(SA.DisposePerfOverlay) end
local saPerfOverlay = { gui = nil, label = nil, last = 0 }

function SA.DisposePerfOverlay()
    if saPerfOverlay.conn then pcall(function() saPerfOverlay.conn:Disconnect() end) end
    if saPerfOverlay.gui then pcall(function() saPerfOverlay.gui:Destroy() end) end
    saPerfOverlay.gui, saPerfOverlay.label, saPerfOverlay.conn = nil, nil, nil
end

local function saPerfOverlayBuild()
    if saPerfOverlay.gui then return end
    local parent = nil
    pcall(function()
        if typeof(gethui) == "function" then parent = gethui() end
    end)
    if not parent then pcall(function() parent = game:GetService("CoreGui") end) end
    if not parent then return end
    pcall(function()
        local sg = Instance.new("ScreenGui")
        sg.Name = "HanamiPerfOverlay"
        sg.ResetOnSpawn = false
        sg.IgnoreGuiInset = true
        sg.DisplayOrder = 996
        sg.Enabled = false
        sg.Parent = parent
        local lbl = Instance.new("TextLabel")
        lbl.Name = "PerfText"
        lbl.Size = UDim2.new(0, 300, 0, 48)
        lbl.Position = UDim2.new(0.5, -150, 0, 8)
        lbl.BackgroundColor3 = Color3.fromRGB(12, 14, 22)
        lbl.BackgroundTransparency = 0.35
        lbl.TextColor3 = Color3.fromRGB(190, 235, 255)
        lbl.TextXAlignment = Enum.TextXAlignment.Center
        lbl.TextYAlignment = Enum.TextYAlignment.Center
        lbl.TextSize = 12
        lbl.Text = ""
        lbl.Parent = sg
        pcall(function() SA.ApplyEspFont(lbl) end)
        saPerfOverlay.gui, saPerfOverlay.label = sg, lbl
    end)
end

saPerfOverlay.conn = bindRender(function()
    if not SA.Alive then return end
    local show = CFG.perfMode == true and CFG.perfShowFps == true
        and (window and window.opened) == false
    if not saPerfOverlay.gui and show then saPerfOverlayBuild() end
    if saPerfOverlay.gui then saPerfOverlay.gui.Enabled = show end
    if not show or not saPerfOverlay.label then return end
    local now = tick()
    if now - saPerfOverlay.last < 0.2 then return end
    saPerfOverlay.last = now
    pcall(function()
        local st = SA.PerfState()
        local v = st.visible or {}
        saPerfOverlay.label.Text = string.format(
            "%.0f FPS  ·  rebuild %.0f ms  ·  cap %s\nplayers %s  npcs %s  crates %s  ·  pool %s",
            st.fps or 0, st.effectiveRebuildMs or 0,
            tostring(st.effectiveEntityCap), tostring(v.players or 0),
            tostring(v.npcs or 0), tostring(v.crates or 0),
            tostring(st.pool and st.pool.total or 0))
    end)
end)

-- ── BETTER: crosshair manipulation-status popup ─────────────────────
-- A small badge just above SA.AimPoint(), the SAME mouse / screen-centre
-- reference used by the FOV circle and target picker. It asks the read-only
-- SA.ManipPossible() probe, so showing the badge never disables CanQuery,
-- consumes the manipulation ray budget or writes a peek into the cache.
-- Updates at ~10 Hz and follows the crosshair on every update.
if SA.DisposeManipPopup then pcall(SA.DisposeManipPopup) end
local saManipPopup = {
    draw = nil, conn = nil, last = 0, built = false, visible = false,
    possible = false, reason = "", text = "", target = nil, npc = false,
}
_G.__saManipPopup = saManipPopup

function SA.DisposeManipPopup()
    if saManipPopup.conn then pcall(function() saManipPopup.conn:Disconnect() end) end
    if saManipPopup.draw then SA.DrawRemove(saManipPopup.draw) end
    saManipPopup.draw, saManipPopup.conn = nil, nil
    saManipPopup.built, saManipPopup.visible = false, false
    saManipPopup.reason = "disposed"
end

local function saManipPopupColour(possible, reason)
    if possible then return Color3.fromRGB(90, 235, 140) end
    if string.find(reason, "OFF", 1, true)
        or string.find(reason, "no target", 1, true) then
        return Color3.fromRGB(255, 205, 90)
    end
    return Color3.fromRGB(255, 105, 105)
end

local function saManipPopupBuild()
    if saManipPopup.draw then return true end
    local draw = SA.NewDraw("Text")
    if not draw then return false end
    draw.Size = Vector2.new(230, 22)
    draw.Anchor = Vector2.new(0.5, 1)
    draw.Align = "Center"
    draw.TextSize = 12
    draw.Outline = true
    draw.Backdrop = true
    draw.ZIndex = 20
    saManipPopup.draw = draw
    saManipPopup.built = true
    return true
end

local function saManipPopupTag(possible, reason)
    if string.find(reason, "OFF", 1, true) then return "OFF" end
    if string.find(reason, "no target", 1, true) then return "NO TARGET" end
    if string.find(reason, "bow", 1, true) then return "BOW" end
    if string.find(reason, "out of", 1, true) then return "RANGE" end
    if string.find(reason, "blocked", 1, true) then return "BLOCKED" end
    return possible and "READY" or "NO"
end

local function saManipPopupTick(force)
    if not SA.Alive or CFG.showManipPopup ~= true then
        if saManipPopup.draw then saManipPopup.draw.Visible = false end
        saManipPopup.visible = false
        return
    end
    if not saManipPopupBuild() then return end
    local now = tick()
    if not force and now - saManipPopup.last < 0.1 then return end
    saManipPopup.last = now
    local ok, possible, reason, info = pcall(SA.ManipPossible)
    if not ok then
        possible, reason, info = false, "probe error: " .. tostring(possible), {}
    end
    reason = tostring(reason or "unknown")
    info = info or {}
    local detail = reason
    if #detail > 28 then detail = string.sub(detail, 1, 28) .. "..." end
    local npcTag = info.npc == true and " NPC" or ""
    local text = "MANIP" .. npcTag .. ": "
        .. saManipPopupTag(possible, reason) .. " | " .. detail
    local okPos, pt = pcall(SA.AimPoint)
    if not okPos or not pt then pt = Vector2.new(640, 360) end
    pcall(function()
        saManipPopup.draw.Position = Vector2.new(pt.X, pt.Y - 26)
        saManipPopup.draw.Text = text
        saManipPopup.draw.Color = saManipPopupColour(possible, reason)
        saManipPopup.draw.Visible = true
    end)
    saManipPopup.possible = possible == true
    saManipPopup.reason = reason
    saManipPopup.text = text
    saManipPopup.target = info.model
    saManipPopup.npc = info.npc == true
    saManipPopup.visible = true
end

function SA.ManipPopupRefresh() saManipPopupTick(true) end
function SA.ManipPopupSet(on)
    on = on == true
    CFG.showManipPopup = on
    pcall(setFlag, "showManipPopup", on)
    saManipPopupTick(true)
end
function SA.ManipPopupState()
    return {
        enabled = CFG.showManipPopup == true,
        built = saManipPopup.built == true,
        visible = saManipPopup.visible == true,
        possible = saManipPopup.possible == true,
        reason = saManipPopup.reason,
        text = saManipPopup.text,
        target = saManipPopup.target,
        npc = saManipPopup.npc == true,
        last = saManipPopup.last or 0,
    }
end

saManipPopupTick(true)
saManipPopup.conn = bindRender(function() saManipPopupTick(false) end)

-- ── BETTER: 100 m player proximity warning ─────────────────────────
-- Any OTHER player inside 100 metres (1 m ≈ 3.571 studs) triggers a small
-- red badge above the crosshair. Fixed threshold, no team filter, ~10 Hz.
if SA.DisposePlayerWarning then pcall(SA.DisposePlayerWarning) end
SA.PLAYER_WARNING_METERS = 100
local saPlayerWarning = {
    draw = nil, conn = nil, last = 0, built = false, visible = false,
    text = "", reason = "idle", nearest = nil, meters = nil, studs = nil,
}
_G.__saPlayerWarning = saPlayerWarning

function SA.DisposePlayerWarning()
    if saPlayerWarning.conn then pcall(function() saPlayerWarning.conn:Disconnect() end) end
    if saPlayerWarning.draw then SA.DrawRemove(saPlayerWarning.draw) end
    saPlayerWarning.draw, saPlayerWarning.conn = nil, nil
    saPlayerWarning.built, saPlayerWarning.visible = false, false
    saPlayerWarning.reason = "disposed"
end

local function saPlayerWarningBuild()
    if saPlayerWarning.draw then return true end
    local draw = SA.NewDraw("Text")
    if not draw then return false end
    draw.Size = Vector2.new(270, 22)
    draw.Anchor = Vector2.new(0.5, 1)
    draw.Align = "Center"
    draw.TextSize = 12
    draw.Outline = true
    draw.Backdrop = true
    draw.Color = Color3.fromRGB(255, 105, 105)
    draw.ZIndex = 21
    saPlayerWarning.draw = draw
    saPlayerWarning.built = true
    return true
end

local function saPlayerWarningNearest()
    local myRoot = SA.PlayerRig(lp.Character)
    local myPos = myRoot and myRoot.Position or nil
    if not myPos then
        pcall(function() myPos = ws.CurrentCamera.CFrame.Position end)
    end
    if not myPos then return nil, "no local position" end
    local ok, players = pcall(function() return Players:GetPlayers() end)
    if not ok or not players then return nil, "Players:GetPlayers failed" end
    local best = nil
    for _, plr in ipairs(players) do
        if plr ~= lp then
            local char = plr.Character
            local root = char and SA.PlayerRig(char) or nil
            local hum = char and char:FindFirstChildOfClass("Humanoid") or nil
            if root and root.Position and hum and hum.Health > 0 then
                local okD, d = pcall(function()
                    return (myPos - root.Position).Magnitude
                end)
                if okD and d then
                    local metres = d / (SA.STUDS_PER_METER or 3.571)
                    if metres <= SA.PLAYER_WARNING_METERS
                        and (not best or d < best.studs) then
                        best = { plr = plr, studs = d, meters = metres }
                    end
                end
            end
        end
    end
    if not best then return nil, "no player within 100m" end
    return best, "player within 100m"
end

local function saPlayerWarningTick(force)
    if not SA.Alive or CFG.showPlayerWarning ~= true then
        if saPlayerWarning.draw then saPlayerWarning.draw.Visible = false end
        saPlayerWarning.visible = false
        saPlayerWarning.reason = "disabled"
        return
    end
    if not saPlayerWarningBuild() then return end
    local now = tick()
    if not force and now - (saPlayerWarning.last or 0) < 0.1 then return end
    saPlayerWarning.last = now
    local best, reason = saPlayerWarningNearest()
    saPlayerWarning.reason = reason or "unknown"
    if not best then
        saPlayerWarning.visible = false
        saPlayerWarning.nearest, saPlayerWarning.meters = nil, nil
        saPlayerWarning.studs = nil
        pcall(function() saPlayerWarning.draw.Visible = false end)
        return
    end
    local name = SA.NearestDisplay(best.plr)
    local text = string.format("WARNING: %s %.0fm / 100m", name, best.meters)
    local okPos, pt = pcall(SA.AimPoint)
    if not okPos or not pt then pt = Vector2.new(640, 360) end
    pcall(function()
        saPlayerWarning.draw.Position = Vector2.new(pt.X, pt.Y - 52)
        saPlayerWarning.draw.Text = text
        saPlayerWarning.draw.Visible = true
    end)
    saPlayerWarning.visible = true
    saPlayerWarning.text = text
    saPlayerWarning.nearest = name
    saPlayerWarning.meters = best.meters
    saPlayerWarning.studs = best.studs
end

function SA.PlayerWarningRefresh() saPlayerWarningTick(true) end
function SA.PlayerWarningSet(on)
    on = on == true
    CFG.showPlayerWarning = on
    pcall(setFlag, "showPlayerWarning", on)
    saPlayerWarningTick(true)
end
function SA.PlayerWarningState()
    return {
        enabled = CFG.showPlayerWarning == true,
        built = saPlayerWarning.built == true,
        visible = saPlayerWarning.visible == true,
        threshold = SA.PLAYER_WARNING_METERS,
        text = saPlayerWarning.text,
        reason = saPlayerWarning.reason,
        nearest = saPlayerWarning.nearest,
        meters = saPlayerWarning.meters,
        studs = saPlayerWarning.studs,
        last = saPlayerWarning.last or 0,
    }
end

saPlayerWarningTick(true)
saPlayerWarning.conn = bindRender(function() saPlayerWarningTick(false) end)


-- ────────────────────────────────────────────────────────────────────
-- BETTER 5 · KEYBIND ERGONOMICS (all seven wrapped binds)
-- Rebind / Clear / toggle-hold-always / conflict detector. Rebind accepts
-- ANY KeyCode or UserInputType, Escape = None. Loaded after every feature
-- bind has been registered, so SA.AllKeybinds is complete here.
-- ────────────────────────────────────────────────────────────────────
-- ────────────────────────────────────────────────────────────────────
-- BETTER 5 · KEYBIND ERGONOMICS
-- All seven wrapped binds in one mini-section: Rebind, Clear, hold /
-- toggle / always mode, and a conflict detector. Rebind listens for ANY
-- KeyCode or UserInputType (mouse buttons included), with Escape = None.
-- ────────────────────────────────────────────────────────────────────

function SA.SetAllKeybindModes(mode)
    mode = ({ toggle = true, hold = true, always = true })[mode]
        and mode or "toggle"
    local n = 0
    for flag, cfg in pairs(SA.AllKeybinds or {}) do
        -- Set fields directly: Atlanta's cfg.set_mode("hold") calls
        -- cfg.set(false), which would fire every callback and switch all
        -- features OFF. A MODE change must never change ON/OFF state.
        cfg.mode = mode
        if mode == "always" then cfg.active = true end
        pcall(function()
            library.flags[flag] = { mode = cfg.mode, key = cfg.key,
                                    active = cfg.active }
        end)
        n = n + 1
    end
    CFG.keybindMode = mode
    return n
end

function SA.KeybindConflicts()
    local byKey, out = {}, {}
    for flag, cfg in pairs(SA.AllKeybinds or {}) do
        local k = SA.KeyToString(cfg.key)
        if k ~= "none" and k ~= "" then
            local bucket = byKey[k] or {}
            bucket[#bucket + 1] = flag
            byKey[k] = bucket
        end
    end
    for k, flags in pairs(byKey) do
        if #flags > 1 then
            table.sort(flags)
            out[#out + 1] = { key = k, flags = flags }
        end
    end
    table.sort(out, function(a, b) return a.key < b.key end)
    return out
end



function SA.StartRebind(flag)
    local cfg = SA.AllKeybinds and SA.AllKeybinds[flag] or nil
    if not cfg then return false, "unknown bind: " .. tostring(flag) end
    pcall(function() if SA.RebindConn then SA.RebindConn:Disconnect() end end)
    SA.RebindFlag = flag
    local conn
    conn = SA.Connect(UserInputService.InputBegan, function(input, gpe)
        if gpe then return end
        local key = nil
        if input.UserInputType == Enum.UserInputType.Keyboard then
            key = input.KeyCode
        else
            key = input.UserInputType
        end
        pcall(function() cfg.set(key) end)
        pcall(function() conn:Disconnect() end)
        SA.RebindConn, SA.RebindFlag = nil, nil
    end)
    SA.RebindConn = conn
    return true
end

function SA.CancelRebind()
    pcall(function() if SA.RebindConn then SA.RebindConn:Disconnect() end end)
    SA.RebindConn, SA.RebindFlag = nil, nil
end

function SA.ClearSelectedKeybind()
    local cfg = SA.AllKeybinds and SA.AllKeybinds[CFG.keybindSelected] or nil
    if not cfg then return false, "no bind selected" end
    if cfg.__saClear then pcall(cfg.__saClear) end
    return true
end



local kbCol = VisualTab:column()
local kbSec = kbCol:section({ name = "Keybinds (All 7)" })
local saKBSelectedItems = {}
for flag in pairs(SA.AllKeybinds or {}) do
    saKBSelectedItems[#saKBSelectedItems + 1] = flag
end
table.sort(saKBSelectedItems)
kbSec:dropdown({
    name = "Bind", flag = "hn_keybindSelected",
    items = saKBSelectedItems,
    default = CFG.keybindSelected,
    callback = function(v) CFG.keybindSelected = tostring(v or "hn_menu_bind") end,
})
kbSec:dropdown({
    name = "All Binds Mode", flag = "hn_keybindMode",
    items = { "toggle", "hold", "always" },
    default = CFG.keybindMode,
    callback = function(mode)
        CFG.keybindMode = mode
        SA.SetAllKeybindModes(mode)
    end,
})
addButton(kbSec, "Rebind Selected", function()
    SA.StartRebind(CFG.keybindSelected)
end)
addButton(kbSec, "Clear Selected", function()
    SA.ClearSelectedKeybind()
end)
addButton(kbSec, "Cancel Rebind", function() SA.CancelRebind() end)
addButton(kbSec, "Set All: Toggle", function() SA.SetAllKeybindModes("toggle") end)
addButton(kbSec, "Set All: Hold", function() SA.SetAllKeybindModes("hold") end)
kbSec:label({ name = "Rebind accepts ANY key or mouse button · Escape = None" })
