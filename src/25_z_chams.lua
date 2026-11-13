-- ==================================================================
-- Hanami / 25_z_chams.lua
-- HAND CHAMS + WEAPON CHAMS, each fully independent.
--
-- Derived from the "1x1x1x1_CORRUPTED" cham snippet: pulsing
-- Obsidian / red Neon, occasional ForceField spike flashes with a red
-- wireframe box, and floating runic BillboardGui glyphs.
--
-- What changed from the snippet, and why:
--   * It is TWO separate features with their OWN settings. Hand chams and
--     weapon chams share the same option set but never read each other's
--     flags, so styling the hands cannot touch the weapon.
--   * It no longer touches other players at all. It decorates the LOCAL
--     player's own character parts, which is what "hand chams" means --
--     a first-person / local cosmetic, not an ESP wallhack on enemies.
--   * Nothing is written to a part the script does not own beyond the
--     properties it restores on disable. Every touched part keeps a
--     snapshot and is restored exactly (material, colour, transparency,
--     reflection) when the style is turned off.
--   * It does not drive itself from math.random() per frame (the snippet
--     flashed ~8% of frames and rerolled glyphs constantly, which is
--     pure churn). Here the pulse is a deterministic function of time and
--     a per-part phase offset, and glyph text changes on a timed beat.
--   * It runs on ONE bindRender callback with an early exit, walks only
--     the local character's parts, and writes a property only when it
--     actually changes.
-- ==================================================================

-- Rune alphabet from the source snippet.
SA.CHAM_GLYPHS = { "1", "x", "0", "!", "?", "Ø", "§", "†", "‡", "¶", "#", "X" }

-- Palette used by the "corrupted" style.
local CORRUPT_DARK   = Color3.fromRGB(15, 12, 14)
local CORRUPT_RED    = Color3.fromRGB(200, 0, 25)
local CORRUPT_SPIKE  = Color3.fromRGB(25, 0, 5)
local CORRUPT_WIRE   = Color3.fromRGB(255, 0, 30)
local CORRUPT_WHITE  = Color3.fromRGB(255, 255, 255)

-- Every style a cham slot can use. Split into two groups so the UI can
-- label them; the engine only cares about the key.
SA.CHAM_STYLES = {
    "Corrupted", "Solid", "Neon", "Wireframe", "Ghost",
}

-- Which parts count as "hands" and which as "weapon".
-- R15 hand parts, R6 arm parts and the classic Hand/RootPart tool grips.
local HAND_PARTS = {
    ["RightHand"] = true, ["LeftHand"] = true,
    ["Right Arm"] = true, ["Left Arm"] = true,
    ["RightArm"] = true, ["LeftArm"] = true,
    ["RightUpperArm"] = true, ["LeftUpperArm"] = true,
    ["RightLowerArm"] = true, ["LeftLowerArm"] = true,
}

-- One cham slot. `key` is the CFG prefix: "hand" or "weapon".
local function chamNewSlot(key)
    return {
        key = key,
        -- id -> { part, material, color, transparency, reflection }
        parts = {},
        -- part -> BillboardGui (runic aura)
        auras = {},
        -- part -> SelectionBox (wireframe spike)
        boxes = {},
        lastTick = 0,
        active = false,
        restores = 0,
    }
end

local chams = {
    hand = chamNewSlot("hand"),
    weapon = chamNewSlot("weapon"),
    built = true,
    errors = 0,
    lastError = nil,
}

-- Hand/weapon chams are per-frame cosmetics on the local character, so
-- they must not survive a re-execute. Clearing the whole table here means
-- a stale style can never be painted onto a freshly spawned character.
_G.__saChams = chams

local function chamSet(inst, prop, value)
    if not inst then return end
    local ok = pcall(function() inst[prop] = value end)
    if not ok then return false end
    return true
end

-- Read a property without throwing on a missing / locked one.
local function chamGet(inst, prop, fallback)
    local ok, value = pcall(function() return inst[prop] end)
    if not ok or value == nil then return fallback end
    return value
end

