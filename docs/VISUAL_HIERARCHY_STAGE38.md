# Etapa 38 — Refinamento da hierarquia visual do editor Windows

Ajustes orientados pelas capturas **reais** da Etapa 37, sem inventar uma tela de demonstração alternativa. O app continua independente, feito em Lua/LÖVE e núcleo nativo C++.

## Galeria

- Cartões ampliados de **212 × 148 para 212 × 210 px**, mantendo a posição e as dimensões horizontais de clique dos cartões anteriores. O novo espaçamento vertical de 236 px impede sobreposição entre linhas.
- Miniaturas RGBA exibidas na área **176 × 126 px**, no lugar da área 176 × 74 px. Desenhos quadrados agora podem utilizar 126 × 126 pixels de prévia sem distorção, preservando o padrão quadriculado da transparência.
- Nomes e dimensões foram separados abaixo da arte, com espaçamento próprio e indicação de foco por hover. A quantidade de cartões por linha permanece proporcional à largura da janela.
- A geração de no máximo uma prévia nativa por frame, o cache limitado e as chaves por projeto/revisão da Etapa 37 continuam em vigor. O desenho e o histórico não são alterados pelas miniaturas.

## Editor

- A fila de ferramentas desktop recebeu um agrupamento discreto, com títulos abreviados como **Ver**, **Pincel**, **Seleção** e **Pipeta**, para não ultrapassarem botões estreitos. As funções e os hitboxes originais não mudaram.
- Todos os textos de botões passam por recorte medido com a fonte LÖVE: se não couberem, recebem reticências em vez de quebrar em linhas inesperadas.
- O cabeçalho exibe o **nome do projeto aberto** no lugar do texto genérico Área de desenho, com largura limitada para não invadir os botões de layout/visualização.
- O painel lateral destaca a identidade do projeto e apresenta título contextual **Projeto e pincel** quando a aba de pincéis está ativa, sem alterar a localização das ações.
- Na barra compacta, uma pequena faixa de cor e o nome da ferramenta ativa reforçam a hierarquia entre o painel de controles de tamanho/opacidade e os sete botões da faixa inferior. O botão ativo ganha uma marca visual inferior. O mapeamento de mouse, toque e Windows Ink foi preservado.

## Validação

O novo módulo `app/visual_hierarchy.lua` centraliza medidas e nomes curtos sem invadir o estado do editor. O teste `tests/test_visual_hierarchy.lua` exercita o layout em 960 × 640, 1220 × 800 e 1920 × 1080, posicionamento e limites de cartões, cabeçalho, textos e preservação dos canais RGBA em prévias quadradas/amplas.

O CI continua a executar LuaJIT, C++, autoteste gráfico de LÖVE, produção de seis capturas PNG reais da interface Windows, criação do executável offline e conferência do pacote.

**Limites:** as capturas são do programa Windows independente e não comprovam fidelidade 1:1 ao ibisPaint Android 14.1.2. Não foram alterados o C++ raster, o formato RBD2, os assets Android nem o projeto Inkora.
