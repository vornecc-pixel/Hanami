-- ==================================================================
-- Hanami / 26_armor_viewer.lua — Fust gear inspector
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
--
-- READ-ONLY by design. It walks each character's replicated `FustWear`
-- folder, reads the ItemId / WASlot attributes the game already put
-- there, and turns them into a protection total per body region. It
-- never writes to another player's character, never fires a remote and
-- never needs a require() to succeed.
--
-- FOV AWARE: every row knows whether that player is inside the aim
-- circle right now, and the list can be filtered to only in-circle
-- targets. NEAREST CROSSHAIR: rows are ordered by pixel distance from
-- SA.AimPoint(), i.e. the same reference the FOV circle and silent aim
-- use, so the top of the list is the player the aim would pick.
-- ==================================================================

-- ── Protection table ────────────────────────────────────────────────
-- Percent of damage absorbed per region, keyed by the real Fust item id
-- (snake_case). Kept in one place so a game update is a one-line edit.
local ARMOR_PROT = {
    burlap_headwrap = 10, burlap_shirt = 10, burlap_trousers = 10,
    burlap_shoes = 5, hide_hood = 13, hide_vest = 14, hide_pants = 14,
    hide_boots = 10, hoodie = 16, cargo_pants = 16, combat_boots = 12,
    wood_chestplate = 15, wood_armor_pants = 12, bone_helmet = 20,
    coffee_can_helmet = 24, road_sign_jacket = 25, road_sign_kilt = 22,
    riot_helmet = 30, tactical_vest = 28, combat_pants = 26,
    metal_facemask = 45, metal_chest_plate = 37, heavy_plate_pants = 32,
    heavy_plate_helmet = 55, heavy_plate_jacket = 47,
    night_vision_goggles = 10,
}

-- A region is capped: stacking every slot on one body part cannot give
-- more than this. The game's own cap is unknown, so this stays a
-- clearly-labelled ceiling rather than a claim about exact behaviour.
local ARMOR_REGION_CAP = 80

local ARMOR_REGIONS = { "Head", "Torso", "Legs", "Feet" }

local ARMOR_SLOT_REGION = {
    head = "Head", torso = "Torso", torso_armor = "Torso",
    legs = "Legs", legs_armor = "Legs", feet = "Feet",
}

-- Normalised lookup: the exporter compared lowercased, de-underscored
-- ids, and so do we, so "Heavy_Plate_Helmet" / "heavy plate helmet"
-- both resolve.
local armorProtByNorm = {}
for id, val in pairs(ARMOR_PROT) do
    armorProtByNorm[string.lower((string.gsub(id, "_", " ")))] = val
end

local function armorNorm(id)
    if not id then return "" end
    return string.lower((string.gsub(tostring(id), "_", " ")))
end

local function armorProtOf(itemId)
    return armorProtByNorm[armorNorm(itemId)]
end

-- When an item has no WASlot attribute we infer the region from its
-- name. Ordered most-specific first: "night_vision_goggles" must not be
-- mistaken for a leg item, and "heavy_plate_jacket" must not become Head
-- just because it contains "plate".
local function armorInferSlot(name)
    local n = string.lower(tostring(name or ""))
    if n == "hoodie" then return "torso_armor" end
    if n:find("helmet", 1, true) or n:find("hood", 1, true)
        or n:find("headwrap", 1, true) or n:find("goggles", 1, true)
        or n:find("facemask", 1, true) then
        return "head"
    end
    if n:find("boots", 1, true) or n:find("shoes", 1, true) then
        return "feet"
    end
    if n:find("pants", 1, true) or n:find("trousers", 1, true)
        or n:find("kilt", 1, true) then
        return "legs_armor"
    end
    if n:find("jacket", 1, true) or n:find("shirt", 1, true)
        or n:find("vest", 1, true) or n:find("chestplate", 1, true)
        or n:find("chest plate", 1, true) then
        return "torso_armor"
    end
    return nil
end

local function armorRegionOf(slot, itemId)
    if slot and ARMOR_SLOT_REGION[slot] then return ARMOR_SLOT_REGION[slot] end
    local inferred = armorInferSlot(itemId)
    if inferred then return ARMOR_SLOT_REGION[inferred] end
    return nil
end