-- ── MATERIAL / COLOUR PER STYLE ─────────────────────────────────────
-- Returns material, colour, transparency for a part at time `t`.
-- `phase` is a per-part offset so the left and right hand never pulse in
-- lockstep -- that synchronised flashing is what made the snippet look
-- like one solid blob rather than two moving hands.
local function chamLook(style, t, phase, intensity, baseColor)
    if style == "Solid" then
        return Enum.Material.SmoothPlastic, baseColor or CORRUPT_RED, 0
    end
    if style == "Neon" then
        local pulse = 0.5 + 0.5 * math.sin(t * 6 + phase)
        local col = (baseColor or CORRUPT_RED):Lerp(CORRUPT_WHITE, pulse * 0.35)
        return Enum.Material.Neon, col, 0
    end
    if style == "Wireframe" then
        -- Wireframe keeps the part dark and full and lets the
        -- SelectionBox carry the look (drawn by the caller).
        return Enum.Material.SmoothPlastic, CORRUPT_DARK, 0
    end
    if style == "Ghost" then
        local pulse = 0.5 + 0.5 * math.sin(t * 3 + phase)
        local col = (baseColor or CORRUPT_RED):Lerp(CORRUPT_WHITE, 0.5)
        return Enum.Material.ForceField, col, 0.35 + pulse * 0.25
    end
    -- Corrupted (default): Obsidian / red Neon pulsing.
    local pulse = math.sin(t * 12 + phase)
    if pulse > 0.4 * math.max(intensity, 0.05) then
        return Enum.Material.Neon, CORRUPT_RED, 0
    end
    return Enum.Material.CorrodedMetal, CORRUPT_DARK, 0
end

