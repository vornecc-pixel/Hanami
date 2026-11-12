-- ==================================================================
-- Hanami / 04_entity_info.lua — Entity scanner (weapon/tool + state)
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- ENTITY SCANNER
-- Finds an equipped Tool (or ItemId / Weapon / HeldItem attributes and
-- common weapon containers), then resolves state from game-specific
-- attributes before falling back to HumanoidStateType.
-- Works for BOTH player characters and Guard/Scavenger/Soldier models.
-- ────────────────────────────────────────────────────────────────────

local TOOL_ATTRS  = { "ItemId", "Weapon", "WeaponId", "HeldItem", "Item", "Gun", "ToolId" }
local STATE_ATTRS = { "State", "Status", "AliveState", "Knocked", "Downed",
                      "IsDown", "Dead", "IsDead", "Ragdolled", "Stunned", "IsStunned" }
local TOOL_CHILDREN = { "Weapon", "Item", "HeldItem", "CurrentWeapon", "Tool", "Gun" }
local EQUIP_ATTRS = { "Equipped", "IsEquipped", "WeaponEquipped", "GunEquipped",
                      "WeaponOut", "HasWeaponOut" }
local HOLSTER_ATTRS = { "Holstered", "IsHolstered", "WeaponHolstered",
                        "GunHolstered", "HolsteredWeapon", "HolsteredItem",
                        "WeaponState", "GunState" }
local HOLSTER_CHILDREN = { "Holster", "HolsteredWeapon", "HolsteredItem",
                           "SheathedWeapon", "BackWeapon", "GunHolster" }

local function firstAttr(inst, names)
    for _, n in ipairs(names) do
        local v = inst:GetAttribute(n)
        if v ~= nil and v ~= "" and v ~= false then return tostring(v) end
    end
    return nil
end

function SA.GetTool(model)
    if not model then return "None" end
    local tool = model:FindFirstChildOfClass("Tool")
    if tool then return firstAttr(tool, TOOL_ATTRS) or tool.Name end
    -- Some executors expose only FindFirstChild / GetChildren on models.
    for _, c in ipairs(model:GetChildren()) do
        if c:IsA("Tool") then
            return firstAttr(c, TOOL_ATTRS) or c.Name
        end
    end
    for _, n in ipairs(TOOL_CHILDREN) do
        local c = model:FindFirstChild(n)
        if c then
            if c:IsA("StringValue") or c:IsA("IntValue") or c:IsA("ObjectValue") then
                return tostring(c.Value)
            end
            return firstAttr(c, TOOL_ATTRS) or c.Name
        end
    end
    return firstAttr(model, TOOL_ATTRS) or "None"
end

-- The nearest-player profile card shows BOTH the resolved weapon name and
-- a separate Equipped / Holstered / Unknown state. A Tool child means the
-- game has an actually equipped tool; common game attributes and holster
-- containers classify the remaining cases without guessing from thin air.
function SA.GetWeaponStatus(model)
    local tool = SA.GetTool(model)
    local hasTool, equippedAttr, holster = false, nil, nil
    pcall(function()
        if model:FindFirstChildOfClass("Tool") then hasTool = true end
        if not hasTool then
            for _, c in ipairs(model:GetChildren()) do
                if c:IsA("Tool") then hasTool = true; break end
            end
        end
    end)
    pcall(function() equippedAttr = firstAttr(model, EQUIP_ATTRS) end)
    pcall(function()
        for _, n in ipairs(HOLSTER_ATTRS) do
            local v = model:GetAttribute(n)
            if v ~= nil and v ~= false and v ~= "" then
                if type(v) == "string" or type(v) == "number" then
                    holster = tostring(v)
                else
                    holster = n
                end
                return
            end
        end
        for _, n in ipairs(HOLSTER_CHILDREN) do
            local c = model:FindFirstChild(n)
            if c then
                local ok, v = pcall(function() return c.Value end)
                holster = (ok and v ~= nil and v ~= "") and tostring(v) or n
                return
            end
        end
    end)
    local state = "Unknown"
    if hasTool or equippedAttr or (tool ~= "None" and not holster) then
        state = "Equipped"
    elseif holster then
        state = "Holstered"
    end
    return {
        tool = tostring(tool), state = state, holster = holster,
        label = state .. ": " .. tostring(tool),
        chip = string.upper(state),
    }
