local vim = vim
local hours = tonumber(vim.fn.strftime("%H"))
local mins = tonumber(vim.fn.strftime("%M"))
local sec = tonumber(vim.fn.strftime("%S"))

if vim.g.dusk_til_dawn_loaded == 1 then
    return
end

vim.g.dusk_til_dawn_loaded = 1

-- Get morning and night times
local morning = (function() if vim.g.dusk_til_dawn_morning ~= nil then return vim.g.dusk_til_dawn_morning else return 7 end end)()
local night = (function() if vim.g.dusk_til_dawn_night ~= nil then return vim.g.dusk_til_dawn_night else return 19 end end)()

-- Get light and dark themes
local light_theme_colorscheme = (function() if vim.g.dusk_til_dawn_light_theme ~= nil then return vim.g.dusk_til_dawn_light_theme else return 'morning' end end)()
local dark_theme_colorscheme = (function() if vim.g.dusk_til_dawn_dark_theme ~= nil then return vim.g.dusk_til_dawn_dark_theme else return 'evening' end end)()

-- Get light and dark themes for minimal lua colorschemes
local light_luafile_colorscheme = (function() if vim.g.dusk_til_dawn_light_luafile ~= nil then return vim.g.dusk_til_dawn_light_luafile else return nil end end)()
local dark_luafile_colorscheme = (function() if vim.g.dusk_til_dawn_dark_luafile ~= nil then return vim.g.dusk_til_dawn_dark_luafile else return nil end end)()

--- Set the light colorscheme
local function lightColors()
    vim.o.background = 'light'
    if light_luafile_colorscheme ~= nil then
        vim.cmd('luafile ' .. light_luafile_colorscheme)
    else
        vim.cmd('colorscheme ' .. light_theme_colorscheme)
    end
end

--- Set the dark colorscheme
local function darkColors()
    vim.o.background = 'dark'
    if dark_luafile_colorscheme ~= nil then
        vim.cmd('luafile ' .. dark_luafile_colorscheme)
    else
        vim.cmd('colorscheme ' .. dark_theme_colorscheme)
    end
end

--- Toggle colorschemes (light/dark)
function changeColors()
    if vim.o.background == 'light' then
        darkColors()
    else
        lightColors()
    end
end

local function nap()
    local s = (60 - sec) * 1000
    local m
    local h

    if hours >= morning and hours <= night then
        if (mins + 1) < 60 then
            m = (mins + 1) * 60000
        else
            m = 0
        end
        if (hours + 1) < night then
            h = (hours + 1) * 3600000
        else
            h = 0
        end
        lightColors()
    else
        if (mins + 1) < 60 then
            m = (mins + 1) * 60000
        else
            m = 0
        end
        if (hours + 1) < morning then
            h = (hours + 1) * 3600000
        else
            h = 0
        end
        darkColors()
    end
    return  h + m + s
end

local sleep_now = nap()

local sleep_regular = (night - morning) * 3600000
-- Create a timer handle (implementation detail: uv_timer_t).
local timer = vim.loop.new_timer()
local i = 0

-- Nap until initial time change,
-- then repeats for time period equal to night - morning (Assumes 12 hour difference)
-- Only last ~48 hours + time to initial timechange.
timer:start(
    sleep_now,
    sleep_regular,
    function()

    if i > 4 then
        timer:close()  -- Always close handles to avoid leaks.
    end
    changeColors()
    i = i + 1

    end
)
