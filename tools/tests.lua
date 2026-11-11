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

-- Keep the harness output readable: real mock errors are always prefixed
-- "[mock]" / "[warn]". The shipped source emits no output of its own, so
-- quiet() is only a guard around the mock's own diagnostics.
local function quiet(fn)
    local saved = { print = print, warn = warn }
    print = function(...)
        if select("#", ...) > 0 then
            local first = tostring(select(1, ...))
            if first:find("[mock]", 1, true) or first:find("[warn]", 1, true) then
                real_print(...)
            end
        end
    end
    warn = function(...)
        if select("#", ...) > 0 then
            local first = tostring(select(1, ...))
            if first:find("[mock]", 1, true) or first:find("[warn]", 1, true) then
                saved.warn(...)
            end
        end
    end
    local good, err = pcall(fn)
    print, warn = saved.print, saved.warn
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
    ok(_G.__saFustBow ~= nil, "Fust bow state rebuilt after full unload")
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
    ok(SA.ManipPopupState and SA.ManipPopupState().built == false,
        "manip popup stays unbuilt while OFF after re-execute")
    eq(SA.FustBowState().hooked, true, "re-execute reinstalls the Fust bow hook")
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
    "keybindSelected", "nearestTopN",
    "nearestShowHealth", "nearestShowState", "nearestShowTeam",
    "nearestCorner", "nearestScale", "nearestTransparency",
    "showNoTargetReason", "espOnlyNearest", "espNearestCount",
    "espOnlyAimTarget", "espTeamMode", "espShowLiveCount", "targetPriority",
    "fovPreset", "targetBoneMode", "espPreviewSource", "espPreviewCompare",
    "perfMode", "perfEspRebuildMs", "perfMaxEntities", "perfShowFps",
    "gunOverrideString",
    "hitboxEnabled", "hitboxTarget", "hitboxMode", "hitboxScale",
    "hitboxCap", "hitboxMaxDist", "hitboxTeamCheck", "hitboxAliveOnly",
    "hitboxVisible", "hitboxNpcs", "fireWallCheck", "espDataRefreshMs",
    "fustBowEnabled", "fustBowFov", "fustBowTargetPart",
    "fustBowManipulation", "fustBowManipPeek", "fustBowManipMaxDist",
    "fustBowOriginRadius",
    "gunNoSpread", "gunShotProbe", "gunInspectDefs", "gunInspectScripts",
    "gunInspectGunControl", "gunInspectLiveGun", "gunNoRecoil",
    "gunCameraKickFilter", "gunFireRate", "gunFireRateMultiplier",
    "gunInfiniteAmmo", "gunMoveShoot",
    "displayBrightnessEnabled", "displayBrightness",
    "uiTheme", "uiFont",
}
for _, key in ipairs(newKeys) do
    ok(CFG[key] ~= nil, "missing CFG." .. key)
    ok(SA.CFG_DEFAULTS[key] ~= nil, "missing shipped default " .. key)
    ok(type(library.config_flags["hn_" .. key]) == "function",
        "unbound hn_ flag " .. key)
    ok(library.flags["hn_" .. key] ~= nil, "uninitialised flag " .. key)
