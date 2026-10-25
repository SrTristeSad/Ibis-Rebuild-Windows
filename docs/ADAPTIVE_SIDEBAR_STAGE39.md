# Etapa 39 — Painel lateral Windows adaptável em 960 × 640

A interface desktop tinha parâmetros em posições verticais fixas (por exemplo, **Estabilizar** em torno de y=726), fora do limite visível ao usar a janela mínima de 960 × 640. A etapa 39 corrige a navegação sem reposicionar ou reimplementar as ações do editor, nem alterar o raster C++.

## Comportamento

- A área do painel lateral passa a ter seu próprio recorte: do cabeçalho inferior em y=64 até antes da barra de mensagens, em y=altura−48. Textos e botões fora dessa área não são desenhados nem podem receber cliques.
- Em janelas abaixo de 800 px de altura, as ações existentes utilizam um espaço lógico equivalente a pelo menos 800 px e ficam acessíveis por **rolagem independente**, sem alterar o canvas, a transformação da câmera, a seleção ou o histórico.
- Há indicador de rolagem e setas fixas de subir/descer na borda direita. A **roda do mouse** sobre o painel desloca a lista; fora dele mantém a navegação da tela. Os atalhos **PageUp / PageDown / Home / End** funcionam com o cursor sobre o painel.
- Os hitboxes dos botões são deslocados e recortados junto com a interface, inclusive quando estão parcialmente visíveis. Os controles deslizantes de diâmetro, opacidade, estabilização e tolerância recebem o movimento do ponteiro no sistema de coordenadas virtual sem converter os valores.
- Ao mudar de ferramenta, abrir um projeto ou redimensionar a janela, o deslocamento é zerado/limitado corretamente. No modo compacto e no modo foco, o painel desktop permanece oculto como antes.
- O uso original da roda do mouse sobre o painel de camadas nas janelas de pelo menos 800 px de altura permanece intacto.

## Testes

`app/sidebar_scroll.lua` é um módulo independente de LÖVE, com limites, recorte, mapeamento de ponteiro e indicador de scroll. `tests/test_sidebar_scroll.lua` verifica janelas de 640, 700, 799, 800, 900 e 1080 px de altura, alcance do controle Estabilizar, hitboxes parcial ou totalmente ocultos e separação do canvas.

O autoteste gráfico Windows redimensiona uma janela LÖVE real para **960 × 640**, navega pelas setas, usa o slider inferior, verifica que pixels da obra, camadas, histórico e flag de modificação permanecem intactos e restaura as dimensões originais.

A geração automatizada de imagens agora publica **sete screenshots** do aplicativo, incluindo `07-editor-960x640.png`, uma captura real do editor desktop com a parte inferior do painel visível após rolar. Os PNGs são gerados por `love.graphics.captureScreenshot`, não por mock visual ou render criado fora do aplicativo.

## Limites

A janela desktop Windows segue como implementação independente em Lua/LÖVE/C++ e não corresponde ainda, pixel a pixel ou em todas as funções, ao ibisPaint Android 14.1.2. A mudança não toca em Inkora, assets Android, no formato RBD2 ou no motor nativo de pintura.
