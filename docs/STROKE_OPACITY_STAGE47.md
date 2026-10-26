# Etapa 47 — Composição de opacidade por pincelada

## Correção funcional

A Etapa 46 desenhava os subsegmentos de uma curva de forma independente.
Em um pincel parcialmente transparente, cada trecho repetia a composição
na junção e escurecia o traço; com a borracha, podia apagar mais que o
previsto.

Nesta etapa, a transação de pintura passa a possuir:
- a imagem original da camada, já existente para o histórico;
- uma máscara de cobertura de 1 byte por pixel, inicializada uma vez;
- uma chamada C++ que desenha apenas o retângulo do segmento e conserva,
  para cada pixel, a maior cobertura observada durante aquele gesto.

Toda contribuição é composta contra a camada **antes** da pincelada.
Segmentos repetidos com a mesma pressão deixam RGBA intocado; outro
gesto independente pode acumular normalmente. A borracha usa a mesma
máscara para evitar remoção dupla. Pressões crescentes, soft brush,
ponta inclinada e traços contínuos também compartilham o mecanismo.

A máscara existe apenas enquanto o usuário desenha e não faz parte
do formato RBD2. O bitmap de histórico não ganha cópias adicionais,
pois a imagem de origem já estava retida na transação. A máscara
temporária exige aproximadamente um byte por pixel e é descartada
ao concluir a pincelada.

## Validação

- `tests/test_core.py`: ABI e composição nativa, cruzamentos,
  repetição de segmentação, pressão variável, pincel suave, inclinação,
  borracha e validação atômica de buffers.
- `tests/test_stroke_accumulation.lua`: interação real C++/Lua, uma
  operação por gesto, dois gestos acumuláveis, undo/redo e RBD2.
- Pipeline Windows: compilação MSVC x64, LuaJIT, testes nativos e
  rotas oficiais do LÖVE.

O Inkora não faz parte destas alterações. O motor permanece independente:
não representa uma cópia 1:1 do algoritmo interno do ibisPaint Android.
