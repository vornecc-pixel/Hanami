-- ==================================================================
-- Hanami / 20_hitbox_expander.lua — Hitbox Expander v2 (silent, R6/R15)
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
--   * teamCheck uses SA.IsTeammate() (FustMates) plus a plr.Team fallback.
--   * maxDist <= 0 means unlimited. visible uses the client-only
--     LocalTransparencyModifier, so nobody else sees the debug tint.
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
local hbWatchedChar = {}
local hbScans = 0
local hbGen = SA.Generation

-- Mirror of the pasted `hitbox` table, exposed through getgenv() for
-- compatibility with scripts that poke `getgenv().hitbox` directly.
local hb = {
    enabled = false, target = "Both", mode = "fixed",
    scale = 8, cap = 8, maxDist = 300,
    teamCheck = true, aliveOnly = true, visible = false,
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
    hb.teamCheck = CFG.hitboxTeamCheck ~= false
    hb.aliveOnly = CFG.hitboxAliveOnly ~= false
    hb.visible   = CFG.hitboxVisible == true
end

local function hbClear(t)
    for k in pairs(t) do t[k] = nil end
end

local function hbCount(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
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

local function hbApplyToPart(part)
    if not part or not part.Parent or not part:IsA("BasePart") then return end
    if not hbOriginals[part] then
        hbOriginals[part] = {
            size = part.Size,
            canCollide = part.CanCollide,
            canQuery = part.CanQuery,
            canTouch = part.CanTouch,
            ltm = part.LocalTransparencyModifier,
        }
        hbInstallSizeHook(part)
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

local function hbSilenceHandle(handle)
    if not handle or not handle:IsA("BasePart") then return end
    if not hbAccessories[handle] then
        hbAccessories[handle] = { canQuery = handle.CanQuery }
    end
    pcall(function() handle.CanQuery = false end)
end

local function hbSilenceAccessories(char)
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Accessory") then
            local handle = child:FindFirstChild("Handle")
            hbSilenceHandle(handle)
        end
    end
end

local function hbApplyToChar(char)
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if hb.aliveOnly and (tonumber(hum.Health) or 0) <= 0 then return end
    if not hbInRange(char) then return end
    local names = hbTargets[hb.target] or hbTargets.Both
    for _, name in ipairs(names) do
        local part = char:FindFirstChild(name)
        if part and part:IsA("BasePart") then hbApplyToPart(part) end
    end
    hbSilenceAccessories(char)
end

local function hbWatchChar(plr, char)
    if hbCharConns[plr] and hbWatchedChar[plr] == char then return end
    local old = hbCharConns[plr]
    if old then pcall(old.Disconnect, old) end
    hbWatchedChar[plr] = char
    local ok, conn = pcall(function()
        return char.ChildAdded:Connect(function(child)
            hbSync()
            if not hb.enabled then return end
            local names = hbTargets[hb.target] or hbTargets.Both
            if child:IsA("BasePart") then
                for _, name in ipairs(names) do
                    if child.Name == name then hbApplyToPart(child) end
                end
            elseif child:IsA("Accessory") then
                hbSilenceHandle(child:FindFirstChild("Handle"))
            end
        end)
    end)
    if ok and conn then hbCharConns[plr] = conn else hbCharConns[plr] = nil end
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

function SA.HitboxRestore()
    for part in pairs(hbOriginals) do pcall(hbRestorePart, part) end
    for conn in pairs(hbSizeConns) do
        pcall(conn.Disconnect, conn)
    end
    hbClear(hbSizeConns)
    for handle, o in pairs(hbAccessories) do
        if handle and o then pcall(function() handle.CanQuery = o.canQuery end) end
    end
    hbClear(hbAccessories)
    for _, conn in pairs(hbCharConns) do pcall(conn.Disconnect, conn) end
    hbClear(hbCharConns)
    hbClear(hbWatchedChar)
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
                hbApplyToChar(char)
                hbWatchChar(plr, char)
                applied = applied + (hbCount(hbOriginals) - before)
            end
        end
    end
    -- Drop entries whose part was destroyed / reparented away.
    for part in pairs(hbOriginals) do
        if not part or not part.Parent then pcall(hbRestorePart, part) end
    end
    hbScans = hbScans + 1
    return applied
end

function SA.HitboxState()
    hbSync()
    return {
        enabled = hb.enabled, target = hb.target, mode = hb.mode,
        scale = hb.scale, cap = hb.cap, maxDist = hb.maxDist,
        teamCheck = hb.teamCheck, aliveOnly = hb.aliveOnly,
        visible = hb.visible,
        parts = hbCount(hbOriginals),
        accessories = hbCount(hbAccessories),
        sizeHooks = hbCount(hbSizeConns),
        charHooks = hbCount(hbCharConns),
        scans = hbScans,
    }
end

function SA.PrintHitbox()
    local s = SA.HitboxState()
    print(string.format(
        "[hitbox] enabled=%s target=%s mode=%s scale=%s cap=%s maxDist=%s team=%s alive=%s visible=%s | parts=%d acc=%d sizeHooks=%d charHooks=%d scans=%d",
        tostring(s.enabled), tostring(s.target), tostring(s.mode),
        tostring(s.scale), tostring(s.cap), tostring(s.maxDist),
        tostring(s.teamCheck), tostring(s.aliveOnly), tostring(s.visible),
        s.parts, s.accessories, s.sizeHooks, s.charHooks, s.scans))
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
