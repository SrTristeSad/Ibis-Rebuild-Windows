# A41 — Barra principal inferior compacta

## Evidência e limites

Referência primária: tutorial oficial, capítulo 03 — [Toolbar and Tool Selection](https://ibispaint.com/lecture/index.jsp?no=4), que documenta nove ações na barra principal, nesta ordem: Brush/Eraser, Tools, Properties, Color, Fullscreen, Undo, Redo, Layers, Back.

Imagem principal no tutorial: `https://ibispaint.com/img/lecture/common/chapter_04_01.png`.

O screenshot real A40 `02-editor-compacto.png` (LÖVE no CI Windows) mostra um bloco de seleção azul de 68×46 px e uma segunda linha de 704 px sobre o rodapé. A referência pública contém uma barra escura contínua, com ícones menores e destaque contido em torno do ícone, não uma placa grande.

**Não foi recuperada captura autenticada do Android 14.1.2.** As mudanças são aproximações estruturais fundamentadas em tutorial público, e não calibração 1:1.

## Implementação

- `app/compact_layout.lua`: nove slots, cada um com 60×44 px, separados por 5 px. Centralizados, com margem vertical de 8 px dentro da faixa de 60 px. A moldura de seleção tem 36×36 px e é desenhada *dentro* do slot clicável. A ordem/IDs permanecem iguais.
- `app/main.lua`: deixa apenas a divisória existente de largura total; remove a linha central artificial de 704 px. Troca o retângulo azul grande por moldura azul discreta em torno do ícone; preserva estado hover/disabled. Renderiza glifos originais vetoriais a 21 px. Não altera a rotina de dispatch nem callbacks.
- `tests/test_compact_layout.lua` e `tests/test_compact_visual.lua`: geometria, alinhamento, centralização e correspondência hitbox/moldura em 960×640, 1220×800 e 1920×1080.

## Não modificado

Motor raster Lua, composição, RBD2, Undo/Redo, camadas, Windows Ink, configuração do seletor, tela inicial e galeria. O modo Desktop continua independente. PR #66 permanece Draft, `main` intocada.

## Critério de validação

CI Linux LuaJIT e Windows LÖVE precisam passar; gerar capturas reais e confrontar imagens do mesmo estado em A40/A41. Testes passando não atestam equivalência de interface com o ibisPaint X 14.1.2.
