# A53 — Propriedades com tamanho do pincel na barra inferior

## Evidência visual

A barra principal do [tutorial oficial do ibisPaint](https://ibispaint.com/lecture/index.jsp?no=4)
identifica a terceira ação como **Properties**. Uma
[captura pública de edição no ibisPaint](https://cdn.ibispaint.com/movie/310/261/310261258/image310261258l.png)
mostra um pequeno disco com a medida **8.2** como indicador do tamanho
da ferramenta. A
[imagem promocional oficial do Windows](https://apps.microsoft.com/detail/9pfdf2zd4z4n)
([IMG-M04](pesuisar-base/02_ATLAS_VISUAL.md)) mostra elementos
semelhantes na barra, mas não informa a versão, escala, DPI nem
todos os detalhes dos estados.

**Limite:** a captura de edição pública não comprova uma build do
Windows específica. A53 adota a convenção do indicador numérico
de pincel, sem declarar fidelidade pixel a pixel à versão Windows alvo.

## Alteração implementada

- `app/ui_icons.lua`: novos `Icons.brushSizeLabel(diameter)` e
  `Icons.drawBrushSizeBadge(cx,cy,size,diameter,font)`. Produzem
  disco escuro com aro claro e valor central. O texto usa a fonte
  existente do editor; o resultado se ajusta para caber em 21 px.
- `app/main.lua`: quando a ferramenta ativa é **Pincel** ou
  **Borracha** e não existe uma categoria visual pendente, a terceira
  ação da barra inferior exibe o `A.brushDiameter` real.
  A hitbox, callback, posição e ação do botão continuam idênticos.
- Para outras ferramentas, permanece o glifo anterior
  `glyphs.properties` (sliders horizontais); assim não se sugere
  que o tamanho de pincel é relevante para um modo não compatível.
- `tests/test_ui_icons.lua`: verifica valor exibido (1, 24 e 256),
  rejeição de valores inválidos, tamanho do disco, balanceamento
  do estado gráfico LÖVE, texto e identidade do terceiro slot.

## Considerações técnicas

O rebuild atual usa **diâmetros inteiros de 1 a 256**, por isso não
replica valores fracionários como 8.2 da imagem; não inventa um motor
de diâmetro decimal. O círculo é uma renderização Lua/LÖVE do estado
vivo do editor, não um arquivo proprietário ou um SVG estático.

O código aproveita `Icons` e `A.fonts.micro` já presentes em
`drawEditor`; não introduz outro módulo capturado e preserva o
limite de 60 upvalues do LuaJIT que exigiu correção na A52.

Não muda camadas, cores, outros botões, raster, ferramenta ativa,
caneta Windows Ink, desfazer/refazer, RBD2 nem a `main`.

## Testes e limites

A suíte pura cobre limites e o desenho via `love.graphics` simulado.
Os testes de Linux, Windows, executável e capturas dependem dos
workflows do commit final. **CI verde valida regressão, não
equivalência 1:1 à versão Windows original.**

A PR #66 deve permanecer aberta em Draft, sem merge automático.
