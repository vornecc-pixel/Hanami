-- ==================================================================
-- Hanami / 18_hitlog.lua — Hit log GUI, hit sound, damage tracker
-- Loaded in order by loader.lua. Parts are joined into ONE chunk
-- before running, so every `local` is shared just like the original.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- HIT LOG + HIT SOUND + DAMAGE TRACKER
-- ────────────────────────────────────────────────────────────────────

local HitLogGui = Instance.new("ScreenGui")
HitLogGui.Name = "HitLogMini"
HitLogGui.ResetOnSpawn = false
HitLogGui.IgnoreGuiInset = true
HitLogGui.Parent = (gethui and gethui()) or lp:WaitForChild("PlayerGui")

local HitLogFrame = Instance.new("Frame")
HitLogFrame.Size = UDim2.fromOffset(220, 150)
HitLogFrame.Position = UDim2.fromOffset(10, 10)
HitLogFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
HitLogFrame.BackgroundTransparency = 0.3
HitLogFrame.BorderSizePixel = 0
HitLogFrame.Active = true
HitLogFrame.Parent = HitLogGui
Instance.new("UICorner", HitLogFrame).CornerRadius = UDim.new(0, 4)
local hlStroke = Instance.new("UIStroke", HitLogFrame)
hlStroke.Color = Color3.fromRGB(60, 60, 60); hlStroke.Thickness = 1

local HitLogTitle = Instance.new("TextLabel")
HitLogTitle.Size = UDim2.new(1, 0, 0, 20)
HitLogTitle.BackgroundTransparency = 1
HitLogTitle.Text = "HIT LOG (Drag me)"
HitLogTitle.Font = Enum.Font.GothamBold
HitLogTitle.TextSize = 11
HitLogTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
HitLogTitle.Parent = HitLogFrame

local HitLogContainer = Instance.new("ScrollingFrame")
HitLogContainer.Size = UDim2.new(1, -8, 1, -24)
HitLogContainer.Position = UDim2.fromOffset(4, 22)
HitLogContainer.BackgroundTransparency = 1
HitLogContainer.BorderSizePixel = 0
HitLogContainer.ScrollBarThickness = 2
HitLogContainer.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
HitLogContainer.CanvasSize = UDim2.new()
HitLogContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
HitLogContainer.Parent = HitLogFrame
local listLayout = Instance.new("UIListLayout", HitLogContainer)
listLayout.Padding = UDim.new(0, 2); listLayout.SortOrder = Enum.SortOrder.LayoutOrder

local draggingHL, dragStartHL, startPosHL = false, nil, nil
HitLogTitle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        draggingHL = true; dragStartHL = input.Position; startPosHL = HitLogFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then draggingHL = false end
        end)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if draggingHL and (input.UserInputType == Enum.UserInputType.MouseMovement
       or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - dragStartHL
        HitLogFrame.Position = UDim2.new(
            startPosHL.X.Scale, startPosHL.X.Offset + d.X,
            startPosHL.Y.Scale, startPosHL.Y.Offset + d.Y)
    end
end)

local function AddLog(text, color)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, 14)
    l.BackgroundTransparency = 1
    l.Text = text; l.Font = Enum.Font.GothamMedium; l.TextSize = 10
    l.TextColor3 = color or Color3.fromRGB(255, 255, 255)
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = HitLogContainer
    task.delay(5, function() if l and l.Parent then l:Destroy() end end)
end

local HitSoundObj = Instance.new("Sound")
HitSoundObj.SoundId = "rbxassetid://112396157430651"
HitSoundObj.Volume = 2
HitSoundObj.Parent = SoundService

local lastHealth = {}
local function trackDamage(plr)
    local char = plr.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    lastHealth[plr] = hum.Health
    hum:GetPropertyChangedSignal("Health"):Connect(function()
        local old = lastHealth[plr] or hum.Health
        local new = hum.Health
        local dmg = math.floor(old - new)
        if dmg <= 0 then lastHealth[plr] = new; return end
        local dist = 0
        if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
           and char:FindFirstChild("HumanoidRootPart") then
            dist = math.floor(
                (lp.Character.HumanoidRootPart.Position - char.HumanoidRootPart.Position).Magnitude)
        end
        if plr == lp then
            AddLog(string.format("[ME] -%d HP (%d/%d)",
                dmg, math.floor(new), math.floor(hum.MaxHealth)), Color3.fromRGB(60, 255, 100))
        else
            AddLog(string.format("%s [%dm] -%d HP (%d/%d)",
                plr.Name, dist, dmg, math.floor(new), math.floor(hum.MaxHealth)),
                Color3.fromRGB(255, 60, 60))
            if CFG.hitSoundEnabled then HitSoundObj:Play() end
        end
        lastHealth[plr] = new
    end)
end

for _, p in ipairs(Players:GetPlayers()) do
    trackDamage(p)
    p.CharacterAdded:Connect(function() task.wait(1) trackDamage(p) end)
end
Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function() task.wait(1) trackDamage(p) end)
end)