-- Mesh part names carry the slot as a suffix ("heavy_plate_helmet_head"),
-- so strip it to recover the item id.
local ARMOR_SUFFIXES = { "_torso_armor", "_legs_armor", "_head",
                         "_torso", "_legs", "_feet" }
local function armorStripSuffix(name)
    local lower = string.lower(tostring(name or ""))
    for _, suf in ipairs(ARMOR_SUFFIXES) do
        if #lower > #suf and lower:sub(-#suf) == suf then
            return tostring(name):sub(1, #name - #suf), suf:sub(2)
        end
    end
    return name, nil
end

-- ── One character -> gear breakdown ─────────────────────────────────
-- Returns the item list plus per-region totals. Everything is pcall'd:
-- a character whose FustWear folder is mid-replication must not abort
-- the scan for the whole server.
function SA.ArmorAnalyze(character)
    local worn, regions, seen = {}, {}, {}
    for _, r in ipairs(ARMOR_REGIONS) do regions[r] = 0 end
    if not character or not character.Parent then return worn, regions end
    local ok, err = pcall(function()
        local wear = character:FindFirstChild("FustWear")
        if not wear then return end
        for _, part in ipairs(wear:GetChildren()) do
            if part:IsA("BasePart") then
                local itemId = part:GetAttribute("ItemId")
                local slot = part:GetAttribute("WASlot")
                if not itemId then
                    local stripped, suffix = armorStripSuffix(part.Name)
                    itemId = stripped
                    if not slot and suffix then slot = suffix end
                end
                itemId = itemId or part.Name
                local region = armorRegionOf(slot, itemId)
                -- Two meshes can describe the same physical item; only the
                -- first contributes protection.
                local key = tostring(itemId) .. "|" .. tostring(region or "?")
                if not seen[key] then
                    seen[key] = true
                    local prot = armorProtOf(itemId) or 0
                    if region and prot > 0 then
                        regions[region] = regions[region] + prot
                    end
                    worn[#worn + 1] = {
                        id = tostring(itemId),
                        region = region,
                        prot = prot,
                        -- An unknown item is reported honestly instead of
                        -- being shown as "+0%".
                        known = prot > 0,
                    }
                end
            end
        end
        for _, r in ipairs(ARMOR_REGIONS) do
            if regions[r] > ARMOR_REGION_CAP then
                regions[r] = ARMOR_REGION_CAP
            end
        end
        table.sort(worn, function(a, b)
            return tostring(a.id) < tostring(b.id)
        end)
    end)
    if not ok then
        SA.ArmorViewerState.lastError = tostring(err)
    end
    return worn, regions
end

-- Total protection across all four regions, used for "Most Armor".
function SA.ArmorTotal(regions)
    local n = 0
    for _, r in ipairs(ARMOR_REGIONS) do n = n + (regions[r] or 0) end
    return n
end

-- ── Eligible players, FOV + distance annotated ──────────────────────
-- Uses the SAME reference as the circle / silent aim / snapline:
-- SA.AimPoint() for the centre and SA.FovPointInside() for membership,
-- so "in FOV" here can never disagree with the drawn circle.
function SA.ArmorTargets()
    local out = {}
    local cam = ws.CurrentCamera
    local myChar = lp.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myPos = myRoot and myRoot.Position
        or (cam and cam.CFrame.Position) or Vector3.new(0, 0, 0)
    local aim = SA.AimPoint and SA.AimPoint() or Vector2.new(0, 0)
    local radius = SA.FovRadius and SA.FovRadius() or 220
    local maxDist = tonumber(CFG.armorMaxDist) or 0
    local includeSelf = false
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= lp or includeSelf then
            local char = plr.Character
            if char and char.Parent then
                local root = char:FindFirstChild("HumanoidRootPart")
                local ok, entry = pcall(function()
                    local dist = root and (root.Position - myPos).Magnitude or 0
                    if maxDist > 0 and dist > maxDist then return nil end
                    local sp, onScreen = nil, false
                    if cam and root then
                        sp, onScreen = cam:WorldToViewportPoint(root.Position)
                    end
                    -- Offset in pixels from the aim point: this IS the
                    -- "nearest crosshair" ordering metric, and it is also
                    -- what the circle is measured against.
                    local px = math.huge
                    if sp then
                        local dx, dy = sp.X - aim.X, sp.Y - aim.Y
                        px = math.sqrt(dx * dx + dy * dy)
                    end
                    local inFov = false
                    if cam and root and sp then
                        inFov = SA.FovPointInside(cam, root.Position, sp,
                            onScreen, aim, radius) == true
                    end
                    -- "In FOV only" belongs to the DATA layer, not just
                    -- the renderer: every consumer of this list (the panel,
                    -- and any future HUD) must see the same filtered set.
                    if CFG.armorOnlyInFov == true and not inFov then
                        return nil
                    end
                    return {
                        player = plr, name = plr.Name, char = char,
                        root = root, dist = dist, px = px,
                        inFov = inFov,
                        -- Behind-camera points project to a mirrored pixel,
                        -- so they are never "near the crosshair".
                        behind = sp ~= nil and (tonumber(sp.Z) or 0) <= 0,
                    }
                end)
                if ok and entry then out[#out + 1] = entry end
            end
        end
    end
    table.sort(out, function(a, b)
        if a.inFov ~= b.inFov then return a.inFov end
        local mode = CFG.armorSortMode or "Nearest"
        if mode == "Name" then return a.name:lower() < b.name:lower() end
        if mode == "Distance" then return a.dist < b.dist end
        if mode == "Nearest" then
            if a.behind ~= b.behind then return not a.behind end
            if a.px ~= b.px then return a.px < b.px end
            return a.dist < b.dist
        end
        -- "Most Armor": resolved lazily below by the caller's sort value.
        return (a.sortValue or 0) > (b.sortValue or 0)
    end)
    return out
end

-- ── Item icon lookup (OPTIONAL) ─────────────────────────────────────
-- The reference viewer did `require(Fust.ItemIcons)` at the top level.
-- That is a hard crash in any game without that module, and it also runs
-- a server-module require the client may not be allowed to do. Here the
-- module is looked up once, behind a pcall, and every accessor is
-- optional: with no ItemIcons the panel simply shows an abbreviation.
local armorIcons, armorIconsTried = nil, false

local function armorLoadIcons()
    if armorIconsTried then return armorIcons end
    armorIconsTried = true
    pcall(function()
        local RS = game:GetService("ReplicatedStorage")
        local fust = RS:FindFirstChild("Fust")
        local mod = fust and fust:FindFirstChild("ItemIcons")
        if mod and type(require) == "function" then
            armorIcons = require(mod)
        end
    end)
    return armorIcons
end

local function armorIconColor(itemId)
    local icons = armorLoadIcons()
    if icons and type(icons.Color) == "function" then
        local ok, c = pcall(icons.Color, itemId)
        if ok and typeof(c) == "Color3" then return c end
    end
    -- Deterministic fallback colour from the id, so a given item always
    -- looks the same between scans.
    local h = 0
    local s = tostring(itemId or "")
    for i = 1, #s do h = (h * 31 + s:byte(i)) % 360 end
    return Color3.fromHSV(h / 360, 0.45, 0.62)
end

local function armorIconAbbr(itemId)
    local icons = armorLoadIcons()
    if icons and type(icons.Abbr) == "function" then
        local ok, a = pcall(icons.Abbr, itemId)
        if ok and type(a) == "string" and #a > 0 then return a end
    end
    local s = tostring(itemId or "?"):gsub("_", " ")
    local out = ""
    for word in s:gmatch("%a+") do
        out = out .. word:sub(1, 1):upper()
        if #out >= 3 then break end
    end
    return #out > 0 and out or "?"
end

-- The panel lives in 27b_armor_viewer_ui.lua. Splitting here keeps each
-- part far inside Luau's 200-register budget: the data layer is pure
-- table work, the UI layer is Instance building, and neither needs the
-- other's locals.
--
-- Public surface used by the UI part:
--   SA.ArmorAnalyze(character) -> worn, regions
--   SA.ArmorTotal(regions)     -> number
--   SA.ArmorTargets()          -> annotated, sorted player list
--   SA.ArmorIconAbbr(id)       -> short label
--   SA.ArmorIconColor(id)      -> Color3
--   SA.ARMOR_REGIONS           -> { "Head", "Torso", "Legs", "Feet" }
SA.ARMOR_REGIONS = ARMOR_REGIONS
SA.ArmorIconAbbr = armorIconAbbr
SA.ArmorIconColor = armorIconColor
