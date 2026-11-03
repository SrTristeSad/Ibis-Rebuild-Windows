# A43 — Atalhos de espessura do ibisPaint para Windows

## Referência oficial verificada

- [Gestures, Keyboard Shortcuts (Windows Version)](https://ibispaint.com/lecture/index.jsp?no=167)
- [Novidades 11.1.0 — atalhos e gestos no PC](https://ibispaint.com/newFeature.jsp)
- [Notas oficiais 11.1.0 de 11/12/2023](https://ibispaint.com/information.jsp?newsID=85228092)

Confirmado: **Ctrl+Alt+arrastar com botão esquerdo** ajusta
o tamanho do pincel, inclusive com caneta; **[ e ]** diminuem
ou aumentam a espessura. Trata-se de comportamento do PC
comprovado, não reconstrução visual inferida do Android.

## Implementação específica A43

- \`app/ibis_windows_brush_size.lua\`: aritmética pura para
  arrasto relativo e degrau com limites do motor atual 1..256.
  Sensibilidade própria de 4 pontos de movimento por 1 px
  de diâmetro, **não** declarada idêntica à curva oficial.
- \`app/main.lua\`: se Ctrl e Alt estão pressionados ao
  clicar com o esquerdo sobre o documento usando pincel/borracha,
  inicia ajuste de parâmetro em vez de pintura, desde que
  nenhum painel/modal/menu/control esteja sendo usado.
  Arrasto utiliza posição X absoluta e origem fixa. Soltura
  conclui sem invocar pintura nem histórico. Esc cancela e
  restaura espessura inicial; perda de foco cancela o gesto.
- \`[\` e \`]\` atualizam espessura em 1 px, fora de campos,
  bibliotecas e painéis, respeitando os limites.
- O pan existente por Espaço+arrasto e botão do meio,
  conta-gotas direito A42, Windows Ink e todo raster são
  preservados. Nenhuma UI nova foi inventada.

## Validação

- \`tests/test_ibis_windows_brush_size.lua\`: monotonicidade,
  retorno à origem, arrasto reverso, limites, atalhos e
  entrada inválida, sem LÖVE.
- Linux CI: suite LuaJIT dedicada.
- Windows CI: suite no executor e smoke GUI com
  \`love.keypressed\`, \`love.mousepressed/mousemoved/mousereleased\`.
  O runner **simula Ctrl+Alt na consulta isDown**, pois não
  possui teclado físico; os eventos de mouse e render são
  executados pelo LÖVE 11.5 real.
- Smoke verifica exclusão de popup, nenhum stroke/pan,
  nenhum byte RGBA, undo ou dirty modificado, e restauração
  do diâmetro para a próxima fixture.

## Limites / status

Não valida caneta física nem sensibilidade pixel-a-pixel do
ibisPaint Windows original, que exigirá original instalado
e referência em mesma resolução/DPI. PR #66 permanece Draft.
