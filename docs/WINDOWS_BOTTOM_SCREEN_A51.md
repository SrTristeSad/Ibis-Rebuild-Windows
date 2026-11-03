# A51 — Botão Tela com seta para baixo na barra inferior Windows

## Evidência visual

A [imagem oficial do ibisPaint Windows na Microsoft Store](https://apps.microsoft.com/detail/9pfdf2zd4z4n)
([IMG-M04](pesuisar-base/02_ATLAS_VISUAL.md)) mostra na barra
inferior uma seta vertical apontando para baixo entre o controle de
cor e os comandos de desfazer/refazer. Esta silhueta também aparece
na captura da [janela de pincéis](https://store-images.s-microsoft.com/image/apps.62782.14202576542330599.5d8d33ef-6e70-4d7f-953d-99930bb9592a.91fbe5d5-ba54-4efc-92b2-f5f6b5059862).

O [tutorial oficial de ferramentas](https://ibispaint.com/lecture/index.jsp?no=4)
identifica a quinta ação da barra principal como **Fullscreen View**.
A versão do rebuild até A50 desenhava quatro cantos de enquadramento
(`fullscreen`); a A51 muda só o desenho para a seta indicada na
referência Windows. Não é medição exata de tamanho, cor, espaçamento
ou estados alternativos, pois a referência é promocional, com versão
e DPI não anotados.

## Fonte livre e adaptação

- Biblioteca: [Tabler Icons](https://github.com/tabler/tabler-icons)
- Ícone: [arrow-down.svg](https://github.com/tabler/tabler-icons/blob/main/icons/outline/arrow-down.svg)
- Licença: **MIT**, (c) 2020–2026 Paweł Kuna. O texto integral
  da licença de Tabler está preservado no repositório em
  [A49](OPEN_ICON_SOURCES_A49.md#licença-mit--tabler-icons).

Os caminhos de seta do SVG original, projetados em uma grade 24x24,
foram convertidos para dois segmentos `line` no sistema normalizado
de `app/ui_icons.lua`. Os comandos são renderizados por LÖVE
sem runtime SVG ou uso de assets proprietários do ibisPaint.

## Escopo

- `app/ui_icons.lua`: substitui apenas `glyphs.fullscreen`.
- `tests/test_ui_icons.lua`: garante haste vertical, ponta inferior
  em V, limites normalizados e o mesmo ID no quinto slot.
- `app/main.lua`, `app/compact_layout.lua`, callbacks,
  posições, tamanhos, controles, motor Lua, Windows Ink,
  pixels RGBA, histórico e RBD2 **não mudaram**.

## Teste e critérios de aceite

O teste estrutural deve passar nas suítes Lua e os workflows
Windows/LÖVE devem terminar aprovados. A captura visual do
rebuild deverá ser inspecionada, mas CI verde sozinho não comprova
fidelidade pixel a pixel com o app original.

Os outros glifos inferiores (principalmente Ferramentas e Ajustes)
continuam sob avaliação. Não alterar seus desenhos só por preferência
estética: requer comparação justificável com a versão Windows.
Manter a PR #66 em Draft e não mesclar na main.
