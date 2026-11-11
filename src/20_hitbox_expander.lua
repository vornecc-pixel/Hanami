-- ==================================================================
-- Hanami / 20_hitbox_expander.lua — Hitbox Expander v2 (players + NPCs)
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- HITBOX EXPANDER v2
--
-- Ported from the pasted script with Hanami conventions:
--   * CFG-driven instead of a standalone `hitbox` boolean.
--   * `bindRender` (generation-guarded RenderStepped) replaces a raw
--     Heartbeat connection, so re-execute / Unload Everything disconnect
--     the loop. The instant Size-revert hook is kept for self-healing.
--   * Originals / connections live in `_G` so a loader re-execute can
--     still restore parts expanded by the previous chunk.
--   * Accessory Handle.CanQuery is saved and restored too (the pasted
--     script left it permanently false).
--   * `table.clear` is Roblox-only; replaced with a portable clear loop.
--   * teamCheck uses SA.IsTeammate() (FustMates) plus a plr.Team fallback;
--     it filters PLAYERS only, never the neutral NPC registry.
--   * NPC models come from the same live registry used by NPC ESP. A raw
--     list view avoids a fresh filtered copy every render frame. NPCs with
--     no UpperTorso / LowerTorso / Torso fall back to HumanoidRootPart.
--   * maxDist <= 0 means unlimited. visible uses the client-only
--     LocalTransparencyModifier, so nobody else sees the tint.
-- ────────────────────────────────────────────────────────────────────

local hbTargets = {
    Head  = { "Head" },
    Torso = { "UpperTorso", "LowerTorso", "Torso" },
    Both  = { "Head", "UpperTorso", "LowerTorso", "Torso" },
}

-- Persist across loader re-executes. Connections from the previous chunk
-- still reference the current CFG / hb globals, so they keep working.
local hbOriginals = _G.__saHitboxOriginals or {}
_G.__saHitboxOriginals = hbOriginals
local hbAccessories = _G.__saHitboxAccessories or {}
_G.__saHitboxAccessories = hbAccessories
local hbSizeConns = _G.__saHitboxSizeConns or {}
_G.__saHitboxSizeConns = hbSizeConns
local hbCharConns = _G.__saHitboxCharConns or {}
_G.__saHitboxCharConns = hbCharConns
local hbNpcWatches = _G.__saHitboxNpcWatches or {}
_G.__saHitboxNpcWatches = hbNpcWatches
local hbWatchedChar = {}
local hbScans = 0
local hbGen = SA.Generation

-- Mirror of the pasted `hitbox` table, exposed through getgenv() for
-- compatibility with scripts that poke `getgenv().hitbox` directly.
local hb = {
    enabled = false, target = "Both", mode = "fixed",
    scale = 8, cap = 8, maxDist = 300,
    teamCheck = true, aliveOnly = true, visible = false, npcs = true,
    originals = hbOriginals, accessories = hbAccessories,
    sizeConns = hbSizeConns, charConns = hbCharConns,
}
if type(getgenv) == "function" then
    pcall(function() getgenv().hitbox = hb end)
end

local function hbSync()
    hb.enabled   = CFG.hitboxEnabled == true
    hb.target    = CFG.hitboxTarget or "Both"
    hb.mode      = CFG.hitboxMode or "fixed"
    hb.scale     = tonumber(CFG.hitboxScale) or 8
    hb.cap       = tonumber(CFG.hitboxCap) or 8
    hb.maxDist   = tonumber(CFG.hitboxMaxDist) or 300
    hb.teamCheck = CFG.hitboxTeamCheck == true
    hb.aliveOnly = CFG.hitboxAliveOnly == true
    hb.visible   = CFG.hitboxVisible == true
    hb.npcs      = CFG.hitboxNpcs == true
end

local function hbClear(t)
    for k in pairs(t) do t[k] = nil end
end

