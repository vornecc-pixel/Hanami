-- ==================================================================
-- Hanami / 03_entity_scan.lua — NPC registry + LOS visibility check
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- NPC REGISTRY
-- Feeds the shared incremental walker in 02_workspace_scan.lua. No
-- GetDescendants() and no per-frame work: the walker yields every 120
-- nodes, so a big map never freezes a frame.
-- ────────────────────────────────────────────────────────────────────

local npcList = _G.__saNpcList or {}
_G.__saNpcList = npcList

local function validNpc(d)
    if not d or not d:IsA("Model") then return false end
    if not isNpc(d) then return false end
    if not d:FindFirstChildOfClass("Humanoid") then return false end
    if not (d:FindFirstChild("Head") or d:FindFirstChild("HumanoidRootPart")) then
        return false
    end
    return Players:GetPlayerFromCharacter(d) == nil  -- never tag a real player
end

local function commitNpcs(found)
    for i = #npcList, 1, -1 do npcList[i] = nil end
    for _, m in ipairs(found) do npcList[#npcList + 1] = m end
end

SA.RegisterScanHandler("npcs", validNpc, commitNpcs)

function SA.GetNpcs()
    local out = {}
    for _, m in ipairs(npcList) do
        if m.Parent and m:FindFirstChildOfClass("Humanoid") then
            out[#out + 1] = m
        end
    end
    return out
end

-- The render loop walks this live list directly instead of allocating a
-- filtered copy every frame. Invalid entries are skipped by buildBatch().
function SA.NpcListRaw() return npcList end

-- Rescan buttons just ask the shared walker for an early pass; no
-- synchronous full-workspace scan can stall the client here.
function SA.RefreshNpcs()
    SA.RequestScan()
    return SA.GetNpcs()
end

if not _G.__saNpcEvents then
    _G.__saNpcEvents = true
    ws.DescendantAdded:Connect(function(d)
        if NPC_NAMES[d.Name] then SA.RequestScan() end
    end)
    ws.DescendantRemoving:Connect(function(d)
        if NPC_NAMES[d.Name] then SA.RequestScan() end
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
    -- A single LOS failure must not abort the whole ESP refresh loop.
    -- Zero-length rays are degenerate; treat them as "visible".
    local ok, vis = pcall(function()
        local filter = {}
        if lp.Character then table.insert(filter, lp.Character) end
        table.insert(filter, model)
        visParams.FilterDescendantsInstances = filter
        local origin = cam.CFrame.Position
        local dir = pos - origin
        local mag = dir.Magnitude
        if mag < 0.001 then return true end
        local hit = ws:Raycast(origin, dir, visParams)
        return (hit == nil) or (hit.Distance >= mag - 0.5)
    end)
    if not ok then return true end
    visCache[model] = { t = now, vis = vis }
    return vis
end
