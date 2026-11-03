# A48 — Silhueta do botão Camadas na barra inferior

## Evidência e decisão

Referência: [IMG-M04 do atlas](pesuisar-base/02_ATLAS_VISUAL.md),
imagem promocional oficial do [ibisPaint Windows na Microsoft Store](https://apps.microsoft.com/detail/9pfdf2zd4z4n).
Na barra inferior, Camadas apresenta três folhas deslocadas para baixo
e para a direita, com a folha frontal preenchida. O glifo A47 tinha
dois quadrados contornados e um pequeno quadrado isolado.

A48 redesenha somente `glyphs.layers` em `app/ui_icons.lua`: folha
frontal preenchida e dois contornos traseiros parciais. São vetores
próprios, não assets extraídos. O desenho permanece dentro da caixa
normalizada existente. Posições, tamanhos de botões, IDs, callbacks,
motor, camadas do documento e RBD2 não mudaram.

## Verificação

As suítes existentes `test_ui_icons`, `test_ibis_visual_tools`,
`test_ibis_editor_rail` e `test_compact_layout` passaram localmente
com Lua via `texlua`. Isso verifica registro, limites geométricos,
associações e layout; não substitui LuaJIT nem renderização LÖVE.
`git diff --check` também passou.

LuaJIT e LÖVE não estão instalados neste ambiente. Os resultados
Windows, executável e capturas devem ser consultados no CI do commit
A48; não são declarados aprovados com base na execução local.

## Limites e continuidade

Esta referência não registra build, DPI ou escala. Sustenta a
silhueta de Camadas, não medidas nem reorganização da barra inteira.
Os demais oito controles foram preservados. Confrontar especialmente
Ferramentas, Ajustes e Tela com capturas da versão Windows alvo antes
de alterar seus desenhos ou posições. Não há alegação de fidelidade
1:1. PR #66 deve continuar Draft, sem merge na main.
