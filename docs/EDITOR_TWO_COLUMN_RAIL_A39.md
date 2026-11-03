# Fase A39 — seletor lateral de ferramentas em duas colunas

## Evidência e diferença concreta
- Tutorial oficial ibisPaint, capítulo 03 — Toolbar and Tool Selection:
  https://ibispaint.com/lecture/index.jsp?no=4
- Imagem oficial da ferramenta selecionada:
  https://ibispaint.com/img/lecture/common/chapter_04_02.png
- Referências derivadas do APK Android 14.1.2:
  `docs/RESEARCH.md` e `docs/research/evidence-index.json`
  (sem screenshot de execução autenticada do Android).

A captura real LÖVE da A38 `02-editor-compacto.png` exibia uma
coluna estreita de **15 ferramentas**, do alto até quase o rodapé.
A captura pública oficial exibe a lista de 15 ferramentas distribuída
em **duas colunas**, com a mesma ordem que o catálogo do rebuild.

## Alterações
- `app/ibis_editor_rail.lua`: 136 px, 2 colunas de 64 px, margem
  interna de 2 px, entrecolunas de 4 px e 43 px por fileira.
  As 15 ferramentas ocupam oito fileiras, na mesma ordem e com as
  mesmas IDs/callbacks. Posição esquerda e direita preservadas.
  A paginação continua disponível para catálogos maiores.
- `app/main.lua`: desenho/ícone/rótulo e fundo calculados a partir
  das fileiras reais. O fundo agora possui uma hitbox **visível**
  de consumo que antecede os botões (despachados por ordem reversa);
  cliques nos pequenos espaços entre células não chegam ao pincel.
  Showcase da posição direita ajustado à largura de duas colunas.
  O modo Popup não desenha nem registra a faixa.
- `tests/test_ibis_editor_rail.lua`: geometria e cobertura das 15
  ferramentas em 960x640, 1220x800 e 1920x1080; ausência de item
  invisível na última célula; paginação de 43 itens; segurança das
  barras superior/inferior; preservação das três posições.

## Critérios de conclusão
Compilação LuaJIT, testes Linux/Windows e captura real do LÖVE
devem passar. A comparação visual mostra apenas **aproximação da
estrutura** da referência pública, NÃO equivalência pixel a pixel
Android 14.1.2. Pincéis, RBD2, camadas, históricos e Windows Ink
não são alterados. PR #66 permanece draft e `main` intacta.

## Revisão A39 — conflito com F10 identificado pelo smoke Windows

A faixa dupla ocupa a região onde o HUD Windows F10 aparece.
O modo F10 **oculta temporariamente a faixa e todas suas hitboxes**,
reexibindo-a ao fechar o painel. O teste LÖVE de F10 diferencia
hitboxes exatas dos comandos auxiliares dos botões da faixa,
verifica que não coexistem e confirma que o seletor volta ao fechar.
