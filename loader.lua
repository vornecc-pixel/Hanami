-- ==================================================================
-- Hanami — short loader. This is the ONLY file you paste/load.
-- It downloads every src/*.lua part, joins them in order, then runs
-- them as ONE chunk so all the `local`s stay shared (no refactoring).
-- ==================================================================

local REPO = "vornecc-pixel/Hanami"
local REF  = "arena%2Fbb927757-hanami"   -- branch name; %2F means "/"
local DIR  = "src/"
local BUST = "?t=" .. tostring(os.time()) -- bypass CDN cache after updates

local PARTS = {
    "01_config.lua",
    "02_shared.lua",
    "03_manipulation.lua",
    "04_firing_and_guns.lua",
    "05_silent_aim.lua",
    "06_fov_circle.lua",
    "07_esp_players.lua",
    "08_esp_players_refresh.lua",
    "09_esp_crates.lua",
    "10_esp_crates_refresh.lua",
    "11_render_loop.lua",
    "12_gun_mods.lua",
    "13_hitlog.lua",
    "14_ui_aiming.lua",
    "15_ui_esp.lua",
    "16_ui_gunmods.lua",
    "17_ui_visual.lua",
    "18_ui_misc.lua",
    "19_banner.lua",
}

-- GitHub's own "Raw" links use refs/heads/<branch>, which also avoids any
-- ambiguity when the branch name contains a slash. The rest are fallbacks.
local PLAIN = (REF:gsub("%%2F", "/"))
local ROOTS = {
    "https://raw.githubusercontent.com/" .. REPO .. "/refs/heads/" .. PLAIN .. "/" .. DIR,
    "https://raw.githubusercontent.com/" .. REPO .. "/" .. REF   .. "/" .. DIR,
    "https://raw.githubusercontent.com/" .. REPO .. "/" .. PLAIN .. "/" .. DIR,
    "https://github.com/" .. REPO .. "/raw/refs/heads/" .. PLAIN .. "/" .. DIR,
}

local function fetch(path)
    local err = "no source responded"
    for _, root in ipairs(ROOTS) do
        local ok, body = pcall(function()
            return game:HttpGet(root .. path .. BUST)
        end)
        local isHtml = type(body) == "string"
            and (body:find("<!DOCTYPE", 1, true) or body:find("<html", 1, true)
              or body:find("404: Not Found", 1, true))
        if ok and type(body) == "string" and #body > 0 and not isHtml then
            return body
        end
        if not ok then err = tostring(body) elseif isHtml then err = "got an error page" end
    end
    error("[Hanami] could not load " .. path .. " — " .. err, 0)
end

local chunks = {}
for i, name in ipairs(PARTS) do
    chunks[i] = fetch(name)
end

local source = table.concat(chunks, "\n\n")
local chunk, compileErr = loadstring(source, "Hanami")
if not chunk then
    error("[Hanami] compile error: " .. tostring(compileErr), 0)
end

return chunk()
