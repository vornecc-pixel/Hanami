-- ==================================================================
-- Hanami / tools/tests.lua — committed Fengari mock-runtime assertions
-- Loaded after tools/mocks.lua and dist/Hanami.lua by tools/run.js.
-- These are mock-environment checks, NOT proof of a real Roblox executor.
-- ==================================================================

local run = TEST_RUN or 1
local real_print = print
local checks = 0

local function ok(value, message)
    checks = checks + 1
    _G.TEST_ASSERTIONS = (_G.TEST_ASSERTIONS or 0) + 1
    if not value then error(message or "assertion failed", 0) end
end

local function eq(a, b, message)
    ok(a == b, (message or "values differ") .. ": got " .. tostring(a)
        .. ", want " .. tostring(b))
end

local function near(a, b, tolerance, message)
    ok(type(a) == "number" and math.abs(a - b) <= (tolerance or 0.001),
        (message or "number out of range") .. ": got " .. tostring(a)
        .. ", want " .. tostring(b))
end

local function contains(value, needle, message)
    local hay = tostring(value or "")
    ok(hay:find(needle, 1, true) ~= nil,
        (message or "missing substring") .. ": " .. needle .. " in " .. hay)
    return true
end

local function count(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

-- Keep the harness output readable: source diagnostics print hundreds of
-- lines, while real mock errors are always prefixed "[mock]" / "[warn]".
local function quiet(fn)
    local old_print = print
    print = function(...)
        if select("#", ...) > 0 then
            local first = tostring(select(1, ...))
            if first:find("[mock]", 1, true) or first:find("[warn]", 1, true) then
                real_print(...)
            end
        end
    end
    local good, err = pcall(fn)
    print = old_print
    if not good then error(err, 0) end
end

local function setFlags(changes)
    quiet(function()
        for key, value in pairs(changes) do setFlag(key, value) end
    end)
end

local function frameTimes(n)
    quiet(function()
        for _ = 1, n do mock_frame(0.016) end
    end)
end

-- ── re-execution / auto-load assertions (before any state reset) ─────
if run == 2 then
    eq(SA.LastConfigResult and SA.LastConfigResult.profile, "AutoProfile",
        "startup auto-load profile")
    eq(CFG.nearestTopN, 4, "auto-loaded nearestTopN")
    eq(CFG.perfMode, true, "auto-loaded perfMode")
    eq(CFG.targetPriority, "Nearest", "auto-loaded targetPriority")
    eq(CFG.autoLoadConfig, true, "auto-load setting")
    eq(SA.GetLastProfile(), "AutoProfile", "last-profile marker")
    ok(SA.Generation > (LAST_GENERATION or 0), "generation must advance on re-execute")
end
if run == 3 then
    eq(SA.Unloaded, false, "unload guard must reset on re-execute")
    eq(SA.Alive, true, "alive must reset on re-execute")
    ok(_G.__saShared ~= nil, "shared state rebuilt after full unload")
    ok(_G.__saCFG ~= nil, "CFG rebuilt after full unload")
    eq(SA.LastSelfCheck, nil, "stale self-check report cleared")
    -- FullUnload deliberately clears _G.__saShared, so the next execution
    -- starts a fresh generation rather than inheriting the old counter.
    ok(SA.Generation >= 1, "fresh generation after full unload")
    eq(window.opened, true, "fresh menu opens")
end

-- Old bindRender callbacks disconnect themselves on the first frame after
-- a loader re-execute; assert the event does not keep accumulating loops.
if run > 1 then
    local before = #RunService.RenderStepped._connections
    frameTimes(1)
    local after = #RunService.RenderStepped._connections
    ok(after <= before, "re-execute must not grow RenderStepped listeners")
    ok(after < 40, "render listener count is bounded")
    -- The wrapper is installed once on the library, with the stock methods
    -- preserved, so repeated loads cannot stack wrapper call chains.
    ok(library.__saKeybindWrapperInstalled == true
        and type(library.__saOriginalCreate) == "function"
        and type(library.__saOriginalKeybind) == "function",
        "single re-execution-safe keybind wrapper")
end

quiet(function() SA.ResetToDefaults() end)

-- ── startup, defaults, config coverage ──────────────────────────────
ok(type(SA) == "table", "SA shared state")
eq(SA.Alive, true, "SA.Alive")
eq(SA.Unloaded, false, "SA.Unloaded")
-- A full unload clears shared state, so a later run may legitimately
-- restart at generation 1; every run only needs a positive generation.
ok(SA.Generation >= 1, "generation")
eq(SA.STUDS_PER_METER, 3.571, "shared metres factor")
ok(type(CFG) == "table", "CFG table")
ok(type(SA.CFG_DEFAULTS) == "table", "shipped-default snapshot")
ok(count(ESP_DEFAULT_COLORS) >= 48, "48-colour palette")
ok(type(library) == "table", "Atlanta library")
ok(library.window == window, "library.window published")
eq(window.opened, true, "menu initially open")
ok(#mock_spawned >= 3, "long-lived scanner/gun/bow tasks installed")
contains(mock_httpget_url, "Atlanta/Library.lua", "Atlanta URL")
eq(mock_library_source, "return library, themes", "mock Atlanta source")

local newKeys = {
    "configProfile", "configName", "autoLoadConfig", "keybindMode",
    "keybindConflictWarn", "keybindSelected", "nearestTopN",
    "nearestShowHealth", "nearestShowState", "nearestShowTeam",
    "nearestCorner", "nearestScale", "nearestTransparency",
    "showNoTargetReason", "espOnlyNearest", "espNearestCount",
    "espOnlyAimTarget", "espTeamMode", "espShowLiveCount", "targetPriority",
    "fovPreset", "targetBoneMode", "espPreviewSource", "espPreviewCompare",
    "perfMode", "perfEspRebuildMs", "perfMaxEntities", "perfShowFps",
    "gunDiffOnScan", "gunOverrideString",
}
for _, key in ipairs(newKeys) do
    ok(CFG[key] ~= nil, "missing CFG." .. key)
    ok(SA.CFG_DEFAULTS[key] ~= nil, "missing shipped default " .. key)
    ok(type(library.config_flags["hn_" .. key]) == "function",
        "unbound hn_ flag " .. key)
    ok(library.flags["hn_" .. key] ~= nil, "uninitialised flag " .. key)
end
eq(#SA.ConfigCoverage(), 0, "hn_* config coverage")
ok(SA.FlagCount() > 40, "Atlanta flag count")
contains(SA.FlagSnapshot(), "hn_menu_bind", "flag snapshot")
ok(count(SA.AllKeybinds) >= 7, "all keybinds registered")
ok(count(SA.FeatureBinds) >= 7, "feature keybinds registered")

-- ── keybind ergonomics ──────────────────────────────────────────────
local menuBind = SA.AllKeybinds["hn_menu_bind"]
local masterBind = SA.AllKeybinds["hn_master_bind"]
local espBind = SA.AllKeybinds["hn_bind_espEnabled"]
local npcBind = SA.AllKeybinds["hn_bind_npcEspEnabled"]
ok(menuBind and masterBind and espBind and npcBind, "core binds exist")
eq(menuBind.key, Enum.KeyCode.RightShift, "menu key")
eq(menuBind.active, true, "menu bind active")
eq(menuBind.mode, "toggle", "menu mode")
eq(menuBind.name, "Toggle Menu", "menu bind row name")
eq(masterBind.key, Enum.KeyCode.Insert, "master key")
eq(#SA.KeybindConflicts(), 0, "no default key conflicts")
eq(SA.KeyToString("none"), "none", "None token")
contains(SA.KeyToString(Enum.KeyCode.Q), "Q", "key string")

local menuActive, espActive = menuBind.active, espBind.active
local modeCount = 0
quiet(function() modeCount = SA.SetAllKeybindModes("hold") end)
ok(modeCount >= 7, "mode applied to every bind")
for flag, cfg in pairs(SA.AllKeybinds) do
    eq(cfg.mode, "hold", "mode for " .. flag)
    eq(library.flags[flag].mode, "hold", "serialised mode for " .. flag)
end
eq(menuBind.active, menuActive, "mode change must not toggle menu")
eq(espBind.active, espActive, "mode change must not toggle ESP")
eq(CFG.keybindMode, "hold", "CFG.keybindMode")
quiet(function() SA.SetAllKeybindModes("toggle") end)
eq(CFG.keybindMode, "toggle", "mode restored")

local espKey, npcKey = espBind.key, npcBind.key
quiet(function()
    espBind.set(Enum.KeyCode.Q)
    npcBind.set(Enum.KeyCode.Q)
end)
local conflicts = SA.KeybindConflicts()
ok(#conflicts >= 1, "duplicate keys detected")
local foundQ = false
for _, c in ipairs(conflicts) do
    if contains(c.key, "Q", "conflict key") then foundQ = true end
end
ok(foundQ, "Q conflict reported")
quiet(function()
    espBind.set(espKey)
    npcBind.set(npcKey)
end)
eq(#SA.KeybindConflicts(), 0, "conflicts cleared")

quiet(function() ok(SA.StartRebind("hn_bind_espEnabled") == true, "rebind start") end)
ok(SA.RebindConn ~= nil, "rebind connection")
UserInputService.InputBegan:Fire({
    UserInputType = Enum.UserInputType.Keyboard,
    KeyCode = Enum.KeyCode.R,
}, false)
eq(espBind.key, Enum.KeyCode.R, "rebind accepts any KeyCode")
eq(SA.RebindConn, nil, "rebind connection released")
quiet(function() espBind.set(espKey) end)

quiet(function() SA.StartRebind("hn_master_bind") end)
ok(SA.RebindConn ~= nil, "second rebind connection")
SA.CancelRebind()
eq(SA.RebindConn, nil, "cancel rebind")

CFG.keybindSelected = "hn_bind_espEnabled"
quiet(function() ok(SA.ClearSelectedKeybind() == true, "clear selected") end)
eq(espBind.key, "none", "Escape / clear = None")
eq(espBind.__saListLbl.Visible, false, "cleared bind removed from list")
quiet(function() espBind.set(espKey) end)
CFG.keybindSelected = "hn_menu_bind"
quiet(function()
    ok(SA.PrintAllKeybinds() >= 7, "print all keybinds")
    SA.PrintKeybindConflicts()
    SA.FeatureBindDiag()
end)

-- ── native config profiles ──────────────────────────────────────────
setFlags({
    nearestTopN = 3,
    perfMode = true,
    targetPriority = "Nearest",
})
eq(CFG.nearestTopN, 3, "profile value written")
eq(CFG.perfMode, true, "profile toggle written")
eq(CFG.targetPriority, "Nearest", "profile dropdown written")
local saved, saveErr = SA.SaveProfile("BETTER Test")
ok(saved == true, "save profile: " .. tostring(saveErr))
local safeName = "BETTER_Test"
eq(CFG.configName, safeName, "saved config name")
eq(CFG.configProfile, safeName, "saved config profile")
eq(SA.GetLastProfile(), safeName, "last-profile marker")
eq(SA.LastConfigResult.profile, safeName, "save result")
local profileFound = false
for _, name in ipairs(SA.ListProfiles()) do
    if name == safeName then profileFound = true end
end
ok(profileFound, "profile appears in native list")
local configData = library:get_config()
local decoded = http_service:JSONDecode(configData)
eq(decoded.hn_nearestTopN, 3, "JSON slider")
eq(decoded.hn_perfMode, true, "JSON toggle")
eq(decoded.hn_targetPriority, "Nearest", "JSON dropdown")
ok(type(decoded.hn_menu_bind) == "table", "JSON keybind table")
ok(decoded.hn_menu_bind.key ~= nil, "JSON keybind key")

setFlags({
    nearestTopN = 1,
    perfMode = false,
    targetPriority = "Crosshair",
})
local loaded, loadErr = SA.LoadProfile(safeName)
ok(loaded == true, "load profile: " .. tostring(loadErr))
eq(CFG.nearestTopN, 3, "profile slider restored")
eq(CFG.perfMode, true, "profile toggle restored")
eq(CFG.targetPriority, "Nearest", "profile dropdown restored")
eq(SA.LastConfigResult.profile, safeName, "load result")
ok(SA.LastConfigResult.bytes > 0, "profile byte count")

local exported = SA.ExportConfig()
eq(getclipboard(), exported, "export to clipboard")
local imported, importErr = SA.ImportConfig(exported)
ok(imported == true, "import config: " .. tostring(importErr))
ok(SA.ImportConfig("") == false, "empty import rejected")
local rtGood, rtDetail = SA.TestConfigRoundTrip()
ok(rtGood == true, "config round-trip: " .. tostring(rtDetail))
contains(rtDetail, "flags round-tripped", "round-trip detail")
ok(SA.LoadProfile("no_such_profile") == false, "missing profile rejected")
ok(SA.DeleteProfile("default") == false, "default profile protected")
local deleted = SA.DeleteProfile(safeName)
ok(deleted == true, "delete profile")
profileFound = false
for _, name in ipairs(SA.ListProfiles()) do
    if name == safeName then profileFound = true end
end
ok(profileFound == false, "deleted profile gone from list")
quiet(function() SA.PrintProfiles() end)

-- ── self-check / panel ──────────────────────────────────────────────
local report = SA.SelfCheck()
ok(type(report.checks) == "table", "self-check table")
ok(#report.checks >= 30, "self-check breadth")
eq(report.failed, 0, "self-check failures")
ok(report.passed >= 25, "self-check passes")
ok(type(SA.SelfCheckState()) == "table", "self-check state")
quiet(function()
    SA.PrintSelfCheck()
    SA.PrintProfiles()
    if SA.PrintDrawWriteFailures then SA.PrintDrawWriteFailures() end
end)
local shown = SA.ShowSelfCheck(true)
eq(shown.failed, 0, "panel report failures")
local selfGui = gethui():FindFirstChild("HanamiSelfCheck")
ok(selfGui ~= nil, "self-check ScreenGui")
local selfLabel = selfGui and selfGui:FindFirstChild("Report")
if not selfLabel then
    for _, child in ipairs(selfGui:GetDescendants()) do
        if child.Name == "Report" then selfLabel = child end
    end
end
ok(selfLabel ~= nil, "self-check report label")
contains(selfLabel.Text, "HANAMI SELF-CHECK", "panel text")
SA.HideSelfCheck()
eq(selfGui.Enabled, false, "self-check hidden")
SA.DisposeSelfCheckPanel()
eq(gethui():FindFirstChild("HanamiSelfCheck"), nil, "self-check disposed")

-- ── aim / FOV / target UX ───────────────────────────────────────────
local aim = SA.AimPoint()
ok(type(aim.X) == "number" and type(aim.Y) == "number", "aim point")
ok(SA.FovRadius() > 0, "FOV radius")
setFlags({ masterEnabled = true, gunEnabled = true })
quiet(function() setFlag("fovPreset", "Legit") end)
eq(CFG.fovPreset, "Legit", "FOV preset state")
eq(CFG.fov, 90, "Legit radius")
eq(CFG.hitChance, 65, "Legit hit chance")
eq(SA.FovRadius(), 90, "shared FOV radius")
quiet(function() setFlag("fovPreset", "Custom") end)
eq(CFG.fovPreset, "Custom", "Custom preset state")

CFG.targetBone = "Hrp"
CFG.targetBoneMode = "Global"
eq(SA.ResolveTargetBone(), "Hrp", "global bone")
CFG.targetBoneMode = "Head for snipers"
local resolvedBone = SA.ResolveTargetBone()
ok(resolvedBone == "Head" or resolvedBone == "Hrp", "per-weapon bone resolves")
CFG.targetBoneMode = "Global"

local pinnedName, pinErr
quiet(function() pinnedName, pinErr = SA.PinNearestTarget() end)
eq(pinnedName, "NearestGuy", "pin nearest target: " .. tostring(pinErr))
eq(SA.PinnedTarget.name, "NearestGuy", "pinned target name")
eq(CFG.targetPriority, "Pinned", "priority changed to Pinned")
contains(SA.NoTargetReason(), "pinned", "pinned no-target reason")
SA.ClearPinnedTarget()
eq(SA.PinnedTarget, nil, "pinned target cleared")
quiet(function() setFlag("targetPriority", "Crosshair") end)
eq(CFG.targetPriority, "Crosshair", "priority restored")

-- ── top-N HUD / performance overlay ─────────────────────────────────
setFlags({
    nearestTopN = 2,
    showNoTargetReason = true,
    perfShowFps = true,
})
quiet(function()
    window.set_menu_visibility(false)
    SA.NearestWindowRefresh()
end)
local hud = SA.NearestWindowState()
eq(hud.enabled, true, "HUD enabled")
eq(hud.built, true, "HUD built")
eq(hud.visible, true, "HUD visible while menu hidden")
eq(hud.menuOpen, false, "menu hidden")
contains(hud.nearest, "NearestGuy", "nearest player")
near(hud.meters, 10 / SA.STUDS_PER_METER, 0.5, "metres conversion")
eq(hud.tool, "AssaultRifle", "held tool")
eq(hud.rows, 2, "two candidate rows")
eq(hud.topN, 2, "top-N setting")
eq(hud.health, 100, "HUD HP")
eq(hud.visibleState, "VIS", "HUD VIS")
eq(hud.teammate, false, "HUD team")
local nearestWindow = _G.__saNearestWindow
ok(nearestWindow and nearestWindow.gui, "HUD GUI state")
eq(nearestWindow.gui.Enabled, true, "HUD ScreenGui enabled")
contains(nearestWindow.label.Text, "2. ", "second HUD row")
contains(nearestWindow.label.Text, "aim:", "why-no-target line")
contains(nearestWindow.label.Text, "fps", "FPS line")

setFlags({ perfMode = true })
frameTimes(40)
local perfGui = gethui():FindFirstChild("HanamiPerfOverlay")
ok(perfGui ~= nil, "FPS overlay built")
eq(perfGui.Enabled, true, "FPS overlay shown with menu hidden")
local perf = SA.PerfState()
eq(perf.enabled, true, "performance mode")
ok(perf.frame >= 40, "render frames counted")
ok(perf.fps > 0, "rolling FPS estimate")
ok(perf.effectiveRebuildMs >= 16 and perf.effectiveRebuildMs <= 500,
    "adaptive rebuild interval")
ok(perf.effectiveEntityCap >= 1
    and perf.effectiveEntityCap <= CFG.perfMaxEntities,
    "adaptive entity cap")
eq(SA.DrawPoolStats().enabled, true, "draw pool enabled")
local writes = SA.DrawWriteFailures()
ok(type(writes.count) == "number", "draw write counter")
contains(SA.DrawDiag(), "backend=", "draw diagnostics")
quiet(function()
    window.set_menu_visibility(true)
    mock_frame(0.016)
    SA.NearestWindowRefresh()
end)
eq(perfGui.Enabled, false, "FPS overlay hidden with menu open")
eq(SA.NearestWindowState().visible, false, "HUD hidden with menu open")

-- ── ESP decluttering / live counts ──────────────────────────────────
setFlags({
    espEnabled = true,
    npcEspEnabled = true,
    crateEnabled = true,
    espOnlyNearest = true,
    espNearestCount = 1,
    espShowLiveCount = true,
    perfMode = true,
})
frameTimes(20)
ok(#SA.GetNpcs() >= 1, "NPC registry")
ok(#SA.GetCrates() >= 1, "crate registry")
ok(count(espObjects) >= 1, "player ESP objects built")
ok(count(npcObjects) >= 1, "NPC ESP objects built")
ok(count(crateObjects) >= 1, "crate ESP objects built")
local espStats = SA.EspPassStats()
ok(type(espStats.players) == "number", "live player count")
ok(type(espStats.npcs) == "number", "live NPC count")
ok(type(espStats.crates) == "number", "live crate count")
eq(espStats.nearest, 1, "nearest-N stat")
eq(espStats.teamMode, "All", "team-mode stat")
eq(espStats.onlyAimTarget, false, "aim-only stat")

local players = Players:GetPlayers()
local otherPlayer, otherChar = players[2], players[2].Character
local farChar = players[3].Character
eq(SA.EspPassAllowed("player", otherChar, 10, otherChar), true,
    "nearest player passes")
eq(SA.EspPassAllowed("player", farChar, 30, nil), false,
    "far player decluttered")
quiet(function() setFlag("espOnlyAimTarget", true) end)
eq(SA.EspPassAllowed("player", otherChar, 10, otherChar), true,
    "aim target keeps a slot")
eq(SA.EspPassAllowed("player", otherChar, 10, nil), false,
    "non-target hidden by aim-only")
quiet(function() setFlag("espOnlyAimTarget", false) end)

lp:SetAttribute("FustMates", tostring(otherPlayer.UserId))
eq(SA.IsTeammate(otherPlayer), true, "teammate detection")
CFG.espTeamMode = "Exclude Teammates"
eq(SA.EspPassAllowed("player", otherChar, 10, otherChar), false,
    "exclude teammate filter")
CFG.espTeamMode = "Teammates Only"
eq(SA.EspPassAllowed("player", otherChar, 10, otherChar), true,
    "teammates-only filter")
lp:SetAttribute("FustMates", nil)
setFlags({
    espTeamMode = "All",
    espOnlyNearest = false,
    espNearestCount = 5,
    espShowLiveCount = false,
    espEnabled = false,
    npcEspEnabled = false,
    crateEnabled = false,
})

-- ── real-model, side-by-side ESP Preview ─────────────────────────────
ok(type(pv) == "table", "preview state")
ok(pv.ui ~= nil and pv.ui2 ~= nil, "two overlay sets")
ok(pv.model ~= nil, "primary live model")
ok(type(pv.parts) == "table" and #pv.parts > 0, "cloned model parts")
setFlags({
    espPreviewCompare = true,
    espPreviewSource = "Nearest Player",
    espPreviewKind = "Player",
})
quiet(function() SA.EspPreviewRefresh() end)
ok(pv.model2 ~= nil, "second live model")
eq(pv.lastCompare, true, "compare state")
eq(pv.lastSource, "Nearest Player", "source state")
eq(pv.ui2.holder.Visible, true, "second overlay visible")
contains(pv.reason, "nearest player", "real-model source reason")
quiet(function()
    SA.EspPreviewDiag()
    mock_frame(0.016)
end)
eq(pv.styleErr, nil, "preview styling has no error")
quiet(function() SA.EspPreviewSet(false) end)
eq(pv.enabled, false, "preview disabled")
eq(pv.root.Visible, false, "viewport hidden")
quiet(function() SA.EspPreviewSet(true) end)
eq(pv.enabled, true, "preview re-enabled")
eq(pv.root.Visible, true, "viewport visible")
setFlags({
    espPreviewCompare = false,
    espPreviewSource = "Local Character",
})
quiet(function() SA.EspPreviewRefresh() end)

-- ── live gun diff / new-gun stubs / manual overrides ─────────────────
local baseSpeed = SA.GunBaseline.assault_rifle.speed
local applied, bad = SA.ApplyGunOverrides("assault_rifle.speed=1555;bad.field=1")
eq(applied, 1, "one valid override")
eq(#bad, 1, "one ignored override")
eq(SA.GUN_SPECS.assault_rifle.speed, 1555, "override reached gun spec")
local diff = SA.GunDiff()
contains(table.concat(diff.changed, "\n"), "assault_rifle.speed", "gun diff")
local synced
quiet(function()
    SA.PrintGunDiff()
    SA.PrintGunOverrides()
    synced = SA.SyncGunDefs()
    SA.PrintGunTable()
end)
ok(type(synced) == "number" and synced > 0, "GC sync changed fields")
ok(SA.GUN_SPECS.proto_railgun ~= nil, "new-gun stub registered")
local diff2 = SA.GunDiff()
contains(table.concat(diff2.added, ","), "proto_railgun", "new-gun diff")
SA.GUN_SPECS.assault_rifle.speed = baseSpeed
SA.InvalidateGunCache()
eq(SA.GUN_SPECS.assault_rifle.speed, baseSpeed, "baseline speed restored")

-- ── UI buttons (every callback is pcall-wrapped by the mock) ─────────
local buttonNames = {
    "Print Feature Keybinds", "Print Profiles", "Run Config Round-Trip Test",
    "Run Self-Check", "Show Self-Check Panel", "Hide Self-Check Panel",
    "Print Config Coverage", "Print Draw Write Failures",
    "Print Performance State", "Print Live ESP Counts", "Print Live Gun Diff",
    "Print All Keybinds", "Print Conflicts", "Set All: Hold",
    "Set All: Toggle", "Print Override Help", "Sync Gun Defs + Diff",
    "Print Full Gun Table", "Print Nearest HUD", "Print Draw Pool",
    "Refresh Nearest HUD", "Print FOV State", "Print Gun Table",
    "Print Bow Mods State", "Print Attachments", "Print Manip State (classic)",
    "Print Silent Aim (v7.7)", "Print Current Target", "Print Prediction",
    "Print ESP Features", "Print Why No Target", "Print Draw Backend",
    "Print Live Ping", "Print Player ESP State", "Rebuild Player ESP",
    "Rebuild ESP Preview", "Show ESP Preview Panel", "Print Gun Spec",
    "Print Crate Names (debug)", "Print Crate States (debug)",
    "Apply Recommended Wall Pen", "Apply Blatant", "Disable All",
    "Pin Nearest Player", "Clear Pinned Target", "Lock Nearest as Aim Target",
    "Export Config to Clipboard", "Import Config from Clipboard",
    "Save Profile", "Load Profile", "Delete Profile", "Reset ESP Colours",
    "Restore Bow Timings", "Scan All Entities", "Toggle Manip",
    "Apply Overrides Now", "Rebind Selected", "Cancel Rebind",
    "Reset to Defaults",
}
for _, name in ipairs(buttonNames) do
    local fn = library.buttons[name]
    ok(type(fn) == "function", "missing UI button: " .. name)
    quiet(function() fn() end)
end
SA.CancelRebind()
SA.ClearPinnedTarget()
quiet(function()
    SA.DisposeSelfCheckPanel()
    SA.SetAllKeybindModes("toggle")
    SA.ResetToDefaults()
    window.set_menu_visibility(true)
end)
eq(#SA.KeybindConflicts(), 0, "no conflicts after button sweep")
eq(CFG.keybindMode, "toggle", "modes restored after button sweep")

-- ── full unload / next-run preparation ──────────────────────────────
if run == 1 then
    -- Prepare a real startup auto-load for the NEXT re-execute. The live
    -- CFG and the saved profile both keep autoLoadConfig = true.
    setFlags({
        autoLoadConfig = true,
        nearestTopN = 4,
        perfMode = true,
        targetPriority = "Nearest",
    })
    local autoSaved = SA.SaveProfile("AutoProfile")
    ok(autoSaved == true, "auto-load profile saved")
    setFlags({
        nearestTopN = 1,
        perfMode = false,
        targetPriority = "Crosshair",
    })
    eq(CFG.autoLoadConfig, true, "live auto-load setting")
    eq(SA.GetLastProfile(), "AutoProfile", "last profile for next run")
    eq(CFG.nearestTopN, 1, "live value differs from saved profile")
    SA.LastConfigResult = nil
    LAST_GENERATION = SA.Generation
else
    LAST_GENERATION = SA.Generation
    local unloaded, why = SA.FullUnload()
    ok(unloaded == true, "full unload: " .. tostring(why))
    eq(SA.Alive, false, "unload stops loops")
    eq(SA.Unloaded, true, "unload guard")
    eq(_G.__saShared, nil, "shared state cleared")
    eq(_G.__saCFG, nil, "CFG cleared")
    eq(_G.__saEspPreview, nil, "preview state cleared")
    eq(_G.__saNearestWindow, nil, "HUD state cleared")
    eq(count(SA.AllKeybinds), 0, "keybind registry cleared")
    eq(SA.PinnedTarget, nil, "pinned target cleared")
    ok(SA.FullUnload() == false, "unload is one-shot")
    eq(window.opened, false, "menu hidden by unload")
    eq(gethui():FindFirstChild("HanamiNearestPlayer"), nil, "HUD destroyed")
    eq(gethui():FindFirstChild("HanamiPerfOverlay"), nil, "FPS overlay destroyed")
    eq(gethui():FindFirstChild("HanamiSelfCheck"), nil, "self-check destroyed")
end

eq(callback_errors, 0, "mock callback errors")
eq(event_errors, 0, "mock event errors")
ok(mock_frame_count > 0, "render frames exercised")
eq(type(SA.DrawBackend()), "string", "draw backend string")

_G.TEST_RUN_OK = 1
print = real_print
real_print(string.format("[runtime] run %d: %d assertions passed", run, checks))
real_print("RUNTIME HARNESS OK")
