# Etapa 41 — Opacidade de camadas com precisão de 1%

A janela compacta de camadas do editor Windows agora possui uma barra contínua de **0% a 100%, em passos de 1%**, na parte inferior do popover. Os botões existentes de menos/mais 10%, seleção, visibilidade, duplicação, mesclagem e exclusão foram preservados.

## Funcionamento

- Clique ou arraste na barra para definir a opacidade da camada selecionada com precisão de 1%.
- Durante o arraste, o valor numérico e o indicador da barra mudam imediatamente, mas **o raster, a composição e o histórico permanecem intactos**.
- Ao soltar o mouse, a opacidade é aplicada pela API `Layers:setOpacity` existente; ela recompõe o RGBA nativo e registra **uma única entrada de metadados no histórico**, mesmo após dezenas de movimentos do ponteiro.
- Ctrl+Z e Ctrl+Y recuperam/reaplicam exatamente o mesmo valor. Se o arraste não alterar o valor, nenhuma entrada é gravada.
- Se a janela perder foco, o rascunho é cancelado. Ao fechar o painel com Esc, nenhuma mudança pendente permanece.
- O layout é calculado por `app/compact_layer_opacity.lua`, que não acessa arquivos, rasterizadores ou UI e mantém a barra fora dos controles de menos/mais e da lista de camadas.

## Validação

`tests/test_compact_layer_opacity.lua` testa os limites, o valor exato de 37%, o não conflito com hitboxes em 960×640, 1220×800 e 1920×1080, a monotonicidade de 0 a 100, a diferenciação entre edição de rascunho e confirmação, e a rejeição de valores inválidos.

O autoteste gráfico LÖVE abre o painel pelo botão real, arrasta o cursor por vários valores, verifica que composição nativa e histórico ficam estáticos durante a manipulação, aplica 37% em uma operação, testa desfazer/refazer e restaura a obra original.

O CI Windows passa a publicar **nove capturas reais**, incluindo `09-opacidade-camadas.png`, que mostra duas camadas e a barra em 37%.

## Escopo e limites

Não foram modificados o motor de pintura C++, o formato RBD2, os assets Android, o projeto Inkora ou os dados dos usuários. Isto não constitui equivalência 1:1 ao ibisPaint Android 14.1.2.
