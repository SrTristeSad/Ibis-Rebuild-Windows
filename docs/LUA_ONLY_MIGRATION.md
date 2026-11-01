# Migração do Ibis Rebuild Windows para Lua

## Arquitetura ativa da branch

- Interface: LÖVE 11.5, LuaJIT.
- Raster: `app/raster_lua.lua`, `app/raster_stroke.lua`,
  `app/raster_tools.lua`; nenhuma DLL de rasterização própria.
- Compatibilidade da interface existente: `app/native.lua` agora reexporta
  a API Lua; o gerenciador de camadas e o formato RBD2 foram preservados.
- Empacotamento Windows: `build.ps1` invoca o LÖVE para executar o
  empacotador `tools/lua_builder/main.lua`, sem Python ou C++.
- Testes Windows: `test.ps1` invoca `tools/lua_tests/main.lua` no LÖVE.
- Entrada da caneta: `app/windows_ink.lua` não usa mais a antiga DLL
  WM_POINTER; pressão e inclinação física de canetas ainda não foram
  restauradas. O toque do LÖVE e o mouse continuam disponíveis.
- Acesso a arquivos Windows: LuaJIT FFI faz chamadas ao sistema
  operacional Win32, sem código C/C++ compilado pelo projeto.

## Verificações realizadas

- Workflow Linux LuaJIT: testes de raster, traços, geometria e camadas.
- Workflow Windows: mesmas suites, geração do executável por Lua e
  verificação do pacote sem `rebuild_core.dll`.
- Smoke de GUI Windows real com OpenGL por software: abriu editor,
  carregou imagem GPU, atualizou sub-região de textura, desfez/refez
  uma pincelada e salvou/reabriu dados RBD2.

Essas verificações foram executadas pelo GitHub Actions; não garantem
qualidade de pintura, desempenho em hardware real, suporte de canetas
físicas nem equivalência exata ao ibisPaint Android 14.1.2.

## Pendências

- Validar visualmente a fidelidade dos pincéis e as diferenças de
  arredondamento/composição em comparação à versão histórica.
- Restaurar Windows Ink inteiramente pela camada Lua/FFI, se tecnicamente
  possível, com testes de hardware real.
- Atualizar e ampliar os testes de interface e da persistência RBD2;
  preservar a segurança do formato e de dados de usuário.
- Revalidar desempenho sob canvases grandes, múltiplas camadas e
  pinceladas longas antes de liberar versão estável.

O projeto é uma reimplementação independente; não distribui arquivos
proprietários do aplicativo Android, nem declara paridade 1:1.
