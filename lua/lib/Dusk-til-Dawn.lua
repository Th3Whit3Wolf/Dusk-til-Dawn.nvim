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
    if debug then
        return 10
    else
        return (function()
            if vim.g.dusk_til_dawn_morning ~= nil then
                return vim.g.dusk_til_dawn_morning
            else
                return 7
            end
        end)()
    end
end)()
local night = (function()
    if debug then
        return 10
    else
        return (function()
            if vim.g.dusk_til_dawn_night ~= nil then
                return vim.g.dusk_til_dawn_night
            else
                return 7
            end
        end)()
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

local function currentTime()
    local hours = (function()
        if debug == true then
            return 10
        else
            return tonumber(os.date("%H"))
        end
    end)()
    local mins = (function()
        if debug == true then
            return 59
        else
            return tonumber(os.date("%M"))
        end
    end)()
    local secs = (function()
        if debug == true then
            return 58
        else
            return tonumber(os.date("%S"))
        end
    end)()

    return hours, mins, secs
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
    local hours, mins, sec = currentTime()
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
        if debug then
            print('Colorscheme Change in ' .. h .. 'h ' .. m .. 'm ' .. s .. 's')
        end
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
        if debug then
            print('Colorscheme Change in ' .. h .. 'h ' .. m .. 'm ' .. s .. 's')
        end
    end
    return h + m + s
end

-- #################### ############ ####################
-- #################### Async Region ####################
-- #################### ############ ####################

-- use with wrap
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

-- use with wrap, creates thunk factory
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

-- sugar over coroutine
local await = function(defer)
    assert(type(defer) == "function", "type error :: expected func")
    return co.yield(defer)
end

--- Create a timer that changes at morning and night
local timer = wrap(function(callback)
    -- wait til next time of day change
    local tm = nap_time()
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

local textlock_succ = function()
    return wrap(wrapHelper)(function()
        initColorscheme()
        while true do
            await(timer())
            await(main_loop)
            changeColors()
        end
    end)
end

textlock_succ()()