end

function SA.GetState(model, hum)
    if not model then return "?" end
    for _, n in ipairs(STATE_ATTRS) do
        local v = model:GetAttribute(n)
        if v ~= nil and v ~= false and v ~= "" then
            if type(v) == "boolean" then
                if v then return n end
            else
                return tostring(v)
            end
        end
    end
    if hum then
        if hum.Health <= 0 then return "Dead" end
        local ok, state = pcall(function() return hum:GetState() end)
        if ok and state then
            return (tostring(state):gsub("Enum%.HumanoidStateType%.", ""))
        end
    end
    return "Alive"
end

-- Tool/state strings barely change, so cache them ~0.25 s per model.
-- (ESP visibility colours use SA.IsVisible directly and stay frame-fresh.)
local scanCache = setmetatable({}, { __mode = "k" })
local SCAN_TTL = 0.25

function SA.ScanEntity(model, hum)
    local now = tick()
    local c = scanCache[model]
    if c and (now - c.t) < SCAN_TTL then return c.info end
    local hrp = model and (model:FindFirstChild("HumanoidRootPart")
        or model:FindFirstChild("Head"))
    local pos = hrp and hrp.Position or nil
    local dist = 0
    if pos and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
        dist = (lp.Character.HumanoidRootPart.Position - pos).Magnitude
    end
    local info = {
        name      = model and model.Name or "?",
        tool      = SA.GetTool(model),
        state     = SA.GetState(model, hum),
        health    = hum and math.floor(hum.Health) or 0,
        maxHealth = hum and math.floor(hum.MaxHealth) or 0,
        dist      = dist,
        meters    = math.floor(dist / (SA.STUDS_PER_METER or 3.571)),
        visible   = SA.IsVisible(model, pos),
    }
    scanCache[model] = { t = now, info = info }
    return info
end

-- ────────────────────────────────────────────────────────────────────
-- STAFF / ADMIN ROLE TAG (read-only)
-- Two public sources, both replicated to the client:
--   1. Fust StaffState player attributes (the StaffState.KEYS list) and
--      the AdminMovedAt heuristic.
--   2. Public rank text: team name plus ordinary replicated attributes.
-- This classifier only READS them for an ESP tag. It never warns, never
-- notifies, never writes an attribute and never changes aim / gun / world
-- state. Missing data simply means "no evidence" for that source.
-- ────────────────────────────────────────────────────────────────────
local STAFF_ATTR_KEYS = {
    "AdminRole", "AdminESP", "AdminFly", "AdminGhost", "AdminMasterOff",
    "FustTester", "StaffPvP", "StaffPvPLockUntil", "StaffPvPExempt",
    "AdminGod", "FustStaffAv",
}
-- Attributes that mean ADMIN on their own (AdminESP is only a flag).
local ADMIN_ATTR_KEYS = {
    AdminRole = true, AdminGod = true, AdminMasterOff = true,
    AdminFly = true, AdminGhost = true,
}
local PUBLIC_RANK_KEYS = { "StaffRank", "GroupRank", "Rank", "Role", "TeamRole" }
local STAFF_RANK_WORDS = {
    "staff", "mod", "moderator", "admin", "administrator", "owner",
    "developer", "manager", "tester", "supervisor",
}
local ADMIN_RANK_WORDS = { "admin", "administrator", "owner", "developer" }
-- Only teams that literally say "admin" upgrade the tag to ADMIN; a
-- "Staff" / "Moderator" team stays STAFF.
local ADMIN_TEAM_NAMES = {
    Admin = true, Admins = true, ["Admin Team"] = true,
    Administrators = true,
}

local function staffWordHit(text, words)
    local s = tostring(text or ""):lower()
    if s == "" then return false end
    for _, word in ipairs(words) do
        if s:find(word, 1, true) then return true end
    end
    return false
end

local function staffPublicRank(plr)
    local team = plr.Team
    local teamName = team and team.Name or nil
    if teamName and ADMIN_TEAM_NAMES[teamName] then
        return "team " .. tostring(teamName), true
    end
    if staffWordHit(teamName, STAFF_RANK_WORDS) then
        -- A team named exactly "Admin" is matched above; every other staff
        -- word (Staff / Moderator / Tester) stays STAFF.
        return "team " .. tostring(teamName), false
    end
    for _, key in ipairs(PUBLIC_RANK_KEYS) do
        local ok, value = pcall(function() return plr:GetAttribute(key) end)
        if ok and value ~= nil and value ~= false and value ~= "" then
            local text = tostring(value)
            if staffWordHit(text, STAFF_RANK_WORDS) then
                return key .. "=" .. text, staffWordHit(text, ADMIN_RANK_WORDS)
            end
        end
    end
    return nil, false
