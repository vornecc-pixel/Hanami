-- ==================================================================
-- Hanami / 24_ui_visual.lua — Visual tab (FOV, snapline, debug)
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================

-- ── VISUAL : FOV + Snapline ─────────────────────────────────────────
local fovCol = VisualTab:column()
local fovSec = fovCol:section({ name = "FOV Circle / Snapline" })

bindToggle(fovSec, "Show FOV Circle", "showFov",
    "The circle IS the aim reference point: silent aim, snapline, tracers and arrows all use the same centre + radius")
bindToggle(fovSec, "Filled", "fovFilled")
bindDropdown(fovSec, "FOV Centre", "fovCenterMode", { "Mouse", "Screen Center" })
fovSec:label({ name = "Centre = crosshair / screen centre; invalid mouse -> centre" })
bindToggle(fovSec, "Force ScreenGui Drawing", "forceGuiDrawing",
    "ON (default) = reliable Roblox GUI frames. Turn OFF only if you want to try the executor's native Drawing API")
fovSec:label({ name = "FOV / snapline / lead colours: ESP -> Colours -> Global" })
-- CFG.fov -> SA.FovRadius(): ONE radius for the circle, aim cone, tracers and arrows
bindSlider(fovSec, "Aim / Circle Radius (px)", "fov", 30, 500, 1, "px")
bindSlider(fovSec, "Transparency (%)", "fovTransparency", 0, 100, 1, "%")
fovSec:label({ name = "Transparency 0% = solid, 100% = nearly invisible" })
bindSlider(fovSec, "Thickness", "fovThickness", 1, 5, 1, "")

bindToggle(fovSec, "Snapline (aim preview)", "snapLineEnabled",
    "Line from the FOV centre to the exact target silent aim would pick. GREEN = clear, RED = blocked")
bindDropdown(fovSec, "Line Origin", "snapLineOrigin", { "Mouse", "Center", "Bottom" })
bindSlider(fovSec, "Snapline Thickness", "snapLineThickness", 1, 5, 1, "")
bindToggle(fovSec, "Show Lead Marker", "snapShowLead",
    "Ring = the exact point the ballistic solver will aim at (moving targets / bullet drop)")

-- ── VISUAL : Debug ─────────────────────────────────────────────────
local dbgCol = VisualTab:column()
local dbgSec = dbgCol:section({ name = "Debug" })

bindToggle(dbgSec, "Debug Log", "debug")
addButton(dbgSec, "Print Silent Aim (v7.7)", function()
    local s = SA.SilentAimState()
    local prio = Enum.RenderPriority.Camera.Value
    print(string.format("[sa] snap @ %d | restore @ %d (Camera @ %d)",
        s.snapPriority, s.restorePriority, prio))
    print("[sa] binds:", s.snapBind, "/", s.restoreBind, "| lock:", s.lock)
    print("[sa] fix A reorder:", s.reorder, "| conns:", s.reorderedConnections,
        "| reason:", s.reorderReason)
    print("[sa] fix B hooked tools:", s.hookedTools,
        "| guns only:", s.gunsOnly, "| bow equipped:", s.bowEquipped)
    print(string.format("[sa] tap window: %.2fs | bow equipped: %s | snapped: %s",
        s.tapWindow, tostring(s.bowEquipped), tostring(s.snapped)))
end)
addButton(dbgSec, "Retry Tap Hooks", function()
    SA.InstallTapReorder()
    local s = SA.SilentAimState()
    print("[sa] fix A:", s.reorderReason, "| fix B tools:", s.hookedTools)
end)
addButton(dbgSec, "Print Bow Mods State", function()
    local b = SA.BowModsState()
    print(string.format("[bow] master=%s instantCharge=%s noCooldown=%s | u10 cfg tables=%d | u14 live states=%d | patched=%d",
        tostring(b.enabled), tostring(b.instantCharge), tostring(b.noCooldown),
        b.configTables, b.liveStates, b.patched))
    print("[bow] hint: needs getgc + setreadonly; enable 'Enable Bow Mods' in Gun Mods -> Bow Mods")
end)
addButton(dbgSec, "Print Attachments", function() SA.PrintAttachments() end)
addButton(dbgSec, "Print Gun Table", function() SA.PrintGunTable() end)
addButton(dbgSec, "Print Draw Backend", function()
    print("[sa] drawing backend:", SA.DrawBackend())
    print("[sa]", SA.DrawDiag())
end)
addButton(dbgSec, "Print FOV State", function()
    local s = SA.FovState()
    print("[fov] enabled:", s.enabled, "| exists:", s.exists, "| visible:", s.visible)
    print(string.format("[fov] centre: %.0f,%.0f (%s) | radius: %.0f | filled: %s | transparency: %s | thickness: %s",
        s.centre.X, s.centre.Y, tostring(s.centreMode), s.radius,
        tostring(s.filled), tostring(s.transparency), tostring(s.thickness)))
    print("[fov] backend:", s.backend, "| write failures:", s.failures)
    print("[fov]", s.diag)
    print("[fov] fix: toggle 'Show FOV Circle', set Centre = Screen Center, keep 'Force ScreenGui Drawing' ON")
end)
addButton(dbgSec, "Print Gun Spec", function()
    SA.PrintGunSpec()
end)
addButton(dbgSec, "Print Prediction", function()
    local cam = ws.CurrentCamera
    local t = SA.Target
    if not (cam and t.model and t.pos) then
        print("[sa] prediction: no target in FOV"); return
    end
    SA.PrintPrediction(cam.CFrame.Position, t.pos, t.model)
end)
addButton(dbgSec, "Sync Gun Defs (GC)", function()
    local n = SA.SyncGunDefs()
    if n == 0 then print("[sa] no live gun tables found; using static specs") end
end)
addButton(dbgSec, "Print Manip State (classic)", function()
    local m = SA.ManipState()
    print(string.format("[manip] frame=%d rays left=%d/%d disabled=%d cached=%d dirs=%d",
        m.frame, m.remaining, m.budget, m.disabled, m.cached, m.directions))
    print(string.format("[manip] range=%s peek=%s deltaCap=%s parts=%s hyst=%s peekOrigin=%s",
        tostring(m.range), tostring(m.basePeek), tostring(m.deltaCap),
        tostring(m.parts), tostring(m.hysteresis), tostring(m.peek or "none")))
end)
addButton(dbgSec, "Print Current Target", function()
    local t = SA.Target
    if not t.model then print("[sa] target: none in FOV"); return end
    print(string.format("[sa] target: %s | %s | age %.2fs | last shot: %s",
        t.model.Name, t.visible and "VISIBLE" or "BLOCKED",
        tick() - (t.t or 0), t.lastShot and t.lastShot.Name or "never"))
end)

