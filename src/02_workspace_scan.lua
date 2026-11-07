-- ==================================================================
-- Hanami / 02_workspace_scan.lua — ONE shared, incremental Workspace walker
-- Loaded in order by loader.lua. Parts are joined into ONE chunk
-- before running, so every `local` is shared just like the original.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- FIX for the ~3 second frame skip
-- The NPC scanner ran `Workspace:GetDescendants()` every 2 s and the crate
-- scanner ran it again every 1.5 s (plus on every toggle / new part). On a
-- big map that single call freezes the whole render thread for seconds.
--
-- There is now exactly ONE breadth-first walker for the entire script. It
-- visits at most SCAN_BUDGET nodes per frame and then YIELDS. It never
-- calls GetDescendants() at all — it uses GetChildren() level by level —
-- so 10 000 descendants cost ~83 short frames instead of one long freeze.
-- Consumers register a predicate + commit callback; both scanners, the FOV
-- overlay etc. share this single pass.
-- ────────────────────────────────────────────────────────────────────

local WS = game:GetService("Workspace")
local SCAN_BUDGET = 120          -- nodes inspected per frame
local SCAN_REST   = 2.5          -- seconds between completed passes
local handlers   = {}
local frontier   = { WS }
local nextLevel  = {}
local fi         = 1
local hits       = {}
local scanning   = false
local lastCommit = 0
local forcePass  = false
local scanGen    = SA.Generation or 0
local scanPass   = 0

function SA.RegisterScanHandler(key, predicate, commit)
    handlers[key] = { predicate = predicate, commit = commit }
    hits[key] = hits[key] or {}
end

local function beginPass()
    frontier   = { WS }
    nextLevel  = {}
    fi         = 1
    for k in pairs(handlers) do hits[k] = {} end
    scanning   = true
    forcePass  = false        -- request is consumed when the pass begins
end

local function finishPass()
    scanning   = false
    lastCommit = tick()
    scanPass   = scanPass + 1
    for k, h in pairs(handlers) do
        if h.commit then
            pcall(h.commit, hits[k] or {})
        end
    end
end

-- returns true while there is still work left in this pass
local function stepPass()
    local used = 0
    while used < SCAN_BUDGET do
        local node = frontier[fi]
        if not node then
            if #nextLevel == 0 then return false end
            frontier, nextLevel, fi = nextLevel, {}, 1
        else
            fi = fi + 1
            used = used + 1
            local ok, children = pcall(function() return node:GetChildren() end)
            if ok and children then
                local lenOk, n = pcall(function() return #children end)
                if lenOk and type(n) == "number" then
                    for i = 1, n do nextLevel[#nextLevel + 1] = children[i] end
                end
            end
            for k, h in pairs(handlers) do
                local okm, match = pcall(h.predicate, node)
                if okm and match then
                    local bucket = hits[k]
                    bucket[#bucket + 1] = node
                end
            end
        end
    end
    return true
end

-- Ask for a fresh pass soon. Cheap and safe to call from DescendantAdded,
-- toggles and buttons — it never scans inline.
function SA.RequestScan()
    forcePass = true
    if not scanning then beginPass() end
end

function SA.ScanNow() beginPass() end
function SA.WorkspacePass() return scanPass end

-- One long-lived task per script generation. Stale generations exit so
-- re-executing the loader does not leave two walkers running.
task.spawn(function()
    task.wait(0.3)
    while SA.Alive and (SA.Generation or 0) == scanGen do
        if not scanning and (forcePass or (tick() - lastCommit) >= SCAN_REST) then
            beginPass()
        end
        if scanning then
            local ok, more = pcall(stepPass)
            if not (ok and more) then finishPass() end
            task.wait()                       -- yield: no frame is ever blocked
        else
            task.wait(0.2)
        end
    end
end)
