-- Compatibilidade com as chamadas existentes do editor.
-- Todo o rasterizador proprio foi transferido para modulos Lua.
-- LuaJIT/FFI e apenas mecanismo de memoria; nenhuma DLL e carregada.
return require('raster_lua')