-- ── NEAREST PLAYER HUD (visible while the menu is hidden) ───────────
-- When the Atlanta menu is minimised / toggled off with RightShift, a small
-- companion window shows the closest OTHER player, their distance in
-- metres and the tool they are holding. It is deliberately NOT part of
-- library.guis, so set_menu_visibility(false) cannot disable it.
if SA.NearestWindowDispose then pcall(SA.NearestWindowDispose) end
local saNearest = {}
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
    if saNearest.conn then pcall(function() saNearest.conn:Disconnect() end) end
    if saNearest.gui then pcall(function() saNearest.gui:Destroy() end) end
    saNearest.gui, saNearest.frame, saNearest.label, saNearest.conn = nil, nil, nil, nil
    saNearest.built, saNearest.visible = false, false
    saNearest.reason = "disposed"
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
        frame.Size = UDim2.new(0, 248, 0, 86)
        frame.BackgroundColor3 = Color3.fromRGB(16, 18, 26)
        frame.BackgroundTransparency = 0.12
        frame.BorderSizePixel = 0
        frame.Active = true
        frame.Parent = gui
        pcall(function() frame.Draggable = true end)
        local vp = SA.ViewportSize()
        frame.Position = UDim2.new(0, vp.X < 270 and 4 or 12,
                                   0, vp.Y < 110 and 4 or 12)
        pcall(function()
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0.08, 0)
            corner.Parent = frame
        end)
        pcall(function()
            local stroke = Instance.new("UIStroke")
            stroke.Color = Color3.fromRGB(90, 110, 160)
            stroke.Thickness = 1
            stroke.Transparency = 0.25
            stroke.Parent = frame
        end)

        local label = Instance.new("TextLabel")
        label.Name = "NearestText"
        label.Size = UDim2.new(1, -16, 1, -16)
        label.Position = UDim2.new(0, 8, 0, 8)
        label.BackgroundTransparency = 1
        label.Text = "NEAREST PLAYER\n—\nwaiting for players…"
        label.TextColor3 = Color3.fromRGB(230, 235, 255)
        label.TextStrokeColor3 = Color3.new(0, 0, 0)
        label.TextStrokeTransparency = 0
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextYAlignment = Enum.TextYAlignment.Top
        label.TextWrapped = true
        label.TextSize = 13
        label.Parent = frame
        pcall(function() label.TextTruncate = Enum.TextTruncate.AtEnd end)
        pcall(function() SA.ApplyEspFont(label) end)

        saNearest.gui, saNearest.frame, saNearest.label = gui, frame, label
        saNearest.built, saNearest.reason = true, "built"
    end)
    if not ok then
        saNearest.reason = "build failed: " .. tostring(err)
        saNearest.built = false
        return false
    end
    return true
