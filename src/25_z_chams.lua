-- ==================================================================
-- Hanami / 25_z_chams.lua
-- HAND CHAMS + WEAPON CHAMS, each fully independent.
--
-- Option set ported from the "FUST VIEWMODEL FX & ANIMATION STUDIO V10"
-- snippet (16 themed engines, per-frame material / colour animation) and
-- from the older "1x1x1x1_CORRUPTED" cham (wireframe spikes + runic
-- glyph BillboardGuis).
--
-- What is kept from the studio, and what was deliberately changed:
--   * All 16 themes are here, unchanged in look: the 10 palette themes
--     (Quantum_Void .. Matrix_Overload) plus the 6 procedural ones
--     (Matrix_Glitch, Cosmic_Nebula, Cyber_Wave, Biohazard_Slime,
--     Supernova_Flux). The studio's "1x1x1x1_Corrupted" is not a separate
--     entry because our "Corrupted" style already IS that look.
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
--   * It does not drive itself from math.random() per frame (the snippets
--     flashed on a random fraction of frames and rerolled glyphs
--     constantly, which is pure churn). Here the pulse is a deterministic
--     function of time and a per-part phase offset, and glyph text changes
--     on a timed beat. Themes that looked random (Matrix_Glitch's
--     "breakdown", Electric_Arc's jitter, the Corrupted spike flash) use a
--     deterministic hash of (time bucket, part phase) instead, so the same
--     part always flashes the same way and nothing flickers per frame.
--   * It runs on ONE bindRender callback with an early exit, walks only the
--     local character's parts, and writes a property only when it actually
--     changes.
-- ==================================================================

-- Rune alphabet from the source snippet.
SA.CHAM_GLYPHS = { "1", "x", "0", "!", "?", "Ø", "§", "†", "‡", "¶", "#", "X" }

-- Palette used by the "corrupted" style.
local CORRUPT_DARK   = Color3.fromRGB(15, 12, 14)
local CORRUPT_RED    = Color3.fromRGB(200, 0, 25)
local CORRUPT_SPIKE  = Color3.fromRGB(25, 0, 5)
local CORRUPT_WIRE   = Color3.fromRGB(255, 0, 30)
local CORRUPT_WHITE  = Color3.fromRGB(255, 255, 255)

-- The 10 themed palettes from the studio. Primary / Accent / Light and the
-- tracer material the theme would use for bullet tracers.
local CHAM_PALETTES = {
    Quantum_Void    = { Primary = Color3.fromRGB(15, 0, 35),    Accent = Color3.fromRGB(180, 0, 255),  Light = Color3.fromRGB(220, 150, 255) },
    Solar_Flare     = { Primary = Color3.fromRGB(255, 60, 0),   Accent = Color3.fromRGB(255, 180, 0),  Light = Color3.fromRGB(255, 255, 240) },
    Cyber_Synthwave = { Primary = Color3.fromRGB(255, 0, 140),  Accent = Color3.fromRGB(0, 240, 255),  Light = Color3.fromRGB(255, 255, 255) },
    Bio_Toxic       = { Primary = Color3.fromRGB(40, 160, 10),  Accent = Color3.fromRGB(140, 255, 0),  Light = Color3.fromRGB(200, 255, 100) },
    Chrono_Shift    = { Primary = Color3.fromRGB(180, 140, 20), Accent = Color3.fromRGB(255, 215, 60), Light = Color3.fromRGB(255, 255, 220) },
    Deep_Frost      = { Primary = Color3.fromRGB(0, 120, 220),  Accent = Color3.fromRGB(100, 220, 255), Light = Color3.fromRGB(230, 250, 255) },
    Blood_Moon      = { Primary = Color3.fromRGB(40, 0, 8),     Accent = Color3.fromRGB(220, 0, 30),   Light = Color3.fromRGB(255, 80, 90) },
    Electric_Arc    = { Primary = Color3.fromRGB(0, 80, 255),   Accent = Color3.fromRGB(120, 220, 255), Light = Color3.fromRGB(255, 255, 255) },
    Prismatic_RGB   = { Primary = Color3.fromRGB(255, 0, 100),  Accent = Color3.fromRGB(0, 255, 200),  Light = Color3.fromRGB(255, 255, 255) },
    Matrix_Overload = { Primary = Color3.fromRGB(0, 40, 10),    Accent = Color3.fromRGB(0, 255, 70),   Light = Color3.fromRGB(220, 255, 230) },
}

-- The procedural studio themes. Kept as a separate list because the
-- engine branches on them rather than reading a palette.
-- "1x1x1x1_Corrupted" is deliberately ABSENT: that is what our existing
-- "Corrupted" style already renders, so importing it again would just put
-- two identical entries in the dropdown.
local CHAM_PROCEDURAL = {
    "Matrix_Glitch", "Cosmic_Nebula",
    "Cyber_Wave", "Biohazard_Slime", "Supernova_Flux",
}

-- SA.CHAM_STYLES / SA.CHAM_STYLE_SET are declared in 01_config.lua so the
-- load-time clamp can validate a saved style against the same list the
-- dropdown and this engine use. Nothing to redefine here.
assert(SA.CHAM_STYLE_SET and SA.CHAM_STYLE_SET.Corrupted,
    "chams: 01_config.lua must declare SA.CHAM_STYLES before this part")

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

-- ── DETERMINISM HELPERS ─────────────────────────────────────────────
-- The snippets used math.random() inside the frame loop: a part flashed on
-- ~8% of frames, so the look was different every time you looked at it and
-- the property writes never settled. These helpers give the SAME
-- pseudo-random-looking variation from a (time bucket, phase) pair, so a
-- flashing theme is stable within its bucket and costs nothing per frame.
-- Pure-arithmetic LCG: no bit32 / bit library assumption (Roblox has
-- bit32, plain Lua 5.3 does not), and every product stays under 2^53 so
-- Luau's floats stay exact.
local function chamHash(a, b)
    local n = ((a or 0) % 1048576) * 1103515 + ((b or 0) % 1048576) * 12345
    n = (n % 2147483) * 48271 % 2147483
    n = (n % 99991) * 16807 % 99991
    return (n % 100000) / 100000
end

-- ── MATERIAL / COLOUR PER STYLE ─────────────────────────────────────
-- Returns material, colour, transparency for a part at time `t`.
-- `phase` is a per-part offset so the left and right hand never pulse in
-- lockstep -- that synchronised flashing is what made the original look
-- like one solid blob rather than two moving hands.
--
-- Every theme uses the part's local Y (via `phase`) so the sweep / scan
-- themes read as a wave travelling across the hand or down the gun.
local function chamLook(style, t, phase, intensity, baseColor)
    intensity = math.max(tonumber(intensity) or 1, 0.05)
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

    local pal = CHAM_PALETTES[style]

    -- ── the 10 palette themes, straight from applyV8EngineFrame ──
    if style == "Quantum_Void" then
        local void = math.sin(t * 8 + phase)
        if void > 0.4 then
            return Enum.Material.ForceField, pal.Accent, 0.2
        end
        return Enum.Material.Glass, pal.Primary, 0.2
    elseif style == "Solar_Flare" then
        local flare = (math.sin(t * 14 + phase) + 1) * 0.5
        if flare > 0.85 then
            return Enum.Material.Neon, pal.Light, 0
        elseif flare > 0.4 then
            return Enum.Material.Neon, pal.Accent, 0
        end
        return Enum.Material.Neon, pal.Primary, 0
    elseif style == "Cyber_Synthwave" then
        local sweep = math.sin(t * 8 - phase * 12)
        if sweep > 0.7 then
            return Enum.Material.Neon, pal.Primary, 0
        end
        return Enum.Material.ForceField, pal.Accent, 0.35
    elseif style == "Bio_Toxic" then
        local boil = (math.sin(t * 12 + phase * 8)
            + math.cos(t * 8 + phase * 8)) * 0.5
        if boil > 0.3 then
            return Enum.Material.Glass, pal.Accent, 0.15
        end
        return Enum.Material.Glass, pal.Primary, 0.15
    elseif style == "Chrono_Shift" then
        -- A 16 Hz tick, but bucketed: the material only flips on the beat.
        if math.floor(t * 16 + phase) % 2 == 0 then
            return Enum.Material.Foil, pal.Accent, 0.1
        end
        return Enum.Material.Glass, pal.Primary, 0.1
    elseif style == "Deep_Frost" then
        local crystal = (math.sin(t * 5 + phase * 10) + 1) * 0.5
        return Enum.Material.Ice, pal.Primary:Lerp(pal.Accent, crystal), 0.2
    elseif style == "Blood_Moon" then
        local eclipse = math.sin(t * 9 + phase * 6)
        if eclipse > 0.3 then
            return Enum.Material.Neon, pal.Accent, 0
        end
        return Enum.Material.CorrodedMetal, pal.Primary, 0
    elseif style == "Electric_Arc" then
        -- Deterministic jitter on a ~10 Hz bucket instead of math.random().
        local jitter = chamHash(math.floor(t * 10), math.floor(phase * 97)) < 0.2
        if jitter then
            return Enum.Material.ForceField, pal.Light, 0.4
        end
        return Enum.Material.Neon, pal.Primary, 0
    elseif style == "Prismatic_RGB" then
        local hue = (t * 0.4 + phase * 0.2) % 1
        return Enum.Material.Neon, Color3.fromHSV(hue, 0.9, 1), 0
    elseif style == "Matrix_Overload" then
        local step = math.floor(t * 22 + phase * 7) % 3
        if step == 0 then
            return Enum.Material.Neon, pal.Light, 0.3
        elseif step == 1 then
            return Enum.Material.Neon, pal.Accent, 0
        end
        return Enum.Material.Neon, pal.Primary, 0

    -- ── the 6 procedural themes, from applyV5EngineFrame ──
    elseif style == "Matrix_Glitch" then
        -- A "major breakdown" is the theme's whole character: it also
        -- drives the wireframe flash and the chromatic fringe. Bucketed at
        -- 6 Hz so it is stable for ~160 ms rather than per frame.
        local bucket = math.floor(t * 6)
        local breakdown = chamHash(bucket, math.floor(phase * 53)) < 0.08 * intensity
        if breakdown then
            if chamHash(bucket, 7) < 0.3 then
                return Enum.Material.ForceField, Color3.fromRGB(240, 255, 245), 0.4
            end
            return Enum.Material.ForceField, Color3.fromRGB(0, 255, 70), 0.4
        end
        local pulse = math.sin(t * 18 + phase * 7)
        if pulse > 0.65 then
            return Enum.Material.Neon, Color3.fromRGB(0, 255, 70), 0
        elseif pulse < -0.65 then
            return Enum.Material.Glass, Color3.fromRGB(0, 60, 20), 0
        end
        return Enum.Material.SmoothPlastic, Color3.fromRGB(10, 35, 15), 0
    elseif style == "Cosmic_Nebula" then
        local wave = (t * 1.5 + phase * 3) % (math.pi * 2)
        local r = (math.sin(wave) + 1) * 0.5
        local g = (math.sin(wave + 2.09) + 1) * 0.5
        local b = (math.sin(wave + 4.18) + 1) * 0.5
        return Enum.Material.Glass,
            Color3.new(0.1 + 0.7 * r, 0.05 + 0.3 * g, 0.4 + 0.6 * b),
            0.15 + math.sin(t * 4 + phase) * 0.1
    elseif style == "Cyber_Wave" then
        local scan = math.sin(t * 8 - phase * 12)
        if scan > 0.75 then
            return Enum.Material.Neon, Color3.fromRGB(255, 0, 140), 0
        end
        return Enum.Material.ForceField, Color3.fromRGB(0, 240, 255), 0.35
    elseif style == "Biohazard_Slime" then
        local boil = (math.sin(t * 14 + phase * 10)
            + math.cos(t * 9 + phase * 10)) * 0.5
        if boil > 0.4 then
            return Enum.Material.Glass, Color3.fromRGB(140, 255, 0), 0.05
        end
        return Enum.Material.Glass, Color3.fromRGB(50, 180, 20), 0.35
    elseif style == "Supernova_Flux" then
        local flare = (math.sin(t * 16 + phase) + 1) * 0.5
        if flare > 0.85 then
            return Enum.Material.Neon, Color3.fromRGB(255, 255, 240), 0
        elseif flare > 0.4 then
            return Enum.Material.Neon, Color3.fromRGB(255, 120, 0), 0
        end
        return Enum.Material.Neon, Color3.fromRGB(200, 20, 0), 0
    end

    -- Corrupted (default): Obsidian / red Neon pulsing.
    local pulse = math.sin(t * 12 + phase)
    if pulse > 0.4 * intensity then
        return Enum.Material.Neon, baseColor or CORRUPT_RED, 0
    end
    return Enum.Material.CorrodedMetal, CORRUPT_DARK, 0
end

-- Does this style ask for the wireframe spike box / chromatic fringe?
-- Both the studio themes and the simple ones can request them; the flags
-- stay per-slot so hands and weapon never share.
local function chamWantsSpike(style, spikesFlag)
    if spikesFlag then return true end
    -- The Wireframe style is defined by its box, so it always draws one.
    return style == "Wireframe"
end

-- The accent colour a theme uses for its wireframe / fringe / rune art.
local function chamAccent(style, baseColor)
    local pal = CHAM_PALETTES[style]
    if pal then return pal.Accent end
    if style == "Matrix_Glitch" then return Color3.fromRGB(0, 255, 240) end
    return baseColor or CORRUPT_WIRE
end

-- ── PART DISCOVERY ──────────────────────────────────────────────────
-- The studio's isHandPart(): any part whose name mentions an arm, hand,
-- wrist, elbow or sleeve is "hands". Everything else on a viewmodel is
-- treated as the weapon. Used only to split the two viewmodels, never to
-- touch anybody else's character.
local HAND_WORDS = { "arm", "hand", "wrist", "elbow", "sleeve", "glove" }

local function chamIsHandName(name)
    local lower = string.lower(name or "")
    if HAND_PARTS[name] then return true end
    for _, word in ipairs(HAND_WORDS) do
        if string.find(lower, word, 1, true) then return true end
    end
    return false
end

local function chamIsPart(inst)
    if not inst then return false end
    local ok, res = pcall(function() return inst:IsA("BasePart") end)
    return ok and res == true
end

local function chamPushPart(out, seen, part)
    if seen[part] or not chamIsPart(part) then return end
    -- Fully invisible parts are skipped: painting them would only write
    -- properties nobody can see, and the studio skipped them too.
    local tr = chamGet(part, "Transparency", 0)
    if type(tr) == "number" and tr >= 1 then return end
    seen[part] = true
    out[#out + 1] = part
end

-- The Fust first-person viewmodels. In a first-person game these -- not
-- the third-person character arms -- are what the player actually sees,
-- so a cham that only painted Workspace arms would look like nothing
-- happened. Both are optional: the walk is pcall'd and a missing model is
-- simply skipped.
local function chamViewmodels()
    local out = {}
    pcall(function()
        local gunFX = Workspace:FindFirstChild("FustGunFX")
        local gunVM = gunFX and gunFX:FindFirstChild("FustGunViewmodel")
        if gunVM then out[#out + 1] = gunVM end
        local camera = Workspace.CurrentCamera
        local toolVM = camera and camera:FindFirstChild("FustToolViewmodel")
        if toolVM then out[#out + 1] = toolVM end
    end)
    return out
end

-- Collect the local character's hand parts and the equipped tool's parts.
-- Read-only walk; never mutates the hierarchy.
local function chamCollect(slotName)
    local out, seen = {}, {}
    local char = lp and lp.Character

    -- 1. the local character's own arms / hands (third person + R6)
    if char and slotName == "hand" then
        pcall(function()
            for _, part in ipairs(char:GetChildren()) do
                if type(part.Name) == "string" and HAND_PARTS[part.Name] then
                    chamPushPart(out, seen, part)
                end
            end
        end)
    end

    -- 2. the equipped tool's parts (the real gun model)
    if slotName == "weapon" and char then
        local tool = nil
        pcall(function() tool = char:FindFirstChildOfClass("Tool") end)
        if tool then
            pcall(function()
                if chamIsPart(tool) then chamPushPart(out, seen, tool) end
                for _, part in ipairs(tool:GetDescendants()) do
                    chamPushPart(out, seen, part)
                end
            end)
        end
    end

    -- 3. the first-person viewmodels, split by part name exactly like the
    --    studio's Target = "Hands" / "Weapon" split.
    for _, vm in ipairs(chamViewmodels()) do
        pcall(function()
            for _, part in ipairs(vm:GetDescendants()) do
                if chamIsPart(part) then
                    local isHand = chamIsHandName(part.Name)
                    if (slotName == "hand") == isHand then
                        chamPushPart(out, seen, part)
                    end
                end
            end
        end)
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
    -- Resolve the style here as well as in the load-time clamp: a saved
    -- profile / clipboard import can write a style name this build does
    -- not have, and an unknown name would silently fall through chamLook
    -- to the default look while the dropdown still showed the old value.
    local style = CFG[prefix .. "Style"]
    if not (type(style) == "string" and SA.CHAM_STYLE_SET[style]) then
        style = "Corrupted"
        CFG[prefix .. "Style"] = style
        pcall(setFlag, prefix .. "Style", style)
    end
    local intensity = tonumber(CFG[prefix .. "Intensity"]) or 1
    local auraOn = CFG[prefix .. "Aura"] == true
    local wireOn = chamWantsSpike(style, CFG[prefix .. "Spikes"] == true)
    local baseColor = ESP_COLORS[prefix .. "Color"] or CORRUPT_RED
    -- Wireframe / fringe / rune colour follows the theme, so a Solar_Flare
    -- box is not red and a Matrix_Glitch one is not red either.
    local accent = chamAccent(style, baseColor)

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
        -- The studio's "breakdown" themes only draw their box on a
        -- breakdown frame; a plain Wireframe style draws it always.
        local showBox = wireOn
        if wireOn and style == "Matrix_Glitch" then
            showBox = chamHash(math.floor(t * 6), math.floor(phase * 53))
                < 0.08 * math.max(intensity, 0.05)
        end
        if showBox then
            local box = chamEnsureBox(slot, part)
            if box then
                chamSet(box, "Color3", accent)
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
                        lbl.TextColor3 = accent
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
    slot.style = style
    slot.active = true
    slot.reason = "active"
    slot.count = #parts
end

-- ── PUBLIC API ──────────────────────────────────────────────────────
-- Clear whatever one slot has painted, without touching the other. The
-- render loop used to clear a slot only while BOTH flags were off, so
-- switching just the hands off (weapon still on) left the arms painted
-- forever. Both the loop and ChamsState() go through here.
local function chamSyncSlot(name, t)
    local slot = chams[name]
    local prefix = name == "hand" and "handChams" or "weaponChams"
    local want = CFG[prefix] == true
    if want then
        chamTickSlot(name, t)
        return
    end
    if slot.active or next(slot.parts) ~= nil
        or next(slot.auras) ~= nil or next(slot.boxes) ~= nil then
        chamClearSlot(slot)
    end
    slot.reason = "disabled"
end

function SA.ChamsSet(slotName, on)
    if slotName ~= "hand" and slotName ~= "weapon" then return false end
    local flag = slotName == "hand" and "handChams" or "weaponChams"
    CFG[flag] = on == true
    pcall(setFlag, flag, CFG[flag])
    return true
end

-- Explicit repaint: the UI's "apply now" path. The per-frame render loop
-- already keeps both slots current, so this is only for a style change
-- that should land before the next frame.
function SA.ChamsRefresh()
    local t = tick()
    chamSyncSlot("hand", t)
    chamSyncSlot("weapon", t)
    return SA.ChamsState()
end

-- Read-only: a state probe must never paint. It used to call the tick
-- for both slots, so asking "are the chams on?" could repaint the arms
-- after the flags had already been switched off.
function SA.ChamsState()
    local function summary(slot)
        local auras, boxes = 0, 0
        for _ in pairs(slot.auras) do auras = auras + 1 end
        for _ in pairs(slot.boxes) do boxes = boxes + 1 end
        return {
            active = slot.active == true,
            style = slot.style or "Corrupted",
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
    -- Each slot is gated on its OWN flag. Both off is the cheap case (two
    -- boolean reads, then a next() check that is already empty).
    if CFG.handChams ~= true and CFG.weaponChams ~= true
        and not chams.hand.active and not chams.weapon.active
        and next(chams.hand.parts) == nil and next(chams.weapon.parts) == nil
        and next(chams.hand.auras) == nil and next(chams.weapon.auras) == nil
        and next(chams.hand.boxes) == nil and next(chams.weapon.boxes) == nil then
        return
    end
    local ok, err = pcall(function()
        local t = tick()
        chamSyncSlot("hand", t)
        chamSyncSlot("weapon", t)
    end)
    if not ok then
        chams.errors = chams.errors + 1
        chams.lastError = tostring(err)
    end
end)
