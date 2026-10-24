# Etapa 22 — Mesclar camada abaixo (Ctrl+E)

Continuação incremental do Ibis Rebuild Windows x64 independente. O projeto mantém LuaJIT/LÖVE 11.5, raster C++ nativo, camadas RBD2 e histórico unificado da Etapa 21. Não modifica o Inkora nem utiliza dados extraídos do aplicativo Android.

## Operação no editor

No painel **Camadas**, escolha uma camada acima da camada de base e pressione **Mesclar ↓** ou **Ctrl+E**. O conteúdo visual da camada selecionada é composto sobre a camada imediatamente inferior, respeitando a visibilidade e a opacidade de ambas. A camada superior deixa de existir na estrutura e a inferior permanece selecionada com o mesmo ID e nome; o resultado utiliza opacidade de camada 100%, pois a transparência das fontes já foi incorporada ao raster.

A mesclagem utiliza exclusivamente a API de **composição source-over RGBA nativa C++** já empregada pelo editor para exibir as camadas. Se uma camada estiver oculta ou com opacidade zero, ela não contribui com pixels visíveis. É importante distinguir isso de uma transformação sem perda: o conteúdo oculto da fonte deixa de existir no arquivo mesclado, embora possa ser restaurado via **Ctrl+Z** durante a sessão.

O limite de oito camadas não muda. A operação reduz o número de camadas em uma unidade e não pode ser executada sobre a primeira camada. Clicar no botão quando desabilitado não modifica os pixels, os metadados ou o histórico.

## Histórico e persistência

A mesclagem cria **uma etapa estrutural** no histórico unificado. **Ctrl+Z** restitui ambas as camadas com os bytes RGBA8, ID, nome, opacidade, visibilidade, ordem e seleção originais. **Ctrl+Y** recompõe deterministicamente os mesmos pixels mesclados e remove novamente a camada superior.

Para caber no orçamento da sessão, o histórico armazena somente os dois buffers fonte e metadados necessários, **não uma terceira cópia integral** do resultado mesclado. O limite anterior de **24 operações e 48 MiB** continua válido; no máximo de 2048×2048, os dois buffers RGBA8 custam aproximadamente 32 MiB. O algoritmo de composição normal usa arredondamentos de 8 bits em cada etapa; podem ocorrer diferenças de até poucos valores por canal quando se compara composição em múltiplas camadas contra um raster já achatado. Não se reivindica identidade matemática perfeita para qualquer sequência de sobreposições.

Salvar o projeto gera o mesmo **RBD2** anterior, agora com uma camada a menos e pixels mesclados. A linha do tempo da sessão não é incluída no RBD2. Depois de fechar e reabrir o arquivo, não é possível usar Ctrl+Z para recuperar as camadas fontes, porque o projeto passa a conter apenas o resultado salvo.

## Verificação

`tests/test_merge_down.lua` executa LuaJIT e DLL C++ reais. Confere source-over e alfa, restauração independente dos dois buffers, IDs e opacidades via undo, recomposição via redo, persistência RBD2, fontes ocultas, bloqueio da primeira camada, ramificação divergente e capacidade máxima de oito camadas.

O autoteste GUI LÖVE clica no botão real de mesclagem, usa desfazer/refazer, verifica restauração de bytes e miniaturas, salva e reabre RBD2 e aciona Ctrl+E. O CI exige a aprovação dos testes nativos e das rotas Windows empacotada e oficial.

O recurso é implementação própria. Não afirma equivalência completa à mesclagem de camadas do ibisPaint Android 14.1.2.
