-- ==================================================================
-- Hanami / 06_firing_and_guns.lua — Firing state (v7.7) + snap cooldown
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- FIRING STATE
-- PATCH v7.7: release also stamps `last`, so a quick tap is still inside
-- the widened 0.35 s window after MouseButton1 goes up. The old build
-- only stamped `last` on press, which made the tap window useless for
-- the very fast click that tap-fire reorder is designed to catch.
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
            firing.held = false; firing.last = tick()
        end
    end)
end

-- GUNS ONLY: no bow draw/hold state. Silent aim bails out entirely while
-- a bow is equipped (see SA.IsEquippedBow() in 07_gun_specs.lua), so the
-- tap window only has to describe mouse presses/releases.
local function isFiring()
    if not CFG.gunShotOnly then return true end
    if firing.held then return true end
    return (tick() - firing.last) < (CFG.saTapWindow or 0.35)
end

-- ────────────────────────────────────────────────────────────────────
-- GUN HELPERS
-- Exact id/spec resolution lives in 07_gun_specs.lua (SA.GetEquippedGun).
-- The old getGunSpeed() + hardcoded GUN_SPEEDS lookup is gone.
-- ────────────────────────────────────────────────────────────────────

local gunCooldownAt = {}
local function gunCanSnap()
    if (CFG.gunCooldown or 0) <= 0 then return true end
    local ok, id = pcall(function() return SA.GetEquippedGun().id end)
    if not ok or not id then return true end
    local now = tick()
    if (gunCooldownAt[id] or 0) + CFG.gunCooldown > now then return false end
    gunCooldownAt[id] = now
    return true
end
