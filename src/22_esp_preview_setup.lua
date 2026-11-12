-- ==================================================================
-- Hanami / 22_esp_preview_setup.lua — ESP Preview build + lifecycle
-- Loaded in order by loader.lua. Parts are joined into ONE chunk;
-- the loader hoists column-1 `local`s to beat Luau's 200-local cap.
-- ==================================================================

-- Continues 22_esp_preview.lua: pv, pvTeardown, the overlay/style helpers
-- and the safe model builders are defined there. This part wires them to
-- Atlanta's window.esp_section once, then exposes the SA.* controls.
-- ==================================================================

local function pvPlaceOne(isNpc, x, ui, tag)
    local model, why, isDummy = pvMakeModel(isNpc)
    if model then
        pvRecenter(model, x)
        local ok = pcall(function() model.Parent = pv.root end)
        if not ok then model = nil end
    end
    if not model then
        local okDummy, dummy = pcall(pvDummyRig)
        if okDummy and dummy then
            pvRecenter(dummy, x)
            pcall(function() dummy.Parent = pv.root end)
            model = dummy
            isDummy = true
            why = "fallback dummy rig"
        end
    end
    if ui then ui.parts = model and pvCollectParts(model) or {} end
    pv[tag] = model
    pv[tag .. "Reason"] = why
    pv[tag .. "Dummy"] = isDummy == true
    local parts = model and pvCollectParts(model) or {}
    for _, e in ipairs(parts) do pv.parts[#pv.parts + 1] = e end
    return model, why
end

local function pvBuildModel()
    if not pv.root then return end
    if pv.model then pcall(function() pv.model:Destroy() end) end
    if pv.model2 then pcall(function() pv.model2:Destroy() end) end
    pv.model, pv.model2, pv.parts = nil, nil, {}
    local compare = CFG.espPreviewCompare == true
    local primaryNpc = CFG.espPreviewKind == "NPC"
    local x1, x2 = compare and -2.4 or 0, compare and 2.4 or 0
    local m1, w1 = pvPlaceOne(primaryNpc, x1, pv.ui, "model")
    pv.reason, pv.isDummy = w1, pv.modelDummy
    if compare then
        pvPlaceOne(not primaryNpc, x2, pv.ui2, "model2")
    end
    pv.lastSource = CFG.espPreviewSource
    pv.lastCompare = compare
    pv.lastKind = CFG.espPreviewKind
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

    -- Rebuild when the user switches sources, the compared kind or the
    -- side-by-side toggle. Models are cloned once, not every frame.
    local compare = CFG.espPreviewCompare == true
    if pv.lastSource ~= CFG.espPreviewSource
        or pv.lastCompare ~= compare
        or pv.lastKind ~= CFG.espPreviewKind then
        pcall(pvBuildModel)
    end
    if CFG.espPreviewSpin and pv.camera then
        pv.angle = ((pv.angle or 0)
            + math.max(tonumber(CFG.espPreviewSpeed) or 25, 0) * (dt or 0.016)) % 360
        local a = math.rad(pv.angle)
        local dist = compare and 11 or 7.5
        pcall(function()
            pv.camera.CFrame = CFrame.lookAt(
                Vector3.new(math.sin(a) * dist, 1.2, math.cos(a) * dist),
                Vector3.new(0, -0.5, 0))
        end)
    end
    local now = tick()
    if now - (pv.lastStyle or 0) > 0.1 then
        pv.lastStyle = now
        local okStyle, styleErr = pcall(pvApplyStyle)
        -- `okStyle and nil or ...` is ALWAYS the right-hand side in Lua:
        -- `true and nil` is nil, so the `or` branch still runs. Use an
        -- explicit if/else so a successful style pass clears the error.
        if okStyle then
            pv.styleErr = nil
        else
            pv.styleErr = tostring(styleErr)
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
if pvSec and pvSec.holder then
    local ok = pcall(function()
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

        pv.ui = pvBuildOverlays(viewport, 0.28, 104, "PlayerSide")
        pv.ui2 = pvBuildOverlays(viewport, 0.72, 104, "NpcSide")
        pv.ui.holder.Position = UDim2new(0.5, 0, 0.5, 0)
        pv.ui2.holder.Visible = false
        pvBuildModel()
        -- bindRender does not guard its callback; one stray Instance
        -- error must never break RenderStepped or the other loops.
        pv.renderConn = bindRender(function(...)
            pcall(pvTick, ...)
        end)
    end)

    -- Rebuild the model after every respawn (the old Atlanta preview
    -- died here because it assumed a live character + Animate script).
    pcall(function()
        _G.__saEspPreviewCharConn = SA.Connect(lp.CharacterAdded, function()
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
    pcall(bindDropdown, pvSec, "Model Source", "espPreviewSource", {
        "Local Character", "Nearest Player", "Nearest NPC", "Aim Target",
    })
    pcall(bindToggle, pvSec, "Side-by-Side Player vs NPC", "espPreviewCompare",
        "Clone a second real server model and show Player ESP next to NPC ESP with the same live settings")
    pcall(bindToggle, pvSec, "Simulate Aim Target", "espPreviewTarget",
        "Paints box / fill / outline with the Target colour, like Highlight Aim Target")
    pcall(bindToggle, pvSec, "Rotate Model", "espPreviewSpin")
    pcall(bindSlider, pvSec, "Spin Speed", "espPreviewSpeed", 0, 90, 5, "deg/s")
    pcall(addButton, pvSec, "Apply Best ESP", function()
        if SA.ApplyBestEsp then SA.ApplyBestEsp() end
    end)
    pcall(addButton, pvSec, "Rebuild Character", function() SA.EspPreviewRefresh() end)
end
