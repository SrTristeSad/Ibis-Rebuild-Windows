# Migração do Ibis Rebuild Windows para Lua

## Estado da branch migration/lua-only-engine

- Interface, edição raster, camadas, histórico e persistência executam
  em LuaJIT sobre o LÖVE 11.5.
- `app/native.lua` passou a ser uma fachada que reexporta módulos Lua;
  a aplicação não carrega mais DLL própria C++.
- `app/raster_lua.lua`, `app/raster_stroke.lua` e `app/raster_tools.lua`
  implementam pixels, pincéis, borracha, pressão, inclinação, seleção,
  formas, balde e composição parcial de camadas.
- Build de Windows em Lua: `tools/lua_builder/main.lua`, invocado por
  `build.ps1`. Testes LuaJIT: `tools/lua_tests/main.lua`, invocado
  por `test.ps1`.
- Os antigos arquivos C++, Python, CMake e CI C++/Python foram retirados
  da branch (permanecem recuperáveis pelo histórico Git).
- Dependências externas: LÖVE 11.5, suas DLLs e APIs Win32 chamadas
  por LuaJIT FFI.

## Validação automatizada

- CI Linux executa regressões puras de raster LuaJIT.
- CI Windows executa 12 suítes Lua, incluindo regressões anteriores
  de documento RBD2, camadas, seleção, preenchimento, traços e histórico.
- O empacotador Windows cria `.love` e executável final sem compilação C++.
- O pacote ZIP é aberto e inspecionado, exigindo entradas Lua essenciais
  e rejeitando C++/Python e DLL própria embutida.
- GUI real testada com OpenGL por software no runner Windows:
  abre editor, desenha, atualiza textura GPU, desfaz/refaz e salva RBD2.
- O executável final **fundido** também inicia e encerra com sucesso no
  runner Windows. Mesa é usado apenas nos testes e removido antes da
  publicação do artefato.

## Limites que continuam

Não existe fidelidade visual/funcional 1:1 ao ibisPaint Android 14.1.2
comprovada. O desempenho e a percepção de latência devem ser medidos
em hardware físico. A antiga ponte Windows Ink C++ foi removida;
suporte avançado a WM_POINTER, pressão real e inclinação da caneta
ainda requer implementação Lua/FFI e validação prática.

A principal linha `main` não é alterada automaticamente por esta branch.