end

-- Returns { staff, admin, role = "STAFF"/"ADMIN"/"NONE", reason, adminFlag }.
-- `plr` is the Player instance (attributes replicate there); `model` is an
-- optional fallback attribute host for games that mirror them on the rig.
function SA.GetStaffRole(plr, model)
    local out = { staff = false, admin = false, role = "NONE",
        reason = nil, adminFlag = nil }
    if not plr then return out end
    local hosts = { plr }
    if model then hosts[#hosts + 1] = model end
    local attrHits, adminFlag = {}, nil
    for _, host in ipairs(hosts) do
        for _, key in ipairs(STAFF_ATTR_KEYS) do
            local ok, value = pcall(function() return host:GetAttribute(key) end)
            if ok and value ~= nil and value ~= false then
                attrHits[#attrHits + 1] = key
                if key == "AdminESP" and adminFlag == nil then adminFlag = key end
            end
        end
    end
    local moved = false
    pcall(function() moved = plr:GetAttribute("AdminMovedAt") ~= nil end)
    local rankReason, rankAdmin = staffPublicRank(plr)
    local attrAdmin = false
    for _, key in ipairs(attrHits) do
        if ADMIN_ATTR_KEYS[key] then attrAdmin = true end
    end
    if #attrHits > 0 then
        out.staff = true
        out.reason = attrHits[1]
    elseif moved then
        out.staff = true
        out.reason = "AdminMovedAt"
    elseif rankReason then
        out.staff = true
        out.reason = rankReason
    end
    out.admin = out.staff and (attrAdmin or rankAdmin == true)
    if out.admin then out.role = "ADMIN"
    elseif out.staff then out.role = "STAFF" end
    out.adminFlag = adminFlag
    return out
end

-- ────────────────────────────────────────────────────────────────────
-- 3-CONSECUTIVE-SCAN CONFIRMATION (StreamingEnabled false-positive fix)
-- The role tag used to be drawn from ONE read of the replicated data. With
-- StreamingEnabled a character streams in part by part: for a few frames
-- the rig can be missing a Humanoid / Head, or the attributes are simply
-- not replicated yet, and a single unlucky read produced a bogus STAFF
-- tag on an ordinary player ("INVIS" in the reported build). The exact
-- same replicated evidence is now required on THREE consecutive scans
-- before the watch flags anyone; any missing / negative / plain read
-- resets the streak to zero. Nothing is written, warned or notified — the
-- detector still only READS, it just refuses to answer from one sample.
-- ────────────────────────────────────────────────────────────────────
SA.STAFF_CONFIRM_SCANS = 3
local staffStreak = _G.__saStaffStreak or setmetatable({}, { __mode = "k" })
_G.__saStaffStreak = staffStreak
local staffScanPass = 0

-- true when the rig is fully streamed in and can be classified at all.
local function staffRigReady(plr, model)
    if not plr or not plr.Parent then return false end
    local char = model or plr.Character
    if not char or not char.Parent then return false end
    local ok, ready = pcall(function()
        if not char:FindFirstChildOfClass("Humanoid") then return false end
        return (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
            ~= nil
    end)
    return ok and ready == true
end

-- One confirmation sample for ONE player. Returns the confirmed role
-- table (role STAFF / ADMIN) or nil while the evidence is not yet
-- confirmed. `sample == false` records an unknown sample instead.
function SA.StaffScanOne(plr, model, sample)
    if not plr then return nil end
    local st = staffStreak[plr]
    if not st then
        st = { streak = 0, scans = 0, role = "NONE", reason = nil,
            admin = false, adminFlag = nil }
        staffStreak[plr] = st
    end
    if sample == false or not staffRigReady(plr, model) then
        -- Character still streaming in / respawning / gone: this sample
        -- answers nothing, so it can never ADD to a streak.
        if st.streak ~= 0 then st.streak = 0 end
        st.role, st.reason, st.admin, st.adminFlag = "NONE", nil, false, nil
        st.pending = true
        return nil
    end
    local ok, info = pcall(SA.GetStaffRole, plr, model or plr.Character)
    if not ok or not info then
        if st.streak ~= 0 then st.streak = 0 end
        st.pending = true
        return nil
    end
    st.scans = (st.scans or 0) + 1
    if info.staff then
        st.streak = (st.streak or 0) + 1
        st.role, st.reason = info.role, info.reason
        st.admin, st.adminFlag = info.admin == true, info.adminFlag
        -- Evidence seen but not yet confirmed on 3 scans = pending. The
        -- tag says "SCAN n/3" instead of claiming STAFF.
        st.pending = (st.streak or 0) < SA.STAFF_CONFIRM_SCANS
    else
        -- A clean read of an ordinary player is a REAL negative sample:
        -- it resets the streak immediately, so one glitched frame can
        -- never accumulate towards a tag.
        st.streak = 0
        st.role, st.reason, st.admin, st.adminFlag = "NONE", nil, false, nil
        st.pending = false
    end
    st.staff = info.staff == true
    st.lastScan = tick()
    if (st.streak or 0) >= SA.STAFF_CONFIRM_SCANS then
        return {
            staff = true, admin = st.admin == true, role = st.role,
            reason = st.reason, adminFlag = st.adminFlag,
            confirmed = true, streak = st.streak, scans = st.scans,
        }
    end
    return nil
end

-- Role used by the ESP tag. Unconfirmed / ordinary players are NONE, so a
-- player who was staff in a PREVIOUS round cannot keep a stale tag after
-- respawn either: the streak is per player and resets on any clean read.
function SA.GetStaffRoleConfirmed(plr, model)
    local out = { staff = false, admin = false, role = "NONE",
        reason = nil, adminFlag = nil, confirmed = false, streak = 0,
        scans = 0, pending = false }
    if not plr then return out end
    local confirmed = SA.StaffScanOne(plr, model)
    local st = staffStreak[plr]
    if st then
        out.streak = st.streak or 0
        out.scans = st.scans or 0
        out.pending = st.pending == true
        if not confirmed then
            out.role = "NONE"
            return out
        end
        out.staff, out.admin = true, confirmed.admin == true
        out.role = confirmed.role
        out.reason, out.adminFlag = confirmed.reason, confirmed.adminFlag
        out.confirmed = true
    end
    return out
end

-- Confirmation state for the watch readout. `raw` is what a single scan
-- would say, `confirmed` needs all three consecutive samples.
function SA.StaffWatchState()
    local out = { scans = SA.STAFF_CONFIRM_SCANS, pass = staffScanPass,
        confirmed = 0, pending = 0, raw = 0, names = {}, pendingNames = {},
        adminNames = {} }
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= lp then
            local role = SA.GetStaffRole(plr, plr.Character)
            if role and role.staff then out.raw = out.raw + 1 end
            local st = staffStreak[plr]
            if st and (st.streak or 0) >= SA.STAFF_CONFIRM_SCANS then
                out.confirmed = out.confirmed + 1
                out.names[#out.names + 1] = plr.Name
                if st.admin then
                    out.adminNames[#out.adminNames + 1] = plr.Name
                end
            elseif st and st.pending then
                out.pending = out.pending + 1
                out.pendingNames[#out.pendingNames + 1] = plr.Name
            end
        end
    end
    return out
end

function SA.StaffWatchReset()
    for plr in pairs(staffStreak) do staffStreak[plr] = nil end
    staffScanPass = 0
    return true
end

-- Detector snapshot for the ESP tab / tests. It reads the live player list,
-- so nothing the UI shows can go stale.
function SA.StaffDetectState()
    -- The tab readout counts CONFIRMED roles only (3 consecutive scans),
    -- so a player streaming in cannot make "staff 1" flash for one second.
    staffScanPass = staffScanPass + 1
    local out = { players = 0, staff = 0, admins = 0,
        names = {}, adminNames = {},
        confirmScans = SA.STAFF_CONFIRM_SCANS, pass = staffScanPass,
        pending = 0 }
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= lp then
            out.players = out.players + 1
            local ok, info = pcall(SA.GetStaffRoleConfirmed, plr,
                plr.Character)
            if not ok or not info then
                info = { staff = false, admin = false }
            end
            if info.staff then
                out.staff = out.staff + 1
                out.names[#out.names + 1] = plr.Name
                if info.admin then
                    out.admins = out.admins + 1
                    out.adminNames[#out.adminNames + 1] = plr.Name
                end
            elseif info.pending then
                out.pending = out.pending + 1
            end
        end
    end
    return out
end
-- ────────────────────────────────────────────────────────────────────
-- UNKNOWN HUMANOID DETECTOR (read-only, Misc)
-- Every humanoid that is not a real player and not a known NPC class is
-- reported as UNKNOWN — never labelled LiveBait, never excluded from aim,
-- never warned about. The Bait / LiveBait attributes are only *reported*
-- as extra evidence when the game has already replicated them; nothing is
-- written and no behaviour depends on them.
-- ────────────────────────────────────────────────────────────────────
local KNOWN_NPC_PATTERNS = {
    "Guard", "Scavenger", "Soldier", "Sleeper_", "Dino", "Raptor", "Rex",
    "Boar", "Deer", "Bear", "Wolf", "Chicken", "Horse", "Stag", "Pig",
    "Cow", "Sheep", "Zombie", "Bandit", "Raider", "Hostile",
}
local unknownList = _G.__saUnknownHumanoids or {}
_G.__saUnknownHumanoids = unknownList

-- A short class label for the report. Any unmatched humanoid is UNKNOWN.
function SA.UnknownHumanoidKind(model)
    if not model then return nil end
    local name = tostring(model.Name or "")
    for _, pat in ipairs(KNOWN_NPC_PATTERNS) do
        if name:find(pat, 1, true) then return pat end
    end
    return nil
end

-- Read-only attribute evidence. Returns "Bait" / "LiveBait" / nil.
function SA.UnknownHumanoidEvidence(model)
    if not model then return nil end
    for _, key in ipairs({ "Bait", "LiveBait" }) do
        local ok, value = pcall(function() return model:GetAttribute(key) end)
        if ok and value ~= nil and value ~= false then return key end
    end
    return nil
end

local function validUnknownHumanoid(d)
    if not d or not d:IsA("Model") then return false end
    if not d:FindFirstChildOfClass("Humanoid") then return false end
    if not (d:FindFirstChild("Head") or d:FindFirstChild("HumanoidRootPart")) then
        return false
    end
    if Players:GetPlayerFromCharacter(d) ~= nil then return false end
    if SA.IsNpcModel and SA.IsNpcModel(d) then return false end
    return SA.UnknownHumanoidKind(d) == nil
end

local function commitUnknownHumanoids(found)
    for i = #unknownList, 1, -1 do unknownList[i] = nil end
    for _, m in ipairs(found) do unknownList[#unknownList + 1] = m end
end

SA.RegisterScanHandler("unknownHumanoids", validUnknownHumanoid,
    commitUnknownHumanoids)

function SA.UnknownHumanoidListRaw() return unknownList end

-- Snapshot for the Misc tab / tests. `withEvidence` counts the models the
-- game itself already tagged (reported only, never acted on).
function SA.UnknownHumanoidState()
    local out = { count = 0, withEvidence = 0, names = {}, evidence = {},
        enabled = CFG.unknownHumanoidScan == true }
    for _, m in ipairs(unknownList) do
        if m.Parent and m:FindFirstChildOfClass("Humanoid") then
            out.count = out.count + 1
            out.names[#out.names + 1] = tostring(m.Name)
            local ev = SA.UnknownHumanoidEvidence(m)
            if ev then
                out.withEvidence = out.withEvidence + 1
                out.evidence[#out.evidence + 1] = tostring(m.Name) .. " " .. ev
            end
        end
    end
    return out
end

-- Roster used by the scan buttons (all players + all discovered NPCs).
function SA.Roster()
    local out = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= lp and p.Character then
            out[#out + 1] = {
                kind = "PLAYER", name = p.Name, model = p.Character,
                hum = p.Character:FindFirstChildOfClass("Humanoid"),
            }
        end
    end
    for _, m in ipairs(SA.GetNpcs()) do
        out[#out + 1] = {
            kind = "NPC", name = m.Name, model = m,
            hum = m:FindFirstChildOfClass("Humanoid"),
        }
    end
    return out
end
