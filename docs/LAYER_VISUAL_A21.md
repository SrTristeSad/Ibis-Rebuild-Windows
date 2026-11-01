# A21 — rodape de Camadas proximo da referencia original

Referência: ibisPaint, Layer Window Details:
https://ibispaint.com/lecture/index.jsp?no=156

## Interface

- Sete comandos reais de camada (Nova, Duplicar, Excluir,
  Subir lista, Descer lista, Renomear e Mesclar) usam
  **uma faixa de sete icones de 36 px no topo do painel**.
  O texto do comando aparece ao passar o mouse.
- O rodape segue a hierarquia do ibisPaint:
  **Clipping | Alpha Lock | Normal** na primeira linha,
  com **percentual, decremento, barra de opacidade e
  incremento** na segunda linha.
- Clipping e Alpha Lock aparecem **desabilitados**: nao ha
  motor funcional; a interface nao cria estados falsos.
- Normal abre o catalogo de modos via clique real.
  O controle Normal anterior dentro da linha ativa continua
  disponivel para compatibilidade com outros percursos.
- A barra de opacidade usa as coordenadas de hit-test,
  drag e release da infraestrutura Lua existente, deslocadas
  conjuntamente com o visual.
- Adicionar, Duplicar, Excluir, Mesclar, visibilidade e
  gerenciamento de metadata conservam os callbacks Lua existentes.
- Capturas 53 e 54 comprovam o novo rodape e a abertura
  do seletor de mesclagem sem alterar os pixels.
- Nao houve alteracao nos motores raster, RBD2 ou Windows Ink.

## Nao coberto

Esta revisao usa a referencia oficial para hierarquia e
disposicao, nao valida equivalencia pixel a pixel com
a compilacao Android 14.1.2; faltam assets originais
licenciados, fontes e regras de varios modos de mesclagem.
