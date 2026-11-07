-- ==================================================================
-- Hanami / 06_firing_and_guns.lua — Firing state + snap cooldown
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
-- Gun id/spec resolution lives in 07_gun_specs.lua (SA.GetEquippedGun).
-- The old getGunSpeed() + hardcoded GUN_SPEEDS lookup was removed.
-- ────────────────────────────────────────────────────────────────────

local gunCooldownAt = {}
local function gunCanSnap()
    if CFG.gunCooldown <= 0 then return true end
    local id = SA.GetEquippedGun().id
    if not id then return true end
    local now = tick()
    if (gunCooldownAt[id] or 0) + CFG.gunCooldown > now then return false end
    gunCooldownAt[id] = now
    return true
end

