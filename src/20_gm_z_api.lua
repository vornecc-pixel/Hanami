-- ==================================================================
-- Hanami / 20_gm_z_api.lua — silent state APIs, toggle wiring and the
-- single master-render frame hook. No extra RenderStepped loop.
-- ==================================================================

function SA.GunRefreshSources(force)
    if not GMP.master() then
        GMP.setStatus("liveGunStatus", "Enable Gun Mods first")
        return false
    end
    if force == true then
        GMP.live.scanned, GMP.live.nextRun = false, 0
        GMP.items.nextAttempt, GMP.gunControl.nextAttempt = 0, 0
    end
    if CFG.gunInspectDefs == true or GMP.on("gunNoSpread") then
        GMP.enableSource("Fust.Items definition")
        GMP.refreshDefinitionInspector(force == true)
    else
        GMP.restoreSource("Fust.Items definition")
        GMP.setStatus("definitionScanState", "Paused (enable Inspect definitions)")
    end
    if CFG.gunInspectGunControl == true then
        GMP.requestGunControlExports(force == true)
    else
        GMP.restoreLocalSpread()
    end
    if CFG.gunInspectScripts == true then GMP.scanVisibleFireScripts()
    else GMP.setStatus("fireScriptStatus", "Paused (enable Inspect scripts)") end
    if CFG.gunInspectLiveGun == true then
        GMP.enableSource("live controller")
        GMP.enableSource("equipped tool")
        GMP.scanLive(force == true)
        GMP.holdLive(true)
    else
        GMP.restoreSource("live controller")
        GMP.restoreSource("equipped tool")
        GMP.setStatus("liveGunStatus",
            "Enable live firing-state inspection first")
    end
    GMP.refreshLabels()
    return true
end

function SA.GunScanLive(force)
    return GMP.scanLive(force == true)
end

function SA.GunRestore()
    GMP.restoreAll()
    GMP.syncLiveStatus()
    GMP.refreshLabels()
    return true
end

function SA.GunRefresh(force)
    return SA.GunRefreshSources(force == true)
end

function SA.GunModeStatus(mode, enabled)
    if mode == "spread" then
        GMP.setStatus("noSpreadStatus", enabled
            and "ON (named local fields only)" or "OFF")
        GMP.setStatus("noSpreadFound", GMP.recordCount("spread"))
        GMP.setStatus("noSpreadZeroed", enabled
            and GMP.liveActiveCount("spread") or 0)
    elseif mode == "recoil" then
        GMP.setStatus("liveRecoilStatus", enabled
            and "Applying cached recoil fields (unverified)"
            or "OFF / originals restored")
    elseif mode == "rate" then
        GMP.setStatus("liveFireRateStatus", enabled
            and "Local rate fields held; server may override" or "OFF")
    elseif mode == "ammo" then
        GMP.setStatus("liveAmmoStatus", enabled
            and "Candidate local counters held; server may override" or "OFF")
    elseif mode == "movement" then
        GMP.setStatus("liveMovementStatus", enabled
            and "Local permissions held; controller/server may gate" or "OFF")
    end
end

