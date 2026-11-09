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

-- ── Atlanta keybind upgrades ────────────────────────────────────────
-- The stock library already accepts ANY Enum.KeyCode / UserInputType,
-- but its "Keybinds" panel keeps showing a bind after Escape sets it to
-- "none", and right-click only opens the mode selector. This wrapper:
--   * hides the keybind-list row when the key is "none";
--   * RIGHT-CLICK on the key widget (or its list row) sets it to "none"
--     and removes/hides it from the list without disabling the feature;
--   * keeps every real key + mouse button bindable (no whitelist).
-- It must be installed BEFORE library:window(), so the template's own
-- "UI Bind" and every feature keybind below get the same behaviour.
local saKeybindCreate = library.create
local saKeybindOriginal = library.keybind
local saKeybindCapture = nil

function library:create(class, props, ...)
    local inst = saKeybindCreate(self, class, props, ...)
    if saKeybindCapture and props then
        -- keybind's little TextButton is 24x14 with empty text
        if class == "TextButton" and props.Text == ""
            and props.Size and props.Size.X and props.Size.X.Offset == 24 then
            saKeybindCapture.button = inst
        end
        -- keybind-list row is a TextLabel parented to library.keybind_list
        if class == "TextLabel" and props.Parent == library.keybind_list then
            saKeybindCapture.listLbl = inst
        end
    end
    return inst
end

local function saFindKeybindLabel(name)
    if not name or not library.keybind_list then return nil end
    for _, c in ipairs(library.keybind_list:GetChildren()) do
        if c:IsA("TextLabel") and string.find(c.Text, name, 1, true) then
            return c
        end
    end
    return nil
end

function library:keybind(opts)
    saKeybindCapture = {}
    local ok, cfg = pcall(saKeybindOriginal, self, opts)
    local cap = saKeybindCapture
    saKeybindCapture = nil
    if not ok then error(cfg, 0) end

    local listLbl = cap.listLbl or saFindKeybindLabel(opts and opts.name)
    local origSet = cfg.set

    local function refreshList()
        listLbl = listLbl or saFindKeybindLabel(opts and opts.name)
        if not listLbl then return end
        local isNone = cfg.key == "none"
            or tostring(cfg.key):find("none", 1, true) ~= nil
        -- "none" / inactive binds must vanish from the Keybinds panel.
        listLbl.Visible = (cfg.active == true) and not isNone
    end

    cfg.set = function(input, ...)
        origSet(input, ...)
        refreshList()
    end
    -- Config loading and quick actions go through config_flags, so make
    -- sure they hit the wrapper rather than the stock setter.
    library.config_flags[cfg.flag] = cfg.set

    local function clearBind()
        -- Escape is Atlanta's built-in "none" token; this keeps the
        -- feature in its current ON/OFF state instead of turning it off.
        pcall(function() cfg.set(Enum.KeyCode.Escape) end)
        cfg.key = "none"
        cfg.key_name = "none"
        cfg.open = false
        if cfg.set_visible then pcall(cfg.set_visible, false) end
        -- Atlanta's own MouseButton2Click opens the mode selector. Our
        -- handler may run BEFORE it, so defer one more close to make sure
        -- right-click leaves the selector closed regardless of ordering.
        pcall(function()
            task.defer(function()
                cfg.open = false
                if cfg.set_visible then pcall(cfg.set_visible, false) end
            end)
        end)
        refreshList()
    end

    cfg.__saButton = cap.button
    cfg.__saListLbl = listLbl
    cfg.__saClear = clearBind

    if cap.button then
        pcall(function()
            cap.button.MouseButton2Click:Connect(function() clearBind() end)
        end)
    end
    if listLbl then
        -- TextLabel has no MouseButton2Click; InputBegan catches RMB.
        -- TextLabels are passive by default, so Active must be ON for the
        -- Keybinds panel row to receive mouse input at all.
        pcall(function() listLbl.Active = true end)
        pcall(function()
            listLbl.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton2 then
                    clearBind()
                end
            end)
        end)
    end
    refreshList()
    return cfg
end

SA.FeatureBinds = SA.FeatureBinds or {}
function SA.FeatureKeybind(obj, name, flag, key, cfgKey)
    if not obj or not obj.keybind then return nil end
    local bind = obj:keybind({
        name = name, flag = flag, key = key, mode = "toggle",
        default = CFG[cfgKey] == true,
        callback = function(active)
            if not SA.Alive then return end
            local on = active == true
            obj.enabled = on        -- same sync as setToggle(), without a
            pcall(function() obj.set(on) end) -- forward dependency on it
        end,
    })
    SA.FeatureBinds[flag] = bind
    return bind
end
function SA.FeatureBindDiag()
    print("════════════ FEATURE KEYBINDS ════════════")
    for flag, cfg in pairs(SA.FeatureBinds) do
        local kn = cfg.key_name or tostring(cfg.key)
        print(string.format("  %-26s key=%-14s mode=%-6s active=%s",
            flag, tostring(kn), tostring(cfg.mode), tostring(cfg.active)))
    end
    print("  right-click a key widget / list row = None + remove from list")
    print("══════════════════════════════════════")
end
function SA.FeatureBindClear(flag)
    local cfg = SA.FeatureBinds[flag]
    if cfg and cfg.__saClear then cfg.__saClear() end
end

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
local masterBind = masterToggle:keybind({
    name = "Toggle Aim", flag = "hn_master_bind",
    key = Enum.KeyCode.RightShift, mode = "toggle",
    default = CFG.masterEnabled,
    callback = function(active) setToggle(masterToggle, active) end,
})
SA.FeatureBinds["hn_master_bind"] = masterBind

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
gunSec:label({ name = "Silent aim + manipulation: GUNS ONLY (bows skipped)" })

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
    "hv_rocket", "incendiary_rocket", "duel_ammo",
})
bindToggle(ballSec, "Saturday2 Damage", "saturday2Mode",
    "Uses the real s2Damage numbers from the gun table (or the SA.S2Damage hook); otherwise Defs[ammo].damage x damageMult")
