local vim = vim
local package = package

found = false
local paths = {}
for match in (package.path..";"):gmatch("(.-);") do
    table.insert(paths, match);
end
for k,_ in pairs(paths) do
    local dirs = {}
    for match in (paths[k].."/"):gmatch("(.-)/") do
        table.insert(dirs, match);
    end
    for i=1, #dirs do
        if found then break end
        if dirs[#dirs + 1 - i] == 'Dusk-till-Dawn.nvim' then
            local str = table.concat(dirs , '/' , 1 , #dirs + 1 - i )
            vim.cmd("luafile " .. str .. "/lua/lib/lib.lua")
            vim.cmd("command! ToggleColorscheme lua changeColors()")
            found = true
        end
    end
end