end
eq(#SA.ConfigCoverage(), 0, "hn_* config coverage")

-- ── OFF defaults, white inline pickers, themes, fonts, 60-50 FPS ────
do
    local function rgbEq(c, r, g, b)
        return type(c) == "table"
            and math.floor((c.R or 0) * 255 + 0.5) == r
            and math.floor((c.G or 0) * 255 + 0.5) == g
            and math.floor((c.B or 0) * 255 + 0.5) == b
    end
    local function white(c) return rgbEq(c, 255, 255, 255) end

    -- Every shipped boolean is a feature toggle and must start OFF, both
    -- in the immutable snapshot and in the live CFG after reset.
    local booleanDefaults = 0
    for k, v in pairs(SA.CFG_DEFAULTS) do
        if type(v) == "boolean" then
            booleanDefaults = booleanDefaults + 1
            ok(v == false, "shipped default OFF: " .. k)
            ok(CFG[k] == false, "live default OFF: " .. k)
        end
    end
    ok(booleanDefaults >= 100, "all boolean feature defaults covered")

    -- Every customizable colour is white and chained INLINE onto the
    -- toggle / slider / dropdown that owns it, never a separate section.
    local pickerCount = 0
    for colorKey, shipped in pairs(ESP_DEFAULT_COLORS) do
        ok(white(shipped), "white shipped colour: " .. colorKey)
        local flag = "hn_col_" .. colorKey
        local flagValue = library.flags[flag]
        ok(type(flagValue) == "table" and white(flagValue.Color),
            "white inline picker: " .. colorKey)
        local owner = library.__saInlinePickers[flag]
        local controlKey = SA.INLINE_COLOR_OWNER[colorKey]
        ok(owner ~= nil and controlKey ~= nil
            and owner.flag == "hn_" .. controlKey,
            "inline picker owner: " .. colorKey)
        pickerCount = pickerCount + 1
    end
    eq(pickerCount, 48, "48 inline colourpickers")
    eq(count(SA.INLINE_COLOR_OWNER), 48, "one owner per colourpicker")
    eq(count(library.__saInlinePickers), 48, "no separate colour section")

    -- 9 additional full Atlanta presets (10 total) and 10 font picks.
    ok(#SA.UI_THEME_NAMES >= 9, "9+ named theme presets")
    ok(#SA.UI_FONT_NAMES >= 10, "10 popular font picks")
    eq(#SA.UI_THEME_KEYS, 9, "all Atlanta theme colours")
    local complete = 0
    for _, name in ipairs(SA.UI_THEME_NAMES) do
        local preset = SA.UI_THEMES[name]
        ok(type(preset) == "table", "theme preset: " .. name)
        local keys = 0
        for _, themeKey in ipairs(SA.UI_THEME_KEYS) do
            local rgb = preset[themeKey]
            if type(rgb) == "table" and #rgb == 3 then keys = keys + 1 end
        end
        eq(keys, 9, "full theme palette: " .. name)
        complete = complete + 1
    end
    eq(complete, #SA.UI_THEME_NAMES, "every named theme is complete")
    eq(#SA.UI_FONTS, 10, "ten font definitions")
    eq(CFG.uiTheme, SA.CFG_DEFAULTS.uiTheme, "theme default")
    eq(CFG.uiFont, SA.CFG_DEFAULTS.uiFont, "font default")

    -- Event-driven only: applying a theme/font adds no render listener,
    -- forces no performance mode, and keeps the existing 60 FPS budget.
    local listenersBefore = #RunService.RenderStepped._connections
    local updatesBefore = {}
    for _, themeKey in ipairs(SA.UI_THEME_KEYS) do
        updatesBefore[themeKey] = library.__saThemeUpdates[themeKey] or 0
    end
    local themeOk, applied = SA.ApplyTheme("Sakura")
    eq(themeOk, true, "theme applies all colours")
    eq(applied, 9, "nine theme colours applied")
    eq(CFG.uiTheme, "Sakura", "theme CFG updated")
    eq(SA.ThemeState().name, "Sakura", "theme state updated")
    ok(rgbEq(SA.ThemeState().colors.accent, 255, 110, 170),
        "Sakura accent colour applied")
    for _, themeKey in ipairs(SA.UI_THEME_KEYS) do
        ok((library.__saThemeUpdates[themeKey] or 0) > updatesBefore[themeKey],
            "Atlanta theme update: " .. themeKey)
    end

    local fontBefore = library.font
    local statusLabel = nil
    for obj in pairs(SA.__saFontStatusLabels or {}) do
        statusLabel = obj
        break
    end
    ok(statusLabel ~= nil, "font status label registered")
    local espLabel = Instance.new("TextLabel")
    SA.ApplyEspFont(espLabel)
    local fontOk, fontName = SA.ApplyFont("Gotham Bold")
    eq(fontOk, true, "font applies")
    eq(fontName, "Gotham Bold", "font name")
    eq(CFG.uiFont, "Gotham Bold", "font CFG updated")
    eq(SA.FontState().name, "Gotham Bold", "font state updated")
    eq(SA.ESP_FONT.Name, "GothamBold", "ESP font enum updated")
    ok(library.font ~= nil and library.font ~= fontBefore,
        "Atlanta menu font updated")
    eq(espLabel.Font, SA.ESP_FONT, "live ESP label Font refreshed")
    eq(espLabel.FontFace, library.font, "live ESP label FontFace refreshed")
    local menuText = nil
    for _, inst in ipairs(library.instances or {}) do
        if inst:IsA("TextLabel") then menuText = inst; break end
    end
    ok(menuText ~= nil, "menu text instance available")
    eq(menuText.FontFace, library.font, "menu text FontFace refreshed")
    contains(statusLabel.inst.Text, "Font: Gotham Bold",
        "font status label refreshed")
    eq(#RunService.RenderStepped._connections, listenersBefore,
        "theme/font add no render listeners")
    eq(CFG.perfMode, false, "theme/font do not force perfMode")
    eq(SA.EspFrameBudget().targetFps, 60, "60 FPS budget preserved")
    ok(SA.ApplyEspFontAll() >= 1, "ESP font registry refresh")
    pcall(SA.ApplyTheme, SA.CFG_DEFAULTS.uiTheme)
    pcall(SA.ApplyFont, SA.CFG_DEFAULTS.uiFont)
    eq(CFG.uiTheme, SA.CFG_DEFAULTS.uiTheme, "theme default restored")
    eq(CFG.uiFont, SA.CFG_DEFAULTS.uiFont, "font default restored")
end

eq(CFG.fustBowEnabled, false, "Fust bow ballistic aim default OFF")
eq(SA.FustBowState().hooked, true, "hookfunction installed at startup")
eq(SA.FustBowState().remotesReady, true, "Fust Shoot remote resolved")
eq(SA.FustBowState().rewrites >= 0, true, "Fust bow state exposes counters")
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
    ok(count(SA.AllKeybinds) >= 7, "keybind registry size")
    ok(type(SA.KeybindConflicts()) == "table", "keybind conflicts state")
    ok(count(SA.FeatureBinds) >= 7, "feature keybind registry size")
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
ok(type(SA.ListProfiles()) == "table", "profile list state")

-- ── self-check state API ───────────────────────────────────────────
local report = SA.SelfCheck()
ok(type(report.checks) == "table", "self-check table")
ok(#report.checks >= 30, "self-check breadth")
eq(report.failed, 0, "self-check failures")
ok(report.passed >= 25, "self-check passes")
ok(type(SA.SelfCheckState()) == "table", "self-check state")
ok(type(SA.DrawWriteFailures()) == "table", "draw write failures state")
eq(SA.SelfCheckState().failed, 0, "cached self-check report has no failures")
eq(type(SA.ShowSelfCheck), "nil", "no self-check panel API")
eq(type(SA.HideSelfCheck), "nil", "no self-check hide API")
eq(type(SA.DisposeSelfCheckPanel), "nil", "no self-check panel dispose API")
eq(gethui():FindFirstChild("HanamiSelfCheck"), nil, "no self-check panel GUI")

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

-- Force Head is shipped ON; explicitly disable it for the classic
-- per-weapon bone regression checks, then restore the default.
CFG.forceHead = false
CFG.targetBone = "Hrp"
CFG.targetBoneMode = "Global"
eq(SA.ResolveTargetBone(), "Hrp", "global bone")
CFG.targetBoneMode = "Head for snipers"
local resolvedBone = SA.ResolveTargetBone()
ok(resolvedBone == "Head" or resolvedBone == "Hrp", "per-weapon bone resolves")
CFG.targetBoneMode = "Global"
CFG.forceHead = true

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

-- ── manipulation crosshair popup ────────────────────────────────────
setFlags({
    masterEnabled = true, gunEnabled = true, manipulation = true,
    showManipPopup = true, manipMaxParts = 3,
})
MOCK_MANIP_BLOCKED = false
local okClear, clearReason, clearInfo = SA.ManipPossible()
eq(okClear, true, "clear-line manipulation possible")
contains(clearReason, "clear", "clear-line reason")
eq(clearInfo.clear, true, "clear-line probe info")
quiet(function() SA.ManipPopupRefresh() end)
local popup = SA.ManipPopupState()
eq(popup.enabled, true, "manip popup enabled")
eq(popup.built, true, "manip popup built")
eq(popup.visible, true, "manip popup visible")
eq(popup.possible, true, "manip popup READY")
contains(popup.text, "MANIP", "manip popup label")
contains(popup.text, "READY", "manip popup READY text")

MOCK_MANIP_BLOCKED = true
setFlags({ manipMaxParts = 0 })
local okBlocked, blockedReason = SA.ManipPossible()
eq(okBlocked, false, "wall-blocked manipulation impossible")
contains(blockedReason, "wall blocked", "wall-blocked reason")
quiet(function() SA.ManipPopupRefresh() end)
popup = SA.ManipPopupState()
eq(popup.possible, false, "manip popup BLOCKED")
contains(popup.text, "BLOCKED", "manip popup BLOCKED text")

setFlags({ manipMaxParts = 3 })
local okBypass, bypassReason = SA.ManipPossible()
eq(okBypass, true, "wall-bypass manipulation possible")
contains(bypassReason, "wall bypass", "wall-bypass reason")
quiet(function() SA.ManipPopupRefresh() end)
eq(SA.ManipPopupState().possible, true, "manip popup bypass READY")

quiet(function() SA.ManipPopupSet(false) end)
eq(SA.ManipPopupState().visible, false, "manip popup hidden when disabled")
quiet(function() SA.ManipPopupSet(true) end)
eq(SA.ManipPopupState().visible, true, "manip popup re-enabled")
MOCK_MANIP_BLOCKED = false

-- ── NPC manipulation support ────────────────────────────────────────
-- NPC targets use the SAME classic peek / CanQuery engine. The NPC
-- classifier must prefer the shared registry but never confuse a real
-- player character with an NPC model.
local npcForManip = SA.GetNpcs()[1]
local playerForManip = Players:GetPlayers()[2].Character
ok(npcForManip ~= nil, "NPC fixture available")
eq(SA.IsNpcModel(npcForManip), true, "registry model classified as NPC")
eq(SA.IsNpcModel(playerForManip), false, "player character NOT classified as NPC")
local npcManipState = SA.ManipNpcState()
eq(npcManipState.enabled, false, "NPC manipulation default OFF")
eq(npcManipState.targeting, false, "NPC targeting default OFF")
ok(npcManipState.count >= 1, "NPC manipulation sees registry count")
eq(type(SA.ManipNpcState), "function", "NPC manipulation state API")

local savedMouseLocation = UserInputService.GetMouseLocation
local savedTargetPriority = CFG.targetPriority
local savedTargetBoneMode = CFG.targetBoneMode
local savedTargetBone = CFG.targetBone
local savedPrediction = CFG.prediction
local savedHitChance = CFG.hitChance
local savedDistance = CFG.distance
local savedTeamCheck = CFG.teamCheck
local savedWallCheck = CFG.wallCheck
local savedFireWallCheck = CFG.fireWallCheck
local savedFov = CFG.fov
local savedFovCentre = CFG.fovCenterMode
local savedTargetNpcs = CFG.targetNpcs
local savedManipNpcs = CFG.manipNpcs
setFlags({
    masterEnabled = true, gunEnabled = true, manipulation = true,
    targetNpcs = true, manipNpcs = true, showManipPopup = true,
    targetPriority = "Crosshair", targetBoneMode = "Global", targetBone = "Head",
    prediction = false, hitChance = 100, distance = 0,
    teamCheck = false, wallCheck = false, fov = 150,
    fovCenterMode = "Mouse", manipMaxParts = 3,
})

-- Explicit override: probe one NPC even when another player is closer to
-- the crosshair. This is a read-only probe; it must not change CanQuery.
local okNpcClear, npcClearReason, npcClearInfo = SA.ManipPossible(npcForManip)
eq(okNpcClear, true, "clear-line NPC manipulation possible")
contains(npcClearReason, "[NPC]", "NPC clear-line reason tagged")
contains(npcClearReason, "clear", "NPC clear-line reason")
eq(npcClearInfo.npc, true, "NPC probe info flags NPC")
eq(npcClearInfo.npcEnabled, true, "NPC probe info enabled")
eq(npcClearInfo.targetingNpcs, true, "NPC probe info targeting")
eq(npcClearInfo.model, "Guard", "NPC probe target name")
eq(npcClearInfo.clear, true, "NPC clear-line probe info")

setFlags({ manipNpcs = false })
local okNpcOff, npcOffReason, npcOffInfo = SA.ManipPossible(npcForManip)
eq(okNpcOff, false, "NPC manipulation toggle disables NPC probe")
contains(npcOffReason, "NPC manipulation OFF", "NPC manipulation OFF reason")
eq(npcOffInfo.npcEnabled, false, "NPC probe info disabled")
eq(SA.ManipNpcState().enabled, false, "NPC manipulation state disabled")

setFlags({ manipNpcs = true, targetNpcs = false })
local okNpcNoTarget, npcNoTargetReason = SA.ManipPossible(npcForManip)
eq(okNpcNoTarget, false, "Target NPCs OFF disables NPC manipulation")
contains(npcNoTargetReason, "NPC targeting OFF", "NPC targeting OFF reason")
setFlags({ targetNpcs = true })

MOCK_MANIP_BLOCKED = true
setFlags({ manipMaxParts = 0 })
local okNpcBlocked, npcBlockedReason, npcBlockedInfo = SA.ManipPossible(npcForManip)
eq(okNpcBlocked, false, "wall-blocked NPC manipulation impossible")
contains(npcBlockedReason, "wall blocked", "NPC wall-blocked reason")
contains(npcBlockedReason, "[NPC]", "NPC wall-blocked reason tagged")
eq(npcBlockedInfo.npc, true, "NPC wall-blocked info flags NPC")
setFlags({ manipMaxParts = 3 })
local okNpcBypass, npcBypassReason, npcBypassInfo = SA.ManipPossible(npcForManip)
eq(okNpcBypass, true, "wall-bypass NPC manipulation possible")
contains(npcBypassReason, "wall bypass", "NPC wall-bypass reason")
contains(npcBypassReason, "[NPC]", "NPC wall-bypass reason tagged")
eq(npcBypassInfo.npc, true, "NPC wall-bypass info flags NPC")
MOCK_MANIP_BLOCKED = false

-- The live shot resolver must also accept an NPC model. Pin one NPC and
-- verify SA.ResolveShot() marks it as the last manipulated target.
local npcBone = npcForManip:FindFirstChild("Head")
ok(npcBone ~= nil, "NPC has Head bone")
SA.PinnedTarget = {
    model = npcForManip, bone = npcBone,
    pos = npcBone.Position, name = npcForManip.Name,
}
CFG.targetPriority = "Pinned"
quiet(function() mock_frame(0.016) end)
local npcShot = SA.ResolveShot()
ok(npcShot ~= nil, "pinned NPC shot resolved")
eq(npcShot.model, npcForManip, "shot target is the NPC model")
eq(SA.ManipState().lastNpc, true, "real resolver recorded NPC target")
SA.PinnedTarget = nil

-- The crosshair popup must label an NPC when the NPC is the FOV pick.
-- Aim the mock mouse exactly at the Guard head; other players remain in
-- FOV but are further from that reference point.
UserInputService.GetMouseLocation = function() return Vector2.new(642, 345) end
quiet(function() SA.ManipPopupRefresh() end)
local npcPopup = SA.ManipPopupState()
eq(npcPopup.npc, true, "manip popup identifies NPC target")
eq(npcPopup.target, "Guard", "manip popup NPC target name")
contains(npcPopup.text, "MANIP NPC", "manip popup NPC label")
contains(npcPopup.text, "READY", "manip popup NPC READY")
UserInputService.GetMouseLocation = nil -- fall back to the mock centre

CFG.targetPriority = savedTargetPriority
CFG.targetBoneMode = savedTargetBoneMode
CFG.targetBone = savedTargetBone
CFG.prediction = savedPrediction
CFG.hitChance = savedHitChance
CFG.distance = savedDistance
CFG.teamCheck = savedTeamCheck
CFG.wallCheck = savedWallCheck
CFG.fireWallCheck = savedFireWallCheck
CFG.fov = savedFov
CFG.fovCenterMode = savedFovCentre
CFG.targetNpcs = savedTargetNpcs
CFG.manipNpcs = savedManipNpcs
if savedMouseLocation ~= nil then
    UserInputService.GetMouseLocation = savedMouseLocation
end

-- ── crate ESP FOV-aware / 100 m warning / fire assist / Force Head ──
local savedFov = CFG.fov
local savedFovCentre = CFG.fovCenterMode
local savedPrediction = CFG.prediction
local savedCrateEnabled = CFG.crateEnabled
local savedCrateFov = CFG.crateFovAware
local savedCrateMilitary = CFG.crateShowMilitary
local savedCrateElite = CFG.crateShowElite
local savedCrateLoot = CFG.crateShowLoot
local savedCrateOpened = CFG.crateShowOpened
local savedCrateLoose = CFG.crateLooseDetect
local savedWarning = CFG.showPlayerWarning
local savedForceHead = CFG.forceHead
local savedTargetBone = CFG.targetBone
local savedBoneMode = CFG.targetBoneMode
local savedTargetNpcs = CFG.targetNpcs
local savedTeamCheck = CFG.teamCheck
local savedWallCheck = CFG.wallCheck
local savedPriority = CFG.targetPriority
local savedDistance = CFG.distance
local savedHitChance = CFG.hitChance
local savedCooldown = CFG.gunCooldown
local savedManip = CFG.manipulation
local savedMasterEnabled = CFG.masterEnabled
local savedGunEnabled = CFG.gunEnabled
local savedTriggerbot = CFG.triggerbot
local savedAutoFire = CFG.autoFire
local savedHeadOnly = CFG.triggerHeadOnly
local savedRandomPart = CFG.triggerRandomPart
local savedTriggerPart = CFG.triggerPart
local savedManipSupport = CFG.triggerUseManip
local savedPerfMode = CFG.perfMode

CFG.perfMode = false
CFG.crateEnabled = true
CFG.crateFovAware = true
CFG.crateShowMilitary, CFG.crateShowElite = true, true
CFG.crateShowLoot, CFG.crateShowOpened = true, true
CFG.crateLooseDetect = true
CFG.crateMaxDist = 3000
CFG.fovCenterMode = "Mouse"
CFG.fov = 1
UserInputService.GetMouseLocation = function() return Vector2.new(700, 360) end
MOCK_MANIP_BLOCKED = false
frameTimes(6)
local crateOut = SA.CrateFovState()
eq(crateOut.enabled, true, "crate FOV mode enabled")
ok(crateOut.outside >= 1, "crate outside FOV counted")
ok(crateOut.dots >= 1, "outside-FOV crate dot drawn")
eq(crateOut.inside, 0, "no in-FOV crate labels at radius 1")
eq(crateOut.highlights, 0, "no outline highlight outside FOV")

CFG.fov = 500
frameTimes(6)
local crateIn = SA.CrateFovState()
ok(crateIn.inside >= 1, "crate inside FOV counted")
ok(crateIn.highlights >= 1, "in-FOV crate outline highlight enabled")
eq(crateIn.outside, 0, "no outside-FOV crates at wide radius")
eq(crateIn.dots, 0, "no outside-FOV dot at wide radius")

CFG.showPlayerWarning = true
quiet(function() SA.PlayerWarningRefresh() end)
local warning = SA.PlayerWarningState()
eq(warning.enabled, true, "100m player warning enabled")
eq(warning.threshold, 100, "fixed 100m warning threshold")
eq(warning.visible, true, "near player triggers warning")
contains(warning.text, "WARNING", "warning popup label")
contains(warning.text, "100m", "warning popup threshold label")
ok(warning.meters ~= nil and warning.meters <= 100,
    "warning nearest distance within 100m")
quiet(function() SA.PlayerWarningSet(false) end)
eq(SA.PlayerWarningState().visible, false, "warning hidden when disabled")
quiet(function() SA.PlayerWarningSet(true) end)
eq(SA.PlayerWarningState().visible, true, "warning restored")
UserInputService.GetMouseLocation = nil

CFG.forceHead = true
CFG.targetBone = "Hrp"
CFG.targetBoneMode = "Hrp for shotguns"
eq(SA.ResolveTargetBone(), "Head", "Force Head overrides per-weapon Hrp")
eq(SA.ForceHeadState().resolved, "Head", "Force Head state resolves Head")
eq(SA.SilentAimState().forceHead, true, "silent aim reports Force Head")
CFG.forceHead = false
CFG.targetBoneMode = "Global"
CFG.targetBone = "Hrp"
eq(SA.ResolveTargetBone(), "Hrp", "Force Head OFF restores Target Bone")
CFG.forceHead = true

-- ── Fust bow: hookfunction, ballistic rewrite, peek-origin wallbang ──
local savedFust = {
    enabled = CFG.fustBowEnabled, fov = CFG.fustBowFov,
    targetPart = CFG.fustBowTargetPart,
    manipulation = CFG.fustBowManipulation,
    peek = CFG.fustBowManipPeek, maxDist = CFG.fustBowManipMaxDist,
    originRadius = CFG.fustBowOriginRadius,
    toolId = MOCK_FUST_TOOL:GetAttribute("ItemId"),
}
mock_fust_reset()
eq(SA.FustBowState().enabled, false, "Fust bow default OFF")
eq(SA.FustBowState().hooked, true, "hookfunction installed on Shoot.FireServer")
eq(SA.FustBowState().method, "hookfunction on Shoot.FireServer", "hook method")
eq(SA.FustBowState().scope, "Fust bows only (players)", "bow-only scope")
eq(SA.FustBowState().bows, 6, "three Fust bow specs + ItemId aliases")
near(SA.FustBowState().arrowLife, 4.5, 0.001, "arrow life")
eq(SA.FustBowState().errors, 0, "no intercept errors")
ok(MOCK_FUST_SHOOT.FireServer ~= fireServerOriginal,
    "hookfunction replaced FireServer")

local fustCam = Vector3.new(0, 3, 0)
local shots0 = SA.FustBowState().shots
local rewrites0 = SA.FustBowState().rewrites
local peeks0 = SA.FustBowState().peeks
MOCK_FUST_TOOL:SetAttribute("ItemId", "hunting_bow")

-- OFF: the hook forwards untouched arguments.
MOCK_FUST_SHOOT:FireServer(fustCam, Vector3.new(0, 0, 220))
eq(SA.FustBowState().shots, shots0 + 1, "one shot forwarded while OFF")
eq(MOCK_FUST_LAST_ARGS[1], fustCam, "origin untouched while OFF")
eq(MOCK_FUST_LAST_ARGS[2].Z, 220, "velocity untouched while OFF")
eq(SA.FustBowState().rewrites, rewrites0, "no rewrite while OFF")

-- ON with a clear line: gravity-compensated velocity rewrite only.
setFlags({ fustBowEnabled = true, fustBowManipulation = false })
MOCK_FUST_BLOCKED = false
MOCK_FUST_SHOOT:FireServer(fustCam, Vector3.new(0, 0, 220))
eq(SA.FustBowState().shots, shots0 + 2, "shot forwarded while ON")
eq(SA.FustBowState().rewrites, rewrites0 + 1, "ballistic velocity rewrite")
eq(SA.FustBowState().peeks, peeks0, "no peek with clear LOS")
eq(SA.FustBowState().lastBow, "hunting_bow", "hunting bow spec")
eq(SA.FustBowState().lastSpeed, 220, "speed from velocity argument")
eq(SA.FustBowState().lastGravity, 50, "hunting bow gravity")
near(MOCK_FUST_LAST_ARGS[2].Magnitude, 220, 0.001, "rewrite keeps arrow speed")
ok(MOCK_FUST_LAST_ARGS[2].Z < 1, "rewrite aims at the target, not -Z")
eq(MOCK_FUST_LAST_ARGS[1], fustCam, "origin untouched without wallbang")

-- Behind cover: 8-direction peek rewrites velocity AND the near-camera origin.
MOCK_FUST_BLOCKED = true
setFlags({ fustBowManipulation = true })
MOCK_FUST_SHOOT:FireServer(fustCam, Vector3.new(0, 0, 220))
eq(SA.FustBowState().rewrites, rewrites0 + 2, "wallbang still rewrites velocity")
eq(SA.FustBowState().peeks, peeks0 + 1, "peek origin rewrite")
ok(SA.FustBowState().lastPeek > 0, "peek distance reported")
ok(MOCK_FUST_LAST_ARGS[1] ~= fustCam, "origin moved to the peek")
near((MOCK_FUST_LAST_ARGS[1] - fustCam).Magnitude, 0.5, 0.001,
    "first clear peek is 0.5 studs")
eq(SA.FustBowState().lastReason, "velocity + peek origin", "state reason")

-- Manipulation OFF behind cover: LOS gate leaves the shot untouched.
setFlags({ fustBowManipulation = false })
MOCK_FUST_SHOOT:FireServer(fustCam, Vector3.new(0, 0, 220))
eq(SA.FustBowState().rewrites, rewrites0 + 2, "no rewrite without LOS")
eq(SA.FustBowState().peeks, peeks0 + 1, "no peek without manipulation")

-- No Fust bow equipped: guns are never rewritten by this hook.
MOCK_FUST_TOOL:SetAttribute("ItemId", nil)
setFlags({ fustBowManipulation = true })
MOCK_FUST_BLOCKED = false
MOCK_FUST_SHOOT:FireServer(fustCam, Vector3.new(0, 0, 220))
eq(SA.FustBowState().rewrites, rewrites0 + 2, "no rewrite without a Fust bow")
eq(MOCK_FUST_LAST_ARGS[2].Z, 220, "velocity untouched without a bow")

-- Crossbow spec and a velocity-only call (no near-camera origin argument).
MOCK_FUST_TOOL:SetAttribute("ItemId", "crossbow")
MOCK_FUST_BLOCKED = true
MOCK_FUST_SHOOT:FireServer(Vector3.new(0, 0, 320))
eq(SA.FustBowState().lastBow, "crossbow", "crossbow spec")
eq(SA.FustBowState().lastGravity, 28, "crossbow gravity")
eq(SA.FustBowState().lastSpeed, 320, "crossbow speed")
eq(SA.FustBowState().peeks, peeks0 + 1, "no origin argument to rewrite")
eq(MOCK_FUST_LAST_ARGS.n, 1, "velocity-only arguments forwarded")

-- Config knobs: FOV, target part, peek range, clear-LOS and generation.
eq(SA.FustBowState().generation, SA.Generation, "hook is generation-guarded")
eq(SA.FustBowState().reason, "active", "hook reports active reason")
MOCK_FUST_BLOCKED = false
local extra0 = SA.FustBowState().rewrites
setFlags({ fustBowFov = 50, fustBowTargetPart = "HumanoidRootPart" })
eq(SA.FustBowState().fov, 50, "FOV is configurable")
eq(SA.FustBowState().targetPart, "HumanoidRootPart",
    "target part is configurable")
MOCK_FUST_SHOOT:FireServer(fustCam, Vector3.new(0, 0, 220))
eq(SA.FustBowState().rewrites, extra0 + 1, "Hrp target still rewrites")
setFlags({ fustBowFov = 1 })
MOCK_FUST_SHOOT:FireServer(fustCam, Vector3.new(0, 0, 220))
eq(SA.FustBowState().rewrites, extra0 + 1,
    "FOV gate declines an off-screen target")
setFlags({ fustBowFov = 400, fustBowTargetPart = "Head" })
setFlags({ fustBowManipMaxDist = 1 })
MOCK_FUST_BLOCKED = true
MOCK_FUST_SHOOT:FireServer(fustCam, Vector3.new(0, 0, 220))
eq(SA.FustBowState().peeks, peeks0 + 1, "max peek distance gate")
setFlags({ fustBowManipMaxDist = 60 })
MOCK_FUST_BLOCKED = false
MOCK_FUST_SHOOT:FireServer(fustCam, Vector3.new(0, 0, 220))
eq(SA.FustBowState().peeks, peeks0 + 1, "clear LOS needs no peek")

-- Dispose / restore / re-hook, then return to the saved settings.
eq(SA.FustBowDispose().hooked, false, "dispose marks hook inactive")
eq(MOCK_FUST_SHOOT.FireServer, fireServerOriginal,
    "dispose restores the original FireServer")
eq(SA.FustBowRestore().hooked, true, "restore re-installs the hook")
ok(MOCK_FUST_SHOOT.FireServer ~= fireServerOriginal, "hook active again")
setFlags({
    fustBowEnabled = savedFust.enabled,
    fustBowFov = savedFust.fov,
    fustBowTargetPart = savedFust.targetPart,
    fustBowManipulation = savedFust.manipulation,
    fustBowManipPeek = savedFust.peek,
    fustBowManipMaxDist = savedFust.maxDist,
    fustBowOriginRadius = savedFust.originRadius,
})
MOCK_FUST_TOOL:SetAttribute("ItemId", savedFust.toolId)
mock_fust_reset()

CFG.fovCenterMode = "Mouse"
CFG.fov = 150
CFG.targetNpcs = false
CFG.teamCheck = false
CFG.wallCheck = true
CFG.fireWallCheck = true
CFG.prediction = false
CFG.distance = 0
CFG.hitChance = 100
CFG.gunCooldown = 0
CFG.targetPriority = "Crosshair"
CFG.masterEnabled = true
CFG.gunEnabled = true
CFG.manipulation = false
CFG.triggerbot = false
CFG.autoFire = false
CFG.triggerHeadOnly = true
CFG.triggerRandomPart = false
CFG.triggerPart = "Head"
CFG.triggerUseManip = false
MOCK_TOOL_ACTIVATE_FAIL = false
UserInputService.GetMouseLocation = function() return Vector2.new(641, 345) end
local otherModel = Players:GetPlayers()[2].Character
eq(SA.TriggerBonePart(otherModel).Name, "Head", "Head Only trigger part")
CFG.triggerHeadOnly = false
CFG.triggerPart = "UpperTorso"
eq(SA.TriggerBonePart(otherModel).Name, "UpperTorso", "specific trigger part")
CFG.triggerRandomPart = true
ok(SA.TriggerBonePart(otherModel) ~= nil, "random trigger part resolves")
CFG.triggerHeadOnly = true
CFG.triggerRandomPart = false
CFG.triggerPart = "Head"
mock_advance_time(0.2)
local triggerTarget = SA.TriggerTarget()
ok(triggerTarget ~= nil, "triggerbot FOV target found")
eq(triggerTarget.model, otherModel, "triggerbot target model")
eq(triggerTarget.part, "Head", "triggerbot uses Head Only part")
eq(triggerTarget.visible, true, "VIS player in FOV passes trigger LOS")

MOCK_FIRE_TOOL = 0
MOCK_FIRE_MOUSE_CLICKS = 0
MOCK_MOUSE_FAIL = false
MOCK_FIRE_MOUSE = 0
MOCK_TOOL_ACTIVATE_FAIL = false
local okDirectFire, directBackend = SA.FireOnce()
eq(okDirectFire, true, "direct Tool:Activate fire")
eq(directBackend, "tool", "Tool:Activate is primary backend")
ok(MOCK_FIRE_TOOL >= 1, "Tool:Activate backend called")
eq(MOCK_FIRE_MOUSE_CLICKS, 0, "mouse input not used when Tool works")

-- Regression: a VIS player in FOV must fire even with silent aim OFF.
CFG.masterEnabled = false
CFG.gunEnabled = false
CFG.triggerbot = true
CFG.autoFire = false
CFG.triggerUseManip = false
CFG.manipulation = false
CFG.wallCheck = true
CFG.fireWallCheck = true
mock_advance_time(0.2)
local shotsBefore = SA.FireAssistState().shots
eq(SA.FireAssistTick(true), true, "VIS FOV triggerbot fires with silent aim OFF")
local afterTrigger = SA.FireAssistState()
eq(afterTrigger.shots, shotsBefore + 1, "triggerbot shot count")
eq(afterTrigger.backend, "tool", "triggerbot Tool-first backend")
eq(afterTrigger.partUsed, "Head", "triggerbot used Head part")
eq(afterTrigger.visible, true, "triggerbot reports VIS target")
eq(afterTrigger.silentAimIndependent, true, "fire assist independent of silent aim")
contains(afterTrigger.reason, "fired", "triggerbot success reason")

-- Manipulation Support must also work without the silent-aim master/gun gate.
CFG.triggerUseManip = true
CFG.manipulation = true
CFG.fireWallCheck = true
MOCK_MANIP_BLOCKED = false
mock_advance_time(0.2)
local okNoAimProbe, noAimReason = SA.ManipPossible(otherModel, true)
eq(okNoAimProbe, true, "manip probe allowNoAim with silent aim OFF: " .. tostring(noAimReason))
eq(SA.FireAssistTick(true), true, "manip support fires with silent aim OFF")
contains(SA.FireAssistState().reason, "fired", "manip support fired")

-- Wall check always wins: Manipulation Support can no longer bypass it.
CFG.triggerbot = true
CFG.autoFire = false
CFG.triggerUseManip = true
CFG.manipulation = true
CFG.fireWallCheck = true
MOCK_MANIP_BLOCKED = true
mock_advance_time(0.2)
local shotsBeforeWall = SA.FireAssistState().shots
eq(SA.FireAssistTick(true), false, "manip support cannot bypass fire wall check")
eq(SA.FireAssistState().shots, shotsBeforeWall, "no shot through wall with manip support")
contains(SA.FireAssistState().reason, "VIS", "manip bypass wall-gated reason")

-- The dedicated gate is independent of silent aim's global wallCheck.
CFG.wallCheck = false
CFG.triggerbot = true
CFG.autoFire = false
CFG.triggerUseManip = false
CFG.manipulation = false
CFG.fireWallCheck = true
MOCK_MANIP_BLOCKED = true
mock_advance_time(0.2)
local shotsGlobalOff = SA.FireAssistState().shots
eq(SA.FireAssistTick(true), false, "fire wall check stays ON when global wallCheck is OFF")
eq(SA.FireAssistState().shots, shotsGlobalOff, "no shot when global wallCheck is OFF")
contains(SA.FireAssistState().reason, "VIS", "dedicated wall check reason")
CFG.wallCheck = true

-- Auto Fire + Manipulation Support also cannot bypass a non-VIS wall.
CFG.triggerbot = false
CFG.autoFire = true
CFG.triggerUseManip = true
CFG.manipulation = true
CFG.fireWallCheck = true
MOCK_MANIP_BLOCKED = true
mock_advance_time(0.2)
local shotsAutoManip = SA.FireAssistState().shots
eq(SA.FireAssistTick(true), false, "auto fire + manip cannot bypass fire wall check")
eq(SA.FireAssistState().shots, shotsAutoManip, "no auto fire shot with manip through wall")
contains(SA.FireAssistState().reason, "VIS", "auto fire manip wall-gated reason")
MOCK_MANIP_BLOCKED = false
mock_advance_time(0.2)

-- Auto Fire stays no-target only while the dedicated wall check is OFF.
CFG.triggerbot = false
CFG.autoFire = true
CFG.triggerUseManip = false
CFG.manipulation = false
CFG.fireWallCheck = false
mock_advance_time(0.2)
local shotsBeforeAuto = SA.FireAssistState().shots
eq(SA.FireAssistTick(true), true, "auto fire continuous click 1")
eq(SA.FireAssistTick(true), true, "auto fire continuous click 2")
eq(SA.FireAssistState().shots, shotsBeforeAuto + 2, "auto fire shot count")
eq(SA.FireAssistState().target, nil, "auto fire needs no target")

-- Dedicated fire-assist wall check: Auto Fire is VIS-target-gated, with
-- no camera snap / aim point added.
CFG.fireWallCheck = true
MOCK_MANIP_BLOCKED = false
mock_advance_time(0.2)
local camBeforeWall = ws.CurrentCamera.CFrame
local shotsBeforeGated = SA.FireAssistState().shots
eq(SA.FireAssistTick(true), true, "auto fire wall check fires on VIS target")
local gated = SA.FireAssistState()
eq(gated.shots, shotsBeforeGated + 1, "auto fire wall check shot count")
eq(gated.visible, true, "auto fire wall check reports VIS")
ok(gated.target ~= nil, "auto fire wall check gates on a target")
eq(gated.wallCheck, true, "fire assist state reports wall check")
eq(gated.autoFireGated, true, "auto fire is target-gated")
eq(ws.CurrentCamera.CFrame, camBeforeWall, "auto fire wall check adds no camera snap")

MOCK_MANIP_BLOCKED = true
mock_advance_time(0.2)
local shotsBeforeBlocked = SA.FireAssistState().shots
eq(SA.FireAssistTick(true), false, "auto fire wall check blocks non-VIS target")
eq(SA.FireAssistState().shots, shotsBeforeBlocked, "no auto fire shot through wall")
contains(SA.FireAssistState().reason, "VIS", "auto fire wall-gated reason")
MOCK_MANIP_BLOCKED = false
mock_advance_time(0.2)

-- Both enabled: Auto Fire wins (continuous / no-target) with wall check OFF,
-- and the VIS target gate applies again with wall check ON.
CFG.triggerbot = true
CFG.autoFire = true
CFG.fireWallCheck = false
CFG.triggerUseManip = false
CFG.manipulation = false
MOCK_MANIP_BLOCKED = false
mock_advance_time(0.2)
local shotsBoth = SA.FireAssistState().shots
eq(SA.FireAssistTick(true), true, "both enabled: auto fire wins")
eq(SA.FireAssistState().shots, shotsBoth + 1, "both enabled shot count")
eq(SA.FireAssistState().target, nil, "both enabled with wall check OFF needs no target")
eq(SA.FireAssistState().autoFireGated, false, "both enabled auto fire not gated")

CFG.fireWallCheck = true
MOCK_MANIP_BLOCKED = false
mock_advance_time(0.2)
local shotsBothWall = SA.FireAssistState().shots
eq(SA.FireAssistTick(true), true, "both enabled with wall check ON gates on VIS target")
eq(SA.FireAssistState().shots, shotsBothWall + 1, "both enabled wall check shot count")
ok(SA.FireAssistState().target ~= nil, "both enabled wall check reports target")
eq(SA.FireAssistState().autoFireGated, true, "both enabled auto fire gated")

-- Triggerbot with wall check OFF still allows wall-pen shots and reports
-- the non-VIS state honestly.
CFG.triggerbot = true
CFG.autoFire = false
CFG.fireWallCheck = false
CFG.triggerUseManip = false
CFG.manipulation = false
MOCK_MANIP_BLOCKED = true
mock_advance_time(0.2)
local shotsWallOff = SA.FireAssistState().shots
eq(SA.FireAssistTick(true), true, "triggerbot wall check OFF fires through wall")
eq(SA.FireAssistState().shots, shotsWallOff + 1, "wall-pen triggerbot shot count")
eq(SA.FireAssistState().visible, false, "reports non-VIS target")
eq(SA.FireAssistState().wallCheck, false, "state reports wall check OFF")
MOCK_MANIP_BLOCKED = false
mock_advance_time(0.2)

-- Backend fallbacks: mouse1click, then mouse1press/release when it is
-- absent, and clean no-backend failure when every backend fails.
MOCK_TOOL_ACTIVATE_FAIL = true
MOCK_MOUSE_FAIL = false
local savedMouse1Click = mouse1click
local clicksBefore = MOCK_FIRE_MOUSE_CLICKS
local okClickFallback, clickBackend = SA.FireOnce()
eq(okClickFallback, true, "mouse1click fallback fires")
eq(clickBackend, "mouse1click", "mouse1click fallback backend")
ok(MOCK_FIRE_MOUSE_CLICKS > clicksBefore, "mouse1click fallback called")
_G.mouse1click = nil
local mouseBefore = MOCK_FIRE_MOUSE
local okPressFallback, pressBackend = SA.FireOnce()
eq(okPressFallback, true, "mouse1press fallback fires")
eq(pressBackend, "mouse", "mouse1press/release backend")
ok(MOCK_FIRE_MOUSE > mouseBefore, "mouse1press fallback called")
_G.mouse1click = savedMouse1Click
MOCK_MOUSE_FAIL = true
local okNoBackend, noBackend = SA.FireOnce()
eq(okNoBackend, false, "no fire backend fails cleanly")
eq(noBackend, "no fire backend", "no-backend reason")
MOCK_TOOL_ACTIVATE_FAIL = false
MOCK_MOUSE_FAIL = false

-- Restore shipped defaults / earlier test state.
UserInputService.GetMouseLocation = nil
CFG.fov = savedFov
CFG.fovCenterMode = savedFovCentre
CFG.prediction = savedPrediction
CFG.crateEnabled = savedCrateEnabled
CFG.crateFovAware = savedCrateFov
CFG.crateShowMilitary = savedCrateMilitary
CFG.crateShowElite = savedCrateElite
CFG.crateShowLoot = savedCrateLoot
CFG.crateShowOpened = savedCrateOpened
CFG.crateLooseDetect = savedCrateLoose
CFG.showPlayerWarning = savedWarning
CFG.forceHead = savedForceHead
CFG.targetBone = savedTargetBone
CFG.targetBoneMode = savedBoneMode
CFG.targetNpcs = savedTargetNpcs
CFG.teamCheck = savedTeamCheck
CFG.wallCheck = savedWallCheck
CFG.targetPriority = savedPriority
CFG.distance = savedDistance
CFG.hitChance = savedHitChance
CFG.gunCooldown = savedCooldown
CFG.manipulation = savedManip
CFG.masterEnabled = savedMasterEnabled
CFG.gunEnabled = savedGunEnabled
CFG.triggerbot = savedTriggerbot
CFG.autoFire = savedAutoFire
CFG.triggerHeadOnly = savedHeadOnly
CFG.triggerRandomPart = savedRandomPart
CFG.triggerPart = savedTriggerPart
CFG.triggerUseManip = savedManipSupport
CFG.perfMode = savedPerfMode
MOCK_MANIP_BLOCKED = false
MOCK_TOOL_ACTIVATE_FAIL = false
MOCK_MOUSE_FAIL = false
pcall(function() ws.CurrentCamera.CFrame = CFrame.new(0, 3, 0) end)

-- ── Hitbox Expander v2: silent, self-healing, reversible ───────────
do
    quiet(function() SA.HitboxRestore() end)
    mock_hitbox_reset()
    local plrs = Players:GetPlayers()
    local lpPlr, otherPlr, farPlr = plrs[1], plrs[2], plrs[3]
    local otherChar = otherPlr.Character
    local farChar = farPlr.Character
    local npcs = SA.GetNpcs()
    local npcChar, npcFallback = npcs[1], npcs[2]
    ok(npcChar ~= nil and npcFallback ~= nil, "two live NPC rigs in registry")
    local npcHum = npcChar:FindFirstChildOfClass("Humanoid")
    local function part(char, name) return char:FindFirstChild(name) end
    local function resetCfg()
        CFG.hitboxEnabled = false
        CFG.hitboxTarget = "Both"
        CFG.hitboxMode = "fixed"
        CFG.hitboxScale = 8
        CFG.hitboxCap = 8
        CFG.hitboxMaxDist = 300
        CFG.hitboxTeamCheck = true
        CFG.hitboxAliveOnly = true
        CFG.hitboxVisible = false
        CFG.hitboxNpcs = false  -- keep the player-only baseline counts exact
    end
    local function offFrame()
        CFG.hitboxEnabled = false
        quiet(function() mock_frame(0.016) end)
    end
    resetCfg()
    CFG.hitboxNpcs = SA.CFG_DEFAULTS.hitboxNpcs == true
    quiet(function() SA.HitboxScan() end)
    local st = SA.HitboxState()
    eq(st.enabled, false, "hitbox default OFF")
    eq(st.target, "Both", "hitbox default target")
    eq(st.mode, "fixed", "hitbox default mode")
    eq(st.scale, 8, "hitbox default scale")
    eq(st.cap, 8, "hitbox default cap")
    eq(st.maxDist, 300, "hitbox default maxDist")
    eq(st.teamCheck, true, "hitbox default teamCheck")
    eq(st.aliveOnly, true, "hitbox default aliveOnly")
    eq(st.visible, false, "hitbox default visible")
    eq(st.npcs, false, "hitbox NPC expansion default OFF")
    eq(st.npcParts, 0, "no NPC parts while OFF")
    eq(getgenv().hitbox.npcs, false, "global hitbox mirror exposes NPC toggle")
    eq(st.parts, 0, "no tracked parts while OFF")
    eq(st.accessories, 0, "no tracked accessories while OFF")
    eq(part(otherChar, "Head").Size.X, 2, "head original size while OFF")
    eq(MOCK_HITBOX_HANDLE.CanQuery, true, "accessory handle untouched while OFF")
    eq(SA.HitboxScan(), 0, "OFF scan expands nothing")
    eq(part(otherChar, "Head").Size.X, 2, "OFF scan leaves head alone")
    eq(part(npcChar, "Head").Size.X, 2, "OFF scan leaves NPC head alone")
    resetCfg()

    -- fixed / Both: both mock enemies get Head + UpperTorso + LowerTorso.
    -- NPC expansion stays OFF for these player-only baseline tests.
    CFG.hitboxEnabled = true
    local expanded = SA.HitboxScan()
    ok(expanded >= 6, "fixed Both expands six parts: " .. tostring(expanded))
    eq(part(otherChar, "Head").Size.X, 8, "fixed Head X")
    eq(part(otherChar, "Head").Size.Y, 8, "fixed Head Y")
    eq(part(otherChar, "Head").Size.Z, 8, "fixed Head Z")
    eq(part(otherChar, "UpperTorso").Size.X, 8, "fixed UpperTorso")
    eq(part(otherChar, "LowerTorso").Size.X, 8, "fixed LowerTorso")
    eq(part(farChar, "Head").Size.X, 8, "fixed far Head")
    eq(part(otherChar, "Head").CanCollide, false, "CanCollide disabled")
    eq(part(otherChar, "Head").CanTouch, false, "CanTouch disabled")
    eq(part(otherChar, "Head").CanQuery, true, "CanQuery enabled")
    eq(part(otherChar, "Head").LocalTransparencyModifier, 0, "silent by default")
    eq(MOCK_HITBOX_HANDLE.CanQuery, false, "accessory Handle silenced")
    st = SA.HitboxState()
    eq(st.parts, 6, "six originals tracked")
    eq(st.accessories, 1, "one accessory tracked")
    eq(st.sizeHooks, 6, "six Size self-heal hooks")
    eq(st.charHooks, 2, "two character ChildAdded hooks")
    ok(st.scans >= 1, "scan counter increments")

    -- Self-healing: a server Size revert is corrected instantly.
    part(otherChar, "Head").Size = Vector3.new(1, 1, 1)
    eq(part(otherChar, "Head").Size.X, 8, "Size revert instantly re-expanded")

    -- Client-only tint.
    CFG.hitboxVisible = true
    SA.HitboxScan()
    eq(part(otherChar, "Head").LocalTransparencyModifier, 0.55,
        "visible = client-only tint")
    CFG.hitboxVisible = false
    SA.HitboxScan()
    eq(part(otherChar, "Head").LocalTransparencyModifier, 0, "tint cleared")

    -- Target = Head only.
    offFrame()
    mock_hitbox_reset()
    CFG.hitboxTarget = "Head"
    CFG.hitboxEnabled = true
    SA.HitboxScan()
    eq(part(otherChar, "Head").Size.X, 8, "Head mode expands Head")
    eq(part(otherChar, "UpperTorso").Size.X, 2, "Head mode skips UpperTorso")
    eq(SA.HitboxState().parts, 2, "Head mode tracks two parts")

    -- Target = Torso (R15 UpperTorso / LowerTorso, R6 Torso if present).
    offFrame()
    mock_hitbox_reset()
    CFG.hitboxTarget = "Torso"
    CFG.hitboxEnabled = true
    SA.HitboxScan()
    eq(part(otherChar, "Head").Size.X, 2, "Torso mode skips Head")
    eq(part(otherChar, "UpperTorso").Size.X, 8, "Torso mode expands UpperTorso")
    eq(part(otherChar, "LowerTorso").Size.X, 8, "Torso mode expands LowerTorso")
    eq(SA.HitboxState().parts, 4, "Torso mode tracks four parts")

    -- Multiply mode with the safety cap: (2,1,1) x 8 -> (16,8,8) -> cap 8.
    offFrame()
    mock_hitbox_reset()
    CFG.hitboxTarget = "Both"
    CFG.hitboxMode = "multiply"
    CFG.hitboxScale = 8
    CFG.hitboxCap = 8
    CFG.hitboxEnabled = true
    SA.HitboxScan()
    eq(part(otherChar, "Head").Size.X, 8, "multiply cap X")
    eq(part(otherChar, "Head").Size.Y, 4, "multiply cap Y")
    eq(part(otherChar, "Head").Size.Z, 4, "multiply cap Z")
    -- No clamping needed when the largest axis is below the cap.
    CFG.hitboxScale = 2
    SA.HitboxScan()
    eq(part(otherChar, "Head").Size.X, 4, "multiply uncapped X")
    eq(part(otherChar, "Head").Size.Y, 2, "multiply uncapped Y")
    eq(part(otherChar, "Head").Size.Z, 2, "multiply uncapped Z")

    -- maxDist: 0 means unlimited; a small cap skips the far character.
    offFrame()
    mock_hitbox_reset()
    CFG.hitboxMode = "fixed"
    CFG.hitboxScale = 8
    CFG.hitboxMaxDist = 5
    otherChar.HumanoidRootPart.Position = Vector3.new(2, 0, 0)
    CFG.hitboxEnabled = true
    SA.HitboxScan()
    eq(part(otherChar, "Head").Size.X, 8, "near target expanded")
    eq(part(farChar, "Head").Size.X, 2, "far target skipped by maxDist")

    -- teamCheck: same Team skipped, enemy Team expanded; OFF ignores teams.
    offFrame()
    mock_hitbox_reset()
    CFG.hitboxMaxDist = 300
    lpPlr.Team = MOCK_TEAM_RED
    otherPlr.Team = MOCK_TEAM_RED
    farPlr.Team = MOCK_TEAM_BLUE
    CFG.hitboxTeamCheck = true
    CFG.hitboxEnabled = true
    SA.HitboxScan()
    eq(part(otherChar, "Head").Size.X, 2, "same Team skipped")
    eq(part(farChar, "Head").Size.X, 8, "enemy Team expanded")
    CFG.hitboxTeamCheck = false
    SA.HitboxScan()
    eq(part(otherChar, "Head").Size.X, 8, "teamCheck OFF expands teammate")

    -- aliveOnly: dead Humanoid skipped; OFF includes it.
    offFrame()
    mock_hitbox_reset()
    lpPlr.Team, otherPlr.Team, farPlr.Team = nil, nil, nil
    CFG.hitboxTeamCheck = true
    otherChar.Humanoid.Health = 0
    CFG.hitboxAliveOnly = true
    CFG.hitboxEnabled = true
    SA.HitboxScan()
    eq(part(otherChar, "Head").Size.X, 2, "dead target skipped")
    eq(part(farChar, "Head").Size.X, 8, "alive target expanded")
    CFG.hitboxAliveOnly = false
    SA.HitboxScan()
    eq(part(otherChar, "Head").Size.X, 8, "aliveOnly OFF expands dead target")

    -- OFF restores every original, disconnects hooks, leaves no globals.
    offFrame()
    eq(part(otherChar, "Head").Size.X, 2, "head size restored")
    eq(part(otherChar, "Head").CanCollide, true, "CanCollide restored")
    eq(part(otherChar, "Head").CanTouch, true, "CanTouch restored")
    eq(part(otherChar, "Head").CanQuery, true, "CanQuery restored")
    eq(part(otherChar, "Head").LocalTransparencyModifier, 0, "tint restored")
    eq(MOCK_HITBOX_HANDLE.CanQuery, true, "accessory CanQuery restored")
    eq(SA.HitboxState().parts, 0, "no tracked parts after restore")
    eq(SA.HitboxState().accessories, 0, "no tracked accessories after restore")
    eq(SA.HitboxState().sizeHooks, 0, "no Size hooks after restore")
    eq(SA.HitboxState().charHooks, 0, "no character hooks after restore")
    part(otherChar, "Head").Size = Vector3.new(3, 3, 3)
    eq(part(otherChar, "Head").Size.X, 3, "Size hook disconnected after restore")
    eq(SA.HitboxScan(), 0, "OFF scan returns zero")

    -- ── live NPC models: players stay in scope, NPC rigs join the scan ──
    offFrame()
    mock_hitbox_reset()
    resetCfg()
    eq(part(npcChar, "Head").Size.X, 2, "NPC head original size")
    eq(part(npcFallback, "HumanoidRootPart").Size.X, 2,
        "NPC fallback HRP original size")
    eq(MOCK_HITBOX_NPC_HANDLE.CanQuery, true, "NPC accessory untouched while OFF")
    eq(SA.HitboxState().npcs, false, "NPC toggle OFF for baseline")

    CFG.hitboxNpcs = true
    CFG.hitboxEnabled = true
    local withNpcs = SA.HitboxScan()
    ok(withNpcs >= 11, "players + NPC parts expanded: " .. tostring(withNpcs))
    eq(part(otherChar, "Head").Size.X, 8,
        "player hitbox still expands with NPC support ON")
    eq(part(farChar, "Head").Size.X, 8, "far player hitbox still expands")
    eq(part(npcChar, "Head").Size.X, 8, "NPC Head expands")
    eq(part(npcChar, "UpperTorso").Size.X, 8, "NPC UpperTorso expands")
    eq(part(npcChar, "LowerTorso").Size.X, 8, "NPC LowerTorso expands")
    eq(part(npcFallback, "Head").Size.X, 8, "NPC fallback Head expands")
    eq(part(npcFallback, "HumanoidRootPart").Size.X, 8,
        "NPC HRP fallback expands when no torso exists")
    eq(part(npcChar, "Head").CanCollide, false, "NPC CanCollide disabled")
    eq(part(npcChar, "Head").CanTouch, false, "NPC CanTouch disabled")
    eq(part(npcChar, "Head").CanQuery, true, "NPC CanQuery enabled")
    eq(MOCK_HITBOX_NPC_HANDLE.CanQuery, false, "NPC accessory Handle silenced")
    eq(part(npcChar, "Head").LocalTransparencyModifier, 0, "NPC silent by default")
    st = SA.HitboxState()
    eq(st.npcs, true, "state reports NPC expansion ON")
    eq(st.parts, 11, "six player parts + five NPC parts tracked")
    eq(st.npcParts, 5, "five NPC-owned parts tracked")
    eq(st.npcModels, 2, "two NPC rigs watched")
    eq(st.accessories, 2, "player + NPC accessory Handles tracked")
    eq(st.sizeHooks, 11, "eleven Size self-heal hooks")
    eq(st.charHooks, 4, "two player + two NPC ChildAdded hooks")
    part(npcChar, "Head").Size = Vector3.new(1, 1, 1)
    eq(part(npcChar, "Head").Size.X, 8, "NPC Size revert instantly re-expanded")

    -- NPC target / mode / distance / alive filters use the same controls.
    offFrame()
    mock_hitbox_reset()
    resetCfg()
    CFG.hitboxNpcs = true
    CFG.hitboxTarget = "Torso"
    CFG.hitboxEnabled = true
    SA.HitboxScan()
    eq(part(npcFallback, "Head").Size.X, 2, "Torso mode skips NPC fallback Head")
    eq(part(npcFallback, "HumanoidRootPart").Size.X, 8,
        "Torso mode expands NPC HRP fallback")

    offFrame()
    mock_hitbox_reset()
    resetCfg()
    CFG.hitboxNpcs = true
    CFG.hitboxMode = "multiply"
    CFG.hitboxScale = 8
    CFG.hitboxCap = 8
    CFG.hitboxEnabled = true
    SA.HitboxScan()
    eq(part(npcChar, "Head").Size.X, 8, "NPC multiply cap X")
    eq(part(npcChar, "Head").Size.Y, 4, "NPC multiply cap Y")

    offFrame()
    mock_hitbox_reset()
    resetCfg()
    CFG.hitboxNpcs = true
    CFG.hitboxMaxDist = 5
    otherChar.HumanoidRootPart.Position = Vector3.new(2, 0, 0)
    CFG.hitboxEnabled = true
    SA.HitboxScan()
    eq(part(otherChar, "Head").Size.X, 8, "near player still expands")
    eq(part(npcChar, "Head").Size.X, 2, "distant NPC skipped by maxDist")

    offFrame()
    mock_hitbox_reset()
    resetCfg()
    CFG.hitboxNpcs = true
    lpPlr.Team, otherPlr.Team, farPlr.Team =
        MOCK_TEAM_RED, MOCK_TEAM_RED, MOCK_TEAM_BLUE
    CFG.hitboxTeamCheck = true
    CFG.hitboxEnabled = true
    SA.HitboxScan()
    eq(part(otherChar, "Head").Size.X, 2, "same-Team player still skipped")
    eq(part(npcChar, "Head").Size.X, 8,
        "Team Check does not filter neutral NPC models")

    offFrame()
    mock_hitbox_reset()
    resetCfg()
    CFG.hitboxNpcs = true
    npcHum.Health = 0
    CFG.hitboxAliveOnly = true
    CFG.hitboxEnabled = true
    SA.HitboxScan()
    eq(part(npcChar, "Head").Size.X, 2, "dead NPC skipped by aliveOnly")
    CFG.hitboxAliveOnly = false
    SA.HitboxScan()
    eq(part(npcChar, "Head").Size.X, 8, "aliveOnly OFF expands dead NPC")

    -- Turning ONLY the NPC toggle OFF restores NPC originals/hooks while
    -- player hitboxes stay expanded.
    offFrame()
    mock_hitbox_reset()
    resetCfg()
    CFG.hitboxNpcs = true
    CFG.hitboxEnabled = true
    SA.HitboxScan()
    eq(part(npcChar, "Head").Size.X, 8, "NPC expanded before toggle OFF")
    CFG.hitboxNpcs = false
    SA.HitboxScan()
    eq(part(otherChar, "Head").Size.X, 8,
        "player hitbox survives NPC toggle OFF")
    eq(part(npcChar, "Head").Size.X, 2, "NPC size restored on toggle OFF")
    eq(part(npcFallback, "HumanoidRootPart").Size.X, 2,
        "NPC HRP fallback restored on toggle OFF")
    eq(MOCK_HITBOX_NPC_HANDLE.CanQuery, true,
        "NPC accessory restored on toggle OFF")
    eq(SA.HitboxState().npcParts, 0, "no NPC parts after toggle OFF")
    eq(SA.HitboxState().npcModels, 0, "no NPC watches after toggle OFF")
    eq(SA.HitboxState().charHooks, 2, "player hooks survive NPC toggle OFF")
    part(npcChar, "Head").Size = Vector3.new(3, 3, 3)
    eq(part(npcChar, "Head").Size.X, 3,
        "NPC Size hook disconnected on toggle OFF")

    -- Master OFF / full restore still covers both scopes.
    offFrame()
    mock_hitbox_reset()
    CFG.hitboxNpcs = true
    CFG.hitboxEnabled = true
    SA.HitboxScan()
    eq(part(npcChar, "Head").Size.X, 8, "NPC re-expanded after toggle ON")
    offFrame()
    eq(part(otherChar, "Head").Size.X, 2, "player head restored on master OFF")
    eq(part(npcChar, "Head").Size.X, 2, "NPC head restored on master OFF")
    eq(part(npcFallback, "HumanoidRootPart").Size.X, 2,
        "NPC HRP fallback restored on master OFF")
    eq(MOCK_HITBOX_HANDLE.CanQuery, true, "player accessory restored")
    eq(MOCK_HITBOX_NPC_HANDLE.CanQuery, true, "NPC accessory restored")
    st = SA.HitboxState()
    eq(st.parts, 0, "no tracked parts after NPC-aware restore")
    eq(st.npcParts, 0, "no NPC parts after NPC-aware restore")
    eq(st.npcModels, 0, "no NPC models after NPC-aware restore")
    eq(st.accessories, 0, "no accessories after NPC-aware restore")
    eq(st.sizeHooks, 0, "no Size hooks after NPC-aware restore")
    eq(st.charHooks, 0, "no character hooks after NPC-aware restore")
    part(npcChar, "Head").Size = Vector3.new(4, 4, 4)
    eq(part(npcChar, "Head").Size.X, 4,
        "NPC Size hook disconnected after master OFF")

    mock_hitbox_reset()
    resetCfg()
    CFG.hitboxNpcs = SA.CFG_DEFAULTS.hitboxNpcs == true
    quiet(function() SA.HitboxRestore() end)
end

-- ── top-N HUD / performance overlay ─────────────────────────────────
setFlags({
    nearestWindow = true,
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

-- ── clean ESP / outline-only preset ─────────────────────────────────
eq(CFG.espCleanMode, false, "clean ESP default OFF")
quiet(function() setFlag("espCleanMode", true) end)
local cleanState = SA.CleanEspState()
eq(cleanState.enabled, true, "clean state enabled")
eq(cleanState.backdrop, false, "clean hides tag backdrops")
eq(cleanState.fill, false, "clean hides chams fill")
eq(cleanState.outline, true, "clean keeps chams outline")
eq(cleanState.textOutline, true, "clean keeps text stroke")
eq(cleanState.cornerBox, false, "clean uses full box outline")
quiet(function() SA.ApplyCleanEsp() end)
eq(CFG.espTagBackdrop, false, "clean preset: no dark pills")
eq(CFG.espShowFill, false, "clean preset: no fill")
eq(CFG.espShowOutline, true, "clean preset: outline on")
eq(CFG.espCornerBox, false, "clean preset: no corner boxes")
eq(CFG.espTextOutline, true, "clean preset: text outline")
eq(CFG.espShowTracer, false, "clean preset: no tracers")
eq(CFG.espShowOffscreen, false, "clean preset: no arrows")

-- An older saved config with every busy option ON must still render clean
-- because drawEntity / preview use effective values, not raw CFG.
setFlags({
    espTagBackdrop = true, espShowFill = true, espShowOutline = false,
    espTextOutline = false, espCornerBox = true, espShowBox = false,
})
cleanState = SA.CleanEspState()
eq(cleanState.backdrop, false, "clean overrides saved backdrops")
eq(cleanState.fill, false, "clean overrides saved fill")
eq(cleanState.outline, true, "clean overrides saved outline")
eq(cleanState.box, true, "clean forces box outline")
eq(cleanState.cornerBox, false, "clean overrides corner boxes")
eq(cleanState.textOutline, true, "clean overrides text outline")
quiet(function() setFlag("espCleanMode", false) end)
eq(SA.CleanEspState().enabled, false, "clean mode can be disabled")
eq(SA.CleanEspState().backdrop, true, "busy look returns when clean off")
quiet(function() SA.ApplyCleanEsp() end)
eq(CFG.espCleanMode, true, "clean preset restored")

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
    synced = SA.SyncGunDefs()
end)
ok(type(synced) == "number" and synced > 0, "GC sync changed fields")
ok(SA.GUN_SPECS.proto_railgun ~= nil, "new-gun stub registered")
local diff2 = SA.GunDiff()
contains(table.concat(diff2.added, ","), "proto_railgun", "new-gun diff")
SA.GUN_SPECS.assault_rifle.speed = baseSpeed
SA.InvalidateGunCache()
eq(SA.GUN_SPECS.assault_rifle.speed, baseSpeed, "baseline speed restored")

-- ── ESP FPS optimization regressions ────────────────────────────────
eq(CFG.espDataRefreshMs, 100, "ESP text refresh default")
eq(SA.EspDataIntervalFrames(), 6, "100 ms refresh is 6 frames at 60 fps")
eq(SA.NpcListRaw(), _G.__saNpcList, "NPC raw list avoids per-frame copy")
eq(SA.CrateListRaw(), _G.__saCrateList, "crate raw list avoids per-frame copy")

-- A 60 FPS frame budget is active even with Performance Mode OFF. A slow
-- frame stretches text refresh and paces new ESP builds instead of adding
-- more work on top of an already expensive frame.
local budget0 = SA.EspFrameBudget()
eq(budget0.targetFps, 60, "ESP frame budget targets 60 FPS")
near(budget0.targetMs, 1000 / 60, 0.001, "16.7 ms ESP frame budget")
eq(budget0.overBudget, false, "60 FPS frame is within budget")
quiet(function() mock_frame(0.033) end)
local budget1 = SA.EspFrameBudget()
eq(budget1.overBudget, true, "30 FPS frame is over ESP budget")
ok(budget1.adaptiveDataIntervalMs > budget1.dataIntervalMs,
    "over-budget frame stretches ESP data refresh")
ok(budget1.buildIntervalMs > 0, "over-budget frame paces new ESP builds")
SA.EspFrameBudgetReset()
eq(SA.EspFrameBudget().overBudget, false, "frame budget reset returns to 60 FPS")

-- One GUI proxy with four property changes must sync exactly once, and
-- only after the render-step flush. This is the stutter fix for the
-- ScreenGui fallback backend.
SA.DrawSyncFlush()
local sync0 = SA.DrawSyncStats()
local batchDraw = SA.NewDraw("Text")
local batchLabel = batchDraw.__saTextLabel
ok(batchLabel ~= nil, "screen-space text proxy exposes text label")
eq(batchLabel.Text, "", "GUI text starts empty")
batchDraw.Text = "batch-test"
batchDraw.Position = Vector2.new(22, 33)
batchDraw.Color = Color3.new(1, 0, 0)
batchDraw.Visible = true
local sync1 = SA.DrawSyncStats()
ok(sync1.writes - sync0.writes >= 4, "four draw writes recorded")
ok(SA.DrawSyncPending() >= 1, "draw sync is deferred")
eq(batchLabel.Text, "", "GUI sync deferred until flush")
local flushed = SA.DrawSyncFlush()
ok(flushed >= 1, "draw sync flush processed proxies")
eq(batchLabel.Text, "batch-test", "coalesced sync applies final text")
eq(SA.DrawSyncPending(), 0, "no pending draws after flush")
local sync2 = SA.DrawSyncStats()
ok(sync2.flushes - sync1.flushes >= 1, "one proxy sync recorded")
ok(sync2.writes - sync0.writes > sync2.flushes - sync0.flushes,
    "fewer GUI syncs than property writes")
ok(type(sync2.instanceWrites) == "number", "per-property instance writes tracked")
ok(type(sync2.instanceSkips) == "number", "per-property instance skips tracked")
batchDraw.Remove()

-- ESP ON must style geometry every frame, but name / weapon / state /
-- BillboardGui data only at the 6-frame interval. The FX pass re-shows
-- the prebuilt lines because it now owns legacy line / chams visibility.
setFlags({
    espEnabled = true, npcEspEnabled = false, crateEnabled = false,
    espVisibleCheck = false, espShowSkeleton = false, espShowHeadDot = false,
    espShowTracer = false, espShowOffscreen = false, espFade = false,
    espOnlyNearest = false, espOnlyAimTarget = false, espTeamMode = "All",
    perfMode = false, espDataRefreshMs = 100,
    snapLineEnabled = false, showManipPopup = false,
    masterEnabled = false, gunEnabled = false,
})
frameTimes(8)
local firstEspObject = nil
for _, o in pairs(espObjects) do firstEspObject = o; break end
ok(firstEspObject ~= nil, "player ESP object built for FPS pass")
eq(firstEspObject.lines.top.Visible, true, "FX pass re-shows prebuilt box lines")
eq(firstEspObject.highlight.Enabled, true, "FX pass re-enables chams")
local perf0 = SA.EspPerfState()
mock_esp_reset()
frameTimes(12)
local perf1 = SA.EspPerfState()
eq(perf1.fxPasses - perf0.fxPasses, 12, "ESP geometry styled every frame")
ok(perf1.dataRefreshes - perf0.dataRefreshes > 0, "data refresh still runs")
ok(perf1.dataRefreshes - perf0.dataRefreshes < 12, "data refresh is throttled")
ok(perf1.dataSkips - perf0.dataSkips > 0, "data refresh frames are skipped")
ok(MOCK_W2V_CALLS <= 12 * (count(espObjects) * 4 + 4),
    "WorldToViewportPoint calls bounded by throttled refresh")
ok(type(perf1.drawSync) == "table", "ESP FPS state exposes draw sync stats")
ok(type(perf1.frameBudget) == "table", "ESP FPS state exposes frame budget")
ok(perf1.frameBudget.targetFps == 60, "frame budget stays 60 FPS with perfMode OFF")

-- Per-property instance caching + per-frame usage marks: with a static
-- camera / rig and no text refresh due, a repeated ESP frame must write
-- zero Roblox Instance / proxy properties instead of rewriting everything.
SA.EspFrameBudgetReset()
frameTimes(2)
SA.DrawSyncReset()
SA.EspFrameBudgetReset()
frameTimes(1)
local inst0 = SA.DrawSyncStats()
frameTimes(1)
local inst1 = SA.DrawSyncStats()
eq(inst1.instanceWrites - inst0.instanceWrites, 0,
    "unchanged ESP frame writes zero Instance properties")
ok(inst1.instanceSkips - inst0.instanceSkips > 0,
    "unchanged ESP properties are skipped")
eq(inst1.writes - inst0.writes, 0,
    "unchanged ESP frame writes zero draw properties")

do
-- ── Adaptive ESP geometry cache / slicing / disabled early-out ──────
-- A static camera / rig must reuse ONE projection set between the FX pass
-- and the throttled BillboardGui refresh. The camera signature is built
-- once per camera change, not once per entity per frame.
quiet(function() SA.ResetToDefaults() end)
setFlags({
    espEnabled = true, npcEspEnabled = false, crateEnabled = false,
    espVisibleCheck = false, espShowSkeleton = false, espShowHeadDot = false,
    espShowTracer = false, espShowOffscreen = false, espFade = false,
    espOnlyNearest = false, espOnlyAimTarget = false,
    espTeamMode = "Exclude Teammates", perfMode = false,
    espDataRefreshMs = 100, snapLineEnabled = false,
    showManipPopup = false, masterEnabled = false, gunEnabled = false,
})
MOCK_CAMERA.CFrame = CFrame.new(0, 3, 0)
SA.EspFrameBudgetReset()
SA.EspGeomReset()
SA.EspGeomInvalidate()
frameTimes(35) -- settle the rolling FPS estimate at 60 before measuring
SA.EspGeomReset()
SA.EspGeomInvalidate()
SA.EspFrameBudgetReset()
frameTimes(1)
local firstGeomObject = nil
for _, o in pairs(espObjects) do
    if o.geomCache then firstGeomObject = o; break end
end
ok(firstGeomObject ~= nil, "player ESP object has cached geometry")
local geomBudget = SA.EspGeometryBudget()
eq(geomBudget.stride, 1, "healthy 60 FPS frame uses no geometry slicing")
eq(geomBudget.targetFps, 60, "geometry budget targets 60 FPS")
eq(geomBudget.overBudget, false, "healthy frame is within geometry budget")
eq(type(SA.EspGeomState()), "table", "geometry state API exposed")
eq(type(SA.EspGeomState().cacheHits), "number", "geometry cache hits tracked")
eq(type(SA.EspGeomState().cameraKeyBuilds), "number",
    "camera signature builds tracked")
local g1 = firstGeomObject.geomCache
local st1 = SA.EspGeomState()
ok(st1.cacheMisses > 0, "first geometry frame populates the cache")
ok(st1.w2vCalls >= 3, "cache miss performs one 3-point projection set")
ok(st1.cameraKeyBuilds >= 1, "camera signature built once")
frameTimes(4)
local st2 = SA.EspGeomState()
eq(firstGeomObject.geomCache, g1,
    "static camera / rig reuses the same geometry table")
ok(st2.cacheHits > st1.cacheHits, "geometry cache hits accumulate")
eq(st2.w2vCalls, st1.w2vCalls,
    "static frame performs no extra WorldToViewportPoint calls")
ok(st2.savedW2vCalls > 0, "saved WorldToViewportPoint calls reported")
ok(st2.cameraKeyBuilds <= st1.cameraKeyBuilds + 1,
    "camera signature is reused across entities and frames")
local cachedG = SA.EspGeom(firstGeomObject, MOCK_CAMERA,
    firstGeomObject.root.Position, firstGeomObject.head.Position, "player")
eq(cachedG, g1, "shared projection API returns the cached geom")
local st3 = SA.EspGeomState()
ok(st3.cacheHits > st2.cacheHits, "shared API records another cache hit")
local oldCam = MOCK_CAMERA.CFrame
MOCK_CAMERA.CFrame = CFrame.new(9, 3, 0)
local movedG = SA.EspGeom(firstGeomObject, MOCK_CAMERA,
    firstGeomObject.root.Position, firstGeomObject.head.Position, "player")
ok(movedG ~= g1, "camera change invalidates the cached projection")
MOCK_CAMERA.CFrame = oldCam
SA.EspGeomInvalidate()
eq(firstGeomObject.geomCache, nil, "geometry invalidation drops cached geom")

-- Teammate map is rebuilt at the DATA interval, not on every FX frame.
SA.EspGeomReset()
SA.EspGeomInvalidate()
SA.EspFrameBudgetReset()
MOCK_GETPLAYERS_CALLS = 0
quiet(function()
    for _ = 1, 8 do SA.ApplyEspFx(MOCK_CAMERA) end
end)
local gpCalls = MOCK_GETPLAYERS_CALLS
ok(gpCalls >= 1, "non-All team filter still builds a teammate map")
ok(gpCalls <= 2, "teammate map is throttled across 8 FX frames")
local teamGeom = SA.EspGeomState()
ok(teamGeom.cacheHits > 0, "FX frames reuse the geometry cache")
ok(teamGeom.cameraKeyBuilds <= 2,
    "one camera signature serves 8 static-camera FX frames")

-- A slow frame raises geometryStride and rotates low-priority entities,
-- while the aim target / nearest set stays on the full-rate path.
SA.EspFrameBudgetReset()
quiet(function() mock_frame(0.05) end)
local slowBudget = SA.EspGeometryBudget()
eq(slowBudget.overBudget, true, "50 ms frame is over geometry budget")
ok(slowBudget.stride >= 2, "slow frame raises adaptive geometry stride")
local perfBefore = SA.EspPerfState()
quiet(function()
    for _ = 1, 4 do SA.ApplyEspFx(MOCK_CAMERA) end
end)
local perfAfter = SA.EspPerfState()
ok(perfAfter.geometrySkips > perfBefore.geometrySkips,
    "slow frame skips low-priority geometry styles")
ok(perfAfter.geometryUpdates > perfBefore.geometryUpdates,
    "rotating buckets still style some entities")
ok(perfAfter.geometryBudget.stride >= 2,
    "ESP perf state exposes the adaptive geometry stride")
ok(perfAfter.frameBudget.geometryStride >= 2,
    "frame budget exposes the adaptive geometry stride")

-- All ESP OFF must hide each object list ONCE, then early-out before the
-- aim / FOV / nearest work. The master render callback still runs normally.
setFlags({
    espEnabled = false, npcEspEnabled = false, crateEnabled = false,
})
SA.EspFrameBudgetReset()
frameTimes(1)
eq(SA.EspHiddenPass.players, true, "player hidden pass recorded")
eq(SA.EspHiddenPass.npcs, true, "NPC hidden pass recorded")
eq(SA.EspHiddenPass.crates, true, "crate hidden pass recorded")
local hide0 = SA.EspPerfState()
frameTimes(4)
local hide1 = SA.EspPerfState()
eq(hide1.geometryHiddenPasses - hide0.geometryHiddenPasses, 0,
    "disabled ESP performs no repeated hidden passes")
eq(hide1.fxPasses - hide0.fxPasses, 4,
    "disabled ESP keeps the single master FX entry alive")
quiet(function() SA.ResetToDefaults() end)
end

quiet(function() SA.ResetToDefaults() end)

quiet(function() SA.ResetToDefaults() end)

-- ── UI buttons (every callback is pcall-wrapped by the mock) ─────────
local buttonNames = {
    "Apply Best ESP", "Apply Blatant", "Apply Clean ESP",
    "Apply Overrides Now", "Apply Recommended Wall Pen", "Cancel Rebind",
    "Clear Pinned Target", "Clear Selected", "Delete Profile", "Disable All",
    "Export Config to Clipboard", "Import Config from Clipboard",
    "Load Profile", "Lock Nearest as Aim Target", "Pin Nearest Player",
    "Rebind Selected", "Rebuild Character", "Rebuild ESP Preview",
    "Rebuild Player ESP", "Refresh Manip Popup", "Refresh Nearest HUD",
    "Refresh Player Warning", "Rescan Attachments", "Rescan Characters",
    "Rescan Crates", "Rescan NPCs", "Reset ESP Colours", "Reset to Defaults",
    "Restore Bow Timings", "Restore Hitboxes", "Retry Tap Hooks",
    "Save Profile", "Set All: Hold", "Set All: Toggle",
    "Show ESP Preview Panel", "Sync Gun Defs (GC)", "Sync Gun Defs + Diff",
    "Toggle Manip",
}
for _, name in ipairs(buttonNames) do
    local fn = library.buttons[name]
    ok(type(fn) == "function", "missing UI button: " .. name)
    quiet(function() fn() end)
end
SA.CancelRebind()
SA.ClearPinnedTarget()
quiet(function()
    SA.SetAllKeybindModes("toggle")
    SA.ResetToDefaults()
    window.set_menu_visibility(true)
end)
eq(#SA.KeybindConflicts(), 0, "no conflicts after button sweep")
eq(CFG.keybindMode, "toggle", "modes restored after button sweep")

-- ── features-only regression: no print/debug UI, no console output ────
eq(CFG.debug, nil, "debug config key removed")
eq(CFG.gunDiffOnScan, nil, "print-on-sync config key removed")
eq(library.config_flags["hn_debug"], nil, "no Debug Log toggle")
eq(library.config_flags["hn_gunDiffOnScan"], nil, "no print-on-sync toggle")
local removedOutputAPIs = {
    "PrintDrawSyncStats", "PrintForceHeadState", "PrintScan",
    "PrintManipNpcState", "PrintAttachments", "PrintPrediction",
    "PrintGunSpec", "PrintGunDiff", "PrintGunOverrides", "PrintGunTable",
    "PrintFireAssist", "PlayerEspDiag", "PrintCrateStates",
    "PrintCrateCandidates", "PrintCrateFovState", "PrintEspFrameBudget",
    "PrintEspPerfState", "PrintHitbox", "FeatureBindDiag", "EspPreviewDiag",
    "EspFeatureDiag", "NearestWindowDiag", "PrintManipPopup",
    "PrintPlayerWarning", "PrintKeybindConflicts", "PrintAllKeybinds",
    "PrintProfiles", "PrintSelfCheck", "ShowSelfCheck", "HideSelfCheck",
    "DisposeSelfCheckPanel",
}
for _, name in ipairs(removedOutputAPIs) do
    eq(SA[name], nil, "removed output API: " .. name)
end
local keptStateAPIs = {
    "SelfCheck", "SelfCheckState", "FustBowState", "FustBowRefresh",
    "FustBowRestore", "FustBowDispose", "EspPerfState", "EspFrameBudget",
    "HitboxState", "HitboxScan", "HitboxRestore", "DrawSyncStats",
    "DrawSyncPending", "DrawDiag", "DrawWriteFailures", "KeybindConflicts",
    "ConfigCoverage", "SilentAimState", "FireAssistState", "ForceHeadState",
    "ManipNpcState", "CrateFovState", "PlayerWarningState",
    "ManipPopupState", "NearestWindowState", "EspPassStats", "DrawPoolStats",
    "PerfState", "GunDiff", "ApplyGunOverrides", "SyncGunDefs",
    "TestConfigRoundTrip", "EspPreviewRefresh",
    "GunState", "GunDisplayState", "GunLiveState", "GunInspectDefinition",
    "GunDefinitionReport", "GunControlReport", "GunFireScriptReport",
    "GunLiveReport", "GunShotProbeState", "GunShotProbeReport",
    "GunShotProbeFire", "GunShotProbeProcess", "GunShotProbeReset",
    "GunObservationBaseline", "GunObservationCompare",
    "GunUseDefinitionCandidate", "GunClearManualDefinition", "GunReport",
    "GunCopyReport", "GunDispose", "GunSet", "GunFrame", "GunRefresh",
    "GunScanLive", "GunRestore", "GunBindToggle", "GunBindSlider",
    "GunBindLabel", "GunBindButton",
}
for _, name in ipairs(keptStateAPIs) do
    eq(type(SA[name]), "function", "kept state API: " .. name)
end
for label in pairs(library.buttons) do
    ok(not label:find("Print", 1, true) and not label:find("Debug", 1, true)
        and not label:find("Self-Check", 1, true)
        and not label:find("Scan ", 1, true),
        "no print/debug button: " .. label)
end
local featureOutput = 0
local saved = { print = print, warn = warn }
print = function(...)
    local first = tostring(select(1, ...) or "")
    if first:find("[mock]", 1, true) or first:find("[warn]", 1, true) then
        real_print(...)
    else
        featureOutput = featureOutput + 1
    end
end
warn = function(...)
    local first = tostring(select(1, ...) or "")
    if first:find("[mock]", 1, true) or first:find("[warn]", 1, true) then
        saved.warn(...)
    else
        featureOutput = featureOutput + 1
    end
end
local silentOk, silentErr = pcall(function()
    SA.SelfCheck()
    SA.GunDiff()
    SA.ApplyGunOverrides("assault_rifle.speed=1555;typo_field=3")
    SA.SyncGunDefs()
    SA.SetAllKeybindModes("toggle")
    SA.StartRebind("hn_bind_espEnabled")
    SA.CancelRebind()
    SA.ExportConfig()
    SA.TestConfigRoundTrip()
    SA.DrawDiag()
    mock_frame(0.016)
end)
print, warn = saved.print, saved.warn
ok(silentOk, "silent feature calls: " .. tostring(silentErr))
eq(featureOutput, 0, "features emit no console output")

-- ── V16.46-style gun mods, brightness, shot probe and camera filter ──
mock_gun_reset()
if run > 1 then
    ok(SA.GunShotProbeState().trialRecovered == true,
        "same-session shot probe checkpoint restored on re-execute")
end
setFlags({
    gmEnabled = true, gunInspectGunControl = true,
    gunInspectDefs = true, gunInspectScripts = true,
    gunInspectLiveGun = true,
})
ok(SA.GunRefresh(true) == true, "forced V16.46 source refresh")
ok(SA.GunScanLive(true) == true, "forced live controller scan")
local gunState = SA.GunState()
eq(gunState.master, true, "gun mods master ON")
ok(gunState.live.scanned == true, "live controller scan cached")
contains(gunState.live.apis, "getsenv=true", "getsenv capability surfaced")
contains(gunState.live.apis, "getgc=true", "getgc capability surfaced")
contains(gunState.live.apis, "debug.getupvalues=true",
    "debug.getupvalues capability surfaced")
ok(gunState.live.gcInspected > 0, "GC objects inspected")
ok(gunState.live.closures > 0, "source-matched controller closures")
ok(gunState.live.tables > 0, "controller tables inspected")
ok(gunState.records.spread > 0, "named spread records cached")
ok(gunState.records.recoil > 0, "named recoil records cached")
ok(gunState.records.rate > 0, "named rate records cached")
ok(gunState.records.ammo > 0, "named ammo records cached")
ok(gunState.records.movement > 0, "named movement records cached")
eq(SA.GunInspectDefinition().id, "assault_rifle",
    "Fust.Items identity alias matched equipped rifle")
contains(SA.GunInspectDefinition().keys, "spread",
    "selected definition exposes spread fields")
contains(SA.GunDefinitionReport(), "UNVERIFIED",
    "definition report labels candidates UNVERIFIED")
contains(SA.GunControlReport(), "UNVERIFIED",
    "GunControl report labels fields UNVERIFIED")
contains(SA.GunFireScriptReport(), "UNVERIFIED",
    "fire-script hints report labels candidates UNVERIFIED")
contains(SA.GunLiveReport(), "UNVERIFIED",
    "live report labels shot results UNVERIFIED")
eq(type(SA.GunUseDefinitionCandidate(1)), "boolean",
    "manual definition candidate API")
eq(SA.GunClearManualDefinition(), true, "clear manual definition API")
eq(SA.GunObservationBaseline(), true, "gun-state baseline captured")
eq(SA.GunObservationCompare(), true, "gun-state comparison completed")
contains(SA.GunState().status.observationStatus, "Compared",
    "observation status is a silent state string")

-- Brightness: local ColorCorrectionEffect only, clamped and disposed.
local lighting = game:GetService("Lighting")
setFlags({ displayBrightnessEnabled = true, displayBrightness = 0.35 })
local brightnessEffect = lighting:FindFirstChild("HanamiLocalBrightness")
ok(brightnessEffect ~= nil, "local ColorCorrectionEffect created")
near(brightnessEffect.Brightness, 0.35, 0.0001,
    "brightness value applied")
eq(brightnessEffect.Contrast, 0, "brightness contrast zeroed")
eq(brightnessEffect.Saturation, 0, "brightness saturation zeroed")
eq(SA.GunDisplayState().enabled, true, "brightness state enabled")
contains(SA.GunDisplayState().kind, "ColorCorrectionEffect",
    "brightness state names the effect kind")
setFlags({ displayBrightness = 1.0 })
near(brightnessEffect.Brightness, 0.5, 0.0001,
    "brightness clamped to 0.5")
setFlags({ displayBrightnessEnabled = false })
eq(lighting:FindFirstChild("HanamiLocalBrightness"), nil,
    "brightness effect destroyed on disable")
eq(SA.GunDisplayState().effect, false, "brightness state disposed")
contains(SA.GunReport("display"), "ColorCorrectionEffect",
    "display report is a callable state string")

-- All mutable holds write only named fields and restore originals.
setFlags({ gunNoSpread = true })
eq(MOCK_GUN_LIVE.Spread, 0, "No Spread holds live spread")
eq(MOCK_GUN_CONTROL.Spread, 0, "No Spread holds GunControl spread")
eq(MOCK_GUN_ITEMS.Defs.assault_rifle.spread, 0,
    "No Spread holds selected definition spread")
eq(SA.GunState().status.noSpreadStatus, "ON (named local fields only)",
    "No Spread status is a silent state string")
setFlags({ gunNoSpread = false })
eq(MOCK_GUN_LIVE.Spread, 1.0, "No Spread restores live original")
eq(MOCK_GUN_CONTROL.Spread, 0.7, "No Spread restores GunControl original")
eq(MOCK_GUN_ITEMS.Defs.assault_rifle.spread, 1.0,
    "No Spread restores definition original")

setFlags({ gunNoRecoil = true })
eq(MOCK_GUN_LIVE.RecoilPitch, 0, "No Recoil holds named recoil")
eq(MOCK_GUN_LIVE.WeaponKick, 0, "No Recoil holds named weapon kick")
setFlags({ gunNoRecoil = false })
eq(MOCK_GUN_LIVE.RecoilPitch, 0.25, "No Recoil restores recoil original")
eq(MOCK_GUN_LIVE.WeaponKick, 0.18, "No Recoil restores kick original")

setFlags({ gunFireRateMultiplier = 2 })
setFlags({ gunFireRate = true })
near(MOCK_GUN_LIVE.FireRate, 4.0, 0.0001,
    "Fire Rate multiplier raises named rate")
near(MOCK_GUN_LIVE.FireDelay, 0.08, 0.0001,
    "Fire Rate multiplier lowers named delay")
near(MOCK_GUN_LIVE.activeProfile.rate, 0.075, 0.0001,
    "Fire Rate multiplier lowers active profile interval")
setFlags({ gunFireRate = false })
setFlags({ gunFireRateMultiplier = 1.5 })
eq(MOCK_GUN_LIVE.FireRate, 2.0, "Fire Rate restores original")
eq(MOCK_GUN_LIVE.FireDelay, 0.16, "Fire Delay restores original")
eq(MOCK_GUN_LIVE.activeProfile.rate, 0.15,
    "active profile rate restores original")

setFlags({ gunInfiniteAmmo = true })
eq(MOCK_GUN_LIVE.CurrentAmmo, 9999, "Infinite Ammo holds named counter")
eq(MOCK_GUN_LIVE.activeProfile.currentAmmo, 9999,
    "Infinite Ammo holds nested counter")
setFlags({ gunInfiniteAmmo = false })
eq(MOCK_GUN_LIVE.CurrentAmmo, 12, "Infinite Ammo restores counter")
eq(MOCK_GUN_LIVE.activeProfile.currentAmmo, 24,
    "Infinite Ammo restores nested counter")

setFlags({ gunMoveShoot = true })
eq(MOCK_GUN_LIVE.CanFireWhileSprinting, true,
    "Move Shoot holds named permission")
eq(MOCK_GUN_LIVE.activeProfile.canFireWhileSprinting, true,
    "Move Shoot holds nested permission")
setFlags({ gunMoveShoot = false })
eq(MOCK_GUN_LIVE.CanFireWhileSprinting, false,
    "Move Shoot restores permission")
eq(MOCK_GUN_LIVE.activeProfile.canFireWhileSprinting, false,
    "Move Shoot restores nested permission")

-- Experimental camera-kick filter uses the existing master render frame.
setFlags({ gunNoRecoil = true, gunCameraKickFilter = true })
MOCK_CAMERA.CFrame = CFrame.new(0, 3, 0)
quiet(function() mock_frame(0.016) end)
local correctionsBefore = SA.GunState().camera.suppressed
MOCK_CAMERA.CFrame = CFrame.fromEulerAnglesXYZ(0.4, 0, 0)
quiet(function() mock_frame(0.016) end)
ok(SA.GunState().camera.suppressed > correctionsBefore,
    "camera-kick filter corrected an upward pitch spike")
ok(SA.GunState().camera.corrections >= 1,
    "camera-kick correction counter exposed")
eq(MOCK_CAMERA.CFrame._pitch, nil,
    "camera kick restores the last good CFrame")
setFlags({ gunNoRecoil = false })
MOCK_CAMERA.CFrame = CFrame.new(0, 3, 0)

-- Visual shot probe: aim snapshot, tracer FX, directional sample, reset.
setFlags({ gunShotProbe = true })
eq(SA.GunShotProbeState().observerPaused, false,
    "shot probe observer started")
window.set_menu_visibility(false)
mock_advance_time(0.4)
local aimBefore = SA.GunShotProbeState().aimSnapshots
eq(SA.GunShotProbeFire(), true, "shot probe captured aim input")
ok(SA.GunShotProbeState().aimSnapshots > aimBefore,
    "shot probe aim snapshot counter")
local tracer = Instance.new("Part")
tracer.Name = "BulletTracer"
tracer.Position = Vector3.new(0, 3, -1)
tracer.Parent = Workspace
Workspace.DescendantAdded:Fire(tracer)
tracer.Position = Vector3.new(0, 3, -2)
SA.GunShotProbeProcess()
ok(SA.GunShotProbeState().tracerCandidates >= 1,
    "shot probe matched a tracer candidate")
ok(SA.GunShotProbeState().directionSamples >= 1,
    "shot probe recorded a visual direction sample")
contains(SA.GunShotProbeState().status, "Matched local visual tracer",
    "shot probe status is a silent UI/state string")
contains(SA.GunShotProbeReport(), "VISUAL effects only",
    "shot probe report refuses hit verification")
eq(SA.GunCopyReport("all"), true, "all gun reports copied to clipboard")
contains(getclipboard(), "VISUAL effects only",
    "clipboard report is silent and UNVERIFIED")
contains(SA.GunState().status.reportStatus, "copied",
    "copy status exposed without console output")
eq(SA.GunShotProbeReset(), true, "shot probe reset API")
eq(SA.GunShotProbeState().directionSamples, 0,
    "shot probe reset clears observations")
setFlags({ gunShotProbe = false })
eq(SA.GunShotProbeState().observerPaused, true,
    "shot probe observer paused")
window.set_menu_visibility(true)
local checkpoint = _G.HanamiGunShotProbeCheckpoint
ok(type(checkpoint) == "table", "same-session shot probe checkpoint")
eq(checkpoint.schema, "HanamiShotProbe/1", "shot probe checkpoint schema")
ok(type(checkpoint.off) == "table" and type(checkpoint.on) == "table",
    "shot probe checkpoint keeps both A/B groups")

-- SA.GunRestore restores every active cached field without dropping cache.
setFlags({
    gunNoSpread = true, gunNoRecoil = true, gunFireRate = true,
    gunInfiniteAmmo = true, gunMoveShoot = true,
})
eq(MOCK_GUN_LIVE.Spread, 0, "restore test: spread held")
ok(MOCK_GUN_LIVE.FireRate ~= 2.0, "restore test: rate held")
eq(MOCK_GUN_LIVE.CurrentAmmo, 9999, "restore test: ammo held")
eq(MOCK_GUN_LIVE.CanFireWhileSprinting, true,
    "restore test: movement held")
eq(SA.GunRestore(), true, "SA.GunRestore API")
eq(MOCK_GUN_LIVE.Spread, 1.0, "SA.GunRestore restores spread")
eq(MOCK_GUN_CONTROL.Spread, 0.7, "SA.GunRestore restores GunControl")
eq(MOCK_GUN_ITEMS.Defs.assault_rifle.spread, 1.0,
    "SA.GunRestore restores definition")
eq(MOCK_GUN_LIVE.RecoilPitch, 0.25, "SA.GunRestore restores recoil")
eq(MOCK_GUN_LIVE.FireRate, 2.0, "SA.GunRestore restores rate")
eq(MOCK_GUN_LIVE.CurrentAmmo, 12, "SA.GunRestore restores ammo")
eq(MOCK_GUN_LIVE.CanFireWhileSprinting, false,
    "SA.GunRestore restores movement")
ok(SA.GunState().records.spread > 0,
    "SA.GunRestore keeps cached records for re-enable")

setFlags({
    gmEnabled = false, gunShotProbe = false,
    gunNoSpread = false, gunNoRecoil = false, gunFireRate = false,
    gunInfiniteAmmo = false, gunMoveShoot = false,
    gunInspectGunControl = false, gunFireRateMultiplier = 1.5,
    displayBrightnessEnabled = false, displayBrightness = 0.2,
    gunCameraKickFilter = true,
})
window.set_menu_visibility(true)
MOCK_CAMERA.CFrame = CFrame.new(0, 3, 0)
mock_gun_reset()

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
    -- Full unload must restore hitboxes even while the toggle is ON.
    quiet(function() SA.HitboxRestore() end)
    mock_hitbox_reset()
    CFG.hitboxEnabled = true
    CFG.hitboxTarget = "Both"
    CFG.hitboxMode = "fixed"
    CFG.hitboxScale = 8
    CFG.hitboxMaxDist = 300
    CFG.hitboxTeamCheck = true
    CFG.hitboxAliveOnly = true
    SA.HitboxScan()
    eq(Players:GetPlayers()[2].Character:FindFirstChild("Head").Size.X, 8,
        "full unload: hitbox expanded before unload")
    setFlags({
        masterEnabled = true, gunEnabled = true, fustBowEnabled = true,
    })
    SA.FustBowRefresh()
    ok(MOCK_FUST_SHOOT.FireServer ~= fireServerOriginal,
        "full unload: Fust bow hook active before unload")
    local unloaded, why = SA.FullUnload()
    eq(Players:GetPlayers()[2].Character:FindFirstChild("Head").Size.X, 2,
        "full unload restores hitbox originals")
    eq(MOCK_FUST_SHOOT.FireServer, fireServerOriginal,
        "full unload restores the original FireServer")
    eq(_G.__saFustBow, nil, "full unload clears Fust bow state")
    eq(_G.__saGunMods, nil, "full unload clears V16.46 gun state")
    eq(game:GetService("Lighting"):FindFirstChild("HanamiLocalBrightness"),
        nil, "full unload destroys local brightness effect")
    eq(MOCK_GUN_LIVE.Spread, 1.0,
        "full unload restores live gun spread original")
    eq(MOCK_GUN_CONTROL.Spread, 0.7,
        "full unload restores GunControl spread original")
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
    eq(SA.ManipPopupState().built, false, "manip popup disposed by full unload")
end

-- Atlanta UI bootstrap: the upstream custom-font repo is gone. The
-- runtime sanitizer must remove its getcustomasset / dead-URL block and
-- substitute a built-in Roblox FontFace before the library is compiled.
do
    local fake = [==[
        makefolder(library.directory .. path)
        writefile("ffff.ttf", game:HttpGet("https://github.com/weasely111/beta/raw/refs/heads/main/fs-tahoma-8px.ttf"))
        local tahoma = { assetId = getcustomasset("ffff.ttf") }
        writefile("dddd.ttf", http_service:JSONEncode(tahoma))
        library.font = Font.new(getcustomasset("dddd.ttf"), Enum.FontWeight.Regular)
        return library, themes
    ]==]
    eq(type(SA.SanitizeAtlantaSource), "function",
        "Atlanta source sanitizer exposed")
    local clean = SA.SanitizeAtlantaSource(fake)
    eq(clean:find("getcustomasset", 1, true), nil,
        "sanitizer removes getcustomasset calls")
    eq(clean:find("weasely111/beta", 1, true), nil,
        "sanitizer removes dead external font URL")
    ok(clean:find("rbxasset://fonts/families/SourceSansPro.json", 1, true) ~= nil,
        "sanitizer installs built-in SourceSansPro FontFace")
    ok(clean:find("library.font = builtInFont", 1, true) ~= nil,
        "sanitizer assigns the fallback font")
    ok(clean:find("pcall(makefolder,", 1, true) ~= nil,
        "sanitizer guards makefolder bootstrap")
    ok(clean:find("return library, themes", 1, true) ~= nil,
        "sanitizer preserves the library return")
    eq(SA.SanitizeAtlantaSource(clean), clean,
        "Atlanta sanitizer is idempotent")
    eq(SA.SanitizeAtlantaSource("return library, themes"),
        "return library, themes", "plain library source is unchanged")
end

eq(callback_errors, 0, "mock callback errors")
eq(event_errors, 0, "mock event errors")
ok(mock_frame_count > 0, "render frames exercised")
eq(type(SA.DrawBackend()), "string", "draw backend string")

_G.TEST_RUN_OK = 1
print = real_print
real_print(string.format("[runtime] run %d: %d assertions passed", run, checks))
real_print("RUNTIME HARNESS OK")
