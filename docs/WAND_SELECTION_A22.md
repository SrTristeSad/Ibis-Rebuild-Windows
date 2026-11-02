# A22 — Varinha Mágica: primeiro motor real de seleção

Referência geral: [ibisPaint — Selection Layer](https://ibispaint.com/lecture/index.jsp?no=24) e [Expand/Contract Selection](https://ibispaint.com/lecture/index.jsp?no=169).

## Escopo implementado

- \`app/wand_selection.lua\`: varredura de RGBA exato, com tolerância
  limitada a 0–100, flood fill de quatro vizinhos ou seleção global.
- Modos **Definir**, **Adicionar** e **Subtrair** operam sobre máscara
  binária \`uint8_t[]\` alocada por LuaJIT FFI; nunca reescrevem pixels.
- Referência ao **composite da tela** ou **buffer da camada atual**.
- Operação não gera undo/redo nem marca RBD2 como modificado.
- Máscara visual própria produz uma imagem azul translúcida apenas
  em pixels efetivamente selecionados; não é apenas bounding box.
- A máscara **ainda não restringe pincel, balde, transformação ou
  exclusão**: essa integração é uma etapa separada. O usuário não
  deve interpretar o preview como garantia de edição mascarada.
- Os botões Gap/Unpainted continuam experimentais sem algoritmo,
  assim como Laço; não há alegação 1:1 com o Android.

## Testes

\`tests/test_wand_selection.lua\`: seleção contínua/descontínua,
tolerância, alfa, união, subtração, limites, invariância dos RGBA.
O teste gráfico real deve confirmar que a seleção não aciona o
pincel antigo, e que o preview acompanha a transformação do canvas.
