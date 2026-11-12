-- ==================================================================
-- Hanami / 06_firing_and_guns.lua — Firing state (v7.7) + snap cooldown
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- FIRING STATE
-- PATCH v7.7: release also stamps `last`, so a quick tap is still inside
-- the widened 0.35 s window after MouseButton1 goes up. The old build
-- only stamped `last` on press, which made the tap window useless for
-- the very fast click that tap-fire reorder is designed to catch.
-- ────────────────────────────────────────────────────────────────────

local firing = _G.__saFiringState or { held = false, last = 0 }
_G.__saFiringState = firing
if not _G.__saInputBound then
    _G.__saInputBound = true
    SA.Connect(UserInputService.InputBegan, function(input, gp)
        if gp then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            firing.held = true; firing.last = tick()
        end
    end)
    SA.Connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            firing.held = false; firing.last = tick()
        end
    end)
end

-- GUNS ONLY: no bow draw/hold state. Silent aim bails out entirely while
-- a bow is equipped (see SA.IsEquippedBow() in 07_gun_specs.lua), so the
-- tap window only has to describe mouse presses/releases.
local function isFiring()
    if not CFG.gunShotOnly then return true end
    if firing.held then return true end
    return (tick() - firing.last) < (CFG.saTapWindow or 0.35)
end

-- ────────────────────────────────────────────────────────────────────
-- GUN HELPERS
-- Exact id/spec resolution lives in 07_gun_specs.lua (SA.GetEquippedGun).
-- The old getGunSpeed() + hardcoded GUN_SPEEDS lookup is gone.
-- ────────────────────────────────────────────────────────────────────

local gunCooldownAt = {}
local function gunCanSnap()
    if (CFG.gunCooldown or 0) <= 0 then return true end
    local ok, id = pcall(function() return SA.GetEquippedGun().id end)
    if not ok or not id then return true end
    local now = tick()
    if (gunCooldownAt[id] or 0) + CFG.gunCooldown > now then return false end
    gunCooldownAt[id] = now
    return true
end

-- ────────────────────────────────────────────────────────────────────
-- COMPLETE UNLOAD SWEEP (kept here for the 02_drawing register budget)
-- Native Drawing objects, GUI proxies and Hanami-owned ScreenGuis /
-- BillboardGuis / Highlights all live OUTSIDE Atlanta's library.guis.
-- The sweep is one-shot (called only by SA.FullUnload), so scanning the
-- small set of known parents / exact names is cheap and deterministic.
-- ────────────────────────────────────────────────────────────────────
local HANAMI_EXACT_NAMES = {
    HanamiOverlay = true, HanamiNearestPlayer = true,
    HanamiPerfOverlay = true, HanamiEspPreviewPanel = true,
    HanamiPlayerGui = true, HanamiPlayerHighlight = true,
    HanamiNpcGui = true, HanamiNpcHighlight = true,
    HanamiCrateGui = true, HanamiCrateHighlight = true,
    HanamiLocalBrightness = true, HanamiAtlantaBlur = true,
}

local function saHanamiParents()
    local out = {}
    pcall(function()
        if typeof(gethui) == "function" then
            local h = gethui()
            if h then out[#out + 1] = h end
        end
    end)
    pcall(function() out[#out + 1] = game:GetService("CoreGui") end)
    pcall(function()
        local pg = lp and (lp:FindFirstChildOfClass("PlayerGui")
            or lp:FindFirstChild("PlayerGui"))
        if pg then out[#out + 1] = pg end
    end)
    pcall(function() out[#out + 1] = game:GetService("Lighting") end)
    return out
end

local function saCollectHanamiGuis(destroy)
    local found, seen, names = {}, {}, {}
    local function add(inst)
        if not inst or seen[inst] then return end
        seen[inst] = true
        found[#found + 1] = inst
        local name = ""
        pcall(function() name = tostring(inst.Name or "") end)
        names[#names + 1] = name
        if destroy then pcall(function() inst:Destroy() end) end
    end

    for _, parent in ipairs(saHanamiParents()) do
        pcall(function()
            for _, child in ipairs(parent:GetChildren()) do
                pcall(function()
                    local name = tostring(child.Name or "")
                    if name:sub(1, 6) == "Hanami" and (
                        child:IsA("ScreenGui") or child:IsA("BlurEffect")
                        or child:IsA("ColorCorrectionEffect")) then
                        add(child)
                    end
                end)
            end
        end)
        for name in pairs(HANAMI_EXACT_NAMES) do
            pcall(function()
                local obj = parent:FindFirstChild(name)
                if obj then add(obj) end
            end)
        end
    end

    pcall(function()
        local workspace = game:GetService("Workspace")
        for _, inst in ipairs(workspace:GetDescendants()) do
            local name = ""
            pcall(function() name = tostring(inst.Name or "") end)
            if HANAMI_EXACT_NAMES[name] then add(inst) end
        end
    end)
    return found, names
end

function SA.HanamiGuiState()
    local found, names = saCollectHanamiGuis(false)
    return { total = #found, names = table.concat(names, ",") }
end

function SA.DisposeHanamiGuis()
    local found = saCollectHanamiGuis(true)
    if drawGui then pcall(function() drawGui:Destroy() end) end
    if _G.__saDrawGui then pcall(function() _G.__saDrawGui:Destroy() end) end
    drawGui, _G.__saDrawGui = nil, nil
    if _G.__saAtlantaBlur then
        pcall(function() _G.__saAtlantaBlur:Destroy() end)
    end
    _G.__saAtlantaBlur = nil
    SA.AtlantaBlur = nil
    pcall(function() SA.DrawSyncReset() end)
    proxyCount = 0
    return #found
end

function SA.DrawDisposeAll()
    local removed = 0
    for _, bucket in pairs(SA.DrawPool or {}) do
        for i = #bucket, 1, -1 do
            SA.DrawRemove(bucket[i])
            bucket[i] = nil
            removed = removed + 1
        end
    end
    local all = {}
    for d in pairs(drawRegistry) do all[#all + 1] = d end
    for _, d in ipairs(all) do
        SA.DrawRemove(d)
        removed = removed + 1
    end
    SA.DrawPool = {}
    for proxy in pairs(drawPending) do drawPending[proxy] = nil end
    return { removed = removed, state = SA.DrawState() }
end

function SA.VisualState()
    local d = SA.DrawState()
    local g = SA.HanamiGuiState()
    local c = SA.ConnectionState and SA.ConnectionState() or { tracked = 0 }
    return {
        draws = d.live, visibleDraws = d.visible, pooledDraws = d.pool,
        hanamiGuis = g.total, guis = g.names,
        connections = c.tracked,
        created = d.created, disposed = d.disposed, overlay = d.overlay,
    }
end
