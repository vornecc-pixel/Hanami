-- ==================================================================
-- Hanami / 16_esp_crates_registry.lua — Crate live registry + diagnostics
-- Loaded in order by loader.lua. Parts are joined into ONE chunk
-- before running, so every `local` is shared just like the original.
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

-- Rescan buttons / enabling the ESP only ask for an early walker pass.
function SA.RefreshCrates()
    SA.RequestScan()
    return #crateList
end

function SA.CrateKind(d) return crateKind(d) end

-- Diagnostic: prints everything that *looks* like a container, so the
-- exact model names / attributes used by the game can be identified.
-- This is the ONLY synchronous Workspace:GetDescendants() left in the
-- script: it runs once, only when the user clicks the debug button, and is
-- never called from a timer, an event or a render loop.
-- Diagnose the opened/unopened problem: dumps every raw state signal the
-- game actually exposes, plus the resolved label, for each known crate.
function SA.PrintCrateStates()
    print("════════ CRATE STATE DEBUG ════════")
    local crates = SA.GetCrates()
    print("  known crates:", #crates, "| invert:", tostring(CFG.crateInvertState),
          "| lid detect:", tostring(CFG.crateLidDetect))
    for i, d in ipairs(crates) do
        if i > 30 then print("  … truncated"); break end
        local state = isCrateOpened(d)
        print(string.format("  %-26s -> %-9s | %s",
            tostring(d.Name):sub(1, 26), state and "OPENED" or "UNOPENED",
            crateStateDebug(d)))
    end
    print("  If every label is backwards, turn ON 'Invert Crate State'.")
    print("═══════════════════════════════════")
end

function SA.PrintCrateCandidates()
    print("════════ CRATE SCAN ════════")
    local shown, total = 0, 0
    local ok = pcall(function()
        for _, d in ipairs(Workspace:GetDescendants()) do
            local n = normKey(d.Name)
            local ours = string.sub(d.Name, 1, 6) == "Hanami"
            local hit = false
            for _, w in ipairs({ "crate", "loot", "supply", "airdrop",
                                 "cache", "chest", "stash", "box", "military", "elite" }) do
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
    local objects = 0
    for _ in pairs(crateObjects) do objects = objects + 1 end
    print(string.format("  candidates: %d | classified: %d | gui objects: %d | ok: %s",
        total, #SA.GetCrates(), objects, tostring(ok)))
    print("  draw backend:", SA.DrawBackend())
    print("  tip: if 'classified' is 0, turn Loose Crate Detection ON")
    print("═══════════════════════════")
end