function SA.GunSet(key, value)
    if not GMP or not GMP.alive then return false end
    if key == "displayBrightness" then
        CFG.displayBrightness = math.clamp(tonumber(value) or 0.2, 0, 0.5)
        GMP.applyBrightness()
        GMP.refreshLabels()
        return true
    elseif key == "displayBrightnessEnabled" then
        CFG.displayBrightnessEnabled = value == true
        GMP.applyBrightness()
        GMP.refreshLabels()
        return true
    elseif key == "gmEnabled" then
        if value == true then
            GMP.masterPaused = false
            SA.GunRefreshSources(false)
            GMP.probeSet(CFG.gunShotProbe == true)
            return true
        end
        GMP.masterPaused = true
        GMP.restoreAll()
        GMP.probeSet(false)
        GMP.cameraReset()
        GMP.setStatus("liveGunStatus", "Paused (Gun Mods master OFF)")
        GMP.refreshLabels()
        return true
    elseif key == "gunFireRateMultiplier" then
        CFG.gunFireRateMultiplier = GMP.multiplier()
        GMP.applyMode("rate")
        GMP.refreshLabels()
        return true
    elseif key == "gunInspectDefs" then
        if value == true then
            GMP.enableSource("Fust.Items definition")
            GMP.refreshDefinitionInspector(true)
        else
            GMP.restoreSource("Fust.Items definition")
            GMP.setStatus("definitionScanState",
                "Paused (enable Inspect definitions)")
        end
        GMP.refreshLabels()
        return true
    elseif key == "gunInspectScripts" then
        if value == true then GMP.scanVisibleFireScripts()
        else
            GMP.status.fireScriptCandidates = {}
            GMP.setStatus("fireScriptMatches", 0)
            GMP.setStatus("fireScriptStatus",
                "Paused (enable Inspect scripts)")
        end
        GMP.refreshLabels()
        return true
    elseif key == "gunInspectGunControl" then
        if value == true then GMP.requestGunControlExports(true)
        else GMP.restoreLocalSpread() end
        GMP.refreshLabels()
        return true
    elseif key == "gunInspectLiveGun" then
        if value == true then
            GMP.enableSource("live controller")
            GMP.enableSource("equipped tool")
            GMP.scanLive(false)
            GMP.holdLive(true)
        else
            GMP.restoreSource("live controller")
            GMP.restoreSource("equipped tool")
            GMP.live.scanned, GMP.live.nextRun = false, 0
            GMP.setStatus("liveGunStatus",
                "Enable live firing-state inspection first")
        end
        GMP.refreshLabels()
        return true
    elseif key == "gunShotProbe" then
        GMP.probeSet(value == true)
        GMP.refreshLabels()
        return true
    elseif key == "gunCameraKickFilter" then
        GMP.cameraReset()
        GMP.refreshLabels()
        return true
    end
    local modes = { gunNoSpread = "spread", gunNoRecoil = "recoil",
        gunFireRate = "rate", gunInfiniteAmmo = "ammo",
        gunMoveShoot = "movement" }
    local mode = modes[key]
    if not mode then return false end
    if value == true then
        if CFG.gunInspectLiveGun ~= true then
            GMP.setStatus("liveGunStatus",
                "Enable live firing-state inspection first")
            GMP.refreshLabels()
            return false
        end
        SA.GunRefreshSources(false)
        if key == "gunNoSpread" then GMP.probeSwitchTrial() end
        GMP.applyMode(mode)
        GMP.holdLive(true)
    else
        GMP.restoreMode(mode)
        if key == "gunNoSpread" then GMP.probeSwitchTrial() end
    end
    SA.GunModeStatus(mode, value == true)
    GMP.refreshLabels()
    return true
end

function SA.GunFrame(dt, now)
    if not GMP or not GMP.alive or SA.Unloaded then return end
    now = tonumber(now) or GMP.now()
    GMP.clock = now
    if now - GMP.profileClock >= 0.5 then
        GMP.profileClock = now
        GMP.applyBrightness()
    end
    if not GMP.master() then
        if not GMP.masterPaused then
            GMP.masterPaused = true
            GMP.restoreAll()
            GMP.probeSet(false)
            GMP.cameraReset()
        end
        if now - GMP.labelClock >= 0.25 then
            GMP.labelClock = now
            GMP.refreshLabels()
        end
        return
    end
    if GMP.masterPaused then
        GMP.masterPaused = false
        SA.GunRefreshSources(false)
        GMP.probeSet(CFG.gunShotProbe == true)
    end
    GMP.holdLive(false)
    if now - GMP.sourceClock >= 0.75 then
        GMP.sourceClock = now
        if CFG.gunInspectDefs == true or GMP.on("gunNoSpread") then
            GMP.refreshDefinitionInspector(false)
        end
        if CFG.gunInspectScripts == true then
            GMP.scanVisibleFireScripts()
        end
        if CFG.gunInspectGunControl == true then
            GMP.testGunControlSpreadFields()
        end
    end
    if now - GMP.spreadClock >= 0.25 then
        GMP.spreadClock = now
        GMP.syncLiveStatus()
        GMP.refreshLabels()
    end
    GMP.probePollHeldFire()
    GMP.probeProcessPending()
    GMP.cameraTick(ws.CurrentCamera)
end

function SA.GunState()
    return { generation = GMP.generation, alive = GMP.alive,
        master = CFG.gmEnabled == true,
        status = GMP.copy(GMP.status), errors = GMP.copy(GMP.errors),
        display = GMP.displayState(), camera = GMP.cameraState(),
        definitions = GMP.inspectSelectedDefinition(),
        gunControl = GMP.gunControl, fireScripts = GMP.fireScript,
        live = { scanned = GMP.live.scanned, apis = GMP.live.apis,
            gcMode = GMP.live.gcMode, gcInspected = GMP.live.gcInspected,
            closures = GMP.live.closures, tables = GMP.live.tables,
            clues = GMP.copy(GMP.live.clues),
            errors = GMP.copy(GMP.live.errors) },
        records = { spread = GMP.recordCount("spread"),
            recoil = GMP.recordCount("recoil"),
            rate = GMP.recordCount("rate"), ammo = GMP.recordCount("ammo"),
            movement = GMP.recordCount("movement") },
        weapon = GMP.weaponSnapshot(),
        probe = GMP.shotProbeSnapshot(),
        lastReport = GMP.lastReportName,
        caveat = "Static + Fengari mock validation only; no real executor or in-game confirmation." }
