-- ==================================================================
-- Hanami / 18_esp_fx_frame.lua — Per-frame ESP styling entry point
-- Loaded in order by loader.lua. Parts are joined into ONE chunk
-- before running, so every `local` is shared just like the original.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- Frame entry point (called by 19_render_loop.lua after all refreshes)
-- ────────────────────────────────────────────────────────────────────
function SA.ApplyEspFx(cam)
    if not cam then return end
    local origin = tracerOrigin(cam)
    local myRoot = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
    local myPos = myRoot and myRoot.Position or cam.CFrame.Position
    local targetModel = SA.Target and SA.Target.model or nil
    local seed = 0
    -- shared with the FOV circle (10_fov_circle.lua) so off-screen arrows
    -- ride the exact same radius/centre the user sees
    local fovC = SA.FovCenter and SA.FovCenter()
        or Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
    local fovR = math.clamp(CFG.fov or 150, 20,
        math.min(cam.ViewportSize.X, cam.ViewportSize.Y) / 2)

    if CFG.espEnabled then
        for plr, o in pairs(espObjects) do
            seed = seed + 0.137
            local char = plr.Character
            local hum  = char and char:FindFirstChildOfClass("Humanoid")
            local hrp  = char and char:FindFirstChild("HumanoidRootPart")
            local head = char and char:FindFirstChild("Head")
            if not (char and hum and hrp and head) then hideFx(o)
            else
                local dist = (myPos - hrp.Position).Magnitude
                local vis = CFG.espVisibleCheck and SA.IsVisible(char, hrp.Position)
                local base = CFG.espVisibleCheck
                    and (vis and espC("playerVisible") or espC("playerHidden"))
                    or espC("playerFlat")
                local dot = CFG.espVisibleCheck
                    and (vis and espC("playerVisible") or espC("playerHidden"))
                    or espC("playerVisDot")
                local raw, ok = cam:WorldToViewportPoint(hrp.Position)
                local hv = cam:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
                local lv = cam:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
                local h, w = math.abs(hv.Y - lv.Y), 0
                w = h / 2
                drawEntity(cam, o, {
                    enabled = dist <= CFG.espMaxDist, pal = "player",
                    base = base, visColor = dot, seed = seed,
                    checkVisible = CFG.espVisibleCheck,
                    dist = dist, maxDist = CFG.espMaxDist, model = char,
                    target = (targetModel == char), origin = origin, opened = false,
                    fovCenter = fovC, fovRadius = fovR,
                    ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1),
                    geom = { x = raw.X - w / 2, y = hv.Y, w = w, h = h,
                             raw = raw, ok = ok, onScreen = ok and raw.Z > 0 },
                })
            end
        end
    else for _, o in pairs(espObjects) do hideFx(o) end end

    if CFG.npcEspEnabled then
        for model, o in pairs(npcObjects) do
            seed = seed + 0.137
            local hum  = model.Parent and model:FindFirstChildOfClass("Humanoid")
            local hrp  = model.Parent and (model:FindFirstChild("HumanoidRootPart")
                or model:FindFirstChild("Head"))
            local head = model.Parent and (model:FindFirstChild("Head") or hrp)
            if not (model.Parent and hum and hrp and head) then hideFx(o)
            else
                local dist = (myPos - hrp.Position).Magnitude
                local vis = CFG.npcVisibleCheck and SA.IsVisible(model, hrp.Position)
                local base = CFG.npcVisibleCheck
                    and (vis and espC("npcVisible") or espC("npcHidden"))
                    or espC("npcFlat")
                local typeColor = nil
                if CFG.npcUseTypeColors then
                    local n = string.lower(model.Name)
                    typeColor = n:find("guard") and espC("npcGuard")
                        or (n:find("scav") and espC("npcScavenger")
                        or (n:find("soldier") and espC("npcSoldier") or nil))
                end
                local dot = CFG.npcVisibleCheck
                    and (vis and espC("npcVisible") or espC("npcHidden"))
                    or espC("npcFlat")
                local raw, ok = cam:WorldToViewportPoint(hrp.Position)
                local hv = cam:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
                local lv = cam:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
                local h = math.abs(hv.Y - lv.Y); local w = h / 2
                drawEntity(cam, o, {
                    enabled = dist <= CFG.npcMaxDist, pal = "npc",
                    base = base, visColor = dot, seed = seed,
                    checkVisible = CFG.npcVisibleCheck, typeColor = typeColor,
                    dist = dist, maxDist = CFG.npcMaxDist, model = model,
                    target = (targetModel == model), origin = origin, opened = false,
                    fovCenter = fovC, fovRadius = fovR,
                    ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1),
                    geom = { x = raw.X - w / 2, y = hv.Y, w = w, h = h,
                             raw = raw, ok = ok, onScreen = ok and raw.Z > 0 },
                })
            end
        end
    else for _, o in pairs(npcObjects) do hideFx(o) end end

    if CFG.crateEnabled then
        for _, o in pairs(crateObjects) do
            seed = seed + 0.137
            if not o.visible or not o.pos then hideFx(o)
            else
                local base = o.opened and espC("crateOpened")
                    or (o.kind == "Military" and espC("crateMilitary")
                    or (o.kind == "Elite" and espC("crateElite") or espC("crateLoot")))
                local raw, ok = cam:WorldToViewportPoint(o.pos)
                local tv = cam:WorldToViewportPoint(o.pos + Vector3.new(0, 2, 0))
                local bv = cam:WorldToViewportPoint(o.pos - Vector3.new(0, 2, 0))
                local h = math.max(math.abs(tv.Y - bv.Y), 18)
                local w = math.max(h * 0.9, 24)
                drawEntity(cam, o, {
                    enabled = true, pal = "crate", base = base, visColor = base,
                    seed = seed, dist = o.dist or 0, maxDist = CFG.crateMaxDist,
                    model = nil, target = false, origin = origin,
                    opened = o.opened, ratio = 1, checkVisible = false,
                    fovCenter = fovC, fovRadius = fovR,
                    typeColor = base, keepNameColor = true,
                    geom = { x = raw.X - w / 2, y = tv.Y, w = w, h = h,
                             raw = raw, ok = ok, onScreen = ok and raw.Z > 0 },
                })
            end
        end
    else for _, o in pairs(crateObjects) do hideFx(o) end end
end
