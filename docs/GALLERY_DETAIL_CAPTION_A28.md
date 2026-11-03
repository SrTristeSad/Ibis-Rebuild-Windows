# Fase A28 — Legendas vinculadas à imagem na galeria ampliada

Data: 02/11/2026

## Diferença observada
Captura real do rebuild `122-galeria-imagem-ampliada.png` (A27,
commit `402f5f7`): a imagem aparece centralizada, mas o título
começa em x=110 e as dimensões aparecem perto da borda direita
da janela (x≈1060 em 1220×800). Na referência oficial, as
informações ficam logo abaixo da própria imagem.

Referência: tutorial oficial [#20, View Your Artwork](https://ibispaint.com/lecture/index.jsp?lang=en&no=20)
e [captura pública chapter_20_02.png](https://ibispaint.com/img/lecture/en/chapter_20_02.png).
São evidências públicas de hierarquia e alinhamento, **não** medições
autenticadas de um frame do APK Android 14.1.2.
`docs/RESEARCH.md` e `docs/research/evidence-index.json` continuam
indicando falta de comparação dinâmica autenticada.

## Mudança
- `ibis_gallery_detail.captionForImage`: calcula legenda alinhada
  ao centro/largura da obra real, 14 px abaixo de sua base.
  Reserva largura mínima de 260 px para imagens panorâmicas ou
  verticais extremas sem transbordar da viewport.
- `app/main.lua`: desenha o título truncado na largura disponível
  e mantém as **dimensões verdadeiras** do RBD2, com largura calculada
  pela fonte LÖVE. Sem simular tempo de desenho inexistente.
- `tests/test_ibis_gallery_detail.lua`: geometria para 960×640,
  1220×800 e 1920×1080, desenhos quadrados, retratos, paisagens
  e proporções extremas; rejeição de retângulos fora da tela.
- Não altera raster, camadas, RBD2, preferências, gestos, mouse,
  Windows Ink, seleção, histórico ou callbacks da galeria.

## Validação
Aguarda confirmação do GitHub Actions e inspeção do artefato real
de screenshots neste commit. A referência não permite declarar
fidelidade 1:1 ou equivalência pixel a pixel.