end

function SA.GunDisplayState() return GMP.displayState() end
function SA.GunLiveState() return GMP.copy(GMP.status) end
function SA.GunInspectDefinition() return GMP.inspectSelectedDefinition() end
function SA.GunDefinitionReport() return GMP.definitionReport() end
function SA.GunControlReport() return GMP.gunControlReport() end
function SA.GunFireScriptReport() return GMP.fireScriptReport() end
function SA.GunLiveReport() return GMP.liveReport() end
function SA.GunShotProbeState() return GMP.shotProbeSnapshot() end
function SA.GunShotProbeReport() return GMP.shotProbeReport() end
function SA.GunObservationBaseline() return GMP.observationBaselineNow() end
function SA.GunObservationCompare() return GMP.observationCompareNow() end
function SA.GunUseDefinitionCandidate(index)
    return GMP.useDefinitionCandidate(index)
end
function SA.GunClearManualDefinition() return GMP.clearManualDefinition() end

function SA.GunShotProbeFire()
    return GMP.noteShotProbeInput()
end

function SA.GunShotProbeProcess()
    return GMP.probeProcessPending()
end

function SA.GunShotProbeReset()
    local enabled = GMP.on("gunShotProbe")
    GMP.probeReset(enabled)
    GMP.probeSet(enabled and GMP.master())
    GMP.refreshLabels()
    return true
end

function SA.GunReport(name)
    name = tostring(name or "live")
    local report
    if name == "definitions" then report = GMP.definitionReport()
    elseif name == "guncontrol" then report = GMP.gunControlReport()
    elseif name == "scripts" then report = GMP.fireScriptReport()
    elseif name == "shot" or name == "probe" then
        report = GMP.shotProbeReport()
    elseif name == "display" then
        local d = GMP.displayState()
        report = "Hanami local brightness\nEnabled: " .. tostring(d.enabled)
            .. "\nValue: " .. tostring(d.brightness)
            .. "\nEffect: " .. tostring(d.effect)
            .. "\n" .. d.kind
    elseif name == "all" then
        report = table.concat({ GMP.definitionReport(),
            GMP.gunControlReport(), GMP.fireScriptReport(),
            GMP.liveReport(), GMP.shotProbeReport() }, "\n\n")
    else report = GMP.liveReport() end
    GMP.lastReport, GMP.lastReportName = report, name
    GMP.setStatus("reportStatus", "ready: " .. name)
    GMP.refreshLabels()
    return report
end

function SA.GunCopyReport(name)
    local report = SA.GunReport(name or "live")
    local copy = nil
    if type(setclipboard) == "function" then copy = setclipboard
    elseif type(toclipboard) == "function" then copy = toclipboard end
    if not copy then
        GMP.setStatus("reportStatus",
            "clipboard unavailable; use SA.GunReport state API")
        return false
    end
    local ok = pcall(copy, report)
    GMP.setStatus("reportStatus", ok and ("copied: " .. GMP.lastReportName)
        or "clipboard failed; use SA.GunReport state API")
    GMP.refreshLabels()
    return ok
end

function SA.GunDispose()
    if not GMP or not GMP.alive then return false end
    GMP.restoreAll()
    GMP.restoreSource("Fust.Items definition")
    GMP.restoreSource("GunControl exports")
    GMP.restoreSource("live controller")
    GMP.restoreSource("equipped tool")
    GMP.brightnessDestroy()
    GMP.probeSet(false)
    GMP.cameraReset()
    GMP.alive = false
    _G.__saGunMods = nil
    return true
end

function SA.GunBindToggle(sec, label, key, tooltip)
    local flag = "hn_" .. key
    local obj = sec:toggle({
        name = label, flag = flag, enabled = CFG[key],
        default = CFG[key], tooltip = tooltip,
        callback = function(v)
            CFG[key] = v
            SA.GunSet(key, v)
        end,
    })
    library.config_flags[flag] = function(v)
        obj.enabled = v == true
        obj.set(v)
    end
    return obj
end

function SA.GunBindSlider(sec, label, key, min, max, interval, suffix)
    local flag = "hn_" .. key
    local obj = sec:slider({
        name = label, flag = flag, min = min, max = max,
        default = CFG[key], interval = interval, suffix = suffix or "",
        callback = function(v)
            CFG[key] = v
            SA.GunSet(key, v)
        end,
    })
    library.config_flags[flag] = function(v) obj.set(v) end
    return obj
end

function SA.GunBindLabel(key, label)
    return GMP.bindLabel(key, label)
end

function SA.GunBindButton(sec, label, fn)
    return addButton(sec, label, fn)
end

SA.GunSetStatus = GMP.setStatus
SA.GunRecordCount = GMP.recordCount
