# A33 — Hierarquia e cores da janela Nova tela

Data: 02/11/2026

## Comparacao observada
Na captura real A32 `70-nova-tela-tamanhos-basicos.png`,
o corpo da janela tem um branco quase puro; as abas e o
formato selecionado possuem azul forte. A referencia
publica do ibisPaint apresenta a janela com corpo cinza,
secao de ilustracao em faixa escura e linhas neutras.

Fonte visual:
- https://ibispaint.com/lecture/index.jsp?lang=en&no=03
- https://ibispaint.com/img/lecture/common/chapter_03_03.png

As cores sao uma aproximacao a partir do tutorial publico,
**nao valores RGB medidos no APK Android 14.1.2**.

## Codigo e limites
- `app/ibis_canvas_dialog_chrome.lua`: modulo isolado de desenho
  LÖVE com corpo neutro, separador `Ilustração`, abas
  planas e paleta coerente, sem dependencia do Store.
- `app/ibis_canvas_preset_rows.lua`: tons cinza para
  linha normal, hover e selecionada. Preserva a linha,
  texto, simbolo e dimensao reais.
- `app/main.lua`: desenha esse corpo e as abas mantendo
  **as mesmas hitboxes e callbacks** da A32. Permanecem:
  campos, +/−, sliders, selecao de presets, Criar e Cancelar.
- `tests/test_ibis_gallery_ui.lua`: estados visuais,
  contraste e valores de cores em conjunto com os testes
  preexistentes de geometria em tres resolucoes.

Nao muda o RBD2, rasters, camadas, Windows Ink, undo ou
limite de 1–2048 px. Nenhum elemento funcional e simulado.

## Validacao
O CI de Linux/Windows e a inspeção das capturas reais devem
ser feitos no HEAD A33 antes de declarar a etapa aprovada.
A aparencia continua sendo uma adaptacao, sem paridade 1:1.
