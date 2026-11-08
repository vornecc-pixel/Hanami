-- ==================================================================
-- Hanami — short loader. This is the ONLY file you paste/load.
-- It downloads every src/*.lua part and runs them as ONE script.
--
-- Luau has a hard limit of 200 live local registers per compiled
-- function. Joining every part into one giant chunk used to trip it:
--   [string "Hanami"]:3904: Out of local registers when trying to
--   allocate playerSec: exceeded limit 200
-- ...because every part added its own top-level `local`s to the SAME
-- main chunk (225 column-1 locals at the time). The script never started.
--
-- Fix: before compiling, hoist each column-1 `local X = ...` into the
-- chunk environment (`X = ...`). Indented `local`s (inside functions)
-- are untouched, so each function keeps its own small set of upvalues.
-- The main chunk then needs ZERO local registers, while every part
-- still sees the same shared names (CFG, SA, library, ...).
--
-- With setfenv those shared names live in an isolated table, so no
-- global spam. Executors without setfenv fall back to normal globals;
-- the script behaves the same either way.
-- ==================================================================

local REPO = "vornecc-pixel/Hanami"
local REF  = "arena%2Fbb927757-hanami"   -- branch name; %2F means "/"
local DIR  = "src/"
local BUST = "?t=" .. tostring(os.time()) -- bypass CDN cache after updates

local PARTS = {
    "01_config.lua",
    "02_drawing.lua",
    "02_shared.lua",
    "02_workspace_scan.lua",
    "03_entity_scan.lua",
    "04_entity_info.lua",
    "05_manipulation.lua",
    "06_firing_and_guns.lua",
    "07_gun_specs.lua",
    "08_prediction.lua",
    "09_silent_aim.lua",
    "10_fov_circle.lua",
    "11_snapline.lua",
    "12_esp_players.lua",
    "13_esp_players_refresh.lua",
    "14_esp_npcs.lua",
    "15_esp_npcs_refresh.lua",
    "16_esp_crates.lua",
    "16_esp_crates_registry.lua",
    "17_esp_crates_refresh.lua",
    "18_esp_fx_colours.lua",
    "18_esp_fx_draw.lua",
    "18_esp_fx_frame.lua",
    "19_render_loop.lua",
    "20_gun_mods.lua",
    "21_ui_aiming.lua",
    "22_esp_preview.lua",
    "22_esp_preview_setup.lua",
    "22_ui_esp.lua",
    "23_ui_gunmods.lua",
    "24_ui_visual.lua",
    "25_ui_misc.lua",
    "26_banner.lua",
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

-- Only column-1 declarations are hoisted. The leading "\n" makes the
-- pattern also match a `local` on the very first line of a part.
-- A bare `local x, y` (no initializer) would become a bare expression
-- after stripping `local`, so give that one an explicit `= nil`.
local function hoist(src)
    local s = ("\n" .. src):gsub("\nlocal[ \t]+([^\n]*)", function(rest)
        local commentAt = rest:find("--", 1, true)
        local code = commentAt and rest:sub(1, commentAt - 1) or rest
        if not rest:match("^function") and not code:find("=", 1, true) then
            return "\n" .. code .. "= nil " .. (commentAt and rest:sub(commentAt) or "")
        end
        return "\n" .. rest
    end)
    return s:sub(2)
end

-- Isolated table for the hoisted names. Copying the real globals in keeps
-- hot loops (game / math / task / Vector2 / Color3 / tick ...) as plain
-- table hits instead of a metatable lookup every frame. __index covers
-- anything an executor exposes lazily and pairs() may not enumerate.
local function makeEnv()
    if type(setfenv) ~= "function" then return nil end
    local ok, base = pcall(function()
        if type(getfenv) == "function" then return getfenv(1) end
        return _G
    end)
    if not ok or type(base) ~= "table" then return nil end
    local env = setmetatable({}, { __index = base })
    pcall(function()
        for k, v in pairs(base) do env[k] = v end
    end)
    return env
end

local chunks, offsets, line = {}, {}, 1
for i, name in ipairs(PARTS) do
    local src = hoist(fetch(name))
    chunks[i] = src
    offsets[i] = { from = line, name = name }
    line = line + select(2, src:gsub("\n", "")) + 2 -- +2 for the join separator
end

local function partAt(n)
    local found = PARTS[1]
    for i = 1, #offsets do
        if offsets[i].from <= n then found = offsets[i].name else break end
    end
    return found
end

local source = table.concat(chunks, "\n\n")
local chunk, compileErr = loadstring(source, "Hanami")
if not chunk then
    local ln = tonumber(tostring(compileErr):match(":(%d+):"))
    error("[Hanami] compile error" .. (ln and (" in " .. partAt(ln)) or "")
        .. ": " .. tostring(compileErr), 0)
end

local env = makeEnv()
if env then pcall(setfenv, chunk, env) end

return chunk()
