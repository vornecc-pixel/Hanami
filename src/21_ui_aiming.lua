-- ==================================================================
-- Hanami / 21_ui_aiming.lua — Atlanta UI setup + Aiming tab
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
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

local hitChanceSlider, cooldownSlider = nil, nil  -- assigned in column 2
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
bindToggle(gunSec, "Wall Check", "wallCheck",
    "Strict LOS-only shots. Automatically bypassed while Manipulation is ON, so leave OFF for wall pen")
bindToggle(gunSec, "Team Check", "teamCheck")
bindToggle(gunSec, "Target NPCs", "targetNpcs",
    "Guard / Scavenger / Soldier models are found anywhere in Workspace (not just an Npcs folder)")

-- v7.7 tap-fire fixes. Fix A reorders InputBegan, Fix B reorders
-- Tool.Activated. Both are guarded and fall back to the render-step snap.
bindToggle(gunSec, "Tap-Fire Reorder (Fix A/B)", "saTapReorder",
    "Snap the camera BEFORE the game's fire handlers run; needs getconnections. Falls back to the render-step snap")
bindSlider(gunSec, "Tap Window (s)", "saTapWindow", 0.1, 1, 0.05, "s")
bindToggle(gunSec, "Bow Shoot Hook", "saBowHook",
    "Rewrites data.dir / data.origin on Fust.Remotes.Shoot for bows; needs hookfunction")

-- ── AIMING : column 2 (Target / Ballistics / Wall Penetration) ──────
local aimCol2 = Aiming:column()
local targetSec, ballSec, manipSec = aimCol2:multi_section({
    names = { "Target", "Ballistics", "Wall Penetration" },
})

bindDropdown(targetSec, "Target Bone", "targetBone", { "Head", "Hrp" })
hitChanceSlider = bindSlider(targetSec, "Hit Chance (%)", "hitChance", 0, 100, 1, "%")
bindSlider(targetSec, "Max Distance (studs)", "distance", 0, 500, 1, "")
cooldownSlider = bindSlider(targetSec, "Cooldown (s)", "gunCooldown", 0, 1, 0.01, "s")

-- ── AIMING : Ballistics ─────────────────────────────────────────────
bindToggle(ballSec, "Ballistic Prediction", "prediction",
    "Exact quadratic intercept using the equipped gun's real speed (not the old distance/speed guess)")
bindToggle(ballSec, "Bullet Drop Compensation", "predictionGravity",
    "Aims above by 0.5 * gravity * t^2 for guns with gravity/life (SMGs and the two snipers)")
bindToggle(ballSec, "Detect Alt Ammo", "predictionAmmo",
    "Reads hv_rifle_ammo (1.5x speed), buckshot_shell, slug_shell and hv_rocket from the tool")
bindSlider(ballSec, "Solver Iterations", "predictionIterations", 1, 8, 1, "")
bindToggle(ballSec, "Auto Ping Lead", "predictionAutoPing",
    "Reads your live ping (GetNetworkPing / Data Ping), smooths it and feeds it into every prediction — no manual guessing")
bindSlider(ballSec, "Ping Scale", "predictionPingScale", 0, 2, 0.1, "x")
bindSlider(ballSec, "Extra Ping Offset (ms)", "predictionLatency", 0, 300, 5, "ms")
ballSec:label({ name = "Auto Ping ON: scale x ping + offset = extra lead" })
bindSlider(ballSec, "Bullet Speed Override (0 = auto)", "gunBulletSpeed", 0, 3000, 10, "")
bindDropdown(ballSec, "Ammo Override", "gunAmmoOverride", {
    "Auto", "handmade_shell", "pistol_bullet", "rifle_ammo", "rocket",
    "hv_rifle_ammo", "explosive_rifle_ammo", "buckshot_shell", "slug_shell",
    "hv_rocket", "incendiary_rocket",
})
bindToggle(ballSec, "Saturday2 Damage", "saturday2Mode",
    "Uses the s2Damage branch of u3492.GunDamage if the game exposes it; otherwise Defs[ammo].damage x damageMult")
bindToggle(ballSec, "Muzzle Boost Equipped", "muzzleBoost",
    "muzzle_boost: +15% fire rate, -10% damage (affects the spec readout, not projectile speed)")
ballSec:label({ name = "Speeds are the gun's `speed` field (GUNS overrides applied)" })
ballSec:label({ name = "Damage = Defs[ammo].damage x damageMult (the damage field is 0)" })
addButton(ballSec, "Print Gun Spec", function() SA.PrintGunSpec() end)
addButton(ballSec, "Print Live Ping", function()
    print(string.format("[sa] ping %.0f ms | auto %s | scale %.1f | offset %.0f ms | total %.0f ms",
        SA.GetPing(), CFG.predictionAutoPing and "ON" or "OFF",
        CFG.predictionPingScale or 1, CFG.predictionLatency or 0, SA.LeadLatencyMs()))
end)

bindToggle(manipSec, "Enabled (FOV-aware, v4)", "manipulation",
    "8 peek directions + adaptive peek + target-aware ray filter. Best with Wall Check OFF and FOV ~150")
bindSlider(manipSec, "Range (studs)", "manipDist", 5, 1500, 5, "")
bindSlider(manipSec, "Base Peek Offset", "manipPeek", 0, 60, 1, "")
bindSlider(manipSec, "Adaptive Peek Cap", "manipMaxPeek", 20, 300, 5, "")
bindSlider(manipSec, "Max CanQuery Parts", "manipMaxParts", 0, 96, 1, "")
bindSlider(manipSec, "Ray Budget / Frame", "manipBudget", 8, 256, 1, "")
bindSlider(manipSec, "Cache Hysteresis (frames)", "manipHysteresis", 0, 12, 1, "")
bindSlider(manipSec, "Max Peek Delta", "manipMaxPeekDelta", 2, 120, 1, "")

manipSec:label({ name = "v7.7 defaults: 1000 / 20 / 120 / 48 / 96 / 3 / 40" })
manipSec:label({ name = "Range | Peek | Cap | Parts | Budget | Hyst | Delta" })
manipSec:label({ name = "Adaptive peek = base + 6% of distance, capped" })
manipSec:label({ name = "Tighter FOV (~150px) = fewer peeks per frame" })
addButton(manipSec, "Apply Recommended Wall Pen", function()
    setFlag("manipulation", true)
    setFlag("wallCheck", false)
    setFlag("manipDist", 1000)
    setFlag("manipPeek", 20)
    setFlag("manipMaxPeek", 120)
    setFlag("manipMaxParts", 48)
    setFlag("manipBudget", 96)
    setFlag("manipHysteresis", 3)
    setFlag("manipMaxPeekDelta", 40)
    setFlag("fov", 150)
    setFlag("hitChance", 100)
    setFlag("gunCooldown", 0)
    print("[sa] v7.7 recommended wall pen applied")
end)
