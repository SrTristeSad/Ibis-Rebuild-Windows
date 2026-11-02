# A36 — Proporções da tela inicial (02/11/2026)

## Problema verificado
O artefato **IbisRebuild-Lua-Real-Screenshots** do workflow Windows
41519732599, commit 4d3538323, contém o PNG real \`00-inicial.png\`.
Nele o logotipo aparece com aproximadamente 215 px de largura no
viewport 1220×800, e os dois destinos ficam agrupados perto do centro.
O tamanho é muito menor do que a composição exibida na referência pública.

## Referência e limites
- Screenshot público de ibisPaint 14.0.2 citado na etapa A35:
  https://assets.st-note.com/img/1779886178-JX09jHZNQRwb5pfsm6Tn1Svk.png
- Tutorial oficial "Comece a criar uma obra de arte":
  https://ibispaint.com/lecture/index.jsp?lang=pt&no=03
- Alteração oficial 12.2.0 que removeu Coleção:
  https://ibispaint.com/newFeature.jsp
- \`docs/RESEARCH.md\` e \`docs/research/evidence-index.json\`:
  evidência derivada, **sem comparação dinâmica 14.1.2**.

A referência 14.0.2 NÃO comprova equivalência 1:1 com a versão 14.1.2.
A roda cromática e os pictogramas permanecem vetores próprios.

## Alterações
- \`app/ibis_home_screen.lua\`: marca dimensionada em função da
  viewport, mantendo proporções tipográficas e posicionamento central;
  círculos maiores e mais separados, com labels e áreas de clique
  sincronizados. Nenhuma fonte ou textura é recriada durante frames.
- \`tests/test_ibis_gallery_ui.lua\`: verifica geometria e separação
  em 960×640, 1220×800 e 1920×1080, inclusive ausência de hitbox
  no espaço vazio entre os destinos.
- \`app/main.lua\`, raster Lua, camadas, RBD2 e Windows Ink intactos.

## Validação
Executar workflow Linux e Windows do commit da A36 e inspecionar
o novo \`00-inicial.png\` publicado pelo LÖVE. Não considerar
a comparação visual final aprovada sem essas verificações.
