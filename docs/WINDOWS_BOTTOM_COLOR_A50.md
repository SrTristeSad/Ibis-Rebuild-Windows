# A50 — Indicador circular de cor na barra inferior (Windows)

## Referência e decisão

A [captura do tutorial oficial de gestos e atalhos para Windows](https://ibispaint.com/lecture/index.jsp?no=167)
([IMG-W03](pesuisar-base/02_ATLAS_VISUAL.md)) mostra, na barra
inferior, um **indicador circular da cor atual**. Uma imagem promocional
da [Microsoft Store](https://apps.microsoft.com/detail/9pfdf2zd4z4n)
([IMG-M01](pesuisar-base/02_ATLAS_VISUAL.md)) também apresenta esse
disco. Nenhuma dessas fontes registra a versão alvo, a escala e as
métricas necessárias para cópia pixel a pixel.

Antes da A50, o rebuild usava uma representação abstrata de paleta
(três pontos dentro de um círculo), um retângulo adjacente e um segundo
quadrado colorido no canto do botão. Era uma escolha de ícone sem
correspondência clara com a referência PC.

## Implementação

- `app/ui_icons.lua`: substitui o glifo estático `color` pela forma
  de discos concêntricos. Acrescenta `Icons.colorSwatchGeometry` e
  `Icons.drawColorSwatch`; o disco interno usa canais RGB normalizados
  e o contorno fornece contraste para cores muito claras ou escuras.
- `app/main.lua`: o slot `color` chama o novo desenho com a seleção
  `A.color`; remove os dois retângulos duplicados. A cor exibida passa
  a ser a **cor selecionada no motor**, mantendo os mesmos callbacks.
- `tests/test_ui_icons.lua`: verifica forma estática, limites do
  disco dentro do botão de 21px, sequência de desenho, valores RGB,
  centralização e rejeição de canais inválidos.

O botão continua abrindo o painel HSB. Não altera o **alfa do pincel**,
gerido separadamente pela barra de opacidade, nem a geometria do
`Compact.toolbar`. IDs, atalhos, hitboxes, camadas, histórico,
rasterização, Windows Ink e RBD2 não mudaram.

## Por que não um SVG pronto nesta etapa

Um disco colorido é um **indicador de estado**, não um símbolo fixo:
SVGs genéricos de paleta e conta-gotas não mostram automaticamente a
cor selecionada. Usamos desenho dinâmico LÖVE do próprio componente.
Para ferramentas estáticas, a estratégia A49 de comparar bibliotecas
abertas e registrar atribuição continua válida.

## Limites e validação

- O círculo e a borda são uma aproximação fundamentada no Windows,
  **não uma medição pixel a pixel** da versão alvo.
- O teste puro com `love.graphics` simulado verifica chamadas e RGB;
  testes do CI Windows/LÖVE verificam a execução e capturas de regressão
  quando disponíveis. Não inferir fidelidade visual apenas do CI.
- Outros ícones e posições da barra inferior permanecem intocados.
- PR #66 deve permanecer **Draft**, sem merge na `main`.
