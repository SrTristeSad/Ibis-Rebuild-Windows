# Etapa 46 — Espaçamento adaptativo e continuidade de curvas

O Ibis Rebuild Windows permanece uma reconstrução independente do ibisPaint
Android 14.1.2. Esta etapa não afirma equivalência 1:1 com o produto original.

## Implementação

- `app/stroke_path.lua` interpola a trajetória de mouse, toque e Windows Ink
  em coordenadas da obra usando curvas quadráticas entre pontos médios.
- Movimentos retilíneos longos geram uma única amostra intermediária por
  pacote, independentemente da distância. Curvas recebem até 12 segmentos,
  controlados pelo desvio perpendicular máximo de 0,5 pixel.
- As pressões dos pontos de controle também são interpoladas, sem extrapolar
  além das amostras recebidas. O ponto final real sempre é pintado ao soltar.
- A rasterização permanece no motor C++ da etapa 45. Os subsegmentos de um
  evento atualizam a composição e a imagem uma só vez ao final do pacote.
  Um gesto continua criando uma única operação de desfazer/refazer.
- O primeiro toque mantém a ponta exata, mesmo sem deslocamento. O estado
  temporário da curva não altera RBD2 nem o formato persistido.
- O desenho é incremental, portanto não há reconstrução de todo o traço
  a cada pacote. Em transições de direção muito fortes ainda pode existir
  acúmulo de opacidade na junção de segmentos: a mesclagem é por segmento,
  não por pincelada inteira.

## Verificações

`tests/test_stroke_path.lua` valida trajetórias retilíneas longas, curvas,
teto de subdivisões, pressões, eventos duplicados, fim exato, erros de
entrada, escrita C++ em camadas, único undo, redo exato e reabertura RBD2.
A suíte é executada por `tools/test_lua.py` nas fases LuaJIT e nativa.
Os testes Windows com LÖVE da pipeline também devem permanecer aprovados.

Inkora, estruturas persistidas, ABI C++ e projeto Android não foram alterados.
