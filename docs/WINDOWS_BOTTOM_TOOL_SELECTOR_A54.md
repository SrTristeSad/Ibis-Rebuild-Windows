# A54 — Diferenciação visual do seletor de ferramentas inferior

## Problema observado na captura real do rebuild

O workflow Windows/LÖVE da A53 publicou capturas reais
([execução 41687351944](https://github.com/SrTristeSad/Ibis-Rebuild-Windows/actions/runs/41687351944),
artefato `IbisRebuild-Lua-Real-Screenshots`).
A imagem `02-editor-compacto.png` mostrou o primeiro botão
(Pincel/Borracha) e o segundo (seletor de ferramentas) com a
**mesma silhueta de pincel**, sem indicação visual da diferença
de função. A A52 associou corretamente o glifo da ferramenta ativa
ao seletor, mas não separou os dois controles visualmente.

A captura `IMG-W03` do
[atlas Windows](pesuisar-base/02_ATLAS_VISUAL.md#img-w03--abrir-configurações-e-lista-de-atalhos-no-windows-pc-oficial)
mostra um controle circular escuro na barra inferior. Ela apoia o
vocabulário visual de discos escuros usado neste estágio, mas não
identifica detalhadamente o desenho, o diâmetro ou o estado do
seletor em todas as versões do ibisPaint Windows. A54 é uma
**adaptação de usabilidade**, não um decalque pixel a pixel.

## Implementação

- `app/ui_icons.lua`: adiciona `Icons.toolSelectorGeometry` para
  centralizar e limitar um disco escuro, um glifo reduzido e uma
  pequena marca triangular de menu.
- `Icons.drawToolSelector` continua resolvendo o glifo pelo catálogo
  A52, mas desenha um fundo circular e um aro antes de traçar a
  ferramenta ativa (65% da escala anterior). A pequena marca no
  canto inferior direito indica que o botão abre um seletor.
- O primeiro botão continua mostrando o Pincel ou a Borracha em
  tamanho normal; portanto, os dois já não parecem idênticos.
- `tests/test_ibis_visual_tools.lua`: verifica os limites da
  geometria, o contraste, a ordem de desenho (disco, aro, glifo e
  indicador), o estado gráfico LÖVE e a preservação da barra.

## Continuidade

Nenhum SVG ou sprite novo foi incluído: os símbolos vêm do
registro `app/ui_icons.lua`, incluindo as adaptações abertas
já creditadas em [A49](OPEN_ICON_SOURCES_A49.md).
O desenho usa apenas primitivas do LÖVE.

`app/main.lua`, `Compact.toolbar`, callbacks, hitboxes,
a lista de 15 ferramentas, a seleção de motor, os controles de
cor e tamanho, Windows Ink, histórico, RBD2 e a `main` ficam
intocados. A função longa `drawEditor` não ganha upvalues, evitando
a regressão LuaJIT identificada na A52.

## Validação e limites

A suíte Lua verifica contratos geométricos e as chamadas de desenho;
os workflows Linux e Windows devem confirmar a compilação e as
capturas finais. O teste estrutural não prova que a estética coincide
exatamente com uma versão instalada do ibisPaint. Manter PR #66 em
Draft, sem merge automático.
