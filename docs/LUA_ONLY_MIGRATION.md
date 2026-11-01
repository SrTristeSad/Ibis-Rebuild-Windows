# Migracao para implementacao inteiramente em Lua

Decisao arquitetural: todo o **codigo proprio** do aplicativo, motor de pintura,
interface, build e testes sera escrito em Lua. O runtime LÖVE/LuaJIT e uma
dependencia externa; seu codigo interno nao faz parte desta migracao.

## Estado atual

Esta branch inicia a substituicao do motor C++ e scripts Python, sem apagar
funcionalidades antes de existirem equivalentes Lua testados.

- `app/raster_lua.lua`: implementacao LuaJIT de buffers RGBA, leitura/escrita
  de pixels, limpeza, composicao normal e composicao por retangulo.
- `tests/test_raster_lua.lua`: teste inicial sem dependencia da DLL.
- FFI nesta etapa **somente aloca e acessa bytes**. Nao carrega DLL, nao
  executa funcoes de rasterizacao C++ e nao contem codigo C++ proprio.

## Pendencias para substituir `app/native.lua`

Portar em Lua, com testes de regressao: pincel rigido/suave, pressao,
inclinacao, acumulador de pincelada, borracha, selecao/movimentacao,
transformacoes, preenchimento, formas, espelhamento, normalizacao de
pressao e empacotamento de amostras. Depois conectar o editor ao novo
motor e retirar `native/*.cpp`, `native/*.h`, CMake e scripts Python,
substituindo o pipeline por ferramentas Lua. Entrada Windows Ink precisa
de uma solucao especifica sem codigo nativo proprio.

**Nao habilitar a troca do motor por padrao ate o contrato estar completo.**
O editor da main continua funcional enquanto a migracao e revisada.