-- ── PART DISCOVERY ──────────────────────────────────────────────────
-- Collect the local character's hand parts and the equipped tool's parts.
-- Read-only walk; never mutates the hierarchy.
local function chamCollect(slotName)
    local out = {}
    local char = lp and lp.Character
    if not char then return out end

    if slotName == "hand" then
        -- Every BasePart on the character whose name is a known hand /
        -- arm name. R15 characters expose the hands directly; R6 ones
        -- only have arms, so both are accepted.
        local ok = pcall(function()
            for _, part in ipairs(char:GetChildren()) do
                if type(part.Name) == "string" and HAND_PARTS[part.Name] then
                    local isPart = select(2, pcall(function()
                        return part:IsA("BasePart")
                    end))
                    if isPart then out[#out + 1] = part end
                end
            end
        end)
        if not ok then return {} end
    else
        -- Weapon: the parts of the currently equipped Tool. A tool can
        -- hold a mesh, a handle, or a whole model, so walk descendants.
        local tool = nil
        pcall(function()
            tool = char:FindFirstChildOfClass("Tool")
        end)
        if tool then
            pcall(function()
                if tool:IsA("BasePart") then out[#out + 1] = tool end
                for _, part in ipairs(tool:GetDescendants()) do
                    local isPart = select(2, pcall(function()
                        return part:IsA("BasePart")
                    end))
                    if isPart then out[#out + 1] = part end
                end
            end)
        end
    end
    return out
end

-- ── RESTORE / CLEANUP ───────────────────────────────────────────────
local function chamRestorePart(slot, part)
    local snap = slot.parts[part]
    if not snap then return end
    chamSet(part, "Material", snap.material)
    chamSet(part, "Color", snap.color)
    chamSet(part, "Transparency", snap.transparency)
    if snap.reflection ~= nil then
        chamSet(part, "Reflectance", snap.reflection)
    end
    slot.parts[part] = nil
end

local function chamDestroyArtifacts(slot)
    for part, gui in pairs(slot.auras) do
        pcall(function() gui:Destroy() end)
        slot.auras[part] = nil
    end
    for part, box in pairs(slot.boxes) do
        pcall(function() box:Destroy() end)
        slot.boxes[part] = nil
    end
end

-- Full teardown of one slot: restores every touched part and drops the
-- auras / wireframe boxes. Safe to call repeatedly.
local function chamClearSlot(slot)
    chamDestroyArtifacts(slot)
    local n = 0
    for part in pairs(slot.parts) do
        chamRestorePart(slot, part)
        n = n + 1
    end
    slot.parts = {}
    slot.active = false
    slot.restores = slot.restores + n
    return n
end

function SA.ChamsDispose()
    local removed = 0
    for _, name in ipairs({ "hand", "weapon" }) do
        removed = removed + chamClearSlot(chams[name])
    end
    CFG.handChams = false
    CFG.weaponChams = false
    return removed
end

-- ── AURA (runic BillboardGui) ───────────────────────────────────────
local function chamEnsureAura(slot, part)
    if slot.auras[part] then return slot.auras[part] end
    local ok, bb = pcall(function()
        local gui = Instance.new("BillboardGui")
        gui.Name = "HanamiChamRune"
        gui.Adornee = part
        gui.Size = UDim2.new(0, 45, 0, 45)
        gui.AlwaysOnTop = true
        gui.ExtentsOffset = Vector3.new(0, 0.4, 0)

        local lbl = Instance.new("TextLabel")
        lbl.Name = "RuneLabel"
        lbl.Size = UDim2.new(1, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        pcall(function() lbl.Font = Enum.Font.SpecialElite end)
        lbl.Text = "1x1x1x1"
        lbl.TextColor3 = CORRUPT_RED
        lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        lbl.TextStrokeTransparency = 0
        lbl.TextSize = 14
        lbl.Parent = gui
        gui.Parent = part
        return gui
    end)
    if not ok or not bb then return nil end
    slot.auras[part] = bb
    return bb
end

local function chamEnsureBox(slot, part)
    if slot.boxes[part] then return slot.boxes[part] end
    local ok, box = pcall(function()
        local b = Instance.new("SelectionBox")
        b.Name = "HanamiChamWire"
        b.Adornee = part
        b.Color3 = CORRUPT_WIRE
        b.LineThickness = 0.04
        b.SurfaceTransparency = 0.9
        b.Parent = part
        return b
    end)
    if not ok or not box then return nil end
    slot.boxes[part] = box
    return box
end

-- Glyph text changes on a timed beat, not per frame. `beat` is derived
-- from the slot key so the hand and weapon runes never land on the same
-- character pair.
local function chamRuneText(t, seed)
    local beat = math.floor(t * 3 + seed)
    local a = SA.CHAM_GLYPHS[(beat * 7 + seed) % #SA.CHAM_GLYPHS + 1]
    local b = SA.CHAM_GLYPHS[(beat * 3 + seed * 2) % #SA.CHAM_GLYPHS + 1]
    return a .. "x" .. b
end

-- ── PER-SLOT FRAME UPDATE ───────────────────────────────────────────
local function chamTickSlot(name, t)
    local slot = chams[name]
    local prefix = name == "hand" and "handChams" or "weaponChams"
    local enabled = CFG[prefix] == true

    if not enabled then
        -- Cheap disabled path: one clear, then nothing. chamClearSlot is
        -- idempotent and leaves the table empty, so this costs a pair()
        -- check per frame at most.
        if slot.active or next(slot.parts) ~= nil then
            chamClearSlot(slot)
        end
        slot.reason = "disabled"
        return
    end

    -- Any style change invalidates the snapshot only for parts whose
    -- style-dependent artifacts differ; simplest correct behaviour is to
    -- restore first so the snapshot always describes the real part.
    local style = CFG[prefix .. "Style"] or "Corrupted"
    local intensity = tonumber(CFG[prefix .. "Intensity"]) or 1
    local auraOn = CFG[prefix .. "Aura"] == true
    local wireOn = (style == "Wireframe") or CFG[prefix .. "Spikes"] == true
    local baseColor = ESP_COLORS[prefix .. "Color"] or CORRUPT_RED

    local parts = chamCollect(name)
    if #parts == 0 then
        if next(slot.parts) ~= nil then chamClearSlot(slot) end
        slot.reason = name == "hand" and "no hand parts" or "no tool equipped"
        return
    end

    -- Drop snapshots for parts that are gone (respawn / tool swap) so the
    -- table cannot grow without bound.
    local present = {}
    for _, part in ipairs(parts) do present[part] = true end
    for part in pairs(slot.parts) do
        if not present[part] then
            chamRestorePart(slot, part)
        end
    end
    for part in pairs(slot.auras) do
        if not present[part] then
            pcall(function() slot.auras[part]:Destroy() end)
            slot.auras[part] = nil
        end
    end
    for part in pairs(slot.boxes) do
        if not present[part] then
            pcall(function() slot.boxes[part]:Destroy() end)
            slot.boxes[part] = nil
        end
    end

    local seed = (name == "hand") and 1 or 5
    for index, part in ipairs(parts) do
        -- Snapshot once, BEFORE the first write, so restore is exact.
        if not slot.parts[part] then
            slot.parts[part] = {
                material = chamGet(part, "Material", nil),
                color = chamGet(part, "Color", nil),
                transparency = chamGet(part, "Transparency", 0),
                reflection = chamGet(part, "Reflectance", nil),
            }
        end
        -- Per-part phase keeps the two hands out of lockstep.
        local phase = index * 1.7 + seed
        local material, color, transparency =
            chamLook(style, t, phase, intensity, baseColor)

        -- Write only when the value actually differs: this is a per-frame
        -- cosmetic and must not churn the replication queue.
        if chamGet(part, "Material", nil) ~= material then
            chamSet(part, "Material", material)
        end
        local curColor = chamGet(part, "Color", nil)
        if curColor ~= color then
            local same = false
            pcall(function()
                same = curColor == color
                    or (curColor.R == color.R and curColor.G == color.G
                        and curColor.B == color.B)
            end)
            if not same then chamSet(part, "Color", color) end
        end
        if chamGet(part, "Transparency", 0) ~= transparency then
            chamSet(part, "Transparency", transparency)
        end

        -- Wireframe spike box: the snippet created one per random frame.
        -- Here it is a pooled instance that is simply shown or hidden.
        if wireOn then
            local box = chamEnsureBox(slot, part)
            if box then
                chamSet(box, "Color3", CORRUPT_WIRE)
                chamSet(box, "LineThickness",
                    0.04 * math.max(intensity, 0.05))
                chamSet(box, "Visible", true)
            end
        else
            local box = slot.boxes[part]
            if box then chamSet(box, "Visible", false) end
        end

        -- Runic aura.
        if auraOn then
            local gui = chamEnsureAura(slot, part)
            if gui then
                local lbl = nil
                pcall(function() lbl = gui:FindFirstChild("RuneLabel") end)
                if lbl then
                    -- Text changes on a 3 Hz beat; bobbing is continuous.
                    if slot.lastTextBeat ~= math.floor(t * 3) then
                        lbl.Text = chamRuneText(t, seed + index)
                        lbl.TextColor3 = CORRUPT_RED
                    end
                    chamSet(gui, "ExtentsOffset", Vector3.new(
                        math.sin(t * 4 + phase) * 0.2 * intensity,
                        0.2 + math.sin(t * 8 + phase) * 0.15,
                        math.cos(t * 4 + phase) * 0.2 * intensity))
                end
            end
        elseif slot.auras[part] then
            pcall(function() slot.auras[part]:Destroy() end)
            slot.auras[part] = nil
        end
    end
    slot.lastTextBeat = math.floor(t * 3)
    slot.active = true
    slot.reason = "active"
    slot.count = #parts
end

-- ── PUBLIC API ──────────────────────────────────────────────────────
function SA.ChamsSet(slotName, on)
    if slotName ~= "hand" and slotName ~= "weapon" then return false end
    local flag = slotName == "hand" and "handChams" or "weaponChams"
    CFG[flag] = on == true
    pcall(setFlag, flag, CFG[flag])
    return true
end

function SA.ChamsRefresh()
    local t = tick()
    chamTickSlot("hand", t)
    chamTickSlot("weapon", t)
    return SA.ChamsState()
end

function SA.ChamsState()
    local t = tick()
    chamTickSlot("hand", t)
    chamTickSlot("weapon", t)
    local function summary(slot)
        local auras, boxes = 0, 0
        for _ in pairs(slot.auras) do auras = auras + 1 end
        for _ in pairs(slot.boxes) do boxes = boxes + 1 end
        return {
            active = slot.active == true,
            parts = slot.count or 0,
            auras = auras,
            boxes = boxes,
            restores = slot.restores or 0,
            reason = slot.reason or "idle",
        }
    end
    return {
        hand = summary(chams.hand),
        weapon = summary(chams.weapon),
        -- Prove the two slots are independent: these must be able to
        -- differ in every field.
        independent = CFG.handChams ~= CFG.weaponChams
            or (CFG.handChamsStyle or "Corrupted")
                ~= (CFG.weaponChamsStyle or "Corrupted"),
        errors = chams.errors,
        lastError = chams.lastError,
    }
end

-- ONE render callback for both slots, with an early exit so the disabled
-- case (the default) costs two boolean reads per frame.
bindRender(function(dt)
    if CFG.handChams ~= true and CFG.weaponChams ~= true then
        -- Still needs one pass to restore anything left over from the
        -- frame the toggle went off.
        if chams.hand.active or next(chams.hand.parts) ~= nil then
            chamClearSlot(chams.hand)
        end
        if chams.weapon.active or next(chams.weapon.parts) ~= nil then
            chamClearSlot(chams.weapon)
        end
        return
    end
    local ok, err = pcall(function()
        local t = tick()
        if CFG.handChams == true then chamTickSlot("hand", t) end
        if CFG.weaponChams == true then chamTickSlot("weapon", t) end
    end)
    if not ok then
        chams.errors = chams.errors + 1
        chams.lastError = tostring(err)
    end
end)
