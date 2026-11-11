-- ==================================================================
-- Hanami / 20_gm_a_core.lua — V16.46 gun sandbox: shared state, helpers,
-- equipped-weapon identity and local post-processing brightness.
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================
--
-- This namespace replaces the old seven-toggle GC gun mods. Everything is
-- client-local and reversible: named numeric settings on the equipped Tool,
-- visible viewmodel, the selected Fust.Items definition, the exported
-- GunControl table and source-attributed live-controller upvalue tables.
-- No firing remotes, RNG hooks, server writes or console output. Reports
-- are returned by SA.Gun* state APIs; the UI shows status labels only.
-- Inspections, a one-time bounded discovery scan and combined reports are
-- automatic; the visible toggles reuse their cached fields.
-- Shot results are NEVER claimed as verified.
-- ==================================================================

if SA.GunDispose then pcall(SA.GunDispose) end

local GMP = {}
_G.__saGunMods = GMP
GMP.generation = SA.Generation or 0
GMP.alive = true
GMP.errors = {}
GMP.lastReport = nil
GMP.lastReportName = "none"
GMP.clock = 0
GMP.holdClock = 0
GMP.profileClock = 0
GMP.sourceClock = 0
GMP.spreadClock = 0
GMP.labelClock = 0
GMP.autoClock = 0
GMP.auto = { scans = 0, reports = 0, baselines = 0,
             comparisons = 0, lastAt = 0 }

GMP.status = {
    noSpreadStatus = "OFF", noSpreadFound = 0, noSpreadZeroed = 0,
    noSpreadWeapon = "none", noSpreadProbePaths = {},
    noSpreadDefinitionStatus = "Not requested",
    noSpreadDefinitionFound = 0, noSpreadDefinitionZeroed = 0,
    gunControlStatus = "Automatic startup scan pending", gunControlType = "unknown",
    gunControlFields = 0, gunControlModified = 0, gunControlPaths = {},
    gunControlExportRows = {}, gunControlExportCount = 0, gunControlError = nil,
    fireScriptStatus = "Not inspected", fireScriptScanned = 0,
    fireScriptMatches = 0, fireScriptCandidates = {},
    definitionScanState = "Starting read-only scan",
    definitionMatchStatus = "Not scanned", definitionMatchEvidence = "none",
    definitionSummary = "none", definitionSchemaSamples = "none",
    definitionSelectionStatus = "Automatic only", definitionCandidates = {},
    liveGunStatus = "Not scanned", liveGunClosures = 0, liveGunTables = 0,
    liveGunFields = 0, liveGunZeroed = 0, liveGunCandidates = {},
    liveGunErrors = {}, liveGunAPIs = "Not checked",
    liveRecoilStatus = "OFF", liveRecoilFields = 0, liveRecoilZeroed = 0,
    liveRecoilPaths = {}, liveFireRateStatus = "OFF", liveFireRateFields = 0,
    liveFireRateChanged = 0, liveFireRatePaths = {}, liveAmmoStatus = "OFF",
    liveAmmoFields = 0, liveAmmoChanged = 0, liveAmmoPaths = {},
    liveMovementStatus = "OFF", liveMovementFields = 0,
    liveMovementChanged = 0, liveMovementPaths = {},
    liveToolSettingsStatus = "No equipped gun inspected",
    cameraKickStatus = "OFF (experimental)", cameraKickSuppressed = 0,
    shotProbeStatus = "OFF", shotProbeFireInputs = 0, shotProbeEffects = 0,
    shotProbeNearbyAdded = 0, shotProbeNames = {}, shotProbeSamples = {},
    shotProbeTracers = 0, shotProbeDirectional = 0, shotProbeAmbiguous = 0,
    shotProbeAngleMean = 0, shotProbeAngleMax = 0, shotProbeAngleLatest = nil,
    shotProbeMethod = "none", shotProbeAimSnapshots = 0,
    shotProbeUnmatched = 0, shotProbeOffCount = 0, shotProbeOnCount = 0,
    shotProbeOffMean = 0, shotProbeOnMean = 0, shotProbeOffScatter = 0,
    shotProbeOnScatter = 0, shotProbeOffMax = 0, shotProbeOnMax = 0,
    shotProbeAxisOff = 0, shotProbeAxisOn = 0,
    shotProbeComparison = "Need motion samples",
    shotProbeVerdict = "No bullet-spread verification",
    shotProbeWeapon = "(not locked)", shotProbeMismatchedWeapon = 0,
    shotProbeOnWritableMax = 0, shotProbeRecent = {},
    observationStatus = "No baseline", observationRows = {},
}

-- ── helpers ───────────────────────────────────────────────────────
function GMP.finite(n)
    return type(n) == "number" and n == n and math.abs(n) < math.huge
end

