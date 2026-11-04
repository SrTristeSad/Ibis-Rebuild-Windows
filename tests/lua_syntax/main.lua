-- Verifica sintaxe no LuaJIT real, antes de carregar testes gráficos.
local names = {"paint_main.lua", "lua_engine.lua", "lua_bridge.lua",
               "lua_selection.lua"}
function love.load()
    for _, name in ipairs(names) do
        local contents, read_error = love.filesystem.read(name)
        if not contents then
            io.stderr:write("LUA_SYNTAX_READ_ERROR: ", name, " ",
                tostring(read_error), "\n")
            io.stderr:flush()
            love.event.quit(1)
            return
        end
        local parsed, reason = loadstring(contents, "@" .. name)
        if not parsed then
            io.stderr:write("LUA_SYNTAX_ERROR: ", tostring(reason), "\n")
            io.stderr:flush()
            love.event.quit(1)
            return
        end
        io.stdout:write("LUA_SYNTAX_OK: ", name, "\n")
        io.stdout:flush()
    end
    love.event.quit(0)
end
