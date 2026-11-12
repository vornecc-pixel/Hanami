-- ==================================================================
-- Hanami / 26_armor_console_cards.lua
-- Widget factories for the ARMOR CONSOLE: the 3D item icon (a real mesh
-- clone in a ViewportFrame), one armour card, and the player header.
-- Split out of 26_armor_console_ui.lua purely to stay under Luau's
-- 200-register ceiling -- the behaviour is unchanged.
--
-- Everything here is exposed on SA.ArmorConsole* so the panel part can
-- use it without a shared file-local upvalue.
-- ==================================================================

-- Layout constants shared with the panel. The panel reads these back, so
-- the two parts cannot drift apart.
SA.ARMOR_CARD_H     = 74
SA.ARMOR_ICON_W     = 66
SA.ARMOR_GROUP_H    = 40
SA.ARMOR_PAD        = 8
SA.ARMOR_FONT_MAIN  = 14
SA.ARMOR_FONT_SUB   = 11
SA.ARMOR_FONT_VALUE = 15
SA.ARMOR_HEADER_H   = 26

-- Icon clones are keyed by item id so a re-render of the same piece does
-- not rebuild the ViewportFrame contents.
SA.ArmorIconCache = SA.ArmorIconCache or {}

-- ── 3D ICON ─────────────────────────────────────────────────────────
-- Clones the real FustWear mesh into a ViewportFrame. Never throws: if
-- anything about the mesh is unusable the chip falls back to the short
-- code over a hashed colour, so a row is never blank.


function SA.ArmorConsoleBuildIcon(card, source, itemId)
    local vf = card.viewport
    if not vf then return false end
    -- Same item already rendered on this row: nothing to do.
    if card.iconId == itemId and card.iconOk then return true end
    card.iconId = itemId
    card.iconOk = false
    pcall(function()
        for _, child in ipairs(vf:GetChildren()) do
            if child.ClassName ~= "Camera" then child:Destroy() end
        end
    end)

    local clone = nil
    pcall(function()
        if source and typeof(source.Clone) == "function" then
            local model = source:Clone()
            -- Aggressive presentation cleanup: the icon is a thumbnail,
            -- so a default grey material reads better than raw textures,
            -- and nothing should be able to block or fall out of frame.
            pcall(function() model.Anchored = true end)
            pcall(function() model.CanCollide = false end)
            pcall(function() model.CanQuery = false end)
            pcall(function() model.Massless = true end)
            pcall(function() model.Material = Enum.Material.SmoothPlastic end)
            pcall(function() model.Transparency = 0 end)
            local size = model.Size
            -- Normalise every item to a similar on-screen size, or a
            -- helmet would fill the tile and a boot would be a speck.
            local longest = math.max(size.X, size.Y, size.Z)
            if longest > 0.0001 then
                local k = 2.6 / longest
                pcall(function()
                    model.Size = Vector3.new(size.X * k, size.Y * k,
                                             size.Z * k)
                end)
            end
            pcall(function()
                model.CFrame = CFrame.new(Vector3.new(0, 0, 0))
                    * CFrame.Angles(0, math.rad(-24), 0)
            end)
            clone = model
        end
    end)

    local ok = pcall(function()
        local cam = vf:FindFirstChildOfClass("Camera")
        if not cam then
            cam = Instance.new("Camera")
            cam.Name = "IconCamera"
            cam.Parent = vf
        end
        -- Three-quarter view: the same angle the reference icons show.
        pcall(function()
            cam.CFrame = CFrame.new(Vector3.new(2.4, 1.5, 3.4))
                * CFrame.Angles(math.rad(-12), math.rad(34), 0)
            cam.FieldOfView = 40
        end)
        vf.CurrentCamera = cam
        if clone then
            clone.Parent = vf
            card.iconOk = true
        end
    end)
    if not ok or not card.iconOk then
        -- Fallback: hide the empty viewport, show the code chip.
        pcall(function() vf.Visible = false end)
        pcall(function() card.chip.Visible = true end)
        return false
    end
    pcall(function() vf.Visible = true end)
    pcall(function() card.chip.Visible = false end)
    return true
end

