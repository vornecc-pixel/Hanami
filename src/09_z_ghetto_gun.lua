-- ==================================================================
-- Hanami / 09_z_ghetto_gun.lua — Ghetto Gun Desync (cosmetic only)
-- Loaded AFTER 09_silent_aim.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================

-- ══════════════════════════════════════════════════════════════════
-- GHETTO GUN DESYNC — local cosmetic hide + anchor (default OFF)
-- The bullet direction stays on the existing SA.ResolveShot / camera-snap
-- path. This feature only saves and restores BasePart properties on the
-- equipped Tool, camera-child viewmodel and local R6/R15 arm parts. It is
-- active whenever the guns-only silent-aim gate is ON, firing or not, and
-- never hooks a remote, rewrites shot arguments or adds a second shot path.
-- ══════════════════════════════════════════════════════════════════
if SA.GhettoGunDispose then pcall(SA.GhettoGunDispose) end
local gg = _G.__saGhettoGun or {
    originals = {}, active = false, dirty = false, reason = "idle",
    partCount = 0, counts = { tool = 0, viewmodel = 0, arms = 0, total = 0 },
    scans = 0, writes = 0, restores = 0, frame = 0, conn = nil,
}
_G.__saGhettoGun = gg
gg.originals = type(gg.originals) == "table" and gg.originals or {}
gg.counts = type(gg.counts) == "table" and gg.counts
    or { tool = 0, viewmodel = 0, arms = 0, total = 0 }
-- Defensive re-execution cleanup: an older generation should never leave a
-- second render callback behind if its disposal entry point was lost.
if gg.conn then
    local staleConn = gg.conn
    pcall(function() staleConn:Disconnect() end)
end
gg.conn = nil
gg.generation = SA.Generation

local GG_SCAN_FRAMES = 12
local GG_MAX_PARTS = 200
local GG_ARM_NAMES = {
    leftarm = true, rightarm = true,
    leftupperarm = true, rightupperarm = true,
    leftlowerarm = true, rightlowerarm = true,
    lefthand = true, righthand = true,
}

