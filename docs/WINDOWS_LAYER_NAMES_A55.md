# A55 — Nomes de camadas legíveis no painel flutuante

## Problema e referência

A captura real da A53 (`47-janela-camadas.png` no artefato
`IbisRebuild-Lua-Real-Screenshots`, workflow
[41687351944](https://github.com/SrTristeSad/Ibis-Rebuild-Windows/actions/runs/41687351944))
mostra que cada linha de camada reserva espaços distintos para
miniatura, índice, **nome**, modo de mesclagem, opacidade e
visibilidade. Os tutoriais oficiais sobre
[Layer Window Details](https://ibispaint.com/lecture/index.jsp?no=156)
mostram a mesma organização funcional; a imagem não comprova
dimensões exatas da versão Windows em uso.

Antes da A55, `ibis_layer_chrome.lua` chamava
`love.graphics.printf(name,...,'left')` com largura limitada,
mas sem limitar o **número de linhas**. Nomes extensos poderiam
quebrar sobre o modo `Normal`, a porcentagem de opacidade e os
controles inferiores da linha, enquanto o texto continuava inteiro
no documento. Isso é um problema de layout, mesmo quando não aparece
na captura com nomes curtos.

## Implementação

- `app/ibis_layer_chrome.lua`: nova função
  `rowName(name,width,measure)`, reutilizando
  `app/text_fit.lua` para truncamento seguro de caracteres UTF-8
  pela **largura real da fonte**. Quebras de linha e tabulações são
  exibidas como espaços somente na representação.
- `LayerChrome.label`: usa `love.graphics.print` com uma única
  linha já medida, em vez de `printf`, preservando os mesmos
  alinhamentos, índice, modo `Normal` e porcentagem.
- `tests/test_ibis_layer_chrome.lua`: cobre nomes curtos, longos,
  acentuados, com quebras, alinhamento, largura útil antes do botão
  Visibilidade, posição da opacidade e renderização LÖVE simulada.

**O nome original permanece intacto** no projeto, na caixa de
renomear, nas camadas, no undo e no formato RBD2. A mudança é
exclusivamente de apresentação e não altera a área clicável,
posição da janela, ordem das camadas ou interação do mouse.

## Limites e continuidade

O painel atual ainda é uma janela compacta de posição e tamanho
definidos pelo rebuild. O
[manual oficial](https://ibispaint.com/lecture/index.jsp?no=156)
informa que a janela flutuante de camadas em PC/tablet pode ser movida
e redimensionada. Essa interação **não é implementada aqui**;
precisa de escopo e testes próprios, sem fingir que já funciona.

A55 não introduz assets nem usa ícones proprietários; é independente
de versão, DPI, idioma ou escala. CI valida a correção de layout e o
aplicativo, não paridade visual pixel a pixel com o ibisPaint Windows.

Manter PR #66 em **Draft** e `main` inalterada.
