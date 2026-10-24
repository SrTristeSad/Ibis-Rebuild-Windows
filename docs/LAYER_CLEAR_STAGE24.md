# Etapa 24 — Limpar pixels da camada ativa

Continuação da Etapa 23 sem reiniciar o projeto e sem modificar o Inkora. Mantidos LuaJIT/LÖVE, a DLL raster C++ x64, o editor próprio, o histórico misto e o armazenamento RBD2.

## Interface e atalho

Na aba **Camadas**, o comando **Limpar** fica ao lado de **Mesclar ↓**, substituindo o cabeçalho passivo do painel nessa aba. O atalho **Shift+Delete** executa a mesma operação enquanto o editor está aberto e sem modal. A operação limpa **somente os pixels RGBA da camada ativa**; não remove a camada, não troca seu ID, nome, ordem, visibilidade nem opacidade e não toca nas camadas inferiores ou superiores.

A seleção e prévias de transformações são dispensadas somente quando a limpeza realmente muda pixels. Limpar uma camada transparente informa que não havia pixels a apagar, não cria uma entrada de histórico e não marca o documento como alterado novamente.

## Motor, histórico e persistência

`Layers:clearActive()` usa `Native.clear(buffer, 0)`, a função nativa C++ pré-existente, no buffer da camada selecionada. Antes da escrita, `beginEdit()` captura o estado RGBA. `finishEdit()` detecta alterações reais e registra **uma** ação raster no mesmo histórico cronológico de pinceladas, propriedades, exclusões, mesclagens e espelhamentos. `Ctrl+Z` restaura todos os bytes RGBA anteriores; `Ctrl+Y` reaplica o esvaziamento, respeitando o limite de 24 passos/48 MiB da sessão.

Salvar ou reabrir o projeto utiliza o RBD2 existente, sem migrações ou novos campos.

## Testes

`tests/test_layer_clear.lua`, executado pelo fluxo `tools/test_lua.py` com LuaJIT e a DLL real, cobre camada vazia (no-op), limpeza de pixels semitransparentes, isolamento, propriedades/IDs, histórico cronológico com renomeação, undo/redo e RBD2.

O autoteste gráfico `app/main.lua` também clica no botão real, testa Shift+Delete, desfaz/refaz e valida o arquivo salvo. Executar as rotas de CI Windows antes de mesclar com a `main`.

**Limitação:** limpeza integral da camada, não somente da seleção. Esta é uma implementação nativa própria; ainda não equivale à interface original do ibisPaint Android 14.1.2.
