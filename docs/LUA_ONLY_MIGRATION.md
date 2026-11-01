# Migracao para motor escrito integralmente em Lua

Objetivo: toda implementacao propria em Lua. O editor continua utilizando
o runtime externo LÖVE 11.5 / LuaJIT, que nao sera reimplementado.

## Implementado nesta branch

- `app/native.lua` agora delega todas as operacoes raster a `raster_lua.lua`;
  nao ha DLL C++ carregada pelo editor.
- `app/raster_lua.lua`: canvas RGBA, composicao de camadas e regioes parciais.
- `app/raster_stroke.lua`: pincel rigido/suave, inclinado, pressao
  interpolada, borracha, cobertura unica por gesto, espelhamento e
  helpers de pressao/amostras.
- `app/raster_tools.lua`: balde, formas, movimento e transformacao de selecao.
- `app/windows_ink.lua`: remove dependencia da DLL Win32 anterior; retorna
  indisponivel para a ponte WM_POINTER. Mouse e toque pelo LÖVE permanecem;
  caneta fisica/tilt via Win32 ainda requer solucao Lua.
- `tests/test_raster_*.lua`: regressoes do raster e do gerenciador de camadas.
- `tools/lua_tests/` e `test.ps1`: executor LuaJIT usando o LÖVE, sem Python.
- `tools/lua_builder/` e `build.ps1`: arquivo .love e executavel Windows gerados em Lua, sem compilar codigo C++.
- `.github/workflows/lua-windows.yml`: verificacao do pacote Windows e execucao das suites Lua.
- `.github/workflows/lua-migration.yml`: suite LuaJIT separada sem compilador
  C++ ou scripts Python.

## Antes de mesclar

**Nao ha validacao de execucao do editor nesta sessao.** O novo raster
pode divergir do antigo no arredondamento RGBA e no desempenho: comparar
capturas, dados RBD2, suavizacao, pressoes, historico e entrada real.

O repositorio AINDA contem `native/*.cpp`, `native/*.h`, scripts
`tools/*.py`, CMake e workflow legado; estes arquivos nao foram apagados
porque a migracao de build/testes/distribuicao ainda nao terminou.
O workflow Windows antigo e seus testes C++/Python precisam ser
aposentados depois que o novo fluxo Lua estiver validado. O novo
empacotador nao inclui a DLL propria `rebuild_core.dll`, mas inclui
as bibliotecas do runtime oficial LÖVE para que o executavel funcione.

Nao ha alegacao de equivalencia 1:1 com o ibisPaint Android 14.1.2.
