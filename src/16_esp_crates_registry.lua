-- ==================================================================
-- Hanami / 16_esp_crates_registry.lua — Crate live registry
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- LIVE CRATE REGISTRY
-- Feeds the shared incremental walker (02_workspace_scan.lua). No
-- GetDescendants(), no 1.5 s timer of its own: the walker yields every
-- 120 nodes so streaming / late spawns are picked up without a hitch.
-- ────────────────────────────────────────────────────────────────────

local crateList = _G.__saCrateList or {}
_G.__saCrateList = crateList

local function commitCrates(found)
    -- a crate Model and a crate-named part inside it can both match; keep
    -- only the outermost container so we don't stack two ESPs on one box
    local set = {}
    for _, d in ipairs(found) do set[d] = true end
    local out = {}
    for _, d in ipairs(found) do
        local anc, nested = d.Parent, false
        while anc do
            if set[anc] then nested = true; break end
            anc = anc.Parent
        end
        if not nested then out[#out + 1] = d end
    end
    for i = #crateList, 1, -1 do crateList[i] = nil end
    for i, d in ipairs(out) do crateList[i] = d end
    return #out
end

SA.RegisterScanHandler("crates", crateKind, commitCrates)

function SA.GetCrates()
    local out = {}
    for _, d in ipairs(crateList) do
        if d and d.Parent then out[#out + 1] = d end
    end
    return out
end

-- No-copy view for the per-frame build queue; stale parents are skipped.
function SA.CrateListRaw() return crateList end

-- Rescan buttons / enabling the ESP only ask for an early walker pass.
function SA.RefreshCrates()
    SA.RequestScan()
    return #crateList
end

function SA.CrateKind(d) return crateKind(d) end

-- The crate registry is fed only by the shared incremental walker.
