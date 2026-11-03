# A40 — ajustes rápidos de espessura e opacidade no editor

Data: 02/11/2026. Branch: `migration/lua-only-engine`.

## Evidências e limites
- Captura real da A39: `02-editor-compacto.png` do CI Windows
  41565760761. Os trilhos anteriores usavam preenchimento azul,
  pequenos thumbs e textos dispersos.
- Tutorial do fabricante sobre controles de pincel, espessura e opacidade:
  https://ibispaint.com/lecture/index.jsp?no=118
- Histórico oficial: correção do desalinhamento entre barra de
  espessura e opacidade no ibisPaint 13.0.8:
  https://ibispaint.com/historyAndRights.jsp?newsID=179937995
- Exemplo público anterior de interface, barras com botões menos/mais:
  https://cms.dmpcdn.com/ugcarticle/2020/05/27/2c48a130-be4d-11ed-97ab-8dda0175ea4b_original.jpg
- Fonte derivada da versão Android 14.1.2:
  `docs/RESEARCH.md`, `docs/research/evidence-index.json`.
  **Não** há screenshot Android 14.1.2 autenticada na conversa.

## Implementação A40
- `app/compact_layout.lua`: geometria central para duas barras
  com trilhos alinhados, rótulos/valores e círculos menos/mais.
  Hit-test exclusivo dos botões, sem interceptar o arrasto.
- `app/main.lua`: aparência de trilho neutro com marcador branco;
  textura xadrez no trilho de opacidade, indicando transparência.
  Clique nos botões ajusta os parâmetros reais do pincel/borracha
  sem registrar ação no raster ou criar história.
- `tests/test_compact_visual.lua`: limites, incrementos (1 px e
  1% de opacidade), geometria e separação de slider, botões e
  dock em 960x640, 1220x800 e 1920x1080.

## Limites explícitos
A faixa preserva o comportamento próprio do rebuild: espessura
entre 1 e 256 px e opacidade de 10% a 100%. Isto NÃO é garantia
de equivalência com os limites ou curvas do ibisPaint original.
As miniaturas e os motores de pincel, RBD2, camadas, histórico e
Windows Ink permanecem intactos. A PR #66 fica em Draft;
nenhuma alteração na branch `main`.

Verificar CI Linux/Windows e **capturas reais do LÖVE** antes de
aprovar a fase.

## Validação real adicional

O teste `--lua-gui-smoke` do Windows agora utiliza eventos reais de
mouse do LÖVE para acionar os quatro botões, confere os incrementos
1 px / 1% e restaura o estado inicial. Também compara os bytes da
composição e as estatísticas de undo antes e depois dos cliques.
