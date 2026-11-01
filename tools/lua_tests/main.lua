-- Executor de testes LuaJIT usando LÖVE, sem Python e sem C++.
local raster={
    'test_raster_lua.lua',
    'test_raster_stroke.lua',
    'test_raster_tools.lua',
    'test_raster_layer_integration.lua',
    'test_gpu_upload.lua',
    'test_windows_ink_lua.lua',
    'test_raster_compositor_equivalence.lua',
    'test_raster_opaque_rows.lua',
    'bench_raster_composition.lua',
    'bench_raster_comparison.lua'
}
-- Suites historicas Lua reutilizadas para detectar regressoes reais.
-- Cada suite recebe seu proprio diretorio de documentos RBD2.
local integration={
    'test_store.lua',
    'test_layers.lua',
    'test_edit_history.lua',
    'test_fill.lua',
    'test_shapes.lua',
    'test_selection.lua',
    'test_stroke_accumulation.lua',
    'test_partial_canvas.lua'
}
local function test(root,name,withStore)
    io.write('[Lua] '..name..'...\n')
    local chunk,reason=loadfile(root..'/tests/'..name)
    assert(chunk,reason)
    local module=chunk()
    if withStore then
        assert(type(module)=='table' and type(module.run)=='function',
            'Suite historica sem funcao run: '..name)
        local fixture=root..'/build/lua-fixtures/'..name:gsub('%.lua$','')
        local report=module.run(fixture)
        assert(type(report)=='table' and report.passed==true,
            'Suite nao retornou sucesso: '..name)
    end
end
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
        for _,name in ipairs(raster) do test(root,name,false) end
        for _,name in ipairs(integration) do test(root,name,true) end
    end,debug.traceback)
    if not ok then
        io.stderr:write('[FALHOU] '..tostring(err)..'\n')
        love.event.quit(1)
    else
        io.write('Testes raster + RBD2 de compatibilidade Lua passaram.\n')
        love.event.quit(0)
    end
end