end

local function saNearestPlayer()
    local myRoot = SA.PlayerRig(lp.Character)
    local myPos = myRoot and myRoot.Position or nil
    if not myPos then
        pcall(function() myPos = ws.CurrentCamera.CFrame.Position end)
    end
    if not myPos then return nil, nil, nil, "no local position" end
    local ok, players = pcall(function() return Players:GetPlayers() end)
    if not ok or not players then return nil, nil, nil, "Players:GetPlayers failed" end
    local best, bestDist = nil, math.huge
    for _, plr in ipairs(players) do
        if plr ~= lp then
            local root = plr.Character and SA.PlayerRig(plr.Character) or nil
            if root and root.Position then
                local okD, d = pcall(function()
                    return (myPos - root.Position).Magnitude
                end)
                if okD and d and d < bestDist then
                    best, bestDist = plr, d
                end
            end
        end
    end
    if not best then return nil, nil, nil, "no other player with a rig" end
    local tool = "None"
    pcall(function() tool = SA.GetTool(best.Character) end)
    return best, bestDist, tool, "ok"
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
    if saNearest.gui then saNearest.gui.Enabled = show end
    saNearest.enabled, saNearest.menuOpen, saNearest.visible = enabled, menuOpen, show
    if not enabled then
        saNearest.reason = "disabled"
        return
    end
    local now = tick()
    if not force and now - (saNearest.lastUpdate or 0) < 0.1 then return end
    saNearest.lastUpdate = now
    local plr, dist, tool, reason = saNearestPlayer()
    saNearest.lastReason = reason
    if not plr then
        saNearest.lastName, saNearest.lastDist = nil, nil
        saNearest.lastMeters, saNearest.lastTool = nil, nil
        if saNearest.label then
            saNearest.label.Text = "NEAREST PLAYER\n—\n" .. tostring(reason)
        end
        return
    end
    local display = plr.Name
    pcall(function()
        if plr.DisplayName and plr.DisplayName ~= "" then
            display = string.format("%s (@%s)", tostring(plr.DisplayName),
                                    tostring(plr.Name))
        end
    end)
    local meters = dist / (SA.STUDS_PER_METER or 3.571)
    saNearest.lastName, saNearest.lastDist = display, dist
    saNearest.lastMeters, saNearest.lastTool = meters, tostring(tool)
    if saNearest.label then
        saNearest.label.Text = string.format(
            "NEAREST PLAYER\n%s\n%.1f m  ·  [ %s ]",
            display, meters, tostring(tool))
    end
end

function SA.NearestWindowRefresh() saNearestTick(0, true) end
function SA.NearestWindowSet(on)
    on = on == true
    CFG.nearestWindow = on
    pcall(setFlag, "nearestWindow", on)
    saNearestTick(0, true)
end
function SA.NearestWindowState()
    return {
        enabled = CFG.nearestWindow == true,
        built = saNearest.built == true,
        visible = saNearest.visible == true,
        menuOpen = window and window.opened,
        nearest = saNearest.lastName,
        studs = saNearest.lastDist,
        meters = saNearest.lastMeters,
        tool = saNearest.lastTool,
        reason = (saNearest.built and (saNearest.lastReason or "ok"))
            or saNearest.reason or "unknown",
        lastUpdate = saNearest.lastUpdate or 0,
    }
end
function SA.NearestWindowDiag()
    local s = SA.NearestWindowState()
    print("════════════ NEAREST PLAYER HUD ════════════")
    print("  enabled:", tostring(s.enabled), "| built:", tostring(s.built),
        "| visible:", tostring(s.visible), "| menu open:", tostring(s.menuOpen))
    print("  nearest:", tostring(s.nearest or "none"),
        "| metres:", s.meters and string.format("%.1f m", s.meters) or "n/a",
        "| studs:", s.studs and string.format("%.1f", s.studs) or "n/a")
    print("  tool:", tostring(s.tool or "none"), "| reason:", tostring(s.reason))
    print("══════════════════════════════════════")
end

bindToggle(dbgSec, "Nearest Player HUD", "nearestWindow",
    "Shows the closest player + distance in metres + held tool while the menu is hidden / minimised")
dbgSec:label({ name = "1 m ≈ 3.571 studs (same as ESP distance)" })
addButton(dbgSec, "Refresh Nearest HUD", function() SA.NearestWindowRefresh() end)
addButton(dbgSec, "Print Nearest HUD", function() SA.NearestWindowDiag() end)

saNearestBuild()
saNearestTick(0, true)
saNearest.conn = bindRender(function(dt) saNearestTick(dt) end)
