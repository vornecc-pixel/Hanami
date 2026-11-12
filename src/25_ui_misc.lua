-- ==================================================================
-- Hanami / 25_ui_misc.lua — Misc tab, profiles, state checks, keybinds,
-- full unload and UI init. Loaded in order by loader.lua. Parts are
-- joined into ONE chunk; the loader hoists column-1 `local`s to beat
-- Luau's 200-local cap.
-- ==================================================================

-- ── MISC : Info ────────────────────────────────────────────────────
local infoCol = MiscTab:column()
local infoSec = infoCol:section({ name = "Info" })
infoSec:label({ name = "@abusegpt — full suite" })
infoSec:label({ name = "Aim + Wall Pen + Player/NPC/Crate ESP + Gun Mods" })
infoSec:label({ name = "Menu key: RightShift (show/hide)" })
infoSec:label({ name = "Aim key: Insert | UI: Atlanta library" })
infoSec:label({ name = "Feature keys: P/N/G/B/M · right-click = None" })
infoSec:label({ name = "ESP: green = visible, red = behind wall" })
infoSec:label({ name = "Colour pickers are inline beside their own controls" })
infoSec:label({ name = "Crates: fuzzy detection + live registry" })
infoSec:label({ name = "NPC names: Guard / Scavenger / Soldier" })
infoSec:label({ name = "Ballistics: all 20 guns + every attribute" })
infoSec:label({ name = "Attachments: auto tune on 12 detected mods" })
infoSec:label({ name = "Gun Mods: V16.46 named-field holds + visual probes" })
infoSec:label({ name = "Bow Mods: instant charge + no cooldown only" })
infoSec:label({ name = "Brightness: local ColorCorrectionEffect, clamped 0-0.5" })
infoSec:label({ name = "Silent aim + manip: GUNS ONLY (bows skipped)" })
infoSec:label({ name = "BETTER: profiles · self-check · perf mode · preview compare" })

-- Colour-picker helpers are defined once in 01_config.lua so this UI part
-- stays inside Luau's 200-local-register limit. Save / Load / Export /
-- Import call SA.EspColorEncode / Decode / Text / FromText below.

-- ── MISC : Quick Actions ───────────────────────────────────────────
local actCol = MiscTab:column()
local actSec = actCol:section({ name = "Quick Actions" })


addButton(actSec, "Disable All", function()
    setFlag("masterEnabled", false)
    setFlag("gmEnabled", false)
    setFlag("displayBrightnessEnabled", false)
    setFlag("bowModsEnabled", false)
    setFlag("espEnabled", false)
    setFlag("npcEspEnabled", false)
    setFlag("crateEnabled", false)
    setFlag("showFov", false)
    setFlag("snapLineEnabled", false)
end)

addButton(actSec, "Apply Blatant", function()
    setFlag("masterEnabled", true)
    presetDropdown.set("Blatant")
end)

addButton(actSec, "Toggle Manip", function()
    setFlag("manipulation", not CFG.manipulation)
end)


addButton(actSec, "Reset ESP Colours", function()
    for k, v in pairs(ESP_DEFAULT_COLORS) do
        local setter = library.config_flags["hn_col_" .. k]
        if setter then setter(v, 1) else ESP_COLORS[k] = v end
    end
end)

-- ────────────────────────────────────────────────────────────────────
-- BETTER 1 · NATIVE CONFIG PROFILES
-- Atlanta's Configurations panel already calls library:get_config() /
-- library:load_config() / library:config_list_update(). Hanami stores
-- profiles in the SAME directory, so the built-in list stays in sync and
-- EVERY hn_* flag round-trips through library.config_flags — including
-- hn_menu_bind as a {mode, key, active} table. We never hand-roll a
-- second serialiser for those flags; that is the whole point.
-- ────────────────────────────────────────────────────────────────────

SA.ProfileDir  = (library.directory or "Atlanta") .. "/configs"
SA.ProfileLast = (library.directory or "Atlanta") .. "/hanami_last_profile.txt"

local saCfgSafeName = function(name)
    name = tostring(name or ""):gsub("[^%w%-_]", "_")
    if name == "" then name = "default" end
    return name
end

function SA.KeyToString(key)
    if key == nil or key == "none" then return "none" end
    return tostring(key):gsub("[\t\r\n]", " ")
end

