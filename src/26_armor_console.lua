-- ==================================================================
-- Hanami / 26_armor_console.lua
-- ARMOR CONSOLE — the fixed version of the Fust Armor Console Scanner.
--
-- The reference script only printed to the console. This is the same
-- data, rendered as a companion HUD in the style of the Nearest Player
-- card: frameless, draggable, and visible exactly when the menu is
-- minimised. Nothing is printed.
--
-- What changed from the reference:
--   * console writes -> a real panel (no console spam at all)
--   * a change SIGNATURE drives the redraw, so a stable lobby costs
--     nothing; the reference rebuilt and reprinted every 0.25s
--   * players are ordered by nearest-to-crosshair, not alphabetically
--   * FOV awareness (optional) via SA.FovPointInside, the same helper
--     the aim circle draws with
--   * the local player is excluded, as in the reference
--
-- Detection notes: nothing here writes to another player. It only reads
-- ItemId / WASlot attributes that the game already replicates on the
-- FustWear folder, the same way the ESP reads health and names.
-- ==================================================================

-- ── CATALOG (full 26 items, with short icon codes) ──────────────────
-- abbr is what the row icon shows. The user-supplied list is authoritative;
-- a duplicate (BS is both burlap_shirt and burlap_shoes) is resolved by
-- tinting: the colour is a deterministic hash of the full id, so the two
-- BS chips never look alike.
SA.ARMOR_CATALOG = {
    -- HEAD
    { id = "burlap_headwrap",      slot = "Head",  prot = 10, abbr = "BH" },
    { id = "hide_hood",            slot = "Head",  prot = 13, abbr = "HHD" },
    { id = "night_vision_goggles", slot = "Head",  prot = 10, abbr = "NVG" },
    { id = "bone_helmet",          slot = "Head",  prot = 20, abbr = "BNH" },
    { id = "coffee_can_helmet",    slot = "Head",  prot = 24, abbr = "CCH" },
    { id = "riot_helmet",          slot = "Head",  prot = 30, abbr = "RIOT" },
    { id = "metal_facemask",       slot = "Head",  prot = 45, abbr = "MFM" },
    { id = "heavy_plate_helmet",   slot = "Head",  prot = 55, abbr = "HPH" },

    -- TORSO
    { id = "burlap_shirt",         slot = "Torso", prot = 10, abbr = "BS" },
    { id = "hide_vest",            slot = "Torso", prot = 14, abbr = "HVS" },
    { id = "wood_chestplate",      slot = "Torso", prot = 15, abbr = "WC" },
    { id = "hoodie",               slot = "Torso", prot = 16, abbr = "HOD" },
    { id = "road_sign_jacket",     slot = "Torso", prot = 25, abbr = "RSJ" },
    { id = "tactical_vest",        slot = "Torso", prot = 28, abbr = "TAC" },
    { id = "metal_chest_plate",    slot = "Torso", prot = 37, abbr = "MCP" },
    { id = "heavy_plate_jacket",   slot = "Torso", prot = 47, abbr = "HPJ" },

    -- LEGS
    { id = "burlap_trousers",      slot = "Legs",  prot = 10, abbr = "BT" },
    { id = "wood_armor_pants",     slot = "Legs",  prot = 12, abbr = "WAP" },
    { id = "hide_pants",           slot = "Legs",  prot = 14, abbr = "HPN" },
    { id = "cargo_pants",          slot = "Legs",  prot = 16, abbr = "CRG" },
    { id = "road_sign_kilt",       slot = "Legs",  prot = 22, abbr = "RSK" },
    { id = "combat_pants",         slot = "Legs",  prot = 26, abbr = "CMB" },
    { id = "heavy_plate_pants",    slot = "Legs",  prot = 32, abbr = "HPP" },

    -- FEET
    { id = "burlap_shoes",         slot = "Feet",  prot = 5,  abbr = "BS" },
    { id = "hide_boots",           slot = "Feet",  prot = 10, abbr = "HBT" },
    { id = "combat_boots",         slot = "Feet",  prot = 12, abbr = "CBT" },
}

SA.ARMOR_REGION_CAP = 80
SA.ARMOR_REGIONS = { "Head", "Torso", "Legs", "Feet" }

-- id -> { prot, abbr, slot }. Built once; never rebuilt per frame.
local armorById = {}
for _, item in ipairs(SA.ARMOR_CATALOG) do
    armorById[item.id] = item
end

