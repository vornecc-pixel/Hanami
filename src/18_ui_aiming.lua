-- ==================================================================
-- Hanami / 18_ui_aiming.lua — Atlanta UI setup + Aiming tab
-- Loaded in order by loader.lua. Parts are joined into ONE chunk
-- before running, so every `local` is shared just like the original.
-- ==================================================================

-- ==================================================================
-- UI (Atlanta Library) — kept in one chunk with the rest of the suite
-- ==================================================================

local library, themes = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/i77lhm/Libraries/refs/heads/main/Atlanta/Library.lua"))()

local dim2 = UDim2.new

local window = library:window({
    name = os.date("Hanami | @abusegpt - %b %d %Y"),
    size = dim2(0, 750, 0, 782),
})

local Aiming    = window:tab({ name = "Aiming" })
local EspTab    = window:tab({ name = "ESP" })
local GunTab    = window:tab({ name = "Gun Mods" })
local VisualTab = window:tab({ name = "Visual" })
local MiscTab   = window:tab({ name = "Misc" })

-- ── binding helpers ────────────────────────────────────────────────
-- Atlanta calls `cfg.set(default)` while building a widget, which fires
-- the callback. Every `default` therefore comes from CFG, so creating
-- the menu never overwrites the settings kept in _G.__saCFG.
-- Flags are prefixed "hn_" to avoid colliding with the library's own.
local function setToggle(obj, value)
    obj.enabled = value       -- Atlanta's cfg.set() does not sync this
    obj.set(value)            -- fires the callback -> writes CFG
end

local function setFlag(key, value)
    local setter = library.config_flags["hn_" .. key]
    if setter then setter(value) end
end

local function bindToggle(sec, label, key, tooltip)
    local flag = "hn_" .. key
    local obj = sec:toggle({
        name = label, flag = flag,
        enabled = CFG[key], default = CFG[key], tooltip = tooltip,
        callback = function(v) CFG[key] = v end,
    })
    -- keep `.enabled` in sync when a config/quick-action sets the flag
    library.config_flags[flag] = function(v) setToggle(obj, v) end
    return obj
end

local function bindSlider(sec, label, key, min, max, interval, suffix)
    return sec:slider({
        name = label, flag = "hn_" .. key,
        min = min, max = max, default = CFG[key],
        interval = interval, suffix = suffix or "",
        callback = function(v) CFG[key] = v end,
    })
end

local function bindDropdown(sec, label, key, items)
    return sec:dropdown({
        name = label, flag = "hn_" .. key,
        items = items, default = CFG[key],
        callback = function(v) CFG[key] = v end,
    })
end

-- Atlanta buttons need a button_holder row created on the same section
local function addButton(sec, label, fn)
    sec:button_holder({})
    return sec:button({ name = label, callback = fn })
end

-- ── AIMING : column 1 (Silent Aim / Gun) ───────────────────────────
local aimCol = Aiming:column()
local masterSec, gunSec = aimCol:multi_section({ names = { "Silent Aim", "Gun" } })

local masterToggle = bindToggle(masterSec, "Enabled", "masterEnabled",
    "Master switch for the camera sandwich")
masterToggle:keybind({
    name = "Toggle Aim", flag = "hn_master_bind",
    key = Enum.KeyCode.RightShift, mode = "toggle",
    default = CFG.masterEnabled,
    callback = function(active) setToggle(masterToggle, active) end,
})

local hitChanceSlider, cooldownSlider  -- assigned in column 2
local presetDropdown = masterSec:dropdown({
    name = "Preset", flag = "hn_preset",
    items = { "Custom", "Legit", "Blatant" }, default = "Custom",
    callback = function(mode)
        if mode == "Legit" then
            CFG.hitChance, CFG.gunCooldown, CFG.prediction = 60, 0.1, true
        elseif mode == "Blatant" then
            CFG.hitChance, CFG.gunCooldown, CFG.prediction = 100, 0, true
        else return end
        hitChanceSlider.set(math.clamp(CFG.hitChance, 0, 100))
        cooldownSlider.set(math.clamp(CFG.gunCooldown, 0, 1))
        setFlag("prediction", true)
    end,
})

bindToggle(gunSec, "Gun Silent Aim", "gunEnabled")
bindToggle(gunSec, "Only While Firing", "gunShotOnly")
bindToggle(gunSec, "Prediction", "prediction")
bindToggle(gunSec, "Wall Check", "wallCheck",
    "Strict LOS-only shots. Automatically bypassed while Manipulation is ON, so leave OFF for wall pen")
bindToggle(gunSec, "Team Check", "teamCheck")
bindToggle(gunSec, "Target NPCs", "targetNpcs",
    "Guard / Scavenger / Soldier models are found anywhere in Workspace (not just an Npcs folder)")

-- ── AIMING : column 2 (Target / Wall Penetration) ──────────────────
local aimCol2 = Aiming:column()
local targetSec, manipSec = aimCol2:multi_section({ names = { "Target", "Wall Penetration" } })

bindDropdown(targetSec, "Target Bone", "targetBone", { "Head", "Hrp" })
hitChanceSlider = bindSlider(targetSec, "Hit Chance (%)", "hitChance", 0, 100, 1, "%")
bindSlider(targetSec, "Max Distance (studs)", "distance", 0, 500, 1, "")
cooldownSlider = bindSlider(targetSec, "Cooldown (s)", "gunCooldown", 0, 1, 0.01, "s")
bindSlider(targetSec, "Bullet Speed Override (0 = auto)", "gunBulletSpeed", 0, 1500, 1, "")

bindToggle(manipSec, "Enabled (FOV-aware)", "manipulation",
    "Best all-round: ON, Wall Check OFF, Range 75, Peek 4, Parts 3, Budget 64, Hysteresis 5, Max Delta 6, FOV ~150")
bindSlider(manipSec, "Range (studs)", "manipDist", 5, 100, 1, "")
bindSlider(manipSec, "Max Peek Offset", "manipPeek", 0, 8, 0.5, "")
bindSlider(manipSec, "Max CanQuery Parts", "manipMaxParts", 0, 8, 1, "")
bindSlider(manipSec, "Ray Budget / Frame", "manipBudget", 8, 128, 1, "")
bindSlider(manipSec, "Cache Hysteresis (frames)", "manipHysteresis", 0, 12, 1, "")
bindSlider(manipSec, "Max Peek Delta", "manipMaxPeekDelta", 2, 12, 1, "")

manipSec:label({ name = "Recommended: 75 / 4 / 3 / 64 / 5 / 6" })
manipSec:label({ name = "Range | Peek | Parts | Budget | Hyst | Delta" })
manipSec:label({ name = "Tighter FOV (~150px) = fewer peeks per frame" })
addButton(manipSec, "Apply Recommended Wall Pen", function()
    setFlag("manipulation", true)
    setFlag("wallCheck", false)
    setFlag("manipDist", 75)
    setFlag("manipPeek", 4)
    setFlag("manipMaxParts", 3)
    setFlag("manipBudget", 64)
    setFlag("manipHysteresis", 5)
    setFlag("manipMaxPeekDelta", 6)
    setFlag("fov", 150)
    setFlag("hitChance", 100)
    setFlag("gunCooldown", 0)
    print("[sa] recommended wall pen applied")
end)
