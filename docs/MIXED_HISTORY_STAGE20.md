# Etapa 20 — Histórico misto de pintura e camadas

Esta etapa continua o projeto Ibis Rebuild Windows independente no mesmo repositório, preservando LuaJIT/LÖVE, o núcleo raster C++ e o formato RBD2. Não altera Inkora nem usa recursos Android extraídos.

## O que Ctrl+Z e Ctrl+Y fazem agora

O editor possui **uma sequência cronológica de alterações**, incluindo tanto edições de pixels quanto as quatro operações estruturais principais: **adicionar, duplicar, excluir e reordenar camadas**. Cada comando cria um único passo na mesma pilha; o usuário pode desfazer uma pintura, desfazer a duplicação anterior e depois refazer ambas, mantendo ordem e identidade das camadas.

O sistema restaura o identificador persistente, posição, propriedades (nome, visibilidade e opacidade), seleção ativa e conteúdo RGBA da camada estruturalmente adicionada/removida. Duplicar usa uma nova identidade e uma nova alocação; desfazer remove a cópia e refazer recria o mesmo ID, com os pixels que ela tinha no instante da duplicação. Excluir preserva os bytes originais da camada removida para restauração. Reordenar registra apenas as posições anterior e posterior, sem copiar grandes imagens.

O histórico de pintura continua ligado ao ID persistente da camada e mantém o controle de uma única entrada por arraste, forma ou transformação. Operações novas depois de desfazer descartam o ramo de refazer. Tentativas inválidas ou sem efeito, como mover uma camada para o mesmo índice, não devem criar novos passos. Os botões da interface, atalhos Ctrl+Z/Y e miniaturas existentes usam o mesmo motor. O cache das miniaturas é recriado com segurança após alterações estruturais desfeitas/refeitas.

## Memória, arquivos e limites

As pilhas permanecem em memória durante a sessão do editor, limitadas a **24 operações e 48 MiB** (valores anteriores). Em vez de copiar todas as camadas a cada ação, as entradas estruturais armazenam apenas o buffer RGBA da camada afetada e alguns metadados, ou somente os índices quando a ordem muda. Assim, o mecanismo evita um aumento de memória proporcional ao número total de camadas por operação.

O formato **RBD2** não é modificado; salva a composição atual de camadas, mas não grava a linha do tempo de desfazer/refazer, assim como nas etapas anteriores. Reabrir um projeto continua iniciando um histórico de sessão vazio. O limite de oito camadas permanece. A duplicação, exclusão e reordenação podem ser desfeitas sem descartar automaticamente todas as pinceladas anteriores.

**Limitação:** nesta etapa, alteração de visibilidade ou opacidade ainda reinicia o histórico em memória conforme o comportamento antigo, e renomear mantém seu funcionamento de metadados fora da linha do tempo. A próxima evolução pode incorporar também essas propriedades, sem comprometer o formato RBD2. Não se alega equivalência com o histórico interno do ibisPaint Android 14.1.2.

## Testes

- `tests/test_structural_history.lua`: sequência pintura → adicionar → pintar → duplicar → pintar → mover → excluir; desfazer e refazer todos os sete passos; verifica IDs, ordem, seleção, alocação de pixels independente, composição, ramos divergentes, invalidação de redo, rejeição atômica ao atingir oito camadas, teto de memória e persistência RBD2.
- `tests/test_edit_history.lua` e `tests/test_layer_duplicate.lua`: expectativas anteriores atualizadas para considerar operações estruturais reversíveis.
- Autoteste de interface LÖVE: botões reais de Duplicar e Excluir, controles de desfazer/refazer, restauração do mesmo ID, atualização de miniaturas, mover camada e reabrir RBD2 após restaurar a estrutura. Testes em ambas as rotas Windows, empacotada e LÖVE oficial.
