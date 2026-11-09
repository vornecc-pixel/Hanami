-- ==================================================================
-- Hanami / 22_esp_preview_setup.lua — ESP Preview build + lifecycle
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================

-- Continues 22_esp_preview.lua: pv, pvTeardown, the overlay/style helpers
-- and the safe model builders are defined there. This part wires them to
-- Atlanta's window.esp_section once, then exposes the SA.* controls.
-- ==================================================================

local function pvBuildModel()
    if not pv.root then return end
    if pv.model then pcall(function() pv.model:Destroy() end) end
    pv.model = nil
    local model, why, isDummy = pvMakeModel()
    pv.reason = why
    pv.isDummy = isDummy == true
    if model then
        pvRecenter(model)
        local ok = pcall(function() model.Parent = pv.root end)
        if not ok then model = nil end
    end
    if not model then
        local okDummy, dummy = pcall(pvDummyRig)
        if okDummy and dummy then
            pcall(function() dummy.Parent = pv.root end)
            model = dummy
            pv.isDummy = true
            pv.reason = "fallback dummy rig"
        else
            pv.reason = "no 3D model available"
        end
    end
    pv.model = model
    pv.parts = pvCollectParts(model)
    pcall(pvApplyStyle)
end

local function pvTick(dt)
    if CFG.espPreview ~= pv.enabled then
        pv.enabled = CFG.espPreview == true
        -- Only hide the 3D view: keep the panel (and its Enabled toggle)
        -- on screen so the user can switch it back on. The panel's own
        -- "X" button is what actually closes the window.
        pcall(function() if pv.root then pv.root.Visible = pv.enabled end end)
    end
    if not pv.enabled or not SA.Alive then return end
    if not pv.root or not pv.root.Parent then return end
    if not pv.root.Visible then return end
    -- Atlanta's "Unload Menu" destroys every ScreenGui; stop working if
    -- the floating panel is gone or the menu has hidden it.
    if pv.sgui and (not pv.sgui.Enabled or not pv.sgui.Parent) then return end

    if CFG.espPreviewSpin and pv.camera then
        pv.angle = ((pv.angle or 0)
            + math.max(tonumber(CFG.espPreviewSpeed) or 25, 0) * (dt or 0.016)) % 360
        local a = math.rad(pv.angle)
        pcall(function()
            pv.camera.CFrame = CFrame.lookAt(
                Vector3.new(math.sin(a) * 7.5, 1.2, math.cos(a) * 7.5),
                Vector3.new(0, -0.5, 0))
        end)
    end
    local now = tick()
    if now - (pv.lastStyle or 0) > 0.1 then
        pv.lastStyle = now
        local okStyle, styleErr = pcall(pvApplyStyle)
        pv.styleErr = okStyle and nil or tostring(styleErr)
        if not okStyle and not pv.styleWarned then
            pv.styleWarned = true
            warn("[esp] preview styling: " .. tostring(styleErr))
        end
    end
end

function SA.EspPreviewSet(on)
    on = on == true
    if type(setFlag) == "function" then pcall(setFlag, "espPreview", on) end
    CFG.espPreview = on
    pv.enabled = on
    pcall(function() if pv.root then pv.root.Visible = on end end)
    -- Re-open the floating panel if its "X" button had closed it.
    if on then pcall(function() if pv.sgui then pv.sgui.Enabled = true end end) end
end

function SA.EspPreviewRefresh()
    pvBuildModel()
end

function SA.EspPreviewDispose()
    pvTeardown()
    CFG.espPreview = false
    pv.enabled = false
    pcall(function() if pv.sgui then pv.sgui.Enabled = false end end)
end

