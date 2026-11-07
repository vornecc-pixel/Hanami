-- ==================================================================
-- Hanami / 17_gun_mods.lua — GC scan gun mods + per-frame state writes
-- Loaded in order by loader.lua. Parts are joined into ONE chunk
-- before running, so every `local` is shared just like the original.
-- ==================================================================

-- ────────────────────────────────────────────────────────────────────
-- GUN MODS (7 toggles — GC scan)
-- ────────────────────────────────────────────────────────────────────

local activeGunStates = {}

task.spawn(function()
    while true do
        if CFG.gmEnabled and getgc and setreadonly then
            local found = {}
            local objects = getgc(true)
            local count = 0
            for _, tbl in pairs(objects) do
                if type(tbl) == "table" then
                    count = count + 1
                    if count % 3000 == 0 then RunService.RenderStepped:Wait() end
                    pcall(setreadonly, tbl, false)
                    if CFG.gmInstantEquip then
                        if rawget(tbl, "EQUIP_TIME")  ~= nil then rawset(tbl, "EQUIP_TIME",  0) end
                        if rawget(tbl, "HOLSTER_TIME") ~= nil then rawset(tbl, "HOLSTER_TIME", 0) end
                    end
                    if CFG.gmInstantAds then
                        if rawget(tbl, "AdsTime")    ~= nil then rawset(tbl, "AdsTime",    0) end
                        if rawget(tbl, "AdsOutTime") ~= nil then rawset(tbl, "AdsOutTime", 0) end
                        if rawget(tbl, "adsTime")    ~= nil then rawset(tbl, "adsTime",    0) end
                    end
                    if CFG.gmNoSpread then
                        if rawget(tbl, "spread")      ~= nil then rawset(tbl, "spread",      0) end
                        if rawget(tbl, "adsSpread")   ~= nil then rawset(tbl, "adsSpread",   0) end
                        if rawget(tbl, "moveSpread")  ~= nil then rawset(tbl, "moveSpread",  0) end
                        if rawget(tbl, "MOVE_SPREAD") ~= nil then rawset(tbl, "MOVE_SPREAD", 0) end
                        if rawget(tbl, "AirSpread")   ~= nil then rawset(tbl, "AirSpread",   0) end
                    end
                    if CFG.gmForceAuto then
                        if rawget(tbl, "auto") ~= nil then rawset(tbl, "auto", true) end
                    end
                    if CFG.gmNoRecoil then
                        if rawget(tbl, "VisualBloom") ~= nil then rawset(tbl, "VisualBloom", 0) end
                        if rawget(tbl, "RecoilClimb") ~= nil then rawset(tbl, "RecoilClimb", 0) end
                        if rawget(tbl, "ShakeMax")    ~= nil then rawset(tbl, "ShakeMax",    0) end
                    end
                    if CFG.gmNoSway then
                        if rawget(tbl, "SWAY")     ~= nil then rawset(tbl, "SWAY",     0) end
                        if rawget(tbl, "SWAY_MAX") ~= nil then rawset(tbl, "SWAY_MAX", 0) end
                        if rawget(tbl, "BOB_WALK") ~= nil then rawset(tbl, "BOB_WALK", 0) end
                        if rawget(tbl, "BOB_IDLE") ~= nil then rawset(tbl, "BOB_IDLE", 0) end
                        if rawget(tbl, "LEAN")     ~= nil then rawset(tbl, "LEAN",     0) end
                    end
                    if CFG.gmNoKick then
                        if rawget(tbl, "KICK_PITCH") ~= nil then rawset(tbl, "KICK_PITCH", 0) end
                        if rawget(tbl, "KICK_BACK")  ~= nil then rawset(tbl, "KICK_BACK",  0) end
                    end
                    if rawget(tbl, "SpreadPx") ~= nil and rawget(tbl, "equipAt") ~= nil then
                        table.insert(found, tbl)
                    end
                end
            end
            activeGunStates = found
        end
        task.wait(1)
    end
end)

RunService.RenderStepped:Connect(function()
    if not CFG.gmEnabled then return end
    for _, state in ipairs(activeGunStates) do
        if CFG.gmInstantEquip and state.equipAt and state.equipAt ~= -math.huge then
            state.equipAt = -math.huge
        end
        if CFG.gmNoSpread then state.SpreadPx = 0 end
        if CFG.gmNoRecoil then
            state.recoil = 0; state.recoilYaw = 0
            state.RecoilPend = 0; state.RecoilYawPend = 0
            state.shakeUntil = 0; state.shakeStrength = 0
        end
        if CFG.gmNoKick then
            state.kick = 0; state.kickV = 0
            state.kickPitch = 0; state.kickRoll = 0
        end
    end
end)

