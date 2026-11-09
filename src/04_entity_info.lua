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

-- Console dump used by the ESP-tab and Misc-tab scan buttons.
function SA.PrintScan(kind)
    print("════════════ ENTITY SCAN ════════════")
    local n = 0
    for _, e in ipairs(SA.Roster()) do
        if not kind or e.kind == kind then
            local i = SA.ScanEntity(e.model, e.hum)
            print(string.format(
                "[%-6s] %-16s | W: %-20s | S: %-12s | HP: %3d/%-3d | %4dm | %s",
                e.kind, i.name, i.tool, i.state, i.health, i.maxHealth,
                i.meters, i.visible and "VISIBLE" or "BLOCKED"))
            n = n + 1
        end
    end
    print(string.format("════════════ %d entities ════════════", n))
end
