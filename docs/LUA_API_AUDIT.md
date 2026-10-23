# Auditoria da API Lua e do encerramento

O host sem gráficos usa `ctypes.CDLL` com a ABI C do LuaJIT e somente a DLL `lua51.dll`. Python e DLL devem ser PE x64/ponteiros de 8 bytes. A identidade em execução foi conferida como Lua 5.1, LuaJIT 2.1, x64. O objeto Python mantém a DLL viva até finalizar seu estado.

| Função | argtypes | restype |
|---|---|---|
| luaL_newstate | [] | c_void_p |
| luaL_openlibs | [c_void_p] | None |
| lua_close | [c_void_p] | None |
| lua_gettop | [c_void_p] | c_int |
| lua_settop | [c_void_p,c_int] | None |
| luaL_loadfile / luaL_loadstring | [c_void_p,c_char_p] | c_int |
| lua_pcall | [c_void_p,c_int,c_int,c_int] | c_int |
| lua_tolstring | [c_void_p,c_int,POINTER(c_size_t)] | c_void_p |

`luaL_newstate` é validado contra NULL. O stack inicial deve estar vazio. O ponteiro pertence a uma única instância; não pode ser reutilizado após close nem encerrado duas vezes. Exceção em close é falha propagada e nunca permite registrar aprovação. O resultado é escrito **depois** do encerramento de todos os estados.

Na implementação anterior, o retorno de luaL_newstate e o argumento de lua_close já eram ponteiros. Portanto não há evidência de truncamento do ponteiro como causa do crash. Faltavam declarações void completas, agora explícitas. A API foi confrontada com o [manual Lua 5.1](https://www.lua.org/manual/5.1/manual.html#3).

`luaopen_love` e `luaopen_love_graphics` têm assinatura de módulo `int(lua_State*)`. O host antigo não as chamava diretamente via ctypes: o carregamento ocorria pelo require Lua. Não é correto atribuir o crash a um restype padrão dessas funções nunca invocadas diretamente pelo Python. A assinatura gráfica está no [wrapper oficial 11.5](https://github.com/love2d/love/blob/11.5/src/modules/graphics/wrap_Graphics.cpp).

O problema observado envolvia finalização de componentes gráficos C++ em um host que não reproduzia o bootstrap oficial: configuração específica do LuaJIT, preload, flags, boot e execução por coroutine, além do ciclo de janela/contexto. O [entrypoint oficial 11.5](https://github.com/love2d/love/blob/11.5/src/love.cpp) conserva esse ciclo e depois chama lua_close. Sem uma stack nativa do crash, o destrutor/objeto exato responsável não está provado.

O caminho ativo não tenta consertar esse host por omissão de close ou por ignorar access violations: ele foi substituído por processos do runtime oficial. O entrypoint compatível `test_ui_embedded.py` apenas encaminha a `test_ui.py`; não carrega love.dll, SDL ou gráficos no Python. Os 100 ciclos headless aprovados testam a vinculação Lua isolada; não substituem a validação gráfica, que ainda falha antes da aplicação.