-- The scan must tolerate meshes whose names carry the slot as a suffix
-- (heavy_plate_helmet_head, hide_pants_legs_armor, ...). Longest first so
-- "_torso_armor" is not eaten by "_torso".
local ARMOR_SUFFIXES = {
    "_torso_armor", "_legs_armor", "_head", "_torso", "_legs", "_feet",
}
local ARMOR_SLOT_REGION = {
    head = "Head", torso = "Torso", torso_armor = "Torso",
    legs = "Legs", legs_armor = "Legs", feet = "Feet",
}

-- Deterministic chip colour from the item id. Two different ids that
-- happen to share an abbreviation (BS) therefore never look identical.
function SA.ArmorIconColor(id)
    local text = tostring(id or "?")
    local h = 0
    for i = 1, #text do
        h = (h * 31 + text:byte(i)) % 360
    end
    return Color3.fromHSV(h / 360, 0.55, 0.95)
end

-- Short code shown on the chip: the catalog abbr, else the initials of
-- the item name so an unknown piece still gets a readable icon.
function SA.ArmorIconAbbr(id)
    local item = armorById[tostring(id or "")]
    if item and item.abbr then return item.abbr end
    local words = {}
    for word in tostring(id or "?"):gmatch("[^_%s]+") do
        words[#words + 1] = word
    end
    if #words == 0 then return "?" end
    if #words == 1 then return string.upper(words[1]:sub(1, 3)) end
    local out = ""
    for i = 1, math.min(#words, 3) do
        out = out .. string.upper(words[i]:sub(1, 1))
    end
    return out
end

-- Strip a slot suffix off a mesh name. Returns the clean id and, when the
-- suffix itself names a slot, that slot.
local function armorStripSuffix(name)
    local lower = string.lower(tostring(name or ""))
    for _, suffix in ipairs(ARMOR_SUFFIXES) do
        if #lower > #suffix and lower:sub(-#suffix) == suffix then
            return name:sub(1, #name - #suffix), suffix:sub(2)
        end
    end
    return name, nil
end

-- Name-based fallback for meshes that carry neither ItemId nor WASlot.
local function armorInferSlot(name)
    local n = string.lower(tostring(name or ""))
    if n == "hoodie" then return "torso_armor" end
    if n:find("helmet", 1, true) or n:find("hood", 1, true)
        or n:find("headwrap", 1, true) or n:find("goggles", 1, true)
        or n:find("facemask", 1, true) then
        return "head"
    end
    if n:find("jacket", 1, true) or n:find("shirt", 1, true)
        or n:find("vest", 1, true) or n:find("chestplate", 1, true)
        or n:find("chest plate", 1, true) then
        return "torso_armor"
    end
    if n:find("pants", 1, true) or n:find("trousers", 1, true)
        or n:find("kilt", 1, true) then
        return "legs_armor"
    end
    if n:find("boots", 1, true) or n:find("shoes", 1, true) then
        return "feet"
    end
    return nil
end

local function armorResolveRegion(slot, itemId)
    if slot and ARMOR_SLOT_REGION[slot] then return ARMOR_SLOT_REGION[slot] end
    local inferred = armorInferSlot(itemId)
    if inferred then return ARMOR_SLOT_REGION[inferred] end
    return nil
end

-- ── ANALYSIS ────────────────────────────────────────────────────────
-- Reads the FustWear folder the game replicates on the character. Returns
-- the worn list plus per-region totals, each capped at ARMOR_REGION_CAP.
function SA.ArmorAnalyze(character)
    local worn = {}
    local regions = { Head = 0, Torso = 0, Legs = 0, Feet = 0 }
    if character == nil then return worn, regions end
    local folder = nil
    pcall(function() folder = character:FindFirstChild("FustWear") end)
    if not folder then return worn, regions end

    local children = nil
    pcall(function() children = folder:GetChildren() end)
    if type(children) ~= "table" then return worn, regions end

    local seen = {}
    for _, part in ipairs(children) do
        local okPart = pcall(function() return part:IsA("BasePart") end)
        if okPart then
            local itemId, slot = nil, nil
            pcall(function()
                itemId = part:GetAttribute("ItemId")
                slot = part:GetAttribute("WASlot")
            end)
            if type(itemId) ~= "string" or itemId == "" then
                local stripped, suffixSlot = armorStripSuffix(part.Name)
                itemId = stripped
                if not slot and suffixSlot then slot = suffixSlot end
            end
            local displayId = tostring(itemId or part.Name or "?")
            local region = armorResolveRegion(slot, displayId)
            -- One mesh per item: two helmets are still one helmet.
            local key = displayId .. "|" .. tostring(region or "?")
            if not seen[key] then
                seen[key] = true
                local entry = armorById[displayId]
                local prot = entry and entry.prot or 0
                if region and prot > 0 then
                    regions[region] = regions[region] + prot
                end
                worn[#worn + 1] = {
                    id = displayId, region = region, prot = prot,
                    known = entry ~= nil,
                    abbr = SA.ArmorIconAbbr(displayId),
                    -- Kept so the HUD can clone the real mesh into its
                    -- ViewportFrame; the icon is the game's own model,
                    -- not a redrawn approximation.
                    source = part,
                }
            end
        end
    end

    for _, region in ipairs(SA.ARMOR_REGIONS) do
        if regions[region] > SA.ARMOR_REGION_CAP then
            regions[region] = SA.ARMOR_REGION_CAP
        end
    end
    table.sort(worn, function(a, b) return a.id < b.id end)
    return worn, regions
end

function SA.ArmorTotal(regions)
    local total = 0
    if type(regions) ~= "table" then return 0 end
    for _, region in ipairs(SA.ARMOR_REGIONS) do
        total = total + (tonumber(regions[region]) or 0)
    end
    return total
end

-- ── TARGET LIST ─────────────────────────────────────────────────────
-- Nearest-to-crosshair first. `px` is the pixel distance from the aim
-- point: that is the "nearest crosshair" metric. A player behind the
-- camera projects to a MIRRORED pixel near the crosshair, so `behind`
-- entries always sort last and are never counted as in-FOV.
function SA.ArmorTargets()
    local out = {}
    if CFG.armorConsole ~= true and CFG.armorConsoleForce ~= true then
        -- Still answer when a caller (tests, a future HUD) asks directly.
    end
    local cam = ws.CurrentCamera
    local myPos = nil
    do
        local root = SA.PlayerRig(lp.Character)
        myPos = root and root.Position or nil
        if not myPos and cam then myPos = cam.CFrame.Position end
    end
    if not myPos or not cam then return out end

    local aim = SA.AimPoint()
    local radius = SA.FovRadius()
    local onlyInFov = CFG.armorConsoleFov == true
    local maxDist = tonumber(CFG.armorConsoleMaxDist) or 0

    local players = nil
    pcall(function() players = Players:GetPlayers() end)
    if type(players) ~= "table" then return out end

    for _, plr in ipairs(players) do
        if plr ~= lp then
            local char = nil
            pcall(function() char = plr.Character end)
            local root = char and SA.PlayerRig(char) or nil
            if root and root.Position then
                local ok, entry = pcall(function()
                    local dist = (root.Position - myPos).Magnitude
                    if maxDist > 0 and dist > maxDist then return nil end
                    -- Trace to the HEAD so a player standing behind a
                    -- low wall is judged by what you can actually see.
                    local head = nil
                    pcall(function()
                        head = char:FindFirstChild("Head")
                    end)
                    local pos = (head and head.Position) or root.Position
                    local sp, onScreen = nil, false
                    pcall(function()
                        sp, onScreen = cam:WorldToViewportPoint(pos)
                    end)
                    local inFov = SA.FovPointInside(cam, pos, sp, onScreen,
                        aim, radius) == true
                    local behind = sp ~= nil and (tonumber(sp.Z) or 0) <= 0
                    if onlyInFov and not inFov then return nil end
                    local px = math.huge
                    if sp and not behind then
                        local dx = (tonumber(sp.X) or 0) - aim.X
                        local dy = (tonumber(sp.Y) or 0) - aim.Y
                        px = math.sqrt(dx * dx + dy * dy)
                    end
                    local worn, regions = SA.ArmorAnalyze(char)
                    return {
                        player = plr, name = tostring(plr.Name or "?"),
                        char = char, root = root, dist = dist,
                        px = px, inFov = inFov, behind = behind,
                        worn = worn, regions = regions,
                        total = SA.ArmorTotal(regions),
                    }
                end)
                if ok and entry then out[#out + 1] = entry end
            end
        end
    end

    local mode = CFG.armorConsoleSort or "Nearest"
    table.sort(out, function(a, b)
        if mode == "Name" then return a.name:lower() < b.name:lower() end
        if mode == "Distance" then return a.dist < b.dist end
        if mode == "Most Armor" then return a.total > b.total end
        -- Nearest (default): in front before behind, then pixel distance.
        if a.behind ~= b.behind then return b.behind end
        if a.px ~= b.px then return a.px < b.px end
        return a.dist < b.dist
    end)
    return out
end
