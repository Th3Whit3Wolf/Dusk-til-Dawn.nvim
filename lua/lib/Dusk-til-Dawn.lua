local vim = vim
local uv = vim.loop
local co = coroutine

if vim.g.dusk_til_dawn_loaded == 1 then
    return
end

vim.g.dusk_til_dawn_loaded = 1

local debug = (function()
    if vim.g.dusk_til_dawn_debug ~= nil then
        return vim.g.dusk_til_dawn_debug
    else
        return false
    end
end)()

-- Get morning and night times
local morning = (function()
    if vim.g.dusk_til_dawn_morning ~= nil then
        return vim.g.dusk_til_dawn_morning
    else
        return 7
    end
end)()
local night = (function()
    if vim.g.dusk_til_dawn_night ~= nil then
        return vim.g.dusk_til_dawn_night
    else
        return 19
    end
end)()

-- Get light and dark themes
local light_theme_colorscheme = (function()
    if vim.g.dusk_til_dawn_light_theme ~= nil then
        return vim.g.dusk_til_dawn_light_theme
    else
        return 'morning'
    end
end)()
local dark_theme_colorscheme = (function()
    if vim.g.dusk_til_dawn_dark_theme ~= nil then
        return vim.g.dusk_til_dawn_dark_theme
    else
        return 'evening'
    end
end)()

-- Get light and dark themes for minimal lua colorschemes
local light_luafile_colorscheme = (function()
    if vim.g.dusk_til_dawn_light_luafile ~= nil then
        return vim.g.dusk_til_dawn_light_luafile
    else
        return nil
    end
end)()
local dark_luafile_colorscheme = (function()
    if vim.g.dusk_til_dawn_dark_luafile ~= nil then
        return vim.g.dusk_til_dawn_dark_luafile
    else
        return nil
    end
end)()

function currentTime()
    local hours = tonumber(os.date("%H"))
    local mins = tonumber(os.date("%M"))
    local secs = tonumber(os.date("%S"))

    return (hours * 3600) + (mins * 60) + secs
end

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
    if vim.api.nvim_get_option('background') == 'light' then
        darkColors()
    else
        lightColors()
    end
end

local function initColorscheme()
    local hours = tonumber(os.date("%H"))
    if hours >= morning and hours <= night then
        lightColors()
    else
        darkColors()
    end
end

local function nap_time()
    local morn = morning * 3600
    local nigh = night * 3600
    local ct = currentTime()

    local count_down = (function()
        if ct < morn then
            return ct - morn
        elseif ct >= morn and ct < nigh then
            return nigh - ct
        else
            -- 86400 is amount a seconds in a day
            return (86400 - ct) + morn
        end
    end)()

    if debug then
        print('Colorscheme Change in ' .. math.floor(count_down / 3600) .. 'hours(s) ' ..
                  math.floor(count_down % 3600 / 60) .. 'minute(s) ' .. math.floor(count_down % 3600 % 60) ..
                  'second(s)')
    end

    -- Timer takes number in milliseconds
    return count_down * 1000
end

-- #################### ############ ####################
-- #################### Async Region ####################
-- #################### ############ ####################

--- use with wrap
local wrapHelper = function(func, callback)
    assert(type(func) == "function", "type error :: expected func")
    local thread = co.create(func)
    local step = nil
    step = function(...)
        local stat, ret = co.resume(thread, ...)
        assert(stat, ret)
        if co.status(thread) == "dead" then
            (callback or function()
            end)(ret)
        else
            assert(type(ret) == "function", "type error :: expected func")
            ret(step)
        end
    end
    step()
end

--- use with wrap, creates thunk factory
local wrap = function(func)
    assert(type(func) == "function", "type error :: expected func")
    local factory = function(...)
        local params = {...}
        local thunk = function(step)
            table.insert(params, step)
            return func(unpack(params))
        end
        return thunk
    end
    return factory
end

--- sugar over coroutine
local await = function(defer)
    assert(type(defer) == "function", "type error :: expected func")
    return co.yield(defer)
end

--- Create a timer that changes at morning and night
local timer = wrap(function(callback)
    -- wait til next time of day change
    local tm = (function()
        if debug == true then
            return 1000
        else
            return nap_time()
        end
    end)()

    local t = uv.new_timer()
    uv.timer_start(t, tm, 0, function()
        uv.timer_stop(t)
        uv.close(t)
        callback()
    end)
end)

-- #################### ############ ####################
-- #################### Loops Region ####################
-- #################### ############ ####################

-- avoid textlock
local main_loop = function(f)
    vim.schedule(f)
end

--- Set initial colorscheme, and change colorscheme at day and night
local colorschemeManager = function()
    return wrap(wrapHelper)(function()
        initColorscheme()
        nap_time()
        while true do
            await(timer())
            await(main_loop)
            changeColors()
        end
    end)
end

colorschemeManager()()

