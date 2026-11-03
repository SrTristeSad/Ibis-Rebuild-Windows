# A32 — Barras de dimensão interativas na criação de tela

Data: 02/11/2026

## Evidência e limites

A referência pública apresenta controles de ajuste de largura (W)
e altura (H) no diálogo de criação de nova tela. A UI do rebuild A31
já tinha campos e botões +/- reais, mas não sliders.

- Tutorial oficial: https://ibispaint.com/lecture/index.jsp?lang=en&no=03
- Captura pública de criação: https://ibispaint.com/img/lecture/common/chapter_03_03.png

O tutorial não autentica a escala numérica exata do Android 14.1.2.
Esta fase adota uma escala **linear 1–2048 px para o Windows**,
alinhada com o limite existente do motor Lua. Não adiciona DPI
nem formatos além dos presets A30.

## Implementação

- `app/ibis_gallery_ui.lua`: dimensionSlider, sliderValue,
  sliderPosition e sliderHit puramente geométricos. Valores inteiros
  e clamp 1–2048, com conservação do 512 exato de preset.
- `app/ibis_canvas_dimension_slider.lua`: renderização LÖVE
  vetorial de trilho e thumb, sem dependência do Store.
- `app/main.lua`: duas barras sob as caixas numéricas, com clique,
  arrasto, soltura, captura temporária de entrada e retorno ao formulário.
  Nenhum documento ou raster é criado até `Criar tela`.
- `tests/test_ibis_gallery_ui.lua`: geometria em três resoluções,
  extremos, clamp, ida/volta 512, valores inválidos e hitboxes.
- Showcase Windows, etapa 70: mouse real percorre os dois sliders,
  testa 2048, 1 e volta a 512. Compara bytes RGBA, contagem do Store
  e tamanho do histórico undo. As etapas 71–75 continuam intactas.

## Limites explícitos

Não reproduz uma curva do aplicativo Android medida em runtime.
O slider de "Speed–Quality" visto em materiais antigos
**não foi adicionado**, porque a implementação Lua atual não possui
um parâmetro de qualidade equivalente a ligar na UI.
Esta fase não altera RBD2, motor raster, camadas, Windows Ink,
gestos, undo ou branch main.

## Critério

A etapa só estará validada após CI LuaJIT Linux, Windows e
capturas LÖVE concluídos no commit A32.
