local vim = vim
local uv = vim.loop
local co = coroutine

local M = {}

local function readSwayColordTmp(file)
    local f = assert(io.open("/tmp/sway-colord/" .., "rb"))
    local time = f:read("*all")
    f:close()
    pattern="(%d+):(%d+):(%d+)"
    hour,min,sec=time:match(pattern)
    return hour,min,sec
end

local debug = (function()
    if vim.g.dusk_til_dawn_debug ~= nil then
        return vim.g.dusk_til_dawn_debug
    else
        return false
    end
end)()

local sway_colord = (function()
    if vim.g.dusk_til_dawn_sway_colord ~= nil then
        return vim.g.dusk_til_dawn_sway_colord
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

function currentTime()
    local hours = tonumber(os.date("%H"))
    local mins = tonumber(os.date("%M"))
    local secs = tonumber(os.date("%S"))

    return (hours * 3600) + (mins * 60) + secs
end

--- Set the light colorscheme
local function lightColors()
    vim.o.background = 'light'
    vim.cmd('colorscheme ' .. light_theme_colorscheme)
end

--- Set the dark colorscheme
local function darkColors()
    vim.o.background = 'dark'
    vim.cmd('colorscheme ' .. dark_theme_colorscheme)
end

--- Toggle colorschemes (light/dark)
function M.changeColors()
    if vim.api.nvim_get_option('background') == 'light' then
        darkColors()
    else
        lightColors()
    end
    if vim.g.loaded_galaxyline == 1 then
        require("galaxyline").load_galaxyline()
    end
end

function M.initColorscheme()
    local hours = tonumber(os.date("%H"))
    if hours >= morning and hours < night then
        lightColors()
    else
        darkColors()
    end
    if vim.g.loaded_galaxyline == 1 then
        require("galaxyline").load_galaxyline()
    end
end

local function toSecs(hours, minutes,seconds)
    return (hours * 3600) + (minutes * 60) + seconds
end

local function nap_timeRigid()
    local morn = morning * 3600
    local nigh = night * 3600
    local ct = currentTime()

    local count_down = (function()
        if ct < morn then
            return morn - ct
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

local function nap_timeSwayColord()
    local sunrise_h, sunrise_m,sunrise_s = readSwayColordTmp('dawn')
    local sunrise_secs = toSecs(sunrise_h, sunrise_m, sunrise_s)
    local sunset_h, sunset_m,sunset_s = readSwayColordTmp('dusk')
    local sunset_secs = toSecs(sunset_h, sunset_m, sunset_s)
    local current_h = tonumber(os.date("%H"))
    local current_m = tonumber(os.date("%M"))
    local current_s = tonumber(os.date("%S"))
    local now = toSecs(current_h, current_m, current_s)

    local count_down = (function()
        if current_h < sunrise_h then
            return sunrise_secs - now
        elseif current_h >= sunrise_h and current_h < sunset_h then
            return sunset_secs - now
        else
            -- 86400 is amount a seconds in a day
            return (86400 - now) + sunrise_secs
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
            if sway_colord ~= true
                return nap_timeRigid()
            else
                return nap_timeSwayColord()
            end
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
M.colorschemeManager = function()
    return wrap(wrapHelper)(function()
        M.initColorscheme()
        while true do
            await(timer())
            await(main_loop)
            M.changeColors()
        end
    end)
end

return M