-- ==================================================================
-- Hanami / 17_ui_visual.lua — Visual tab controls
-- Loaded in order by loader.lua. Parts are joined into ONE chunk
-- before running, so every `local` is shared just like the original.
-- ==================================================================

-- ── VISUAL : FOV ──
local FovSec = VisualTab:Section({ Text = "FOV Circle" })
FovSec:Toggle({ Text = "Show FOV Circle", Default = CFG.showFov,
    Callback = function(v) CFG.showFov = v end })
FovSec:Toggle({ Text = "Filled", Default = CFG.fovFilled,
    Callback = function(v) CFG.fovFilled = v end })
FovSec:Slider({ Text = "Radius (px)",
    Default = CFG.fov, Minimum = 30, Maximum = 500,
    Callback = function(v) CFG.fov = v end })
FovSec:Slider({ Text = "Transparency (%)",
    Default = CFG.fovTransparency, Minimum = 0, Maximum = 100,
    Callback = function(v) CFG.fovTransparency = v end })
FovSec:Slider({ Text = "Thickness",
    Default = CFG.fovThickness, Minimum = 1, Maximum = 5,
    Callback = function(v) CFG.fovThickness = v end })

-- ── VISUAL : Debug ──
local DbgSec = VisualTab:Section({ Text = "Debug", Side = "Right" })
DbgSec:Toggle({ Text = "Debug Log", Default = CFG.debug,
    Callback = function(v) CFG.debug = v end })
DbgSec:Button({ Text = "Print Sandwich",
    Callback = function()
        local prio = Enum.RenderPriority.Camera.Value
        print(string.format("[sa] snap @ %d | gun @ %d | restore @ %d",
            prio + 2, prio + 3, prio + 4))
    end })
DbgSec:Button({ Text = "Print Equipped Gun",
    Callback = function()
        local id = getEquippedGunId()
        print("[sa] equipped:", id or "nothing")
    end })
DbgSec:Button({ Text = "Print Manip State",
    Callback = function()
        local n = 0; for _ in pairs(saManipCache) do n = n + 1 end
        print(string.format("[manip] frame=%d budget=%d disabled=%d cached=%d",
            saManipFrame, saManipBudget, #saManipDisabled, n))
    end })

