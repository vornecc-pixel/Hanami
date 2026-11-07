-- ==================================================================
-- Hanami / 17_ui_visual.lua — Visual tab (FOV + debug)
-- Loaded in order by loader.lua. Parts are joined into ONE chunk
-- before running, so every `local` is shared just like the original.
-- ==================================================================

-- ── VISUAL : FOV ───────────────────────────────────────────────────
local fovCol = VisualTab:column()
local fovSec = fovCol:section({ name = "FOV Circle" })

bindToggle(fovSec, "Show FOV Circle", "showFov")
    :colorpicker({
        name = "FOV Color", flag = "hn_fov_color", color = fovColor,
        callback = function(c) fovColor = c end,
    })
bindToggle(fovSec, "Filled", "fovFilled")
-- CFG.fov is used by both the target picker and the drawn circle
bindSlider(fovSec, "Aim / Circle Radius (px)", "fov", 30, 500, 1, "px")
bindSlider(fovSec, "Transparency (%)", "fovTransparency", 0, 100, 1, "%")
bindSlider(fovSec, "Thickness", "fovThickness", 1, 5, 1, "")

-- ── VISUAL : Debug ─────────────────────────────────────────────────
local dbgCol = VisualTab:column()
local dbgSec = dbgCol:section({ name = "Debug" })

bindToggle(dbgSec, "Debug Log", "debug")
addButton(dbgSec, "Print Sandwich", function()
    local prio = Enum.RenderPriority.Camera.Value
    print(string.format("[sa] snap @ %d | gun @ %d | restore @ %d",
        prio + 2, prio + 3, prio + 4))
    print(string.format("[sa] actual binds: %s @ %d / %s @ %d",
        snapName, snapPrio, restoreName, restorePrio))
end)
addButton(dbgSec, "Print Equipped Gun", function()
    local id = getEquippedGunId()
    print("[sa] equipped:", id or "nothing")
end)
addButton(dbgSec, "Print Manip State", function()
    local n = 0; for _ in pairs(saManipCache) do n = n + 1 end
    print(string.format("[manip] frame=%d budget=%d disabled=%d cached=%d",
        saManipFrame, saManipBudget, #saManipDisabled, n))
end)
