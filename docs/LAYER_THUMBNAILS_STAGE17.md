# Etapa 17 — Miniaturas RGBA e navegação do painel de camadas

Continuação incremental do Ibis Rebuild Windows x64, sobre a Etapa 16. O aplicativo continua independente, usando LuaJIT/LÖVE 11.5, núcleo raster C++ e RBD2. Não modifica Inkora, não troca o motor raster e não usa imagens extraídas do APK original.

## Melhorias visuais e de interação

O painel **Camadas** exibe agora, à esquerda de cada camada, uma **miniatura real da imagem daquela camada**, obtida diretamente de seu buffer RGBA8 nativo. A miniatura preserva transparência, proporção e a cor de cada pixel amostrado. Ao lado permanecem nome, índice, indicação visível/oculta e destaque da camada ativa; clicar em qualquer parte da linha continua selecionando aquela camada.

Duas pequenas setas no cabeçalho permitem percorrer a lista quando o número de camadas excede a altura disponível. Com janela 1220×800 aparecem até **cinco linhas**; com janela mínima 960×640 permanece **uma linha utilizável**, sem sobrepor os comandos de visibilidade, reordenação ou opacidade do rodapé. Os botões de adicionar, excluir, mostrar/ocultar e mover camadas são preservados. A roda sobre o painel ainda pode alternar a camada ativa, como antes.

## Estratégia de renderização

O módulo `app/layer_thumbnails.lua` realiza amostragem limitada de, no máximo, **28×28 pixels** diretamente de `Native.buffer.bytes`, sem converter a imagem original inteira para bytes Lua. A amostragem é feita por pixel mais próximo, com preenchimento transparente para conservar a proporção de telas retangulares.

O editor mantém em cache **uma pequena textura LÖVE por camada**, identificada pelo ID persistente da camada. A textura é reconstruída quando o raster da camada ativa é alterado, incluindo pintura e desfazer/refazer. Alterar apenas a camada selecionada, sem mudar pixels, não obriga reconstruir todas as miniaturas. As texturas descartadas são liberadas ao substituir, excluir camadas, trocar de projeto ou encerrar. O cache não entra no arquivo RBD2, e a amostragem não escreve nem um único byte no raster.

A lista é calculada por funções puras que delimitam quantas linhas cabem acima do rodapé e quais camadas ficam visíveis. Os limites de oito camadas e de dimensões do projeto não foram alterados.

## Validação

`tests/test_layer_thumbnails.lua` usa buffers da DLL C++ real para conferir RGBA, alfa parcial, preenchimento transparente, preservação de proporção, amostragem limitada, imutabilidade da fonte, limites da janela e paginação com oito camadas.

O autoteste gráfico real do LÖVE verifica a miniatura renderizada, reutilização de textura em cache, invalidação após pintura, substituição após desfazer, comandos de paginação e seleção de camada pelo clique na linha. O workflow Windows exige aprovação em ambas as rotas de execução (executável empacotado e fontes pelo LÖVE oficial).

**Limitação:** estas são miniaturas discretas e independentes, não uma reprodução certificada dos painéis ou algoritmos de redução de imagem do ibisPaint Android 14.1.2. Não há máscaras, grupos, modos avançados de mesclagem nem pré-visualizações vetoriais nesta etapa.
