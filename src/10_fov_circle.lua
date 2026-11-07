-- ==================================================================
-- Hanami / 10_fov_circle.lua — FOV circle drawing
-- Loaded in order by loader.lua. Parts are joined into ONE chunk
-- before running, so every `local` is shared just like the original.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- FOV CIRCLE
-- ────────────────────────────────────────────────────────────────────

-- fovColor is declared in 01_config.lua and shared with the Visual tab colourpicker
local fovCircle = nil
do
    local ok, c = pcall(function() return Drawing.new("Circle") end)
    if ok and c then
        c.Thickness = 1; c.Filled = false
        c.Color = fovColor; c.Visible = false
        fovCircle = c
    end
end
if fovCircle then
    RunService.RenderStepped:Connect(function()
        if CFG.masterEnabled and CFG.showFov and CFG.fov > 0 then
            fovCircle.Radius       = CFG.fov
            fovCircle.Position     = UserInputService:GetMouseLocation()
            fovCircle.Filled       = CFG.fovFilled
            fovCircle.Thickness    = CFG.fovThickness
            fovCircle.Transparency = 1 - math.clamp(CFG.fovTransparency / 100, 0, 1)
            fovCircle.Color        = CFG.manipulation
                and Color3.fromRGB(255, 160, 40) or fovColor
            fovCircle.Visible = true
        else
            fovCircle.Visible = false
        end
    end)
end

