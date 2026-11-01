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

A entrada de caneta usa uma ponte Windows Ink experimental em
`app/windows_ink.lua`, implementada em LuaJIT FFI com APIs Win32.
Sua integração com a janela LÖVE passou nos testes; pressão/inclinação
com caneta física ainda não foram verificadas. Mouse/toque do LÖVE
permanecem como fallback, com opção `--no-windows-ink`.
Consulte [WINDOWS_INK_LUA.md](WINDOWS_INK_LUA.md).

Ver [estado da migração](LUA_ONLY_MIGRATION.md) e
[workflows de testes](../.github/workflows).
