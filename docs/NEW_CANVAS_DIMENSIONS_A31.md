# Fase A31 — Ajustes reais de largura e altura na Nova tela

Data: 02/11/2026

## Evidência
O tutorial oficial do ibisPaint (#02, *Start Creating an Artwork*)
mostra controles `−` e `+` ao lado de W/H na seção Illustration:
https://ibispaint.com/lecture/index.jsp?lang=en&no=03
https://ibispaint.com/img/lecture/common/chapter_03_03.png
A captura pública orienta a aparência, **não** estabelece a escala
exata do controle na edição Android 14.1.2.

A captura real da A30, `70-nova-tela-tamanhos-basicos.png`, exibe
campos de largura e altura sem ajustes por clique.

## Mudança
- `app/ibis_gallery_ui.lua`: define geometria pura de dois controles
  ao final de cada campo numérico. `stepDimension` mantém valores
  inteiros de 1 a 2048 px; retorna nil para entrada inválida,
  ou se já estiver no limite.
- **Adaptação Windows explícita:** cada clique usa passo de 16 px;
  não se presume a mesma escala interna do aplicativo Android.
- `app/ibis_canvas_dimension_controls.lua`: desenhos vetoriais
  de menos/mais, com estilo normal/hover/indisponível.
- `app/main.lua`: hitboxes usam a geometria dos botões, sem
  bloquear o foco do campo de texto. Os botões editam somente
  `m.values[2]` e `m.values[3]`; a prévia e o estado selecionado
  são rederivados a partir desses mesmos valores. Nenhum acesso
  ao Store nem atualização de raster até `Criar tela`.
- `tests/test_ibis_gallery_ui.lua`: sobreposição, limites,
  entradas inválidas, passo de ida/volta e três resoluções.
- O showcase GUI executa clique real no + e no - da largura,
  confirma o retorno aos 512 px e verifica bytes RGBA,
  histórico undo e quantidade de projetos inalterados.

## Limites
Campos continuam editáveis por teclado. O tutorial também mostra
sliders e tamanhos maiores, mas estes não são simulados aqui.
O limite real do motor Lua continua 2048 px, sem DPI operacional.
RBD2, pincéis, camadas, Windows Ink e branch main permanecem iguais.

## Validação
Exige CI do commit e inspeção da captura real do Windows.
Sem alegação de equivalência pixel a pixel com Android 14.1.2.