function SA.ListProfiles()
    local out = { "default" }
    pcall(function()
        makefolder(library.directory or "Atlanta")
        makefolder(SA.ProfileDir)
        for _, f in ipairs(listfiles(SA.ProfileDir)) do
            local n = tostring(f):match("([^/\\]+)%.cfg$")
            if n and n ~= "default" and n ~= "hanami_last_profile" then
                out[#out + 1] = n
            end
        end
    end)
    table.sort(out)
    return out
end

function SA.GetLastProfile()
    local name = nil
    pcall(function() name = readfile(SA.ProfileLast) end)
    if type(name) ~= "string" or name == "" then return "default" end
    return saCfgSafeName(name)
end

function SA.FlagCount()
    local n = 0
    pcall(function() for _ in pairs(library.flags) do n = n + 1 end end)
    return n
end

function SA.SaveProfile(name)
    name = saCfgSafeName(name)
    local encoded = nil
    local ok, err = pcall(function()
        makefolder(library.directory or "Atlanta")
        makefolder(SA.ProfileDir)
        encoded = SA.EspColorEncode(library:get_config())
        writefile(SA.ProfileDir .. "/" .. name .. ".cfg", encoded)
        writefile(SA.ProfileDir .. "/" .. name .. ".colors", SA.EspColorText())
        writefile(SA.ProfileLast, name)
        library:config_list_update()
    end)
    if not ok then return false, tostring(err) end
    CFG.configName, CFG.configProfile = name, name
    local colorCount = SA.EspColorCount()
    SA.LastConfigResult = { profile = name, flags = SA.FlagCount(),
                            colors = colorCount, bytes = encoded and #encoded or nil }
    return true
end

function SA.LoadProfile(name)
    name = saCfgSafeName(name)
    local data = nil
    local ok, err = pcall(function()
        data = readfile(SA.ProfileDir .. "/" .. name .. ".cfg")
    end)
    if not ok or type(data) ~= "string" then
        return false, "profile not found: " .. name
    end
    pcall(function() library.old_config = library:get_config() end)
    local okLoad, loadErr = pcall(function() library:load_config(data) end)
    if not okLoad then return false, tostring(loadErr) end
    local colorCount = SA.EspColorDecode(data)
    pcall(function()
        local sidecar = readfile(SA.ProfileDir .. "/" .. name .. ".colors")
        if type(sidecar) == "string" then
            colorCount = SA.EspColorRestore(SA.EspColorFromText(sidecar))
        end
    end)
    CFG.configName, CFG.configProfile = name, name
    pcall(function() writefile(SA.ProfileLast, name) end)
    pcall(function() library:config_list_update() end)
    SA.LastConfigResult = { profile = name, flags = SA.FlagCount(),
                            colors = colorCount, bytes = #data }
    return true
end

function SA.DeleteProfile(name)
    name = saCfgSafeName(name)
    if name == "default" then
        return false, "cannot delete the default profile"
    end
    local ok, err = pcall(function()
        delfile(SA.ProfileDir .. "/" .. name .. ".cfg")
        pcall(function() delfile(SA.ProfileDir .. "/" .. name .. ".colors") end)
        library:config_list_update()
    end)
    if not ok then return false, tostring(err) end
    return true
end


function SA.ExportConfig()
    local data = SA.EspColorEncode(library:get_config())
    pcall(function() setclipboard(data) end)
    return data
end

function SA.ImportConfig(data)
    if type(data) ~= "string" or data == "" then return false, "empty input" end
    local ok, err = pcall(function() library:load_config(data) end)
    if ok then SA.EspColorDecode(data) end
    return ok, err
end

function SA.ConfigCoverage()
    local missing = {}
    for flag, setter in pairs(library.config_flags or {}) do
        if flag:sub(1, 3) == "hn_" then
            local key = flag:sub(4)
            local colKey = key:match("^col_(.+)$")
            local covered = (CFG[key] ~= nil)
                or (colKey ~= nil and ESP_COLORS[colKey] ~= nil)
                or (SA.AllKeybinds ~= nil and SA.AllKeybinds[flag] ~= nil)
                or (library.flags[flag] ~= nil
                    and type(library.flags[flag]) ~= "table")
            if not covered then missing[#missing + 1] = flag end
        end
    end
    table.sort(missing)
    return missing
end

function SA.FlagSnapshot()
    local rows = {}
    for flag, v in pairs(library.flags or {}) do
        local val
        if type(v) == "table" then
            local bits = {}
            for k, vv in pairs(v) do bits[#bits + 1] = k .. "=" .. tostring(vv) end
            table.sort(bits)
            val = "{" .. table.concat(bits, ",") .. "}"
        else
            val = tostring(v)
        end
        rows[#rows + 1] = flag .. "=" .. val
    end
    table.sort(rows)
    return table.concat(rows, "\n")
end

function SA.TestConfigRoundTrip()
    local okGet, data = pcall(function() return library:get_config() end)
    if not okGet then return false, "get_config failed: " .. tostring(data) end
    local before = SA.FlagSnapshot() .. "\n" .. SA.EspColorText()
    local okLoad, err = pcall(function() library:load_config(data) end)
    if not okLoad then return false, "load_config failed: " .. tostring(err) end
    local after = SA.FlagSnapshot() .. "\n" .. SA.EspColorText()
    if before ~= after then return false, "flag / colour snapshot changed" end
    local colorCount = SA.EspColorCount()
    return true, SA.FlagCount() .. " flags round-tripped + "
        .. colorCount .. " colours"
end

function SA.ResetKeybindDefaults()
    local defaults = {
        -- The RightShift menu bind is UI navigation, not a feature toggle:
        -- keep it active even though every feature starts OFF.
        hn_menu_bind = { key = Enum.KeyCode.RightShift, active = true },
        hn_master_bind = { key = Enum.KeyCode.Insert,
                           active = SA.CFG_DEFAULTS.masterEnabled == true },
        hn_bind_espEnabled = { key = Enum.KeyCode.P,
                               active = SA.CFG_DEFAULTS.espEnabled == true },
        hn_bind_npcEspEnabled = { key = Enum.KeyCode.N,
                                  active = SA.CFG_DEFAULTS.npcEspEnabled == true },
        hn_bind_gmEnabled = { key = Enum.KeyCode.G,
                              active = SA.CFG_DEFAULTS.gmEnabled == true },
        hn_bind_bowModsEnabled = { key = Enum.KeyCode.B,
                                   active = SA.CFG_DEFAULTS.bowModsEnabled == true },
        hn_bind_manipulation = { key = Enum.KeyCode.M,
                                 active = SA.CFG_DEFAULTS.manipulation == true },
        hn_bind_hitboxEnabled = { key = Enum.KeyCode.H,
                                  active = SA.CFG_DEFAULTS.hitboxEnabled == true },
    }
    for flag, d in pairs(defaults) do
        local cfg = SA.AllKeybinds and SA.AllKeybinds[flag] or nil
        if cfg then
            pcall(function()
                cfg.set({ mode = "toggle", key = d.key, active = d.active })
                cfg.set(cfg.active)  -- refresh list row without changing key
            end)
        end
    end
end

function SA.ResetToDefaults()
    local n = 0
    for k, v in pairs(SA.CFG_DEFAULTS or {}) do
        CFG[k] = v
        local setter = library.config_flags["hn_" .. k]
        if setter then pcall(setter, v) end
        n = n + 1
    end
    for k, v in pairs(ESP_DEFAULT_COLORS or {}) do
        ESP_COLORS[k] = v
        local setter = library.config_flags["hn_col_" .. k]
        if setter then pcall(setter, v, 1) end
    end
    pcall(SA.ResetKeybindDefaults)
    pcall(SA.ApplyTheme, CFG.uiTheme)
    pcall(SA.ApplyFont, CFG.uiFont)
    return n
end

-- ────────────────────────────────────────────────────────────────────
-- BETTER 2 · PROGRAMMATIC SELF-CHECK STATE
-- SA.SelfCheck() returns a report table (checks / passed / warned /
-- failed) for code that wants to inspect executor capabilities. There is
-- no panel, no button and no console output: the features stay silent.
-- ────────────────────────────────────────────────────────────────────

local saSCAdd = function(out, name, status, detail)
    out[#out + 1] = { name = name, status = status,
                      detail = tostring(detail or "-") }
end

local saSCCapability = function(name, neededBy)
    local ok = false
    pcall(function()
        local fn = rawget(_G, name)
        if typeof(fn) ~= "function" and typeof(getgenv) == "function" then
            fn = getgenv()[name]
        end
        ok = typeof(fn) == "function"
    end)
    return ok, neededBy
end

function SA.SelfCheck()
    local out = {}
    saSCAdd(out, "alive", SA.Alive == true and "ok" or "fail",
        "SA.Alive=" .. tostring(SA.Alive) .. " gen=" .. tostring(SA.Generation))
    saSCAdd(out, "render loop", "ok", "frame=" .. tostring(renderFrame or 0))
    local fps = 0
    pcall(function() fps = SA.PerfState().fps or 0 end)
    saSCAdd(out, "fps", fps > 0 and "ok" or "warn", string.format("%.1f", fps))
    local lpOk = false
    pcall(function() lpOk = lp ~= nil and lp.Character ~= nil end)
    saSCAdd(out, "local player", lpOk and "ok" or "warn",
        lpOk and "character present" or "no character yet")
    local camOk = false
    pcall(function() camOk = ws.CurrentCamera ~= nil end)
    saSCAdd(out, "camera", camOk and "ok" or "fail", tostring(camOk))

    local caps = {
        { "gethui", "GUI parent (CoreGui fallback)" },
        { "getgc", "Gun / Bow Mods GC scan" },
        { "setreadonly", "Gun / Bow Mods GC scan" },
        { "getconnections", "Tap-Fire Reorder (Fix A)" },
        { "hookfunction", "Tap-Fire Reorder (Fix B)" },
        { "writefile", "Profile save" },
        { "readfile", "Profile load" },
        { "delfile", "Profile delete" },
        { "listfiles", "Profile list" },
        { "makefolder", "Profile folder" },
        { "setclipboard", "Config export" },
    }
    for _, c in ipairs(caps) do
        local has, why = saSCCapability(c[1], c[2])
        saSCAdd(out, "cap:" .. c[1], has and "ok" or "warn", why)
    end
    local drawingHas = false
    pcall(function() drawingHas = typeof(Drawing) == "table" end)
    saSCAdd(out, "native Drawing", drawingHas and "ok" or "warn",
        drawingHas and "available" or "ScreenGui fallback in use")
    local backend, diag = "?", "?"
    pcall(function() backend = SA.DrawBackend() end)
    pcall(function() diag = SA.DrawDiag() end)
    saSCAdd(out, "draw backend", "ok", backend)
    saSCAdd(out, "overlay", diag:find("overlay=NONE", 1, true)
        and "warn" or "ok", diag)
    local wf = { count = 0, last = "none" }
    pcall(function() wf = SA.DrawWriteFailures() end)
    saSCAdd(out, "Drawing writes", wf.count == 0 and "ok" or "warn",
        tostring(wf.count) .. " failures, last=" .. tostring(wf.last))

    local pCount, nCount, cCount = 0, 0, 0
    pcall(function() for _ in pairs(espObjects) do pCount = pCount + 1 end end)
    pcall(function() for _ in pairs(npcObjects) do nCount = nCount + 1 end end)
    pcall(function() for _ in pairs(crateObjects) do cCount = cCount + 1 end end)
    saSCAdd(out, "ESP objects", "ok",
        "players=" .. pCount .. " npcs=" .. nCount .. " crates=" .. cCount)
    local vis = SA.EspPassStats and SA.EspPassStats() or nil
    saSCAdd(out, "on-screen ESP", "ok", vis and string.format(
        "%d players / %d npcs / %d crates", vis.players, vis.npcs, vis.crates)
        or "stats unavailable")
    local colourCount = 0
    pcall(function() for _ in pairs(ESP_COLORS) do colourCount = colourCount + 1 end end)
    saSCAdd(out, "ESP colours", colourCount >= 48 and "ok" or "warn",
        colourCount .. " pickers")
    local flagCount = 0
    pcall(function() for _ in pairs(library.config_flags) do
        flagCount = flagCount + 1 end end)
    saSCAdd(out, "UI flags", flagCount > 40 and "ok" or "warn",
        flagCount .. " bound")
    local missing = SA.ConfigCoverage()
    saSCAdd(out, "hn_* coverage", #missing == 0 and "ok" or "fail",
        #missing == 0 and "all flags round-trip" or table.concat(missing, ", "))

    local bindCount, conflicts = 0, SA.KeybindConflicts()
    pcall(function() for _ in pairs(SA.AllKeybinds or {}) do
        bindCount = bindCount + 1 end end)
    saSCAdd(out, "keybinds", bindCount >= 7 and "ok" or "warn",
        bindCount .. " registered")
    saSCAdd(out, "key conflicts", #conflicts == 0 and "ok" or "warn",
        #conflicts == 0 and "none" or (#conflicts .. " shared keys"))

    local stateCalls = {
        { "silent aim", "SilentAimState" }, { "bow mods", "BowModsState" },
        { "manipulation", "ManipState" }, { "attachments", "AttachmentState" },
        { "FOV", "FovState" }, { "ESP pass stats", "EspPassStats" },
        { "nearest HUD", "NearestWindowState" }, { "config coverage", "ConfigCoverage" },
        { "gun diff", "GunDiff" }, { "perf", "PerfState" },
        { "manip popup", "ManipPopupState" }, { "clean ESP", "CleanEspState" },
        { "NPC manipulation", "ManipNpcState" },
        { "crate FOV", "CrateFovState" },
        { "player warning", "PlayerWarningState" },
        { "fire assist", "FireAssistState" },
        { "force head", "ForceHeadState" },
        { "fust bow", "FustBowState" },
        { "gun mods", "GunState" },
        { "draw sync", "DrawSyncStats" },
        { "esp perf", "EspPerfState" },
        { "esp frame budget", "EspFrameBudget" },
        { "hitbox", "HitboxState" },
        { "FOV reference", "EspFovState" },
        { "snapline", "SnaplineState" },
        { "saved colours", "EspColorSnapshot" },
        { "colour count", "EspColorCount" },
        { "colour restore", "EspColorRestore" },
        { "colour encode", "EspColorEncode" },
        { "colour decode", "EspColorDecode" },
        { "colour text", "EspColorText" },
        { "colour parse", "EspColorFromText" },
    }
    for _, d in ipairs(stateCalls) do
        local ok = false
        pcall(function()
            if type(SA[d[2]]) == "function" then
                SA[d[2]]()   -- state helpers return data silently
                ok = true
            end
        end)
        saSCAdd(out, "api:" .. d[1], ok and "ok" or "warn", d[2])
    end
    local okPool, pool = pcall(function() return SA.DrawPoolStats() end)
    if okPool and pool then
        saSCAdd(out, "draw pool", "ok", "enabled=" .. tostring(pool.enabled)
            .. " free=" .. tostring(pool.total))
    end
    local okNearest, nearest = pcall(function() return SA.NearestWindowState() end)
    if okNearest and nearest then
        saSCAdd(out, "nearest HUD", nearest.built and "ok" or "warn",
            "built=" .. tostring(nearest.built) .. " reason=" .. tostring(nearest.reason))
    end
    saSCAdd(out, "no target", "ok", SA.NoTargetReason())
    local okManip, manipPossible, manipReason = pcall(SA.ManipPossible)
    saSCAdd(out, "manip possible", okManip and "ok" or "warn",
        (okManip and tostring(manipPossible) or "probe error")
        .. " | " .. tostring(manipReason))
    local okRT, rtGood, rtDetail = pcall(SA.TestConfigRoundTrip)
    saSCAdd(out, "config round-trip",
        (okRT and rtGood) and "ok" or "fail",
        okRT and tostring(rtDetail) or tostring(rtGood))

    local passed, warned, failed = 0, 0, 0
    for _, c in ipairs(out) do
        if c.status == "ok" then passed = passed + 1
        elseif c.status == "warn" then warned = warned + 1
        else failed = failed + 1 end
    end
    local report = { checks = out, passed = passed, warned = warned,
                     failed = failed, at = tick() }
    SA.LastSelfCheck = report
    return report
end


function SA.SelfCheckState()
    return SA.LastSelfCheck or SA.SelfCheck()
end




-- ────────────────────────────────────────────────────────────────────
-- BOTH UNLOAD PATHS USE ONE COMPLETE TEARDOWN
-- Misc -> Unload Everything (FULL) and Atlanta's built-in "Unload Menu"
-- both call SA.FullUnload(). A plain RightShift hide does NOT. Atlanta
-- only destroys library.guis / library.connections, so Hanami additionally
-- disconnects every direct service / RenderStepped hook, removes native
-- Drawing objects + GUI proxies + orphan world ESP, and destroys its own
-- ScreenGuis / blur / brightness effects before clearing shared state.
-- ────────────────────────────────────────────────────────────────────

function SA.FullUnloadState()
    return SA.LastUnload or {}
end

function SA.FullUnload(reason)
    if SA.Unloaded then return false, "already unloaded" end
    SA.Unloaded = true
    SA.Alive = false
    SA.Generation = (SA.Generation or 0) + 1
    local trigger = tostring(reason or "SA.FullUnload()")

    -- Turn every visual / runtime feature OFF through Atlanta when its
    -- widgets still exist, then hard-reset CFG so a destroyed menu cannot
    -- let a stale setter rebuild anything after the sweep.
    for _, key in ipairs({
        "showFov", "snapLineEnabled", "snapShowLead", "espEnabled",
        "npcEspEnabled", "crateEnabled", "espPreview", "nearestWindow",
        "perfMode", "perfShowFps", "showManipPopup", "showPlayerWarning",
        "showNoTargetReason", "masterEnabled", "gunEnabled", "gmEnabled",
        "hitboxEnabled", "bowModsEnabled", "bowInstantCharge",
        "bowNoCooldown", "fustBowEnabled", "displayBrightnessEnabled",
        "forceHead", "triggerbot", "autoFire",
    }) do
        pcall(function() setFlag(key, false) end)
    end
    CFG.showFov, CFG.snapLineEnabled, CFG.espEnabled = false, false, false
    CFG.npcEspEnabled, CFG.crateEnabled, CFG.espPreview = false, false, false
    CFG.nearestWindow, CFG.perfMode, CFG.perfShowFps = false, false, false
    CFG.showManipPopup, CFG.showPlayerWarning = false, false
    CFG.masterEnabled, CFG.gunEnabled, CFG.gmEnabled = false, false, false
    CFG.hitboxEnabled, CFG.bowModsEnabled = false, false
    CFG.bowInstantCharge, CFG.bowNoCooldown = false, false
    CFG.fustBowEnabled, CFG.displayBrightnessEnabled = false, false
    CFG.forceHead, CFG.triggerbot, CFG.autoFire = false, false, false

    pcall(function() if SA.BowModsRestore then SA.BowModsRestore() end end)
    pcall(function() if SA.HitboxRestore then SA.HitboxRestore() end end)
    pcall(function() if SA.FovDispose then SA.FovDispose() end end)
    pcall(function() if SA.SnaplineDispose then SA.SnaplineDispose() end end)
    pcall(function() disableESP() end)
    pcall(function() disableNpcESP() end)
    pcall(function() disableCrateESP() end)
    pcall(function() if SA.EspPreviewDispose then SA.EspPreviewDispose() end end)
    pcall(function() if SA.NearestWindowDispose then SA.NearestWindowDispose() end end)
    pcall(function() if SA.DisposePerfOverlay then SA.DisposePerfOverlay() end end)
    pcall(function() if SA.DisposeManipPopup then SA.DisposeManipPopup() end end)
    pcall(function() if SA.DisposePlayerWarning then SA.DisposePlayerWarning() end end)
    pcall(function() if SA.DisposeFireAssist then SA.DisposeFireAssist() end end)
    pcall(function() if SA.FustBowDispose then SA.FustBowDispose() end end)
    pcall(function() if SA.GunDispose then SA.GunDispose() end end)
    pcall(function() if SA.DrawDisposeAll then SA.DrawDisposeAll() end end)
    pcall(function() if SA.DisposeHanamiGuis then SA.DisposeHanamiGuis() end end)
    pcall(function() RunService:UnbindFromRenderStep(snapName) end)
    pcall(function() RunService:UnbindFromRenderStep(restoreName) end)
    pcall(function() SA.TapRestore(_G.__saTapCF, _G.__saTapCam) end)
    pcall(function() saManipRestore() end)
    pcall(function() if SA.DisconnectConnections then SA.DisconnectConnections() end end)
    pcall(function()
        for _, c in ipairs(library.connections or {}) do
            pcall(function() c:Disconnect() end)
        end
    end)
    pcall(function()
        if SA.RebindConn then SA.RebindConn:Disconnect() end
        SA.RebindConn, SA.RebindFlag = nil, nil
    end)
    pcall(function()
        if _G.__saEspPreviewCharConn then
            _G.__saEspPreviewCharConn:Disconnect()
            _G.__saEspPreviewCharConn = nil
        end
    end)
    pcall(function()
        for _, g in ipairs(library.guis or {}) do
            pcall(function() g:Destroy() end)
        end
    end)
    pcall(function() window.set_menu_visibility(false) end)

    SA.PinnedTarget, SA.Target = nil, {}
    SA.DrawPool, SA.EspVisibleCount = {}, { players = 0, npcs = 0, crates = 0 }
    SA.AllKeybinds, SA.FeatureBinds = {}, {}
    _G.__saTapCF, _G.__saTapCam, _G.__saTapAt = nil, nil, nil
    _G.__saShared, _G.__saCFG = nil, nil
    _G.__saEspObjects, _G.__saNpcObjects, _G.__saCrateObjects = nil, nil, nil
    _G.__saEspPreview, _G.__saNearestWindow = nil, nil
    _G.__saNearestWindowPos = nil
    _G.__saTapReorder, _G.__saManipFix = nil, nil
    _G.__saWhiteColorFix, _G.__saFovFix = nil, nil
    _G.__saFustBow, _G.__saGunMods = nil, nil
    _G.__saConnections, _G.__saDrawGui = nil, nil
    _G.__saPlayerCharHooks = nil
    _G.__saPlayerAddedConn, _G.__saPlayerRemovingConn = nil, nil
    _G.__saCrateEvents, _G.__saEspPreviewCharConn = nil, nil
    _G.__saAtlantaBlur, _G.__saManipPopup = nil, nil
    _G.__saPlayerWarning = nil
    pcall(function() if SA.EspFontRegistryReset then SA.EspFontRegistryReset() end end)

    local report = {
        trigger = trigger,
        visuals = SA.VisualState and SA.VisualState() or {},
        connections = SA.ConnectionState and SA.ConnectionState() or {},
        at = tick(),
    }
    SA.LastUnload = report
    _G.__saLastUnload = report
    return true, report
end

-- ── MISC : Profile / System UI ────────────────────────────────────
local miscCol = MiscTab:column()
local profileSec, sysSec = miscCol:multi_section({
    names = { "Config Profiles", "System" },
})

bindToggle(profileSec, "Auto-load Last Profile", "autoLoadConfig",
    "On startup, load the last saved Hanami/Atlanta config automatically")
profileSec:textbox({
    name = "Profile Name", flag = "hn_configName",
    default = CFG.configName or "default",
    placeholder = "profile name",
    callback = function(text) CFG.configName = tostring(text or "") end,
})
local saCfgProfileItems = SA.ListProfiles()
local saCfgHasSelected = false
for _, n in ipairs(saCfgProfileItems) do
    if n == CFG.configProfile then saCfgHasSelected = true end
end
if not saCfgHasSelected then
    saCfgProfileItems[#saCfgProfileItems + 1] = CFG.configProfile
    table.sort(saCfgProfileItems)
end
profileSec:dropdown({
    name = "Profile", flag = "hn_configProfile",
    items = saCfgProfileItems, default = CFG.configProfile,
    callback = function(v)
        CFG.configProfile = tostring(v or "default")
        CFG.configName = CFG.configProfile
        pcall(function()
            local setter = library.config_flags["hn_configName"]
            if setter then setter(CFG.configName) end
        end)
    end,
})
addButton(profileSec, "Save Profile", function()
    local ok, err = SA.SaveProfile(CFG.configName or CFG.configProfile)
end)
addButton(profileSec, "Load Profile", function()
    local ok, err = SA.LoadProfile(CFG.configProfile)
end)
addButton(profileSec, "Delete Profile", function()
    local ok, err = SA.DeleteProfile(CFG.configProfile)
end)
addButton(profileSec, "Reset to Defaults", function() SA.ResetToDefaults() end)
addButton(profileSec, "Export Config to Clipboard", function() SA.ExportConfig() end)
addButton(profileSec, "Import Config from Clipboard", function()
    local data = nil
    pcall(function() data = getclipboard() end)
    local ok, err = SA.ImportConfig(data)
end)


addButton(sysSec, "Unload Everything (FULL)", function()
    SA.FullUnload("Unload Everything (FULL)")
end)

-- ── Initialisation (from the Atlanta template) ─────────────────────
Aiming.open_tab()

pcall(function() library:config_list_update() end)
for index, value in themes.preset do
    pcall(function() library:update_theme(index, value) end)
end
-- Re-assert the selected preset/font after the whole UI is built. These
-- are one-time event-driven passes, never a second RenderStepped loop.
pcall(SA.ApplyTheme, CFG.uiTheme)
pcall(SA.ApplyFont, CFG.uiFont)

task.wait()
pcall(function() library.old_config = library:get_config() end)
if CFG.autoLoadConfig == true then
    local lastName = SA.GetLastProfile()
    local okCall, loaded, why = pcall(SA.LoadProfile, lastName)
end
