-- Windows LuaJIT regression launcher using the official LÖVE runtime.
-- Execute from test.ps1 with an absolute repository root argument.
local suites={
    'test_raster_lua.lua',
    'test_raster_stroke.lua',
    'test_raster_tools.lua',
    'test_raster_layer_integration.lua'
}
function love.load(args)
    local root=(args and args[1]) or os.getenv('IBIS_PROJECT_ROOT')
    if not root or root=='' then
        io.stderr:write('Informe o diretorio raiz do projeto.\n')
        love.event.quit(1)
        return
    end
    root=root:gsub('\\','/')
    package.path=root..'/app/?.lua;'..root..'/app/?/init.lua;'..package.path
    local ok,err=xpcall(function()
        for _,name in ipairs(suites) do
            io.write('[Lua] '..name..'...\n')
            local chunk,reason=loadfile(root..'/tests/'..name)
            assert(chunk,reason)
            chunk()
        end
    end,debug.traceback)
    if not ok then
        io.stderr:write('[FALHOU] '..tostring(err)..'\n')
        love.event.quit(1)
    else
        io.write('Todas as suites Lua da migracao passaram.\n')
        love.event.quit(0)
    end
end
