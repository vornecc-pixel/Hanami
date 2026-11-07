-- ==================================================================
-- Hanami / 16_esp_crates_registry.lua — Crate live registry + diagnostics
-- Loaded in order by loader.lua. Parts are joined into ONE chunk
-- before running, so every `local` is shared just like the original.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- LIVE CRATE REGISTRY
-- Rebuilt on a timer (and on demand) so streaming / late spawns / nested
-- models are picked up even if DescendantAdded fired too early.
-- ────────────────────────────────────────────────────────────────────
local crateList = _G.__saCrateList or {}
_G.__saCrateList = crateList
local CRATE_SCAN_INTERVAL = 1.5

local function collectCrates()
    local found = {}
    pcall(function()
        for _, d in ipairs(Workspace:GetDescendants()) do
            if crateKind(d) then found[#found + 1] = d end
        end
    end)
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

function SA.GetCrates()
    local out = {}
    for _, d in ipairs(crateList) do
        if d and d.Parent then out[#out + 1] = d end
    end
    return out
end

function SA.RefreshCrates()
    local n = collectCrates()
    if CFG.crateEnabled then
        for _, d in ipairs(SA.GetCrates()) do buildCrate(d) end
    end
    return n
end

function SA.CrateKind(d) return crateKind(d) end

-- Diagnostic: prints everything that *looks* like a container, so the
-- exact model names / attributes used by the game can be identified.
function SA.PrintCrateCandidates()
    print("════════ CRATE SCAN ════════")
    local shown, total = 0, 0
    local ok = pcall(function()
        for _, d in ipairs(Workspace:GetDescendants()) do
            local n = normKey(d.Name)
            local ours = string.sub(d.Name, 1, 6) == "Hanami"
            local hit = false
            for _, w in ipairs({ "crate", "loot", "supply", "airdrop", "cache", "chest", "stash", "box" }) do
                if n:find(w) then hit = true; break end
            end
            if not hit then
                for _, a in ipairs({ "CrateType", "Opened", "Looted", "LootTable" }) do
                    if d:GetAttribute(a) ~= nil then hit = true; break end
                end
            end
            if hit and not ours then
                total = total + 1
                local kind = crateKind(d) or "-"
                if shown < 45 and (d:IsA("Model") or d:IsA("BasePart") or d:IsA("Folder")) then
                    print(string.format("  %-30s %-9s kind=%-8s parent=%s",
                        tostring(d.Name):sub(1, 30), d.ClassName, kind,
                        tostring(d.Parent and d.Parent.Name)))
                    shown = shown + 1
                end
            end
        end
    end)
    print(string.format("  candidates: %d | classified: %d | gui objects: %d | ok: %s",
        total, #SA.GetCrates(), (function() local c = 0; for _ in pairs(crateObjects) do c = c + 1 end; return c end)(),
        tostring(ok)))
    print("  tip: if 'classified' is 0, turn Loose Crate Detection ON")
    print("═══════════════════════════")
end

-- One loop per loader run (SA.Generation stops the previous one), so
-- "Unload Everything" followed by a fresh load starts scanning again.
local crateGeneration = SA.Generation
task.spawn(function()
    while true do
        if SA.Alive == false or SA.Generation ~= crateGeneration then break end
        pcall(collectCrates)
        task.wait(CRATE_SCAN_INTERVAL)
    end
end)
