-- ==================================================================
-- Hanami / 03_entity_scan.lua — NPC registry + LOS visibility check
-- Loaded in order by loader.lua. Parts are joined into ONE chunk
-- before running, so every `local` is shared just like the original.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- NPC REGISTRY
-- Scans the WHOLE workspace (not just an "Npcs" folder). The expensive
-- GetDescendants() scan runs in a background task every 2 s, never on a
-- render frame; SA.GetNpcs() only walks the cached list on demand.
-- ────────────────────────────────────────────────────────────────────

local npcList = _G.__saNpcList or {}
_G.__saNpcList = npcList
local NPC_SCAN_INTERVAL = 2

local function validNpc(d)
    return d and d:IsA("Model") and isNpc(d)
        and d:FindFirstChildOfClass("Humanoid") ~= nil
        and (d:FindFirstChild("Head") or d:FindFirstChild("HumanoidRootPart")) ~= nil
        and Players:GetPlayerFromCharacter(d) == nil  -- never tag a real player as an NPC
end

local function collectNpcs()
    local found = {}
    local ok, err = pcall(function()
        for _, d in ipairs(ws:GetDescendants()) do
            if validNpc(d) then found[#found + 1] = d end
        end
    end)
    if ok then
        table.clear(npcList)
        for _, m in ipairs(found) do table.insert(npcList, m) end
    else
        dbg("npc scan failed:", err)
    end
end

function SA.GetNpcs()
    local out = {}
    for _, m in ipairs(npcList) do
        if m.Parent and m:FindFirstChildOfClass("Humanoid") then
            out[#out + 1] = m
        end
    end
    return out
end

-- force an immediate scan (used by the "Rescan NPCs" button)
function SA.RefreshNpcs()
    pcall(collectNpcs)
    return SA.GetNpcs()
end

-- One background scanner + one event pair per game session. Re-executing
-- the loader reuses the same _G.__saNpcList table, so no duplicate loops.
if not _G.__saNpcScanner then
    _G.__saNpcScanner = true
    local scanPending = false
    local function requestScan()
        if scanPending then return end
        scanPending = true
        task.spawn(function()
            task.wait(0.2)
            scanPending = false
            pcall(collectNpcs)
        end)
    end
    ws.DescendantAdded:Connect(function(d)
        if NPC_NAMES[d.Name] then requestScan() end
    end)
    ws.DescendantRemoving:Connect(function(d)
        if NPC_NAMES[d.Name] then requestScan() end
    end)
    task.spawn(function()
        while true do
            pcall(collectNpcs)
            task.wait(NPC_SCAN_INTERVAL)
        end
    end)
end

-- ────────────────────────────────────────────────────────────────────
-- VISIBILITY (LOS)
-- Cached ~120 ms per model so a 30-player server costs ~30 raycasts per
-- 0.12 s instead of 30 raycasts every single frame.
-- ────────────────────────────────────────────────────────────────────

local visParams = RaycastParams.new()
visParams.FilterType = Enum.RaycastFilterType.Exclude
visParams.IgnoreWater = true
local visCache = setmetatable({}, { __mode = "k" })
local VIS_TTL = 0.12

function SA.IsVisible(model, pos)
    if not model or not pos then return false end
    local now = tick()
    local e = visCache[model]
    if e and (now - e.t) < VIS_TTL then return e.vis end
    local cam = ws.CurrentCamera
    if not cam then return true end
    local filter = {}
    if lp.Character then table.insert(filter, lp.Character) end
    table.insert(filter, model)
    visParams.FilterDescendantsInstances = filter
    local origin = cam.CFrame.Position
    local dir = pos - origin
    local hit = ws:Raycast(origin, dir, visParams)
    local vis = (hit == nil) or (hit.Distance >= dir.Magnitude - 0.5)
    visCache[model] = { t = now, vis = vis }
    return vis
end
