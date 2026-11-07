-- ==================================================================
-- Hanami / 04_firing_and_guns.lua — Firing state, gun speed/id lookups, cooldown
-- Loaded in order by loader.lua. Parts are joined into ONE chunk
-- before running, so every `local` is shared just like the original.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- FIRING STATE
-- ────────────────────────────────────────────────────────────────────

local firing = _G.__saFiringState or { held = false, last = 0 }
_G.__saFiringState = firing
if not _G.__saInputBound then
    _G.__saInputBound = true
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            firing.held = true; firing.last = tick()
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            firing.held = false
        end
    end)
end

local function isFiring()
    if not CFG.gunShotOnly then return true end
    if firing.held then return true end
    return (tick() - firing.last) < 0.2
end

-- ────────────────────────────────────────────────────────────────────
-- GUN HELPERS
-- ────────────────────────────────────────────────────────────────────

local function getGunSpeed()
    if CFG.gunBulletSpeed > 0 then return CFG.gunBulletSpeed end
    local char = lp.Character
    if not char then return GUN_DEFAULT_SPEED end
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") then
            local id = child:GetAttribute("ItemId")
            if id and GUN_SPEEDS[id] then return GUN_SPEEDS[id] end
        end
    end
    return GUN_DEFAULT_SPEED
end

local function getEquippedGunId()
    local char = lp.Character
    if not char then return nil end
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") then
            local id = child:GetAttribute("ItemId")
            if id and GUN_SPEEDS[id] then return id end
        end
    end
    return nil
end

local gunCooldownAt = {}
local function gunCanSnap()
    if CFG.gunCooldown <= 0 then return true end
    local id = getEquippedGunId()
    if not id then return true end
    local now = tick()
    if (gunCooldownAt[id] or 0) + CFG.gunCooldown > now then return false end
    gunCooldownAt[id] = now
    return true
end