function GMP.norm(value)
    if type(value) ~= "string" then return "" end
    return value:lower():gsub("[^%w]", "")
end

function GMP.copy(t)
    local out = {}
    if type(t) == "table" then
        for k, v in pairs(t) do out[k] = v end
    end
    return out
end

function GMP.clear(t)
    if type(t) ~= "table" then return t end
    for k in pairs(t) do t[k] = nil end
    return t
end

function GMP.addError(text)
    if #GMP.errors < 12 then
        GMP.errors[#GMP.errors + 1] = tostring(text):sub(1, 180)
    end
end

function GMP.guard(name, fn)
    local ok, err = pcall(fn)
    if not ok then GMP.addError(name .. ": " .. tostring(err)) end
    return ok, err
end

function GMP.master()
    return CFG.gmEnabled == true and SA.Alive == true
        and SA.Unloaded ~= true and GMP.alive == true
end

function GMP.on(key)
    return GMP.master() and CFG[key] == true
end

function GMP.mutableOn()
    return GMP.on("gunNoSpread") or GMP.on("gunNoRecoil")
        or GMP.on("gunFireRate") or GMP.on("gunInfiniteAmmo")
        or GMP.on("gunMoveShoot")
end

function GMP.setStatus(key, value)
    GMP.status[key] = value
end

-- ── local post-processing brightness (ColorCorrectionEffect only) ──
-- No Lighting global property writes, no character or weapon changes.
local Lighting = game:GetService("Lighting")
GMP.brightnessEffect = nil
GMP.brightnessApplies = 0
GMP.brightnessDisposed = 0

function GMP.brightnessDestroy()
    local effect = GMP.brightnessEffect
    GMP.brightnessEffect = nil
    if effect then
        pcall(function() effect:Destroy() end)
        GMP.brightnessDisposed = GMP.brightnessDisposed + 1
    end
    return false
end

function GMP.applyBrightness()
    if not SA.Alive or SA.Unloaded or CFG.displayBrightnessEnabled ~= true then
        return GMP.brightnessDestroy()
    end
    local effect = GMP.brightnessEffect
    if not effect or not effect.Parent then
        local ok, made = pcall(function()
            local inst = Instance.new("ColorCorrectionEffect")
            inst.Name = "HanamiLocalBrightness"
            inst.Parent = Lighting
            return inst
        end)
        if not ok or not made then return false end
        effect = made
        GMP.brightnessEffect = effect
    end
    local value = math.clamp(tonumber(CFG.displayBrightness) or 0.2, 0, 0.5)
    pcall(function()
        effect.Brightness = value
        effect.Contrast = 0
        effect.Saturation = 0
        effect.TintColor = Color3.new(1, 1, 1)
    end)
    GMP.brightnessApplies = GMP.brightnessApplies + 1
    return true
end

function GMP.displayState()
    return {
        enabled = CFG.displayBrightnessEnabled == true,
        brightness = math.clamp(tonumber(CFG.displayBrightness) or 0.2, 0, 0.5),
        effect = GMP.brightnessEffect ~= nil,
        effectName = GMP.brightnessEffect and GMP.brightnessEffect.Name or "none",
        applies = GMP.brightnessApplies,
        disposed = GMP.brightnessDisposed,
        kind = "ColorCorrectionEffect (local post-processing only)",
    }
end

-- ── equipped weapon identity ──────────────────────────────────────
local Tags = game:GetService("CollectionService")
GMP.EQUIP_ATTRS = { "ItemId", "ItemID", "EquippedItemId", "HeldItemId",
    "CurrentItemId", "WeaponId", "CurrentWeapon", "EquippedWeapon",
    "HeldWeapon", "SelectedItemId", "SelectedWeaponId" }
GMP.EQUIP_VALUE_NAMES = {
    equippeditemid = true, helditemid = true, currentitemid = true,
    weaponid = true, currentweapon = true, equippedweapon = true,
    heldweapon = true, selecteditemid = true, selectedweaponid = true,
    itemid = true,
}

function GMP.attrText(object, names)
    if not object then return nil end
    for _, name in ipairs(names or GMP.EQUIP_ATTRS) do
        local ok, value = pcall(function() return object:GetAttribute(name) end)
        if ok then
            if type(value) == "string" and value ~= "" then return value end
            if GMP.finite(value) then return tostring(value) end
        end
    end
    return nil
end

function GMP.valueObjectText(object)
    if object:IsA("ObjectValue") then
        local value = object.Value
        if value then return GMP.attrText(value) or value.Name, value end
        return nil, nil
    end
    if object:IsA("StringValue") then
        local value = object.Value
        if value ~= "" then return value, object end
    elseif object:IsA("IntValue") or object:IsA("NumberValue") then
        return tostring(object.Value), object
    end
    return nil, nil
end

function GMP.scanEquippedValue(root)
    if not root then return nil, nil end
    local visited = 0
    local ok, descendants = pcall(function() return root:GetDescendants() end)
    if not ok then return nil, nil end
    for _, object in ipairs(descendants) do
        visited = visited + 1
        if visited > 900 then break end
        if GMP.EQUIP_VALUE_NAMES[GMP.norm(object.Name)] then
            local okRead, value, source = pcall(GMP.valueObjectText, object)
            if okRead and value then return value, source end
        end
    end
    return nil, nil
end

GMP.weapon = { Tool = nil, ItemId = nil, Name = "None", Tags = {},
    LastCharacter = nil, NextEquip = 0, Identity = nil, Source = "none",
    SourceObject = nil, Definition = nil, DefinitionId = nil, DetectedAt = 0 }

function GMP.getWeapon()
    local w = GMP.weapon
    local char = lp.Character
    if not char then
        w.Tool, w.ItemId, w.Name, w.Tags = nil, nil, "None", {}
        w.Identity, w.LastCharacter, w.Source = nil, nil, "none"
        w.SourceObject, w.Definition, w.DefinitionId = nil, nil, nil
        return w
    end
    if w.LastCharacter == char and os.clock() < w.NextEquip then return w end
    w.LastCharacter = char
    w.NextEquip = os.clock() + 0.20
    local tool = char:FindFirstChildOfClass("Tool")
    local id = GMP.attrText(tool) or GMP.attrText(char) or GMP.attrText(lp)
    local sourceObject = tool
    local source = tool and "character Tool" or nil
    if not id then
        local found, obj = GMP.scanEquippedValue(char)
        if found then id, sourceObject, source = found, obj, "character value" end
    end
    if not id then
        local found, obj = GMP.scanEquippedValue(lp)
        if found then id, sourceObject, source = found, obj, "player value" end
    end
    local camera = Workspace.CurrentCamera
    local sticky = w.SourceObject
    local stickyAlive = sticky and sticky.Parent and (
        (char and sticky:IsDescendantOf(char))
        or (camera and sticky:IsDescendantOf(camera))
        or sticky == char or sticky == camera)
    if not id and stickyAlive and w.ItemId and w.Definition then
        id, sourceObject, source = w.ItemId, sticky, w.Source
    end
    local name = (tool and tool.Name) or id or "None"
    if not id and tool then id = tool.Name end
    local identity = tostring(sourceObject) .. "/" .. tostring(id)
    if w.Identity and w.Identity ~= identity then
        w.Definition, w.DefinitionId = nil, nil
    end
    w.Identity, w.Tool, w.ItemId, w.Name = identity, tool, id, name
    w.Source, w.SourceObject = source or "none", sourceObject
    w.DetectedAt = os.clock()
    w.Tags = {}
    local ok, tags = pcall(function() return Tags:GetTags(tool or char) end)
    if ok and type(tags) == "table" then w.Tags = tags end
    return w
end

function GMP.hasGunIdentity(w)
    local raw = tostring((w and w.ItemId) or (w and w.Name) or ""):lower()
    for _, tag in ipairs((w and w.Tags) or {}) do
        local n = GMP.norm(tag)
        if n == "gun" or n == "firearm" then return true end
    end
    if raw:find("bow", 1, true) or raw:find("grenade", 1, true)
        or raw:find("throw", 1, true) or raw:find("melee", 1, true) then
        return false
    end
    for _, word in ipairs({ "rifle", "pistol", "revolver", "shotgun", "smg",
        "carbine", "firearm", "machinegun", "sniper", "gun", "ak47", "m4" }) do
        if raw:find(word, 1, true) then return true end
    end
    return false
end

function GMP.weaponSnapshot()
    local w = GMP.getWeapon()
    return { name = tostring(w.Name), itemId = tostring(w.ItemId),
        source = tostring(w.Source), tags = GMP.copy(w.Tags),
        definitionId = tostring(w.DefinitionId),
        manual = GMP.status.definitionSelectionStatus }
end

-- Only explicitly named numeric dispersion fields are ever written.
function GMP.isNumericSpreadName(name)
    if type(name) ~= "string" then return false end
    local key = GMP.norm(name)
    local allowed = key:find("spread", 1, true) or key:find("inaccuracy", 1, true)
        or key:find("dispersion", 1, true) or key:find("bloom", 1, true)
        or key == "cone" or key == "conesize" or key == "coneradius"
        or key == "bulletcone" or key == "shotcone"
    if not allowed then return false end
    for _, denied in ipairs({ "recovery", "recover", "cooldown", "reset",
        "decay", "duration", "interval", "rate", "time", "speed", "reduce",
        "recoil" }) do
        if key:find(denied, 1, true) then return false end
    end
    return true
end