local function hbCount(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

local function hbCountNpcParts()
    local n = 0
    for _, o in pairs(hbOriginals) do
        if o and o.npcOwner ~= nil then n = n + 1 end
    end
    return n
end

local function hbIsEnemy(plr)
    if not hb.teamCheck then return true end
    if type(SA.IsTeammate) == "function" then
        local ok, mate = pcall(SA.IsTeammate, plr)
        if ok and mate then return false end
    end
    local myTeam, theirTeam = lp.Team, plr.Team
    if myTeam and theirTeam then return myTeam ~= theirTeam end
    return true
end

local function hbInRange(char)
    local d = tonumber(hb.maxDist) or 0
    if d <= 0 then return true end
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local myHrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
    if not hrp or not myHrp then return true end
    return (hrp.Position - myHrp.Position).Magnitude <= d
end

local function hbComputeTargetSize(part)
    local o = (hbOriginals[part] and hbOriginals[part].size) or part.Size
    if hb.mode == "multiply" then
        local scaled = o * hb.scale
        local mx = math.max(scaled.X, scaled.Y, scaled.Z)
        if mx > hb.cap and mx > 0 then
            return scaled * (hb.cap / mx)
        end
        return scaled
    end
    local s = hb.scale
    return Vector3.new(s, s, s)
end

-- Instant re-apply on a server Size revert (1–2 frame window).
local function hbOnSizeChanged(part)
    hbSync()
    if not hb.enabled then return end
    if not part or not part.Parent then return end
    local want = hbComputeTargetSize(part)
    local ok, diff = pcall(function() return (part.Size - want).Magnitude end)
    if ok and diff > 0.005 then pcall(function() part.Size = want end) end
end

local function hbInstallSizeHook(part)
    if hbSizeConns[part] then return end
    if type(part.GetPropertyChangedSignal) ~= "function" then return end
    local ok, signal = pcall(function() return part:GetPropertyChangedSignal("Size") end)
    if not ok or not signal then return end
    local conn
    local okConnect = pcall(function()
        conn = signal:Connect(function() pcall(hbOnSizeChanged, part) end)
    end)
    if okConnect and conn then hbSizeConns[part] = conn end
end

-- npcOwner is the NPC Model for registry entries and nil for player rigs.
-- It lets the NPC toggle restore ONLY NPC-owned originals while leaving
-- player hitboxes expanded.
local function hbApplyToPart(part, npcOwner)
    if not part or not part.Parent or not part:IsA("BasePart") then return end
    if not hbOriginals[part] then
        hbOriginals[part] = {
            size = part.Size,
            canCollide = part.CanCollide,
            canQuery = part.CanQuery,
            canTouch = part.CanTouch,
            ltm = part.LocalTransparencyModifier,
            npcOwner = npcOwner,
        }
        hbInstallSizeHook(part)
    elseif npcOwner ~= nil then
        hbOriginals[part].npcOwner = npcOwner
    end
    local want = hbComputeTargetSize(part)
    local ok, diff = pcall(function() return (part.Size - want).Magnitude end)
    if ok and diff > 0.005 then pcall(function() part.Size = want end) end
    pcall(function()
        part.CanCollide = false
        part.CanTouch = false
        part.CanQuery = true
        part.LocalTransparencyModifier = hb.visible and 0.55 or 0
    end)
end

local function hbSilenceHandle(handle, npcOwner)
    if not handle or not handle:IsA("BasePart") then return end
    if not hbAccessories[handle] then
        hbAccessories[handle] = { canQuery = handle.CanQuery, npcOwner = npcOwner }
    elseif npcOwner ~= nil then
        hbAccessories[handle].npcOwner = npcOwner
    end
    pcall(function() handle.CanQuery = false end)
end

local function hbSilenceAccessories(char, npcOwner)
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Accessory") then
            local handle = child:FindFirstChild("Handle")
            hbSilenceHandle(handle, npcOwner)
        end
    end
end

-- Some NPC rigs expose only Head + HumanoidRootPart. In that case the HRP
-- is the only expandable torso proxy; never add it to a normal player rig.
local function hbNpcNeedsRootPart(char)
    local head = char:FindFirstChild("Head")
    local hasHead = head ~= nil and head:IsA("BasePart")
    local hasTorso = false
    for _, name in ipairs(hbTargets.Torso) do
        local part = char:FindFirstChild(name)
        if part and part:IsA("BasePart") then
            hasTorso = true
            break
        end
    end
    if hb.target == "Head" then return not hasHead end
    if hb.target == "Torso" then return not hasTorso end
    return not hasHead or not hasTorso
end

local function hbApplyRig(char, npcOwner)
    local names = hbTargets[hb.target] or hbTargets.Both
    for _, name in ipairs(names) do
        local part = char:FindFirstChild(name)
        if part and part:IsA("BasePart") then hbApplyToPart(part, npcOwner) end
    end
    if npcOwner ~= nil and hbNpcNeedsRootPart(char) then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp and hrp:IsA("BasePart") then hbApplyToPart(hrp, npcOwner) end
    end
end

local function hbApplyToChar(char, isNpc)
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if hb.aliveOnly and (tonumber(hum.Health) or 0) <= 0 then return end
    if not hbInRange(char) then return end
    local npcOwner = isNpc and char or nil
    hbApplyRig(char, npcOwner)
    hbSilenceAccessories(char, npcOwner)
end

local function hbWatchChar(owner, char, isNpc)
    if hbCharConns[owner] and hbWatchedChar[owner] == char then return end
    local old = hbCharConns[owner]
    if old then pcall(old.Disconnect, old) end
    hbWatchedChar[owner] = char
    local npcOwner = isNpc and char or nil
    local ok, conn = pcall(function()
        return char.ChildAdded:Connect(function(child)
            hbSync()
            if not hb.enabled then return end
            if isNpc and not hb.npcs then return end
            if child:IsA("BasePart") then
                if isNpc then
                    hbApplyToChar(char, true)
                else
                    local names = hbTargets[hb.target] or hbTargets.Both
                    for _, name in ipairs(names) do
                        if child.Name == name then hbApplyToPart(child) end
                    end
                end
            elseif child:IsA("Accessory") then
                hbSilenceHandle(child:FindFirstChild("Handle"), npcOwner)
            end
        end)
    end)
    if ok and conn then hbCharConns[owner] = conn else hbCharConns[owner] = nil end
end

local function hbRestorePart(part)
    -- Disconnect the self-healing hook FIRST: restoring Size would otherwise
    -- fire it and immediately re-expand the part.
    local conn = hbSizeConns[part]
    if conn then
        pcall(conn.Disconnect, conn)
        hbSizeConns[part] = nil
    end
    local o = hbOriginals[part]
    if o and part and part.Parent then
        pcall(function()
            part.Size = o.size
            part.CanCollide = o.canCollide
            part.CanTouch = o.canTouch
            part.CanQuery = o.canQuery
            part.LocalTransparencyModifier = o.ltm or 0
        end)
    end
    hbOriginals[part] = nil
end

local function hbRestoreHandle(handle, o)
    if handle and o then
        pcall(function() handle.CanQuery = o.canQuery end)
    end
    hbAccessories[handle] = nil
end

-- Bounded ancestry check: restore parts / handles owned by a removed NPC
-- even when an original was saved by an older chunk without npcOwner.
local function hbIsUnder(part, model)
    local node = part
    for _ = 1, 16 do
        if node == model then return true end
        local ok, parent = pcall(function() return node.Parent end)
        if not ok or not parent then return false end
        node = parent
    end
    return false
end

local function hbRestoreNpcOwned(owner)
    for part, o in pairs(hbOriginals) do
        if o and ((owner == nil and o.npcOwner ~= nil)
            or (owner ~= nil and (o.npcOwner == owner or hbIsUnder(part, owner)))) then
            pcall(hbRestorePart, part)
        end
    end
    for handle, o in pairs(hbAccessories) do
        if o and ((owner == nil and o.npcOwner ~= nil)
            or (owner ~= nil and (o.npcOwner == owner or hbIsUnder(handle, owner)))) then
            pcall(hbRestoreHandle, handle, o)
        end
    end
end

local function hbModelAlive(model)
    local ok, parent = pcall(function() return model.Parent end)
    return ok and parent ~= nil
end

local function hbPruneNpcWatches(seen)
    for model in pairs(hbNpcWatches) do
        if not seen[model] or not hbModelAlive(model) then
            hbRestoreNpcOwned(model)
            local conn = hbCharConns[model]
            if conn then pcall(conn.Disconnect, conn) end
            hbCharConns[model] = nil
            hbWatchedChar[model] = nil
            hbNpcWatches[model] = nil
        end
    end
end

function SA.HitboxRestore()
    for part in pairs(hbOriginals) do pcall(hbRestorePart, part) end
    for conn in pairs(hbSizeConns) do
        pcall(conn.Disconnect, conn)
    end
    hbClear(hbSizeConns)
    for handle, o in pairs(hbAccessories) do pcall(hbRestoreHandle, handle, o) end
    hbClear(hbAccessories)
    for _, conn in pairs(hbCharConns) do pcall(conn.Disconnect, conn) end
    hbClear(hbCharConns)
    hbClear(hbWatchedChar)
    hbClear(hbNpcWatches)
    if _G.__saHitboxPlayerRemovingConn then
        pcall(_G.__saHitboxPlayerRemovingConn.Disconnect,
            _G.__saHitboxPlayerRemovingConn)
        _G.__saHitboxPlayerRemovingConn = nil
    end
    _G.__saHitboxPlayerRemovingBound = false
    hbSync()
    return true
end

local function hbEnsurePlayerRemoving()
    if _G.__saHitboxPlayerRemovingBound then return end
    local ok, conn = pcall(function()
        return Players.PlayerRemoving:Connect(function(plr)
            local c = hbCharConns[plr]
            if c then pcall(c.Disconnect, c) end
            hbCharConns[plr] = nil
            hbWatchedChar[plr] = nil
        end)
    end)
    if ok and conn then
        _G.__saHitboxPlayerRemovingConn = conn
        _G.__saHitboxPlayerRemovingBound = true
    end
end

-- Prefer the live raw NPC list: the render loop already uses it, and it does
-- not allocate a filtered copy every frame. GetNpcs() remains a fallback.
local function hbNpcList()
    if type(SA.NpcListRaw) == "function" then
        local ok, list = pcall(SA.NpcListRaw)
        if ok and type(list) == "table" then return list end
    end
    if type(SA.GetNpcs) == "function" then
        local ok, list = pcall(SA.GetNpcs)
        if ok and type(list) == "table" then return list end
    end
    return nil
end

-- The registry already classified these models. Keep this guard cheap and
-- read-only: no SA.IsNpcModel() copy, no raycast, no CanQuery write.
local function hbNpcValid(model)
    if not model then return false end
    local okModel, isModel = pcall(function() return model:IsA("Model") end)
    if not okModel or not isModel then return false end
    if not hbModelAlive(model) then return false end
    if model == lp.Character then return false end
    local okPlr, plr = pcall(function()
        return Players:GetPlayerFromCharacter(model)
    end)
    if okPlr and plr then return false end
    local okHum, hum = pcall(function()
        return model:FindFirstChildOfClass("Humanoid")
    end)
    return okHum and hum ~= nil
end

local function hbScanNpcs()
    if not hb.npcs then
        hbRestoreNpcOwned(nil)
        hbPruneNpcWatches({})
        return 0
    end
    local list = hbNpcList()
    if not list then return 0 end
    local seen, applied = {}, 0
    for _, model in ipairs(list) do
        if not seen[model] and hbNpcValid(model) then
            seen[model] = true
            hbNpcWatches[model] = true
            local before = hbCount(hbOriginals)
            hbApplyToChar(model, true)
            hbWatchChar(model, model, true)
            applied = applied + (hbCount(hbOriginals) - before)
        end
    end
    hbPruneNpcWatches(seen)
    return math.max(0, applied)
end

function SA.HitboxScan()
    hbSync()
    if not hb.enabled or SA.Alive ~= true then return 0 end
    hbEnsurePlayerRemoving()
    local applied = 0
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= lp and hbIsEnemy(plr) then
            local char = plr.Character
            if char then
                local before = hbCount(hbOriginals)
                hbApplyToChar(char, false)
                hbWatchChar(plr, char, false)
                applied = applied + (hbCount(hbOriginals) - before)
            end
        end
    end
    applied = applied + hbScanNpcs()
    -- Drop entries whose part was destroyed / reparented away.
    for part in pairs(hbOriginals) do
        if not part or not part.Parent then pcall(hbRestorePart, part) end
    end
    hbScans = hbScans + 1
    return math.max(0, applied)
end

function SA.HitboxState()
    hbSync()
    return {
        enabled = hb.enabled, target = hb.target, mode = hb.mode,
        scale = hb.scale, cap = hb.cap, maxDist = hb.maxDist,
        teamCheck = hb.teamCheck, aliveOnly = hb.aliveOnly,
        visible = hb.visible, npcs = hb.npcs,
        parts = hbCount(hbOriginals),
        npcParts = hbCountNpcParts(),
        npcModels = hbCount(hbNpcWatches),
        accessories = hbCount(hbAccessories),
        sizeHooks = hbCount(hbSizeConns),
        charHooks = hbCount(hbCharConns),
        scans = hbScans,
    }
end


local function hbTick()
    hbSync()
    if not hb.enabled or SA.Alive ~= true then
        if next(hbOriginals) or next(hbAccessories) or next(hbSizeConns)
            or next(hbCharConns) then
            pcall(SA.HitboxRestore)
        end
        return
    end
    pcall(SA.HitboxScan)
end

bindRender(function() pcall(hbTick) end)
