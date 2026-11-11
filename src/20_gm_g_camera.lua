-- ==================================================================
-- Hanami / 20_gm_g_camera.lua — experimental late camera-pitch correction.
-- The master render loop calls GMP.cameraTick; no second RenderStepped loop.
-- Manual upward aim may be restricted while the filter is armed.
-- ==================================================================

GMP.camera = { armed = false, baseline = 0, lastGood = nil,
    suppressed = 0, corrections = 0 }
GMP.labels = {}
GMP.masterPaused = false

function GMP.cameraPitch(cf)
    if type(cf) ~= "table" then return 0 end
    local tagged = rawget(cf, "_pitch")
    if type(tagged) == "number" and GMP.finite(tagged) then return tagged end
    local ok, rx = pcall(function()
        local x = cf:ToEulerAnglesXYZ()
        return x
    end)
    if ok and GMP.finite(rx) then return rx end
    local look = cf.LookVector
    if type(look) == "table" and look.Magnitude > 0.0001 then
        return math.asin(math.clamp(look.Y / look.Magnitude, -1, 1))
    end
    return 0
end

function GMP.cameraReset()
    GMP.camera.armed = false
    GMP.camera.baseline = 0
    GMP.camera.lastGood = nil
    GMP.setStatus("cameraKickStatus", "OFF (experimental)")
end

function GMP.cameraTick(cam)
    if not cam or not GMP.on("gunNoRecoil")
        or CFG.gunCameraKickFilter ~= true then
        GMP.cameraReset()
        return false
    end
    if not GMP.camera.armed then
        GMP.camera.armed = true
        GMP.camera.baseline = GMP.cameraPitch(cam.CFrame)
        GMP.camera.lastGood = cam.CFrame
        GMP.setStatus("cameraKickStatus",
            "Armed: enable No Recoil, then fire (experimental)")
        return false
    end
    local pitch = GMP.cameraPitch(cam.CFrame)
    if pitch > GMP.camera.baseline + 0.08 and GMP.camera.lastGood then
        local ok = pcall(function()
            cam.CFrame = GMP.camera.lastGood
        end)
        if ok then
            GMP.camera.suppressed = GMP.camera.suppressed + 1
            GMP.camera.corrections = GMP.camera.corrections + 1
            GMP.setStatus("cameraKickSuppressed", GMP.camera.suppressed)
            GMP.setStatus("cameraKickStatus",
                "Pitch correction applied (experimental)")
            return true
        end
    end
    GMP.camera.baseline = GMP.camera.baseline
        + (pitch - GMP.camera.baseline) * 0.12
    GMP.camera.lastGood = cam.CFrame
    GMP.setStatus("cameraKickStatus",
        "Armed; no correction (experimental)")
    return false
end

function GMP.cameraState()
    return { armed = GMP.camera.armed, baseline = GMP.camera.baseline,
        suppressed = GMP.camera.suppressed,
        corrections = GMP.camera.corrections,
        enabled = CFG.gunCameraKickFilter == true,
        status = GMP.status.cameraKickStatus,
        warning = "Experimental; may restrict manual upward aim" }
end

function GMP.bindLabel(key, label)
    if not key or not label then return false end
    GMP.labels[key] = label
    return true
end

function GMP.labelRows()
    local s = GMP.status
    return {
        weapon = "Weapon: " .. tostring(GMP.getWeapon().Name)
            .. " | " .. tostring(GMP.status.definitionMatchStatus),
        definitions = "Definitions: " .. tostring(s.definitionScanState),
        gunControl = "GunControl: " .. tostring(s.gunControlStatus)
            .. " | exports " .. tostring(s.gunControlExportCount),
        scripts = "Script hints: " .. tostring(s.fireScriptStatus)
            .. " | " .. tostring(s.fireScriptMatches) .. " names",
        live = "Live controller: " .. tostring(s.liveGunStatus),
        spread = "No Spread: " .. tostring(s.noSpreadStatus)
            .. " | fields " .. tostring(GMP.recordCount("spread")),
        recoil = "No Recoil: " .. tostring(s.liveRecoilStatus)
            .. " | held " .. tostring(s.liveRecoilZeroed),
        rate = "Fire Rate: " .. tostring(s.liveFireRateStatus)
            .. " | x" .. tostring(GMP.multiplier()),
        ammo = "Infinite Ammo: " .. tostring(s.liveAmmoStatus)
            .. " | held " .. tostring(s.liveAmmoChanged),
        movement = "Move Shoot: " .. tostring(s.liveMovementStatus)
            .. " | held " .. tostring(s.liveMovementChanged),
        camera = "Camera kick: " .. tostring(s.cameraKickStatus)
            .. " | corrected " .. tostring(s.cameraKickSuppressed),
        probe = "Shot probe: " .. tostring(s.shotProbeStatus)
            .. " | " .. tostring(s.shotProbeComparison),
        verdict = "Verdict: " .. tostring(s.shotProbeVerdict),
        report = "Report: " .. tostring(GMP.lastReportName)
            .. " | " .. tostring(GMP.status.reportStatus or "none"),
        display = "Brightness: " .. tostring(
            CFG.displayBrightnessEnabled == true)
            .. " | " .. tostring(GMP.displayState().brightness),
        observation = "Observation: " .. tostring(s.observationStatus),
    }
end

function GMP.refreshLabels()
    local rows = GMP.labelRows()
    for key, label in pairs(GMP.labels) do
        local text = rows[key]
        if text and label.set then
            pcall(function() label.set(tostring(text):sub(1, 150)) end)
        end
    end
end
