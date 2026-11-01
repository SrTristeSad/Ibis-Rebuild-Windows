# Arquitetura Lua do Ibis Rebuild Windows

O aplicativo utiliza **LuaJIT no runtime LÖVE 11.5** para interface,
entrada de mouse/toque, composição de telas, edição raster e persistência.

- `app/main.lua`: interface e eventos.
- `app/raster_lua.lua`: buffers RGBA8, pixels e composição de camadas.
- `app/raster_stroke.lua`: traços, pressão interpolada, inclinação,
  cobertura única por gesto, borracha e espelhamento.
- `app/raster_tools.lua`: seleção, movimentação, transformação,
  preenchimento e formas.
- `app/native.lua`: fachada de compatibilidade Lua (não carrega DLL).
- `app/layers.lua`, `app/store.lua`: histórico e formato RBD2.
- `app/fs.lua`: acesso a arquivos Win32 via LuaJIT FFI, sem C++ próprio.
- `tools/lua_builder/`: empacotamento .love + .exe em Lua.
- `tools/lua_tests/`: testes LuaJIT no Windows.

A aplicação não contém servidor, WebView nem dependência de código do
ibisPaint Android. O runtime LÖVE é uma dependência externa que contém
bibliotecas nativas oficiais; estas não são código C++ do projeto.

A antiga ponte C++ de Windows Ink foi removida. Eventos comuns de mouse
e toque LÖVE continuam. A compatibilidade de pressão/inclinação física
por WM_POINTER está pendente de implementação Lua/FFI e teste em hardware.

Ver [estado da migração](LUA_ONLY_MIGRATION.md) e
[workflows de testes](../.github/workflows).