function SA.EspPreviewDiag()
    print("════════════ ESP PREVIEW ════════════")
    print("  enabled :", tostring(CFG.espPreview), "| spin:", tostring(CFG.espPreviewSpin),
        "| speed:", tostring(CFG.espPreviewSpeed))
    print("  kind    :", tostring(CFG.espPreviewKind), "ESP | aim target:",
        tostring(CFG.espPreviewTarget), "| overlays:", pv.ui and "BUILT" or "MISSING")
    print("  model   :", pv.isDummy and "synthetic dummy rig"
        or (pv.model and "local character clone" or "NONE"))
    print("  parts   :", pv.parts and #pv.parts or 0, "| reason:", tostring(pv.reason or "-"))
    print("  panel   :", pv.sgui and (pv.sgui.Enabled and "visible" or "hidden") or "MISSING",
        "| own:", tostring(pv.ownGui ~= nil))
    print("  viewport:", pv.root and (pv.root.Visible and "visible" or "hidden") or "MISSING")
    print("  style   :", tostring(pv.styleErr or "ok"),
        "| embedded:", tostring(pv.embedded == true))
    print("  features: box", tostring(CFG.espShowBox),
        "| corners", tostring(CFG.espCornerBox),
        "| skeleton", tostring(CFG.espShowSkeleton),
        "| head", tostring(CFG.espShowHeadDot),
        "| tracer", tostring(CFG.espShowTracer),
        "| arrows", tostring(CFG.espShowOffscreen),
        "| fade", tostring(CFG.espFade))
    print("══════════════════════════════════════")
end

-- ── Build once ───────────────────────────────────────────────────────
local pvSec = window and window.esp_section or nil
if pvSec and pvSec.holder then
    pv.embedded = false
else
    -- A future Atlanta revision may stop exposing the floating panel.
    -- Keep the ESP-tab section for the controls AND give it a real
    -- holder: a small standalone ScreenGui owned by Hanami. Previously
    -- this path only warned and skipped the build, so the preview was
    -- completely unavailable on those library builds.
    pv.embedded = true
    pcall(function()
        local col = EspTab:column()
        pvSec = col:section({ name = "ESP Preview" })
    end)
    pcall(function()
        local parent = nil
        pcall(function() parent = lp and lp:FindFirstChildOfClass("PlayerGui") end)
        if not parent then
            pcall(function() parent = game:GetService("CoreGui") end)
        end
        if not parent then return end
        local sg = Instance.new("ScreenGui")
        sg.Name = "HanamiEspPreviewPanel"
        sg.ResetOnSpawn = false
        sg.IgnoreGuiInset = true
        sg.DisplayOrder = 998
        local panel = Instance.new("Frame")
        panel.Name = "Panel"
        panel.Size = UDim2new(0, 300, 0, 325)
        panel.Position = UDim2new(0.72, 0, 0.1, 0)
        panel.BackgroundColor3 = c3(24, 24, 34)
        panel.BackgroundTransparency = 0.05
        panel.Parent = sg
        pcall(function()
            local layout = Instance.new("UIListLayout")
            layout.SortOrder = Enum.SortOrder.LayoutOrder
            layout.Parent = panel
        end)
        sg.Parent = parent
        pv.ownGui = sg
        if pvSec then pvSec.holder = panel end
        pv.embedded = false
    end)
end
if not pvSec or not pvSec.holder then
    warn("[esp] no ESP Preview holder available — preview unavailable")
else
    local ok, buildErr = pcall(function()
        local holder = pvSec.holder
        pv.sgui = nil

        -- The library places this panel BELOW the main window, which puts
        -- it off-screen on anything shorter than ~1080 px. Clamp it into
        -- the viewport so the preview is actually reachable.
        if not pv.embedded then
            pv.sgui = holder:FindFirstAncestorOfClass("ScreenGui")
        end
        if pv.sgui then
            local panel = pv.sgui:FindFirstChildOfClass("Frame")
            if panel then
                pcall(function()
                    local vp = SA.ViewportSize()
                    local w = panel.Size.X.Offset > 0 and panel.Size.X.Offset or 300
                    local h = panel.Size.Y.Offset > 0 and panel.Size.Y.Offset or 325
                    local origX, origY = panel.Position.X.Offset, panel.Position.Y.Offset
                    local maxX = math.max(4, vp.X - w - 4)
                    local maxY = math.max(4, vp.Y - h - 4)
                    local x = math.clamp(origX, 4, maxX)
                    local y = math.clamp(origY, 4, maxY)
                    -- The template docks this panel BELOW the main window,
                    -- which is off-screen under ~1080 px tall. When that
                    -- happens, dock it top-right instead of dumping it on
                    -- top of the main menu.
                    if origY > maxY then
                        x = math.max(4, vp.X - w - 8)
                        y = 8
                    end
                    panel.Position = UDim2new(0, x, 0, y)
                end)
            end
            pcall(function() pv.sgui.Enabled = true end)
        end

        pv.enabled = CFG.espPreview == true
        pv.angle = 25

        local viewport = Instance.new("ViewportFrame")
        viewport.Name = "HanamiEspPreview"
        viewport.LayoutOrder = -10            -- keep it above the controls
        viewport.BackgroundTransparency = 0.4
        viewport.BackgroundColor3 = c3(24, 24, 34)
        viewport.BorderSizePixel = 0
        viewport.Size = UDim2new(1, -8, 0, 210)
        viewport.Visible = pv.enabled
        viewport.Parent = holder
        pv.root = viewport
        pcall(function()
            viewport.Ambient = c3(170, 170, 180)
            viewport.LightColor = c3(255, 255, 255)
            viewport.LightDirection = Vector3.new(-1, -1, -1)
        end)

        local cam = Instance.new("Camera")
        cam.Name = "HanamiPreviewCamera"
        cam.CameraType = Enum.CameraType.Scriptable
        cam.FieldOfView = 50
        cam.CFrame = CFrame.lookAt(Vector3.new(3.2, 1.2, 6.8), Vector3.new(0, -0.5, 0))
        cam.Parent = viewport
        pv.camera = cam
        viewport.CurrentCamera = cam

        pv.ui = pvBuildOverlays(viewport)
        pvBuildModel()
        -- bindRender does not guard its callback; one stray Instance
        -- error must never spam RenderStepped or break the other loops.
        pv.renderConn = bindRender(function(...)
            pcall(pvTick, ...)
        end)
    end)
    if not ok then warn("[esp] ESP preview build failed: " .. tostring(buildErr)) end

    -- Rebuild the model after every respawn (the old Atlanta preview
    -- died here because it assumed a live character + Animate script).
    pcall(function()
        _G.__saEspPreviewCharConn = lp.CharacterAdded:Connect(function()
            task.spawn(function()
                task.wait(0.6)
                if SA.Alive and CFG.espPreview then SA.EspPreviewRefresh() end
            end)
        end)
    end)

    -- Controls live in the preview panel itself, next to the render. Each
    -- is its own pcall so one unsupported widget cannot hide the rest.
    pcall(function() pvSec:label({ name = "Live preview of YOUR ESP settings" }) end)
    pcall(bindToggle, pvSec, "Enabled", "espPreview",
        "Show / hide the 3D ESP Preview render")
    pcall(bindDropdown, pvSec, "Preview Kind", "espPreviewKind", { "Player", "NPC" })
    pcall(bindToggle, pvSec, "Simulate Aim Target", "espPreviewTarget",
        "Paints box / fill / outline with the Target colour, like Highlight Aim Target")
    pcall(bindToggle, pvSec, "Rotate Model", "espPreviewSpin")
    pcall(bindSlider, pvSec, "Spin Speed", "espPreviewSpeed", 0, 90, 5, "deg/s")
    pcall(addButton, pvSec, "Apply Best ESP", function()
        if SA.ApplyBestEsp then SA.ApplyBestEsp() end
    end)
    pcall(addButton, pvSec, "Rebuild Character", function() SA.EspPreviewRefresh() end)
    pcall(addButton, pvSec, "Print Preview State", function() SA.EspPreviewDiag() end)
end