-- ── CARD ────────────────────────────────────────────────────────────
-- One armour piece: [3D icon] name / slot / +X%
function SA.ArmorConsoleMakeCard(parent)
    local ok, card = pcall(function()
        local root = Instance.new("Frame")
        root.Name = "ArmorCard"
        root.BackgroundColor3 = Color3.fromRGB(26, 28, 38)
        root.BackgroundTransparency = 0.08
        root.BorderSizePixel = 0
        root.Visible = false
        root.Parent = parent
        pcall(function()
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 6)
            corner.Parent = root
        end)
        pcall(function()
            local stroke = Instance.new("UIStroke")
            stroke.Color = Color3.fromRGB(58, 64, 84)
            stroke.Thickness = 1
            stroke.Transparency = 0.45
            stroke.Parent = root
        end)

        -- Icon column: a real 3D thumbnail of the item.
        local viewport = Instance.new("ViewportFrame")
        viewport.Name = "Icon"
        viewport.BackgroundTransparency = 1
        viewport.BorderSizePixel = 0
        viewport.Parent = root
        pcall(function() viewport.Ambient = Color3.fromRGB(180, 180, 180) end)
        pcall(function() viewport.LightColor = Color3.fromRGB(255, 246, 235) end)
        pcall(function() viewport.LightDirection = Vector3.new(-0.4, -1, -0.6) end)

        -- Text fallback that sits on top of the icon tile.
        local chip = Instance.new("TextLabel")
        chip.Name = "Chip"
        chip.BackgroundColor3 = Color3.fromRGB(52, 58, 76)
        chip.BackgroundTransparency = 0.05
        chip.BorderSizePixel = 0
        chip.Text = "?"
        chip.TextColor3 = Color3.fromRGB(240, 244, 255)
        chip.TextXAlignment = Enum.TextXAlignment.Center
        chip.TextYAlignment = Enum.TextYAlignment.Center
        chip.TextSize = 12
        chip.Visible = false
        chip.Parent = root
        pcall(function()
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 6)
            corner.Parent = chip
        end)
        pcall(function() SA.ApplyEspFont(chip) end)

        local name = Instance.new("TextLabel")
        name.Name = "ItemName"
        name.BackgroundTransparency = 1
        name.Text = ""
        name.TextColor3 = Color3.fromRGB(240, 244, 255)
        name.TextXAlignment = Enum.TextXAlignment.Left
        name.TextYAlignment = Enum.TextYAlignment.Center
        name.TextSize = FONT_MAIN
        name.Parent = root
        pcall(function() name.TextTruncate = Enum.TextTruncate.AtEnd end)
        pcall(function() SA.ApplyEspFont(name) end)

        local slot = Instance.new("TextLabel")
        slot.Name = "Slot"
        slot.BackgroundTransparency = 1
        slot.Text = ""
        slot.TextColor3 = Color3.fromRGB(150, 162, 186)
        slot.TextXAlignment = Enum.TextXAlignment.Left
        slot.TextYAlignment = Enum.TextYAlignment.Center
        slot.TextSize = FONT_SUB
        slot.Parent = root
        pcall(function() SA.ApplyEspFont(slot) end)

        local value = Instance.new("TextLabel")
        value.Name = "Protection"
        value.BackgroundTransparency = 1
        value.Text = ""
        -- The reference layout uses green for protection.
        value.TextColor3 = Color3.fromRGB(110, 226, 130)
        value.TextXAlignment = Enum.TextXAlignment.Left
        value.TextYAlignment = Enum.TextYAlignment.Center
        value.TextSize = FONT_VALUE
        value.Parent = root
        pcall(function() SA.ApplyEspFont(value) end)

        return { root = root, viewport = viewport, chip = chip,
                 name = name, slot = slot, value = value }
    end)
    if not ok then return nil end
    return card
end

-- ── PLAYER GROUP HEADER ─────────────────────────────────────────────
function SA.ArmorConsoleMakeGroup(parent)
    local ok, group = pcall(function()
        local root = Instance.new("Frame")
        root.Name = "PlayerGroup"
        root.BackgroundColor3 = Color3.fromRGB(32, 35, 48)
        root.BackgroundTransparency = 0.05
        root.BorderSizePixel = 0
        root.Visible = false
        root.Parent = parent
        pcall(function()
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 5)
            corner.Parent = root
        end)

        local name = Instance.new("TextLabel")
        name.Name = "PlayerName"
        name.BackgroundTransparency = 1
        name.Text = ""
        name.TextColor3 = Color3.fromRGB(245, 248, 255)
        name.TextXAlignment = Enum.TextXAlignment.Left
        name.TextYAlignment = Enum.TextYAlignment.Center
        name.TextSize = FONT_MAIN
        name.Parent = root
        pcall(function() SA.ApplyEspFont(name) end)

        local totals = Instance.new("TextLabel")
        totals.Name = "Totals"
        totals.BackgroundTransparency = 1
        totals.Text = ""
        totals.TextColor3 = Color3.fromRGB(168, 196, 240)
        totals.TextXAlignment = Enum.TextXAlignment.Left
        totals.TextYAlignment = Enum.TextYAlignment.Center
        totals.TextSize = FONT_SUB
        totals.Parent = root
        pcall(function() SA.ApplyEspFont(totals) end)

        local empty = Instance.new("TextLabel")
        empty.Name = "NoItems"
        empty.BackgroundTransparency = 1
        empty.Text = "no items"
        empty.TextColor3 = Color3.fromRGB(120, 130, 150)
        empty.TextXAlignment = Enum.TextXAlignment.Left
        empty.TextYAlignment = Enum.TextYAlignment.Center
        empty.TextSize = FONT_SUB
        empty.Visible = false
        empty.Parent = root
        pcall(function() SA.ApplyEspFont(empty) end)

        return { root = root, name = name, totals = totals, empty = empty }
    end)
    if not ok then return nil end
    return group
end