local function ggCount(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

local function ggGate()
    if SA.Alive ~= true then return false, "unloaded" end
    if CFG.ghettoGunDesync ~= true then return false, "toggle OFF" end
    if CFG.masterEnabled ~= true then return false, "master OFF" end
    if CFG.gunEnabled ~= true then return false, "gun silent aim OFF" end
    local bow = false
    pcall(function()
        if type(SA.IsEquippedBow) == "function" then
            bow = SA.IsEquippedBow() == true
        end
    end)
    if bow then return false, "bow equipped (guns only)" end
    -- Retain the single guns-only lock even if another gate is added later.
    if not saLockActive() then return false, "gun aim gate OFF" end
    return true, "active"
end

local function ggArmName(name)
    local key = tostring(name or ""):lower():gsub("[%s_%-]", "")
    return GG_ARM_NAMES[key] == true
end

local function ggRead(part, prop)
    local ok, value = pcall(function() return part[prop] end)
    return ok, value
end

local function ggWrite(part, prop, value)
    local okRead, current = ggRead(part, prop)
    if okRead and current == value then return false end
    local okWrite = pcall(function() part[prop] = value end)
    if okWrite then
        gg.writes = (gg.writes or 0) + 1
        return true
    end
    return false
end

local function ggSave(part)
    if gg.originals[part] then return end
    local saved = {}
    local okA, a = ggRead(part, "Anchored")
    local okT, t = ggRead(part, "Transparency")
    local okL, l = ggRead(part, "LocalTransparencyModifier")
    if okA then saved.hasA, saved.a = true, a end
    if okT then saved.hasT, saved.t = true, t end
    if okL then saved.hasL, saved.l = true, l end
    gg.originals[part] = saved
    gg.dirty = true
end

local function ggRestorePart(part, saved)
    if not part or not saved then return end
    local function restore(has, prop, value)
        if not has then return end
        local okRead, current = ggRead(part, prop)
        if okRead and current == value then return end
        local okWrite = pcall(function() part[prop] = value end)
        if okWrite then gg.restores = (gg.restores or 0) + 1 end
    end
    restore(saved.hasA, "Anchored", saved.a)
    restore(saved.hasT, "Transparency", saved.t)
    restore(saved.hasL, "LocalTransparencyModifier", saved.l)
    gg.originals[part] = nil
end

function SA.GhettoGunRestore()
    local rows = {}
    for part, saved in pairs(gg.originals) do
        rows[#rows + 1] = { part, saved }
    end
    for _, row in ipairs(rows) do ggRestorePart(row[1], row[2]) end
    gg.active = false
    gg.dirty = false
    gg.partCount = 0
    gg.counts = { tool = 0, viewmodel = 0, arms = 0, total = 0 }
    gg.reason = "restored"
    return true
end

function SA.GhettoGunDispose()
    if gg.conn then
        local conn = gg.conn
        pcall(function() conn:Disconnect() end)
    end
    gg.conn = nil
    SA.GhettoGunRestore()
    gg.reason = "disposed"
    return true
end

local function ggIsBasePart(obj)
    if not obj then return false end
    local ok, is = pcall(function() return obj:IsA("BasePart") end)
    return ok and is == true
end

local function ggAdd(seen, rows, counts, part, category)
    if #rows >= GG_MAX_PARTS or seen[part] then return end
    if not ggIsBasePart(part) then return end
    seen[part] = true
    rows[#rows + 1] = part
    counts.total = (counts.total or 0) + 1
    counts[category] = (counts[category] or 0) + 1
end

local function ggWalk(seen, rows, counts, root, category)
    if not root or #rows >= GG_MAX_PARTS then return end
    ggAdd(seen, rows, counts, root, category)
    local ok, descendants = pcall(function() return root:GetDescendants() end)
    if not ok or type(descendants) ~= "table" then return end
    for _, part in ipairs(descendants) do
        if #rows >= GG_MAX_PARTS then break end
        ggAdd(seen, rows, counts, part, category)
    end
end

local function ggUnder(node, ancestor)
    local p, depth = node, 0
    while p and depth < 32 do
        if p == ancestor then return true end
        p = p.Parent
        depth = depth + 1
    end
    return false
end

local function ggCollect()
    local rows = {}
    local seen = {}
    local counts = { tool = 0, viewmodel = 0, arms = 0, total = 0 }
    local char = nil
    pcall(function() char = lp.Character end)
    if not char then return rows, counts end

    local okTool, tool = pcall(function()
        return char:FindFirstChildOfClass("Tool")
    end)
    if okTool and tool then ggWalk(seen, rows, counts, tool, "tool") end

    local camera = ws.CurrentCamera
    if camera then
        local okChildren, children = pcall(function()
            return camera:GetChildren()
        end)
        if okChildren and type(children) == "table" then
            for _, child in ipairs(children) do
                if not ggUnder(child, char) then
                    ggWalk(seen, rows, counts, child, "viewmodel")
                end
            end
        end
    end

    local okCharChildren, charChildren = pcall(function()
        return char:GetChildren()
    end)
    if okCharChildren and type(charChildren) == "table" then
        for _, child in ipairs(charChildren) do
            local okName, name = pcall(function() return child.Name end)
            if okName and ggArmName(name) then
                ggAdd(seen, rows, counts, child, "arms")
            end
        end
    end
    return rows, counts
end

function SA.GhettoGunState()
    local allowed, reason = ggGate()
    return {
        enabled = CFG.ghettoGunDesync == true,
        gate = allowed,
        active = allowed and gg.active == true or false,
        parts = gg.partCount or 0,
        tracked = ggCount(gg.originals),
        toolParts = gg.counts.tool or 0,
        viewmodelParts = gg.counts.viewmodel or 0,
        armParts = gg.counts.arms or 0,
        reason = allowed and (gg.reason or "active") or reason,
        method = "hide + anchor",
        scope = "tool + camera viewmodel + local arms",
        bullets = "camera-snap resolver",
        intervalFrames = GG_SCAN_FRAMES,
        scans = gg.scans or 0,
        writes = gg.writes or 0,
        restores = gg.restores or 0,
        frames = gg.frame or 0,
        generation = gg.generation or SA.Generation,
    }
end

function SA.GhettoGunRefresh()
    local allowed, reason = ggGate()
    if not allowed then
        if gg.active or gg.dirty then SA.GhettoGunRestore() end
        gg.reason = reason
        return SA.GhettoGunState()
    end
    local rows, counts = ggCollect()
    local activeSet = {}
    for _, part in ipairs(rows) do
        activeSet[part] = true
        ggSave(part)
        ggWrite(part, "Anchored", true)
        ggWrite(part, "Transparency", 1)
        ggWrite(part, "LocalTransparencyModifier", 1)
    end
    -- A tool swap / respawn / removed viewmodel must restore only parts that
    -- left this frame's scope; still-visible parts keep their saved originals.
    local stale = {}
    for part, saved in pairs(gg.originals) do
        if not activeSet[part] then stale[#stale + 1] = { part, saved } end
    end
    for _, row in ipairs(stale) do ggRestorePart(row[1], row[2]) end
    gg.active = true
    gg.dirty = ggCount(gg.originals) > 0
    gg.partCount = #rows
    gg.counts = counts
    gg.scans = (gg.scans or 0) + 1
    gg.reason = "active"
    return SA.GhettoGunState()
end

function SA.GhettoGunTick(force)
    local allowed, reason = ggGate()
    if not allowed then
        if gg.active or gg.dirty then SA.GhettoGunRestore() end
        gg.reason = reason
        return false
    end
    gg.frame = (gg.frame or 0) + 1
    if force or gg.active ~= true or gg.frame >= GG_SCAN_FRAMES then
        gg.frame = 0
        SA.GhettoGunRefresh()
        return gg.active == true
    end
    gg.reason = "active"
    return true
end


-- Wrap instead of editing 09_silent_aim.lua's state table. Tagging the
-- wrapper lets a loader re-execute detect the fresh base function written
-- by part 09, so wrappers never stack across repeated executions.
if SA.__ggSilentAimWrapper ~= SA.SilentAimState then
    SA.__ggBaseSilentAimState = SA.SilentAimState
end
local ggBaseSilentAimState = SA.__ggBaseSilentAimState
function SA.SilentAimState()
    local state = {}
    if type(ggBaseSilentAimState) == "function" then
        local ok, base = pcall(ggBaseSilentAimState)
        if ok and type(base) == "table" then state = base end
    end
    state.ghettoGun = CFG.ghettoGunDesync == true
    state.ghettoActive = gg.active == true
    state.ghettoParts = gg.partCount or 0
    state.ghettoReason = gg.reason or "idle"
    return state
end
SA.__ggSilentAimWrapper = SA.SilentAimState

gg.conn = bindRender(function() SA.GhettoGunTick(false) end)
-- Apply a saved ON profile immediately; default OFF simply records why it is idle.
SA.GhettoGunTick(true)
