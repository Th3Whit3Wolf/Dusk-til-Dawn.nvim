local vim = vim
local uv = vim.loop
local co = coroutine

local M = {}

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

function M.currentTime()
    local hours = tonumber(os.date("%H"))
    local mins = tonumber(os.date("%M"))
    local secs = tonumber(os.date("%S"))

    return (hours * 3600) + (mins * 60) + secs
end

function M.readSwayColordDawn()
    local f = assert(io.open("/tmp/sway-colord/dawn", "rb"))
    local time = f:read("*all")
    f:close()
    pattern="(%d+):(%d+):(%d+)"
    hour,min,sec=time:match(pattern)
    return (tonumber(hour) * 3600) + (tonumber(min) * 60) + tonumber(sec)
end

function M.readSwayColordDusk()
    local f = assert(io.open("/tmp/sway-colord/dusk", "rb"))
    local time = f:read("*all")
    f:close()
    pattern="(%d+):(%d+):(%d+)"
    hour,min,sec=time:match(pattern)
    return (tonumber(hour) * 3600) + (tonumber(min) * 60) + tonumber(sec)
end

--- Set the light colorscheme
local function lightColors()
    if vim.api.nvim_get_option('background') == 'light' then return end
    vim.o.background = 'light'
    vim.cmd('colorscheme ' .. light_theme_colorscheme)
end

--- Set the dark colorscheme
local function darkColors()
    if vim.api.nvim_get_option('background') == 'dark' then return end
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
end

-- Runs a function durring the day
-- and another function durring the night
function M.day_and_night(day_func, night_func)
    if type(day_func) ~= 'function' or type(night_func) ~= 'function' then
        print('Error: day_and_night takes 2 functions, but received ' .. type(day) .. ' and ' .. type(night) .. '!')
        return
    end
    local now = M.currentTime()
    if sway_colord ~= true then
        local morn = morning * 3600
        local nigh = night * 3600
        
        if now < morn or now > nigh then
            night_func()
        else
            day_func()
        end
    else
        local sunrise = M.readSwayColordDawn()
        local sunset  = M.readSwayColordDusk()
        if now < sunrise or now > sunset then
            night_func()
        else
            day_func()
        end
    end
end

local function toSecs(hours, minutes,seconds)
    return (hours * 3600) + (minutes * 60) + seconds
end

local function nap_timeRigid()
    local morn = morning * 3600
    local nigh = night * 3600
    local ct = M.currentTime()

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
    local sunrise = M.readSwayColordDawn()
    local sunset  = M.readSwayColordDusk()
    local now = M.currentTime()

    local count_down = (function()
        if now < sunrise then
            return sunrise - now
        elseif now >= sunrise and now < sunset then
            return sunset - now
        else
            -- 86400 is amount a seconds in a day
            return (86400 - now) + sunrise
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
            if sway_colord ~= true then
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

--- Manages what to do in day and night times 
M.timeMan = function(day, night)
    return wrap(wrapHelper)(function()
        M.day_and_night(lightColors, darkColors)
        if day ~= nil and night ~= nil then
            M.day_and_night(day, night)
        end
        while true do
            await(timer())
            await(main_loop)
            M.day_and_night(lightColors, darkColors)
            if day ~= nil and night ~= nil then
                M.day_and_night(day, night)
            end
        end
    end)
end


return M