bindToggle(ballSec, "Muzzle Boost Equipped", "muzzleBoost",
    "Manual fallback for muzzle_boost (+15% rate / -10% damage). Auto Attachment Tuning normally detects it for you")
ballSec:label({ name = "Speeds are the gun's `speed` field (GUNS overrides applied)" })
ballSec:label({ name = "Damage = Defs[ammo].damage x damageMult (the damage field is 0)" })
addButton(ballSec, "Print Gun Spec", function() SA.PrintGunSpec() end)
addButton(ballSec, "Print Live Ping", function()
    print(string.format("[sa] ping %.0f ms | auto %s | scale %.1f | offset %.0f ms | total %.0f ms",
        SA.GetPing(), CFG.predictionAutoPing and "ON" or "OFF",
        CFG.predictionPingScale or 1, CFG.predictionLatency or 0, SA.LeadLatencyMs()))
end)

-- CLASSIC manip sliders are back. Every bound is a real, functional
-- range: 0-300 studs, base peek 4-6 only, and the four remaining sliders
-- all feed the resolver in 05_manipulation.lua (no dead "adaptive cap").
local manipToggle = bindToggle(manipSec, "Enabled (FOV-aware)", "manipulation",
    "Best all-round: ON, Wall Check OFF, Range 75, Peek 4, Parts 3, Budget 64, Hysteresis 5, Max Delta 6, FOV ~150")
SA.FeatureKeybind(manipToggle, "Enable Manipulation", "hn_bind_manipulation",
    Enum.KeyCode.M, "manipulation")
bindSlider(manipSec, "Range (studs)", "manipDist", 0, 300, 1, "")
bindSlider(manipSec, "Base Peek Offset", "manipPeek", 4, 6, 0.5, "")
bindSlider(manipSec, "Max CanQuery Parts", "manipMaxParts", 0, 8, 1, "")
bindSlider(manipSec, "Ray Budget / Frame", "manipBudget", 8, 128, 1, "")
bindSlider(manipSec, "Cache Hysteresis (frames)", "manipHysteresis", 0, 12, 1, "")
bindSlider(manipSec, "Max Peek Delta", "manipMaxPeekDelta", 2, 12, 1, "")

manipSec:label({ name = "Recommended: 75 / 4 / 3 / 64 / 5 / 6" })
manipSec:label({ name = "Range | Peek | Parts | Budget | Hyst | Delta" })
manipSec:label({ name = "Range 0-300 studs · Base peek 4-6 only" })
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

-- ── AIMING : column 3 (Attachment auto tune) ───────────────────────
-- The moment any of the 12 attachments is detected on the equipped Tool,
-- 08_attachments.lua folds its effects into SA.GetEquippedGun(); the
-- solver in 08_prediction.lua then uses the tuned speed / aim-time lead
-- with no manual toggle. The four dropdowns are a manual fallback for
-- games that store attachments somewhere the detector can't see.
local aimCol3 = Aiming:column()
local attSec, attOvrSec = aimCol3:multi_section({
    names = { "Attachments (Auto)", "Overrides & Diagnostics" },
})
attSec:label({ name = "Auto-detects 12 attachments from the equipped tool" })
bindToggle(attSec, "Auto Attachment Tuning", "attachmentAutoTune",
    "Detects sight / muzzle / underbarrel / mag attachments and re-tunes prediction automatically")
bindToggle(attSec, "Force ADS Spread", "attachmentAds",
    "Assume aiming down sights. OFF = read right mouse button; affects the spread readout only")
bindToggle(attSec, "Aim-Time Lead Tune", "attachmentAimTune",
    "Scopes / ACOG / vertical grip add a small time-to-aim lead; reflex sight removes some")
bindSlider(attSec, "Aim-Time Scale", "attachmentAimScale", 0, 2, 0.1, "x")
bindSlider(attSec, "Silencer Speed Mult", "attachmentSilencerSpeed", 0.5, 1, 0.01, "x")
attSec:label({ name = "ESTIMATE: the script says 'slower bullets' but gives no number" })
attSec:label({ name = "Fitted mods: Sight / Muzzle / Under / Mag" })
bindDropdown(attOvrSec, "Sight Override", "attOverrideSight", {
    "Auto", "None", "red_dot_sight", "holo_sight", "scope_4x", "acog_sight", "reflex_sight",
})
bindDropdown(attOvrSec, "Muzzle Override", "attOverrideMuzzle", {
    "Auto", "None", "muzzle_brake", "silencer", "muzzle_boost",
})
bindDropdown(attOvrSec, "Under Override", "attOverrideUnder", {
    "Auto", "None", "vertical_grip", "laser_sight", "flashlight",
})
bindDropdown(attOvrSec, "Mag Override", "attOverrideMag", {
    "Auto", "None", "mag_extender",
})
addButton(attOvrSec, "Print Attachments", function() SA.PrintAttachments() end)
addButton(attOvrSec, "Rescan Attachments", function()
    local s = SA.RescanAttachments()
    print(string.format("[att] %s | %d detected | speed %.0f -> %.0f",
        tostring(s.gunId), s.count, s.baseSpeed, s.speed))
end)
addButton(attOvrSec, "Print Gun Table", function() SA.PrintGunTable() end)
addButton(attOvrSec, "Sync Gun Defs (GC)", function()
    local n = SA.SyncGunDefs()
    print("[att] live gun fields merged:", n)
end)
